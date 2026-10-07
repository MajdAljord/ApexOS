#!/usr/bin/env python3
"""Validate the AME Playbook source and staged ApexDesktop payload."""
import argparse
import json
import pathlib
import re
import sys
import uuid
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "playbook-source"
errors: list[str] = []


def require_file(path: pathlib.Path, label: str) -> bool:
    if not path.is_file():
        errors.append(f"Missing {label}: {path.relative_to(ROOT)}")
        return False
    return True


def relative_inside(base: pathlib.Path, relative: str, label: str) -> pathlib.Path | None:
    candidate = (base / relative.replace("\\", "/")).resolve()
    try:
        candidate.relative_to(base.resolve())
    except ValueError:
        errors.append(f"Unsafe {label} path: {relative}")
        return None
    return candidate


def validate_source() -> None:
    manifest = SOURCE / "playbook.conf"
    main = SOURCE / "Configuration" / "main.yml"
    task = SOURCE / "Configuration" / "tasks" / "install-apex.yml"
    launcher = SOURCE / "Executables" / "Install-Apex.ps1"
    source_files_exist = True
    for path in (manifest, main, task, launcher):
        source_files_exist = require_file(path, "Playbook source") and source_files_exist
    if not source_files_exist:
        return

    try:
        metadata = ET.parse(manifest).getroot()
    except ET.ParseError as exc:
        errors.append(f"Invalid AME playbook.conf XML: {exc}")
        return

    for field in ("Name", "Username", "ShortDescription", "Title", "Description", "Version", "UniqueId"):
        if not (metadata.findtext(field) or "").strip():
            errors.append(f"AME playbook.conf is missing {field}.")
    if metadata.tag != "Playbook":
        errors.append("AME metadata root element must be Playbook.")
    if (metadata.findtext("Name") or "").strip() != "Apex OS":
        errors.append("Playbook Name must use Apex OS branding.")
    if (metadata.findtext("SupportsISO") or "").strip().lower() != "false":
        errors.append("Playbook must explicitly disable ISO support.")
    if metadata.find("ISO") is not None or metadata.find("OOBE") is not None:
        errors.append("This deployment Playbook must not define ISO or OOBE media functionality.")
    if not re.fullmatch(r"\d+(?:\.\d+){0,2}", (metadata.findtext("Version") or "").strip()):
        errors.append("Playbook version must use AME's numeric version format (for example, 1.0.0).")
    try:
        if not metadata.findtext("UniqueId") or uuid.UUID(metadata.findtext("UniqueId", "")) == uuid.UUID(int=0):
            errors.append("Playbook UniqueId must be a non-empty UUID.")
    except ValueError:
        errors.append("Playbook UniqueId must be a valid UUID.")

    wallpaper_source = ROOT / "Wallpapers"
    for default in ("Apex-Dark.jpg", "Apex-LockScreen-Dark.jpg"):
        if not (wallpaper_source / default).is_file():
            errors.append(f"Required Apex default wallpaper is missing: Wallpapers/{default}")

    main_text = main.read_text(encoding="utf-8")
    referenced_tasks = re.findall(r"!task\s*:\s*\{[^}]*\bpath\s*:\s*['\"]([^'\"]+)['\"]", main_text)
    if not referenced_tasks:
        errors.append("Configuration/main.yml must reference a task with an AME !task action.")
    for relative in referenced_tasks:
        path = relative_inside(main.parent, relative, "AME task")
        if path is not None and not path.is_file():
            errors.append(f"Missing referenced AME task: {path.relative_to(ROOT)}")

    task_text = task.read_text(encoding="utf-8")
    if "!powerShell:" not in task_text and "!run:" not in task_text:
        errors.append("AME install task must use a supported !powerShell or !run action.")
    if "currentUserElevated" not in task_text:
        errors.append("AME install action must explicitly use currentUserElevated privilege.")
    if not re.search(r"Install-Apex\.ps1", task_text, re.IGNORECASE):
        errors.append("AME install task does not invoke the Apex installer.")

    launcher_text = launcher.read_text(encoding="utf-8")
    for expected in ("ApexDesktop", "Apex-Dark.jpg", "Wallpaper.ps1", "Apex-LockScreen-Dark.jpg"):
        if expected not in launcher_text:
            errors.append(f"Apex installer does not account for {expected}.")
    if "Join-Path $env:WINDIR 'ApexDesktop'" not in launcher_text:
        errors.append("Apex installer must install to the Windows ApexDesktop directory.")
    if "Copy-Item" not in launcher_text or "preserved" not in launcher_text.lower():
        errors.append("Apex installer must copy existing components and report wallpaper preservation.")
    if re.search(r"Remove-Item|robocopy\s+/MIR", launcher_text, re.IGNORECASE):
        errors.append("Apex installer must not delete existing installation or wallpaper files.")

    for path in SOURCE.rglob("*"):
        if not path.is_file():
            continue
        relative = path.relative_to(SOURCE)
        if path.suffix.lower() in {".iso", ".wim", ".esd"}:
            errors.append(f"Forbidden Windows media file in Playbook source: {relative}")

