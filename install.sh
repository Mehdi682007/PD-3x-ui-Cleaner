#!/usr/bin/env bash
set -uo pipefail

# ================= COLORS =================
RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"
BLUE="\e[34m"; CYAN="\e[36m"; RESET="\e[0m"; BOLD="\e[1m"

# ================= PATHS =================
SCRIPT_PATH="$(realpath "$0")"
SERVICE_FILE="/etc/systemd/system/3xui-clean.service"
TIMER_FILE="/etc/systemd/system/3xui-clean.timer"
JSON_REPORT="/var/log/3xui-maintenance.json"

RETENTION_DAYS=14

# ================= LOGO =================
clear
echo -e "${CYAN}${BOLD}"
cat <<'EOF'
____________   _____                   _   _____ _                            
| ___ \  _  \ |____ |                 (_) /  __ \ |                           
| |_/ / | | |     / /_  ________ _   _ _  | /  \/ | ___  __ _ _ __   ___ _ __ 
|  __/| | | |     \ \ \/ /______| | | | | | |   | |/ _ \/ _` | '_ \ / _ \ '__|
| |   | |/ /  .___/ />  <       | |_| | | | \__/\ |  __/ (_| | | | |  __/ |   
\_|   |___/   \____//_/\_\       \__,_|_|  \____/_|\___|\__,_|_| |_|\___|_|   
           3X-UI LOG MAINTENANCE TOOL
EOF
echo -e "${RESET}"

# ================= UTILS =================
require_root() {
  [[ "$EUID" -ne 0 ]] && echo -e "${RED}❌ Run as root${RESET}" && exit 1
}

disk_usage() {
  df / | awk 'NR==2{gsub("%","");print $5}'
}

free_bytes() {
  df -B1 / | awk 'NR==2{print $4}'
}

human_bytes() {
  numfmt --to=iec-i --suffix=B --format="%.2f" "$1"
}

# ================= LOG HELPERS =================
detect_logs() {
  find /etc/x-ui /usr/local/x-ui /var/log -type f -name "*.log*" 2>/dev/null || true
}

top_consumers() {
  du -xh /var/log /usr/local /etc/x-ui 2>/dev/null | sort -hr | head -10
}

# ================= INSTALL =================
install_setup() {
  apt-get update -y >/dev/null
  apt-get install -y logrotate >/dev/null

  cat >/etc/logrotate.d/3x-ui-xray <<'EOF'
/etc/x-ui/*.log
/var/log/xray/*.log
/var/log/*.log
{
  daily
  rotate 14
  missingok
  notifempty
  compress
  delaycompress
  copytruncate
}
EOF

  mkdir -p /etc/systemd/journald.conf.d
  cat >/etc/systemd/journald.conf.d/3x-ui-limits.conf <<'EOF'
[Journal]
SystemMaxUse=512M
MaxRetentionSec=14day
EOF

  systemctl restart systemd-journald
  echo -e "${GREEN}✅ Installation completed${RESET}"
}

# ================= CLEAN =================
clean_logs() {
  BEFORE_USAGE=$(disk_usage)
  BEFORE_FREE=$(free_bytes)

  echo -e "${YELLOW}🧹 Cleaning logs...${RESET}"

  detect_logs | while read -r f; do : > "$f" || true; done
  journalctl --vacuum-time="${RETENTION_DAYS}d" >/dev/null 2>&1 || true
  sync

  AFTER_USAGE=$(disk_usage)
  AFTER_FREE=$(free_bytes)
  FREED=$((AFTER_FREE - BEFORE_FREE))

  echo
  echo -e "${BLUE}📊 Disk usage before : ${BEFORE_USAGE}%${RESET}"
  echo -e "${BLUE}📊 Disk usage after  : ${AFTER_USAGE}%${RESET}"

  if (( FREED > 0 )); then
    echo -e "${GREEN}🎉 Freed space: $(human_bytes "$FREED")${RESET}"
    echo "{\"time\":\"$(date -Is)\",\"freed_bytes\":$FREED}" >>"$JSON_REPORT"
  else
    echo -e "${YELLOW}ℹ No significant space freed${RESET}"
  fi
}

# ================= DRY RUN =================
dry_run() {
  echo -e "${CYAN}🧪 Dry-run (preview only):${RESET}"
  detect_logs | while read -r f; do
    SIZE=$(stat -c %s "$f" 2>/dev/null || echo 0)
    (( SIZE > 0 )) && echo "$(human_bytes "$SIZE")  $f"
  done
}

# ================= TIMER =================
set_timer() {
  read -rp "⏲ Run cleanup every how many days? (1 = daily): " DAYS
  DAYS="$(echo "$DAYS" | tr -d '[:space:]')"

  [[ ! "$DAYS" =~ ^[0-9]+$ || "$DAYS" -lt 1 ]] && echo "Invalid number" && return

  systemctl disable --now 3xui-clean.timer >/dev/null 2>&1 || true
  rm -f "$SERVICE_FILE" "$TIMER_FILE"

  cat >"$SERVICE_FILE" <<EOF
[Unit]
Description=3xui log cleanup

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH --auto
EOF

  cat >"$TIMER_FILE" <<EOF
[Unit]
Description=3xui cleanup timer

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl daemon-reload
  systemctl enable --now 3xui-clean.timer

  echo -e "${GREEN}⏲ Timer enabled (daily 03:00)${RESET}"
}

# ================= STATUS =================
show_status() {
  echo -e "${BLUE}${BOLD}📌 Current status:${RESET}"

  systemctl is-enabled --quiet 3xui-clean.timer \
    && echo -e "⏲ Timer : ${GREEN}Enabled${RESET}" \
    || echo -e "⏲ Timer : ${YELLOW}Disabled${RESET}"

  systemctl is-active --quiet 3xui-clean.timer \
    && echo -e "▶️  State : ${GREEN}Running${RESET}" \
    || echo -e "▶️  State : ${YELLOW}Inactive${RESET}"

  systemctl list-timers --no-pager | grep 3xui-clean || true
  echo -e "💽 Disk usage : $(disk_usage)%"
}

# ================= REMOVE =================
remove_all() {
  read -rp "❗ Type YES to remove the script completely: " ANS
  [[ "$ANS" != "YES" ]] && echo "Canceled." && return

  systemctl disable --now 3xui-clean.timer >/dev/null 2>&1 || true
  rm -f "$SERVICE_FILE" "$TIMER_FILE" "$SCRIPT_PATH"

  echo -e "${RED}🗑 Script removed completely${RESET}"
  exit 0
}

# ================= MENU =================
menu() {
  while true; do
    echo
    echo -e "${CYAN}========== MENU ==========${RESET}"
    echo -e "1) 🛠 Install / Update"
    echo -e "2) 🧹 Clean logs now"
    echo -e "3) 🧪 Dry-run preview"
    echo -e "4) 📊 Show status"
    echo -e "5) 📦 Top disk consumers"
    echo -e "6) ⏲ Set auto-run (systemd timer)"
    echo -e "7) ❌ Remove script"
    echo -e "8) 🚪 Exit"
    echo -e "${CYAN}==========================${RESET}"

    read -rp "Select option: " C
    C="$(echo "$C" | tr -d '[:space:]')"

    case "$C" in
      1) install_setup ;;
      2) clean_logs ;;
      3) dry_run ;;
      4) show_status ;;
      5) top_consumers ;;
      6) set_timer ;;
      7) remove_all ;;
      8) exit 0 ;;
      *) echo -e "${RED}Invalid option${RESET}" ;;
    esac
  done
}

# ================= MAIN =================
require_root

if [[ "${1:-}" == "--auto" ]]; then
  clean_logs
  exit 0
fi

menu
