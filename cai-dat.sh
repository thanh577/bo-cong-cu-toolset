#!/usr/bin/env bash
set -euo pipefail
# ============================================================
#  CÀI ĐẶT BỘ CÔNG CỤ TOOLSET — trình cài đặt gộp
#  Phiên bản: 1.0
#
#  Gồm 4 nhóm độc lập, cài chọn lọc qua menu hoặc cờ (flag):
#    1) thu-vien  → gói apt + pip cần thiết      (Cài đặt các thư viện — nên làm trước)
#    2) hoc-linux → lệnh `hoc`, `hoc-linux`      (Mỗi ngày một lệnh Linux)
#    3) hoc-trung → lệnh `tu`                     (Học từ mới tiếng Trung)
#    4) may-tinh  → lệnh `donrac`, `pin`          (Công cụ cho máy tính của bạn)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

XANH='\e[1;32m'; DO='\e[1;31m'; VANG='\e[1;33m'; TIM='\e[1;36m'; HONG='\e[1;35m'; RESET='\e[0m'

THU_MUC_LINUX="/opt/lenh-linux"
THU_MUC_LINUX_SCRIPT="$THU_MUC_LINUX/scripts"
THU_MUC_TRUNG="/opt/hoc-trung"
THU_MUC_TRUNG_SCRIPT="$THU_MUC_TRUNG/scripts"
THU_MUC_TRUNG_DATA="$THU_MUC_TRUNG/data"

_DA_SAO_LUU_BASHRC=0

in_tieu_de() {
    echo -e "\n${TIM}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${TIM}║        🚀  BỘ CÔNG CỤ TOOLSET — CÀI ĐẶT           ║${RESET}"
    echo -e "${TIM}╚════════════════════════════════════════════════════╝${RESET}\n"
}

kiem_tra_sudo() {
    if ! sudo -v 2>/dev/null; then
        echo -e "${DO}❌ Cần quyền sudo để cài đặt.${RESET}"
        exit 1
    fi
}

# Sao lưu ~/.bashrc — chỉ 1 lần mỗi lần chạy script, dù gọi nhiều module
sao_luu_bashrc() {
    [ "$_DA_SAO_LUU_BASHRC" = "1" ] && return 0
    if [ -f "$HOME/.bashrc" ]; then
        cp "$HOME/.bashrc" "$HOME/.bashrc.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "   ${XANH}✔ Đã sao lưu ~/.bashrc${RESET}"
    fi
    _DA_SAO_LUU_BASHRC=1
}

# Thêm 1 khối vào .bashrc với marker riêng — idempotent, không trùng lặp
# $1 = tên marker (vd: hoc-linux) | $2 = nội dung khối (không gồm marker)
them_bashrc_block() {
    local marker="$1" noi_dung="$2"
    if grep -q ">>> ${marker} bashrc block >>>" "$HOME/.bashrc" 2>/dev/null; then
        echo -e "   ${XANH}✔ Đã có khối '${marker}' trong ~/.bashrc — bỏ qua${RESET}"
        return 0
    fi
    sao_luu_bashrc
    {
        echo ""
        echo "# >>> ${marker} bashrc block >>>"
        echo "$noi_dung"
        echo "# <<< ${marker} bashrc block <<<"
    } >> "$HOME/.bashrc"
    echo -e "   ${XANH}✔ Đã thêm khối '${marker}' vào ~/.bashrc${RESET}"
}

# Xóa 1 khối theo marker khỏi .bashrc
xoa_bashrc_block() {
    local marker="$1"
    [ -f "$HOME/.bashrc" ] || return 0
    if grep -q ">>> ${marker} bashrc block >>>" "$HOME/.bashrc" 2>/dev/null; then
        sao_luu_bashrc
        sed -i "/>>> ${marker} bashrc block >>>/,/<<< ${marker} bashrc block <<</d" "$HOME/.bashrc"
        echo -e "   ${XANH}✔ Đã xóa khối '${marker}' khỏi ~/.bashrc${RESET}"
    fi
}

