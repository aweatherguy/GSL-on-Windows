#!/bin/perl
# yeah, right...like Windoze knows what to do with THAT!
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
use strict;
use warnings;
use POSIX;


#=========================================================================

sub check_setup
{
    my @reqd = ( "source", "libgsl", "libgsl-dll", "tests" );
    my $rc = 0;

    foreach (@reqd)
    {
        my $dirname = $_;
        my $dir;
        if (! opendir( $dir, $dirname  ) )
        {
            print "\n\n***** Required directory \"$dirname\" does not exist\n";
            $rc = -1;
        }
        else
        {
            closedir( $dir );
        }
    }

    my $fp;
    if ( open( $fp, "source/test/gsl_test.h" ) )
    {
        close( $fp );
    }
    else
    {
        print "\n\n***** The file \"source/test/gsl_test.h\" is missing\n";
    }

    return $rc;
}

#=========================================================================

sub append_to_file #(filename, mustHavePattern, whatToAppend, logfile)
{
    my $srcfn = shift;
    my $musthave = shift;
    my $appendix = shift;
    my $log = shift;

    my $destfn = "$srcfn.tmp";
    my $fp;
    my $line;

    open($fp, $srcfn);

    if (!$fp)
    {
        printf "Error: Cannot open $srcfn\n";
        return -1;
    }    

    my @lines = <$fp>;
    close($fp);
    
    my $nlines = @lines;

    if (! $nlines) { return 0; }

    my $alreadyHasIt = 0;

    foreach (@lines)
    {
        if (/$musthave/)
        {
            $alreadyHasIt = 1;
            last;
        }
    }

    if ($alreadyHasIt) 
    {
        print $log "      $srcfn has already been modified.\n";
        return 0; 
    }

    open($fp, ">", $destfn);

    if (! $fp)
    {
        print "Error: cannot open $destfn to append fix.\n";
        return -1;
    }
    
    binmode $fp;
    print $fp @lines;

    binmode $fp;
    print $fp $appendix;
    close($fp);

    my @cmd = ( "copy", "/b", "/y", $destfn, $srcfn, ">>append.log", "2>&1" );
    my $status = system(@cmd);

    unlink($destfn);

    if ($status)
    {
        print $log "Could not overwrite $srcfn with temporary file $destfn\n";
        return -1;
    }

    print $log "====> Appended text successfully to $srcfn\n";

    return 0;
}

#=========================================================================

sub make_guid
{
    # a guid contains 128 bits, broken up like this for display:
    # the bit count sequence for hex digits is: 32, 16, 16, 16, 48,
    # the most we can get from rand() is 16 bits so we break this 
    # up accordingly, with the last 48 bits being 16-16-16

    my @g;
    my $k;
    for ($k = 0; $k < 8; $k++) 
    { 
        $g[$k] = int(rand(65535)); 
    }

    my $fmt = "{%04X%04X-%04X-%04X-%04X-%04X%04X%04X}";

    my $guid = sprintf($fmt, @g);

    return $guid;
}

#=========================================================================

sub process_template # ( templatename, triggerstring, outfile, logfile, prefix, suffix, names )
{
    my $templatename = shift;
    my $trigger = shift;
    my $projfile = shift;
    my $logfile = shift;
    my $prefix = shift;
    my $suffix = shift;
    my $namelist = shift;
    
    my @names = split(/:/, $namelist);
    my $cnt = @names;

    if ($cnt < 1) { return -1; }

    my $tfile;
    if (! open($tfile, $templatename))
    {
        print $logfile "**** Can't open $templatename\n";
        return -1;
    }

    my $vcxfile;
    if (! open($vcxfile, ">$projfile"))
    {
        print $logfile "**** Can't open $projfile for output\n";
        return -1;
    }

    my $found = 0;
    my $line;

    while ($line = <$tfile>)
    {
        if ($line =~ /$trigger/)
        {
            $found++;

            if ($cnt)
            {
                foreach (@names)
                {
                    if (/\w/) # don't output unless there is at least one non-space char 
                    {
                        print $vcxfile "$prefix$_$suffix";
                    }
                }
            }
        }
        else
        {
            print $vcxfile $line;
        }
    }

    close($tfile);
    close($vcxfile);

    my $rc = 0;

    if ($found)
    {
        print $logfile "     Expanded $found lists in $projfile.\n";
    }
    else
    {
        print $logfile "\n**** Trigger not found in libgsl-vcxproj-template.txt\n";
        $rc = -1;
    }

    print $logfile "===> $projfile created\n";
    
    return $rc;
}

