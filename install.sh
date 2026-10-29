#!/bin/zsh
# Installeert Sharelink - Finder in /Applications, registreert sharelink:// en de Services, en start de app.
set -e
cd "$(dirname "$0")"
NAME="Sharelink - Finder"
pkill -x "$NAME" 2>/dev/null || true
rm -rf "/Applications/$NAME.app"
cp -R "build/$NAME.app" /Applications/
xattr -dr com.apple.quarantine "/Applications/$NAME.app" 2>/dev/null || true
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/$NAME.app"
/System/Library/CoreServices/pbs -update 2>/dev/null || true
open -a "/Applications/$NAME.app"
echo "$NAME gestart. Bij de eerste klik vraagt macOS toestemming om Finder te lezen."
echo "Eigen domein voor de links: defaults write nl.itgsolutions.sharelink LinkBase 'https://open.jouwdomein.nl/#'"
