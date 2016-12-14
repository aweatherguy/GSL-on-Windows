use strict;
use warnings;
use Cwd;
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
# there are a few symbol names that we would otherwise detect as needing to
# be exported, but they don't exist. I'm taking the easy way out here because
# tweaking the script to detect these generically is difficult. instead, we
# just key on the names and skip them. If future GSL releases enable these names
# or add more false detections, this list can be modified....but it should be
# done on a version-specific basis so the change does not break this tool when
# processing older versions of GSL source.
#
sub badfuncname
{
    my $name = shift;
    my $ver = shift;

    $name =~ s/^[[:space:]][[:space:]]*//;
    $name =~  s/[[:space:]][[:space]]*$//;
    $name =~ s/\s+DATA.*$//;
    #
    # this one is only bad in versions prior to 2.3
    #
    my $bad_in_2p2 = "gsl_multilarge_nlinear_trs_subspace2D";

    my @bad = ( 
        "int",
        "gsl_bspline_deriv_free", "gsl_bspline_deriv_alloc", "gsl_multifit_fdfsolver_dif_fdf",
        "gsl_multilarge_nlinear_df",  "gsl_multilarge_nlinear_fdfvv",
        "gsl_sf_legendre_array_size", "gsl_sf_legendre_Plm_array", "gsl_sf_legendre_Plm_deriv_array",
        "gsl_sf_legendre_sphPlm_array", "gsl_sf_legendre_sphPlm_deriv_array"
    );

    foreach (@bad)
    {
        if ( ($name eq $_) || ($name =~ /$_[[:space:]]/) )
        {
            return 1;
        }
    }

    if ($ver =~ /^2\.2/)
    {
        if ( ($name eq $bad_in_2p2) || ($name =~ /$bad_in_2p2[[:space:]]/) )
        {
            return 1;
        }
    }

    return 0;
}

#==============================================================================

