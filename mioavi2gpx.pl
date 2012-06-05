#!/usr/bin/perl

#$Id$

use 5.010;
use strict;
use warnings;
use utf8;
use autodie;

use POSIX;
use Geo::Gpx;
use File::Slurp;


my $file = $ARGV[0];
die 'need filename'  if !length $file;

my @tpoints;
_parse_file($file);

my $gpx = Geo::Gpx->new();
$gpx->tracks([ { name => $file, segments => [ { points => \@tpoints } ] } ]);
write_file "$file.gpx", $gpx->xml();



sub _parse_file
{
    my ($file) = @_;

    open my $fh, '<', $file;
    binmode $fh;

    my $fourcc = _read_fourcc($fh);
    die if $fourcc ne 'RIFF';

    my $size = _read_size($fh);
    my $type = _read_fourcc($fh);

#    say STDERR "$fourcc ($type, $size)";
    _parse_list($fh, $size, 1);

    close $fh;
    return;
}


sub _parse_list
{
    my ($fh, $csize, $level) = @_;
    my $start = tell $fh;

    my $pos = $start;
    while ($pos < $start + $csize - 8) {
        seek $fh, $pos, 0;
#        printf STDERR '%08X: ', $pos;
        my $fourcc = _read_fourcc($fh);
        if ( $fourcc ~~ [qw/ LIST idx1 01wb avih strh strf 00dc /] ) {
            my $size = _read_size($fh);
            if ( $fourcc ~~ [qw/ LIST /] ) {
                my $type = _read_fourcc($fh);
#                say STDERR q{ }x$level . "$fourcc ($type, $size)";
                if ( $type ne 'JUNK' ) {
                    _parse_list($fh, $size, $level+1 );
                }
            }
            else {
#                say STDERR q{ }x$level . "$fourcc ($size)";
            }
            
            $pos += (8 + $size);
            next;
        }
        elsif ( $fourcc eq 'GPS ' ) {
            my $cnt = _read_size($fh);
            my $size = _read_size($fh);
            read $fh, (my $data), $size;

#            my $hex = join q{ }, map { sprintf "%02X", $_ } unpack 'C*', $data;
#            say STDERR q{ }x$level . "$fourcc: ($hcnt) $hex";

#            printf "%08X: $hex\n", $pos;
            if ($data) {
                my @data = my ($y, $m, $d, $hh, $mm, $ss, $lat, $lon, $ele) = unpack '@4 SCCCCSLLL', $data;
#                say "@data";
                push @tpoints, {
                    lat => $lat / 1000000,
                    lon => $lon / 1000000,
                    ele => $ele / 10,
                    time => POSIX::mktime($ss/1000, $mm, $hh, $d, $m-1, $y-1900) + 4*60*60,
                };
            }


            $pos += 12 + $size;
            next;
        }
#        say STDERR q{ }x$level . "$fourcc";
        last;
    }
}




sub _read_fourcc
{
    my ($fh) = @_;
    read $fh, my $fourcc, 4;
    return $fourcc;
}

sub _read_size
{
    my ($fh) = @_;
    read $fh, my $size_dump, 4;
    return unpack 'V', $size_dump;
}




