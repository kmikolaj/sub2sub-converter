#!/usr/bin/perl

use strict;

use Getopt::Long;
use Pod::Usage;
use Switch;

# default options
my $help = 0;
my $fps = 23.976;
my $from = "mdvd";
my $to = "mpl2";
my $eol = "\r\n";

sub read_raw_input
{
    return <>;
}

sub auto_detect_format
{
    # to do
}

sub format_mdvd_mpl2
{
    my $match = 0;
    # convert mdvd tags to mpl2
    foreach(@{$_}[3..$#{$_}])
    {
        # remove useless tags
        s/\{[^yY]:.+?\}//g;
        # remove Y:u and Y:b
        s/\{[y|Y]:[^i]\}//g;
        # swap y:i to /
        s/^\{y:i\}/\//g;
        # seek for Y:i
        $match = 1 if (/^\{Y:i\}/);
        # replace Y:i by adding / to all lines
        s/^\{Y:i\}|^/\//g if ($match);
        # remove tags inside subtitles
        s/\{[Yy]:i\}//g;
    }
    # to-do
    # parse y:I, y:UbI
}

sub format_srt_mpl2
{
    # convert srt tags to mpl2
    foreach(@{$_}[3..$#{$_}])
    {
        # remove useless tags (+2-letters)
        s/<\/?[^>\/]{2,}?>//g;
        # remove 1-letter tags w/o italic
        s/<\/?[^iI]?>//g;
        # if line starts with tag
        if (/^<[iI]>/)
        {
            # replace tag
            s/^<[iI]>/\//;
            # remove tag-closing if exists in line
            s/<\/[iI]>$//;
        }
        # if line ends with tag
        elsif (/<\/[iI]>$/)
        {
            # add / to line start
            s/<\/[iI]>$//;
            s/^/\//;
        }
        # remove tags inside subtitles
        s/<\/?[iI]>//g;
    }
}

sub format_mpl2_mdvd
{
    my $slashes = 0;
    # convert mpl2 tags to mdvd
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
}

sub format_mpl2_srt
{
    my $s = 0;
    my $e = 0;
    for (my $i = 3; $i <= $#{$_}+1; $i++)
    {
        if ($_->[$i] =~ /^\// and $s == 0)
        {
            $s = $i;
            $e = $i;
        }
        elsif  ($_->[$i] =~ /^\//)
        {
            $_->[$i] =~ s/^\///;
            $e = $i;
        }
        else
        {
            $_->[$s] =~ s/^\//<i>/;
            $_->[$e] =~ s/$/<\/i>/;
            $s = 0;
            $e = 0;
        }
    }
}

sub format_mdvd_srt
{
    # to do
}

sub format_srt_mdvd
{
    # to do
}

sub format_tags
{
    if ($from eq "mdvd")
    {
        switch($to)
        {
            case "mpl2" { format_mdvd_mpl2(\@{$_}); }
            case "srt" { format_mdvd_srt(\@{$_}); }
        }
    }
    elsif ($from eq "mpl2")
    {
        switch($to)
        {
            case "mdvd" { format_mpl2_mdvd(\@{$_}); }
            case "srt" { format_mpl2_srt(\@{$_}); }
        }
    }
    elsif ($from eq "srt")
    {
        switch($to)
        {
            case "mpl2" { format_srt_mpl2(\@{$_}); }
            case "mdvd" { format_srt_mdvd(\@{$_}); }
        }
    }
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
        format_tags(\@{$_});
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
        format_tags(\@{$_});
        push(@subtitles,
            sprintf "[%d][%d]%s", $_->[1]/100, $_->[2]/100, join('|', @{$_}[3..$#{$_}]));
    }
    return @subtitles;
}

sub srt_time
{
    # from time in miliseconds make string in srt time format: hh:mm:ss,mmm
    my ($time) = @_;
    my $ms = $time % 1000;
    my $sec = int($time / 1000);
    my $min = int($sec / 60);
    $sec %= 60;
    my $hour = int($min / 60);
    $min %= 60;
    return sprintf "%02d:%02d:%02d,%03d", $hour, $min, $sec, $ms;
}

sub to_srt {
    my $lines = $_[0];
    my @subtitles = ();

    foreach(@$lines)
    {
        push(@subtitles, "$_->[0]");
        push(@subtitles,
            sprintf "%s --> %s", srt_time($_->[1]), srt_time($_->[2]));
        format_tags(\@{$_});
        foreach(@{$_}[3..$#{$_}])
        {
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
        print "$_$eol";
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
    # read subtitles from file or STDIN if file omitted
    my @lines = read_raw_input();
    my (@sub1, @sub2);

    switch ($from)
    {
        case "mdvd" { @sub1 = from_mdvd(\@lines); }
        case "mpl2" { @sub1 = from_mpl2(\@lines); }
        case "srt" { @sub1 = from_srt(\@lines); }
    }

    switch ($to)
    {
        case "mdvd" { @sub2 = to_mdvd(\@sub1); }
        case "mpl2" { @sub2 = to_mpl2(\@sub1); }
        case "srt" { @sub2 = to_srt(\@sub1); }
    }

    # write everything to STDOUT
    write_raw_output(\@sub2);
    #debug_write(\@sub1);
}

# read the options
GetOptions ("help|h" => \$help,
            "f=f" => \$fps,
            "i=s" => \$from,
            "o=s" => \$to,
            ) or pod2usage(2);

# show help message if needed
pod2usage(1) if $help;

# run the script
main($from, $to);

__END__

=head1 NAME

sub2sub - Subtitle format converter.

=head1 DESCRIPTION

B<This program> will convert subtitle in given format to another. It also converts
control tags. Convertable formats are MicroDVD, SubRip (Srt) and Mpl2.

=head1 SYNOPSIS

sub2sub [-f fps] [-o output_format] [-i input_format] [-h] subfilename

=head1 OPTIONS

=over 4

=item B<-h>

Print a brief help message and exits.

=item B<-f>

Give an fps for frame-based subtitles. (Default is 23.976)

=item B<-i>

Input subtitle format.

=item B<-o>

Output subtitle format.

=back

=head1 AUTHOR

Jakub Mikołajczyk, kmikolaj@gmail.com

=head1 COPYRIGHT

Copyright (c) 2009 Jakub Mikołajczyk. All rights reserved. This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
