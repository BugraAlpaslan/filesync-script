#!/bin/bash

#===============================================================================
#        DOSYA SENKRONIZASYON ARACI - GELİŞMİŞ GRAFIKSEL ARAYÜZ
#===============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENGINE="$SCRIPT_DIR/sync_tool.sh"
LOG_DIR="$HOME/.sync_logs"
CONFIG_FILE="$HOME/.sync_config"
APP_NAME="Dosya Senkronizasyon Aracı v2.0"

mkdir -p "$LOG_DIR"

#-------------------------------------------------------------------------------
# VARSAYILAN AYARLAR
#-------------------------------------------------------------------------------
SYNC_MODE="one-way"
DRY_RUN=false
VERBOSE=false
CUSTOM_LOG=""
MAX_SIZE="100"

# Önceki ayarları yükle
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

#-------------------------------------------------------------------------------
# KONTROLLER
#-------------------------------------------------------------------------------
if ! command -v zenity &> /dev/null; then
    echo "Hata: Zenity bulunamadı. Kurmak için:"
    echo "Ubuntu/Debian: sudo apt install zenity"
    exit 1
fi

[ -f "$ENGINE" ] || {
    zenity --error \
    --title="Hata" \
    --width=400 \
    --text="sync_tool.sh bulunamadı.\n\nAynı klasörde olmalıdır."
    exit 1
}

#-------------------------------------------------------------------------------
# BAŞLANGIÇ EKRANI
#-------------------------------------------------------------------------------
zenity --info \
--title="$APP_NAME" \
--width=600 \
--height=350 \
--text="<span size='xx-large' weight='bold'>📁 Dosya Senkronizasyon Aracı</span>\n\n\
<span size='large'>Gelişmiş Özellikler:</span>\n\n\
✓ Tek ve çift yönlü senkronizasyon\n\
✓ Dry-run (simülasyon) modu\n\
✓ Detaylı log kayıtları\n\
✓ Dosya boyutu filtreleme\n\
✓ Verbose (ayrıntılı) çıktı\n\
✓ Önceki ayarları hatırlama\n\n\
<span size='small' style='italic'>İşletim Sistemleri Dersi Projesi</span>"

#-------------------------------------------------------------------------------
# ANA MENÜ - GELİŞMİŞ AYARLAR
#-------------------------------------------------------------------------------
while true; do
    MENU_CHOICE=$(zenity --list \
        --title="$APP_NAME - Ana Menü" \
        --text="Ne yapmak istersiniz?" \
        --radiolist \
        --column="Seç" --column="İşlem" --column="Açıklama" \
        TRUE "Yeni Senkronizasyon" "Klasörleri senkronize et" \
        FALSE "Gelişmiş Ayarlar" "Mod, dry-run, verbose vb." \
        FALSE "Geçmiş Logları Görüntüle" "Önceki senkronizasyonları incele" \
        FALSE "Hızlı Yardım" "Kullanım kılavuzu" \
        FALSE "Çıkış" "Programdan çık" \
        --width=700 --height=400)
    
    [ -z "$MENU_CHOICE" ] && exit 0
    
    case "$MENU_CHOICE" in
        "Yeni Senkronizasyon")
            break
            ;;
        "Gelişmiş Ayarlar")
            # Ayarlar menüsü
            SETTINGS=$(zenity --forms \
                --title="Gelişmiş Ayarlar" \
                --text="Senkronizasyon ayarlarını yapılandırın:" \
                --add-combo="Senkronizasyon Modu" --combo-values="Tek Yönlü|Çift Yönlü" \
                --add-combo="Dry-Run (Simülasyon)" --combo-values="Hayır|Evet" \
                --add-combo="Verbose (Detaylı Çıktı)" --combo-values="Hayır|Evet" \
                --add-entry="Maksimum Dosya Boyutu (MB)" \
                --add-entry="Özel Log Dosya Adı (opsiyonel)" \
                --separator="|" \
                --width=600 --height=400)
            
            if [ -n "$SETTINGS" ]; then
                IFS='|' read -r MODE_CHOICE DRY_CHOICE VERBOSE_CHOICE SIZE_INPUT LOG_INPUT <<< "$SETTINGS"
                
                # Ayarları uygula
                [ "$MODE_CHOICE" == "Çift Yönlü" ] && SYNC_MODE="two-way" || SYNC_MODE="one-way"
                [ "$DRY_CHOICE" == "Evet" ] && DRY_RUN=true || DRY_RUN=false
                [ "$VERBOSE_CHOICE" == "Evet" ] && VERBOSE=true || VERBOSE=false
                [ -n "$SIZE_INPUT" ] && MAX_SIZE="$SIZE_INPUT"
                [ -n "$LOG_INPUT" ] && CUSTOM_LOG="$LOG_INPUT"
                
                # Ayarları kaydet
                cat > "$CONFIG_FILE" << EOF
