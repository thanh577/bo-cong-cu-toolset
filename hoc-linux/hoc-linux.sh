#!/usr/bin/env bash
# ============================================================
#  HOC-LINUX — Học lệnh Linux tương tác
#  Tính năng: Quiz, Flashcard, Favorites, History
#  Phiên bản: 1.0
# ============================================================

set -euo pipefail
# shellcheck source=lib.sh
SELF_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$SELF_DIR/lib.sh"

# ===== MÀU SẮC =====
# Kiểm tra terminal hỗ trợ màu
if [ -t 1 ] && [ "${TERM:-}" != "dumb" ]; then
    XANH='\e[1;32m'; DO='\e[1;31m'; VANG='\e[1;33m'
    TIM='\e[1;36m'; HONG='\e[1;35m'; TRANG='\e[1;37m'; RESET='\e[0m'
else
    XANH=''; DO=''; VANG=''; TIM=''; HONG=''; TRANG=''; RESET=''
fi

# ===== HÀM LOG =====
info()  { echo -e "${XANH}$*${RESET}"; }
warn()  { echo -e "${VANG}$*${RESET}"; }
error() { echo -e "${DO}$*${RESET}"; }

# ===== ĐƯỜNG DẪN =====
# Dùng SELF_DIR (đã resolve symlink ở trên) thay vì tính lại — tránh lỗi khi
# chạy qua lệnh đã cài (symlink ở /usr/local/bin).
SCRIPT_DIR="$SELF_DIR"
DB_FILE="${DB_FILE:-$HOME/.lenh_linux_db.txt}"
[ ! -f "$DB_FILE" ] && DB_FILE="$SCRIPT_DIR/lenh_linux_db.txt"

FAV_FILE="$HOME/.hoclinux_favorites"
HIS_FILE="$HOME/.hoclinux_history"

# ===== KIỂM TRA DB =====
if [ ! -f "$DB_FILE" ]; then
    error "❌ Không tìm thấy file dữ liệu lệnh!"
    error "   Đặt file lenh_linux_db.txt vào: $HOME/ hoặc $SCRIPT_DIR/"
    exit 1
fi

