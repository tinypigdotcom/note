package App::Notes;

use 5.022001;
use strict;
use warnings;

BEGIN { $| = 1 }

use Clipboard;
use IO::File;

our $VERSION = '0.11.0';

my $SEPARATOR = "%%%\n";

sub which_notefile {
    my ($pattern) = @_;
    $pattern ||= '';

    my $nf = $ENV{NOTEFILES} || "$ENV{HOME}/.notes";
    my @notefiles = split ':', $nf;

    # No pattern specified, use default
    if ( !$pattern ) {
        return @notefiles;
    }
    if ( -r $pattern ) {
        return $pattern;
    }
    my @found_notefiles = grep { /$pattern/i } @notefiles;
    if ( @found_notefiles > 1 ) {
        die qq{Ambiguous file specification "$pattern"};
    }
    elsif ( @found_notefiles < 1 ) {
        die qq{No file found for pattern "$pattern"};
    }
    else {
        return $found_notefiles[0];
    }
}

sub new {
    my ( $class, %opts ) = @_;

    my @notefiles = which_notefile($opts{file});
    my $self = {
        library      => $opts{library},
        title        => $opts{title},
        Verbose      => $opts{Verbose},
        word         => $opts{word},
        autoprint    => $opts{autoprint},
        notefiles    => \@notefiles,
        threshold    => $opts{threshold} || 10,
        output_lines => [],
    };
    bless $self, $class;

    return $self;
}

sub output {
    my ($self,@args) = @_;
    my $output_line = join( '', @args );
    push @{$self->{output_lines}}, $output_line;
}

sub add_note {
    my ($self) = @_;
    my $note;
    while ( my $input_line = <STDIN> ) {
        $note .= $input_line;
    }

    my $outfile = $self->{notefiles}->[0];
    my $ofh = IO::File->new( $outfile, '>>' );
    die "Cant open $outfile: $!" if !defined $ofh;

    print $ofh "${SEPARATOR}${note}\n";
    $ofh->close;
    warn "*** 1 note added to $outfile\n";

    return;
}

sub markup {
    my ($self) = @_;
    my $ESC = "\x1B";
    my $reset = "${ESC}[0m";
    my $bold = "${ESC}[1m";
    my $italics = "${ESC}[3m";

    if ( $_[0] =~ m{^[^\x0a\x0d]*format:markup} ) {
        $_[0] =~ s{\s*format:markup}{};
        for ($_[0]) {
            s/\\\\/xDMBqbackslash/g;
            s/\\\*/xDMBqasterisk/g;
            s/\\\_/xDMBqunderscore/g;
            s/\*([^*]*)\*/$bold$1$reset/g;
            s/_([^_]*)_/$italics$1$reset/g;
            s/xDMBqunderscore/_/g;
            s/xDMBqasterisk/*/g;
            s/xDMBqbackslash/\\/g;
        }
    }
}


sub search_note {
    my ($self,@patterns) = @_;
    my $library = $self->{library};
    my $title   = $self->{title};
    my $Verbose = $self->{Verbose};
    my $word    = $self->{word};

    if ($word) {
        for (@patterns) {
            $_ = "\\b$_\\b";
        }
    }

    if ($title) {
        for (@patterns) {
            $_ = "^[^\\x0a\\x0d]*$_";
        }
    }

    my @notes;
    for my $file (@{$self->{notefiles}}) {
        my $ifh = IO::File->new( $file, '<' );
        die "Cant open $file: $!" if !defined $ifh;

        my $contents = do { local $/; <$ifh> };

        $ifh->close;
        push @notes, split( /^$SEPARATOR/m, $contents );
    }

    my %matches;
    my %excluded;
    my $total_excluded = 0;
  OUTER: for (@notes) {
        for my $pattern (@patterns) {
            next OUTER unless /$pattern/i;
        }
        if (/^[^\x0a\x0d]*library:(\S*)/) {
            my $note_lib = $1;
            if ( $library ne $note_lib ) {
                $excluded{$note_lib}++;
                $total_excluded++;
                next OUTER;
            }
        }
        else {
            if ($library) {
                $excluded{no_library}++;
                $total_excluded++;
                next OUTER;
            }
        }
        s/^/  /mg;
        $matches{$_}++;
    }
    my $output_separator = "\n" . '+' . '=' x 78 . "\n|";
    my $title_separator  = "\n" . '+' . '-' x 68 . "\n";
    if (%matches) {
        my $total_matches = scalar keys %matches;
        # this needs to be part of the script
#        if ( $total_matches > $self->{threshold} ) {
#            print "Found $total_matches matches. Continue (Y/n) ? ";
#            my $junk = <STDIN>;
#            chomp $junk;
#            if ( $junk =~ /n/i ) {
#                exit;
#            }
#        }
        my $content;
        for my $match ( keys %matches ) {
            markup($match);
            my @lines = split "\n", $match;
            my $title = shift @lines;
            $title =~ s/^\s*//;
            my $body = join "\n", @lines;
            $body =~ s/\s*$//s;
            $self->output($output_separator, " $title", $title_separator);
            $content = '';
            if ( $body =~ s/[[]<(.*)>[]]/$1/sg ) {
                $content = $1;
            }
            $self->output($body, "\n");
            Clipboard->copy($content || $body);
        }
        $self->output("\n");
    }
    else {
        $self->output("No match.\n");
    }
    if ( $Verbose && $total_excluded ) {
        my $entries = $total_excluded == 1 ? 'entry' : 'entries';
        my $were    = $total_excluded == 1 ? 'was'   : 'were';
        $self->output("($total_excluded $entries $were excluded in other libraries- ");
        for ( keys %excluded ) {
            $self->output("$_:$excluded{$_} ");
        }
        $self->output(")\n");
    }
    if ($self->{autoprint}) {
        my $pager = $ENV{PAGER} || 'less -FX';
        open O, "| $pager" or die;
        print O @{$self->{output_lines}};
        close O;
    }

    return @{$self->{output_lines}};
}

1;

__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

App::Notes - Perl extension for blah blah blah

=head1 SYNOPSIS

  use App::Notes;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for App::Notes, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

U-Wesker\dave, E<lt>dave@nonetE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by U-Wesker\dave

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.22.1 or,
at your option, any later version of Perl 5 you may have available.

=cut

