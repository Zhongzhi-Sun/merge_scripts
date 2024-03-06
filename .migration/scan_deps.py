import subprocess
import sys
import os
from typing import *
import re

class Cpanfile:
    def __init__(self,path):
        self.path = path
        self.cpan_path = os.path.join(path, "cpanfile")
        self.project_name = self.get_project_name(path)
        self.all_core_modules = self.get_all_core_modules()  # Fetch all core modules at initialization


    # get project name from path
    def get_project_name(self, path) -> str:
        path = path[:-1] if path.endswith("/") else path
        return os.path.basename(path).replace("-", "::").replace("\n", "")

    def get_all_core_modules(self):
        perl_code = "use Module::CoreList; print join('\n', keys %{$Module::CoreList::version{5.032}});"
        result = subprocess.run(['perl', '-e', perl_code], capture_output=True, text=True)
        return set(result.stdout.strip().split('\n'))

    # find perl files
    def find_perl_file(self, path) -> list:
        return [os.path.join(root, file) for root, _, files in os.walk(path) for file in files if file.endswith((".pl", ".pm"))]


    def scan_deps(self, path) -> list:
        pl_deps = []
        with open(path,"r") as f:
            for line in f:
                if line.startswith("use") or line.startswith("require"):
                    pl_deps.append(line.replace(";","").split(" ")[1].strip())
        return pl_deps


    # generate cpanfile
    def generate_outputs(self, deps:list, output_path:str):
        with open(output_path,"w") as f:
            for dep in deps:
                f.write(f"requires {dep};\n")


    # check if existing cpanfile missing deps
    def check_cpanfile(self, deps:list, cpan_path:str) -> list:
        missing_deps = []
        with open(cpan_path,"r") as f:
            lines = [line.replace(";","").replace(",","").replace("'","").split(" ")[1].strip() for line in f]
        missing_deps = [dep for dep in deps if dep not in lines and not any(self.is_sublib(dep, line) for line in lines)]
        return lines, missing_deps


    # check if def1 is sub libs of dep2
    def is_sublib(self, dep1:str,dep2:str) -> list:
        return dep1 == dep2 or dep1.startswith(dep2 + "::")

    # check if perl core module
    def is_perl_core_module(self, module_name):
        return True if module_name in self.all_core_modules else False

    # drop sub libs
    def filter_deps(self, deps:list) -> list:
        deps_set = set(deps)
        block_list = {"strict", "warnings", "strictures", "feature", "Module", "if"}
        version_pattern = r'v\d+(\.\d+)*'

        # filter sub libs
        filtered_deps = {dep for dep in deps_set if not any(self.is_sublib(dep, other_dep) for other_dep in deps_set if dep != other_dep)}
        # filter project name
        filtered_deps -= {item for item in filtered_deps if item.startswith(self.project_name)}
        # filter version announce and none module items
        filtered_deps -= {item for item in filtered_deps if re.match(version_pattern, item) or item in block_list}
        # drop perl core modules
        filtered_deps -= {item for item in filtered_deps if self.is_perl_core_module(item)}

        return list(filtered_deps)


# main function
def main(path) ->None:
    cpan = Cpanfile(path)
    # scan perl files
    pl_files = cpan.find_perl_file(path)
    # scan deps
    deps = sorted(set(dep for pl_file in pl_files for dep in cpan.scan_deps(pl_file)))
    deps = cpan.filter_deps(deps)

    # check if cpanfile exists
    if os.path.exists(cpan.cpan_path):
        exist_deps, missing_deps = cpan.check_cpanfile(deps,cpan.cpan_path)
        # print(f"exist__deps={exist_deps}\nmissed_deps={missing_deps}\n")
        if len(missing_deps) != 0:
            print("==== Please add the lines below into cpanfile manually:\n")
            for item in missing_deps:
                print(f"requires {item};")
        else:
            print("==== No missing deps found.")

    else:
        # generate_outputs(deps, cpan_path)
        pass


if __name__ == "__main__":
    main(sys.argv[1])