# Xóa 1 khối "if [ -f ~/<file> ]; then ... fi" kiểu CŨ (không có marker >>> <<<)
# liên quan đến 1 file DB cụ thể — dùng để dọn tàn dư từ bản cài rất cũ.
#
# QUAN TRỌNG: neo vào dòng code ASCII thuần (`if [ -f ~/xxx_db.txt ]; then`),
# KHÔNG neo vào dòng comment tiếng Việt như bản đầu — từng bị lỗi thực tế vì so
# khớp comment tiếng Việt không đáng tin cậy giữa các lần cài khác nhau (lệch
# khoảng trắng/định dạng), khiến sed không khớp và để sót nguyên khối cũ. Đồng
# thời hàm này CHỦ ĐỘNG BỎ QUA nội dung đã nằm trong khối có marker của chính
# bộ cài đặt này (>>> ... bashrc block >>> ... <<< ... <<<), để không xóa nhầm
# khối mới hợp lệ (khối mới cũng chứa cùng dòng "if [ -f ~/xxx_db.txt ]; then"
# ở bên trong).
# $1 = tên file DB tính từ $HOME (vd: .lenh_linux_db.txt)
xoa_khoi_cu_khong_marker() {
    local ten_file="$1"
    [ -f "$HOME/.bashrc" ] || return 0
    grep -qF "if [ -f ~/${ten_file} ]; then" "$HOME/.bashrc" 2>/dev/null || return 0

    sao_luu_bashrc
    local tmp; tmp=$(mktemp)
    awk -v trigger="if [ -f ~/${ten_file} ]; then" '
        BEGIN { in_marker=0; skipping=0; da_xoa=0 }
        /^# >>> .* bashrc block >>>$/ { in_marker=1; print; next }
        /^# <<< .* bashrc block <<<$/ { in_marker=0; print; next }
        {
            if (skipping) {
                if ($0 == "fi") { skipping=0 }
                next
            }
            if (!in_marker && index($0, trigger) == 1) { skipping=1; da_xoa=1; next }
            print
        }
        END { if (da_xoa) print "DA_XOA" > "/dev/stderr" }
    ' "$HOME/.bashrc" > "$tmp" 2>/tmp/.xoa_khoi_cu_flag
    mv "$tmp" "$HOME/.bashrc"

    if [ -s /tmp/.xoa_khoi_cu_flag ]; then
        # Dọn luôn dòng comment mồ côi (không bắt buộc phải khớp, chỉ để gọn)
        sed -i '/^# Hiển thị ngẫu nhiên 1 từ tiếng Trung$/d;/^# Hiển thị ngẫu nhiên 1 lệnh Linux$/d' "$HOME/.bashrc" 2>/dev/null || true
        sed -i '/^$/N;/^\n$/D' "$HOME/.bashrc" 2>/dev/null || true
        echo -e "   ${XANH}✔ Đã dọn khối hiển thị kiểu cũ (không marker) liên quan đến ${ten_file}${RESET}"
    fi
    rm -f /tmp/.xoa_khoi_cu_flag
}

# Di chuyển bản cài rất cũ (trước bản tách hoc-trung riêng) nếu phát hiện
don_ban_that_cu() {
    if [ -d "/opt/hoc-linux" ]; then
        echo -e "\n${VANG}⚠ Phát hiện bản cài rất cũ tại /opt/hoc-linux (gộp chung Linux + tiếng Trung).${RESET}"
        echo -ne "${VANG}Gỡ bản cũ trước khi cài mới? (co/khong): ${RESET}"
        read -r xac_nhan
        if [ "$xac_nhan" = "co" ]; then
            sudo rm -f /usr/local/bin/hoc /usr/local/bin/donrac /usr/local/bin/pin /usr/local/bin/hoc-linux
            sudo rm -rf /opt/hoc-linux
            xoa_khoi_cu_khong_marker ".tiengtrung_db.txt"
            xoa_khoi_cu_khong_marker ".lenh_linux_db.txt"
            echo -e "   ${XANH}✔ Đã gỡ bản cũ${RESET}"
        fi
    fi
}

# ============================================================
#  0) CÁC THƯ VIỆN CẦN THIẾT (RẤT QUAN TRỌNG)
#  Gói hệ thống (apt) + thư viện Python từ requirements.txt.
#  KHÔNG dùng venv — cài thẳng vào hệ thống (máy mới, dùng riêng cho bộ công cụ này).
# ============================================================
GOI_HE_THONG_CAN=(python3 python3-pip curl bc bluez upower espeak-ng mpv)

