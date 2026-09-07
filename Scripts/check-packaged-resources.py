#!/usr/bin/env python3
"""Check a locally built release ZIP without access to the SwiftPM build tree.

Usage: python3 Scripts/check-packaged-resources.py dist/AI-Power-1.1.1-macOS.zip
This checks resources without starting login items, notifications or account queries.
"""
import json
import pathlib
import subprocess
import sys
import tempfile


def main():
    archive = pathlib.Path(sys.argv[1]).resolve(strict=True)
    repo = pathlib.Path(__file__).resolve().parent.parent
    profile = '(version 1)(allow default)(deny file-read* (subpath {}))'.format(
        json.dumps(str(repo / '.build'), ensure_ascii=False)
    )
    with tempfile.TemporaryDirectory(prefix='ai-power-release-check-') as directory:
        root = pathlib.Path(directory)
        subprocess.run(['/usr/bin/ditto', '-x', '-k', str(archive), str(root)], check=True)
        app = root / 'AI Power.app'
        executable = app / 'Contents/MacOS/AI Power'
        subprocess.run(['/usr/bin/codesign', '--verify', '--all-architectures', '--deep', '--strict', str(app)], check=True)
        command = ['/usr/bin/sandbox-exec', '-p', profile, str(executable), '--check-resources']
        result = subprocess.run(command, capture_output=True, text=True, timeout=15)
        if result.returncode != 0 or 'AI Power resources OK:' not in result.stdout:
            raise RuntimeError('Packaged resources failed: ' + result.stdout + result.stderr)
        print(result.stdout.strip())

        # Missing packaged resources must not be hidden by local build artifacts.
        resources = app / 'Contents/Resources/AIPower_AIPower.bundle'
        outside = root / 'resources-held-for-negative-test.bundle'
        resources.rename(outside)
        try:
            missing = subprocess.run([str(executable), '--check-resources'], capture_output=True, text=True, timeout=15)
            if missing.returncode != 1 or 'AI Power resources FAILED' not in missing.stdout:
                raise RuntimeError('Missing-resource negative control failed: ' + missing.stdout + missing.stderr)
        finally:
            outside.rename(resources)
        subprocess.run(['/usr/bin/codesign', '--verify', '--all-architectures', '--deep', '--strict', str(app)], check=True)
        print('PASS: archive resources work with build directory denied; missing resources fail without a development fallback.')


if __name__ == '__main__':
    main()
