#!/bin/bash

#===============================================================================
#                       DOSYA SENKRONİZASYON ARACI
#                     İşletim Sistemleri Dersi Projesi
#===============================================================================

# Renkli çıktı için
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Varsayılan değerler
LOG_FILE="sync.log"
MAX_FILE_SIZE=$((100 * 1024 * 1024))  # 100 MB (byte cinsinden)
SYNC_MODE="one-way"  # one-way veya two-way

#-------------------------------------------------------------------------------
# Yardım mesajı
#-------------------------------------------------------------------------------
show_help() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           DOSYA SENKRONİZASYON ARACI - KULLANIM                  ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Kullanım:${NC}"
    echo "  $0 <kaynak_klasör> <hedef_klasör> [seçenekler]"
    echo ""
    echo -e "${GREEN}Seçenekler:${NC}"
    echo "  -l, --log <dosya>     Log dosyası adı (varsayılan: sync.log)"
    echo "  -t, --two-way         Çift yönlü senkronizasyon"
    echo "  -d, --dry-run         Sadece ne yapılacağını göster, işlem yapma"
    echo "  -v, --verbose         Detaylı çıktı"
    echo "  -h, --help            Bu yardım mesajını göster"
    echo ""
    echo -e "${GREEN}Örnekler:${NC}"
    echo "  $0 ~/Documents ~/Backup"
    echo "  $0 ~/Source ~/Target -l mylog.txt -v"
    echo "  $0 ~/FolderA ~/FolderB --two-way"
    echo ""
}

#-------------------------------------------------------------------------------
# Log fonksiyonu
#-------------------------------------------------------------------------------
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log dosyasına yaz
    echo "[$timestamp] $level: $message" >> "$LOG_FILE"
    
    # Ekrana renkli yaz
    case "$level" in
        "KOPYALANDI")
            echo -e "${GREEN}[+]${NC} $message"
            ;;
        "SİLİNDİ")
            echo -e "${RED}[-]${NC} $message"
            ;;
        "GÜNCELLENDİ")
            echo -e "${YELLOW}[~]${NC} $message"
            ;;
        "ATLANDI")
            echo -e "${BLUE}[=]${NC} $message"
            ;;
        "HATA")
            echo -e "${RED}[!]${NC} $message"
            ;;
        "BİLGİ")
            if [ "$VERBOSE" = true ]; then
                echo -e "${CYAN}[i]${NC} $message"
            fi
            ;;
    esac
}

#-------------------------------------------------------------------------------
# Dosya boyutunu okunabilir formata çevir
#-------------------------------------------------------------------------------
format_size() {
    local size=$1
    if [ $size -ge $((1024*1024*1024)) ]; then
        echo "$(echo "scale=2; $size / 1024 / 1024 / 1024" | bc) GB"
    elif [ $size -ge $((1024*1024)) ]; then
        echo "$(echo "scale=2; $size / 1024 / 1024" | bc) MB"
    elif [ $size -ge 1024 ]; then
        echo "$(echo "scale=2; $size / 1024" | bc) KB"
    else
        echo "$size B"
    fi
}

#-------------------------------------------------------------------------------
# MD5 hash hesapla
#-------------------------------------------------------------------------------
get_file_hash() {
    local file="$1"
    if command -v md5sum &> /dev/null; then
        md5sum "$file" 2>/dev/null | cut -d' ' -f1
    elif command -v md5 &> /dev/null; then
        md5 -q "$file" 2>/dev/null
    else
        # Hash hesaplanamıyorsa timestamp kullan
        stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null
    fi
}

#-------------------------------------------------------------------------------
# Dosya boyutu kontrolü
#-------------------------------------------------------------------------------
check_file_size() {
    local file="$1"
    local size=$(stat -c %s "$file" 2>/dev/null || stat -f %z "$file" 2>/dev/null)
    
    if [ "$size" -gt "$MAX_FILE_SIZE" ]; then
        log_message "ATLANDI" "$file - Boyut sınırını aşıyor ($(format_size $size) > 100 MB)"
        return 1
    fi
    return 0
}

