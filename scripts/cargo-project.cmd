@echo off
setlocal EnableExtensions

set "REPO_ROOT=%~dp0.."
set "TOOLCHAIN_ROOT=C:\Users\Public\GuideRunToolchains"
set "CARGO_HOME=%TOOLCHAIN_ROOT%\cargo"
set "RUSTUP_HOME=%TOOLCHAIN_ROOT%\rustup"
set "PATH=%CARGO_HOME%\bin;%PATH%"
set "MAPPED_DRIVE="

for %%D in (G H I J K L M N O P Q R S T U V W X Y Z) do (
    if not exist %%D:\ (
        subst %%D: "%REPO_ROOT%" >nul 2>nul
        if not errorlevel 1 (
            set "MAPPED_DRIVE=%%D:"
            goto :mapped
        )
    )
)

echo No free drive letter was available for Cargo path normalization.
exit /b 1

:mapped
pushd "%MAPPED_DRIVE%\"
if "%~1"=="" (
    call cargo check
) else (
    call cargo %*
)
set "EXIT_CODE=%ERRORLEVEL%"
popd
subst %MAPPED_DRIVE% /D >nul 2>nul
exit /b %EXIT_CODE%