# ===== ĐỌC DB VÀO MẢNG =====
load_db() {
    mapfile -t DB_LINES < <(grep -v '^\s*$' "$DB_FILE")
    DB_COUNT=${#DB_LINES[@]}
}

get_lenh()    { echo "${1}" | cut -d'|' -f1 | xargs; }
get_mo_ta()   { echo "${1}" | cut -d'|' -f2 | xargs; }
get_vi_du()   { local _v; _v=$(echo "${1}" | cut -d'|' -f3); echo "${_v#"${_v%%[! ]*}"}" ; }

# ===== HÀM TIỆN ÍCH =====
in_header() {
    echo -e "\n${TIM}╔════════════════════════════════════════════════════╗${RESET}"
    printf "${TIM}║${RESET}  %-50s${TIM}║${RESET}\n" "$1"
    echo -e "${TIM}╚════════════════════════════════════════════════════╝${RESET}\n"
}

ghi_lich_su() {
    local lenh="$1"
    local tg; tg=$(date '+%Y-%m-%d %H:%M')
    # Không ghi trùng liên tiếp
    local cuoi; cuoi=$(tail -1 "$HIS_FILE" 2>/dev/null | cut -d'|' -f1 | xargs)
    [ "$cuoi" = "$lenh" ] && return
    echo "${lenh}|${tg}" >> "$HIS_FILE"
    # Giữ tối đa 200 dòng
    tail -200 "$HIS_FILE" > "$HIS_FILE.tmp" && mv "$HIS_FILE.tmp" "$HIS_FILE"
}

# ============================================================
#  8. QUIZ
# ============================================================
cmd_quiz() {
    load_db
    in_header "🧠  QUIZ — Kiểm tra kiến thức lệnh Linux"

    # Phân tích tham số: quiz [số_câu] [--type]
    local so_cau=10
    local mode_type=0  # 0: multiple choice, 1: type command
    for arg in "${@:-}"; do
        case "$arg" in
            --type|-t) mode_type=1 ;;
            *)
                [ "$arg" -gt 0 ] 2>/dev/null && so_cau="$arg"
                ;;
        esac
    done

    local dung=0 sai=0

    for _ in $(seq 1 "$so_cau"); do
        # Chọn ngẫu nhiên 1 lệnh làm đáp án đúng
        local dap_an_idx=$(( RANDOM % DB_COUNT ))
        local dap_an_dong="${DB_LINES[$dap_an_idx]}"
        local lenh_dung; lenh_dung=$(get_lenh "$dap_an_dong")
        local mo_ta_dung; mo_ta_dung=$(get_mo_ta "$dap_an_dong")

        local so_tt=$(( dung + sai + 1 ))

        if [ "$mode_type" -eq 1 ]; then
            # ===== CHẾ ĐỘ GÕ LỆNH =====
            echo -e "${HONG}Câu ${so_tt}/${so_cau}:${RESET} Hãy gõ lệnh dùng để ${VANG}${mo_ta_dung}${RESET}"
            echo -ne "${VANG}Nhập lệnh: ${RESET}"
            read -r tra_loi || tra_loi=""

            # Chuẩn hóa: bỏ khoảng trắng thừa, chuyển về chữ thường
            tra_loi="$(echo "$tra_loi" | xargs)"
            local lenh_dung_norm="$(echo "$lenh_dung" | xargs)"

            if [ "$tra_loi" = "$lenh_dung_norm" ]; then
                echo -e "${XANH}✔ Đúng rồi!${RESET}  ${TIM}${lenh_dung}${RESET} — ${mo_ta_dung}"
                echo -e "   Ví dụ: ${TIM}$(get_vi_du "$dap_an_dong")${RESET}\n"
                dung=$((dung+1))
                cap_nhat_do_kho "$lenh_dung" "dung"
            else
                echo -e "${DO}✗ Sai rồi!${RESET}  Đáp án đúng là: ${TIM}${lenh_dung}${RESET}"
                echo -e "   Bạn nhập: ${DO}${tra_loi}${RESET}"
                echo -e "   Ví dụ: ${TIM}$(get_vi_du "$dap_an_dong")${RESET}\n"
                sai=$((sai+1))
                cap_nhat_do_kho "$lenh_dung" "sai"
            fi
        else
            # ===== CHẾ ĐỘ TRẮC NGHIỆM (mặc định) =====
            # Chọn 3 lệnh sai ngẫu nhiên (khác lệnh đúng)
            local cac_lua_chon=("$lenh_dung")
            while [ ${#cac_lua_chon[@]} -lt 4 ]; do
                local r=$(( RANDOM % DB_COUNT ))
                local ung_vien; ung_vien=$(get_lenh "${DB_LINES[$r]}")
                local trung=0
                for x in "${cac_lua_chon[@]}"; do
                    [ "$x" = "$ung_vien" ] && trung=1 && break
                done
                [ $trung -eq 0 ] && cac_lua_chon+=("$ung_vien")
            done

            # Xáo trộn 4 lựa chọn bằng shuf
            local xao=()
            mapfile -t xao < <(printf '%s\n' "${cac_lua_chon[@]}" | shuf)

            # Tìm vị trí đáp án đúng sau xáo
            local vi_tri=0
            for i in "${!xao[@]}"; do
                [ "${xao[$i]}" = "$lenh_dung" ] && vi_tri=$((i+1)) && break
            done

            # Hiển thị câu hỏi
            echo -e "${HONG}Câu ${so_tt}/${so_cau}:${RESET} Lệnh nào dùng để ${VANG}${mo_ta_dung}${RESET}?\n"
            for i in "${!xao[@]}"; do
                printf "   ${TIM}[%d]${RESET}  %s\n" "$((i+1))" "${xao[$i]}"
            done
            echo ""
            echo -ne "${VANG}Nhập số lựa chọn (1-4): ${RESET}"
            read -r tra_loi || tra_loi=""

            if [ "$tra_loi" = "$vi_tri" ]; then
                echo -e "${XANH}✔ Đúng rồi!${RESET}  ${TIM}${lenh_dung}${RESET} — ${mo_ta_dung}"
                echo -e "   Ví dụ: ${TIM}$(get_vi_du "$dap_an_dong")${RESET}\n"
                dung=$((dung+1))
                cap_nhat_do_kho "$lenh_dung" "dung"
            else
                echo -e "${DO}✗ Sai rồi!${RESET}  Đáp án đúng là: ${TIM}${lenh_dung}${RESET}"
                echo -e "   Ví dụ: ${TIM}$(get_vi_du "$dap_an_dong")${RESET}\n"
                sai=$((sai+1))
                cap_nhat_do_kho "$lenh_dung" "sai"
            fi
        fi

        echo -e "   ${VANG}────────────────────────────────────${RESET}"

        ghi_lich_su "quiz:${lenh_dung}"
        cap_nhat_streak
    done

    # Kết quả
    local phan_tram=$(( dung * 100 / so_cau ))
    echo -e "\n${TIM}╔═══════════════════════════╗${RESET}"
    echo -e "${TIM}║   📊  KẾT QUẢ QUIZ        ║${RESET}"
    echo -e "${TIM}╚═══════════════════════════╝${RESET}"
    echo -e "   ✔ Đúng  : ${XANH}${dung}/${so_cau}${RESET}"
    echo -e "   ✗ Sai   : ${DO}${sai}/${so_cau}${RESET}"
    if [ $phan_tram -ge 80 ]; then
        echo -e "   🏆 Xuất sắc! ${phan_tram}%"
    elif [ $phan_tram -ge 60 ]; then
        echo -e "   👍 Khá tốt! ${phan_tram}%"
    else
        echo -e "   📖 Cần ôn tập thêm. ${phan_tram}%"
    fi
    echo ""
}

# ============================================================
#  9. FLASHCARD
# ============================================================
cmd_flashcard() {
    load_db
    in_header "🃏  FLASHCARD — Luyện nhớ lệnh Linux"

    echo -e "${VANG}Phím tắt: ${TIM}Enter${VANG}=chuyển tiếp  ${TIM}s${VANG}=lưu Favorites  ${TIM}q${VANG}=thoát\n${RESET}"

    local da_hoc=0 so_tt=0

    # Tắt exit-on-error cho vòng lặp tương tác
    set +e

    # Xáo ngẫu nhiên bằng shuf
    local thu_tu=()
    mapfile -t thu_tu < <(seq 0 $((DB_COUNT-1)) | shuf)

    for idx in "${thu_tu[@]}"; do
        local dong="${DB_LINES[$idx]}"
        local lenh; lenh=$(get_lenh "$dong")
        local mo_ta; mo_ta=$(get_mo_ta "$dong")
        local vi_du; vi_du=$(get_vi_du "$dong")
        so_tt=$((so_tt+1))
        cap_nhat_streak

        # Hiện thẻ — không cố đóng khung bên phải tránh tràn tiếng Việt
        echo -e "${TIM}  ┌──────────────────────────────────────────────────┐${RESET}"
        echo -e "${TIM}  │${RESET}  Thẻ ${so_tt} / ${DB_COUNT}"
        echo -e "${TIM}  ├──────────────────────────────────────────────────┤${RESET}"
        echo -e "${TIM}  │${RESET}"
        echo -e "${TIM}  │${RESET}  💡  ${TIM}${lenh}${RESET}"
        echo -e "${TIM}  │${RESET}"
        echo -e "${TIM}  │${RESET}  📖  ${mo_ta}"
        # Tách options bằng ;; rồi in từng dòng
        python3 -c "
import sys
for o in sys.argv[1].split(';;'):
    o=o.strip()
    if o: print(o)
" "$vi_du" | while IFS= read -r opt; do
            opt="${opt#"${opt%%[! ]*}"}"; opt="${opt%"${opt##*[! ]}"}"
            [ -z "$opt" ] && continue
            echo -e "${TIM}  │${RESET}  ${VANG}▸ ${opt}${RESET}"
        done
        echo -e "${TIM}  │${RESET}"
        echo -e "${TIM}  └──────────────────────────────────────────────────┘${RESET}"

        # Kiểm tra favorites
        local da_luu=""
        grep -qx "$lenh" "$FAV_FILE" 2>/dev/null && da_luu=" ${XANH}⭐${RESET}" || true
        echo -ne "\n${VANG}[Enter]=tiếp  [s]=lưu favorites  [q]=thoát${da_luu}: ${RESET}"
        read -r nhap
        nhap="${nhap:-}"

        if [ "$nhap" = "q" ] || [ "$nhap" = "Q" ]; then
            break
        elif [ "$nhap" = "s" ] || [ "$nhap" = "S" ]; then
            if grep -qx "$lenh" "$FAV_FILE" 2>/dev/null; then
                warn "   ⭐ '${lenh}' đã có trong Favorites rồi."
            else
                echo "$lenh" >> "$FAV_FILE"
                echo -e "   ${XANH}⭐ Đã lưu '${lenh}' vào Favorites!${RESET}"
            fi
        fi

        da_hoc=$((da_hoc+1))
        cap_nhat_do_kho "$lenh" "dung"
        echo "${lenh}|flash|$(date '+%Y-%m-%d %H:%M')" >> "$HIS_FILE" 2>/dev/null
        echo ""
    done

    set -e
    echo -e "${XANH}✔ Đã xem ${da_hoc}/${DB_COUNT} thẻ trong phiên này.${RESET}\n"
}

# ============================================================
#  11. FAVORITES
# ============================================================
cmd_favorites() {
    in_header "⭐  FAVORITES — Lệnh đã đánh dấu"

    case "${1:-xem}" in
        xem|"")
            if [ ! -f "$FAV_FILE" ] || [ ! -s "$FAV_FILE" ]; then
                warn "Chưa có lệnh nào trong Favorites."
                warn "Dùng: hoc-linux favorites them <tên_lệnh>"
                warn "Hoặc nhấn [s] khi dùng Flashcard."
                return
            fi
            echo -e "${VANG}Danh sách lệnh yêu thích:${RESET}\n"
            load_db
            local so=1
            while IFS= read -r lenh; do
                [ -z "$lenh" ] && continue
                # Tìm mô tả từ DB
                local mo_ta="—"
                for dong in "${DB_LINES[@]}"; do
                    local ten; ten=$(get_lenh "$dong")
                    if [ "$ten" = "$lenh" ]; then
                        mo_ta=$(get_mo_ta "$dong")
                        break
                    fi
                done
                printf "   ${TIM}%-4s${RESET} ${XANH}%-20s${RESET} %s\n" "${so}." "$lenh" "$mo_ta"
                so=$((so+1))
            done < "$FAV_FILE"
            echo -e "\n${VANG}Dùng ${TIM}hoc-linux favorites xoa <tên_lệnh>${VANG} để xóa${RESET}\n"
            ;;
        them)
            local lenh="${2:-}"
            [ -z "$lenh" ] && error "Thiếu tên lệnh!" && exit 1
            if ! grep -q "^${lenh}$" "$FAV_FILE" 2>/dev/null; then
                echo "$lenh" >> "$FAV_FILE"
                echo -e "${XANH}⭐ Đã thêm '${lenh}' vào Favorites!${RESET}"
            else
                warn "⭐ '${lenh}' đã có trong Favorites rồi."
            fi
            ;;
        xoa)
            local lenh="${2:-}"
            [ -z "$lenh" ] && error "Thiếu tên lệnh!" && exit 1
            if [ -f "$FAV_FILE" ]; then
                grep -v "^${lenh}$" "$FAV_FILE" > "$FAV_FILE.tmp" 2>/dev/null || true; [ -f "$FAV_FILE.tmp" ] && mv "$FAV_FILE.tmp" "$FAV_FILE" || true
                echo -e "${XANH}✔ Đã xóa '${lenh}' khỏi Favorites.${RESET}"
            fi
            ;;
        xoa-tat-ca)
            echo -ne "${DO}Xóa toàn bộ Favorites? (co/khong): ${RESET}"
            read -r xn || xn=""
            [ "$xn" = "co" ] && : > "$FAV_FILE" && info "✔ Đã xóa toàn bộ."
            ;;
        *)
            error "Tùy chọn không hợp lệ. Dùng: xem | them | xoa"
            ;;
    esac
}

