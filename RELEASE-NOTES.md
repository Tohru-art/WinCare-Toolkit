# WinCare Toolkit v2.3.2 Release Notes

Release date: August 2026

V2.3.2 is the stable CLI baseline for WinCare Toolkit. This release focuses on conservative Windows maintenance, readable diagnostics, explicit confirmation for disruptive actions, and reliable PowerShell 5.1 behavior.

## Release highlights

- Full System Health Audit
- Conservative Monthly Maintenance
- Security and firewall checks
- Read-only Storage Report
- Network troubleshooting menu
- Guided Windows Repair workflow
- Defender scan handling that respects the active antivirus provider
- Windows-native Recycle Bin cleanup with explicit confirmation
- Manual Aggressive Cleanup
- Toolkit Self Check
- Per-run text and JSON logging

## Final fixes

The Storage Report now excludes Windows junctions and reparse points from top-level folder ranking. This prevents compatibility paths such as `Local Settings` from appearing as separate large folders when they point into other profile data.

The final cleanup design no longer relies on custom Recycle Bin metadata parsing. Windows-native `Clear-RecycleBin` is used only after explicit user confirmation.

## Recommended first run

Run Toolkit Self Check, then System Health Audit, then Monthly Maintenance manually. Enable scheduled maintenance only after those operations complete normally on the target PC.
