#!/usr/bin/perl

use strict;

use Getopt::Long;
use Pod::Usage;

my $help = 0;
my $fps = 23.976;
my $from = "mdvd";
my $to = "mpl2";

sub read_raw_input
{
    return <>;
}

sub format_mdvd_mpl2
{
    my $match = 0;
    foreach(@{$_}[3..$#{$_}])
    {
        # mdvd tags
        # remove useless tags
        s/\{[^yY]:.+?\}//g;
        # remove Y:u and Y:b
        s/\{[y|Y]:[^i]\}//g;
        # swap y:i to /
        s/\{y:i\}/\//g;
        # seek for Y:i
        $match = 1 if (/\{Y:i\}/);
        # replace Y:i by adding / to all lines
        s/^\{Y:i\}|^/\//g if ($match);

        # srt tags
        # remove useless tags
        # to do
    }
}

sub format_srt_mpl2
{
    my $match = 0;
    foreach(@{$_}[3..$#{$_}])
    {
        # srt tags
        # remove useless tags (+2-letters)
        s/<\/?[^>\/]{2,}?>//g;
        # remove 1-letter tags w/o italic
        s/<\/?[^iI]?>//g;
        # to do
    }
}

sub format_mdvd
{
    my $slashes = 0;
    foreach(@{$_}[3..$#{$_}])
    {
        $slashes++ if (/^\//);
    }
    if ($slashes == $#{$_} - 2 && $slashes > 0)
    {
        foreach(@{$_}[3..$#{$_}])
        {
            s/^\///;
        }
        @{$_}[3] =~ s/^/\{Y:i\}/
    }
    elsif ($slashes > 0)
    {
        foreach(@{$_}[3..$#{$_}])
        {
            s/^\//\{y:i\}/;
        }
    }
    # srt tags
    # to do
}

sub format_srt
{
    # to do
}

sub from_mdvd
{
    my $lines = $_[0];
    my @subtitles = ();

    for (my $i = 0; $i <= $#{$lines}; $i++)
    {
        # parse subtitle format using regexp
        $lines->[$i] =~ m/\{\s*([^\}]*)\s*\}\s*\{\s*([^\}]*)\s*\}\s*(.*)/;
        # separate every line of text
        my @textlines = split(/\s*\|\s*/, $3);
        # create array with subtitle number, start time, stop time and lines of text
        my @sub_line = ($i+1, int(($1*1000)/$fps), int(($2*1000)/$fps));
        push(@sub_line, @textlines);
        # add reference to big table
        push(@subtitles, \@sub_line);
    }
    return @subtitles;
}

sub from_mpl2
{
    my $lines = $_[0];
    my @subtitles = ();

    for (my $i = 0; $i <= $#{$lines}; $i++)
    {
        # parse subtitle format using regexp
        $lines->[$i] =~ m/\[\s*([^\]]*)\s*\]\s*\[\s*([^\]]*)\s*\]\s*(.*)/;
        # separate every line of text
        my @textlines = split(/\s*\|\s*/, $3);
        # create array with subtitle number, start time, stop time and lines of text
        my @sub_line = ($i+1, $1*100, $2*100);
        push(@sub_line, @textlines);
        # add reference to big table
        push(@subtitles, \@sub_line);
    }
    return @subtitles;
}

sub from_srt
{
    my $lines = $_[0];
    my @subtitles = ();

    my @textlines = ();
    my $start = 0;
    my $stop = 0;
    my $count = 0;

    foreach (@$lines)
    {
        if (/^\s*(\d+):(\d+):(\d+),(\d+)\s*-->\s*(\d+):(\d+):(\d+),(\d+)\s*/)
        {
            $start = ((($1*60) + $2)*60 + $3) * 1000 + $4;
            $stop = ((($5*60) + $6)*60 + $7) * 1000 + $8;
        }
        elsif (/^\s*(\d+)\s*$/)
        {
            my @sub_line = ($count++, $start, $stop);
            push(@sub_line, @textlines);
            push(@subtitles, \@sub_line);
            @textlines = ();
        }
        elsif (/^\s*(.*\S)\s*$/)
        {
            push(@textlines, $1);
        }
    }
    # add last one
    my @sub_line = ($count++, $start, $stop);
    push(@sub_line, @textlines);
    push(@subtitles, \@sub_line);
    # remove first (dummy)
    shift (@subtitles);
    return @subtitles;
}

sub to_mdvd {
    my $lines = $_[0];
    my @subtitles = ();

    push(@subtitles, "{1}{1}$fps");
    foreach(@$lines)
    {
        format_mdvd(\@{$_});
        push(@subtitles,
            sprintf "{%d}{%d}%s", int(($_->[1]/1000)*$fps), int(($_->[2]/1000)*$fps), join('|', @{$_}[3..$#{$_}]));
    }
    return @subtitles;
}

sub to_mpl2
{
    my $lines = $_[0];
    my @subtitles = ();

    foreach(@$lines)
    {
        #format_mpl2(\@{$_});
        format_srt_mpl2(\@{$_});
        push(@subtitles,
            sprintf "[%d][%d]%s", $_->[1]/100, $_->[2]/100, join('|', @{$_}[3..$#{$_}]));
    }
    return @subtitles;
}

sub to_srt {
    my $lines = $_[0];
    my @subtitles = ();

    foreach(@$lines)
    {
        push(@subtitles, "$_->[0]");
        my $start = sprintf "%09d", $_->[1];
        my $stop = sprintf "%09d", $_->[2];
        my $time = sprintf "%02d:%02d:%02d,%03d --> %02d:%02d:%02d,%03d", substr($start, 0, 2), substr($start, 2, 2), substr($start, 4, 2), substr($start, 6, 3), substr($stop, 0, 2), substr($stop, 2, 2), substr($stop, 4, 2), substr($stop, 6, 3);
        push(@subtitles, $time);
        foreach(@{$_}[3..$#{$_}])
        {
            # format srt
            # to-do
            push(@subtitles, "$_");
        }
        push(@subtitles, ""); # blank
    }
    return @subtitles;
}

sub write_raw_output
{
    # print to stdout
    my $lines = $_[0];
    foreach(@$lines)
    {
        print "$_\n";
    }
}

sub debug_write
{
    my $lines = $_[0];
    for (my $i = 0; $i <= $#{$lines}; $i++)
    {
        foreach (@{$lines->[$i]})
        {
            print "[$_]";
        }
        print "\n";
    }
}

sub main
{
    my @lines = read_raw_input();
    #my @sub1 = from_mdvd(\@lines);
    my @sub1 = from_srt(\@lines);
    my @sub2 = to_mpl2(\@sub1);

    #my @sub1 = from_mpl2(\@lines);
    #my @sub1 = from_srt(\@lines);
    #my @sub2 = to_mdvd(\@sub1);

    #my @sub1 = from_mdvd(\@lines);
    #my @sub1 = from_mpl2(\@lines);
    #my @sub2 = to_srt(\@sub1);

    write_raw_output(\@sub2);
    #debug_write(\@sub1);
}

GetOptions ("h" => \$help,
            "f=f" => \$fps,
            "i=s" => \$from,
            "o=s" => \$to,
            ) or pod2usage(2);

pod2usage(1) if $help;
# ssie jak jest bez argumentny
main();

__END__

=head1 NAME

sub2sub - Subtitle format converter.

=head1 SYNOPSIS

sub2sub [options]

"perlcmdline --help" will list options.  "perlcmdline --man"
will show docs.

=head1 OPTIONS

=over 4

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--length positive-integer>

A "do nothing" length value which must be an int > 0.

=item B<--filename input-filename>

A "do nothing" string value.

=item B<--addr hostname-or-ip>

An internet address.  This option may be used multiple
times in a single command to specify multiple addresses.

=back

=head1 AUTHOR

Jakub Mikołajczyk, kmikolaj@gmail.com

=head1 COPYRIGHT

Copyright (c) 2009 Jakub Mikołajczyk. All rights reserved. This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
