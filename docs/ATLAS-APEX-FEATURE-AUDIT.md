# Atlas to Apex Feature Audit

This is a technical comparison of the supplied Atlas Playbook configuration and scripts against the Apex scripts, Toolbox action catalog, and AME playbook. Atlas files remain reference-only and are not included in the Apex payload.

| Area | Atlas reference behavior | Apex status | Apex decision |
| --- | --- | --- | --- |
| Consumer AppX removal | Removes a broad set of inbox apps and can remove Store/Xbox packages. | PARTIALLY IMPLEMENTED | Apex exposes an allowlist of current-user consumer apps with snapshots and restore. Store removal is separate and warns about consequences. Protected runtimes/services are not targeted. |
| Service startup changes | Changes multiple Windows service start types, including diagnostic, sync, networking, and GPU-related services. | INTENTIONALLY EXCLUDED | Broad static service lists are build- and device-sensitive and can break updates, Defender, networking, Bluetooth, audio, GPU support, and recovery. Apex leaves services unchanged. |
| Scheduled task reduction | Disables selected Application Experience, AppX deployment, and usage-reporting tasks. | INTENTIONALLY EXCLUDED | There is no safe universal task allowlist for supported Windows builds; Apex does not disable scheduled tasks without per-build evidence and restore tests. |
| Privacy registry changes | Changes input, Office, NVIDIA, .NET CLI, and Windows diagnostic preferences. | PARTIALLY IMPLEMENTED | Apex currently offers reversible current-user Advertising ID and tailored diagnostic-personalization settings. It does not claim to disable OS telemetry or third-party product telemetry. |
| Telemetry services | Disables or alters telemetry-related services and components. | INTENTIONALLY EXCLUDED | No machine-wide telemetry service changes are made because their dependencies and policy behavior vary by Windows build and edition. |
| Windows consumer experiences | Removes or alters promoted apps, suggestions, and consumer experiences. | PARTIALLY IMPLEMENTED | Apex provides current-user removal for a bounded consumer-app allowlist. Advertising ID/personalization is reversible. No broad policy bundle is applied. |
| Windows features/capabilities | Adds/removes selected optional features and capabilities. | MISSING | Apex has no general feature/capability manager yet. It intentionally does not issue broad DISM removals from a copied list. |
| Startup items | Changes startup behavior and taskbar/browser startup choices. | PARTIALLY IMPLEMENTED | Apex inventories startup commands and links to Startup Apps settings; it does not yet provide per-entry disable/restore controls. |
| Background apps | Applies broad background-activity policies. | PARTIALLY IMPLEMENTED | RAM Saver has reversible Balanced/Aggressive user policy; Background Activity exposes startup/background settings. It does not kill processes or disable services. |
| Search/indexing | Applies reduced indexing profiles and search-related changes. | PARTIALLY IMPLEMENTED | Apex opens Search and Indexing Options and leaves Windows Search running. Per-location indexing profiles are not implemented. |
| Visual effects and animations | Applies performance-oriented UI effects changes. | IMPLEMENTED | Apex has a reversible visual-effects script and theme-aware Toolbox feedback. Windows UI effects are verified from current-user state. |
| Gaming/GameDVR | Changes Game Mode and capture preferences. | PARTIALLY IMPLEMENTED | Apex reversibly enables Game Mode and disables GameDVR/Game Bar capture values for the current user. It does not change machine policy or remove gaming components. |
| Fullscreen/game compatibility | Applies broad game-related compatibility changes. | INTENTIONALLY EXCLUDED | Global fullscreen/GPU/driver tweaks are title- and driver-specific. Apex provides per-app Graphics Settings and does not guess per-game settings. |
| Power plans | Selects a hard-coded built-in plan and processor values. | IMPLEMENTED | Apex enumerates real plans, dynamically clones an available source, verifies created GUIDs and activation, and reports supported processor settings. Maximum Performance and Custom profiles are exposed without fixed scheme GUID assumptions. |
| Network stack | Changes network defaults and can reset networking. | PARTIALLY IMPLEMENTED | Apex diagnoses adapters/gateway/TCP/DNS; safe repair flushes DNS only when indicated. Winsock/TCP-IP resets are separate Advanced, confirmed actions with a before-state backup and restart warning. |
| Explorer | Applies context-menu and Explorer shell changes. | PARTIALLY IMPLEMENTED | Apex supports reversible Windows 11/classic context-menu choices and Explorer restart. Other Atlas folder-discovery/tuning options are not copied. |
| Browser selection/install | Offers browser choices and installs selected browsers. | IMPLEMENTED | Apex first-run setup offers Chrome, Firefox, Brave, or Keep Existing. It only invokes the chosen exact WinGet package ID, does not silently change defaults, and checks local install presence afterward. Windows installation verification remains pending. |
| Optional software | Installs utilities and other selected packages. | IMPLEMENTED | Apex offers one optional game launcher, OBS, and NanaZip/7-Zip in first-run setup; the Software page permits individual installs. WinGet is only invoked after explicit selection. |
| Security/Defender | Atlas contains Defender-related changes, including disable paths. | INTENTIONALLY EXCLUDED | Apex never disables Defender, Firewall, Security Center, or Windows Update security mechanisms. It reads Defender/Firewall status and links to Windows Security. |
| Xbox/Gaming Services | Removes/changes some Xbox-related packages and dependencies. | INTENTIONALLY EXCLUDED | Apex preserves Xbox identity, Gaming Services, and Minecraft dependencies; only read-only diagnostics and optional Minecraft Launcher installation are provided. |
| Windows Update | Atlas changes update behavior/services/tasks. | INTENTIONALLY EXCLUDED | Apex does not disable update policy or update services. It provides Windows Update diagnostics/repair and a Settings link. |
| Compatibility | Atlas uses build-specific assumptions and package conditions. | PARTIALLY IMPLEMENTED | Apex reports Windows release/build and detects Edge/WebView2 and related compatibility components. No broad multi-build VM matrix has been run here. |
| Repair/recovery | Includes backup and reset/restore workflows. | IMPLEMENTED | Apex includes restore points, configuration backup, reversible registry snapshots, DISM/SFC, Windows Update cache repair, WinRE diagnostics, and action logs. These are not a full system image. |
| Lock-screen images | Uses Windows Runtime `LockScreen.SetImageFileAsync`. | PARTIALLY IMPLEMENTED | Apex uses that API, checks support and an active stream, and logs Windows rejection. The API does not expose the active image's source path, so exact-file identity is not claimed; real Windows verification is still required. |

