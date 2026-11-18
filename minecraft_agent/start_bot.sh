#!/usr/bin/env bash
# start_bot.sh - 啟動愛蜜莉雅 Minecraft 同伴機器人
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🌸 正在啟動愛蜜莉雅 Minecraft 智能同伴機器人..."
node index.js "$@"
