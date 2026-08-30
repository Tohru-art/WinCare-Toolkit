# WinCare Toolkit

> Safe Windows maintenance, diagnostics, cleanup, and troubleshooting from one PowerShell CLI.

![Version](https://img.shields.io/badge/version-2.3.2-blue)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?logo=windows&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green)

WinCare Toolkit is a PowerShell-based Windows maintenance and diagnostics utility built around conservative defaults, clear reporting, and explicit user confirmation. It combines system health auditing, safe cleanup, security checks, storage analysis, network troubleshooting, Windows repair, and maintenance logging in one menu-driven toolkit.

## Why WinCare Toolkit?

- One CLI for common Windows maintenance and diagnostic tasks
- Safe defaults that avoid destructive system changes
- Clear `[OK]`, `[INFO]`, and warning-oriented output
- Timestamped text logs and JSON history
- Read-only diagnostics where possible
- Explicit confirmation before disruptive or destructive actions
- Compatible with Windows PowerShell 5.1

## Core features

| Feature | What it does |
| --- | --- |
| System Health Audit | Reviews uptime, restart state, devices, stability, storage, security, firewall, and Windows image health |
| Monthly Maintenance | Performs conservative TEMP and WER cleanup plus supported Windows maintenance |
| Security Check | Reports registered antivirus providers, active protection state, firewall status, and supported scan behavior |
| Storage Report | Shows common folder usage, large Downloads files, top-level profile folders, and drive health |
| Network Troubleshooting | Shows network configuration and provides opt-in DNS, DHCP, and Winsock actions |
| Windows Repair | Runs DISM ScanHealth first, with optional RestoreHealth and SFC |
| Defender Full Scan | Runs only when Microsoft Defender is the active antivirus |
| Empty Recycle Bin | Permanently empties the Recycle Bin only after explicit confirmation |
| Aggressive Cleanup | Uses shorter TEMP/WER retention while preserving user data and the Recycle Bin by default |
| Toolkit Self Check | Validates required commands, paths, permissions, and runtime capabilities |

## Safety first

WinCare Toolkit is intentionally conservative.

It does not automatically:

- Reboot Windows
- Run DISM `/ResetBase`
- Reset Winsock
- Renew DHCP
- Empty the Recycle Bin
- Delete browser profiles or browser data
- Delete game data or shader caches
- Delete Downloads or Documents
- Modify BIOS settings
- Run registry cleaners
- Update drivers
- Manually defragment SSD/NVMe drives

Potentially disruptive actions remain opt-in. Aggressive Cleanup requires `CLEAN`. Recycle Bin cleanup requires a separate `EMPTY` confirmation.

See [Safety and Behavior](docs/SAFETY.md) for details.

## Quick start

### Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or later
- Administrator privileges

### Run

1. Download and extract the latest release ZIP.
2. Run `Run-WinCare-Toolkit-v2.3.2.cmd`.
3. Approve the Administrator prompt.
4. Start with `System Health Audit` or `Toolkit Self Check`.
5. Review the generated report and next steps.

For first-time setup, see the [Quick Start Guide](docs/QUICK-START.md).

## Main menu

| # | Function | Type |
| ---: | --- | --- |
| 1 | Monthly Maintenance | Maintenance |
| 2 | System Health Audit | Diagnostic |
| 3 | Security Check | Diagnostic |
| 4 | Storage Report | Read-only |
| 5 | Network Troubleshooting | Diagnostic / opt-in repair |
| 6 | Windows Repair | Diagnostic / opt-in repair |
| 7 | Defender Full Scan | Security |
| 8 | Empty Recycle Bin | Destructive, confirmed |
| 9 | Aggressive Cleanup | Manual cleanup |
| 10 | Toolkit Self Check | Validation |

## Maintenance behavior

Monthly Maintenance uses a conservative cleanup policy:

- TEMP files older than 14 days
- Archived Windows Error Reporting files older than 30 days
- Recycle Bin preserved
- DISM StartComponentCleanup without `/ResetBase`
- Restart-state, storage, antivirus, firewall, and Windows image checks

Aggressive Cleanup is manual only:

- TEMP files older than 7 days
- WER reports older than 14 days
- Recycle Bin preserved unless separately confirmed
- Browser data, game data, shader caches, Downloads, and Documents preserved

## Reports and history

WinCare Toolkit stores run data under:

```text
C:\ProgramData\WinCare ToolkitV232\Logs
C:\ProgramData\WinCare ToolkitV232\History
```

Each top-level operation creates a timestamped text log and JSON record. `Latest.json` contains the latest JSON result.

## Scheduled maintenance

`Install-Monthly-Task.ps1` installs the supported monthly maintenance task. Run Monthly Maintenance manually at least once before enabling scheduling.

`Install-Optional-Quarterly-Defender-Full-Scan.ps1` can install an optional quarterly Microsoft Defender Full Scan. Defender scans are skipped when Defender is not the active antivirus provider.

Use `Uninstall-Scheduled-Tasks.ps1` to remove installed WinCare scheduled tasks.

## Project structure

```text
WinCare-Toolkit/
├── WinCare-Toolkit-v2.3.2.ps1
├── Run-WinCare-Toolkit-v2.3.2.cmd
├── Run-System-Audit.cmd
├── Run-Monthly-Maintenance.cmd
├── Run-Aggressive-Cleanup.cmd
├── Run-Toolkit-Self-Check.cmd
├── Install-Monthly-Task.ps1
├── Install-Optional-Quarterly-Defender-Full-Scan.ps1
├── Uninstall-Scheduled-Tasks.ps1
├── docs/
│   ├── QUICK-START.md
│   └── SAFETY.md
├── CHANGELOG.md
├── RELEASE-NOTES.md
├── SECURITY.md
└── LICENSE
```

## Documentation

- [Quick Start Guide](docs/QUICK-START.md)
- [Safety and Behavior](docs/SAFETY.md)
- [Changelog](CHANGELOG.md)
- [Release Notes](RELEASE-NOTES.md)
- [Security Policy](SECURITY.md)

## Release status

Current stable CLI baseline: `v2.3.2`

Core functions have been manually tested on Windows before release packaging. WinCare Toolkit remains focused on predictable behavior, transparent output, and conservative maintenance.

## License

Released under the [MIT License](LICENSE).
