@echo off
cd /d "%~dp0"
echo ============================================
echo  PoseAI 体态评估后端启动脚本
echo ============================================
echo.

REM 检查 .env 文件
if not exist ".env" (
    echo [WARN] 未找到 .env 文件，正在从 .env.example 复制...
    copy .env.example .env >nul
    echo [INFO] 请编辑 .env 文件，填入 ZHIPU_API_KEY
    echo.
)

REM 检查虚拟环境
if not exist ".venv" (
    echo [INFO] 未找到虚拟环境，正在创建...
    python -m venv .venv
    echo [INFO] 安装依赖...
    .venv\Scripts\python.exe -m pip install -r requirements.txt
    echo.
)

REM 检查模型文件
if not exist "models\pose_landmarker_full.task" (
    echo [WARN] 未找到 MediaPipe 模型文件！
    echo [INFO] 请下载 pose_landmarker_full.task 到 models\ 目录
    echo.
)

echo [INFO] 启动 Flask 后端...
echo [INFO] 访问 http://localhost:5000
echo [INFO] HarmonyOS 模拟器地址：http://10.207.40.229:5000
echo.

.venv\Scripts\python.exe app.py

pause
