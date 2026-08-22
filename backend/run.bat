@echo off
cd /d "%~dp0"
echo 使用项目虚拟环境启动 Flask...
".venv\Scripts\python.exe" app.py
pause