# ============================================================
#  12. HISTORY
# ============================================================
cmd_history() {
    in_header "📜  HISTORY — Lịch sử tra cứu"

    if [ ! -f "$HIS_FILE" ] || [ ! -s "$HIS_FILE" ]; then
        warn "Chưa có lịch sử nào."
        warn "Hãy dùng quiz hoặc flashcard để bắt đầu học!"
        return
    fi

    local so_hien="${1:-30}"

    echo -e "${VANG}${so_hien} lệnh tra cứu gần nhất:${RESET}\n"
    printf "   ${TRANG}%-4s %-25s %-12s %s${RESET}\n" "STT" "Lệnh" "Loại" "Thời gian"
    echo -e "   ${VANG}$(printf '%.0s─' {1..55})${RESET}"

    local so=1
    tac "$HIS_FILE" 2>/dev/null | head -"$so_hien" | while IFS='|' read -r lenh tg || true; do
        # Phân loại
        local loai="tra cứu"
        if [[ "$lenh" == quiz:* ]]; then
            loai="quiz"; lenh="${lenh#quiz:}"
        elif [[ "$lenh" == flash:* ]]; then
            loai="flashcard"; lenh="${lenh#flash:}"
        fi
        printf "   ${TIM}%-4s${RESET} ${XANH}%-25s${RESET} %-12s %s\n" "${so}." "$lenh" "$loai" "$tg"
        so=$((so+1))
    done

    # Thống kê
    local tong; tong=$(wc -l < "$HIS_FILE")
    local nhieu_nhat; nhieu_nhat=$(awk -F'|' '{print $1}' "$HIS_FILE" 2>/dev/null | sed 's/^quiz://;s/^flash://' | sort | uniq -c | sort -rn | head -1 || true)
    echo -e "\n   ${VANG}Tổng số lần học: ${TIM}${tong}${RESET}"
    [ -n "$nhieu_nhat" ] && echo -e "   ${VANG}Học nhiều nhất : ${TIM}${nhieu_nhat}${RESET}"

    echo -e "\n${VANG}Dùng ${TIM}hoc-linux history xoa${VANG} để xóa lịch sử${RESET}\n"

    if [ "${1:-}" = "xoa" ]; then
        echo -ne "${DO}Xóa toàn bộ lịch sử? (co/khong): ${RESET}"
        read -r xn || xn=""
        [ "$xn" = "co" ] && printf "" > "$HIS_FILE" && info "✔ Đã xóa toàn bộ lịch sử."
    fi
}

