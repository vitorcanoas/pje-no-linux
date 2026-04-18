# PJe on Linux

> README em português: [README.md](README.md)

---

## Install — copy, paste and press Enter

```bash
git clone https://github.com/vitorcanoas/pje-no-linux.git && cd pje-no-linux && bash instalar.sh
```

> Open the Terminal (`Ctrl + Alt + T`), paste with `Ctrl + Shift + V` and press Enter.
> Don't know what a Terminal is? Read the step-by-step guide with images below. 👇

---

## Just installed Linux and can't get PJe to work?

Relax. This guide was made **by a lawyer, for lawyers** — including those who have never touched Linux in their lives.

One single command installs everything. No tech knowledge required.

---

## What this script installs for you

| What | What it's for |
|---|---|
| **Google Chrome** | Official PJe browser |
| **SafeNet SAC** | Makes your computer recognize your digital token (the certificate USB stick) |
| **SafeSign IC** | Signs documents with your A3 certificate |
| **PJeOffice Pro** | The official court digital signing tool |
| **Web Signer** | Extension for signing in the browser (eSAJ, TJSP and others) |
| **Antigravity IDE** | Recommended work environment |
| **Microsoft 365** | Word, Excel, PowerPoint and Outlook running on Linux |

It also configures the **Super+Shift+S** shortcut for area screenshots — same as Win+Shift+S on Windows.

---

## How to install — step by step, from scratch

### Step 1 — Open the Terminal

**The Terminal is Linux's "Command Prompt".** It's a window where you type instructions — it looks scary, but you'll only use one command.

To open it:
- Press **Ctrl + Alt + T** at the same time
- Or search for **"Terminal"** in your apps (like the Start Menu)

![Terminal with the install command](assets/screenshots/01-terminal.png)

---

### Step 2 — Type the command

With the Terminal open, **click once inside the black window** and type exactly:

```
bash instalar.sh
```

Then press **Enter**.

> **Tip:** You can copy the text above and paste it into the Terminal with **Ctrl + Shift + V** (on Linux it's Shift+V, not just V).

---

### Step 3 — Enter your password

The installer will ask for your user password (the same one you use to log into the computer).

**⚠️ Important:** When you type your password, **the characters do NOT appear on screen** — no asterisks, nothing. It looks like it's not working, but it is. This is normal Linux security. Just type your password and press Enter.

---

### Step 4 — Confirm the installation

A summary will appear showing what will be installed. Read it and, if you agree, **press the letter `s`** and then **Enter** to confirm.

---

### Step 5 — Wait

The installer will download and install everything on its own. Depending on your internet speed, it takes 5 to 15 minutes. You'll see text scrolling on screen — that's normal, just let it run.

At the end, a report like this appears:

```
✓ Google Chrome        installed
✓ SafeNet SAC          installed
✓ SafeSign IC          installed
✓ PJeOffice Pro        installed
✓ Web Signer           installed
✓ Microsoft 365 PWA    configured
✓ Super+Shift+S        configured
```

---

### Step 6 — Configure Web Signer (one time only)

After installing, open **Chrome** and do this configuration **just once**:

1. Click the **Web Signer** icon in Chrome's toolbar (a blue shield)
2. Click **Settings** (gear icon)
3. Click the **"Crypto Devices"** tab
4. In the **"SO file name"** field, type: `libeToken.so`
5. Click the **+** button

![Web Signer configuration](assets/screenshots/03-websigner.png)

---

## When everything is working

**PJeOffice recognizing your token:**

![PJeOffice recognizing the token](assets/screenshots/02-pjeoffice.png)

**eSAJ with your certificate available:**

![eSAJ with certificate working](assets/screenshots/04-esaj.png)

---

## Something went wrong?

Don't panic. The installer saves a full log of everything that happened to:

```
~/pje-install-DATE-TIME.log
```

Send that file to support and they'll have everything they need to help you.

---

## Day-to-day tips on Linux

See [DICAS.md](DICAS.md) (Portuguese) to learn:

- **Super+Shift+S** — area screenshot (same as Win+Shift+S)
- Keyboard shortcuts equivalent to Windows
- Clipboard history (same as Win+V)
- How to print to PDF
- How to recover deleted files
- How to use the digital token

---

## About the author

I'm **Vitor**, a lawyer for over 10 years, passionate about technology and currently learning to code — because apparently law alone isn't complicated enough.

I switched to Linux and spent hours trying to get PJe to work. After a lot of suffering (and a few words that don't belong in a README), I put everything into a script so no other lawyer has to go through the same thing.

After all, **who hasn't struggled with technology on a daily basis?** 😄

If I figured it out, you can too.

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
| SafeSign IC | 4.6.0.0 | Ubuntu 22.04 |
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

*Open source project licensed under [GPL-3.0](LICENSE). Use it, improve it, share it — but keep it open.*
