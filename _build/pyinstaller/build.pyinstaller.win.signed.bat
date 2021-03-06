@echo off

setlocal

REM ......................setup variables......................
if [%1]==[] (
    goto :usage
) else (
    SET ARCH=%1
)

if [%2]==[] (
    goto :usage
) else (
    SET PASS=%2
)

if ["%ARCH%"]==["64"] (
    SET BINARCH=x64
    SET FFMPEG_URL=https://ffmpeg.zeranoe.com/builds/win64/shared/ffmpeg-latest-win64-shared.7z
    SET FFMPEG=ffmpeg-latest-win64-shared.7z
    SET MEDIAINFO_URL=https://mediaarea.net/download/binary/mediainfo/17.10/MediaInfo_CLI_17.10_Windows_x64.zip
    SET MEDIAINFO=MediaInfo_CLI_17.10_Windows_x64.zip
)
if ["%ARCH%"]==["32"] (
    SET BINARCH=x86
    SET FFMPEG_URL=https://ffmpeg.zeranoe.com/builds/win32/shared/ffmpeg-latest-win32-shared.zip
    SET FFMPEG=ffmpeg-latest-win32-shared.7z
    SET MEDIAINFO_URL=https://mediaarea.net/download/binary/mediainfo/17.10/MediaInfo_CLI_17.10_Windows_i386.zip
    SET MEDIAINFO=MediaInfo_CLI_17.10_Windows_i386.zip
)

REM ......................get latest version number......................
for /f "delims=" %%a in ('C:\Python36-%BINARCH%\python.exe version.py') do @set APPVER=%%a

REM ......................cleanup previous build scraps......................
rd /s /q build
rd /s /q dist
if not exist "..\..\bin\" mkdir ..\..\bin\
del /q ..\..\bin\*.*

REM ......................download latest FFmpeg & MediaInfo shared binary + libs ......................
if not exist ".\temp\" mkdir temp
if not exist "temp\ffmpeg-latest-win%ARCH%-shared.7z" ( call curl -k -L -fsS -o temp\%FFMPEG% "%FFMPEG_URL%" )
if not exist "temp\%MEDIAINFO%" ( call curl -k -L -fsS -o temp\%MEDIAINFO% "%MEDIAINFO_URL%" )

REM ......................extract files & move them to top-level binary folder ......................
cd temp\
7z x ffmpeg-latest-win%ARCH%-shared.7z ffmpeg-latest-win%ARCH%-shared\bin
del /q ffmpeg-latest-win%ARCH%-shared\bin\ffplay.exe
unzip %MEDIAINFO% MediaInfo.exe
move ffmpeg-latest-win%ARCH%-shared\bin\*.* ..\..\..\bin\
move MediaInfo.exe ..\..\..\bin\
cd ..

REM ......................run pyinstaller......................
C:\Python36-%BINARCH%\scripts\pyinstaller.exe --clean vidcutter.win%ARCH%.spec

if exist "dist\vidcutter.exe" (
    REM ......................add metadata to built Windows binary......................
    .\verpatch.exe dist\vidcutter.exe /va %APPVER%.0 /pv %APPVER%.0 /s desc "VidCutter" /s name "VidCutter" /s copyright "(c) 2017 Pete Alexandrou" /s product "VidCutter %BINARCH%" /s company "ozmartians.com"

    REM ................sign frozen EXE with self-assigned certificate..........
    "C:\Program Files (x86)\Windows Kits\10\bin\10.0.16299.0\%BINARCH%\signtool.exe" sign /f "%USERPROFILE%\Documents\pgpkey\code-sign.pfx" /t http://timestamp.comodoca.com/authenticode /p %PASS% dist\vidcutter.exe

    REM ......................call Inno Setup installer build script......................
    cd ..\InnoSetup
    REM ......................remove post strings from version number so that its M$ valid......................
    SET APPVER=%APPVER:.DEV=%.0
    call "C:\Program Files (x86)\Inno Setup 5\iscc.exe" ""/DAppVersion=%APPVER%"" /Ssigntool="""C:\Program Files (x86)\Windows Kits\10\bin\10.0.16299.0\%BINARCH%\signtool.exe"" sign /f ""%USERPROFILE%\Documents\pgpkey\code-sign.pfx"" /t http://timestamp.comodoca.com/authenticode /p %PASS% $f" installer_%BINARCH%.signed.iss

    cd ..\pyinstaller
)

goto :eof

:usage
    echo.
    echo Usage:
    echo. 
    echo   build.pyinstaller.win.signed [32 or 64] [pgp password]
    echo. 
    goto :eof

:eof
    endlocal
    exit /b
