# Build and install

## Codespaces

Requirements: .NET 8 SDK and Python 3.

```sh
python3 scripts/validate_project.py
dotnet build src/ApexToolbox/ApexToolbox.csproj
```

The WinForms application targets Windows and cannot run in Linux Codespaces. A successful cross-target build verifies compilation and packaged resources, not Windows runtime behavior.

## Windows 11

Build requirements: .NET 8 SDK and Windows PowerShell 5.1 or later. The installed GUI also requires the .NET 8 Windows Desktop Runtime. Run:

```powershell
.\scripts\ValidateProject.ps1
if ($LASTEXITCODE -ne 0) { throw 'Apex validation failed.' }
.\scripts\BuildApex.ps1
```

Build validates first and writes `dist\ApexDesktop`. Copy that directory to `C:\Windows\ApexDesktop` to install. Building does not modify Windows or create an ISO. Launch `Apex Toolbox.exe`; begin with Diagnostics and Backup & Restore. Test changes in a disposable VM first.

When the protected install directory is not writable, scripts and Toolbox logs fall back to `%LOCALAPPDATA%\ApexOS`. Some restore operations require elevation. Canceling UAC is reported as failure. No action automatically reboots Windows.

Use [docs/WINDOWS-VM-TESTING.md](docs/WINDOWS-VM-TESTING.md) for the disposable-VM functional test matrix. Its checks have not been run as part of the Codespaces build.