# ============================================================
#  MENU CHÍNH
# ============================================================
in_menu() {
    in_header "🐧  HOC-LINUX — Học lệnh Linux tương tác"

    # Hiện streak
    local streak; streak=$(tinh_streak)
    [ "$streak" -gt 0 ] && echo -e "   🔥 Streak: ${XANH}${streak} ngày liên tiếp${RESET}\n"

    echo -e "${HONG}Chọn chức năng:${RESET}\n"
    printf "   ${TIM}[1]${RESET}  🧠  Quiz       — Kiểm tra kiến thức (trắc nghiệm)\n"
    printf "   ${TIM}[2]${RESET}  🧠  Quiz (gõ) — Kiểm tra kiến thức (gõ lệnh)\n"
    printf "   ${TIM}[3]${RESET}  🃏  Flashcard  — Luyện nhớ (Spaced Repetition)\n"
    printf "   ${TIM}[4]${RESET}  ⭐  Favorites  — Xem lệnh đã đánh dấu\n"
    printf "   ${TIM}[5]${RESET}  📜  History    — Lịch sử học tập\n"
    printf "   ${TIM}[6]${RESET}  📊  Stats      — Thống kê & thành tích\n"
    printf "   ${TIM}[0]${RESET}  🚪  Thoát\n"
    echo ""
    echo -ne "${VANG}Nhập số lựa chọn: ${RESET}"
    read -r chon || chon=""
    case "$chon" in
        1) cmd_quiz ;;
        2) cmd_quiz 10 --type ;;
        3) cmd_flashcard ;;
        4) cmd_favorites xem ;;
        5) cmd_history ;;
        6) cmd_stats ;;
        0) echo -e "${XANH}Tạm biệt!${RESET}\n"; exit 0 ;;
        *) error "Lựa chọn không hợp lệ." ;;
    esac
}