#-------------------------------------------------------------------------------
# Tek dosya kopyala
#-------------------------------------------------------------------------------
copy_file() {
    local src="$1"
    local dst="$2"
    local size=$(stat -c %s "$src" 2>/dev/null || stat -f %z "$src" 2>/dev/null)
    
    if [ "$DRY_RUN" = true ]; then
        log_message "KOPYALANDI" "[DRY-RUN] $src → $dst ($(format_size $size))"
        return 0
    fi
    
    # Hedef dizini oluştur
    mkdir -p "$(dirname "$dst")"
    
    if cp "$src" "$dst" 2>/dev/null; then
        log_message "KOPYALANDI" "$src → $dst ($(format_size $size))"
        ((COPIED_COUNT++))
        COPIED_SIZE=$((COPIED_SIZE + size))
        return 0
    else
        log_message "HATA" "Kopyalama başarısız: $src"
        ((ERROR_COUNT++))
        return 1
    fi
}

#-------------------------------------------------------------------------------
# Tek dosya sil
#-------------------------------------------------------------------------------
delete_file() {
    local file="$1"
    
    if [ "$DRY_RUN" = true ]; then
        log_message "SİLİNDİ" "[DRY-RUN] $file"
        return 0
    fi
    
    if rm "$file" 2>/dev/null; then
        log_message "SİLİNDİ" "$file"
        ((DELETED_COUNT++))
        return 0
    else
        log_message "HATA" "Silme başarısız: $file"
        ((ERROR_COUNT++))
        return 1
    fi
}

#-------------------------------------------------------------------------------
# Dosya güncelle (üzerine yaz)
#-------------------------------------------------------------------------------
update_file() {
    local src="$1"
    local dst="$2"
    local size=$(stat -c %s "$src" 2>/dev/null || stat -f %z "$src" 2>/dev/null)
    
    if [ "$DRY_RUN" = true ]; then
        log_message "GÜNCELLENDİ" "[DRY-RUN] $dst ($(format_size $size))"
        return 0
    fi
    
    if cp "$src" "$dst" 2>/dev/null; then
        log_message "GÜNCELLENDİ" "$dst ($(format_size $size))"
        ((UPDATED_COUNT++))
        UPDATED_SIZE=$((UPDATED_SIZE + size))
        return 0
    else
        log_message "HATA" "Güncelleme başarısız: $dst"
        ((ERROR_COUNT++))
        return 1
    fi
}

#-------------------------------------------------------------------------------
# Kaynak → Hedef senkronizasyonu
#-------------------------------------------------------------------------------
sync_source_to_target() {
    local source_dir="$1"
    local target_dir="$2"
    
    log_message "BİLGİ" "Kaynak taranıyor: $source_dir"
    
    # Kaynak klasördeki tüm dosyaları tara
    find "$source_dir" -type f 2>/dev/null | while read -r src_file; do
        # Göreceli yol hesapla
        local relative_path="${src_file#$source_dir/}"
        local dst_file="$target_dir/$relative_path"
        
        # Boyut kontrolü
        if ! check_file_size "$src_file"; then
            continue
        fi
        
        if [ ! -f "$dst_file" ]; then
            # Yeni dosya - kopyala
            copy_file "$src_file" "$dst_file"
        else
            # Dosya var - hash karşılaştır
            local src_hash=$(get_file_hash "$src_file")
            local dst_hash=$(get_file_hash "$dst_file")
            
            if [ "$src_hash" != "$dst_hash" ]; then
                # Hash farklı - güncelle
                update_file "$src_file" "$dst_file"
            else
                log_message "BİLGİ" "Değişiklik yok: $relative_path"
                ((SKIPPED_COUNT++))
            fi
        fi
    done
}

#-------------------------------------------------------------------------------
# Hedefte olup kaynakta olmayan dosyaları sil
#-------------------------------------------------------------------------------
clean_target() {
    local source_dir="$1"
    local target_dir="$2"
    
    log_message "BİLGİ" "Hedef klasör temizleniyor..."
    
    find "$target_dir" -type f 2>/dev/null | while read -r dst_file; do
        local relative_path="${dst_file#$target_dir/}"
        local src_file="$source_dir/$relative_path"
        
        if [ ! -f "$src_file" ]; then
            delete_file "$dst_file"
        fi
    done
    
    # Boş dizinleri temizle
    find "$target_dir" -type d -empty -delete 2>/dev/null
}

#-------------------------------------------------------------------------------
# Çift yönlü senkronizasyon
#-------------------------------------------------------------------------------
two_way_sync() {
    local dir_a="$1"
    local dir_b="$2"
    
    echo -e "${CYAN}[1/2] A → B senkronizasyonu...${NC}"
    sync_source_to_target "$dir_a" "$dir_b"
    
    echo -e "${CYAN}[2/2] B → A senkronizasyonu...${NC}"
    sync_source_to_target "$dir_b" "$dir_a"
}