cai_thu_vien() {
    echo -e "\n${HONG}▶ Cài đặt: Các thư viện cần thiết (rất quan trọng)${RESET}"
    kiem_tra_sudo

    echo -e "${VANG}📦 Kiểm tra gói hệ thống...${RESET}"
    local goi_thieu=()
    for g in "${GOI_HE_THONG_CAN[@]}"; do
        if dpkg -s "$g" &>/dev/null; then
            echo -e "   ${XANH}✔ $g${RESET} — đã có"
        else
            echo -e "   ${VANG}✗ $g${RESET} — sẽ cài"
            goi_thieu+=("$g")
        fi
    done

    if [ ${#goi_thieu[@]} -gt 0 ]; then
        echo -e "\n${VANG}⏳ Đang cài: ${goi_thieu[*]}${RESET}"
        sudo apt-get update -qq
        sudo apt-get install -y -qq "${goi_thieu[@]}"
        echo -e "   ${XANH}✔ Đã cài xong gói hệ thống${RESET}"
    else
        echo -e "   ${XANH}✔ Đã đủ gói hệ thống, không cần cài thêm${RESET}"
    fi

    echo -e "\n${VANG}🐍 Cài thư viện Python từ requirements.txt (không dùng venv)...${RESET}"
    if [ ! -f "$SCRIPT_DIR/requirements.txt" ]; then
        echo -e "   ${DO}⚠ Không tìm thấy requirements.txt cạnh cai-dat.sh — bỏ qua.${RESET}"
    elif ! command -v pip3 &>/dev/null && ! command -v pip &>/dev/null; then
        echo -e "   ${DO}⚠ Không tìm thấy pip. Chạy lại mục này sau khi python3-pip đã cài xong.${RESET}"
    else
        local pip_cmd; pip_cmd=$(command -v pip3 || command -v pip)
        # --break-system-packages cần cho Ubuntu 23.04+/24.04 (PEP 668); nếu pip
        # cũ không hiểu cờ này thì thử lại không có cờ.
        if "$pip_cmd" install -r "$SCRIPT_DIR/requirements.txt" --break-system-packages -q 2>/dev/null \
           || "$pip_cmd" install -r "$SCRIPT_DIR/requirements.txt" -q 2>/dev/null; then
            echo -e "   ${XANH}✔ Đã cài xong: edge-tts, gTTS (dùng cho 'tu nghe')${RESET}"
        else
            echo -e "   ${DO}⚠ Cài pip thất bại. Thử thủ công:${RESET}"
            echo -e "   ${TIM}pip install -r requirements.txt --break-system-packages${RESET}"
        fi
    fi

    echo -e "\n${XANH}✔ Hoàn tất cài thư viện. Nên chạy mục này TRƯỚC khi cài các nhóm khác.${RESET}"
}

# ============================================================
#  1) MỖI NGÀY MỘT LỆNH LINUX  (hoc, hoc-linux)
# ============================================================
cai_hoc_linux() {
    echo -e "\n${HONG}▶ Cài đặt: Mỗi ngày một lệnh Linux (hoc, hoc-linux)${RESET}"
    kiem_tra_sudo

    for tep in "hoc-lenh.sh" "hoc-linux.sh" "lib.sh" "lenh_linux_db.txt"; do
        if [ ! -f "$SCRIPT_DIR/hoc-linux/$tep" ]; then
            echo -e "   ${DO}✗ Thiếu tệp nguồn: hoc-linux/$tep${RESET}"
            return 1
        fi
    done

    sudo mkdir -p "$THU_MUC_LINUX_SCRIPT"
    sudo cp "$SCRIPT_DIR/hoc-linux/hoc-lenh.sh"      "$THU_MUC_LINUX_SCRIPT/hoc"
    sudo cp "$SCRIPT_DIR/hoc-linux/hoc-linux.sh"     "$THU_MUC_LINUX_SCRIPT/hoc-linux"
    sudo cp "$SCRIPT_DIR/hoc-linux/lib.sh"           "$THU_MUC_LINUX_SCRIPT/lib.sh"
    sudo cp "$SCRIPT_DIR/hoc-linux/lenh_linux_db.txt" "$THU_MUC_LINUX_SCRIPT/lenh_linux_db.txt"
    sudo chown -R root:root "$THU_MUC_LINUX"
    sudo chmod -R 755 "$THU_MUC_LINUX_SCRIPT"

    sudo ln -sf "$THU_MUC_LINUX_SCRIPT/hoc"       /usr/local/bin/hoc
    sudo ln -sf "$THU_MUC_LINUX_SCRIPT/hoc-linux" /usr/local/bin/hoc-linux

    cp "$SCRIPT_DIR/hoc-linux/lenh_linux_db.txt" "$HOME/.lenh_linux_db.txt"
    echo -e "   ${XANH}✔ Đã copy ~/.lenh_linux_db.txt${RESET}"

    # Tự dọn khối hiển thị kiểu cũ (không marker) nếu còn sót từ bản cài trước —
    # phòng vệ thêm cho trường hợp don_ban_that_cu không chạy (vd: /opt/hoc-linux
    # đã bị xóa ở lần chạy trước đó nhưng khối bashrc cũ chưa được dọn).
    xoa_khoi_cu_khong_marker ".lenh_linux_db.txt"

    # Khối hiển thị "lệnh hôm nay" — KHÔNG dùng xargs cho VI_DU (option có thể
    # bắt đầu bằng dấu "-", vd "-n", "-e"; xargs sẽ nuốt mất các flag này vì nó
    # ngầm gọi `echo -n .../-e ...` khi không truyền lệnh)
    them_bashrc_block "hoc-linux" '
if [ -f ~/.lenh_linux_db.txt ]; then
    DONG=$(shuf -n 1 ~/.lenh_linux_db.txt)
    LENH=$(echo "$DONG"      | cut -d'"'"'|'"'"' -f1 | xargs)
    CONG_DUNG=$(echo "$DONG" | cut -d'"'"'|'"'"' -f2 | xargs)
    VI_DU=$(echo "$DONG"     | cut -d'"'"'|'"'"' -f3)
    VI_DU="${VI_DU#"${VI_DU%%[! ]*}"}"; VI_DU="${VI_DU%"${VI_DU##*[! ]}"}"
    echo -e "\e[1;35m💡 LỆNH HÔM NAY:\e[0m \e[1;33m${LENH}\e[0m — \e[0;37m${CONG_DUNG}\e[0m"
    echo -e "   \e[0;37mVí dụ:\e[0m \e[1;36m${VI_DU}\e[0m"
fi'

    echo -e "   ${XANH}✔ Xong. Dùng: ${TIM}hoc ls${RESET}${XANH}, ${TIM}hoc-linux quiz${RESET}"
}

# ============================================================
#  2) HỌC TỪ MỚI TIẾNG TRUNG  (tu)
# ============================================================
cai_hoc_trung() {
    echo -e "\n${HONG}▶ Cài đặt: Học từ mới tiếng Trung (tu)${RESET}"
    kiem_tra_sudo

    for tep in "tu.sh" "lib.sh" "tiengtrung_db.txt"; do
        if [ ! -f "$SCRIPT_DIR/hoc-trung/$tep" ]; then
            echo -e "   ${DO}✗ Thiếu tệp nguồn: hoc-trung/$tep${RESET}"
            return 1
        fi
    done

    sudo mkdir -p "$THU_MUC_TRUNG_SCRIPT" "$THU_MUC_TRUNG_DATA"
    sudo cp "$SCRIPT_DIR/hoc-trung/tu.sh"  "$THU_MUC_TRUNG_SCRIPT/tu"
    sudo cp "$SCRIPT_DIR/hoc-trung/lib.sh" "$THU_MUC_TRUNG_SCRIPT/lib.sh"
    sudo cp "$SCRIPT_DIR/hoc-trung/tiengtrung_db.txt" "$THU_MUC_TRUNG_DATA/tiengtrung_db.txt"
    sudo chown -R root:root "$THU_MUC_TRUNG"
    sudo chmod -R 755 "$THU_MUC_TRUNG_SCRIPT"

    sudo ln -sf "$THU_MUC_TRUNG_SCRIPT/tu" /usr/local/bin/tu

    if [ ! -f "$HOME/.tiengtrung_db.txt" ]; then
        cp "$SCRIPT_DIR/hoc-trung/tiengtrung_db.txt" "$HOME/.tiengtrung_db.txt"
        echo -e "   ${XANH}✔ Đã copy ~/.tiengtrung_db.txt${RESET}"
    fi

    # Tự dọn khối hiển thị kiểu cũ (không marker) nếu còn sót từ bản cài trước
    xoa_khoi_cu_khong_marker ".tiengtrung_db.txt"

    them_bashrc_block "hoc-trung" '
if [ -f ~/.tiengtrung_db.txt ]; then
    DONG=$(shuf -n 1 ~/.tiengtrung_db.txt)
    HAN=$(echo "$DONG"    | cut -d'"'"'|'"'"' -f1 | xargs)
    PINYIN=$(echo "$DONG" | cut -d'"'"'|'"'"' -f2 | xargs)
    NGHIA=$(echo "$DONG"  | cut -d'"'"'|'"'"' -f3 | xargs)
    VD=$(echo "$DONG"     | cut -d'"'"'|'"'"' -f4 | xargs)
    echo -e "\e[1;31m🀄 TIẾNG TRUNG HÔM NAY:\e[0m \e[1;33m${HAN}\e[0m  \e[0;37m${PINYIN}\e[0m  \e[1;32m${NGHIA}\e[0m"
    echo -e "   \e[0;37mVí dụ:\e[0m \e[0;36m${VD}\e[0m"
    # disown: chạy tu nghe ở nền nhưng không để bash in thông báo job-control
    # kiểu "[1]+ Done ..." ra terminal khi job nền hoàn tất (rất gây khó chịu,
    # xuất hiện ngay trước dấu nhắc lệnh tiếp theo).
    { command -v tu &>/dev/null && tu nghe "${HAN}" 2>/dev/null; } &
    disown 2>/dev/null || true
fi'

    echo -e "   ${XANH}✔ Xong. Dùng: ${TIM}tu 你好${RESET}"
}

# ============================================================
#  3) CÔNG CỤ CHO MÁY TÍNH CỦA BẠN  (donrac, pin)
# ============================================================
cai_may_tinh() {
    echo -e "\n${HONG}▶ Cài đặt: Công cụ cho máy tính của bạn (donrac, pin)${RESET}"
    kiem_tra_sudo

    for tep in "don-rac.sh" "giam-sat-pin.sh" "lib.sh"; do
        if [ ! -f "$SCRIPT_DIR/may-tinh/$tep" ]; then
            echo -e "   ${DO}✗ Thiếu tệp nguồn: may-tinh/$tep${RESET}"
            return 1
        fi
    done

    sudo mkdir -p "$THU_MUC_LINUX_SCRIPT"
    sudo cp "$SCRIPT_DIR/may-tinh/don-rac.sh"      "$THU_MUC_LINUX_SCRIPT/donrac"
    sudo cp "$SCRIPT_DIR/may-tinh/giam-sat-pin.sh" "$THU_MUC_LINUX_SCRIPT/pin"
    # lib.sh dùng chung thư mục với nhóm hoc-linux nếu đã có; nếu chưa, copy mới
    sudo cp "$SCRIPT_DIR/may-tinh/lib.sh" "$THU_MUC_LINUX_SCRIPT/lib.sh"
    sudo chown -R root:root "$THU_MUC_LINUX"
    sudo chmod -R 755 "$THU_MUC_LINUX_SCRIPT"

    sudo ln -sf "$THU_MUC_LINUX_SCRIPT/donrac" /usr/local/bin/donrac
    sudo ln -sf "$THU_MUC_LINUX_SCRIPT/pin"    /usr/local/bin/pin

    echo -e "   ${XANH}✔ Xong. Dùng: ${TIM}donrac${RESET}${XANH}, ${TIM}pin${RESET}"
}

# ============================================================
#  MENU
# ============================================================
hien_menu() {
    in_tieu_de
    don_ban_that_cu
    echo -e "${VANG}Chọn (các) mục muốn cài đặt:${RESET}\n"
    echo -e "   ${TIM}1${RESET})  ${DO}Cài đặt các thư viện cần thiết (rất quan trọng)${RESET}"
    echo -e "   ${TIM}2${RESET})  Mỗi ngày một lệnh Linux     (hoc, hoc-linux)"
    echo -e "   ${TIM}3${RESET})  Học từ mới tiếng Trung       (tu)"
    echo -e "   ${TIM}4${RESET})  Công cụ cho máy tính của bạn (donrac, pin)"
    echo -e "   ${TIM}5${RESET})  Cài tất cả"
    echo -e "   ${TIM}0${RESET})  Thoát"
    echo -e "\n${VANG}Có thể chọn nhiều mục, cách nhau bằng dấu cách (vd: ${TIM}1 2 4${VANG})${RESET}"
    echo -e "${VANG}Máy mới nên chọn mục ${TIM}1${VANG} trước tiên.${RESET}"
    echo -ne "${VANG}➜ Nhập STT: ${RESET}"
    read -r chon

    if [ -z "$chon" ]; then
        echo -e "${VANG}Không chọn gì. Đã thoát.${RESET}\n"
        exit 0
    fi

    local da_cai=0
    for so in $chon; do
        case "$so" in
            0) echo -e "${VANG}Đã huỷ.${RESET}\n"; exit 0 ;;
            1) cai_thu_vien;  da_cai=1 ;;
            2) cai_hoc_linux; da_cai=1 ;;
            3) cai_hoc_trung; da_cai=1 ;;
            4) cai_may_tinh;  da_cai=1 ;;
            5) cai_thu_vien; cai_hoc_linux; cai_hoc_trung; cai_may_tinh; da_cai=1; break ;;
            *) echo -e "${DO}⚠ Bỏ qua lựa chọn không hợp lệ: '${so}'${RESET}" ;;
        esac
    done

    if [ "$da_cai" = "1" ]; then
        echo -e "\n${TIM}╔════════════════════════════════════════════════════╗${RESET}"
        echo -e "${TIM}║              ✅  CÀI ĐẶT HOÀN TẤT                 ║${RESET}"
        echo -e "${TIM}╚════════════════════════════════════════════════════╝${RESET}"
        echo -e "\n${VANG}Mở terminal mới hoặc chạy: ${TIM}source ~/.bashrc${RESET}\n"
    fi
}

