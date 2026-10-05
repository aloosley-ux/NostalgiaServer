@echo off
setlocal
call "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64
if errorlevel 1 exit /b %errorlevel%
set "VCPKG_ROOT=C:\AI\vcpkg"
set "VCPKG_MAX_CONCURRENCY=8"
set "VCPKG_BINARY_SOURCES=clear;files,C:\AI\opentibia-build-cache\binaries,readwrite"
set "VCPKG_DOWNLOADS=C:\AI\vcpkg\downloads"
set "PATH=C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja;%PATH%"
cd /d "%~dp0"
cmake --preset windows-release -DOPTIONS_ENABLE_SCCACHE=OFF -DOPTIONS_ENABLE_CCACHE=OFF -DCANARY_USE_SHARED_VCPKG_INSTALLED=OFF
if errorlevel 1 exit /b %errorlevel%
cmake --build --preset windows-release --target canary --parallel 8
exit /b %errorlevel%