sub isfunc
{
    my $line = shift;
    my $func = shift;
    my $okay;

    $okay = $line =~ /[ \*]$func\_.*\(/ ;
    if (! $okay) 
    {
        $okay = $line =~ /^$func\_.*\(/ ;
    }
    if (! $okay) { return ""; }
    
    $line =~ s/ \(/\(/;
    $line =~ s/\(.*$//;
    $line =~ s/^.*$func\_/$func\_/;
    
    return $line;
}

#==============================================================================

sub isgslvar
{
    my $line = shift;
    my $okay;

    $line =~ s/^[[:space:]][[:space:]]*//;

    $okay = $line =~ /^GSL_VAR[[:space:]]/;
    if (! $okay) { return ""; }

    $okay = $line =~ /[[:space:]]gsl_/;
    if (! $okay) { return ""; }

    $line =~ s/^.*gsl_/gsl_/;
    $line =~ s/[[:space:];].*$//;

    # some declarations may end with [] if it is an array. 
    # remove that too
    $line =~ s/\[\]$//;

    return $line;
}

#==============================================================================

sub find_exports  # (filename, comment, expfile)
{
    my $filename = shift;
    my $comment = shift;
    my $expfile = shift;    
    my $gslver = shift;

    my $hdrfile;

    if (!open( $hdrfile, $filename))
    {
        my $here = cwd();
        print "Cannot open header file $filename from $here\n";
        return -1;
    }

    my $line;
    my $skip = 0;
    my $other = 0;
    my $struct = 0;
    my $inline = 0;
    my $incomment = 0;

    my @exports;
    my $nexports = 0;
    my $nvars = 0;

    while ($line = <$hdrfile>)
    {
        chomp( $line );
        
        # skip the /* ... */ style of comment if it is multi-line
        
        if ($incomment)
        {
            if ($line =~ /\*\//)
            {
                $incomment = 0;
            }
            next;
        }
        else
        {
            if ( ($line =~ /\/\*/) && ! ($line =~ /\*\//) )
            {
                $incomment = 1;
                next;
            }
        }

        #trim comments from end of line
        $line =~ s/\/\*.*$//;
        $line =~ s/\/\/.*$//;

        if ($line =~ /#ifdef  *HAVE_INLINE/)
        {
            $skip++;
        }
        if ($line =~ /#else/)
        {
            if ($skip) { $skip--; }
            $other = 1;
        }
        if ($line =~ /#endif/)
        {
            if (! $other)
            {
                if ($skip) { $skip--; }
            }
            $other = 0;
        }

        next if ($skip);

        my $blank = $line;
        $blank =~ s/[[:space:]]*//g;

        if ($blank eq "")
        {
            $inline = 0;
        }
        else
        {
            if (! $inline && ($line =~ /INLINE_DECL/))
            {
                $inline = 1;
            }
            if (! $inline && ($line =~ /INLINE_FUN/))
            {
                $inline = 1;
            }
        }

        next if ($inline);

        if ($struct)
        {
            if ( $line =~ /}/ )
            {
                if ($struct > 0) 
                {
                    $struct--;
                }
            }
        }
        else
        {
            if ( $line =~ /typedef struct/ )
            {
                # if all on one line it's not to worry...
                if ( ! ($line =~ /}/) && ! ($line =~ /;/) )
                {
                    $struct++;
                }
            }
        }
    
        next if ($struct);        
        next if ( $line =~ /#define/ );
        next if ( $line =~ /typedef/ );
        next if ( $line =~ / return / );
        

        my $fix = isfunc($line, "gsl");

        if ($fix eq "")
        {
            $fix = isfunc($line, "blas");
        }
        if ($fix eq "")
        {
            $fix = isfunc($line, "cblas");
        }        
        if ($fix eq "")
        {
            $fix = isgslvar($line);
            if ($fix ne "") 
            { 
                $nvars++; 
                $fix = "$fix    DATA";
            }
        }

        if ($fix ne "")
        {
            if (! badfuncname($fix, $gslver))
            {
                $exports[$nexports++] = $fix;
            }
        }
    }
    
    close( $hdrfile );

    if ($nexports == 0) { return 0; }
    
    print $expfile ";========> $comment <========\n";

    my $prev = "nobody-better-use-this-name";
    $nexports = 0;
    
    @exports = sort(@exports);
    
    foreach (@exports)
    {
        my $exp = $_;
        next if ( $exp eq $prev );
        $prev = $exp;
    
        $nexports++;
        print $expfile  "    $exp\n";
    }

    return $nexports;
}

#=================================================================================

sub usage
{
    print <<EOM;

Usage:  perl 2-create-def.pl version

        This perl script will create the def file listing DLL export symbols
        required to build the DLL version of the GSL library.

        The GSL version is a required argument. This is due to the fact that
        versions 2.2 and 2.2.1 have a problem wherein an exported global variable
        is listed in gsl_multilarge_nlinear.h which does not actually exist. 
        This causes the build tool to add the symbol for export and then the link
        fails because the symbol is not defined. This problem does not exits in
        versions prior to 2.2 and is fixed in version 2.3.

EOM
    ;
}

#==============================================================================

if ($#ARGV != 0)
{
    print "\n====> Error: exactly one command line argument is required <====\n\n";
    usage();
    exit(1);
}

my $gslver = $ARGV[0];

my $dir = "source/gsl";

my $errcnt = 0;

my @projs;
my $nproj = 0;
my $n;
my $total = 0;
my $deffile;
my $dirfile;

opendir($ dirfile, $dir ) or die $!;

open( $deffile, ">", "libgsl-dll/libgsl-dll.def" ) or die "Cannot open def file for output";

print $deffile "\n; === This file autogenerated by build-def-file.pl ===\n\n";
print $deffile "\nLIBRARY libgsl-dll\n\nEXPORTS\n";

while (my $name= readdir( $dirfile ))
{
    chomp( $name );
    my $hdrfn = "$dir/$name";

    next unless ( $name =~ '[a-z][a-z0-9_]*\.h$' );
    if (! -f "$hdrfn" )
    {
        print "====> File $hdrfn not found. <====\n";
        next;
    }
    # next unless ( -f "$hdrfn" );
    next if ( $name =~ /gsl_inline/ );

    print "Processing $name...\n";

    my $fn = "$hdrfn";
    $n = find_exports( $fn, $name, $deffile, $gslver );
    if ($n > 0)
    {
        $total += $n;
    }
}

closedir( $dirfile );

close( $deffile );

print "\nExported $total functions.\n\n";
