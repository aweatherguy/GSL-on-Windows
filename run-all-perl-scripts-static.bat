@echo off

REM
REM for this to work:
REM - perl must be installed
REM - the executable must be named "perl"
REM - "perl" executable's directory must be in the PATH env variable
REM

echo.
set /p ver=Enter GSL version: 
echo.

perl 1-create-vs-sln.pl -static

perl 2-create-def.pl %ver%

perl 3-patch-fp-c.pl

perl 4-patch-percent-z.pl

perl 5-patch-test-sf-h.pl

pause
