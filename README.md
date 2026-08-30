# WinCare Toolkit v2.3.2

Windows maintenance and diagnostics toolkit built in PowerShell.

WinCare Toolkit provides one CLI for system health checks, conservative cleanup, security status, storage reporting, network troubleshooting, Windows repair, and maintenance logging. The toolkit is designed around explicit user confirmation and safe defaults.

## Highlights

- Windows PowerShell 5.1 compatible CLI
- System Health Audit with uptime, restart state, device health, stability, storage, security, firewall, and DISM health
- Monthly Maintenance with conservative TEMP and WER cleanup
- Security Check with registered antivirus detection, firewall state, and Quick Scan when supported
- Read-only Storage Report with largest Downloads files and top-level profile folders
- Network Troubleshooting for configuration, DNS flush, DHCP renewal, and confirmed Winsock reset
- Windows Repair workflow using DISM ScanHealth, optional RestoreHealth, and SFC
- Defender Full Scan only when Microsoft Defender is the active antivirus
- Windows-native Recycle Bin cleanup with explicit EMPTY confirmation
- Manual Aggressive Cleanup with 7-day TEMP and 14-day WER retention, plus optional full Recycle Bin emptying
- Toolkit Self Check for required commands, paths, and runtime capabilities
- Timestamped text logs and JSON history for each operation

## Safety model

WinCare Toolkit uses conservative defaults. It does not automatically reboot Windows, run DISM /ResetBase, reset DNS or Winsock, renew DHCP, empty the Recycle Bin, delete browser profiles, delete game data, delete shader caches, modify BIOS settings, run registry cleaners, update drivers, or manually defragment SSD/NVMe drives.

Destructive or disruptive troubleshooting actions remain opt-in. Recycle Bin cleanup requires a separate `EMPTY` confirmation. Aggressive Cleanup requires `CLEAN` before cleanup begins.

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1
- Administrator privileges

## Quick start

1. Download and extract the release ZIP.
2. Run `Run-WinCare Toolkit v2.3.2.cmd`.
3. Approve the Administrator prompt.
4. Start with `System Health Audit` or `Toolkit Self Check`.
5. Review the generated report and next steps.

For a first installation, see [Quick Start](docs/QUICK-START.md).

## Main menu

| Option | Function |
| --- | --- |
| 1 | Monthly Maintenance |
| 2 | System Health Audit |
| 3 | Security Check |
| 4 | Storage Report |
| 5 | Network Troubleshooting |
| 6 | Windows Repair |
| 7 | Defender Full Scan |
| 8 | Empty Recycle Bin |
| 9 | Aggressive Cleanup |
| 10 | Toolkit Self Check |

## Maintenance policy

Default Monthly Maintenance removes TEMP files older than 14 days and archived Windows Error Reporting files older than 30 days. It preserves the Recycle Bin. It also runs DISM StartComponentCleanup without `/ResetBase`, checks restart state, storage health, antivirus and firewall state, and Windows image health.

Aggressive Cleanup is manual only. It targets TEMP files older than 7 days and WER reports older than 14 days. The Recycle Bin stays preserved unless the user separately confirms a full Windows-native empty operation.

## Logs

WinCare Toolkit stores run data under:

```text
C:\ProgramData\WinCare ToolkitV232\Logs
C:\ProgramData\WinCare ToolkitV232\History
```

Each top-level operation receives its own timestamped text log and JSON record. `Latest.json` provides the most recent JSON result.

## Scheduled maintenance

`Install-Monthly-Task.ps1` installs the supported monthly maintenance task. Run Monthly Maintenance manually at least once before enabling scheduling.

An optional quarterly Microsoft Defender Full Scan installer is also included. Defender scans are skipped when Defender is not the active antivirus provider.

To remove installed scheduled tasks, use `Uninstall-Scheduled-Tasks.ps1`.

## Screenshots

Add release screenshots under `docs/screenshots/`. Recommended captures:

- Main menu
- System Health Audit
- Storage Report
- Toolkit Self Check
- Aggressive Cleanup result

## Documentation

- [Quick Start](docs/QUICK-START.md)
- [Safety and Behavior](docs/SAFETY.md)
- [Changelog](CHANGELOG.md)
- [Release Notes](RELEASE-NOTES.md)
- [Security Policy](SECURITY.md)

## Release status

V2.3.2 is the stable CLI baseline. Core functions have been manually tested on Windows before release packaging.

## License

Released under the [MIT License](LICENSE).