#=========================================================================

sub get_automake_target
{
    my $filename = shift;
    my $tgt = shift;
    my $logfile = shift;

    my $amfile;

    if (! open($amfile, $filename))
    {
        print $logfile "**** Can't open automake file: $filename\n";
        return "";
    }
    
    my $line;

    my @values;
    my $nvalues = 0;

    while (($line = <$amfile>))
    {
        $line =~ s/^ *//;
        $line =~ s/ *$//;
        
        if ($line =~ /^#/)
        {
            next;
        }

        if ($line =~ /$tgt/)
        {
            my @flds = split(/=/, $line);
            my $nflds = @flds;

            if ($nflds == 2) 
            {                 
                my $tgtlist = $flds[1];
                $tgtlist =~ s/^ *//;
                $tgtlist =~ s/ *$//;
                @values = split (/\s\s*/, $tgtlist);
                $nvalues=@values;
                last;
            }
        }
    }

    close($amfile);

    if ($nvalues > 0)
    {
        return join(':', @values);
    }
    else
    {
        return "";
    }
}

#=========================================================================
#
sub create_vcxproj #(templatefn, targetpattern, srcdir, projfn, logfile)
{
    my $templatename = shift;
    my $targetpattern = shift;
    my $srcdir = shift;
    my $projfile = shift;
    my $logfile = shift;
    my $rc = 0;
    my $amfile;

    my $srclist = get_automake_target("Makefile.am", $targetpattern, $logfile);

    if (length($srclist) < 1) 
    { 
        print $logfile "**** Can't find $targetpattern target in Makefile.am\n";
        return -1; 
    }

    # remove .h files from the list
    if (! ($srclist =~ /:$/) ) { $srclist = "$srclist:"; }
    if (! ($srclist =~ /^:/) ) { $srclist = ":$srclist"; }
    
    while ($srclist =~ /\.h:/)
    {
        $srclist =~ s/:\w+\.h:/:/g;
    }
    $srclist =~ s/:+$//;
    $srclist =~ s/^:+//;
    
    my $trigger = "000ClCompileList000";
    my $prefix = "    <ClCompile Include=\"$srcdir";
    my $suffix = "\" />\n";

    # process_template( templatename, triggerstring, outfile, logfile, prefix, suffix, names )

    $rc = process_template(
        $templatename, $trigger, $projfile, $logfile, 
        $prefix, $suffix, $srclist );

    return $rc;
}

#=========================================================================
#
sub copy_headers #(destdir, logfile)
{
    my $destdir = shift;
    my $logfile = shift;

    my $tmp = get_automake_target("Makefile.am", 'pkginclude_HEADERS', $logfile);
    
    if (length($tmp) < 1) 
    { 
        print $logfile "**** Can't find pkginclude_HEADERS target in Makefile.am\n";
        return -1; 
    }
    
    my @hdrs = split(/:/, $tmp);
    my $nhdrs = @hdrs;
    
    if ($nhdrs < 1)
    {
        print $logfile "====> Found no header files to copy\n";
        return -1;
    }

    my $failures = 0;
    my $copied = 0;

    foreach (@hdrs)
    {
        my @cmd = ("copy", "/b", "/y", $_, $destdir, ">>..\\copy.log", "2>&1");
        my $rc = system(@cmd);
        if ($rc) 
        { 
            $failures++; 
        }
        else
        {
            $copied++;
        }
    }
    
    print $logfile "====> Copied $copied header files\n";
    
    if ($failures)
    {
        print $logfile "***** $failures copy attempts failed\n";
        return -1;
    }

    return 0;
}

#=================================================================================

sub create_library_vcxproj
{
    my $templatename = shift;
    my $liblist = shift;
    my $projfile = shift;
    my $logfile = shift;
    
    my $status = process_template(
        $templatename, "000LibFileList000", $projfile, $logfile, 
        "        ", ".lib;\n", $liblist);

    return $status;
}

#=================================================================================

sub create_sln
{
    my $filename = shift;
    my $projList = shift;
    my $testList = shift;

    my @projs = split(/:/, $projList);
    my @tests = split(/:/, $testList);
    my $nproj = @projs;
    my @pguids;
    my @tguids;

    my $libguid = make_guid();
    my $dllguid = make_guid();

    my $k;
    my $j;
    
    # create a separate GUID for each project, and for each test project

    for ($k=0; $k<$nproj; $k++) 
    {
        $pguids[$k] = make_guid();
        $tguids[$k] = make_guid();
    }

    my $projHdr = "Project(\"{8BC9CEB8-8B4A-11D0-8D11-00A0C91BC942}\") = ";

    my $fp;
    open($fp, ">", $filename);
    #
    # there are three "special" bytes at the start of a VS2010 solution file,
    # followed by a new line sequence (CR/LF).
    #
    printf $fp "\xef\xbb\xbf\n";

    print $fp "Microsoft Visual Studio Solution File, Format Version 11.00\n# Visual Studio 2010\n";

    # create the library sub-projects

    for ($k=0; $k<$nproj; $k++)
    {
        my $p = $projs[$k];
        next if ($p =~ /parent/);

        my $pdir = "\"source\\$p\\$p.vcxproj\"";
        print $fp "$projHdr\"$p\", $pdir, \"$pguids[$k]\"\nEndProject\n";
    }

    # create the static library project

    print $fp "$projHdr\"libgsl\", \"libgsl\\libgsl.vcxproj\", \"$libguid\"\n";    
    print $fp "\tProjectSection(ProjectDependencies) = postProject\n";
    # print $fp "\t\t$libguid = $libguid\n";

    for ($k=0; $k<$nproj; $k++)
    {
        next if ($projs[$k] =~ /parent/);

        my $g = $pguids[$k];
        printf $fp "\t\t$g = $g\n";
    }

    print $fp "\tEndProjectSection\n";
    print $fp "EndProject\n";
    
    # create the DLL project

    print $fp "$projHdr\"libgsl-dll\", \"libgsl-dll\\libgsl-dll.vcxproj\", \"$dllguid\"\n";    
    print $fp "\tProjectSection(ProjectDependencies) = postProject\n";
    print $fp "\t\t$libguid = $libguid\n";
    print $fp "\tEndProjectSection\n";
    print $fp "EndProject\n";

    # create the test projects
    
    for ($k=0; $k<$nproj; $k++)
    {
        next if ($projs[$k] =~ /parent/);

        if ($tests[$k])
        {
            my $g = $tguids[$k];
            my $p = "test-$projs[$k]";
            my $pdir = "\"tests\\$p\\$p.vcxproj\"";
            print $fp "$projHdr\"$p\", $pdir, \"$g\"\n";
            print $fp "\tProjectSection(ProjectDependencies) = postProject\n";
          # print $fp "\t\t$g = $g\n";
            print $fp "\t\t$libguid = $libguid\n";
            print $fp "\t\t$dllguid = $dllguid\n";
            print $fp "\tEndProjectSection\n";
            print $fp "EndProject\n";
        }
        else
        {
            # print "      Skipping test for $projs[$k]\n";
        }
    }

    # create the global section with platforms and configurations for each project

    print $fp "Global\n";
    print $fp "\tGlobalSection(SolutionConfigurationPlatforms) = preSolution\n";
    print $fp "\t\tDebug|Win32 = Debug|Win32\n";
	print $fp "\t\tDebug|x64 = Debug|x64\n";
	print $fp "\t\tRelease|Win32 = Release|Win32\n";
	print $fp "\t\tRelease|x64 = Release|x64\n";
    print $fp "\tEndGlobalSection\n";

    print $fp "\tGlobalSection(ProjectConfigurationPlatforms) = postSolution\n";

    my @configs = ( ".Debug|Win32.ActiveCfg   = Debug|Win32\n",
                    ".Debug|Win32.Build.0     = Debug|Win32\n",
                    ".Debug|x64.ActiveCfg     = Debug|x64\n",
                    ".Debug|x64.Build.0       = Debug|x64\n",
                    ".Release|Win32.ActiveCfg = Release|Win32\n",
                    ".Release|Win32.Build.0   = Release|Win32\n",
                    ".Release|x64.ActiveCfg   = Release|x64\n",
                    ".Release|x64.Build.0     = Release|x64\n"
    );
    my $nconfig = @configs;

    for ($j=0; $j<$nproj; $j++)
    {
        for ($k=0; $k<$nconfig; $k++)
        {
            printf $fp "\t\t$pguids[$j]$configs[$k]";
        }
    }

    for ($k=0; $k<$nconfig; $k++)
    {
        print $fp "\t\t$libguid$configs[$k]";
    }

    for ($k=0; $k<$nconfig; $k++)
    {
        print $fp "\t\t$dllguid$configs[$k]";
    }
    
    for ($j=0; $j<$nproj; $j++)
    {
        next if ($projs[$j] =~ /parent/);

        if ($tests[$j])
        {
            for ($k=0; $k<$nconfig; $k++)
            {
                printf $fp "\t\t$tguids[$j]$configs[$k]";
            }
        }
        else
        {
            # printf "Skipping configs for test-$projs[$j]\n";
        }
    }

    print $fp "\tEndGlobalSection\n";
    
    print $fp "\tGlobalSection(SolutionProperties) = preSolution\n";
    print $fp "\t\tHideSolutionNode = FALSE\n";
    print $fp "\tEndGlobalSection\n";
    print $fp "EndGlobal\n";

    close($fp);

    print "Created $filename\n";
}

#=================================================================================

sub usage
{
    print <<EOM;

Usage:  perl 1-create-vs-sln.pl [ -static | -dll | -h ]

        This perl script will create a working VS 2010 solution from which the GSL
        library can be built. Both static and dynamic (DLL) libraries are created.
        There are 32-bit (aka x86) and AMD 64-bit (x64) platforms to choose from and
        both Debug and Release builds are available.

        Be warned that some of the test programs in the Debug configuration will 
        spew out an extreme amount of data to the console.

        See the PDF manual that came with this package for more detailed information.

        -static Causes the test projects in the solution to be linked against
                the static library output of the build (libgsl.lib).

        -dll    Causes test projects to be linked against the DLL output (libgsl-dll.dll).

        -h      Displays this message.

EOM
    ;
}

#=================================================================================

if (check_setup()) { die "One or more required directories/files are missing; check your setup."; }

my $dir = 'source';

my $static_test_template = "test-vcxproj-static-template.txt";
my $dll_test_template = "test-vcxproj-dll-template.txt";
#
# This is where we choose whether to link the test programs against
# the static or dynamic library. The default is to link to DLL.
#
my $test_template = $dll_test_template;

if ($#ARGV > 0)
{
    print "\n====> Error: only one command line argument is allowed <====\n\n";
    usage();
    exit(1);
}

my $argok = 0;

if ($#ARGV < 0)
{
    print "\n===> No arguments were provided on the command line.\n";
    print   "     This script defaults to creating test projects which are linked\n";
    print   "     against the DLL instead of the static library.\n";
    print   "     To change this, re-run this script with the -static option.\n\n";
    $argok = 1;
}
else
{
    if ($ARGV[0] eq "-h")
    {
        usage();
        exit(0);
    }

    if ($ARGV[0] eq "-static")
    {
        print "\n===> Test projects will be linked against the static library.\n\n";
        $test_template = $static_test_template;
        $argok = 1;
    }
    if (! $argok && ($ARGV[0] eq "-dll"))
    {
        print "\n===> Test projects will be linked against the DLL.\n\n";
        $test_template = $dll_test_template;
        $argok = 1;
    }
}

if (!$argok)
{
    print "\n====> Error: invalid argument <====\n\n";
    usage();
    exit(1);
}

my $logfile;
open($logfile, ">vcxproj.log") or die "Cannot open vcxproj.log\n";

my $errcnt = 0;

my @projs;
my @tests;
my $nproj = 0;
my $ntest = 0;  # how many projects have tests?
my $dirfile;

opendir($dirfile, $dir) or die $!;

while (my $name= readdir($dirfile))
{
    if ($name =~ /\./) { next; }
    if ($name =~ /^gsl$/) { next; }
    if ($name =~ /^doc$/) { next; }
    if ($name =~ /^const$/) { next; }

    if (-d "$dir/$name")
    {
        $tests[$nproj] = 0;
        $projs[$nproj++] = $name;
    }
}

closedir($dirfile);

print "creating libgsl project...\n";

my $projlist = join(':', @projs);

if (create_library_vcxproj("libgsl-vcxproj-template.txt", $projlist, "libgsl/libgsl.vcxproj", $logfile))
{
    $errcnt++;
}

print "creating libgsl-dll project...\n";

if (create_library_vcxproj("libgsl-dll-vcxproj-template.txt", $projlist, "libgsl-dll/libgsl-dll.vcxproj", $logfile))
{
    $errcnt++;
}

chdir("source");
copy_headers("gsl", $logfile);
chdir("..");

print "processing $nproj projects...\n";

my $k;
my $status;

my $libpattern = 'lib.*_la_SOURCES';
my $testpattern = 'test_SOURCES';

for ($k=0; $k<$nproj; $k++)
{
    my $name = $projs[$k];

    mkdir( "tests/test-$name" );

    if (chdir("$dir/$name")) 
    {
        print "Processing $name...\n";
        print $logfile "Processing $name...\n";

        $status = create_vcxproj(
            "../../vcxproj-template.txt", 
            $libpattern, 
            "", 
            "$name.vcxproj", 
            $logfile);
        
        if ($status < 0) { $errcnt++; }

        $status = create_vcxproj(
            "../../$test_template",
            $testpattern,
            "..\\..\\source\\$name\\", 
            "../../tests/test-$name/test-$name.vcxproj", 
            $logfile);
        
        if ($status < 0) 
        { 
            $tests[$k] = 0;
            $errcnt++; 
        }
        else
        {
            $tests[$k] = 1;
            $ntest++;
        }

        $status = copy_headers("..\\gsl", $logfile);
        if ($status < 0) { $errcnt++; }

        chdir "../.." ;
        print $logfile "\n";
    }
}

printf "\nCreated $nproj library projects and $ntest test projects.\n\n";

my $cfile;

printf "Appending WIN32 macros to gsl_math.h and gsl_test.h...\n";

my $test_appendix = "\n\n#ifdef WIN32\n\t#pragma warning( disable : 4267 4244 4723 )\n\t#include <io.h>\n\n\t#ifdef X64\n\t\t#define PCTZ \"%ll\"\n\t#else\n\t\t#define PCTZ \"%l\"\n\t#endif\n#endif\n";
my $math_appendix = "\n\n#ifdef WIN32\n\t#pragma warning( disable : 4267 4244 4723 )\n\n\t#ifdef X64\n\t\t#define PCTZ \"%ll\"\n\t#else\n\t\t#define PCTZ \"%l\"\n\t#endif\n#endif\n";

chdir("source/gsl");
if (append_to_file("gsl_math.h", "WIN32", $math_appendix, $logfile)) { $errcnt++; }
if (append_to_file("gsl_test.h", "WIN32", $test_appendix, $logfile)) { $errcnt++; }
chdir("../..");

create_sln("gslnw.sln", join(':',@projs), join(':',@tests));

printf "\n";

my $batmobile;

if (open($batmobile, ">", "test-all.bat"))
{
    print $batmobile "\@echo off\necho Running all GSL test programs now...\necho.\n\n";

    for ($k=0; $k<$nproj; $k++)
    {
        my $name = $projs[$k];
        if ($tests[$k])
        {
            print $batmobile "echo Starting test-$name...\ntest-$name\necho.\n";            
        }
    }
    print $batmobile "\npause\n";

    close($batmobile);

    my @platforms = ( "Win32", "x64" );
    my @configs =   ( "Debug", "Release" );

    foreach(@platforms)
    {
        my $plat = $_;

        foreach(@configs)
        {
            my $config = $_;
            my $dest = "tests\\$plat\\$config\\test-all.bat";
            my @cmd = ( "copy", "/b", "/y", "test-all.bat", $dest, ">>copy.log", "2>&1" );
            $status = system(@cmd);
            if ($status) { $errcnt++; }
        }
    }
    print "Copied test-all.bat to tests executable directories.\n";
}
else
{
    $errcnt++;
    print "**** Could not create test-all.bat\n";
}

if ($errcnt)
{
    print "*** Some projects ($errcnt) reported errors. See vcxproj.log for details";
}
