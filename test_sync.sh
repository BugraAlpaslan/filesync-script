#!/bin/bash

#===============================================================================
#           DOSYA SENKRONİZASYON ARACI - TEST SÜİTİ
#===============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TEST_DIR="sync_test_$$"
PASSED=0
FAILED=0
TOTAL=0

#-------------------------------------------------------------------------------
# Test fonksiyonları
#-------------------------------------------------------------------------------

test_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║ TEST: $1${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
}

assert_file_exists() {
    ((TOTAL++))
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓ PASS:${NC} Dosya mevcut: $1"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL:${NC} Dosya bulunamadı: $1"
        ((FAILED++))
        return 1
    fi
}

assert_file_not_exists() {
    ((TOTAL++))
    if [ ! -f "$1" ]; then
        echo -e "${GREEN}✓ PASS:${NC} Dosya yok (beklenen): $1"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL:${NC} Dosya hala mevcut: $1"
        ((FAILED++))
        return 1
    fi
}

assert_files_equal() {
    ((TOTAL++))
    if cmp -s "$1" "$2"; then
        echo -e "${GREEN}✓ PASS:${NC} Dosyalar eşit: $1 == $2"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL:${NC} Dosyalar farklı: $1 != $2"
        ((FAILED++))
        return 1
    fi
}

assert_log_contains() {
    ((TOTAL++))
    if grep -q "$1" "$2"; then
        echo -e "${GREEN}✓ PASS:${NC} Log mesajı bulundu: '$1'"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL:${NC} Log mesajı bulunamadı: '$1'"
        ((FAILED++))
        return 1
    fi
}

cleanup() {
    rm -rf "$TEST_DIR"
}

#===============================================================================
#                              TEST SENARYOLARI
#===============================================================================

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     DOSYA SENKRONİZASYON ARACI - KAPSAMLI TEST SÜİTİ            ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"

# Test ortamını hazırla
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

#-------------------------------------------------------------------------------
# TEST 1: Temel Dosya Kopyalama
#-------------------------------------------------------------------------------
test_header "Temel Dosya Kopyalama"

mkdir -p source target
echo "Test dosyası 1" > source/file1.txt
echo "Test dosyası 2" > source/file2.txt

../sync_tool.sh source target -l test1.log > /dev/null 2>&1

assert_file_exists "target/file1.txt"
assert_file_exists "target/file2.txt"
assert_files_equal "source/file1.txt" "target/file1.txt"
assert_log_contains "KOPYALANDI" "test1.log"

rm -rf source target test1.log

#-------------------------------------------------------------------------------
# TEST 2: Alt Klasör Desteği
#-------------------------------------------------------------------------------
test_header "Alt Klasör ve Derin Dizin Yapısı"

mkdir -p source/level1/level2/level3 target
echo "Derin dosya" > source/level1/level2/level3/deep.txt
echo "Orta seviye" > source/level1/middle.txt

../sync_tool.sh source target -l test2.log > /dev/null 2>&1

assert_file_exists "target/level1/level2/level3/deep.txt"
assert_file_exists "target/level1/middle.txt"
assert_files_equal "source/level1/level2/level3/deep.txt" "target/level1/level2/level3/deep.txt"

rm -rf source target test2.log

#-------------------------------------------------------------------------------
# TEST 3: Dosya Güncelleme (Hash Değişimi)
#-------------------------------------------------------------------------------
test_header "Dosya Güncelleme Tespiti"

mkdir -p source target
echo "Orijinal içerik" > source/file.txt
cp source/file.txt target/file.txt

# İlk sync - değişiklik yok
../sync_tool.sh source target -l test3a.log > /dev/null 2>&1
assert_log_contains "Değişiklik yok" "test3a.log"

# Dosyayı değiştir
sleep 1
echo "Güncellenmiş içerik" > source/file.txt

# İkinci sync - güncelleme olmalı
../sync_tool.sh source target -l test3b.log > /dev/null 2>&1
assert_files_equal "source/file.txt" "target/file.txt"
assert_log_contains "GÜNCELLENDİ" "test3b.log"

rm -rf source target test3a.log test3b.log

