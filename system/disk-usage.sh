#!/bin/bash
# ===========================================
# Script Adı  : 02-disk-usage.sh
# Açıklama    : Disk kullanımını kontrol eder, eşik aşılırsa uyarır
# Kullanım    : ./02-disk-usage.sh [--threshold 80] [--log]
# Örnek       : ./02-disk-usage.sh --threshold 70 --log
# Kategori    : system/ (02)
# ===========================================
set -e
set -u
set -o pipefail

# --- Renkler ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Değişkenler ---
SCRIPT_NAME=$(basename "$0")
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_DIR="/var/log/bash-scripts"
LOG_FILE="${LOG_DIR}/disk-usage_${TIMESTAMP}.log"
WRITE_LOG=false
THRESHOLD=80          # varsayılan eşik: %80
CRITICAL_FOUND=false  # kritik disk bulundu mu?

# --- Fonksiyonlar ---
info()   { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()   { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()  { echo -e "${RED}[ERROR]${NC} $1" >&2; }
header() { echo -e "\n${BLUE}===== $1 =====${NC}"; }

log_write() {
    if [ "$WRITE_LOG" = true ]; then
        # tee -a → hem ekrana yaz hem dosyaya ekle
        echo "[${TIMESTAMP}] $1" | tee -a "$LOG_FILE"
    fi
}

usage() {
    echo "Kullanım: $SCRIPT_NAME [seçenekler]"
    echo ""
    echo "Seçenekler:"
    echo "  --threshold N   Uyarı eşiği (varsayılan: 80)"
    echo "  --log           Log dosyasına yaz"
    echo "  --help          Bu yardımı göster"
    echo ""
    echo "Örnek:"
    echo "  $SCRIPT_NAME --threshold 70 --log"
}

# --- Parametre Parsing ---
# $# → toplam parametre sayısı
# shift → parametreleri sola kaydırır, sıradakini işlemek için
while [[ $# -gt 0 ]]; do
    case $1 in
        --threshold)
            # $2 → bir sonraki parametre (değer)
            THRESHOLD="$2"
            shift 2  # hem --threshold hem değeri atla
            ;;
        --log)
            WRITE_LOG=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            error "Bilinmeyen parametre: $1"
            usage
            exit 1
            ;;
    esac
done

# Threshold sayı mı? Değilse hata ver
# [[ ! $X =~ ^[0-9]+$ ]] → regex: sadece rakam değilse
if [[ ! "$THRESHOLD" =~ ^[0-9]+$ ]] || [ "$THRESHOLD" -gt 100 ]; then
    error "Geçersiz threshold değeri: $THRESHOLD (0-100 arası olmalı)"
    exit 1
fi

# --- Log dizini hazırla ---
if [ "$WRITE_LOG" = true ]; then
    mkdir -p "$LOG_DIR"
fi

# --- TRAP ---
trap 'error "Hata oluştu! Satır: $LINENO"' ERR

# ===========================================
# FONKSİYON: Tek bir diski kontrol et
# Parametre: df çıktısından bir satır
# ===========================================
check_disk() {
    local line="$1"

    # awk ile sütunları ayır
    local mount
    local usage_pct
    local total
    local used
    local avail

    mount=$(echo "$line"     | awk '{print $6}')  # mount noktası
    usage_pct=$(echo "$line" | awk '{print $5}' | tr -d '%')  # % işaretini kaldır
    total=$(echo "$line"     | awk '{print $2}')
    used=$(echo "$line"      | awk '{print $3}')
    avail=$(echo "$line"     | awk '{print $4}')

    # Görsel doluluk bar'ı oluştur
    # Örnek: [████████░░] %80
    local bar=""
    local bar_length=20
    # kaç blok dolu? (usage_pct * bar_length / 100)
    local filled=$(( usage_pct * bar_length / 100 ))
    local empty=$(( bar_length - filled ))

    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++));  do bar+="░"; done

    # Eşiğe göre renk ve seviye belirle
    local color
    local level

    if [ "$usage_pct" -ge 90 ]; then
        color="$RED"
        level="KRİTİK"
        CRITICAL_FOUND=true
    elif [ "$usage_pct" -ge "$THRESHOLD" ]; then
        color="$YELLOW"
        level="UYARI"
        CRITICAL_FOUND=true
    else
        color="$GREEN"
        level="NORMAL"
    fi

    # Formatlanmış çıktı
    echo -e "${color}[$level]${NC} $mount"
    echo -e "         Kullanım : ${color}${usage_pct}%${NC}  [${color}${bar}${NC}]"
    echo -e "         Toplam   : $total  |  Kullanılan: $used  |  Boş: $avail"
    echo ""

    log_write "[$level] $mount → ${usage_pct}% (${used}/${total})"
}

# ===========================================
# ANA PROGRAM
# ===========================================

header "DİSK KULLANIM RAPORU — $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "Uyarı eşiği : ${YELLOW}%${THRESHOLD}${NC}"
echo -e "Hostname    : $(hostname)"
echo ""

log_write "=== Disk Raporu Başladı | Threshold: %${THRESHOLD} ==="

# df çıktısını işle
# -h : human readable
# grep '^/' : sadece gerçek diskler (/dev/sda, /dev/mapper vs)
# NR>1 : başlık satırını atla
while IFS= read -r line; do
    check_disk "$line"
done < <(df -h | grep '^/')

# --- Özet ---
header "ÖZET"

if [ "$CRITICAL_FOUND" = true ]; then
    warn "Eşik aşan disk(ler) bulundu! (threshold: %${THRESHOLD})"
    log_write "SONUÇ: Kritik disk var!"
    # exit 1 → CI/CD pipeline'da bu scripti kullanırsan
    # hata durumunda pipeline durur
    EXIT_CODE=1
else
    info "Tüm diskler normal. (threshold: %${THRESHOLD})"
    log_write "SONUÇ: Tüm diskler normal"
    EXIT_CODE=0
fi

if [ "$WRITE_LOG" = true ]; then
    info "Log kaydedildi: $LOG_FILE"
fi

log_write "=== Disk Raporu Tamamlandı ==="

# Script'in exit code'unu döndür
# Bu sayede: if ./02-disk-usage.sh; then echo "OK"; fi  → çalışır
exit $EXIT_CODE