def validate_project_links(payload: pathlib.Path | None) -> None:
    config_path = ROOT / "config" / "toolbox.json"
    try:
        config = json.loads(config_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"Cannot validate Toolbox script references: {exc}")
        return

    scripts = [action.get("script", "") for action in config.get("actions", [])]
    for relative in scripts:
        source_script = relative_inside(ROOT, relative, "Toolbox script")
        if source_script is not None and not source_script.is_file():
            errors.append(f"Toolbox action references missing script: {relative}")
        if payload is not None:
            payload_script = relative_inside(payload, relative, "packaged Toolbox script")
            if payload_script is not None and not payload_script.is_file():
                errors.append(f"Packaged ApexDesktop is missing Toolbox script: {relative}")

    project = ROOT / "src" / "ApexToolbox" / "ApexToolbox.csproj"
    if require_file(project, "Apex Toolbox project"):
        project_text = project.read_text(encoding="utf-8")
        if "<TargetFramework>net8.0-windows</TargetFramework>" not in project_text:
            errors.append("Apex Toolbox requires its documented .NET 8 Windows target.")
        for include in ('../../config/toolbox.json', '../../config/protected-components.json', '../../scripts/**/*.ps1', '../../scripts/**/*.psm1'):
            if include not in project_text:
                errors.append(f"Apex Toolbox project does not package required content glob: {include}")

    module = ROOT / "scripts" / "Modules" / "Apex.Common.psm1"
    require_file(module, "Apex common PowerShell module")
    wallpaper_source = ROOT / "Wallpapers"
    if payload is not None:
        if not any((payload / name).is_file() for name in ("Apex Toolbox.exe", "Apex Toolbox.dll")):
            errors.append("Published Apex Toolbox executable/app assembly is missing.")
        require_file(payload / "Toolbox" / "config" / "toolbox.json", "packaged Toolbox configuration")
        require_file(payload / "Toolbox" / "config" / "protected-components.json", "packaged protected-components configuration")
        require_file(payload / "scripts" / "Modules" / "Apex.Common.psm1", "packaged Apex common module")

        wallpaper_payload = payload / "Wallpapers"
        supported = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
        if wallpaper_source.is_dir():
            for wallpaper in wallpaper_source.iterdir():
                if wallpaper.is_file() and wallpaper.suffix.lower() in supported and not (wallpaper_payload / wallpaper.name).is_file():
                    errors.append(f"Packaged ApexDesktop is missing source wallpaper: {wallpaper.name}")
            for default in ("Apex-Dark.jpg", "Apex-LockScreen-Dark.jpg"):
                if (wallpaper_source / default).is_file() and not (wallpaper_payload / default).is_file():
                    errors.append(f"Packaged ApexDesktop is missing default wallpaper: {default}")

    # Python is only the validator's runtime; AME executes its actions with Windows PowerShell.
    build = ROOT / "scripts" / "BuildApexPlaybook.ps1"
    if require_file(build, "Windows Playbook packager"):
        build_text = build.read_text(encoding="utf-8")
        for dependency in ("7z.exe", "BuildApex.ps1", "validate_project.py", "validate_playbook.py", "-t7z", "-pmalte", "-SelfContained", "-RuntimeIdentifier", "win-x64", "win-arm64"):
            if dependency not in build_text:
                errors.append(f"Windows Playbook packager is missing required dependency/format step: {dependency}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--payload", type=pathlib.Path, help="Validate a built dist/ApexDesktop payload too.")
    arguments = parser.parse_args()
    payload = arguments.payload.resolve() if arguments.payload else None
    validate_source()
    validate_project_links(payload)
    if errors:
        print("\n".join(f"ERROR: {error}" for error in errors), file=sys.stderr)
        return 1
    print("AME Playbook source and Apex references validated.")
    if payload is not None:
        print(f"Built ApexDesktop payload validated: {payload}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
