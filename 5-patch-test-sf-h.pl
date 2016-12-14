
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
chdir("source/specfunc");

my $fp;

if (!open($fp, "test_sf.h") )
{
    chdir("../..");
    print "Cannot open specfunc/test_sf.h";
    exit(1);
}

binmode $fp;
my @lines = <$fp>;
close($fp);

my $fixed = 1;

my $k;
my $nlines = @lines;

for ($k=0; $k<$nlines; $k++)
{
    my $str = $lines[$k];

    if ($str =~ /#if[[:space:]]+RELEASED[[:space:]]/)
    {
        $fixed = 0;
        $lines[$k] =~ s/#if[[:space:]]/#ifdef / ;
    }
}

if ($fixed) 
{
    printf "     specfunc/test_sf.h is okay.\n"; 
    chdir("../..");
    exit(0);
}

if (! open($fp, ">", "test_sf_h.txt") )
{
    print "Cannot open test_sf_h.txt for output";
    chdir("../..");
    exit(1);
}

binmode $fp;

foreach (@lines)
{
    print $fp $_;
}

close($fp);

my @cmd = ( "copy", "/b", "/y", "test_sf_h.txt", "test_sf.h" );

my $status = system(@cmd);

chdir("../..");

if ($status)
{
    print "Failed to copy test_sf_h.txt over test_sf.h\n";
    exit(1);
}
else
{
    print "test_sf.h has been sucessfully patched.\n";
    exit(0);
}

