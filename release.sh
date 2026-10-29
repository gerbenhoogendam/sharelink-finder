#!/bin/zsh
# Bouwt, signeert met Developer ID en hardened runtime, notariseert, stapelt het ticket en maakt een zip voor verspreiding.
#
# Eenmalig op deze Mac:
#   1. Developer ID Application-certificaat in de sleutelhanger (Xcode > Settings > Accounts > Manage Certificates).
#   2. xcrun notarytool store-credentials notary --apple-id <Apple ID> --team-id <TEAMID>
#      (vraagt om een app-specifiek wachtwoord van appleid.apple.com)
# Daarna:
#   SIGN_ID="Developer ID Application: Naam (TEAMID)" ./release.sh
set -e
cd "$(dirname "$0")"
# Zonder SIGN_ID: het eerste Developer ID Application-certificaat in de sleutelhanger.
SIGN_ID="${SIGN_ID:-$(security find-identity -v -p codesigning | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"')}"
: "${SIGN_ID:?Geen Developer ID Application-certificaat gevonden, zie: security find-identity -v -p codesigning}"
PROFILE="${NOTARY_PROFILE:-notary}"
NAME="Sharelink - Finder"; APP="build/$NAME.app"; ZIP="build/$NAME.zip"

./build.sh
codesign --force --options runtime --timestamp --entitlements Sharelink.entitlements --sign "$SIGN_ID" "$APP"
codesign --verify --strict --verbose=2 "$APP"

ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"
ditto -c -k --keepParent "$APP" "$ZIP"     # opnieuw inpakken, nu mét het geniete ticket
spctl -a -vv -t exec "$APP"
echo "klaar voor verspreiding: $ZIP"