# ============================================================
#  GỠ CÀI ĐẶT
# ============================================================
go_cai_dat() {
    in_tieu_de
    echo -e "${VANG}Chọn (các) mục muốn gỡ:${RESET}\n"
    echo -e "   ${TIM}1${RESET})  Mỗi ngày một lệnh Linux (hoc, hoc-linux)"
    echo -e "   ${TIM}2${RESET})  Học từ mới tiếng Trung   (tu)"
    echo -e "   ${TIM}3${RESET})  Công cụ máy tính         (donrac, pin)"
    echo -e "   ${TIM}4${RESET})  Gỡ tất cả"
    echo -e "   ${TIM}0${RESET})  Thoát"
    echo -ne "\n${VANG}➜ Nhập STT: ${RESET}"
    read -r chon
    [ -z "$chon" ] && exit 0

    kiem_tra_sudo
    for so in $chon; do
        case "$so" in
            0) exit 0 ;;
            1)
                sudo rm -f /usr/local/bin/hoc /usr/local/bin/hoc-linux
                sudo rm -f "$THU_MUC_LINUX_SCRIPT/hoc" "$THU_MUC_LINUX_SCRIPT/hoc-linux" "$THU_MUC_LINUX_SCRIPT/lenh_linux_db.txt"
                xoa_bashrc_block "hoc-linux"
                echo -e "   ${XANH}✔ Đã gỡ: hoc, hoc-linux${RESET}" ;;
            2)
                sudo rm -f /usr/local/bin/tu
                sudo rm -rf "$THU_MUC_TRUNG"
                xoa_bashrc_block "hoc-trung"
                echo -e "   ${XANH}✔ Đã gỡ: tu${RESET}" ;;
            3)
                sudo rm -f /usr/local/bin/donrac /usr/local/bin/pin
                sudo rm -f "$THU_MUC_LINUX_SCRIPT/donrac" "$THU_MUC_LINUX_SCRIPT/pin"
                echo -e "   ${XANH}✔ Đã gỡ: donrac, pin${RESET}" ;;
            4)
                sudo rm -f /usr/local/bin/hoc /usr/local/bin/hoc-linux /usr/local/bin/donrac /usr/local/bin/pin /usr/local/bin/tu
                sudo rm -rf "$THU_MUC_LINUX" "$THU_MUC_TRUNG"
                xoa_bashrc_block "hoc-linux"
                xoa_bashrc_block "hoc-trung"
                echo -e "   ${XANH}✔ Đã gỡ toàn bộ${RESET}"; break ;;
            *) echo -e "${DO}⚠ Bỏ qua: '${so}'${RESET}" ;;
        esac
    done
    echo ""
}

