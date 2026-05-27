@echo off
setlocal EnableExtensions

set "REPO_ROOT=%~dp0.."
set "TOOLCHAIN_ROOT=C:\Users\Public\GuideRunToolchains"
set "FLUTTER_ROOT=%TOOLCHAIN_ROOT%\flutter"
set "ANDROID_HOME=%TOOLCHAIN_ROOT%\android-sdk"
set "ANDROID_SDK_ROOT=%ANDROID_HOME%"
set "PUB_CACHE=%TOOLCHAIN_ROOT%\pub-cache"
set "CARGO_HOME=%TOOLCHAIN_ROOT%\cargo"
set "RUSTUP_HOME=%TOOLCHAIN_ROOT%\rustup"
set "PATH=%FLUTTER_ROOT%\bin;%ANDROID_HOME%\cmdline-tools\latest\bin;%ANDROID_HOME%\platform-tools;%CARGO_HOME%\bin;%PATH%"
set "MAPPED_DRIVE="

if /I "%~1"=="build" (
    if /I "%~2"=="apk" goto :realpath
    if /I "%~2"=="appbundle" goto :realpath
    if /I "%~2"=="aar" goto :realpath
)

for %%D in (G H I J K L M N O P Q R S T U V W X Y Z) do (
    if not exist %%D:\ (
        subst %%D: "%REPO_ROOT%" >nul 2>nul
        if not errorlevel 1 (
            set "MAPPED_DRIVE=%%D:"
            goto :mapped
        )
    )
)

echo No free drive letter was available for Flutter path normalization.
exit /b 1

:mapped
pushd "%MAPPED_DRIVE%\apps\mobile"
if "%~1"=="" (
    call flutter analyze --no-pub
) else (
    call flutter %*
)
set "EXIT_CODE=%ERRORLEVEL%"
popd
subst %MAPPED_DRIVE% /D >nul 2>nul
exit /b %EXIT_CODE%

:realpath
pushd "%REPO_ROOT%\apps\mobile"
call flutter %*
set "EXIT_CODE=%ERRORLEVEL%"
popd
exit /b %EXIT_CODE%
