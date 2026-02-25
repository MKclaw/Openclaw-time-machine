#!/bin/bash

# ==========================================================
# 🚀 Software: OpenClaw Time Machine Manager
# ----------------------------------------------------------
# Version: 2.3.4 (Official Edition)
# Arch: Optimized for Apple Silicon M4 (arm64)
# Features: Bilingual UI, Full-Pro Snapshots, Visible Restore
# ==========================================================

# --- 1. Settings & Paths / 环境与路径 ---
APP_NAME="OpenClaw Time Machine Manager"
OPENCLAW_DIR="$HOME/.openclaw"
BACKUP_ROOT="$OPENCLAW_DIR/backups"
LOG_DIR="$OPENCLAW_DIR/logs"

mkdir -p "$BACKUP_ROOT"

# Set Terminal Title / 设置终端标题
echo -ne "\033]0;${APP_NAME} v2.3.4\007"

# --- 2. UI Adapter / 界面适配器 ---
safe_dialog() {
    local title="$1" prompt="$2"
    shift 2
    local raw_items=("$@") dialog_items=()
    for i in "${!raw_items[@]}"; do dialog_items+=("$((i+1))" "${raw_items[i]}"); done

    if command -v dialog &> /dev/null; then
        export TERM=xterm-256color
        local result
        if result=$(dialog --clear --stdout --keep-tite --title "$title" --menu "$prompt" 24 85 12 "${dialog_items[@]}" 2>/dev/null); then
            echo "$result"; return 0
        fi
    fi
    # Fallback Terminal Menu / 终端备用菜单
    clear
    echo -e "\n\033[36m========================================================\033[0m"
    echo -e "  \033[1m${title}\033[0m"
    echo -e "\033[36m========================================================\033[0m"
    echo -e "$prompt\n"
    for i in "${!raw_items[@]}"; do echo -e "  \033[1m$((i+1))\033[0m. ${raw_items[i]}"; done
    echo -ne "\n  Select Option / 请选择编号: "; read -r choice; echo "$choice"
}

# --- 3. Full-Pro Backup Logic / 全量备份逻辑 ---
perform_backup() {
    local ts=$(date +'%Y%m%d-%H%M%S')
    local target_dir="$BACKUP_ROOT/$ts"
    
    echo -e "\n📦 \033[36m[Backup] Initializing Full-Pro Snapshot... / 正在初始化全量备份...\033[0m"
    mkdir -p "$target_dir"
    
    # Core Components / 核心组件
    local items=("openclaw.json" "workspace" "plugins" "memory")
    
    for item in "${items[@]}"; do
        if [ -e "$OPENCLAW_DIR/$item" ]; then
            echo "   \033[32m[+]\033[0m Syncing / 同步中: $item ..."
            cp -a "$OPENCLAW_DIR/$item" "$target_dir/" 2>/dev/null || true
        else
            echo "   \033[33m[-]\033[0m Not found, skipping / 未找到，跳过: $item"
        fi
    done
    
    echo -e "\n✅ \033[32mSuccess! Snapshot saved to: / 全量备份成功！存档于：\033[0m"
    echo "   $target_dir"
}

# --- 4. Restore Logic / 恢复逻辑 ---
restore_menu() {
    local BACKUPS=($(find "$BACKUP_ROOT" -maxdepth 1 -mindepth 1 -type d -name "20*" | xargs -I {} basename {} | sort -r))
    [[ ${#BACKUPS[@]} -eq 0 ]] && { echo -e "\n❌ Error: No valid backups found. / 未找到有效备份。"; return; }

    local choice=$(safe_dialog "🔄 Restore / 恢复中心" "Choose a checkpoint to restore: / 请选择要回滚的备份点：" "${BACKUPS[@]}")
    [[ -z "$choice" ]] && return

    local SELECTED_ID="${BACKUPS[$((choice-1))]}"
    local BACKUP_DIR="$BACKUP_ROOT/$SELECTED_ID"

    echo -e "\n\033[41m  CRITICAL / 关键操作确认  \033[0m"
    echo "  Rolling back to: / 正在回滚至: $SELECTED_ID"
    read -p "  Confirm overwrite? / 确认执行覆盖恢复? (y/N): " confirm
    [[ "$confirm" != "y" ]] && return

    # Pre-Restore Visibility Snapshot / 恢复前可见快照
    local ts=$(date +'%Y%m%d-%H%M%S')
    local snap_dir="$BACKUP_ROOT/PRE-RESTORE-$ts"
    echo "📦 Creating pre-restore snapshot / 创建灾备快照: $snap_dir"
    mkdir -p "$snap_dir"
    
    local items=("openclaw.json" "workspace" "plugins" "memory")
    for item in "${items[@]}"; do
        [ -e "$OPENCLAW_DIR/$item" ] && cp -a "$OPENCLAW_DIR/$item" "$snap_dir/" 2>/dev/null || true
    done

    # Execute Data Injection / 执行数据注入
    echo "🔄 Restoring files / 正在写入文件..."
    for item in "${items[@]}"; do
        if [ -e "$BACKUP_DIR/$item" ]; then
            echo "   [>] Recovering / 恢复中: $item ..."
            rm -rf "$OPENCLAW_DIR/$item" 
            cp -a "$BACKUP_DIR/$item" "$OPENCLAW_DIR/"
        fi
    done
    echo -e "\n✅ \033[32mSystem Restored Successfully! / 系统全量恢复完成！\033[0m"
}

# --- 5. Main Interface / 主界面循环 ---
main_loop() {
    while true; do
        local choice
        choice=$(safe_dialog "${APP_NAME}" "System: macOS M4 | Root: $OPENCLAW_DIR\nVisible PRE-RESTORE snapshots are auto-generated before any restore.\n恢复操作前会自动在 backups 目录生成可见的快照。" \
            "[Full-Pro] Backup Now / 立即执行全量备份" \
            "[Restore] History Backups / 恢复历史备份点" \
            "[Finder] Open Backup Folder / 打开备份文件夹" \
            "[Cleanup] Purge Log Files / 清理过期日志" \
            "[Exit] Close Manager / 退出管理程序")

        case $choice in
            1) perform_backup; echo -ne "\nPress Enter / 回车继续..."; read ;;
            2) restore_menu; echo -ne "\nPress Enter / 回车继续..."; read ;;
            3) open "$BACKUP_ROOT" ;;
            4) rm -rf "$LOG_DIR"/*.log && echo -e "\n✅ Logs cleared. / 日志已清理。"; sleep 1 ;;
            *) break ;;
        esac
    done
    echo -e "\n\033[36mStay productive. / 保持高效。\033[0m"
    sleep 1
}

main_loop