# ============================================================
#  KIỂM TRA TRẠNG THÁI
# ============================================================
kiem_tra_trang_thai() {
    in_tieu_de
    echo -e "${VANG}📊 Trạng thái lệnh đã cài:${RESET}\n"
    for lenh in hoc hoc-linux tu donrac pin; do
        if command -v "$lenh" &>/dev/null; then
            echo -e "   ${XANH}✔ $lenh${RESET} → $(command -v "$lenh")"
        else
            echo -e "   ${DO}✗ $lenh${RESET} → Chưa cài"
        fi
    done

    echo -e "\n${VANG}📦 Trạng thái thư viện hệ thống:${RESET}\n"
    for g in "${GOI_HE_THONG_CAN[@]}"; do
        if dpkg -s "$g" &>/dev/null; then
            echo -e "   ${XANH}✔ $g${RESET}"
        else
            echo -e "   ${DO}✗ $g${RESET} → chưa cài, chạy: ${TIM}bash cai-dat.sh --thu-vien${RESET}"
        fi
    done
    echo ""
}

# ============================================================
#  ĐIỀU PHỐI
# ============================================================
case "${1:-}" in
    "")
        hien_menu ;;
    "--tat-ca"|"--all")
        in_tieu_de; don_ban_that_cu
        cai_thu_vien; cai_hoc_linux; cai_hoc_trung; cai_may_tinh
        echo -e "\n${XANH}✅ Đã cài tất cả. Mở terminal mới để áp dụng.${RESET}\n" ;;
    "--thu-vien"|"--deps")
        in_tieu_de; cai_thu_vien ;;
    "--hoc-linux")
        in_tieu_de; cai_hoc_linux ;;
    "--hoc-trung")
        in_tieu_de; cai_hoc_trung ;;
    "--may-tinh")
        in_tieu_de; cai_may_tinh ;;
    "--go-cai-dat"|"go")
        go_cai_dat ;;
    "--kiem-tra"|"kt")
        kiem_tra_trang_thai ;;
    "--giup-do"|"-h"|"--help")
        in_tieu_de
        echo -e "${XANH}Cách dùng:${RESET}"
        echo -e "   ${TIM}bash cai-dat.sh${RESET}              → Mở menu chọn cài đặt"
        echo -e "   ${TIM}bash cai-dat.sh --tat-ca${RESET}      → Cài tất cả (kể cả thư viện), không hỏi"
        echo -e "   ${TIM}bash cai-dat.sh --thu-vien${RESET}    → Chỉ cài thư viện cần thiết (apt + pip)"
        echo -e "   ${TIM}bash cai-dat.sh --hoc-linux${RESET}   → Chỉ cài hoc, hoc-linux"
        echo -e "   ${TIM}bash cai-dat.sh --hoc-trung${RESET}   → Chỉ cài tu"
        echo -e "   ${TIM}bash cai-dat.sh --may-tinh${RESET}    → Chỉ cài donrac, pin"
        echo -e "   ${TIM}bash cai-dat.sh --go-cai-dat${RESET}  → Gỡ cài đặt (có menu chọn)"
        echo -e "   ${TIM}bash cai-dat.sh --kiem-tra${RESET}    → Kiểm tra trạng thái\n" ;;
    *)
        echo -e "${DO}Tùy chọn không hợp lệ: $1${RESET}"
        echo -e "Gõ ${TIM}bash cai-dat.sh --giup-do${RESET} để xem hướng dẫn."
        exit 1 ;;
esac