SYNC_MODE="$SYNC_MODE"
DRY_RUN=$DRY_RUN
VERBOSE=$VERBOSE
MAX_SIZE="$MAX_SIZE"
CUSTOM_LOG="$CUSTOM_LOG"
EOF
                
                zenity --info --title="Ayarlar Kaydedildi" --width=400 \
                --text="✅ Ayarlar başarıyla kaydedildi.\n\nBir sonraki açılışta bu ayarlar kullanılacak."
            fi
            ;;
        "Geçmiş Logları Görüntüle")
            # Log dosyalarını listele
            LOG_FILES=$(ls -t "$LOG_DIR"/sync_*.log 2>/dev/null | head -20)
            
            if [ -z "$LOG_FILES" ]; then
                zenity --info --title="Log Bulunamadı" --width=400 \
                --text="Henüz senkronizasyon kaydı bulunmuyor."
            else
                # Log dosyası seç
                SELECTED_LOG=$(zenity --list \
                    --title="Log Dosyası Seçin" \
                    --text="Görüntülemek istediğiniz log dosyasını seçin:" \
                    --column="Log Dosyaları" \
                    $(ls -t "$LOG_DIR"/sync_*.log 2>/dev/null | head -20 | xargs -n1 basename) \
                    --width=600 --height=400)
                
                if [ -n "$SELECTED_LOG" ]; then
                    zenity --text-info \
                        --title="Log: $SELECTED_LOG" \
                        --filename="$LOG_DIR/$SELECTED_LOG" \
                        --width=800 --height=600
                fi
            fi
            ;;
        "Hızlı Yardım")
            zenity --info \
            --title="Kullanım Kılavuzu" \
            --width=700 \
            --height=500 \
            --text="<span size='large' weight='bold'>🛈 Kullanım Kılavuzu</span>\n\n\
<b>Senkronizasyon Modları:</b>\n\
• <b>Tek Yönlü:</b> Kaynak → Hedef (standart yedekleme)\n\
• <b>Çift Yönlü:</b> Kaynak ↔ Hedef (her iki taraf da güncellenir)\n\n\
<b>Dry-Run Modu:</b>\n\
• İşlemleri gerçekleştirmeden önce simüle eder\n\
• Ne yapılacağını gösterir ama dosyalara dokunmaz\n\
• İlk kez kullanımlarda önerilir\n\n\
<b>Verbose Modu:</b>\n\
• Tüm işlemleri detaylı gösterir\n\
• Debug için yararlıdır\n\n\
<b>Dosya Boyutu Limiti:</b>\n\
• Belirtilen boyuttan büyük dosyalar atlanır\n\
• Varsayılan: 100 MB\n\n\
<b>Log Dosyaları:</b>\n\
• Tüm işlemler ~/.sync_logs/ klasörüne kaydedilir\n\
• 'Geçmiş Loglar' menüsünden görüntülenebilir"
            ;;
        "Çıkış")
            exit 0
            ;;
    esac
done

#-------------------------------------------------------------------------------
# MEVCUT AYARLARI GÖSTER
#-------------------------------------------------------------------------------
CURRENT_SETTINGS="<b>Mevcut Ayarlar:</b>\n\n"
CURRENT_SETTINGS+="• Mod: <span color='blue'>"
[ "$SYNC_MODE" == "two-way" ] && CURRENT_SETTINGS+="Çift Yönlü" || CURRENT_SETTINGS+="Tek Yönlü"
CURRENT_SETTINGS+="</span>\n"
CURRENT_SETTINGS+="• Dry-Run: <span color='blue'>"
[ "$DRY_RUN" == true ] && CURRENT_SETTINGS+="Aktif ✓" || CURRENT_SETTINGS+="Kapalı"
CURRENT_SETTINGS+="</span>\n"
CURRENT_SETTINGS+="• Verbose: <span color='blue'>"
[ "$VERBOSE" == true ] && CURRENT_SETTINGS+="Aktif ✓" || CURRENT_SETTINGS+="Kapalı"
CURRENT_SETTINGS+="</span>\n"
CURRENT_SETTINGS+="• Max Dosya Boyutu: <span color='blue'>${MAX_SIZE} MB</span>\n\n"
CURRENT_SETTINGS+="<span size='small' style='italic'>Ayarları değiştirmek için Ana Menü → Gelişmiş Ayarlar</span>"