# ============================================================
#  SPACED REPETITION — Quản lý độ khó học
# ============================================================
DIFF_FILE="$HOME/.hoclinux_difficulty"
STREAK_FILE="$HOME/.hoclinux_streak"

lay_do_kho() {
    local lenh="$1"
    # Format: lenh|lan_sai|lan_dung
    if [ -f "$DIFF_FILE" ]; then
        grep "^${lenh}|" "$DIFF_FILE" 2>/dev/null | cut -d'|' -f2 || echo "0"
    else
        echo "0"
    fi
}

cap_nhat_do_kho() {
    local lenh="$1" ket_qua="$2"  # ket_qua: "dung" hoặc "sai"
    touch "$DIFF_FILE"
    local lan_sai; lan_sai=$(grep "^${lenh}|" "$DIFF_FILE" 2>/dev/null | cut -d'|' -f2 || echo "0")
    local lan_dung; lan_dung=$(grep "^${lenh}|" "$DIFF_FILE" 2>/dev/null | cut -d'|' -f3 || echo "0")

    if [ "$ket_qua" = "sai" ]; then
        lan_sai=$((lan_sai + 1))
    else
        lan_dung=$((lan_dung + 1))
        # Giảm dần khi trả lời đúng nhiều lần
        [ "$lan_sai" -gt 0 ] && lan_sai=$((lan_sai - 1))
    fi

    grep -v "^${lenh}|" "$DIFF_FILE" > "$DIFF_FILE.tmp" 2>/dev/null || true; [ -f "$DIFF_FILE.tmp" ] && mv "$DIFF_FILE.tmp" "$DIFF_FILE" || true
    echo "${lenh}|${lan_sai}|${lan_dung}" >> "$DIFF_FILE"
}

