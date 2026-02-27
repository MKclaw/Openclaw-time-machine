#!/bin/zsh
# OpenClaw Time Machine v4.1 (Interactive TUI - Bilingual)
# 修复：解决 Enter 键无效问题，升级为中英双语菜单

# --- 环境初始化 ---
autoload -Uz compinit 2>/dev/null && compinit 2>/dev/null || true
stty -echoctl # 隐藏按键提示符

# --- 基础路径 ---
OPENCLAW_DIR="$HOME/.openclaw" #
BACKUP_ROOT="$OPENCLAW_DIR/backups"

# --- 颜色与样式 ---
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
P='\033[0;35m'
R='\033[0;31m'
NC='\033[0m'
HIGHLIGHT='\033[7m' # 反白高亮

init_system() {
    mkdir -p "$BACKUP_ROOT"
}

# --- 核心交互引擎 (修复回车与双语显示) ---
gui_menu() {
    local title="$1"
    shift
    local options=("$@")
    local current_selection=0
    local total_options=${#options[@]}

    while true; do
        clear
        echo -e "${B}======================================================${NC}"
        echo -e "  ${P}$title${NC}"
        echo -e "${B}======================================================${NC}"
        echo -e "  方向键 [↑/↓] 移动，[Enter] 确认选择"
        echo -e "  Use [↑/↓] to move, [Enter] to confirm"
        echo -e "${B}------------------------------------------------------${NC}"

        for i in {0..$((total_options-1))}; do
            if [[ $i -eq $current_selection ]]; then
                echo -e "  ${HIGHLIGHT} > ${options[$((i+1))]} ${NC}"
            else
                echo -e "    ${options[$((i+1))]}"
            fi
        done
        echo -e "${B}======================================================${NC}"

        # 逐字符精准捕获
        local key
        read -s -k 1 key
        if [[ $key == $'\x1b' ]]; then # 处理转义序列 (方向键)
            read -s -k 2 rest
            case "$rest" in
                '[A') # 向上
                    ((current_selection--))
                    [[ $current_selection -lt 0 ]] && current_selection=$((total_options-1))
                    ;;
                '[B') # 向下
                    ((current_selection++))
                    [[ $current_selection -ge $total_options ]] && current_selection=0
                    ;;
            esac
        elif [[ $key == $'\x0a' || $key == "" ]]; then # 处理回车键
            return $((current_selection + 1))
        fi
    done
}

# --- 业务逻辑功能 ---

do_backup() {
    local ts=$(date +'%Y%m%d_%H%M%S')
    local target_dir="$BACKUP_ROOT/config_$ts"
    mkdir -p "$target_dir"
    cp "$OPENCLAW_DIR/openclaw.json" "$target_dir/openclaw.json" #
    echo -e "\n${G}[SUCCESS]${NC} 备份完成 / Backup Done: $target_dir/openclaw.json"
    sleep 1
}

do_restore_config() {
    local backup_paths=()
    local display_names=()
    
    # 获取备份列表
    while IFS= read -r line; do
        backup_paths+=("$line")
        display_names+=("Version: $(basename $(dirname "$line"))")
    done < <(find "$BACKUP_ROOT" -name "openclaw.json" -path "*/config_*/openclaw.json" | sort -r)

    if [[ ${#backup_paths[@]} -eq 0 ]]; then
        echo -e "\n${R}[ERROR]${NC} 未发现备份 / No backups found."
        sleep 2; return
    fi

    display_names+=("<< 返回 / Back")
    
    gui_menu "选择还原版本 / Select Version" "${display_names[@]}"
    local choice=$?
    
    if [[ $choice -le ${#backup_paths[@]} ]]; then
        local selected="${backup_paths[$choice]}"
        echo -ne "\n${R}[CONFIRM]${NC} 覆盖当前配置？/ Overwrite config? (y/n): "
        read -r confirm
        if [[ "$confirm" == "y" ]]; then
            local ts=$(date +'%Y%m%d_%H%M%S')
            mkdir -p "$BACKUP_ROOT/pre_restore_$ts"
            cp "$OPENCLAW_DIR/openclaw.json" "$BACKUP_ROOT/pre_restore_$ts/openclaw.json" #
            cp -f "$selected" "$OPENCLAW_DIR/openclaw.json"
            echo -e "${G}[SUCCESS]${NC} 还原成功 / Restore Complete!"
        fi
    fi
}

do_full_snap() {
    local ts=$(date +'%Y%m%d_%H%M%S')
    local snap_path="$BACKUP_ROOT/full_$ts"
    mkdir -p "$snap_path"
    cp -a "$OPENCLAW_DIR/openclaw.json" "$snap_path/" #
    [ -d "$OPENCLAW_DIR/memory" ] && cp -a "$OPENCLAW_DIR/memory" "$snap_path/"
    [ -d "$OPENCLAW_DIR/plugins" ] && cp -a "$OPENCLAW_DIR/plugins" "$snap_path/"
    echo -e "\n${G}[SUCCESS]${NC} 快照完成 / Snapshot Done: $snap_path"
    sleep 1
}

# --- 主程序入口 ---
init_system
while true; do
    gui_menu "OpenClaw Time Machine v4.1" \
        "备份配置 / Backup openclaw.json" \
        "还原配置 / Restore openclaw.json" \
        "系统全量备份 / Full System Snapshot" \
        "升级程序 / Upgrade OpenClaw" \
        "打开备份目录 / Open Backup Folder" \
        "退出系统 / Exit System"
    
    case $? in
        1) do_backup ;;
        2) do_restore_config ;;
        3) do_full_snap ;;
        4) 
            echo -e "\n${P}[UPGRADING]${NC} 升级中..."
            npm install -g openclaw@latest --loglevel error || sudo npm install -g openclaw@latest --loglevel error #
            ;;
        5) open "$BACKUP_ROOT" ;;
        6) echo -e "\n再见，Director / Goodbye."; exit 0 ;;
    esac
    
    echo -e "\n按回车键继续 / Press Enter to continue..."
    read
done