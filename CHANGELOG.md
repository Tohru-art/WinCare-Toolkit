# Changelog

## V2.3.2, August 2026

Stable CLI and release-hardening baseline.

### Added

- Toolkit Self Check with runtime and capability validation
- Timestamped text logs and JSON history per top-level operation
- Overall Status and Next Steps summaries
- Human-readable uptime and storage sizes
- Restart-state analysis
- VirtualBox-aware disabled-device reporting
- Event 41 stability context
- Antivirus registration and firewall reporting
- Largest Downloads files and top-level user-profile folder reporting
- Dedicated launchers for audit, monthly maintenance, aggressive cleanup, and self check
- Optional quarterly Defender Full Scan task installer

### Cleanup and safety

- Monthly TEMP retention set to 14 days
- Monthly WER retention set to 30 days
- Monthly/default maintenance preserves the Recycle Bin
- Aggressive Cleanup uses 7-day TEMP and 14-day WER retention
- Recycle Bin emptying uses Windows-native `Clear-RecycleBin`
- Recycle Bin cleanup requires a separate `EMPTY` confirmation
- Aggressive Cleanup requires `CLEAN` confirmation
- Removed custom Recycle Bin metadata deletion from the final cleanup path
- No automatic reboot
- No DISM `/ResetBase`
- No automatic network reset

### Windows repair

- DISM ScanHealth runs first
- RestoreHealth and SFC remain opt-in
- SFC is dependent on successful RestoreHealth when the repair path is selected
- Guidance explains when repair actions are unnecessary

### Storage reporting

- Added scanning progress text for long profile scans
- Excluded AppData from top-level ranking
- Excluded junction/reparse-point folders to prevent compatibility paths such as `Local Settings` from duplicating storage usage
- Storage Report remains read-only

### CLI stabilization

- Replaced Unicode UI elements with ASCII for Windows PowerShell 5.1 compatibility
- Improved alignment and status presentation
- Added run date and log filename to report headers
- Launcher keeps the terminal open on startup or parser errors

## Earlier versions

V1 introduced the initial prototype. V2 separated maintenance from troubleshooting. V2.1 improved unattended safety and documentation. V2.2 added contextual diagnostics, antivirus detection, reboot analysis, device handling, stability context, storage scoring, and JSON history. V2.2.1 expanded the CLI before the interface was standardized around ASCII in V2.3.2.