zenity --info \
--title="Mevcut Ayarlar" \
--width=500 \
--height=300 \
--text="$CURRENT_SETTINGS"

#-------------------------------------------------------------------------------
# KLASÖR SEÇIMI
#-------------------------------------------------------------------------------
SOURCE=$(zenity --file-selection --directory \
--title="1/2 - Kaynak Klasörü Seçin" \
--filename="$HOME/")

[ -z "$SOURCE" ] && exit 0

TARGET=$(zenity --file-selection --directory \
--title="2/2 - Hedef Klasörü Seçin" \
--filename="$HOME/")

[ -z "$TARGET" ] && exit 0

# Aynı klasör kontrolü
if [ "$SOURCE" == "$TARGET" ]; then
    zenity --error \
    --title="Hata" \
    --width=400 \
    --text="❌ Kaynak ve hedef klasör aynı olamaz!\n\nLütfen farklı klasörler seçin."
    exit 1
fi

#-------------------------------------------------------------------------------
# ÖZET VE ONAY EKRANI
#-------------------------------------------------------------------------------
MODE_TEXT="Tek Yönlü (One-Way)"
MODE_ICON="→"
[ "$SYNC_MODE" == "two-way" ] && MODE_TEXT="Çift Yönlü (Two-Way)" && MODE_ICON="↔"

DRY_WARNING=""
[ "$DRY_RUN" == true ] && DRY_WARNING="\n<span color='orange' weight='bold'>⚠ DRY-RUN MODU AKTİF - Hiçbir değişiklik yapılmayacak!</span>"

SUMMARY="<span size='large' weight='bold'>📋 Senkronizasyon Özeti</span>\n\n"
SUMMARY+="<b>Mod:</b> $MODE_TEXT $MODE_ICON\n\n"
SUMMARY+="<b>Kaynak:</b>\n<tt>  $SOURCE</tt>\n\n"
SUMMARY+="<b>Hedef:</b>\n<tt>  $TARGET</tt>\n\n"
SUMMARY+="<b>Seçenekler:</b>\n"
SUMMARY+="  • Dry-Run: "
[ "$DRY_RUN" == true ] && SUMMARY+="<span color='orange'>Evet ⚠</span>" || SUMMARY+="Hayır"
SUMMARY+="\n  • Verbose: "
[ "$VERBOSE" == true ] && SUMMARY+="Evet" || SUMMARY+="Hayır"
SUMMARY+="\n  • Max Boyut: ${MAX_SIZE} MB"
SUMMARY+="$DRY_WARNING"

zenity --question \
--title="Onay Gerekli" \
--width=600 \
--height=400 \
--ok-label="✓ Başlat" \
--cancel-label="✗ İptal" \
--text="$SUMMARY"

[ $? -ne 0 ] && exit 0

#-------------------------------------------------------------------------------
# LOG DOSYASINI HAZIRLA
#-------------------------------------------------------------------------------
if [ -n "$CUSTOM_LOG" ]; then
    LOG_FILE="$LOG_DIR/$CUSTOM_LOG"
else
    LOG_FILE="$LOG_DIR/sync_$(date +%Y%m%d_%H%M%S).log"
fi

#-------------------------------------------------------------------------------
# KOMUT SATIRI PARAMETRELERINI OLUŞTUR
#-------------------------------------------------------------------------------
CMD_OPTS=""
[ "$SYNC_MODE" == "two-way" ] && CMD_OPTS+=" --two-way"
[ "$DRY_RUN" == true ] && CMD_OPTS+=" --dry-run"
[ "$VERBOSE" == true ] && CMD_OPTS+=" --verbose"

#-------------------------------------------------------------------------------
# SENKRONIZASYON ÇALIŞTIR
#-------------------------------------------------------------------------------
TEMP_OUTPUT=$(mktemp)

(
    echo "10"; echo "# Başlatılıyor..."
    sleep 0.3
    
    echo "20"; echo "# Kaynak klasör analiz ediliyor..."
    sleep 0.5
    
    echo "35"; echo "# Hedef klasör kontrol ediliyor..."
    sleep 0.5
    
    echo "50"; echo "# Dosyalar karşılaştırılıyor..."
    sleep 0.7
    
    if [ "$DRY_RUN" == true ]; then
        echo "70"; echo "# Simülasyon yapılıyor (DRY-RUN)..."
    else
        echo "70"; echo "# Dosyalar işleniyor..."
    fi
    
    # Asıl senkronizasyon
    "$ENGINE" "$SOURCE" "$TARGET" $CMD_OPTS -l "$LOG_FILE" > "$TEMP_OUTPUT" 2>&1
    SYNC_EXIT_CODE=$?
    
    echo "90"; echo "# Sonuçlar hazırlanıyor..."
    sleep 0.3
    
    echo "100"; echo "# Tamamlandı!"
    
    exit $SYNC_EXIT_CODE
    
) | zenity --progress \
--title="Senkronizasyon Çalışıyor..." \
--width=500 \
--height=150 \
--percentage=0 \
--auto-close \
--no-cancel

