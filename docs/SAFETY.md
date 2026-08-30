# Safety and Behavior

WinCare Toolkit uses conservative defaults and keeps disruptive actions opt-in.

## Preserved by default

The toolkit is designed to preserve:

- Browser profiles and browser data
- Game data
- Shader caches
- Downloads
- Documents
- Recycle Bin contents during normal and scheduled maintenance

## Actions WinCare does not perform automatically

WinCare Toolkit does not automatically:

- Reboot Windows
- Run DISM `/ResetBase`
- Reset Winsock
- Renew DHCP
- Empty the Recycle Bin
- Delete browser profiles
- Delete game data
- Delete shader caches
- Modify BIOS settings
- Run registry cleaners
- Update drivers
- Manually defragment SSD/NVMe drives

## Cleanup policy

Monthly Maintenance targets TEMP files older than 14 days and archived Windows Error Reporting files older than 30 days. The Recycle Bin is preserved.

Aggressive Cleanup is manual only. It targets TEMP files older than 7 days and WER reports older than 14 days. The Recycle Bin remains preserved unless the user separately confirms a full empty operation.

## Network actions

Network configuration viewing is diagnostic. DNS flush, DHCP renewal, and Winsock reset are troubleshooting actions. DHCP renewal may briefly interrupt network connectivity. Winsock reset normally requires a restart before its effects are fully applied.

## Windows repair

DISM ScanHealth is used as the diagnostic starting point. RestoreHealth and SFC remain optional. The toolkit does not run `/ResetBase`.

## Antivirus behavior

WinCare Toolkit reports registered antivirus providers and Windows Firewall state. Microsoft Defender scans are skipped when Defender is not the active antivirus provider.

## Logs

Operations generate timestamped text logs and JSON history so actions and results can be reviewed after a run.
