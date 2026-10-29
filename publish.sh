#!/bin/zsh
# Publiceert build/Sharelink - Finder.zip (uit release.sh) als GitHub Release, met de zip onder twee namen:
# met versienummer voor het archief, en als vaste Sharelink-Finder.zip zodat de downloadlink op de site altijd klopt:
#   https://github.com/gerbenhoogendam/sharelink-finder/releases/latest/download/Sharelink-Finder.zip
# Gebruik: ./publish.sh "- regel 1" ["- regel 2" ...]   (het versienummer komt uit Info.plist)
set -e
cd "$(dirname "$0")"
V=$(plutil -extract CFBundleShortVersionString raw -o - Info.plist)
[ -f "build/Sharelink - Finder.zip" ] || { echo "geen build/Sharelink - Finder.zip; draai eerst ./release.sh"; exit 1; }
cp "build/Sharelink - Finder.zip" "build/Sharelink-Finder-$V.zip"
cp "build/Sharelink - Finder.zip" "build/Sharelink-Finder.zip"
NOTES=$(printf '%s\n' "$@"; printf '\nBijwerken: zip uitpakken, app vervangen in Programma'"'"'s, één keer starten.')
gh release create "v$V" "build/Sharelink-Finder-$V.zip" "build/Sharelink-Finder.zip" --title "Sharelink - Finder $V" --notes "$NOTES"
echo "gepubliceerd: v$V"
