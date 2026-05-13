#!/usr/bin/env bash
#
# tema_kaymasi_kontrol.sh
# ------------------------
# `zed_commit_pin.txt` dosyasındaki Zed commit'ini taban alır, yerel Zed
# reposunu bu commit'e geri sabitler, upstream'den `git pull --ff-only` ile
# günceller ve eski pin ile yeni HEAD arasındaki farkı timestamp'li diff
# dosyası olarak kaydeder.
#
# Kullanım:
#   ./tema_kaymasi_kontrol.sh [zed_repo_yolu] [cikti_dizini]
#
# Varsayılanlar:
#   zed_repo_yolu : bu script'in dizinine göre ../zed
#   cikti_dizini  : bu script'in dizini
#
# Ortam değişkenleri:
#   ZED_PIN_DOSYASI     : Pin dosyasını değiştirmek için.
#   ZED_PULL_REMOTE     : Upstream yerine açık remote kullanmak için.
#   ZED_PULL_BRANCH     : Upstream yerine açık branch kullanmak için.
#                         İkisi birlikte verilirse:
#                           git pull --ff-only "$ZED_PULL_REMOTE" "$ZED_PULL_BRANCH"
#   ZED_TEMIZLE_IGNORED : 1 ise `git clean -fdx`, değilse `git clean -fd`.
#
# Çıktı adı:
#   zed_farkları<yıl-ay-gun-saat-dakika>-<güncel-kısa-commit>.diff
#
# Not:
#   Bu script Zed reposunu yönetilen kaynak olarak ele alır. `git pull`
#   öncesinde HEAD'i pin commit'e geri alır, tracked değişiklikleri siler ve
#   untracked dosyaları temizler.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIN_DOSYASI="${ZED_PIN_DOSYASI:-$SCRIPT_DIR/zed_commit_pin.txt}"
VARSAYILAN_ZED="$SCRIPT_DIR/../zed"
ZED_REPO="${1:-$VARSAYILAN_ZED}"
CIKTI_DIZINI="${2:-$SCRIPT_DIR}"
PULL_REMOTE="${ZED_PULL_REMOTE:-}"
PULL_BRANCH="${ZED_PULL_BRANCH:-}"

hata() {
  printf "HATA: %s\n" "$*" >&2
  exit 1
}

baslik() {
  printf "\n\033[1;36m==> %s\033[0m\n" "$*"
}

if [ ! -f "$PIN_DOSYASI" ]; then
  hata "Zed pin dosyası bulunamadı: $PIN_DOSYASI
Önce mevcut Zed commit'ini bu dosyaya yazın:
  git -C $ZED_REPO rev-parse HEAD > $PIN_DOSYASI"
fi

if [ ! -d "$ZED_REPO/.git" ]; then
  hata "Zed git reposu bulunamadı: $ZED_REPO
İpucu:
  $0 /baska/yol/zed"
fi

ZED_REPO="$(cd "$ZED_REPO" && pwd)"
mkdir -p "$CIKTI_DIZINI"
CIKTI_DIZINI="$(cd "$CIKTI_DIZINI" && pwd)"

PIN="$(grep -Eo '[a-f0-9]{7,40}' "$PIN_DOSYASI" | head -n1 || true)"
if [ -z "${PIN:-}" ]; then
  hata "Pin dosyasında commit SHA okunamadı: $PIN_DOSYASI"
fi

if ! git -C "$ZED_REPO" cat-file -e "$PIN^{commit}" 2>/dev/null; then
  hata "Pin commit'i Zed reposunda bulunamadı: $PIN
Zed reposunda ilgili commit yoksa önce fetch yapın veya pin dosyasını düzeltin."
fi

PIN="$(git -C "$ZED_REPO" rev-parse "$PIN^{commit}")"
PIN_KISA="$(git -C "$ZED_REPO" rev-parse --short=12 "$PIN")"
ESKI_HEAD="$(git -C "$ZED_REPO" rev-parse HEAD)"
ESKI_HEAD_KISA="$(git -C "$ZED_REPO" rev-parse --short=12 HEAD)"
BRANCH="$(git -C "$ZED_REPO" symbolic-ref --quiet --short HEAD || true)"

baslik "Zed repo ve pin durumu"
echo "    Zed repo     : $ZED_REPO"
echo "    Pin dosyası  : $PIN_DOSYASI"
echo "    Pin commit   : $PIN_KISA"
echo "    Eski HEAD    : $ESKI_HEAD_KISA"
if [ -n "$BRANCH" ]; then
  echo "    Branch       : $BRANCH"
