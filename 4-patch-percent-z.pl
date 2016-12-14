
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
sub search_file #(filename) # returns 1 if file contains %z, zero otherwise
{
    my $fn = shift;
    my $fp;

    if (! open($fp, $fn)) { return 0; }
    my @lines = <$fp>;
    close($fp);
    
    my $rc = 0;
    
    foreach (@lines)
    {
        if (/%z/)
        {
            $rc++;
            last;
        }
    }

    return $rc;
}

#==============================================================================
#
# returns  -1 on failure, otherwise the number of lines edited in the file.
#
sub fix_file #(filename, format_replacement, logfile)
{
    my $fn = shift;
    my $fmt = shift;    # s/b either "l" or "ll"
    my $log = shift;
    my $tmp = "$fn.txt";
    my $fp;

    if (! open($fp, $fn)) 
    {
        print $log "Cannot open file for input processing: $fn\n";
        return -1;
    }
    
    my @lines = <$fp>;
    close($fp);
    
    my $cnt = 0;
    
    if (! open($fp, ">", $tmp)) 
    {
        print $log "Cannot open temporary file for output processing: $tmp\n";
        return -1;
    }

    binmode $fp;

    foreach (@lines)
    {
        if (/%z/)
        {
            $cnt++;
            # first, replace those occurances which are bounded on both side by quotes
            s/"%z"/$fmt/g;
            # next, those bounded on the left by a quote
            s/"%z/$fmt"/g;
            # now on the right side...
            s/%z"/"$fmt/g;
            # finally, those not bounded by any quotes
            s/%z/"$fmt"/g;
        }
        print $fp $_;
    }
    close($fp);
    
    my @cmd = ("copy", "/b", "/y", $tmp, $fn, ">>..\\fix-percent-zees.log", "2>&1");

    my $rc = 0;
    
    $rc = system(@cmd);

    if ($rc)
    {
        print $log "Could not copy temporary file $tmp back to orignal $fn\n";
        return -1;
    }
    else
    {
        print $log "Modified $cnt lines containing %z in file: $fn\n";
    }

    unlink($tmp);

    return $cnt;
}

my $fixed = 0;
my $errs = 0;
my $files = 0;

my $logfile;
my $logfn = "fix-percent-z.log";

open($logfile, ">", $logfn) or die "Cannot open $logfn\n";

chdir("source");

my $srcdir;
my $projdir;
my $pname;
my $cname;

opendir($srcdir, ".") or die $!;

while ($pname = readdir($srcdir))
{
    if ($pname =~ /\./) { next; }
    if ($pname =~ /^gsl$/) { next; }
    if ($pname =~ /^doc$/) { next; }
    if ($pname =~ /^const$/) { next; }

    if (-d "$pname")
    {
        # print "Searching $pname...\n";

        chdir($pname);
        
        if (opendir($projdir, "."))
        {
            print "Scanning directory $pname...\n";
            print $logfile "Scanning directory $pname...\n";

            while ($cname = readdir($projdir))
            {
                # only .c files are known to have the problem...

                next if (! ($cname =~ /\.c$/)); 
                
                $files++;

                if (search_file($cname))
                {
                    if (fix_file($cname, "PCTZ", $logfile))
                    {
                        $fixed++;
                    }
                    else
                    {
                        $errs++;
                    }
                }
            }
            closedir($projdir);
        }

        chdir("..");
    }
}

closedir($srcdir);

chdir("..");

print "Searched $files files, modified $fixed, $errs errors occurred\n";
print "See $logfn for details.\n";
