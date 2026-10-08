# Apex OS

Apex OS is an independent Windows 11 configuration and diagnostics toolkit targeting modern Windows 11, including 26H2. Compatibility with each Windows build and physical hardware must be verified on that system. It favors reversible, opt-in changes and preserves Windows Update, Defender, recovery, networking, and application runtimes.

The project builds **Apex Toolbox** and packages scripts into `C:\Windows\ApexDesktop\`. Its AME Wizard Playbook source and Windows `.apbx` packaging steps are documented in [BUILD.md](BUILD.md). It does not download Windows components, Chrome, NanaZip, third-party binaries, or create a Windows ISO.

The wallpaper library is `C:\Windows\ApexDesktop\Wallpapers\`. Apex Toolbox scans it whenever the Personalization page opens and includes JPG, JPEG, PNG, BMP, and WebP files (where supported by Windows); use **Refresh** after adding an image while the page is open. **Apex default** selects `Apex-Default-Dark.jpg`. Selecting a lock-screen image opens Windows Lock screen settings because Windows controls whether that image can be applied. Apex does not remove user-added wallpaper files.

See [BUILD.md](BUILD.md) for Codespaces and Windows instructions and [docs/SAFETY.md](docs/SAFETY.md) before applying settings. A configuration backup is not a full system image.