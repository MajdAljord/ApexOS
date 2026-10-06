# Windows 11 VM Test Procedure

These tests are **not passed** by the Codespaces build. Run them on disposable Windows 11 VMs. Use one standard-user VM and one administrator-capable VM; snapshot both before installing Apex. Keep the VM network isolated for repair scenarios and never test by disrupting a host or production connection.

## Setup

1. Create a clean Windows 11 VM with a checkpoint/snapshot and a separate test account. For laptop-specific power behavior, also test on physical laptop hardware; a VM cannot validate battery/AC policy.
2. Install the .NET 8 Windows Desktop Runtime. Copy `dist\ApexDesktop` to `C:\Windows\ApexDesktop` and launch `Apex Toolbox.exe`.
3. Record Windows edition, `DisplayVersion`, build, architecture, and active power-plan GUID. Keep Windows Security and Windows Update enabled.
4. From the repository checkout, run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\BuildApex.ps1`; the build runs `ValidateProject.ps1` before publishing.
5. Copy `dist\ApexDesktop` to `C:\Windows\ApexDesktop`, launch Apex Toolbox, and run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Windows\ApexDesktop\scripts\TestApexWindows.ps1`. This is a read-only status smoke test only; record its output and exit code.

## Functional checklist

Record each result as `Not run`, `Passed`, or `Failed`, plus the build number and Apex log path. Do not mark a row passed until you perform it on Windows.

| Area | Procedure | Verify |
| --- | --- | --- |
| 26H2 compatibility | On a VM reporting `DisplayVersion=26H2`, open Windows Compatibility in Apex; repeat on an unsupported Windows build in a separate VM. | Release/build/architecture match Windows; unknown build warning appears; unsupported client has modifying actions disabled. |
| Elevation | Run a `requiresAdmin` action as standard user, accept UAC, then repeat and cancel UAC. | Accepted action returns its script exit code; canceled elevation reports failure and log path. |
| Power plans | Record `powercfg /getactivescheme`; select each Apex profile; inspect plans with `powercfg /list`; select Restore. | Active GUID follows selection; restore reactivates recorded prior GUID; AC/DC processor values are as documented; plans remain installed. |
| Laptop power | On a physical laptop, inspect Apex Laptop Performance while plugged in and on battery. | Battery limits stay below AC limits; sleep, thermal, and battery behavior remain normal. |
| RAM Saver | Record the target HKCU `GlobalUserDisabled` value; apply Balanced, then Aggressive, then Restore. | Status reports each actual value; restore returns the original existence, type, and value; app background behavior is understood. |
| Gaming Mode | Record the three Gaming/GameDVR registry values; enable and restore Gaming Mode. | Every value matches its snapshot after restore; Game Bar/Game Mode and a supported game still work. |
| Explorer context menu | Capture the CLSID branch with `reg export`; apply Classic, verify; switch to Windows 11, verify; restore. | Explorer restarts; each mode is visible; restore reproduces the captured branch. |
| Wallpaper/theme | Test each present wallpaper file, missing-file behavior, Dark/Light theme, transparency, and Restore. | Missing images fail honestly; current-user settings and prior wallpaper/theme return after restore. |
| Restore point | Enable System Protection if appropriate, create an Apex restore point, inspect System Protection. | Windows reports the point or Apex reports the actual failure; no reboot occurs. |
| Apex backup/restore | Create a backup, alter a harmless Apex config copy or test snapshot, then restore. | Archive contents and recovered files are correct; no claim is made about Windows-wide rollback. |
| Optional app removal | In a disposable test account only, remove one allowlisted package and attempt Restore. | Only current-user package changes; protected components remain installed; restore succeeds only if manifest is retained, otherwise reports the limitation. |
| Store/Edge/WebView2 | Record Store package, Edge executable, and WebView2 version; optionally remove Store for the test user and attempt restore. | Edge and WebView2 are reported independently; neither is removed; Store removal is explicit and Store-dependent apps are retested. |
| Chrome/NanaZip | Test with each app installed and absent; open Windows Default apps; inspect `.zip`, `.7z`, `.rar`, `.tar`, `.gz`, `.bz2`, `.xz`. | Missing software is reported; Windows owns association changes; no UserChoice hash is edited. |
| Driver Center | Run inventory, problem-device scan, each device-class report, CSV export, and Windows Update driver search. | Provider/version/date/device IDs are plausible; search only lists updates and installs none. |
| Network | Run diagnostics on healthy, disconnected, DNS-failure, and gateway-failure VM network states. Run Safe Recovery only in the isolated VM. | Category is evidence-based; DNS cache is flushed only when the specified preconditions hold; result is re-tested; no driver reset/reboot occurs. |
| SFC/DISM | Run verify/check/scan first; run SFC repair and DISM RestoreHealth only on a checkpointed VM. | Output and exit codes match Windows logs; progress remains visible; no automatic reboot occurs. |
| Windows Update repair/restore | In a checkpointed VM, run update diagnostics, cache repair, verify services, then click Restore. | Cache folders are renamed, not deleted; prior caches return, generated caches remain renamed, and previously running services return to Running. Windows Update can scan/install afterward. |
| Installer/Explorer | Run Installer diagnostics and re-register; restart Explorer from both Explorer and Repair categories. | Installer remains usable; Explorer returns; no unsaved test work is lost. |
| Gaming/Xbox/WinRE | Run Gaming Services, Microsoft/Xbox sign-in, and WinRE diagnostics. Test Minecraft/Xbox sign-in if installed. | These tools only report; authentication, Gaming Services, WinRE, and games remain functional. |
| First run | On a fresh VM profile, test Skip; then another profile with one selection at a time, including restore-point failure and missing Chrome/NanaZip. | Skip is available; only selected actions run; first failing script stops the sequence and reports its code/log. |

For Windows Update cache recovery, Apex renames cache directories to `*.ApexBackup-<timestamp>` beneath `%windir%`; it does not delete them or provide an automatic cache-folder rollback. Use the VM checkpoint if you need to revert the complete test state.