#!/usr/bin/perl

use strict;
use warnings;

use English qw(-no_match_vars);
use Test::More;
use UNIVERSAL::require;

plan(skip_all => 'Test::Compile required')
    unless Test::Compile->require();
Test::Compile->import();

# use mock modules for non-available ones
if ($OSNAME eq 'MSWin32') {
    push @INC, 't/lib/fake/unix';
} else {
    push @INC, 't/lib/fake/windows';
}

# exclude linked modules
my @files = grep { filter($_) } all_pm_files('lib');

all_pm_files_ok(@files);

# filename-based filter
sub filter {
    return 1;
}
