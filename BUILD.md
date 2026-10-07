# Build and install

## Codespaces

Requirements: .NET 8 SDK and Python 3.

```sh
python3 scripts/validate_project.py
dotnet build src/ApexToolbox/ApexToolbox.csproj
```

The WinForms application targets Windows and cannot run in Linux Codespaces. A successful cross-target build verifies compilation and packaged resources, not Windows runtime behavior.

## Windows 11

Build Requirements: .NET 8 SDK, Python 3, Windows PowerShell 5.1 or later, and 7-Zip CLI for Playbook packaging. A regular `BuildApex.ps1` deployment requires the .NET 8 Windows Desktop Runtime on its target PC. Run:

```powershell
.\scripts\ValidateProject.ps1
if ($LASTEXITCODE -ne 0) { throw 'Apex validation failed.' }
.\scripts\BuildApex.ps1
```

Build validates first and writes `dist\ApexDesktop`. Copy that directory to `C:\Windows\ApexDesktop` to install. Building does not modify Windows or create an ISO. Launch `Apex Toolbox.exe`; begin with Diagnostics and Backup & Restore. Test changes in a disposable VM first.

## AME Wizard Playbook

The source project is in `playbook-source/`. It uses AME Wizard's `playbook.conf` XML metadata plus `Configuration/main.yml`, task YAML, and an `Executables/` installer. The task only installs the already-built ApexDesktop payload and delegates default desktop wallpaper application to Apex's existing `Wallpaper.ps1`. The AME Playbook explicitly disables ISO support.

To create `dist\ApexOS.apbx`, run this on Windows from the repository root:

```powershell
.\scripts\BuildApexPlaybook.ps1
```

Then, in AME Wizard on the supported Windows 11 installation, select `dist\ApexOS.apbx` and apply the Apex OS Playbook. After completion, launch `C:\Windows\ApexDesktop\Apex Toolbox.exe`.

Requirements: Windows PowerShell 5.1, Python 3.10+, the .NET 8 SDK, both default files `Wallpapers\Apex-Dark.jpg` and `Wallpapers\Apex-LockScreen-Dark.jpg`, and 7-Zip CLI (`C:\Program Files\7-Zip\7z.exe`; use `-SevenZipPath` if installed elsewhere). The builder runs project and Playbook validation, calls the existing `BuildApex.ps1` to publish self-contained for the packaging host's x64 or ARM64 architecture, stages ApexDesktop and available supported wallpaper files, then invokes 7-Zip with AME's established archive password (`malte`) to create a password-protected 7z-format `.apbx` archive. It does not create a ZIP or ISO. No separate .NET runtime is needed on the installed PC. The source targets the current public AME Wizard/Trusted-Uninstaller Playbook schema (verified against upstream commit `f325e9d950e6b37003a46c786fd1b6c20f3180dd`). The final archive must still be opened and test-installed with the exact target AME Wizard release on Windows before distribution.

Existing files in `C:\Windows\ApexDesktop\Wallpapers\` are preserved during Playbook installation, including same-named wallpaper files. The built-in `Apex-Dark.jpg` is applied as desktop background only when present. The lock-screen image is included when supplied; Windows or Apex Toolbox can select it where Windows permits.

When the protected install directory is not writable, scripts and Toolbox logs fall back to `%LOCALAPPDATA%\ApexOS`. Some restore operations require elevation. Canceling UAC is reported as failure. No action automatically reboots Windows.

Use [docs/WINDOWS-VM-TESTING.md](docs/WINDOWS-VM-TESTING.md) for the disposable-VM functional test matrix. Its checks have not been run as part of the Codespaces build.