#-------------------------------------------------------------------------------
# TEST 4: Dosya Silme İşlemi
#-------------------------------------------------------------------------------
test_header "Silinen Dosyaların Temizlenmesi"

mkdir -p source target
echo "Silinecek dosya" > source/temp.txt
echo "Kalacak dosya" > source/keep.txt

# İlk sync - her iki dosya da kopyalanır
../sync_tool.sh source target -l test4a.log > /dev/null 2>&1
assert_file_exists "target/temp.txt"
assert_file_exists "target/keep.txt"

# Kaynak dosyayı sil
rm source/temp.txt

# İkinci sync - hedefte de silinmeli
../sync_tool.sh source target -l test4b.log > /dev/null 2>&1
assert_file_not_exists "target/temp.txt"
assert_file_exists "target/keep.txt"
assert_log_contains "SİLİNDİ" "test4b.log"

rm -rf source target test4a.log test4b.log

#-------------------------------------------------------------------------------
# TEST 5: Büyük Dosya Kontrolü
#-------------------------------------------------------------------------------
test_header "100 MB Dosya Boyutu Limiti"

mkdir -p source target

# 50 MB dosya - kopyalanmalı
dd if=/dev/zero of=source/small.dat bs=1M count=50 2>/dev/null
../sync_tool.sh source target -l test5a.log > /dev/null 2>&1
assert_file_exists "target/small.dat"

# 150 MB dosya - atlanmalı
dd if=/dev/zero of=source/large.dat bs=1M count=150 2>/dev/null
../sync_tool.sh source target -l test5b.log > /dev/null 2>&1
assert_file_not_exists "target/large.dat"
assert_log_contains "ATLANDI" "test5b.log"

rm -rf source target test5a.log test5b.log

#-------------------------------------------------------------------------------
# TEST 6: Çok Sayıda Dosya
#-------------------------------------------------------------------------------
test_header "100 Dosya ile Performans Testi"

mkdir -p source target
for i in {1..100}; do
    echo "Dosya $i içeriği" > "source/file_$i.txt"
done

time ../sync_tool.sh source target -l test6.log > /dev/null 2>&1

# Rastgele 10 dosya kontrol et
for i in 5 15 25 35 45 55 65 75 85 95; do
    assert_file_exists "target/file_$i.txt"
done

rm -rf source target test6.log

#-------------------------------------------------------------------------------
# TEST 7: Özel Karakterler ve Boşluklar
#-------------------------------------------------------------------------------
test_header "Özel Karakterli Dosya Adları"

mkdir -p source target
echo "Test" > "source/dosya ile boşluk.txt"
echo "Test" > "source/özel-karakter-türkçe.txt"
echo "Test" > "source/file_with_123.txt"

../sync_tool.sh source target -l test7.log > /dev/null 2>&1

assert_file_exists "target/dosya ile boşluk.txt"
assert_file_exists "target/özel-karakter-türkçe.txt"
assert_file_exists "target/file_with_123.txt"

rm -rf source target test7.log

#-------------------------------------------------------------------------------
# TEST 8: Boş Klasörler
#-------------------------------------------------------------------------------
test_header "Boş Klasör İşleme"

mkdir -p source/empty_folder target
echo "Test" > source/normal.txt

../sync_tool.sh source target -l test8.log > /dev/null 2>&1

assert_file_exists "target/normal.txt"
# Boş klasör kopyalanmamalı (sadece dosyalar)

rm -rf source target test8.log

#-------------------------------------------------------------------------------
# TEST 9: Dry-Run Modu
#-------------------------------------------------------------------------------
test_header "Dry-Run Modu (Simülasyon)"

mkdir -p source target
echo "Test dosya" > source/dryrun.txt

../sync_tool.sh source target -d -l test9.log > /dev/null 2>&1

assert_file_not_exists "target/dryrun.txt"
assert_log_contains "DRY-RUN" "test9.log"

rm -rf source target test9.log

#-------------------------------------------------------------------------------
# TEST 10: Çift Yönlü Senkronizasyon
#-------------------------------------------------------------------------------
test_header "Çift Yönlü Senkronizasyon"

