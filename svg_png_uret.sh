#!/usr/bin/env bash
set -euo pipefail

cikti_klasoru="svg"
pencere_boyutu="1440,1024"

kullanim_yaz() {
  printf 'Kullanim: %s [svg_dosyasi]\n' "$0" >&2
}

svg_render_et() {
  local dosya="$1"
  local dosya_adi
  local mutlak_yol

  if [[ ! -f "$dosya" ]]; then
    printf 'Hata: dosya bulunamadi: %s\n' "$dosya" >&2
    return 1
  fi

  case "$dosya" in
    *.svg | *.SVG) ;;
    *)
      printf 'Hata: dosya bir SVG degil: %s\n' "$dosya" >&2
      return 1
      ;;
  esac

  dosya_adi="$(basename "${dosya%.*}")"
  mutlak_yol="$(realpath "$dosya")"

  google-chrome --headless --disable-gpu \
    --screenshot="${cikti_klasoru}/${dosya_adi}.png" \
    --window-size="$pencere_boyutu" \
    "file://${mutlak_yol}" >/dev/null 2>&1

  printf '%s -> %s/%s.png\n' "$dosya" "$cikti_klasoru" "$dosya_adi"
}

if [[ ! -d "$cikti_klasoru" ]]; then
  printf 'Hata: %s klasoru yok. Betik mkdir calistirmaz; klasorun onceden olusturulmasi gerekir.\n' "$cikti_klasoru" >&2
  exit 1
fi

if [[ "$#" -gt 1 ]]; then
  kullanim_yaz
  exit 2
fi

if [[ "$#" -eq 1 ]]; then
  svg_render_et "$1"
  exit 0
fi

while IFS= read -r dosya; do
  svg_render_et "$dosya"
done < <(rg --files src -g '*.svg' | sort)
