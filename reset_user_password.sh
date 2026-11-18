#!/usr/bin/env bash
# ==============================================================================
# 愛蜜莉雅 (Emilia) Live2D 桌寵 - 使用者密碼重設腳本 (CLI)
# 用法: ./reset_user_password.sh <使用者名稱> <新密碼>
# 例如: ./reset_user_password.sh siewilly backey513
# ==============================================================================

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="${BASE_DIR}/Open-LLM-VTuber"
PYTHON_BIN="${BACKEND_DIR}/.venv/bin/python"

if [ ! -f "$PYTHON_BIN" ]; then
    PYTHON_BIN="python3"
fi

if [ "$#" -lt 2 ]; then
    echo "使用方式: $0 <使用者名稱> <新密碼>"
    echo "例如: $0 siewilly newpassword123"
    exit 1
fi

USERNAME="$1"
NEW_PASSWORD="$2"

cd "${BACKEND_DIR}" || exit 1

"$PYTHON_BIN" -c "
import sys
from src.open_llm_vtuber.database import db_manager

username = sys.argv[1].strip()
password = sys.argv[2]

try:
    success = db_manager.reset_password(username, password)
    if success:
        print(f'✅ 成功重設使用者 [{username}] 的密碼！')
        sys.exit(0)
    else:
        print(f'❌ 找不到使用者 [{username}]，重設失敗。')
        sys.exit(1)
except Exception as e:
    print(f'❌ 錯誤: {e}')
    sys.exit(1)
" "$USERNAME" "$NEW_PASSWORD"