## Source Areas Reviewed

- `AtlasOs Source/AtlasPlaybook_v0.5.0/Configuration/atlas/{appx,components,default,revert,services,start}.yml`
- `AtlasOs Source/AtlasPlaybook_v0.5.0/Configuration/tweaks.yml` and the `tweaks/{debloat,networking,performance,privacy,qol,security}` groups
- Atlas `Modules/{Debloat,Performance,Privacy,Qol,Scripts,Themes}` and browser/software setup scripts
- Apex `config/toolbox.json`, `scripts/`, `playbook-source/`, and `src/ApexToolbox/`

## Intentionally Not Ported

- Bulk machine-wide service/task disabling without per-build dependency tests and verified rollback.
- Defender, Firewall, Edge/WebView2, Xbox/Gaming Services, or Windows Update removal/disable operations.
- Fixed power GUIDs, generic telemetry bundles, or undocumented registry optimizations.
- Atlas branding, names, URLs, assets, package assumptions, and Atlas UI structure.

## Verification Boundary

This audit is source-based. Toolbox builds, project validation, playbook validation, and PowerShell parsing can be run in Codespaces, but Windows effects, WinGet package identity/availability, Defender/Firewall query results, network resets, powercfg behavior, desktop wallpaper, lock screen, and AME import/install must still be tested on a disposable Windows 11 system. None are represented here as Windows-runtime verified.