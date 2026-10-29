#!/bin/zsh
# Bouwt build/Sharelink - Finder.app zonder Xcode-project en draait de zelftest (link maken en weer oplossen).
set -e
cd "$(dirname "$0")"
NAME="Sharelink - Finder"
APP="build/$NAME.app"; BIN="$APP/Contents/MacOS/$NAME"
rm -rf build; mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/"
mkdir -p "$APP/Contents/Resources"; cp Resources/* "$APP/Contents/Resources/"
swiftc -O -parse-as-library -o "$BIN" CloudLinks.swift App.swift
codesign --force --sign - "$APP"
root=$(plutil -extract business.root_path raw -o - ~/.dropbox/info.json 2>/dev/null || plutil -extract personal.path raw -o - ~/.dropbox/info.json 2>/dev/null || true)
if [ -n "$root" ]; then
  got=$("$BIN" --links "$root/Kop of Munt/02_Website/KoM-logo.pdf" "$HOME/Desktop/x.pdf")
  want=$'https://share-link.nl/#file/dropbox/Kop%20of%20Munt/02_Website/KoM-logo.pdf\nGEEN'
  [ "$got" = "$want" ] || { echo "zelftest link FOUT:"; echo "$got"; exit 1; }
  f=$(find "$root" -maxdepth 2 -type f ! -name '.*' ! -name 'Icon*' | LC_ALL=C grep -v '[^ -~]' | head -1)
  if [ -n "$f" ]; then
    link=$("$BIN" --links "$f"); back=$("$BIN" --resolve "sharelink://${link#*#}")
    [ "$back" = "$f" ] || { echo "zelftest resolve FOUT: $f -> sharelink://${link#*#} -> $back"; exit 1; }
  fi
  # Symlink-controle: een koppeling naar buiten de root mag niet door.
  T=$(mktemp -d); mkdir -p "$T/root/map"; echo x > "$T/root/map/echt.txt"; ln -s /etc/hosts "$T/root/map/naarbuiten"
  [ "$("$BIN" --check "$T/root" "map/echt.txt")" = "$T/root/map/echt.txt" ] || { echo "zelftest symlink FOUT: echt bestand geweigerd"; exit 1; }
  [ "$("$BIN" --check "$T/root" "map/naarbuiten")" = "GEEN" ] || { echo "zelftest symlink FOUT: koppeling naar buiten toegelaten"; exit 1; }
  rm -rf "$T"
  echo "zelftest ok"
else
  echo "zelftest overgeslagen: geen Dropbox op deze Mac"
fi
echo "gebouwd: $APP"
