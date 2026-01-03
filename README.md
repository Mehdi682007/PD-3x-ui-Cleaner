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
curl -fsSL https://raw.githubusercontent.com/Mehdi682007/PD-3x-ui-Cleaner/main/install.sh | bash