SYNC_RESULT=$?

#-------------------------------------------------------------------------------
# SONUÇLARI GÖSTER
#-------------------------------------------------------------------------------
if [ -f "$LOG_FILE" ]; then
    # İstatistikleri hesapla - Sadece gerçek işlem satırlarını say
    COPIED=$(grep "KOPYALANDI:" "$LOG_FILE" | grep -v "DRY-RUN" | grep -v "SENKRONİZASYON" | wc -l 2>/dev/null)
    UPDATED=$(grep "GÜNCELLENDİ:" "$LOG_FILE" | grep -v "DRY-RUN" | grep -v "SENKRONİZASYON" | wc -l 2>/dev/null)
    DELETED=$(grep "SİLİNDİ:" "$LOG_FILE" | grep -v "DRY-RUN" | grep -v "SENKRONİZASYON" | wc -l 2>/dev/null)
    SKIPPED=$(grep "ATLANDI:" "$LOG_FILE" | wc -l 2>/dev/null)
    ERRORS=$(grep "HATA:" "$LOG_FILE" | wc -l 2>/dev/null)
    
    # Boş değerleri 0'a çevir
    COPIED=${COPIED:-0}
    UPDATED=${UPDATED:-0}
    DELETED=${DELETED:-0}
    SKIPPED=${SKIPPED:-0}
    ERRORS=${ERRORS:-0}
    
    TOTAL=$((COPIED + UPDATED + DELETED))
    
    # Sonuç başlığı
    if [ $SYNC_RESULT -eq 0 ]; then
        if [ "$DRY_RUN" == true ]; then
            RESULT_TITLE="🔍 Simülasyon Tamamlandı"
            RESULT_ICON="info"
        else
            RESULT_TITLE="✅ Senkronizasyon Başarılı"
            RESULT_ICON="info"
        fi
    else
        RESULT_TITLE="⚠ Senkronizasyon Hatalarla Tamamlandı"
        RESULT_ICON="warning"
    fi
    
    # Mod bilgisi
    MODE_INFO="<b>Mod:</b> $MODE_TEXT"
    [ "$DRY_RUN" == true ] && MODE_INFO+="\n<b>Durum:</b> <span color='orange'>Simülasyon (Değişiklik yapılmadı)</span>"
    
    # Sonuç mesajı
    RESULT_MSG="<span size='large' weight='bold'>$RESULT_TITLE</span>\n\n"
    RESULT_MSG+="$MODE_INFO\n\n"
    
    # Yapılan işlem bilgisi
    RESULT_MSG+="<b>Senkronize Edilen Klasörler:</b>\n"
    RESULT_MSG+="━━━━━━━━━━━━━━━━━━━━━━\n"
    RESULT_MSG+="  📂 Kaynak: <tt>$(basename "$SOURCE")</tt>\n"
    RESULT_MSG+="     <span size='small' color='gray'>$SOURCE</span>\n\n"
    if [ "$SYNC_MODE" == "two-way" ]; then
        RESULT_MSG+="  📂 Hedef: <tt>$(basename "$TARGET")</tt> $MODE_ICON\n"
    else
        RESULT_MSG+="  📁 Hedef: <tt>$(basename "$TARGET")</tt> $MODE_ICON\n"
    fi
    RESULT_MSG+="     <span size='small' color='gray'>$TARGET</span>\n\n"
    
    RESULT_MSG+="<b>İstatistikler:</b>\n"
    RESULT_MSG+="━━━━━━━━━━━━━━━━━━━━━━\n"
    RESULT_MSG+="  Toplam İşlem: <b>$TOTAL</b>\n\n"
    RESULT_MSG+="  🟢 Kopyalanan:  <span color='green'>$COPIED</span>\n"
    RESULT_MSG+="  🟡 Güncellenen:  <span color='orange'>$UPDATED</span>\n"
    RESULT_MSG+="  🔴 Silinen:  <span color='red'>$DELETED</span>\n"
    RESULT_MSG+="  🔵 Atlanan:  <span color='blue'>$SKIPPED</span>\n"
    [ $ERRORS -gt 0 ] && RESULT_MSG+="  ⚠ Hata:  <span color='red' weight='bold'>$ERRORS</span>\n"
    RESULT_MSG+="\n<span size='small'>Log: <tt>$(basename "$LOG_FILE")</tt></span>"
    
    # Sonuç penceresini göster
    RESULT_ACTION=$(zenity --$RESULT_ICON \
        --title="$RESULT_TITLE" \
        --width=500 \
        --height=400 \
        --ok-label="✓ Tamam" \
        --extra-button="📄 Log'u Göster" \
        --extra-button="📁 Log Klasörünü Aç" \
        --text="$RESULT_MSG")
    
    ACTION_RESULT=$?
    
    # Kullanıcı seçimine göre işlem yap
    if [ $ACTION_RESULT -eq 1 ]; then
        # Log'u göster butonuna basıldı
        if [ "$RESULT_ACTION" == "📄 Log'u Göster" ]; then
            zenity --text-info \
                --title="Detaylı Log: $(basename "$LOG_FILE")" \
                --filename="$LOG_FILE" \
                --width=900 \
                --height=600 \
                --font="Monospace 10"
        elif [ "$RESULT_ACTION" == "📁 Log Klasörünü Aç" ]; then
            xdg-open "$LOG_DIR" 2>/dev/null || nautilus "$LOG_DIR" 2>/dev/null
        fi
    fi
    
    # Eğer değişiklik varsa, özet listesini göster
    if [ $TOTAL -gt 0 ] && [ "$DRY_RUN" != true ]; then
        SHOW_DETAILS=$(zenity --question \
            --title="Değişiklik Detayları" \
            --width=400 \
            --ok-label="📋 Değişiklikleri Göster" \
            --cancel-label="⏭ Atla" \
            --text="Yapılan değişikliklerin detaylı listesini görmek ister misiniz?")
        
        if [ $? -eq 0 ]; then
            # Son değişiklikleri filtrele ve göster
            {
                echo "=== KOPYALANAN DOSYALAR ==="
                grep "KOPYALANDI" "$LOG_FILE" | grep -v "DRY-RUN" | tail -50
                echo ""
                echo "=== GÜNCELLENENLİKLER ==="
                grep "GÜNCELLENDİ" "$LOG_FILE" | grep -v "DRY-RUN" | tail -50
                echo ""
                echo "=== SİLİNENLER ==="
                grep "SİLİNDİ" "$LOG_FILE" | grep -v "DRY-RUN" | tail -50
            } | zenity --text-info \
                --title="Değişiklik Detayları (Son 50'şer)" \
                --width=900 \
                --height=600 \
                --font="Monospace 10"
        fi
    fi
    
