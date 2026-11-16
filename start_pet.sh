#!/usr/bin/env bash
# ==============================================================================
# 愛蜜莉雅 (Emilia) Live2D 桌寵 一鍵啟動腳本
# ==============================================================================

BASE_DIR="/home/siewilly/Live2D_pet"
BACKEND_DIR="${BASE_DIR}/Open-LLM-VTuber"
FRONTEND_DIR="${BASE_DIR}/Open-LLM-VTuber-Web"

# 自動偵測並設定桌面顯示環境變數
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
if [ -z "$XAUTHORITY" ]; then
    AUTH_FILE=$(ls -t /run/user/1000/.mutter-Xwaylandauth* /run/user/1000/gdm/Xauthority ~/.Xauthority 2>/dev/null | head -n 1)
    if [ -n "$AUTH_FILE" ]; then
        export XAUTHORITY="$AUTH_FILE"
    fi
fi
export ELECTRON_DISABLE_SANDBOX=1

# 確保日誌目錄存在
mkdir -p "${BACKEND_DIR}/logs"
mkdir -p "${FRONTEND_DIR}/logs"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 正在檢查愛蜜莉雅 Live2D 桌寵運行狀態..."

# 1. 檢查後端 (Open-LLM-VTuber) 是否已在運行
if pgrep -f "run_server.py" > /dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Open-LLM-VTuber 後端伺服器已在運行中。"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 正在啟動 Open-LLM-VTuber 後端伺服器..."
    cd "${BACKEND_DIR}" || exit 1
    setsid nohup "${BACKEND_DIR}/.venv/bin/python" run_server.py </dev/null > "${BACKEND_DIR}/logs/autostart_server.log" 2>&1 &
fi

# 等待後端連接埠 12393 準備就緒 (最多等待 30 秒)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 等待後端就緒 (Port 12393)..."
MAX_RETRIES=30
COUNT=0
while ! (ss -tulpn 2>/dev/null | grep -q ":12393 ") && [ $COUNT -lt $MAX_RETRIES ]; do
    sleep 1
    COUNT=$((COUNT + 1))
done

if ! (ss -tulpn 2>/dev/null | grep -q ":12393 "); then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 警告：後端伺服器啟動逾時，請檢查 ${BACKEND_DIR}/logs/autostart_server.log"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Open-LLM-VTuber 後端已成功就緒！"
fi

# 2. 檢查前端桌寵視窗 (Electron) 是否已在運行
if pgrep -f "pet-main.cjs" > /dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 愛蜜莉雅桌寵前端已在運行中。"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 正在啟動愛蜜莉雅桌寵前端視窗..."
    cd "${FRONTEND_DIR}" || exit 1
    setsid nohup "${FRONTEND_DIR}/node_modules/.bin/electron" "${FRONTEND_DIR}/pet-main.cjs" </dev/null > "${FRONTEND_DIR}/logs/autostart_pet.log" 2>&1 &
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 愛蜜莉雅 Live2D 桌寵啟動完成！"
fi
