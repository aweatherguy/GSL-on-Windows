
use strict;
use warnings;

#
# Copyright 2016, aweatherguy (email: wsdl at osengr.org)
#
#==========================================================================
#This file is part of GSL on Windows
#
#    GSL on Windows is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 2 of the License, or
#    (at your option) any later version.
#
#    Foobar is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with GSL on Windows.  If not, see <http://www.gnu.org/licenses/>.
#============================================================================
#
chdir("source/ieee-utils");

my $fp;
my $fn = "fp.c";
my $tmpfn = "fp-c.txt";
my $winmacro = "HAVE_WINX64_IEEE_INTERFACE";
my $anymacro = "#elif[[:space:]]+HAVE_[A-Z0-9]+_IEEE_INTERFACE";

if (!open($fp, $fn) )
{
    chdir("../..");
    print "Cannot open $fn";
    exit(1);
}

binmode $fp;
my @lines = <$fp>;
close($fp);

my $fixed = 0;

my $k;
my $nlines = @lines;

foreach (@lines)
{
    if (/$winmacro/)
    {
        $fixed = 1;
        last;
    }
}

if ($fixed) 
{
    printf "     $fn is okay.\n"; 
    chdir("../..");
    exit(0);
}

if (! open($fp, ">", $tmpfn) )
{
    print "Cannot open $tmpfn for output";
    chdir("../..");
    exit(1);
}

binmode $fp;

foreach (@lines)
{
    if (! $fixed)
    {
        if (/$anymacro/)
        {
            print $fp "#elif $winmacro\n#include \"fp-winx64.c\"\n";
            $fixed = 1;
        }
    }
    print $fp $_;
}

close($fp);

if (! $fixed)
{
    unlink($tmpfn);
    print "**** Could not find place to insert macro in fp.c\n";
    exit(1);
}


my @cmd = ( "copy", "/b", "/y", $tmpfn, $fn );

my $status = system(@cmd);

unlink($tmpfn);

chdir("../..");

if ($status)
{
    print "Failed to overwrite $fn with $tmpfn\n";
    exit(1);
}
else
{
    print "$fn has been sucessfully patched.\n";
    exit(0);
}

