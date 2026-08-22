@echo off
echo 正在启动 Cloudflare Tunnel，请保持此窗口不要关闭...
echo 公网链接会在下方显示（https://xxx.trycloudflare.com）
echo.
"%~dp0tools\cloudflared.exe" tunnel --url http://localhost:5000
pause
