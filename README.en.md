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

### How to install

**Step 1** — Open the Terminal (`Ctrl+Alt+T`)

**Step 2** — Type the command below and press Enter:

```bash
bash instalar.sh
```

**Step 3** — Read the summary, confirm with `s` and wait. The script installs everything on its own.

At the end, a report shows what was installed successfully.

---

### Tips and Help

See [DICAS.md](DICAS.md) (Portuguese) for:

- How to use the digital token on Linux
- Keyboard shortcuts equivalent to Windows
- Clipboard history (equivalent to Win+V)
- How to print to PDF
- How to recover deleted files

---

### Problems?

The installer writes a full log to `~/pje-install-DATE-TIME.log`. If something goes wrong, send this file to support.

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
specs/001-rewrite-instalar-sh/
  spec.md            # Full specification (user stories, requirements)
  plan.md            # Implementation plan by phases
  tasks.md           # Task list with completion status
  research.md        # Technical research (versions, URLs, decisions)
  data-model.md      # Data model and state flow diagram
  quickstart.md      # VM test scenarios
```

### Security

Every downloaded binary is verified with **SHA256** before installation. If the hash doesn't match, the installation aborts. Hashes are stored in the `CONFIG` block at the top of `instalar.sh` and must be updated by the maintainer when bumping versions.

To calculate a binary's hash:

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