#-------------------------------------------------------------------------------
# İstatistikleri göster
#-------------------------------------------------------------------------------
show_stats() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    SENKRONİZASYON RAPORU                         ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "  ${GREEN}Kopyalanan:${NC}   $COPIED_COUNT dosya ($(format_size $COPIED_SIZE))"
    echo -e "  ${YELLOW}Güncellenen:${NC}  $UPDATED_COUNT dosya ($(format_size $UPDATED_SIZE))"
    echo -e "  ${RED}Silinen:${NC}      $DELETED_COUNT dosya"
    echo -e "  ${BLUE}Atlanan:${NC}      $SKIPPED_COUNT dosya"
    echo -e "  ${RED}Hata:${NC}         $ERROR_COUNT"
    echo ""
    echo -e "  ${CYAN}Log dosyası:${NC}  $LOG_FILE"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
}

#===============================================================================
#                              ANA PROGRAM
#===============================================================================

# Sayaçları başlat
COPIED_COUNT=0
COPIED_SIZE=0
UPDATED_COUNT=0
UPDATED_SIZE=0
DELETED_COUNT=0
SKIPPED_COUNT=0
ERROR_COUNT=0
DRY_RUN=false
VERBOSE=false

# Argümanları işle
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--log)
            LOG_FILE="$2"
            shift 2
            ;;
        -t|--two-way)
            SYNC_MODE="two-way"
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

set -- "${POSITIONAL[@]}"

# Kaynak ve hedef klasör kontrolü
if [ $# -lt 2 ]; then
    echo -e "${RED}Hata: Kaynak ve hedef klasör belirtilmeli!${NC}"
    echo ""
    show_help
    exit 1
fi

SOURCE_DIR="$1"
TARGET_DIR="$2"

# Klasörlerin var olduğunu kontrol et
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}Hata: Kaynak klasör bulunamadı: $SOURCE_DIR${NC}"
    exit 1
fi

# Hedef klasörü oluştur (yoksa)
if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${YELLOW}Hedef klasör oluşturuluyor: $TARGET_DIR${NC}"
    mkdir -p "$TARGET_DIR"
fi

# Başlık
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              DOSYA SENKRONİZASYON ARACI v1.0                     ║${NC}"
echo -e "${CYAN}║            İşletim Sistemleri Dersi Projesi                      ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}Kaynak:${NC}  $SOURCE_DIR"
echo -e "  ${GREEN}Hedef:${NC}   $TARGET_DIR"
echo -e "  ${GREEN}Mod:${NC}     $SYNC_MODE"
[ "$DRY_RUN" = true ] && echo -e "  ${YELLOW}[DRY-RUN modu aktif - işlem yapılmayacak]${NC}"
echo ""

# Log dosyasına başlangıç yaz
echo "═══════════════════════════════════════════════════════════════════" >> "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] SENKRONİZASYON BAŞLADI" >> "$LOG_FILE"
echo "Kaynak: $SOURCE_DIR" >> "$LOG_FILE"
echo "Hedef: $TARGET_DIR" >> "$LOG_FILE"
echo "Mod: $SYNC_MODE" >> "$LOG_FILE"
echo "═══════════════════════════════════════════════════════════════════" >> "$LOG_FILE"

# Senkronizasyonu başlat
if [ "$SYNC_MODE" = "two-way" ]; then
    two_way_sync "$SOURCE_DIR" "$TARGET_DIR"
else
    echo -e "${CYAN}[1/2] Dosyalar senkronize ediliyor...${NC}"
    sync_source_to_target "$SOURCE_DIR" "$TARGET_DIR"
    
    echo -e "${CYAN}[2/2] Silinen dosyalar temizleniyor...${NC}"
    clean_target "$SOURCE_DIR" "$TARGET_DIR"
fi

# Log dosyasına bitiş yaz
echo "[$(date '+%Y-%m-%d %H:%M:%S')] SENKRONİZASYON TAMAMLANDI" >> "$LOG_FILE"
echo "Kopyalanan: $COPIED_COUNT, Güncellenen: $UPDATED_COUNT, Silinen: $DELETED_COUNT, Hata: $ERROR_COUNT" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# İstatistikleri göster
show_stats

exit 0
