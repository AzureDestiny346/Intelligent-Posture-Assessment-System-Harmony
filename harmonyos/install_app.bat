@echo off
"%~dp0..\..\..\..\..\IDE\devecostudio-windows-6.0.0.878\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe" install -r "%~dp0entry\build\default\outputs\default\entry-default-signed.hap"
echo RESULT=%ERRORLEVEL%
pause