chon_lenh_spaced() {
    # Trả về index ngẫu nhiên, ưu tiên lệnh có nhiều lần sai
    local idx; idx=$(( RANDOM % DB_COUNT ))
    if [ -f "$DIFF_FILE" ]; then
        # 40% cơ hội chọn lệnh từng sai
        if [ $(( RANDOM % 10 )) -lt 4 ]; then
            local lenh_kho; lenh_kho=$(sort -t'|' -k2 -rn "$DIFF_FILE" 2>/dev/null | head -5 | shuf | head -1 | cut -d'|' -f1 || true)
            if [ -n "$lenh_kho" ]; then
                local found_idx
                found_idx=$(grep -n "^${lenh_kho}|" "$DB_FILE" 2>/dev/null | head -1 | cut -d':' -f1)
                [ -n "$found_idx" ] && idx=$((found_idx - 1))
            fi
        fi
    fi
    echo "$idx"
}

# ============================================================
#  STREAK
# ============================================================
tinh_streak() {
    if [ ! -f "$STREAK_FILE" ]; then
        echo "0"; return
    fi
    local ngay_hom_nay; ngay_hom_nay=$(date '+%Y-%m-%d')
    local ngay_cuoi; ngay_cuoi=$(cat "$STREAK_FILE" 2>/dev/null | head -1)
    local streak; streak=$(cat "$STREAK_FILE" 2>/dev/null | tail -1)

    if [ "$ngay_cuoi" = "$ngay_hom_nay" ]; then
        echo "${streak:-1}"
    elif [ "$(date -d 'yesterday' '+%Y-%m-%d' 2>/dev/null)" = "$ngay_cuoi" ]; then
        echo "${streak:-1}"
    else
        echo "0"
    fi
}

cap_nhat_streak() {
    local ngay_hom_nay; ngay_hom_nay=$(date '+%Y-%m-%d')
    local ngay_cuoi; ngay_cuoi=$(cat "$STREAK_FILE" 2>/dev/null | head -1)
    local streak; streak=$(cat "$STREAK_FILE" 2>/dev/null | tail -1)
    streak="${streak:-0}"

    if [ "$ngay_cuoi" = "$ngay_hom_nay" ]; then
        return  # Đã cập nhật hôm nay rồi
    elif [ "$(date -d 'yesterday' '+%Y-%m-%d' 2>/dev/null)" = "$ngay_cuoi" ]; then
        streak=$((streak + 1))
    else
        streak=1
    fi
    printf '%s\n%s\n' "$ngay_hom_nay" "$streak" > "$STREAK_FILE"
}

