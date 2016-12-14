@echo off


7z a GSL-Build-Tools.7z . -xr!.svn -x!make7z.bat -x!*.7z -x!c.c -x!README.txt -mx=9

7z a GSL-on-Windows.7z GSL-Build-Tools.7z README.txt -mx=1

del GSL-Build-Tools.7z

pause
