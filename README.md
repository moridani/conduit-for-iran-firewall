# 🇮🇷 Iran-Only Firewall for Psiphon Conduit

> **🙏 Based on the original idea by [SamNet-dev](https://github.com/SamNet-dev/iran-conduit-firewall)**  
> This is a standalone version (no Python required) for easier distribution.

**Maximize your Psiphon Conduit bandwidth for Iranian users during internet shutdowns.**

When you run Psiphon Conduit, people from ANY country can connect. This tool restricts connections to Iran-only, so your bandwidth helps those who need it most.

---

## ⚡ Quick Start

1. **[Download iran_firewall.bat](https://github.com/user/repo/releases/latest)**
2. **Right-click → Run as Administrator**
3. **Press 1** to enable Iran-only mode
4. **Done!** ✅

No Python. No installation. Just run.

---

## 📸 Screenshot

```
╔═══════════════════════════════════════════════════════════════════╗
║       🇮🇷 IRAN-ONLY FIREWALL FOR PSIPHON CONDUIT v2.0.0 🇮🇷        ║
╠═══════════════════════════════════════════════════════════════════╣
║  Maximize bandwidth for Iranian users during internet shutdowns   ║
╚═══════════════════════════════════════════════════════════════════╝

  1. 🟢 Enable Iran-only mode (Normal)
  2. 🔒 Enable Iran-only mode (Strict)
  3. 🔴 Disable Iran-only mode
  4. 📊 Check status
  5. 🚀 Conduit management
  6. ❓ Help
  0. 🚪 Exit
```

---

## 🔒 How It Works

| Mode | TCP | UDP | Best For |
|------|-----|-----|----------|
| **Normal** | Global | Iran only | Most users |
| **Strict** | Iran only | Iran only | Maximum restriction |

- Downloads 2000+ Iran IP ranges from trusted sources
- Creates Windows Firewall rules for `conduit-tunnel-core.exe` only
- **Your PC works normally** — only Conduit is affected

---

## 📋 Requirements

- Windows 10/11
- [Psiphon Conduit](https://conduit.psiphon.ca/) installed
- Windows Firewall enabled

---

## ❓ FAQ

**Does this affect my PC?**  
No. Only Psiphon Conduit is filtered.

**Do rules persist after closing?**  
Yes, until you run "Disable" (option 3).

**How do I update IP ranges?**  
Re-run option 1 or 2 — it fetches the latest ranges.

---

## 🙏 Credits

- **Original idea & Python version:** [SamNet-dev/iran-conduit-firewall](https://github.com/SamNet-dev/iran-conduit-firewall)
- **IP sources:** [ipdeny.com](https://www.ipdeny.com/), [herrbischoff/country-ip-blocks](https://github.com/herrbischoff/country-ip-blocks)

---

## 📜 License

MIT — Free to use and share.

---

<div dir="rtl">

## 🇮🇷 فارسی

این ابزار پهنای باند Psiphon Conduit شما را فقط برای کاربران ایرانی محدود می‌کند.

**استفاده:**
1. فایل `iran_firewall.bat` را دانلود کنید
2. راست‌کلیک → Run as Administrator
3. گزینه 1 را انتخاب کنید

</div>