#!/usr/bin/env bash
#
# tema_kaymasi_kontrol.sh
# ------------------------
# Zed yukarı akışında (upstream) tema crate'lerine dokunan ve henüz
# bu projeye yansıtılmamış commit'leri raporlar.
#
# Pin commit'i `tema_aktarimi.md` içindeki "Son incelenen Zed commit"
# satırından okur. Çıktı, bir sonraki sync turunda incelenmesi gereken
# commit listesidir.
#
# Kullanım:
#   ./tema_kaymasi_kontrol.sh [zed_repo_yolu]
#
# Varsayılan zed_repo_yolu: bu script'in dizinine göre `../zed`
# (yani `~/github/gpui_belge/` altından çalıştırılırsa `~/github/zed`).
#
# Çıkış kodları:
#   0  Drift yok (yeni commit bulunamadı) veya raporlama başarılı.
#   1  Bir hata oluştu (pin okunamadı, repo bulunamadı vs).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIN_DOSYASI="$SCRIPT_DIR/tema_aktarimi.md"
VARSAYILAN_ZED="$SCRIPT_DIR/../zed"
ZED_REPO="${1:-$VARSAYILAN_ZED}"

# İzlenen yollar — tema_aktarimi.md ile senkron tutulmalıdır.
IZLENEN_YOLLAR=(
  "crates/theme/"
  "crates/syntax_theme/"
  "crates/settings_content/src/theme.rs"
  "assets/themes/"
)

# --- yardımcılar -------------------------------------------------------------

hata() {
  printf "HATA: %s\n" "$*" >&2
  exit 1
}

baslik() {
  printf "\n\033[1;36m==> %s\033[0m\n" "$*"
}

# --- ön kontroller -----------------------------------------------------------

if [ ! -f "$PIN_DOSYASI" ]; then
  hata "Pin dosyası bulunamadı: $PIN_DOSYASI"
fi

if [ ! -d "$ZED_REPO/.git" ]; then
  hata "Zed git reposu bulunamadı: $ZED_REPO
İpucu: yolu argüman olarak ver:
  $0 /baska/yol/zed"
fi

# Mutlak yolu çöz (rapor çıktısı için).
ZED_REPO="$(cd "$ZED_REPO" && pwd)"

# Pin commit'i tabloda 'Son incelenen Zed commit' satırından çek.
# Markdown tablo formatı: '| Son incelenen Zed commit | `<sha>` |'
PIN=$(grep -E '^\| *Son incelenen Zed commit' "$PIN_DOSYASI" \
      | sed -E 's/.*`([a-f0-9]+)`.*/\1/' \
      | head -n1)

if [ -z "${PIN:-}" ]; then
  hata "Pin dosyasında 'Son incelenen Zed commit' satırı okunamadı.
Beklenen format:
  | Son incelenen Zed commit | \`<sha>\` |"
fi

# --- uzaktan değişiklikleri çek ---------------------------------------------

baslik "Zed reposu: $ZED_REPO"
echo "    Pin: $PIN"
echo "    İzlenen yollar: ${IZLENEN_YOLLAR[*]}"

baslik "Uzak değişiklikler çekiliyor (git fetch)..."
git -C "$ZED_REPO" fetch --quiet origin

if ! git -C "$ZED_REPO" cat-file -e "$PIN^{commit}" 2>/dev/null; then
  hata "Pin commit'i Zed reposunda bulunamadı: $PIN
Pin commit yerel kopyada yok olabilir. Önce: git -C $ZED_REPO fetch --unshallow"
fi

ARALIK="$PIN..origin/main"

# --- ana rapor ---------------------------------------------------------------

baslik "Aralık: $ARALIK"
COMMIT_SAYISI=$(git -C "$ZED_REPO" rev-list --count "$ARALIK" -- "${IZLENEN_YOLLAR[@]}")
echo "    İzlenen yollara dokunan commit sayısı: $COMMIT_SAYISI"

if [ "$COMMIT_SAYISI" -eq 0 ]; then
  baslik "Sonuç: drift yok."
  echo "    Tema crate'lerinde pin'den bu yana değişiklik bulunmuyor."
  exit 0
fi

baslik "İzlenen yollara dokunan commit'ler"
git -C "$ZED_REPO" log --oneline "$ARALIK" -- "${IZLENEN_YOLLAR[@]}"

baslik "Dosya bazında değişiklik özeti (diffstat)"
git -C "$ZED_REPO" diff --stat "$ARALIK" -- "${IZLENEN_YOLLAR[@]}"

baslik "Yalnızca styles/ değişikliklerini görmek için"
echo "    Alan paritesi açısından en kritik dizin styles/ — ayrıca incele:"
echo ""
git -C "$ZED_REPO" log --oneline "$ARALIK" -- \
  crates/theme/src/styles/ \
  || true

baslik "Sonraki adımlar"
cat <<EOF
1. Yukarıdaki commit listesini açıp tek tek incele:
     git -C $ZED_REPO show <sha>

2. Yeni alan eklenmiş veya alan adı değişmişse:
     - tema crate'inde struct'ları güncelle
     - tests/fixtures/ altındaki tema JSON'larını yeni pin'den yenile
     - cargo test ile fixture testlerini doğrula

3. tema_aktarimi.md dosyasını güncelle:
     - "Mevcut durum" tablosunu yeni pin SHA + bugünün tarihi ile değiştir
     - "Senkron turu geçmişi" tablosuna yeni bir satır ekle
     - Yansıtılmayan değişiklikleri "Senkron edilMEYEN" veya
       "Bekleyen kararlar" bölümlerine gerekçeyle düş

4. Değişiklikleri tek bir commit olarak işle:
     tema: Upstream sync to <yeni-kisa-sha>
EOF