mkdir -p dirA dirB
echo "A'dan" > dirA/from_a.txt
echo "B'den" > dirB/from_b.txt

../sync_tool.sh dirA dirB --two-way -l test10.log > /dev/null 2>&1

assert_file_exists "dirA/from_b.txt"
assert_file_exists "dirB/from_a.txt"

rm -rf dirA dirB test10.log

#-------------------------------------------------------------------------------
# TEST 11: İzin ve Timestamp Koruması
#-------------------------------------------------------------------------------
test_header "Dosya İzinleri"

mkdir -p source target
echo "Özel izinli" > source/special.txt
chmod 600 source/special.txt

../sync_tool.sh source target -l test11.log > /dev/null 2>&1

assert_file_exists "target/special.txt"

rm -rf source target test11.log

#-------------------------------------------------------------------------------
# TEST 12: Sembolik Linkler
#-------------------------------------------------------------------------------
test_header "Sembolik Link İşleme"

mkdir -p source target
echo "Asıl dosya" > source/original.txt
ln -s original.txt source/link.txt

../sync_tool.sh source target -l test12.log > /dev/null 2>&1

# Link'in kendisi değil, hedefi kopyalanmalı
assert_file_exists "target/original.txt"

rm -rf source target test12.log

#-------------------------------------------------------------------------------
# TEST 13: Farklı Dosya Türleri
#-------------------------------------------------------------------------------
test_header "Çeşitli Dosya Formatları"

mkdir -p source target
echo "Text" > source/file.txt
echo "Binary data" > source/file.bin
echo "#!/bin/bash" > source/script.sh
echo "Data" > source/file.dat

chmod +x source/script.sh

../sync_tool.sh source target -l test13.log > /dev/null 2>&1

assert_file_exists "target/file.txt"
assert_file_exists "target/file.bin"
assert_file_exists "target/script.sh"
assert_file_exists "target/file.dat"

rm -rf source target test13.log

#-------------------------------------------------------------------------------
# TEST 14: Ardışık Senkronizasyonlar
#-------------------------------------------------------------------------------
test_header "Birden Fazla Ardışık Sync"

mkdir -p source target

# 1. Sync
echo "Versiyon 1" > source/file.txt
../sync_tool.sh source target > /dev/null 2>&1

# 2. Sync - değişiklik yok
../sync_tool.sh source target -l test14a.log > /dev/null 2>&1
assert_log_contains "Değişiklik yok" "test14a.log"

# 3. Sync - güncelleme
echo "Versiyon 2" > source/file.txt
../sync_tool.sh source target -l test14b.log > /dev/null 2>&1
assert_log_contains "GÜNCELLENDİ" "test14b.log"

rm -rf source target test14a.log test14b.log

#-------------------------------------------------------------------------------
# TEST 15: Hata Durumları
#-------------------------------------------------------------------------------
test_header "Hata Yönetimi"

# Var olmayan kaynak klasör
../sync_tool.sh nonexistent target 2>/dev/null
if [ $? -ne 0 ]; then
    echo -e "${GREEN}✓ PASS:${NC} Var olmayan kaynak klasör doğru şekilde reddedildi"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL:${NC} Var olmayan kaynak klasör kabul edildi"
    ((FAILED++))
fi
((TOTAL++))

# Hedef klasör otomatik oluşturulmalı
mkdir -p source
echo "Test" > source/auto.txt
../sync_tool.sh source auto_created_target > /dev/null 2>&1
assert_file_exists "auto_created_target/auto.txt"

rm -rf source auto_created_target

#===============================================================================
#                              TEST SONUÇLARI
#===============================================================================

cd ..
cleanup

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    TEST SONUÇLARI                                ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}Başarılı:${NC}  $PASSED / $TOTAL"
echo -e "  ${RED}Başarısız:${NC} $FAILED / $TOTAL"
echo -e "  ${BLUE}Başarı Oranı:${NC} $(echo "scale=2; $PASSED * 100 / $TOTAL" | bc)%"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ TÜM TESTLER BAŞARILI!${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}✗ BAZI TESTLER BAŞARISIZ${NC}"
    echo ""
    exit 1
fi
