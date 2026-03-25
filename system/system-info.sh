#!/bin/bash
# ===========================================
# Script Adı  : 01-system-info.sh
# Açıklama    : Sistem bilgilerini toplar ve raporlar
# Kullanım    : ./01-system-info.sh [--log]
# Örnek       : ./01-system-info.sh --log
# Kategori    : system/ (01)
# ===========================================
set -e
set -u
set -o pipefail

# --- Renkler ---:
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Değişkenler ---
SCRIPT_NAME=$(basename "$0")
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_DIR="/var/log/bash-scripts"
LOG_FILE="${LOG_DIR}/system-info_$(date '+%Y-%m-%d_%H-%M-%S').log"
WRITE_LOG=false

# --- Fonksiyonlar ---
info()   { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()   { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()  { echo -e "${RED}[ERROR]${NC} $1" >&2; }
header() { echo -e "\n${BLUE}===== $1 =====${NC}"; }

log_write() {
    # WRITE_LOG true ise hem ekrana hem dosyaya yazar
    if [ "$WRITE_LOG" = true ]; then
        echo "[${TIMESTAMP}] $1" | tee -a "$LOG_FILE"
    fi
}

# --- Parametre parsing ---
for arg in "$@"; do
    case $arg in
        --log)   WRITE_LOG=true ;;
        --help)
            echo "Kullanım: $SCRIPT_NAME [--log] [--help]"
            exit 0
            ;;
        *)
            error "Bilinmeyen parametre: $arg"
            exit 1
            ;;
    esac
done

# --- Log dizini hazırla ---
if [ "$WRITE_LOG" = true ]; then
    mkdir -p "$LOG_DIR"
    info "Log dosyası: $LOG_FILE"
fi

# --- TRAP ---
# Hata olursa hangi satırda patladığını söyler
# EXIT her durumda çalışır (başarılı da olsa)
trap 'error "Hata oluştu! Satır: $LINENO"' ERR
trap 'info  "Script tamamlandı."' EXIT

# ===========================================
# ANA PROGRAM
# ===========================================

header "SİSTEM BİLGİ RAPORU — $TIMESTAMP"
log_write "=== Rapor Başladı ==="

# --- 1. Genel ---
header "1. Genel Bilgiler"
OS=$(lsb_release -ds 2>/dev/null || uname -s)
KERNEL=$(uname -r)
UPTIME=$(uptime -p)
info "Hostname : $(hostname)"
info "OS       : $OS"
info "Kernel   : $KERNEL"
info "Uptime   : $UPTIME"
log_write "Hostname: $(hostname) | OS: $OS"

# --- 2. CPU ---
header "2. CPU"
CPU_CORES=$(nproc)
CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo | awk -F': ' '{print $2}')
info "Model : $CPU_MODEL"
info "Cores : $CPU_CORES"
log_write "CPU: $CPU_MODEL ($CPU_CORES cores)"

# --- 3. RAM ---
header "3. Bellek"
# free -h : human readable (GB/MB)
# awk '/^Mem:/ : sadece Mem: ile başlayan satırı al
TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
USED=$(free -h  | awk '/^Mem:/ {print $3}')
FREE=$(free -h  | awk '/^Mem:/ {print $4}')
info "Toplam : $TOTAL"
info "Kullanılan : $USED"
info "Boş   : $FREE"
log_write "RAM: $TOTAL toplam, $USED kullanılan"

# --- 4. Disk ---
header "4. Disk Kullanımı"
# grep '^/' : /dev/sda gibi gerçek diskleri filtrele, tmpfs'i alma
df -h | grep '^/' | while read -r line; do
    USAGE=$(echo "$line" | awk '{print $5}' | tr -d '%')
    if [ "$USAGE" -gt 85 ]; then
        warn "$line  ← Yüksek!"
    else
        info "$line"
    fi
done
log_write "Disk kontrolü tamamlandı"

# --- 5. Network ---
header "5. Network"
# ip -br addr : brief format, daha temiz çıktı
ip -br addr show | while read -r line; do
    info "$line"
done

# --- 6. Servisler ---
header "6. Kritik Servisler"
# Listeyi ihtiyacına göre genişletebilirsin
SERVICES=("ssh" "cron" "ufw")
for svc in "${SERVICES[@]}"; do
    STATUS=$(systemctl is-active "$svc" 2>/dev/null || echo "not-found")
    if [ "$STATUS" = "active" ]; then
        info "✓ $svc → $STATUS"
    else
        warn "✗ $svc → $STATUS"
    fi
    log_write "Servis: $svc = $STATUS"
done

# --- 7. Son Girişler ---
header "7. Son 5 Login"
last -n 5

log_write "=== Report Succesfully ==="