# ============================================================
#  STATS — Thống kê học tập
# ============================================================
cmd_stats() {
    in_header "📊  THỐNG KÊ HỌC TẬP"
    set +e

    local tong_quiz=0 tong_flash=0 tong_tra=0
    if [ -f "$HIS_FILE" ]; then
        tong_quiz=$(grep -c "^quiz:" "$HIS_FILE" 2>/dev/null) || tong_quiz=0
        tong_flash=$(grep -c "^flash:" "$HIS_FILE" 2>/dev/null) || tong_flash=0
        tong_tra=$(grep -c "." "$HIS_FILE" 2>/dev/null) || tong_tra=0
        tong_tra=$(( tong_tra - tong_quiz - tong_flash ))
        [ "$tong_tra" -lt 0 ] && tong_tra=0
    fi
    local tong=$(( tong_quiz + tong_flash + tong_tra ))

    echo -e "${HONG}📈 Tổng số lần học: ${TIM}${tong}${RESET}\n"
    echo -e "   🧠 Quiz      : ${XANH}${tong_quiz}${RESET} lần"
    echo -e "   🃏 Flashcard : ${XANH}${tong_flash}${RESET} lần"
    echo -e "   🔍 Tra cứu  : ${XANH}${tong_tra}${RESET} lần"

    # Lệnh học nhiều nhất
    if [ -f "$HIS_FILE" ] && [ "$tong" -gt 0 ]; then
        echo -e "\n${HONG}🏆 Top 5 lệnh học nhiều nhất:${RESET}\n"
        awk -F'|' '{print $1}' "$HIS_FILE" | sed 's/^quiz://;s/^flash://' | \
            sort | uniq -c | sort -rn | head -5 | \
            while read -r dem lenh; do
                printf "   ${TIM}%-20s${RESET} ${XANH}%s lần${RESET}\n" "$lenh" "$dem"
            done
    fi

    # Lệnh hay sai nhất (spaced repetition)
    if [ -f "$DIFF_FILE" ] && [ -s "$DIFF_FILE" ]; then
        echo -e "\n${HONG}⚠️  Lệnh hay sai nhất (cần ôn thêm):${RESET}\n"
        sort -t'|' -k2 -rn "$DIFF_FILE" | head -5 | \
            while IFS='|' read -r lenh sai dung; do
                [ "$sai" -gt 0 ] && printf "   ${DO}%-20s${RESET} sai ${sai} lần\n" "$lenh"
            done
    fi

    # Streak
    local streak; streak=$(tinh_streak)
    echo -e "\n${HONG}🔥 Streak học liên tiếp: ${TIM}${streak} ngày${RESET}"
    [ "$streak" -ge 7 ]  && echo -e "   ${XANH}🏅 Huy hiệu: Học 7 ngày liên tiếp!${RESET}"
    [ "$streak" -ge 30 ] && echo -e "   ${XANH}🏆 Huy hiệu: Học 30 ngày liên tiếp!${RESET}"
    [ "$tong" -ge 100 ]  && echo -e "   ${XANH}⭐ Huy hiệu: 100+ lần học!${RESET}"
    [ "$tong_quiz" -ge 50 ] && echo -e "   ${XANH}🧠 Huy hiệu: Quiz master!${RESET}"
    echo ""
    set -e
}

