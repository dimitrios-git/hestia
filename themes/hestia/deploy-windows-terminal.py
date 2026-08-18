#!/usr/bin/env python3
"""deploy-windows-terminal.py — apply the hestia Windows Terminal theme.

Run manually, once, from inside a WSL distro. This is deliberately NOT part
of the Ansible bootstrap (site.yml) — WSL is a separate machine the
bootstrap was never meant to reach, same category as NVM/vim-plug/GitHub
onboarding in CLAUDE.md.

Drops two JSON Fragment files into the ONE folder Windows Terminal scans for
third-party fragments regardless of install variant —
%LOCALAPPDATA%/Microsoft/Windows Terminal/Fragments/hestia/ (see
learn.microsoft.com/windows/terminal/json-fragment-extensions,
"applications installed from the web") — Windows Terminal auto-merges these
at launch, so this NEVER touches the user's own settings.json:

  hestia-schemes.json  copied verbatim from dist/windows-terminal/ (both
                        hestia-dark and hestia-light colour schemes; run
                        render.py first if this is missing/stale)
  hestia-profile.json  a small profile PATCH (colorScheme/cursorColor/
                        tabColor) targeting THIS distro's own
                        Windows-Terminal-auto-generated WSL profile, located
                        by computing its GUID from $WSL_DISTRO_NAME (the
                        same value Windows Terminal itself used to name that
                        profile when it auto-generated it) — not guessed.
                        Safe no-op if the GUID matches nothing (e.g. an
                        already-renamed profile): Windows Terminal just
                        ignores an "updates" that targets no profile.

Idempotent — always overwrites both files. A fragment is only picked up on
the next Windows Terminal launch / new tab, not live.

Usage: deploy-windows-terminal.py [--variant dark|light]
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import uuid
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCHEMES_SRC = HERE / "dist/windows-terminal/hestia-schemes.json"

# Windows Terminal's namespace GUID for its own auto-generated profiles
# (e.g. the WSL profile it creates per installed distro) — from the MS Learn
# JSON-fragment-extensions doc.
WT_AUTOGEN_NAMESPACE = uuid.UUID("{2bde4a90-d05f-401c-9492-e40884ead1d8}")

ACCENT = "#7c3aed"


def profile_guid(distro_name: str) -> str:
    """Replicates MS's documented recipe exactly. uuid.uuid5() always
    UTF-8-encodes its `name` argument internally, but Windows Terminal
    derives the GUID from the UTF-16LE bytes of the name (it's a
    WinRT/C++ app) — so the name is round-tripped through a UTF-16LE
    encode + ASCII decode first. For an ASCII distro name (always true
    for WSL) that produces a Python str which, when uuid5 re-encodes it
    to UTF-8, comes back out as exactly the original UTF-16LE byte
    sequence."""
    utf16_as_str = distro_name.encode("utf-16-le").decode("ascii")
    return f"{{{uuid.uuid5(WT_AUTOGEN_NAMESPACE, utf16_as_str)}}}"


def run(cmd: list) -> str:
    """Capture RAW BYTES, not text=True — some corporate Windows images wire
    an AutoRun hook onto cmd.exe (VPN/EDR/IT-policy banners) that prints
    legacy-codepage text ahead of the real output; text=True decodes both
    streams as strict UTF-8 inside subprocess.run() itself and crashes on
    that before we ever see a chance to handle it (hit live, 2026-08-18).
    Decode leniently instead so garbage bytes can't take the whole script
    down; win_userprofile() below does the actual banner-line filtering."""
    try:
        result = subprocess.run(cmd, capture_output=True, check=True)
    except FileNotFoundError as e:
        sys.exit(f"failed to run {cmd!r}: {e}")
    except subprocess.CalledProcessError as e:
        stderr = (e.stderr or b"").decode("utf-8", errors="replace")
        sys.exit(f"failed to run {cmd!r} (exit {e.returncode}): {stderr}")
    return result.stdout.decode("utf-8", errors="replace").strip()


def win_userprofile() -> Path:
    """Resolve %USERPROFILE% via cmd.exe (always present via WSL interop,
    no extra utility beyond the wslpath binary WSL itself ships) and
    translate it to its /mnt/c/... path. `/d` disables cmd.exe's AutoRun
    registry hook (HKCU/HKLM ...\\Command Processor\\AutoRun) — the likely
    source of banner text corporate images print on every cmd.exe launch.
    As a second layer of defense, take the LAST non-empty output line (the
    echoed value always comes last) and sanity-check it looks like a
    Windows path before trusting it."""
    win_path = run(["cmd.exe", "/d", "/c", "echo %USERPROFILE%"])
    lines = [ln.strip() for ln in win_path.splitlines() if ln.strip()]
    if not lines:
        sys.exit("cmd.exe produced no output for %USERPROFILE%")
    win_path = lines[-1]
    if not re.match(r"^[A-Za-z]:\\", win_path):
        sys.exit(
            f"unexpected output resolving %USERPROFILE% (got {win_path!r}) "
            "— check for a cmd.exe AutoRun banner (HKCU/HKLM ...\\Command "
            "Processor\\AutoRun) printing extra text ahead of it"
        )
    return Path(run(["wslpath", "-u", win_path]))


def fragments_dir(userprofile: Path) -> Path:
    """The ONE folder Windows Terminal scans for third-party fragments,
    regardless of whether the installed Terminal is the Microsoft Store
    package, the unpackaged/winget build, Preview, or Canary — per
    learn.microsoft.com/windows/terminal/json-fragment-extensions
    ("applications installed from the web", current-user case), confirmed
    live 2026-08-19: a Store package's OWN
    Packages\\<pkg>\\LocalState\\Fragments is a DIFFERENT, unrelated
    mechanism (for a Store app declaring itself as an extension via its
    own appxmanifest, surfaced through the AppExtension catalog, not a
    folder Terminal scans on disk) — an earlier version of this script
    wrote there by mistake (branching on which install's settings.json
    existed) and nothing loaded, because Terminal never looks there."""
    return userprofile / "AppData" / "Local" / "Microsoft" / "Windows Terminal" / "Fragments"


# Where the earlier (buggy) version of this script mistakenly wrote —
# cleaned up automatically since Windows Terminal never reads these.
_STALE_FRAGMENT_DIRS = [
    "AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/Fragments/hestia",
    "AppData/Local/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/Fragments/hestia",
    "AppData/Local/Packages/Microsoft.WindowsTerminalCanary_8wekyb3d8bbwe/LocalState/Fragments/hestia",
]


def clean_stale(userprofile: Path) -> None:
    for rel in _STALE_FRAGMENT_DIRS:
        stale = userprofile / rel
        if stale.exists():
            shutil.rmtree(stale)
            print(f"removed stale {stale} (Windows Terminal never reads this location)")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--variant", choices=["dark", "light"], default="dark")
    args = parser.parse_args()

    distro = os.environ.get("WSL_DISTRO_NAME")
    if not distro:
        sys.exit(
            "WSL_DISTRO_NAME is not set — this only makes sense run from "
            "inside a WSL distro."
        )
    if not SCHEMES_SRC.exists():
        sys.exit(f"{SCHEMES_SRC} does not exist — run render.py first.")

    userprofile = win_userprofile()
    clean_stale(userprofile)
    dest_dir = fragments_dir(userprofile) / "hestia"
    dest_dir.mkdir(parents=True, exist_ok=True)

    shutil.copyfile(SCHEMES_SRC, dest_dir / "hestia-schemes.json")

    guid = profile_guid(distro)
    profile_patch = {
        "profiles": [
            {
                "updates": guid,
                "colorScheme": f"hestia-{args.variant}",
                "cursorColor": ACCENT,
                "tabColor": ACCENT,
            }
        ]
    }
    (dest_dir / "hestia-profile.json").write_text(
        json.dumps(profile_patch, indent=2) + "\n"
    )

    print(f"wrote {dest_dir / 'hestia-schemes.json'}")
    print(f"wrote {dest_dir / 'hestia-profile.json'} (distro '{distro}', profile {guid})")
    print("Open a new Windows Terminal tab/window to pick this up.")


if __name__ == "__main__":
    main()
