#!/usr/bin/env bash
# shellcheck source=lib.sh
SELF_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$SELF_DIR/lib.sh"
# ============================================================
#  DỌN DẸP HỆ THỐNG - Giải phóng dung lượng và dọn cache
#  Phiên bản: 2.0
# ============================================================


# ===== HÀM TIỆN ÍCH =====
in_tieu_de() {
    echo -e "\n${TIM}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${TIM}║            🧹  DỌN DẸP HỆ THỐNG                   ║${RESET}"
    echo -e "${TIM}╚════════════════════════════════════════════════════╝${RESET}\n"
}

# Chuyển bytes sang dạng dễ đọc (KB, MB, GB)
dinh_dang_dung_luong() {
    local bytes=$1
    # Dùng bash arithmetic thuần — không cần bc
    if (( bytes >= 1073741824 )); then
        printf "%d.%02d GB
" $((bytes / 1073741824)) $(( (bytes % 1073741824) * 100 / 1073741824 ))
    elif (( bytes >= 1048576 )); then
        printf "%d.%d MB
" $((bytes / 1048576)) $(( (bytes % 1048576) * 10 / 1048576 ))
    elif (( bytes >= 1024 )); then
        printf "%d KB
" $((bytes / 1024))
    else
        printf "%d Bytes
" "$bytes"
    fi
}

lay_dung_luong_da_dung_bytes() {
    df --output=used / | tail -1 | tr -d ' '
}

in_tieu_de

# ===== ĐO DUNG LƯỢNG TRƯỚC =====
echo -e "${VANG}📊 Kiểm tra dung lượng trước khi dọn...${RESET}"
TRUOC_KB=$(lay_dung_luong_da_dung_bytes)
echo -e "   💾 Đang dùng: ${VANG}$(dinh_dang_dung_luong $((TRUOC_KB * 1024)))${RESET}\n"

TONG_GIAI_PHONG=0
DONRAC_LOG="$HOME/.donrac_history"

# Xử lý tham số --lich-su
if [ "${1:-}" = "--lich-su" ]; then
    echo -e "\n${TIM}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${TIM}║         📜  LỊCH SỬ DỌN DẸP                        ║${RESET}"
    echo -e "${TIM}╚════════════════════════════════════════════════════╝${RESET}\n"
    if [ ! -f "$DONRAC_LOG" ] || [ ! -s "$DONRAC_LOG" ]; then
        echo -e "${VANG}Chưa có lịch sử dọn dẹp nào.${RESET}\n"
        exit 0
    fi
    printf "   ${TRANG}%-20s %-12s %s${RESET}\n" "Thời gian" "Giải phóng" "Ghi chú"
    echo -e "   ${VANG}$(printf '%.0s─' {1..50})${RESET}"
    dem=0
    while IFS='|' read -r tg gp ghi; do
        printf "   %-20s ${XANH}%-12s${RESET} %s\n" "$tg" "$gp" "$ghi"
        dem=$((dem+1))
    done < "$DONRAC_LOG"
    echo -e "\n   ${VANG}Tổng số lần dọn: ${TIM}${dem}${RESET}\n"
    exit 0
fi

