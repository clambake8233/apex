#!/usr/bin/env python3
"""
Generate the AltStore source JSON for Apex.

Reads the built IPA + app metadata and emits `altstore.json` — the self-hosted
manifest AltStore reads. The IPA is distributed as a GitHub Release asset; the
downloadURL points at that asset.

Usage:
  python3 Tools/make_altsource.py \
      --ipa xtool/Apex.ipa \
      --download-url https://github.com/clambake8233/apex/releases/download/vX/Apex.ipa \
      --version 1.0.0 --build 1 \
      --out altstore.json

The `size` MUST be the exact byte length of the IPA at downloadURL.
"""
import argparse, datetime, json, os, sys


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ipa", required=True)
    ap.add_argument("--download-url", required=True)
    ap.add_argument("--version", default="1.0.0")
    ap.add_argument("--build", default="1")
    ap.add_argument("--changelog", default="First AltStore release of Apex.")
    ap.add_argument("--icon-url", default="")
    ap.add_argument("--screenshots", nargs="*", default=[])
    ap.add_argument("--out", default="altstore.json")
    args = ap.parse_args()

    if not os.path.exists(args.ipa):
        print(f"error: ipa not found: {args.ipa}", file=sys.stderr)
        return 1
    size = os.path.getsize(args.ipa)
    today = datetime.date.today().isoformat()

    version_entry = {
        "version": args.version,
        "buildVersion": args.build,
        "date": today,
        "localizedDescription": args.changelog,
        "downloadURL": args.download_url,
        "size": size,
        "minOSVersion": "17.0",
    }

    app = {
        "name": "Apex",
        "bundleIdentifier": "com.apexrides.app",
        "developerName": "Apex",
        "subtitle": "Record your rides. Keep every corner.",
        "localizedDescription": (
            "Apex is a motorcycle riding companion. Record your rides and get "
            "them back as beautiful keepsakes — route, distance, duration, and "
            "top speed for every ride you carve.\n\n"
            "Tap \u201cTry Demo Mode\u201d on first launch to explore with sample "
            "rides before your first ride."
        ),
        "iconURL": args.icon_url,
        "tintColor": "#FF6B2C",
        "category": "lifestyle",
        "screenshots": args.screenshots,
        "versions": [version_entry],
        "appPermissions": {
            "entitlements": [],
            "privacy": {
                "NSLocationWhenInUseUsageDescription":
                    "Apex records your route while you ride.",
                "NSLocationAlwaysAndWhenInUseUsageDescription":
                    "Apex records your route while you ride, even with the screen off.",
            },
        },
    }

    source = {
        "name": "Apex",
        "subtitle": "The Apex riding companion",
        "description": "Official source for Apex — a motorcycle riding companion.",
        "iconURL": args.icon_url,
        "website": "https://github.com/clambake8233/apex",
        "tintColor": "#FF6B2C",
        "featuredApps": ["com.apexrides.app"],
        "apps": [app],
        "news": [],
    }

    with open(args.out, "w") as f:
        json.dump(source, f, indent=2)
    print(f"wrote {args.out}  (ipa size={size} bytes, version={args.version} build={args.build})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
