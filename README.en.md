# PJe on Linux

Installs everything a Brazilian lawyer needs to use PJe (Judicial Electronic Process) on Linux — in a single command.

> README em português: [README.md](README.md)

---

## For the Lawyer

### What is this?

If you just migrated from Windows to Linux (Ubuntu, Zorin OS, Linux Mint) and need to use the Brazilian **PJe** court system, this script installs everything automatically:

| What it installs | Purpose |
|---|---|
| Google Chrome | Official PJe browser |
| SafeNet SAC | Digital token (A3) driver |
| SafeSign IC | A3 certificate signing |
| PJeOffice Pro | Document signing inside PJe |
| Web Signer | Browser digital signature extension |
| Antigravity IDE | Recommended work environment |
| Microsoft 365 PWA | Word, Excel, PowerPoint and Outlook on Linux |

It also configures the **Super+Shift+S** shortcut (equivalent to Win+Shift+S on Windows) for area screenshots.

---

### How to install — 3 simple steps

**Step 1** — Open the Terminal with `Ctrl + Alt + T`

**Step 2** — Paste the command and press Enter:

```bash
bash instalar.sh
```

![Terminal with the install command](assets/screenshots/01-terminal.png)

> When prompted for your password, the characters won't appear on screen — this is normal, it's a system security feature.

**Step 3** — Read the summary, confirm with `s` and wait. An installation report will appear when done.

---

### After installing — configure Web Signer

This is done **once** in Chrome:

1. Open Chrome → click the **Web Signer** icon (blue shield in the toolbar)
2. Go to **Settings** → **"Crypto Devices"** tab
3. In the **"SO file name"** field, type: `libeToken.so`
4. Click **+**

![Web Signer configuration](assets/screenshots/03-websigner.png)

---

### When everything is working

**PJeOffice — token recognized:**

![PJeOffice recognizing the token](assets/screenshots/02-pjeoffice.png)

**eSAJ — certificate available for signing:**

![eSAJ with certificate working](assets/screenshots/04-esaj.png)

---

### Tips and Help

See [DICAS.md](DICAS.md) (Portuguese) for:

- How to use **Super+Shift+S** (screenshot like Win+Shift+S on Windows)
- Keyboard shortcuts equivalent to Windows
- Clipboard history (equivalent to Win+V)
- How to print to PDF
- How to recover deleted files
- How to use the digital token on Linux

---

### Problems?

The installer writes a full log to `~/pje-install-DATE-TIME.log`. Send this file to support if something goes wrong.

---

## For the Tech-Savvy Lawyer (and Developers)

### Project structure

```
instalar.sh          # Main script — installs all components
desinstalar.sh       # Removes everything instalar.sh installed
checksums.sha256     # SHA256 hashes of binaries (for auditing)
DICAS.md             # Usage guide for lawyers migrating from Windows
assets/
  icons/             # 128×128 PNG icons for Microsoft 365 PWAs
  screenshots/       # Illustrative screenshots for the README
  dicas/             # Images for the DICAS.md guide
```

### Security

Every downloaded binary is verified with **SHA256** before installation. If the hash doesn't match, the installation aborts. Hashes are stored in the `CONFIG` block at the top of `instalar.sh` and must be updated by the maintainer when bumping versions.

```bash
sha256sum filename.deb
```

### How to uninstall

```bash
bash desinstalar.sh
```

Removes all packages, config files, shortcuts, and reverts the screenshot keyboard shortcut.

### Components and current versions

| Component | Version | Distribution |
|---|---|---|
| SafeNet SAC | 10.8.1050 | Ubuntu 22.04 |
| SafeSign IC | 4.2.1.0 | Ubuntu 22.04 |
| PJeOffice Pro | v2.5.16u | Linux x64 |
| Web Signer | 2.12.1 | Chrome (64-bit .deb) |

### System requirements

- Ubuntu 22.04 / 24.04, Zorin OS 17/18, Linux Mint 21–22, or Debian 12+
- Architecture: `amd64` (64-bit)
- Bash 5.0+
- Internet connection
- `sudo` available

### Contributing

The project uses **SpecKit** as its specification methodology. See [AGENTS.md](AGENTS.md) for the command workflow and how to contribute new features.

```bash
# Check code quality
shellcheck --severity=warning instalar.sh
shellcheck --severity=warning desinstalar.sh
bash -n instalar.sh
```

---

*Open source project. Contributions welcome.*
