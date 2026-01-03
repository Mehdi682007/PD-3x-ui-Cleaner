# PD-3x-ui-Cleaner

A professional **log maintenance & disk protection tool** for servers running **3x-ui / Xray**.

This script is designed for production environments where uncontrolled logs (especially `journald`) can silently fill up disk space and cause service outages.

---

## ✨ Features

- 🧹 Clean 3x-ui, Xray, and system logs safely (truncate-based)
- 📊 Show disk usage before & after cleanup
- 🧪 Dry-run mode (preview what will be cleaned)
- 📦 Show top disk space consumers
- ⏲ Automatic cleanup using **systemd timer** (no cron)
- 🔁 Configurable interval (daily / every N days)
- 🧾 Journald rotation & vacuum (size/time based)
- 🧠 Status dashboard (timer state, next run, disk usage)
- ❌ Clean uninstall with confirmation
- 🎨 Interactive terminal menu with colors & emojis

---

## 🚀 Installation

Run the following command on your server:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/Mehdi682007/PD-3x-ui-Cleaner/main/install.sh)
```

You will see an interactive menu:

1) Install / Update
2) Clean logs now
3) Dry-run preview
4) Show status
5) Top disk consumers
6) Set auto-run (systemd timer)
7) Remove script
8) Exit


⏲ Automatic Cleanup (systemd)

You can configure automatic cleanup using systemd timer.

Daily cleanup

Or every N days (user-defined)

Runs safely in the background

View status with:
systemctl list-timers | grep 3xui


⚠️ Why logs are not fully zeroed?

systemd-journald always keeps active log files.
This tool:

Rotates logs

Enforces size limits

Prevents uncontrolled growth

This is expected and correct behavior in Linux production systems.

❌ Uninstall

From the menu, select:
Remove script

This will:

Disable systemd timer

Remove service & timer files

Remove the script itself

No logs or system files are harmed.

🛡 Recommended For

3x-ui / Xray servers

Long-running VPS

Production environments

Low-disk servers (≤20GB)

📄 License

MIT License

Maintained by Mehdi


