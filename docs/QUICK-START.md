# WinCare Toolkit Quick Start

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or later
- Administrator privileges

## First run

1. Download and extract the WinCare Toolkit release ZIP.
2. Keep the included files together in the extracted folder.
3. Run `Run-WinCare-Toolkit-v2.3.2.cmd`.
4. Approve the Windows Administrator prompt.
5. Select `Toolkit Self Check` to validate the environment.
6. Run `System Health Audit` for a read-oriented overview of the PC.
7. Review the on-screen status, next steps, and generated logs.

## Recommended first-use order

1. Toolkit Self Check
2. System Health Audit
3. Security Check
4. Storage Report
5. Monthly Maintenance, only when you are ready to perform maintenance

Network troubleshooting, Windows repair, Recycle Bin cleanup, Aggressive Cleanup, and full antivirus scanning should be used when needed rather than as routine first-run actions.

## Logs

Run history is stored under:

```text
C:\ProgramData\WinCare ToolkitV232\Logs
C:\ProgramData\WinCare ToolkitV232\History
```

Each top-level operation creates a timestamped text log and JSON record.

## Important confirmations

Some operations require explicit confirmation before they run.

- Aggressive Cleanup requires `CLEAN`.
- Full Recycle Bin cleanup requires `EMPTY`.
- Winsock reset requires confirmation.
- Windows repair actions beyond ScanHealth are optional.

See [Safety and Behavior](SAFETY.md) before using repair or cleanup functions.