else
    zenity --error \
    --title="Hata" \
    --width=400 \
    --text="❌ İşlem tamamlanamadı.\n\nLog dosyası oluşturulamadı.\n\nLütfen sync_tool.sh'ın doğru çalıştığından emin olun."
fi

# Geçici dosyayı temizle
rm -f "$TEMP_OUTPUT"

#-------------------------------------------------------------------------------
# DEVAM ET VEYA ÇIK
#-------------------------------------------------------------------------------
FINAL_MSG="<span size='large' weight='bold'>✅ İşlem Tamamlandı</span>\n\n"
FINAL_MSG+="<b>Senkronize Edilen:</b>\n"
FINAL_MSG+="  📂 <tt>$SOURCE</tt>\n"
if [ "$SYNC_MODE" == "two-way" ]; then
    FINAL_MSG+="  ↔\n"
else
    FINAL_MSG+="  →\n"
fi
FINAL_MSG+="  📁 <tt>$TARGET</tt>\n\n"
FINAL_MSG+="<b>Sonuç:</b>\n"
FINAL_MSG+="  • Kopyalanan: <span color='green'><b>$COPIED</b></span>\n"
FINAL_MSG+="  • Güncellenen: <span color='orange'><b>$UPDATED</b></span>\n"
FINAL_MSG+="  • Silinen: <span color='red'><b>$DELETED</b></span>\n"
FINAL_MSG+="  • Toplam: <b>$TOTAL</b> işlem\n\n"
FINAL_MSG+="Ne yapmak istersiniz?"

CONTINUE_CHOICE=$(zenity --question \
    --title="İşlem Tamamlandı" \
    --width=500 \
    --height=350 \
    --ok-label="🔄 Yeni Senkronizasyon" \
    --cancel-label="❌ Çıkış" \
    --text="$FINAL_MSG")

if [ $? -eq 0 ]; then
    # Yeni senkronizasyon için programı yeniden başlat
    exec "$0"
else
    exit 0
fi