else
  echo "    Branch       : detached HEAD"
fi

if [ -z "$PULL_REMOTE" ] && [ -z "$PULL_BRANCH" ]; then
  if [ -z "$BRANCH" ]; then
    hata "Zed reposu detached HEAD durumunda. `git pull` için branch gerekir.
Çözüm:
  git -C $ZED_REPO switch main
veya explicit pull hedefi verin:
  ZED_PULL_REMOTE=origin ZED_PULL_BRANCH=main $0"
  fi

  if ! git -C "$ZED_REPO" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' >/dev/null 2>&1; then
    hata "Zed branch'i için upstream tanımlı değil: $BRANCH
Çözüm:
  git -C $ZED_REPO branch --set-upstream-to=origin/main $BRANCH
veya explicit pull hedefi verin:
  ZED_PULL_REMOTE=origin ZED_PULL_BRANCH=main $0"
  fi
elif [ -z "$PULL_REMOTE" ] || [ -z "$PULL_BRANCH" ]; then
  hata "ZED_PULL_REMOTE ve ZED_PULL_BRANCH birlikte verilmelidir."
fi

baslik "Zed reposu pin commit'e geri sabitleniyor"
if [ "$ESKI_HEAD" != "$PIN" ]; then
  echo "    HEAD pin'den farklı; branch $PIN_KISA commit'ine geri alınacak."
fi
git -C "$ZED_REPO" reset --hard "$PIN"

if [ "${ZED_TEMIZLE_IGNORED:-0}" = "1" ]; then
  echo "    Untracked ve ignored dosyalar temizleniyor: git clean -fdx"
  git -C "$ZED_REPO" clean -fdx
else
  echo "    Untracked dosyalar temizleniyor: git clean -fd"
  git -C "$ZED_REPO" clean -fd
fi

baslik "Zed reposu upstream'den güncelleniyor"
if [ -n "$PULL_REMOTE" ] && [ -n "$PULL_BRANCH" ]; then
  echo "    git pull --ff-only $PULL_REMOTE $PULL_BRANCH"
  git -C "$ZED_REPO" pull --ff-only "$PULL_REMOTE" "$PULL_BRANCH"
else
  UPSTREAM="$(git -C "$ZED_REPO" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}')"
  echo "    git pull --ff-only ($UPSTREAM)"
  git -C "$ZED_REPO" pull --ff-only
fi

GUNCEL="$(git -C "$ZED_REPO" rev-parse HEAD)"
GUNCEL_KISA="$(git -C "$ZED_REPO" rev-parse --short=12 HEAD)"

baslik "Güncel commit aralığı"
echo "    Pin commit   : $PIN_KISA"
echo "    Yeni HEAD    : $GUNCEL_KISA"

if [ "$PIN" = "$GUNCEL" ]; then
  baslik "Sonuç: fark yok"
  echo "    Git pull sonrası HEAD değişmedi. Diff dosyası oluşturulmadı."
  exit 0
fi

if ! git -C "$ZED_REPO" merge-base --is-ancestor "$PIN" "$GUNCEL" 2>/dev/null; then
  echo "UYARI: Pin commit yeni HEAD'in doğrudan atası görünmüyor." >&2
  echo "       Diff yine üretilecek; upstream force-push veya branch sapmasını kontrol edin." >&2
fi

ZAMAN="$(date '+%Y-%m-%d-%H-%M')"
CIKTI_DOSYASI="$CIKTI_DIZINI/zed_farkları${ZAMAN}-${GUNCEL_KISA}.diff"

baslik "Diff kaydediliyor"
git -C "$ZED_REPO" diff --binary "$PIN" "$GUNCEL" > "$CIKTI_DOSYASI"
echo "    $CIKTI_DOSYASI"

baslik "Commit özeti"
git -C "$ZED_REPO" log --oneline "$PIN..$GUNCEL" || true

baslik "Diffstat"
git -C "$ZED_REPO" diff --stat "$PIN" "$GUNCEL" || true

baslik "Sonraki adımlar"
cat <<EOF
1. Diff dosyasını incele:
     $CIKTI_DOSYASI

2. Tema, bileşen ve genel rehber kaynaklarını güncelle:
     - tema_rehber.md
     - bilesen_rehberi.md
     - rehber.md
     - tema_aktarimi.md

3. Rehberlerdeki kapsam doğrulama komutlarını çalıştır.

4. İnceleme tamamlandıysa pin dosyasını yeni commit'e taşı:
     printf '%s\n' "$GUNCEL" > "$PIN_DOSYASI"
EOF