# ===== ƯỚC TÍNH TRƯỚC KHI DỌN =====
uoc_tinh() {
    echo -e "\n${TIM}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${TIM}║       📊  DỰ ĐOÁN DUNG LƯỢNG SẼ GIẢI PHÓNG        ║${RESET}"
    echo -e "${TIM}╚════════════════════════════════════════════════════╝${RESET}\n"

    local tong_uoc=0

    # APT cache
    local apt_kb; apt_kb=$(du -sk /var/cache/apt/archives 2>/dev/null | awk '{print $1}' || echo 0)
    echo -e "   📦 Cache APT        : ${VANG}$(dinh_dang_dung_luong $((apt_kb * 1024)))${RESET}"
    tong_uoc=$((tong_uoc + apt_kb))

    # Thumbnails
    local thumb_kb; thumb_kb=$(du -sk ~/.cache/thumbnails 2>/dev/null | awk '{print $1}' || echo 0)
    echo -e "   🖼️  Thumbnails cũ    : ${VANG}$(dinh_dang_dung_luong $((thumb_kb * 1024)))${RESET}"
    tong_uoc=$((tong_uoc + thumb_kb))

    # Cache người dùng > 30 ngày
    local cache_kb=0
    cache_kb=$(find ~/.cache -type f -atime +30 -exec du -sk {} + 2>/dev/null | awk '{s+=$1} END {print s+0}')
    echo -e "   ⏰  Cache > 30 ngày  : ${VANG}$(dinh_dang_dung_luong $((cache_kb * 1024)))${RESET}"
    tong_uoc=$((tong_uoc + cache_kb))

    # Journal logs
    local log_kb=0
    if command -v journalctl &>/dev/null; then
        # journalctl báo dạng "330.0M in ..." (số dính liền đơn vị, không có
        # khoảng trắng ở giữa), nên phải tách số và đơn vị K/M/G riêng.
        # Không khớp được (vd journal tắt) thì giữ 0 thay vì để trống.
        local log_txt; log_txt=$(journalctl --disk-usage 2>/dev/null | grep -oP '[\d.]+[KMGT](?= in)' | head -1 || true)
        if [ -n "$log_txt" ]; then
            local log_so; log_so=${log_txt%[KMGT]}; log_so=${log_so%.*}
            [ -z "$log_so" ] && log_so=0
            case "$log_txt" in
                *K) log_kb=$log_so ;;
                *M) log_kb=$(( log_so * 1024 )) ;;
                *G) log_kb=$(( log_so * 1024 * 1024 )) ;;
                *) log_kb=0 ;;
            esac
        fi
        echo -e "   📋 Journal logs     : ${VANG}$(dinh_dang_dung_luong $((log_kb * 1024)))${RESET} (giữ lại 7 ngày)"
        tong_uoc=$((tong_uoc + log_kb))
    fi

    # Tệp tạm /tmp
    local tmp_kb; tmp_kb=$(find /tmp -maxdepth 1 -type f -atime +1 -exec du -sk {} + 2>/dev/null | awk '{s+=$1} END {print s+0}')
    echo -e "   🗃️  Tệp tạm /tmp     : ${VANG}$(dinh_dang_dung_luong $((tmp_kb * 1024)))${RESET}"
    tong_uoc=$((tong_uoc + tmp_kb))

    echo -e "\n   ${VANG}$(printf '%.0s─' {1..45})${RESET}"
    echo -e "   ✅ Ước tính tổng    : ${XANH}$(dinh_dang_dung_luong $((tong_uoc * 1024)))${RESET}\n"

    echo -ne "${VANG}Tiếp tục dọn dẹp thật? (co/khong): ${RESET}"
    read -r xac_nhan
    [ "$xac_nhan" != "co" ] && echo -e "${VANG}Đã huỷ.${RESET}\n" && exit 0
    echo ""
}

if [ "${1:-}" = "--uoc-tinh" ] || [ "${1:-}" = "--ước-tính" ]; then
    uoc_tinh
fi


echo -e "${TIM}[1/6]${RESET} 🗑️  Dọn bộ nhớ đệm APT (gói phần mềm cũ)..."
APT_CACHE_TRUOC=$(du -sk /var/cache/apt/archives 2>/dev/null | awk '{print $1}')
# AN TOÀN (bài học 2026-09-07: gỡ libnss3 làm rớt metapackage ubuntu-desktop,
# rồi chính dòng autoremove vô điều kiện này cuốn theo ~200 gói "mồ côi").
# Mô phỏng trước: nếu autoremove định chạm vào gói hệ thống thì BỎ QUA và
# cảnh báo, thay vì làm sập máy thêm.
_BO_QUA_AUTO=0
_MO_PHONG_AUTO=$(LC_ALL=C sudo apt-get -s autoremove -y 2>/dev/null | grep -E '^(Remv|Purg) ' | awk '{print $2}' | cut -d: -f1 || true)
for _bv in ubuntu-desktop ubuntu-desktop-minimal ubuntu-session gdm3 gnome-shell systemd systemd-sysv libc6 libgcc-s1 bash apt dpkg network-manager; do
    if echo "$_MO_PHONG_AUTO" | grep -qx "$_bv"; then
        echo -e "   ${DO}⛔ BỎ QUA autoremove: phát hiện sẽ gỡ gói hệ thống '${_bv}'.${RESET}"
        echo -e "   ${VANG}Máy có dấu hiệu từng gỡ nhầm metapackage — cài lại trước: ${TIM}sudo apt install ubuntu-desktop${RESET}"
        _BO_QUA_AUTO=1
        break
    fi
done
[ "$_BO_QUA_AUTO" = "0" ] && sudo apt-get autoremove -y -q 2>/dev/null
sudo apt-get clean -q 2>/dev/null
APT_CACHE_SAU=$(du -sk /var/cache/apt/archives 2>/dev/null | awk '{print $1}')
APT_TIKET=$((APT_CACHE_TRUOC - APT_CACHE_SAU))
[ "$APT_TIKET" -lt 0 ] && APT_TIKET=0
TONG_GIAI_PHONG=$((TONG_GIAI_PHONG + APT_TIKET))
echo -e "   ${XANH}✔ Đã giải phóng: $(dinh_dang_dung_luong $((APT_TIKET * 1024)))${RESET}"

