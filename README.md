# 🛠️ IT Support Diagnostic & Setup Toolkit

![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11%20%7C%20Ubuntu%20on%20WSL2-blue)
![Type](https://img.shields.io/badge/type-documentation%20%2B%20scripts-green)

A documented toolkit that any junior IT technician can pick up and run on a new or problem machine: a full Windows health report, a new-employee onboarding flow, networking setup, Linux health checks, application lifecycle management, and cloud productivity tools.

> **Scenario:** I'm the new IT support hire. My manager asked me to build a diagnostic + setup toolkit that any junior tech can run on a new/problem machine, and to document a full onboarding flow for a new employee.

---

## 📁 Repository Structure

```
.
├── README.md                     ← you are here (master index, cheat-sheet, screenshot index)
├── windows-scripts/
│   ├── README.md                 ← Part 1 (diagnostics), Part 2 (onboarding), Part 5 (app lifecycle)
│   └── screenshots/
├── linux-scripts/
│   ├── README.md                 ← Part 4 (Linux health check on WSL)
│   └── screenshots/
└── networking-notes/
    ├── README.md                 ← Part 3 (networking), Part 6 (cloud tools)
    └── screenshots/
```

> This repository is **documentation-first**: every script is embedded in the README of its folder as a code block. The line above each block tells you the file name to save it as (for example `Get-SystemDiagnostic.ps1`, `disk_check.sh`).

---

## 🗺️ Project Map

| Part | Topic | Documented in |
|------|-------|---------------|
| 1 | System diagnostic script (Windows) | [windows-scripts](windows-scripts/README.md#part-1-system-diagnostic-script) |
| 2 | New employee onboarding (Windows) | [windows-scripts](windows-scripts/README.md#part-2-new-employee-onboarding) |
| 3 | Networking setup (Windows) | [networking-notes](networking-notes/README.md#part-3-networking-setup) |
| 4 | Linux health check (WSL) | [linux-scripts](linux-scripts/README.md#part-4-linux-health-check-wsl) |
| 5 | Application lifecycle | [windows-scripts](windows-scripts/README.md#part-5-application-lifecycle) |
| 6 | Cloud-based productivity tools | [networking-notes](networking-notes/README.md#part-6-cloud-based-productivity-tools) |
| 7 | Deliverable (this README + folder layout) | You are here |

### ✅ Requirement Checklist

**Part 1: System Diagnostic Script**
- [x] PowerShell script: OS version/build, edition/license, disk space, installed apps, network config, top 10 processes by memory
- [x] File system type of every drive via `fsutil fsinfo volumeinfo`
- [x] Boot method (UEFI vs Legacy BIOS) via `msinfo32` / `bcdedit`
- [x] `sfc /scannow`, `chkdsk`, `DISM /Online /Cleanup-Image /RestoreHealth` with captured output

**Part 2: New Employee Onboarding**
- [x] Local standard (non-admin) user via command line
- [x] Shrink volume → new partition → format NTFS (documented step by step)
- [x] Windows Update pause policy
- [x] System Restore point created + verified from the command line
- [x] Personalization via Settings vs PowerShell/registry (compared)
- [x] Security setting via Control Panel (BitLocker) + Defender scan schedule, verified from the command line

**Part 3: Networking**
- [x] Static IP, gateway, DNS
- [x] Firewall rule blocking a port + proof it is blocked
- [x] Network discovery on/off and visibility test
- [x] Shared folder + access from a second device
- [x] `net use` drive mapping + shared/mapped network printer
- [x] RDP vs SSH / remote-support app (differences documented)
- [x] Workgroup vs Domain (note)

**Part 4: Linux Health Check (WSL)**
- [x] Disk usage script (top 5 largest, >80% flag)
- [x] `.tar.gz` timestamped backup script
- [x] Hourly cron job
- [x] `find` / `cp -r` / `mv` / `ls -la` practice
- [x] Permissions in depth (`chmod 750`, tested across users)
- [x] User/group/sudo administration
- [x] Networking commands (`ip a`, `ping`, `ss -tulpn`, `curl`)
- [x] `htop`

**Part 5: Application Lifecycle**
- [x] Silent install
- [x] Full uninstall + leftover verification
- [x] System requirements check against the Part 1 report
- [x] Installer vs portable comparison
- [x] App permissions / limited user restriction

**Part 6: Cloud Productivity**
- [x] Cloud folder sync + conflict test
- [x] View-only vs edit sharing
- [x] Storage-as-a-Service vs Software-as-a-Service

**Part 7: Deliverable**
- [x] One README covering scripts, commands, screenshots
- [x] `/windows-scripts`, `/linux-scripts`, `/networking-notes`, `/README.md`

---

## 🧪 Lab Environment

| Machine | Role | OS | Address used in the notes |
|---------|------|----|---------------------------|
| `IT-WS01` | Primary test machine (VM) | Windows 11 Pro | `192.168.1.50` (static, Part 3) |
| `IT-WS02` | Second device (VM) for share / firewall / RDP tests | Windows 10/11 Pro | `192.168.1.60` |
| WSL | Linux practice | Ubuntu 22.04 / 24.04 on WSL2 | n/a |

> **Adapt the addresses to your own lab.** Use a bridged or internal VM network, pick addresses outside your DHCP pool, and replace `192.168.1.x` everywhere it appears.
> RDP hosting and BitLocker need **Windows Pro or higher**, so Home editions cannot be used for those steps.

**Suggested accounts**

| Account | Where | Purpose |
|---------|-------|---------|
| `jsmith` | Windows | The new employee (standard user) created in Part 2 |
| `alice`, `bob`, `carol` | Linux | Owner / group member / "other" for the permission tests |
| `devuser` | Linux | Admin practice (group + sudo) |

---

## 🚀 Quick Start

**Windows: run the diagnostic** (elevated PowerShell)
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Get-SystemDiagnostic.ps1            # full run incl. SFC / CHKDSK / DISM
.\Get-SystemDiagnostic.ps1 -SkipRepairs   # fast run, report only
```

**Linux (WSL): run the disk check**
```bash
chmod +x disk_check.sh backup.sh
./disk_check.sh 80 ~                  # threshold 80%, scan home directory
./backup.sh ~/messy ~/backups         # timestamped .tar.gz
```

---

## 📋 Command Cheat-Sheet (all parts)

### Windows: diagnostics & onboarding
| Task | Command |
|------|---------|
| OS build | `Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'` |
| Activation status | `slmgr /dli` |
| File system per drive | `fsutil fsinfo volumeinfo C:\` |
| Boot mode | `(Get-ComputerInfo).BiosFirmwareType` · `bcdedit /enum '{current}'` · `msinfo32` → *BIOS Mode* |
| System file check | `sfc /scannow` |
| Disk check (online) | `chkdsk C: /scan` |
| Repair component store | `DISM /Online /Cleanup-Image /RestoreHealth` |
| Create standard user | `net user jsmith * /add` |
| Shrink / partition / format | `diskpart` → `shrink desired=` · `create partition primary` · `format fs=ntfs quick` |
| Restore point | `Checkpoint-Computer -Description "x"` · verify `Get-ComputerRestorePoint` |
| Defender schedule | `Set-MpPreference -ScanScheduleDay 0 -ScanScheduleTime 02:00:00` |
| BitLocker status | `manage-bde -status E:` |

### Windows: networking
| Task | Command |
|------|---------|
| Static IP | `New-NetIPAddress -InterfaceAlias Ethernet -IPAddress 192.168.1.50 -PrefixLength 24 -DefaultGateway 192.168.1.1` |
| DNS | `Set-DnsClientServerAddress -InterfaceAlias Ethernet -ServerAddresses 192.168.1.1,8.8.8.8` |
| Block a port | `New-NetFirewallRule -DisplayName "Block 8080" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Block` |
| Test a port | `Test-NetConnection 192.168.1.50 -Port 8080` |
| Share a folder | `New-SmbShare -Name TeamDocs -Path C:\Shares\TeamDocs -ChangeAccess jsmith` |
| Map a drive | `net use Z: \\IT-WS01\TeamDocs /user:IT-WS01\jsmith *` |
| Enable RDP | `Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' fDenyTSConnections 0` |
| SSH server | `Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0` |

### Linux (WSL)
| Task | Command |
|------|---------|
| Disk usage | `df -hT` · `du -h --max-depth=1 ~ \| sort -rh \| head` |
| Backup | `tar -czf backup_$(date +%Y%m%d_%H%M%S).tar.gz dir/` |
| Cron (hourly) | `0 * * * * /path/disk_check.sh` |
| Permissions | `chmod 750 file` · `chown alice:devs file` |
| Users | `sudo adduser x` · `sudo usermod -aG sudo x` · `id x` |
| Network | `ip a` · `ping -c4 host` · `ss -tulpn` · `curl -I https://example.com` |
| Monitor | `htop` |

### Application lifecycle
| Task | Command |
|------|---------|
| Silent EXE | `setup.exe /S` (NSIS) · vendor-specific switches vary |
| Silent MSI | `msiexec /i app.msi /qn /norestart /L*v install.log` |
| Silent uninstall | `msiexec /x {GUID} /qn` · `winget uninstall --id <id> --silent` |
| Restrict access | `icacls C:\Restricted /inheritance:r /grant Administrators:(OI)(CI)F` |
| Run as other user | `runas /user:IT-WS01\jsmith cmd` |

---

## 📸 Screenshot Index

Save screenshots in the `screenshots/` folder next to the README that references them, using the names below. **Blur or crop** anything sensitive: recovery keys, public IPs, real usernames, license keys, personal emails.

| # | File | What to capture | Folder |
|---|------|-----------------|--------|
| P1 | `p1-01-diagnostic-run.png` | Script running in an elevated PowerShell window | windows-scripts |
| P1 | `p1-02-report-sections.png` | Report file open showing OS / disk / process sections | windows-scripts |
| P1 | `p1-03-fsutil-volumes.png` | `fsutil fsinfo volumeinfo` output for each drive | windows-scripts |
| P1 | `p1-04-boot-mode.png` | `msinfo32` *BIOS Mode* + `bcdedit` output | windows-scripts |
| P1 | `p1-05-sfc-dism-chkdsk.png` | Completion messages of SFC, CHKDSK and DISM | windows-scripts |
| P2 | `p2-01-user-created.png` | `net user jsmith` + `net localgroup Users` / `Administrators` | windows-scripts |
| P2 | `p2-02-diskpart-shrink.png` | `shrink` in diskpart (or Disk Management) | windows-scripts |
| P2 | `p2-03-new-partition.png` | New NTFS volume in `Get-Volume` / Disk Management | windows-scripts |
| P2 | `p2-04-update-pause.png` | Settings showing "Updates paused until…" + registry values | windows-scripts |
| P2 | `p2-05-restore-point.png` | `Get-ComputerRestorePoint` output | windows-scripts |
| P2 | `p2-06-theme-gui.png` | Settings → Personalization → Colors (before / after) | windows-scripts |
| P2 | `p2-07-theme-powershell.png` | Same change done via registry / PowerShell | windows-scripts |
| P2 | `p2-08-bitlocker-gui.png` | Control Panel → BitLocker Drive Encryption | windows-scripts |
| P2 | `p2-09-bitlocker-verify.png` | `manage-bde -status` + `Get-MpPreference` schedule | windows-scripts |
| P5 | `p5-01-silent-install.png` | Silent install + exit code | windows-scripts |
| P5 | `p5-02-uninstall-clean.png` | `Test-AppLeftovers.ps1` result after uninstall | windows-scripts |
| P5 | `p5-03-requirements-check.png` | `Test-AppRequirements.ps1` PASS/FAIL table | windows-scripts |
| P5 | `p5-04-portable-vs-installer.png` | Installer (Uninstall entry) vs portable (none) | windows-scripts |
| P5 | `p5-05-access-denied.png` | "Access is denied" as `jsmith` | windows-scripts |
| P3 | `p3-01-static-ip.png` | `ipconfig /all` after static config | networking-notes |
| P3 | `p3-02-firewall-block.png` | `Test-NetConnection` success → block → fail | networking-notes |
| P3 | `p3-03-discovery.png` | Network view with discovery on vs off | networking-notes |
| P3 | `p3-04-smb-share.png` | `Get-SmbShare` + access from second device | networking-notes |
| P3 | `p3-05-net-use.png` | `net use` listing + mapped drive in Explorer | networking-notes |
| P3 | `p3-06-printer.png` | Shared printer + client connection | networking-notes |
| P3 | `p3-07-rdp.png` | RDP session window | networking-notes |
| P3 | `p3-08-ssh.png` | SSH session to the second machine | networking-notes |
| P3 | `p3-09-workgroup.png` | `sysdm.cpl` / `Win32_ComputerSystem` workgroup value | networking-notes |
| P6 | `p6-01-onedrive-sync.png` | Sync client status + synced folder | networking-notes |
| P6 | `p6-02-conflict.png` | Conflicted copy / version history | networking-notes |
| P6 | `p6-03-share-view.png` | View-only link being refused edit | networking-notes |
| P6 | `p6-04-share-edit.png` | Edit link successfully editing | networking-notes |
| P6 | `p6-05-cloud-suite.png` | Cloud office suite (Docs / Office online) in a browser | networking-notes |
| P4 | `p4-01-disk-check.png` | `disk_check.sh` output with a warning line | linux-scripts |
| P4 | `p4-02-backup.png` | Backup script output + `ls -lh ~/backups` | linux-scripts |
| P4 | `p4-03-cron.png` | `crontab -l` + log file growing | linux-scripts |
| P4 | `p4-04-messy-before-after.png` | Messy folder before / after organising | linux-scripts |
| P4 | `p4-05-permissions-matrix.png` | `permission_test.sh` matrix | linux-scripts |
| P4 | `p4-06-user-sudo.png` | `id devuser` + `sudo whoami` as that user | linux-scripts |
| P4 | `p4-07-network-cmds.png` | `ip a`, `ss -tulpn`, `curl` results | linux-scripts |
| P4 | `p4-08-htop.png` | `htop` with a busy process | linux-scripts |

---

## ⚠️ Safety & Good Practice

- **Do all destructive work in a VM** (partitioning, firewall changes, static IPs, BitLocker) and take a snapshot first.
- **Never commit secrets:** recovery keys, passwords, license keys, tokens. Add generated reports to `.gitignore` (e.g. `Diagnostics/`), because they contain hostnames and installed software lists.
- Commands that take a password on the command line leave it in history. Use the `*` prompt form (`net user jsmith * /add`) or `Read-Host -AsSecureString`.
- Registry edits: export the key first (`reg export <key> backup.reg`).
- Scripts must be saved with **LF** line endings for Linux. Add a `.gitattributes` with `*.sh text eol=lf` if you keep script files in the repo.

---

## 🧠 Key Takeaways

- **Automate what you repeat.** The diagnostic script turns a 30-minute manual checklist into one command with a saved, timestamped report.
- **Every GUI action has a CLI twin,** and the CLI version is repeatable, auditable and scalable (see the theme comparison in Part 2).
- **Test, don't assume.** Firewall rules, permissions and shares are only "done" once a second device or user has proved the expected allow/deny behaviour.
- **Least privilege:** standard user by default, `sudo` only where needed, NTFS/share permissions scoped to the group that needs them.
- **Know the model:** workgroup vs domain, RDP vs SSH vs remote-support tools, storage vs SaaS. Choosing the right tool matters as much as knowing the command.

---

## 📄 License

Documentation released under the MIT License. Use it, adapt it, and test everything in a lab before using it on production machines.
