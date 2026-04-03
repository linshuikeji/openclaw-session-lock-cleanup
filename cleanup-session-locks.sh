#!/bin/bash
# OpenClaw 会话锁文件自动清理脚本
# 清理孤立的 .lock 文件（没有对应 .jsonl 文件的锁文件）
# 也会清理超过 5 分钟的孤儿锁文件

LOCK_DIR="$HOME/.openclaw/agents/main/sessions"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始清理会话锁文件..."

if [ ! -d "$LOCK_DIR" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 警告：锁文件目录不存在：$LOCK_DIR"
    exit 0
fi

CLEANED=0
STALE_FOUND=0

# 遍历所有 .lock 文件
for lock_file in "$LOCK_DIR"/*.lock; do
    [ -f "$lock_file" ] || continue
    
    # 提取 session ID
    session_id=$(basename "$lock_file" .lock)
    
    # 检查是否有对应的 .jsonl 文件
    jsonl_file="$LOCK_DIR/${session_id}.jsonl"
    
    if [ ! -f "$jsonl_file" ]; then
        # 没有对应的 .jsonl，是孤立的锁文件
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 发现孤立锁文件：$lock_file"
        rm -f "$lock_file"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 已删除孤立锁文件：$session_id"
        ((CLEANED++))
    else
        # 检查是否是孤儿锁文件（锁文件存在但 session 已过期）
        # 获取锁文件的创建时间
        lock_mtime=$(stat -c %Y "$lock_file" 2>/dev/null)
        current_time=$(date +%s)
        age_seconds=$((current_time - lock_mtime))
        
        # 如果锁文件超过 5 分钟（300 秒），认为是孤儿
        if [ "$age_seconds" -gt 300 ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 发现孤儿锁文件（超过 5 分钟）：$session_id (已存在 ${age_seconds}s)"
            rm -f "$lock_file"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 已删除孤儿锁文件：$session_id"
            ((CLEANED++))
            ((STALE_FOUND++))
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 保留正常锁文件：$session_id (${age_seconds}s)"
        fi
    fi
done

echo ""
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 清理完成！"
echo "[$(date '+%Y-%m-%d %H:%M:%S')]   - 清理孤立锁文件：$CLEANED 个"
echo "[$(date '+%Y-%m-%d %H:%M:%S')]   - 清理孤儿锁文件：$STALE_FOUND 个"
echo "[$(date '+%Y-%m-%d %H:%M:%S')]   - 保留正常锁文件：$(( $(ls "$LOCK_DIR"/*.lock 2>/dev/null | wc -l) - CLEANED - STALE_FOUND )) 个"

# 如果有清理，发送通知
if [ "$CLEANED" -gt 0 ]; then
    echo ""
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  检测到 $CLEANED 个异常锁文件已被清理！"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 如果通道出现假死，可能是 session 超时导致的锁泄漏。"
fi

exit 0
