use strict;
use warnings FATAL => 'all';
use Test::Compile::Internal;
use Test::More;
use Module::Runtime qw[ use_module ];
use FindBin;
use Carp qw[ confess ]; # Import confess
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../SocialFlow-Web-Config/lib";

BEGIN {
    use FindBin;
    $ENV{SOCIALFLOW_TEMPLATE_PATH} = "$FindBin::Bin/../root/templates";
};

if (@ARGV) {
  my $path = $ARGV[0];
} else {
  my $path = "$FindBin::Bin/../lib/";
}
my @pms = Test::Compile::Internal->all_pm_files($path);

plan tests => 0+@pms;

for my $pm (@pms) {
    my $file = $pm;
    $pm =~ s|$path||g;
    $pm =~ s!(^lib/|\.pm$)!!g;
    $pm =~ s|/|::|g;
    
    # Use eval to catch exceptions
    my $load_result = eval {
        use_module($pm)->import;
        1; # Return true if module loads successfully
    };
    my $error = $@; # Capture error message if eval fails

    # Test the result of the eval block
    my $test_result = ok($load_result, $pm);
    
    unless ($test_result) {
        diag("\n======PM is == $pm; File is == $file\n\n");
        if ($error) {
            confess "Error loading module: $error";
        }
    }
}