# ============================================================
#  EXPLAIN — Giải thích từng phần của lệnh
# ============================================================
cmd_explain() {
    local lenh_day="$*"
    [ -z "$lenh_day" ] && error "Dùng: hoc-linux explain \"lệnh options...\"" && return

    in_header "🔎  GIẢI THÍCH LỆNH"
    echo -e "${VANG}Lệnh:${RESET} ${TIM}${lenh_day}${RESET}\n"

    # Tách lệnh chính và các phần
    local parts=()
    read -ra parts <<< "$lenh_day"
    local lenh_chinh="${parts[0]}"

    # Tra DB lấy mô tả lệnh chính
    local dong_db; dong_db=$(grep -i "^${lenh_chinh}|" "$DB_FILE" 2>/dev/null | head -1 || true)

    if [ -n "$dong_db" ]; then
        local mo_ta; mo_ta=$(echo "$dong_db" | cut -d'|' -f2 | xargs)
        local options_db; options_db=$(echo "$dong_db" | cut -d'|' -f3)
        echo -e "   ${XANH}${lenh_chinh}${RESET}  →  ${mo_ta}\n"

        # Giải thích từng option
        for part in "${parts[@]:1}"; do
            [ -z "$part" ] && continue
            # Tìm option trong DB
            local mo_ta_opt; mo_ta_opt=$(echo "$options_db" | tr ';;' '\n' | grep -i "^[[:space:]]*${part}" | head -1 | xargs || true)
            if [ -n "$mo_ta_opt" ]; then
                printf "   ${VANG}%-15s${RESET} →  %s\n" "$part" "$mo_ta_opt"
            else
                printf "   ${VANG}%-15s${RESET} →  (không có trong DB — dùng: man %s)\n" "$part" "$lenh_chinh"
            fi
        done
    else
        echo -e "   ${VANG}'${lenh_chinh}' chưa có trong DB.${RESET}"
        echo -e "   Dùng: ${TIM}man ${lenh_chinh}${RESET} hoặc ${TIM}${lenh_chinh} --help${RESET}"
    fi
    echo ""
}

# ============================================================
#  CHEATSHEET — Tóm tắt nhanh 1 lệnh
# ============================================================
cmd_cheatsheet() {
    local lenh="${1:-}"
    [ -z "$lenh" ] && error "Dùng: hoc-linux cheat <tên_lệnh>" && return

    local dong_db; dong_db=$(grep -i "^${lenh}|" "$DB_FILE" 2>/dev/null | head -1 || true)
    if [ -z "$dong_db" ]; then
        warn "Không tìm thấy '${lenh}' trong DB."
        return
    fi

    local mo_ta;     mo_ta=$(echo "$dong_db"     | cut -d'|' -f2 | xargs)
    local options;   options=$(echo "$dong_db"   | cut -d'|' -f3)
    local lien_quan; lien_quan=$(echo "$dong_db" | cut -d'|' -f4 | xargs)

    echo -e "\n${TIM}✂️  CHEATSHEET — ${XANH}${lenh}${RESET}  —  ${mo_ta}\n"
    python3 -c "
import sys
for opt in sys.argv[1].split(';;'):
    opt = opt.strip()
    if opt:
        print(opt)
" "$options" | while IFS= read -r opt; do
        opt="${opt#"${opt%%[! ]*}"}"; opt="${opt%"${opt##*[! ]}"}"
        [ -z "$opt" ] && continue
        # Tách flag và mô tả
        local flag; flag=$(echo "$opt" | cut -d'(' -f1); flag="${flag#"${flag%%[! ]*}"}" ; flag="${flag%"${flag##*[! ]}"}" 
        local desc; desc=$(echo "$opt" | grep -o '([^)]*)' | tr -d '()')
        printf "   ${VANG}%-25s${RESET} %s\n" "${lenh} ${flag}" "$desc"
    done
    [ -n "$lien_quan" ] && echo -e "\n   ${HONG}📌 Xem thêm:${RESET} ${lien_quan}"
    echo ""
}

# ============================================================
#  ĐIỀU PHỐI
# ============================================================
case "${1:-}" in
    "quiz"|"q")
        shift
        cmd_quiz "${@:-10}" ;;
    "flashcard"|"flash"|"f")
        cmd_flashcard ;;
    "favorites"|"fav"|"star")
        shift
        cmd_favorites "${1:-xem}" "${2:-}" ;;
    "history"|"his"|"h")
        cmd_history "${2:-30}" ;;
    "stats"|"stat")
        cmd_stats ;;
    "explain"|"exp")
        shift
        cmd_explain "$@" ;;
    "cheatsheet"|"cheat"|"cs")
        cmd_cheatsheet "${2:-}" ;;
    ""|"menu")
        in_menu ;;
    *)
        error "Lệnh không hợp lệ: $1"
        echo -e "Dùng: ${TIM}hoc-linux${RESET} để mở menu"
        exit 1 ;;
esac