# ===== 2. XÓA THUMBNAIL CŨ =====
echo -e "${TIM}[2/6]${RESET} 🖼️  Xóa ảnh thumbnail cũ..."
THUMB_TRUOC=$(du -sk ~/.cache/thumbnails 2>/dev/null | awk '{print $1}')
rm -rf ~/.cache/thumbnails/* 2>/dev/null
THUMB_TIKET=${THUMB_TRUOC:-0}
TONG_GIAI_PHONG=$((TONG_GIAI_PHONG + THUMB_TIKET))
echo -e "   ${XANH}✔ Đã giải phóng: $(dinh_dang_dung_luong $((THUMB_TIKET * 1024)))${RESET}"

# ===== 3. XÓA CACHE NGƯỜI DÙNG CŨ =====
echo -e "${TIM}[3/6]${RESET} ⏰  Xóa cache cũ hơn 30 ngày..."
CACHE_TRUOC=$(du -sk ~/.cache 2>/dev/null | awk '{print $1}')
find ~/.cache -type f -atime +30 -delete 2>/dev/null
find ~/.cache -type d -empty -delete 2>/dev/null
CACHE_SAU=$(du -sk ~/.cache 2>/dev/null | awk '{print $1}')
CACHE_TIKET=$((CACHE_TRUOC - CACHE_SAU))
[ "$CACHE_TIKET" -lt 0 ] && CACHE_TIKET=0
TONG_GIAI_PHONG=$((TONG_GIAI_PHONG + CACHE_TIKET))
echo -e "   ${XANH}✔ Đã giải phóng: $(dinh_dang_dung_luong $((CACHE_TIKET * 1024)))${RESET}"

# ===== 4. XÓA JOURNAL LOGS CŨ =====
echo -e "${TIM}[4/6]${RESET} 📋  Dọn nhật ký hệ thống (giữ lại 7 ngày gần nhất)..."
if command -v journalctl &>/dev/null; then
    LOG_TRUOC=$(journalctl --disk-usage 2>/dev/null | grep -oP '[\d.]+[MGK]?(?= [a-z])' | head -1)
    sudo journalctl --vacuum-time=7d -q 2>/dev/null
    LOG_SAU=$(journalctl --disk-usage 2>/dev/null | grep -oP '[\d.]+[MGK]?(?= [a-z])' | head -1)
    echo -e "   ${XANH}✔ Nhật ký: ${LOG_TRUOC:-?} → ${LOG_SAU:-?}${RESET}"
else
    echo -e "   ${VANG}⚠ Bỏ qua (không có journalctl)${RESET}"
fi

# ===== 5. XÓA SNAP REVISIONS CŨ =====
echo -e "${TIM}[5/6]${RESET} 📦  Dọn phiên bản Snap cũ..."
if command -v snap &>/dev/null; then
    DEM_SNAP=0
    snap list --all 2>/dev/null | awk '/disabled/{print $1, $3}' | while read -r ten ban; do
        sudo snap remove "$ten" --revision="$ban" 2>/dev/null && DEM_SNAP=$((DEM_SNAP+1))
    done
    echo -e "   ${XANH}✔ Đã dọn các phiên bản snap cũ${RESET}"
else
    echo -e "   ${VANG}⚠ Bỏ qua (không có snap)${RESET}"
fi

# ===== 6. XÓA TỆP TẠM =====
echo -e "${TIM}[6/6]${RESET} 🗃️  Xóa tệp tạm thời..."
TMP_TRUOC=$(du -sk /tmp 2>/dev/null | awk '{print $1}')
find /tmp -maxdepth 1 -type f -atime +1 -delete 2>/dev/null
find /tmp -maxdepth 1 -type d -empty -not -name tmp -delete 2>/dev/null
TMP_SAU=$(du -sk /tmp 2>/dev/null | awk '{print $1}')
TMP_TIKET=$((TMP_TRUOC - TMP_SAU))
[ "$TMP_TIKET" -lt 0 ] && TMP_TIKET=0
TONG_GIAI_PHONG=$((TONG_GIAI_PHONG + TMP_TIKET))
echo -e "   ${XANH}✔ Đã giải phóng: $(dinh_dang_dung_luong $((TMP_TIKET * 1024)))${RESET}"

# ===== KẾT QUẢ TỔNG =====
SAU_KB=$(lay_dung_luong_da_dung_bytes)
THUC_TE_KB=$((TRUOC_KB - SAU_KB))
[ "$THUC_TE_KB" -lt 0 ] && THUC_TE_KB=0

echo -e "\n${TIM}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${TIM}║               📊 KẾT QUẢ DỌN DẸP                  ║${RESET}"
echo -e "${TIM}╚════════════════════════════════════════════════════╝${RESET}"
echo -e "   💿 Trước khi dọn : ${VANG}$(dinh_dang_dung_luong $((TRUOC_KB * 1024)))${RESET}"
echo -e "   💿 Sau khi dọn   : ${XANH}$(dinh_dang_dung_luong $((SAU_KB * 1024)))${RESET}"
echo -e "   🎉 Tổng giải phóng: ${XANH}$(dinh_dang_dung_luong $((THUC_TE_KB * 1024)))${RESET}"
echo "$(date '+%Y-%m-%d %H:%M')|$(dinh_dang_dung_luong $((THUC_TE_KB * 1024)))|Tự động" >> "$DONRAC_LOG" 2>/dev/null || true
# Giữ tối đa 50 dòng log
tail -50 "$DONRAC_LOG" > "$DONRAC_LOG.tmp" 2>/dev/null && mv "$DONRAC_LOG.tmp" "$DONRAC_LOG" 2>/dev/null || true
echo -e "${VANG}════════════════════════════════════════════════════════${RESET}\n"

# ===== GỠ PHẦN MỀM =====
go_phan_mem() {
    echo -e "\n${TIM}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${TIM}║            🗑️   GỠ PHẦN MỀM ĐÃ CÀI                ║${RESET}"
    echo -e "${TIM}╚════════════════════════════════════════════════════╝${RESET}\n"

    # Hỏi muốn quét loại nào
    echo -e "${HONG}Quét phần mềm từ nguồn nào?${RESET}\n"
    printf "   ${TIM}[1]${RESET}  📦  APT  — phần mềm cài bằng apt install\n"
    printf "   ${TIM}[2]${RESET}  📦  Snap — phần mềm cài bằng snap install\n"
    printf "   ${TIM}[3]${RESET}  📦  Cả hai\n"
    printf "   ${TIM}[0]${RESET}  ←   Bỏ qua\n"
    echo ""
    echo -ne "${VANG}Nhập số lựa chọn: ${RESET}"
    read -r lua_chon_nguon

    case "$lua_chon_nguon" in
        1) _go_apt ;;
        2) _go_snap ;;
        3) _go_apt; _go_snap ;;
        0) echo -e "${VANG}Bỏ qua phần gỡ phần mềm.${RESET}\n"; return ;;
        *) echo -e "${DO}❌ Lựa chọn không hợp lệ.${RESET}\n"; return ;;
    esac
}

# shellcheck disable=SC2227
_phan_loai_goi() {
    local ten="$1"

    # KHÔNG THỂ GỠ: gói cốt lõi hệ thống
    if echo "$ten" | grep -qE \
        '^(ubuntu-minimal|ubuntu-standard|ubuntu-desktop|ubuntu-server|base-files|base-passwd|bash|coreutils|systemd|systemd-sysv|init|sysvinit-utils|libc6|libc-bin|libgcc-s1|dpkg|apt|login|passwd|sudo|adduser|mount|util-linux|e2fsprogs|grub-|linux-image-|linux-headers-|linux-base|linux-firmware|network-manager|udev|dbus|policykit-1|accountsservice|gdm3|lightdm|xorg|xserver-xorg)'; then
        echo "system"
        return
    fi

    # CẨN THẬN: thư viện, runtime, font
    if echo "$ten" | grep -qE \
        '^(lib|python3-|python-|fonts-|gnome-|kde-|xfonts-|gir1\.|gcc-|cpp-|binutils|perl|ruby|nodejs|npm)'; then
        echo "lib"
        return
    fi

    # APP ĐỒ HOẠ: có file .desktop
    if find /usr/share/applications /usr/local/share/applications \
            ~/.local/share/applications 2>/dev/null \
            \( -name "${ten}.desktop" -o -name "${ten}*.desktop" \) | grep -q .; then
        echo "app"
        return
    fi

    echo "cli"
}

_hien_nhom() {
    local nhan="$1"
    local mau="$2"
    local -n mang_ref=$3
    local so_bat_dau=$4

    if [ ${#mang_ref[@]} -eq 0 ]; then return; fi

    echo -e "\n${mau}${nhan} (${#mang_ref[@]} gói):${RESET}"
    printf "   ${TRANG}%-5s %-28s %-10s %s${RESET}\n" "STT" "Tên gói" "Dung lượng" "Ghi chú"
    echo -e "   ${VANG}$(printf '%0.s─' {1..72})${RESET}"

    local i=0
    for entry in "${mang_ref[@]}"; do
        local so=$((so_bat_dau + i))
        local ten; ten=$(echo "$entry"    | cut -d'|' -f1)
        local dung; dung=$(echo "$entry"   | cut -d'|' -f2)
        local mo_ta; mo_ta=$(echo "$entry"  | cut -d'|' -f3)
        local loai; loai=$(echo "$entry"   | cut -d'|' -f4)

        if [ "$loai" = "system" ]; then
            printf "   ${DO}%-5s %-28s %-10s${RESET}" "  🔒" "$ten" "$dung"
            echo -e " ${DO}(KHÔNG GỠ — thuộc hệ thống Ubuntu)${RESET}"
        elif [ "$loai" = "lib" ]; then
            printf "   ${VANG}%-5s${RESET} %-28s %-10s" "$so" "$ten" "$dung"
            echo -e " ${VANG}(cẩn thận — thư viện/runtime)${RESET}"
        else
            printf "   ${TIM}%-5s${RESET} %-28s %-10s %s\n" "$so" "$ten" "$dung" "$mo_ta"
        fi
        i=$((i + 1))
    done
}

_go_apt() {
    echo -e "\n${VANG}📋 Đang quét và phân loại phần mềm APT... (có thể mất vài giây)${RESET}"

    # Phân loại vào 3 mảng: app / cli / lib
    DS_APP=(); DS_CLI=(); DS_LIB=(); DS_SYS=()
    # Mảng tổng để tra cứu theo STT
    DS_TATCA=()

    while IFS= read -r ten; do
        [ -z "$ten" ] && continue
        THONG_TIN=$(dpkg-query -W -f='${Installed-Size}\t${binary:Summary}' "$ten" 2>/dev/null)
        DUNG_LUONG=$(echo "$THONG_TIN" | cut -f1)
        MO_TA=$(echo "$THONG_TIN" | cut -f2 | cut -c1-32)

        if [ -n "$DUNG_LUONG" ] && [ "$DUNG_LUONG" -gt 0 ] 2>/dev/null; then
            [ "$DUNG_LUONG" -ge 1024 ] \
                && HIEN_DUNG="$(echo "scale=1; $DUNG_LUONG/1024" | bc)MB" \
                || HIEN_DUNG="${DUNG_LUONG}KB"
        else
            HIEN_DUNG="—"
        fi

        LOAI=$(_phan_loai_goi "$ten")
        ENTRY="${ten}|${HIEN_DUNG}|${MO_TA}|${LOAI}"
        DS_TATCA+=("$ENTRY")

        case "$LOAI" in
            app)    DS_APP+=("$ENTRY") ;;
            cli)    DS_CLI+=("$ENTRY") ;;
            lib)    DS_LIB+=("$ENTRY") ;;
            system) DS_SYS+=("$ENTRY") ;;
        esac
    done < <(apt-mark showmanual 2>/dev/null | sort)

    # QUAN TRỌNG: DS_TATCA phải theo đúng thứ tự hiển thị (App → CLI → Lib),
    # vì STT trên màn hình đánh liên tục theo nhóm. Nếu để theo ABC (thứ tự
    # phân loại) thì DS_TATCA[so-1] sẽ trỏ SAI gói — từng gây gỡ nhầm gói hệ
    # thống (vd gõ số của app nhưng lại gỡ libnss3). Gói system (khóa 🔒,
    # không có STT) tuyệt đối không được có mặt trong DS_TATCA.
    DS_TATCA=("${DS_APP[@]}" "${DS_CLI[@]}" "${DS_LIB[@]}")

    if [ ${#DS_TATCA[@]} -eq 0 ]; then
        echo -e "${VANG}Không tìm thấy phần mềm nào.${RESET}\n"
        return
    fi

    # Tính offset để STT liên tục xuyên suốt các nhóm (system không có STT)
    OFF_APP=1
    OFF_CLI=$((OFF_APP + ${#DS_APP[@]}))
    OFF_LIB=$((OFF_CLI + ${#DS_CLI[@]}))
    OFF_SYS=0  # system không dùng STT
    TONG_GOI=$((${#DS_APP[@]} + ${#DS_CLI[@]} + ${#DS_LIB[@]}))

    while true; do
        echo -e "\n${TIM}╔════════════════════════════════════════════════════╗${RESET}"
        echo -e "${TIM}║         📦  PHẦN MỀM APT — PHÂN THEO NHÓM         ║${RESET}"
        echo -e "${TIM}╚════════════════════════════════════════════════════╝${RESET}"

        # Nhóm 1: App đồ hoạ
        _hien_nhom "🖥️  APP ĐỒ HOẠ — có giao diện, xuất hiện trong menu ứng dụng" \
            "$XANH" DS_APP $OFF_APP

        # Nhóm 2: Công cụ CLI
        _hien_nhom "⌨️  CÔNG CỤ DÒNG LỆNH — dùng trong terminal" \
            "$VANG" DS_CLI $OFF_CLI

        # Nhóm 3: Thư viện / runtime
        _hien_nhom "📚  THƯ VIỆN & RUNTIME — lib, python3-, fonts-... (cẩn thận)" \
            "$VANG" DS_LIB $OFF_LIB

        # Nhóm 4: Hệ thống — hiện nhưng khóa
        _hien_nhom "🔒  HỆ THỐNG UBUNTU — KHÔNG GỠ" \
            "$DO" DS_SYS $OFF_SYS

        echo -e "\n${HONG}Tổng có thể gỡ: ${TONG_GOI} gói  |  🖥 App: ${#DS_APP[@]}  |  ⌨ CLI: ${#DS_CLI[@]}  |  📚 Thư viện: ${#DS_LIB[@]}  |  🔒 Hệ thống (khóa): ${#DS_SYS[@]}${RESET}"
        echo -e "\n${VANG}Nhập STT để gỡ (nhiều số cách nhau bằng dấu cách, ví dụ: ${TIM}1 3 5${VANG})"
        echo -e "Hoặc lọc theo nhóm: ${TIM}a${VANG}=chỉ App  ${TIM}c${VANG}=chỉ CLI  ${TIM}l${VANG}=chỉ Thư viện  ${TIM}0${VANG}=thoát${RESET}"
        echo -ne "${VANG}➜ ${RESET}"
        read -r nhap

        case "$nhap" in
            0) echo -e "${VANG}Thoát khỏi gỡ APT.${RESET}\n"; return ;;
            "") continue ;;
            a|A)
                # Chỉ hiện nhóm App
                _hien_nhom "🖥️  APP ĐỒ HOẠ" "$XANH" DS_APP $OFF_APP
                echo -e "\n${VANG}Nhập STT gói muốn gỡ (${TIM}0${VANG}=quay lại): ${RESET}\c"
                read -r nhap_app
                [ "$nhap_app" = "0" ] || [ -z "$nhap_app" ] && continue
                nhap="$nhap_app" ;;
            c|C)
                _hien_nhom "⌨️  CÔNG CỤ DÒNG LỆNH" "$VANG" DS_CLI $OFF_CLI
                echo -e "\n${VANG}Nhập STT gói muốn gỡ (${TIM}0${VANG}=quay lại): ${RESET}\c"
                read -r nhap_cli
                [ "$nhap_cli" = "0" ] || [ -z "$nhap_cli" ] && continue
                nhap="$nhap_cli" ;;
            l|L)
                _hien_nhom "⚙️  THƯ VIỆN HỆ THỐNG" "$DO" DS_LIB $OFF_LIB
                echo -e "\n${DO}⚠ Gỡ thư viện hệ thống có thể làm hỏng phần mềm khác!${RESET}"
                echo -e "${VANG}Nhập STT gói muốn gỡ (${TIM}0${VANG}=quay lại): ${RESET}\c"
                read -r nhap_lib
                [ "$nhap_lib" = "0" ] || [ -z "$nhap_lib" ] && continue
                nhap="$nhap_lib" ;;
        esac

        # Xử lý số STT được nhập
        DANH_SACH_GO=()
        for so in $nhap; do
            if echo "$so" | grep -qE '^[0-9]+$' && [ "$so" -ge 1 ] && [ "$so" -le "$TONG_GOI" ]; then
                ENTRY_CHON="${DS_TATCA[$((so-1))]}"
                TEN_GOI=$(echo "$ENTRY_CHON" | cut -d'|' -f1)
                LOAI_GOI=$(echo "$ENTRY_CHON" | cut -d'|' -f4)
                if [ "$LOAI_GOI" = "system" ]; then
                    echo -e "   ${DO}🔒 '$TEN_GOI' là gói hệ thống — KHÔNG THỂ GỠ${RESET}"
                else
                    DANH_SACH_GO+=("$TEN_GOI")
                fi
            else
                echo -e "   ${DO}⚠ Bỏ qua số không hợp lệ: $so${RESET}"
            fi
        done

        [ ${#DANH_SACH_GO[@]} -eq 0 ] && echo -e "${DO}❌ Không có gói hợp lệ.${RESET}\n" && continue

        # Cảnh báo nếu có thư viện hệ thống
        CO_LIB=0
        for g in "${DANH_SACH_GO[@]}"; do
            echo "$g" | grep -qE '^(lib|python3-|python-|fonts-|gnome-)' && CO_LIB=1 && break
        done

        echo -e "\n${DO}⚠️  Sắp gỡ ${#DANH_SACH_GO[@]} gói:${RESET}"
        for g in "${DANH_SACH_GO[@]}"; do
            if echo "$g" | grep -qE '^(lib|python3-|python-|fonts-|gnome-)'; then
                echo -e "   ${DO}→ $g  ⚠ thư viện hệ thống${RESET}"
            else
                echo -e "   ${VANG}→ $g${RESET}"
            fi
        done

        [ $CO_LIB -eq 1 ] && echo -e "\n${DO}⚠ Danh sách có thư viện hệ thống — gỡ sai có thể làm hỏng app khác!${RESET}"

        echo -e "\n${DO}Xác nhận gỡ cài đặt? (co/khong): ${RESET}\c"
        read -r xac_nhan

        if [ "$xac_nhan" = "co" ]; then
            # LÁ CHẮN CASCADE (bài học vụ gỡ libnss3 ngày 2026-09-07 kéo sập
            # ubuntu-desktop/gdm3/gnome-shell): mô phỏng trước bằng apt-get -s
            # (không cần sudo, không thay đổi gì). Nếu gỡ kéo theo gói trong
            # GOI_BAO_VE thì TỪ CHỐI thẳng; nếu kéo theo gói thường khác thì
            # hỏi xác nhận lần 2. Gỡ từng gói riêng (tập con của cả danh sách)
            # không thể kéo theo nhiều hơn gỡ cả danh sách cùng lúc, nên mô
            # phỏng một lần cho cả danh sách là đủ.
            GOI_BAO_VE=(ubuntu-desktop ubuntu-desktop-minimal ubuntu-session gdm3 gnome-shell gnome-control-center systemd systemd-sysv libc6 libgcc-s1 base-files bash apt dpkg sudo login passwd util-linux mount coreutils network-manager netplan.io linux-image-generic linux-base xorg xserver-xorg-core)
            MO_PHONG=$(LC_ALL=C apt-get -s remove --purge "${DANH_SACH_GO[@]}" 2>/dev/null)
            KEO_THEO=()
            while IFS= read -r dong_phong; do
                ten_keo=$(echo "$dong_phong" | awk '{print $2}' | cut -d: -f1)
                [ -z "$ten_keo" ] && continue
                la_da_chon=0
                for g in "${DANH_SACH_GO[@]}"; do
                    [ "$ten_keo" = "$g" ] && la_da_chon=1 && break
                done
                [ "$la_da_chon" = "1" ] && continue
                KEO_THEO+=("$ten_keo")
            done < <(echo "$MO_PHONG" | grep '^Purg ' || true)
            if [ ${#KEO_THEO[@]} -gt 0 ]; then
                VI_PHAM=()
                for k in "${KEO_THEO[@]}"; do
                    for b in "${GOI_BAO_VE[@]}"; do
                        [ "$k" = "$b" ] && VI_PHAM+=("$k") && break
                    done
                done
                if [ ${#VI_PHAM[@]} -gt 0 ]; then
                    echo -e "\n   ${DO}⛔ TỪ CHỐI GỠ để bảo vệ máy: '${DANH_SACH_GO[*]}' kéo theo gói hệ thống: ${VI_PHAM[*]}${RESET}"
                    echo -e "   ${VANG}Gỡ tiếp sẽ làm hỏng Ubuntu (đã từng sập desktop vì gỡ libnss3). Đã hủy, máy không thay đổi gì.${RESET}\n"
                    continue
                fi
                echo -e "\n${VANG}⚠ Gỡ '${DANH_SACH_GO[*]}' sẽ kéo theo ${#KEO_THEO[@]} gói khác: ${KEO_THEO[*]}${RESET}"
                echo -ne "${VANG}Vẫn gỡ tất cả? (co/khong): ${RESET}"
                read -r xac_nhan_keo_theo
                if [ "$xac_nhan_keo_theo" != "co" ]; then
                    echo -e "${VANG}Đã huỷ.${RESET}\n"
                    continue
                fi
            fi
            for GOI in "${DANH_SACH_GO[@]}"; do
                echo -ne "   ⏳ Đang gỡ ${TIM}${GOI}${RESET}..."
                sudo apt-get remove --purge -y "$GOI" -q 2>/dev/null
                echo -e "\r   ${XANH}✔ Đã gỡ: ${GOI}${RESET}          "
            done
            sudo apt-get autoremove -y -q 2>/dev/null
            echo -e "\n   ${XANH}✔ Hoàn tất! Đã dọn các gói phụ thuộc không còn dùng.${RESET}\n"

            # Làm mới danh sách (giữ đúng thứ tự hiển thị như lúc quét đầu)
            DS_APP=(); DS_CLI=(); DS_LIB=(); DS_SYS=(); DS_TATCA=()
            while IFS= read -r ten; do
                [ -z "$ten" ] && continue
                THONG_TIN=$(dpkg-query -W -f='${Installed-Size}\t${binary:Summary}' "$ten" 2>/dev/null)
                DUNG_LUONG=$(echo "$THONG_TIN" | cut -f1)
                MO_TA=$(echo "$THONG_TIN" | cut -f2 | cut -c1-32)
                [ -n "$DUNG_LUONG" ] && [ "$DUNG_LUONG" -ge 1024 ] 2>/dev/null \
                    && HIEN_DUNG="$(echo "scale=1; $DUNG_LUONG/1024" | bc)MB" \
                    || HIEN_DUNG="${DUNG_LUONG:-—}KB"
                LOAI=$(_phan_loai_goi "$ten")
                ENTRY="${ten}|${HIEN_DUNG}|${MO_TA}|${LOAI}"
                case "$LOAI" in
                    app) DS_APP+=("$ENTRY") ;;
                    cli) DS_CLI+=("$ENTRY") ;;
                    lib) DS_LIB+=("$ENTRY") ;;
                    system) DS_SYS+=("$ENTRY") ;;
                esac
            done < <(apt-mark showmanual 2>/dev/null | sort)
            DS_TATCA=("${DS_APP[@]}" "${DS_CLI[@]}" "${DS_LIB[@]}")
            OFF_CLI=$((1 + ${#DS_APP[@]}))
            OFF_LIB=$((OFF_CLI + ${#DS_CLI[@]}))
            TONG_GOI=${#DS_TATCA[@]}
        else
            echo -e "${VANG}Đã huỷ.${RESET}\n"
        fi
    done
}

_go_snap() {
    if ! command -v snap &>/dev/null; then
        echo -e "${VANG}⚠ Không có snap trên hệ thống.${RESET}\n"
        return
    fi

    echo -e "\n${VANG}📋 Đang quét danh sách phần mềm Snap đã cài...${RESET}"
    mapfile -t DS_SNAP < <(snap list 2>/dev/null | tail -n +2 | grep -v "^snapd " | awk '{print $1"|"$2"|"$4}')

    if [ ${#DS_SNAP[@]} -eq 0 ]; then
        echo -e "${VANG}Không có gói Snap nào.${RESET}\n"
        return
    fi

    while true; do
        echo -e "\n${HONG}📦 PHẦN MỀM SNAP ĐÃ CÀI (${#DS_SNAP[@]} gói):${RESET}\n"
        printf "   ${TRANG}%-5s %-25s %-12s %s${RESET}\n" "STT" "Tên gói" "Phiên bản" "Nhà phát triển"
        echo -e "   ${VANG}$(printf '%0.s─' {1..60})${RESET}"

        dem=1
        for entry in "${DS_SNAP[@]}"; do
            TEN=$(echo "$entry" | cut -d'|' -f1)
            PHIEN_BAN=$(echo "$entry" | cut -d'|' -f2)
            NHA_PT=$(echo "$entry" | cut -d'|' -f3)
            printf "   ${TIM}%-5s${RESET} %-25s %-12s %s\n" "$dem" "$TEN" "$PHIEN_BAN" "$NHA_PT"
            dem=$((dem + 1))
        done

        echo ""
        echo -e "${VANG}Nhập STT gói muốn gỡ (nhiều số cách nhau bằng dấu cách, ví dụ: 1 3), ${TIM}0${VANG}=thoát:${RESET}"
        echo -ne "${VANG}➜ ${RESET}"
        read -r nhap

        [ "$nhap" = "0" ] && echo -e "${VANG}Thoát khỏi gỡ Snap.${RESET}\n" && return
        [ -z "$nhap" ] && continue

        DANH_SACH_GO=()
        for so in $nhap; do
            if echo "$so" | grep -qE '^[0-9]+$' && [ "$so" -ge 1 ] && [ "$so" -le "${#DS_SNAP[@]}" ]; then
                TEN=$(echo "${DS_SNAP[$((so-1))]}" | cut -d'|' -f1)
                DANH_SACH_GO+=("$TEN")
            else
                echo -e "   ${DO}⚠ Bỏ qua số không hợp lệ: $so${RESET}"
            fi
        done

        if [ ${#DANH_SACH_GO[@]} -eq 0 ]; then
            echo -e "${DO}❌ Không có gói hợp lệ nào.${RESET}\n"
            continue
        fi

        echo -e "\n${DO}⚠️  Sắp gỡ ${#DANH_SACH_GO[@]} gói Snap sau:${RESET}"
        for g in "${DANH_SACH_GO[@]}"; do
            echo -e "   ${VANG}→ $g${RESET}"
        done
        echo -e "\n${DO}Xác nhận gỡ cài đặt? (co/khong): ${RESET}\c"
        read -r xac_nhan

        if [ "$xac_nhan" = "co" ]; then
            for GOI in "${DANH_SACH_GO[@]}"; do
                echo -ne "   ⏳ Đang gỡ ${TIM}${GOI}${RESET}..."
                sudo snap remove "$GOI" 2>/dev/null
                echo -e "\r   ${XANH}✔ Đã gỡ: ${GOI}${RESET}          "
            done
            # Cập nhật lại danh sách
            mapfile -t DS_SNAP < <(snap list 2>/dev/null | tail -n +2 | grep -v "^snapd " | awk '{print $1"|"$2"|"$4}')
        else
            echo -e "${VANG}Đã huỷ.${RESET}\n"
        fi
    done
}

# Hỏi có muốn gỡ phần mềm không
echo -ne "\n${VANG}Bạn có muốn gỡ phần mềm không cần thiết không? (co/khong): ${RESET}"
read -r hoi_go
if [ "$hoi_go" = "co" ]; then
    go_phan_mem
fi
