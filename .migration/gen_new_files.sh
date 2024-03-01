#!/bin/bash
set -euo pipefail

# set repo_name

# Check if no arguments are provided
if [ $# -eq 0 ]; then
    # Get the current Git branch name
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    # Extract the substring after the first slash
    repo_name=${current_branch#*/}
else
    repo_name=$1
fi



# Set version
current_date=$(date +%Y.%m)
version="$current_date"_0

echo "Repo name: $repo_name"

echo version is $version


# check if the path exist
if [ ! -d "./libs/$repo_name" ]; then
  echo "Directory "./libs/$repo_name" does not exist. Exiting script."
  exit 1
fi

# create Dockerfile

cat <<EOT > libs/$repo_name/Dockerfile
FROM localhost/images_sf.perl.base:prod-latest AS pin

COPY libs /src/libs

WORKDIR /src/libs/$repo_name

CMD /tools/lock_dists.sh


FROM pin AS base

RUN /tools/install_dependencies.sh


FROM base AS test

WORKDIR /src/libs/$repo_name

RUN cpm install -g App::Prove

CMD /tools/run-tests.sh


FROM base AS dist

# Install all Dist::Zilla plugins we will ever need.
RUN /tools/install_dzil_deps.sh

CMD /tools/release.sh


FROM base AS prod
EOT

# create README

cat <<EOT > libs/$repo_name/README.md

# Migration Checklist

From: [https://github.com/SocialFlowDev/$repo_name](https://github.com/SocialFlowDev/$repo_name)

## Checklist

- [X] Set to WIP In the list of distributions
- [X] Subtree added
- [X] Create a README with the checklist
- [X] Dockerfile
- [X] Dockerfile.dockerignore
- [X] .bumpversion.cfg
- [X] dist.ini
- [X] release
- [X] cpanfile
- [X] cpanfile.pinned
- [X] container.dep
- [X] Tests
- [ ] Initial Release
- [ ] Any dependents re-pinned (checks released)
- [ ] Old repo archived
- [ ] Set to sf-perl In the list of distributions
- [ ] Colleagues informed
- [ ] sf-deploy-application changed

## New added dependencies

- 'Test::Compile::Internal'

EOT

# Add Dockerfile.dockerignore
cat <<EOT > libs/$repo_name/Dockerfile.dockerignore
*
!libs/$repo_name
libs/$repo_name/Dockerfile
libs/$repo_name/Dockerfile.dockerignore
!tools/container
EOT

# Add .bumpversion.cfg

cat <<EOT > libs/$repo_name/.bumpversion.cfg
[bumpversion]
current_version = $version
serialize = {year}.{month}_{release}
parse = (?P<year>\\d{4})\\.(?P<month>\\d{2})_(?P<release>\\d+)

[bumpversion:file:dist.ini]
EOT

# Add a dependency declaration to container.dep
echo images/sf.perl.base > libs/$repo_name/container.dep

# Add an empty release file to mark this project as being released 
touch libs/$repo_name/release

# Add test file when there are no test file in repo dir
if [ ! -d "./libs/$repo_name/t/compile.t" ]; then
  echo "test file "./libs/$repo_name/t/compile.t" does not exist. Gonna create one."
  mkdir -p "./libs/$repo_name/t"
  cat <<"EOT" > libs/$repo_name/t/compile.t
use strict;
use warnings FATAL => 'all';
use Test::Compile::Internal;
use Test::More;
use Module::Runtime qw[ use_module ];
use FindBin;
use lib "$FindBin::Bin/../lib";


my $path = "$FindBin::Bin/../lib/";
my @pms = Test::Compile::Internal->all_pm_files($path);

plan tests => 0+@pms;

for my $pm (@pms) {
    $pm =~ s|$path||g;
    $pm =~ s!(^lib/|\.pm$)!!g;
    $pm =~ s|/|::|g;
    print "$pm\n";
    eval <<"";
use strict;
use warnings;
package SocialFlow::TestFor::$pm;
use $pm;
1;

    ok !$@, "no warnings from use $pm";
    die $@ if $@;
}
EOT

fi

# generate cpanfile
bash "$(dirname "$0")/dist_to_cpanfile.sh"
