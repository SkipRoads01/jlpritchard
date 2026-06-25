#!/usr/bin/env bash
# Regenerate og.jpg (the link-preview image) from a RANDOM image in the
# manifest, cropped to 1200x630. Run by .github/workflows/rotate-og.yml on a
# daily schedule + on push, so shared links unfurl with a rotating cover.
# Works with ImageMagick (CI) or sips (local macOS) — whichever is present.
set -euo pipefail
cd "$(dirname "$0")/.."

W=1200; H=630

SRC=$(node -e '
const fs=require("fs");
const m=JSON.parse(fs.readFileSync("media/manifest.json","utf8"));
const imgs=(m.images||[]).filter(p=>fs.existsSync(p));
if(!imgs.length){console.error("no images in manifest");process.exit(1);}
process.stdout.write(imgs[Math.floor(Math.random()*imgs.length)]);
')
echo "Selected source: $SRC"

if command -v magick >/dev/null 2>&1; then CONV=magick
elif command -v convert >/dev/null 2>&1; then CONV=convert
else CONV=""; fi

if [ -n "$CONV" ]; then
  "$CONV" "$SRC" -resize "${W}x${H}^" -gravity center -extent "${W}x${H}" -quality 85 og.jpg
else
  # sips fallback: scale to fill, then centre-crop to exact size
  read -r sw sh < <(sips -g pixelWidth -g pixelHeight "$SRC" \
    | awk '/pixelWidth/{w=$2}/pixelHeight/{h=$2}END{print w" "h}')
  nw=$(node -e "const s=Math.max($W/$sw,$H/$sh);console.log(Math.round($sw*s))")
  nh=$(node -e "const s=Math.max($W/$sw,$H/$sh);console.log(Math.round($sh*s))")
  tmp=$(mktemp /tmp/og.XXXXXX.jpg)
  sips -z "$nh" "$nw" "$SRC" --out "$tmp" >/dev/null
  sips -c "$H" "$W" "$tmp" --out og.jpg >/dev/null
  sips -s format jpeg -s formatOptions 85 og.jpg --out og.jpg >/dev/null
  rm -f "$tmp"
fi

echo "og.jpg regenerated from $SRC"
