#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Data::Dumper;
use DMB::Tools ':all';

use lib 'lib';
use App::Notes;

sub function1 {
    print "I am b.pl\n";

    my $file = "$ENV{HOME}/monstercards/dnd.note";
    my $app_note = App::Notes->new(
        file      => $file,
        title     => 1,
    );
    my @output_files = $app_note->search_note('claw');
    print @output_files;
}

sub main {
    my @argv = @_;
    function1();
    return;
}

my $rc = ( main(@ARGV) || 0 );

exit $rc;

