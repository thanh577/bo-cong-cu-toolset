#!/usr/bin/env bash
# ============================================================
#  HOC LENH — Tra cứu lệnh Linux từ file DB
#  Phiên bản: 3.0 — Data-driven, fuzzy search, tìm theo mô tả
# ============================================================

set -euo pipefail
# shellcheck source=lib.sh
SELF_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$SELF_DIR/lib.sh"

# ===== ĐƯỜNG DẪN DB =====
# Dùng SELF_DIR (đã resolve symlink ở trên) thay vì tính lại — nếu không, khi
# chạy qua lệnh đã cài (/usr/local/bin/hoc là symlink), đường dẫn dự phòng sẽ trỏ
# sai vào /usr/local/bin thay vì thư mục cài thật.
SCRIPT_DIR="$SELF_DIR"
DB_FILE="${HOC_DB:-$HOME/.lenh_linux_db.txt}"
[ ! -f "$DB_FILE" ] && DB_FILE="$SCRIPT_DIR/lenh_linux_db.txt"

if [ ! -f "$DB_FILE" ]; then
    echo -e "${DO}❌ Không tìm thấy file DB: $DB_FILE${RESET}"
    exit 1
fi

# ===== HÀM HIỂN THỊ MỘT LỆNH =====
hien_lenh() {
    local dong="$1"
    local ten;         ten=$(echo "$dong"         | cut -d'|' -f1 | xargs)
    local mo_ta;       mo_ta=$(echo "$dong"       | cut -d'|' -f2 | xargs)
    local options;     options=$(echo "$dong"     | cut -d'|' -f3)
    local lien_quan;   lien_quan=$(echo "$dong"   | cut -d'|' -f4 | xargs)
    local do_kho;      do_kho=$(echo "$dong"      | cut -d'|' -f5 | xargs)
    local vi_du_full;  vi_du_full=$(echo "$dong"  | cut -d'|' -f6 | xargs)

    # Nhãn độ khó
    local nhan_kho=""
    case "$do_kho" in
        1) nhan_kho="${XANH}● Cơ bản${RESET}" ;;
        2) nhan_kho="${VANG}● Trung bình${RESET}" ;;
        3) nhan_kho="${DO}● Nâng cao${RESET}" ;;
    esac

    echo ""
    echo -e "${TIM}  ┌──────────────────────────────────────────────────┐${RESET}"
    echo -e "${TIM}  │${RESET}  ${XANH}${ten}${RESET}  —  ${mo_ta}"
    [ -n "$nhan_kho" ] && echo -e "${TIM}  │${RESET}  ${nhan_kho}"
    echo -e "${TIM}  ├──────────────────────────────────────────────────┤${RESET}"

    # In từng option trên 1 dòng — dùng python3 để tách ;; chính xác
    python3 -c "
import sys
opts = sys.argv[1]
for opt in opts.split(';;'):
    opt = opt.strip()
    if opt:
        print(opt)
" "$options" | while IFS= read -r opt; do
        # Trim khoảng trắng không dùng xargs (xargs cắt mất dấu -)
        opt="${opt#"${opt%%[! ]*}"}"
        opt="${opt%"${opt##*[! ]}"}"
        [ -z "$opt" ] && continue
        echo -e "${TIM}  │${RESET}  ${VANG}${opt}${RESET}"
    done

    # Lệnh liên quan
    if [ -n "$lien_quan" ]; then
        echo -e "${TIM}  ├──────────────────────────────────────────────────┤${RESET}"
        echo -e "${TIM}  │${RESET}  ${HONG}📌 Liên quan:${RESET} ${lien_quan}"
    fi

    # Lệnh hoàn chỉnh (chỉ có khi từ AI)
    if [ -n "$vi_du_full" ]; then
        echo -e "${TIM}  ├──────────────────────────────────────────────────┤${RESET}"
        echo -e "${TIM}  │${RESET}  ${XANH}📦 Ví dụ chạy ngay:${RESET}"
        echo -e "${TIM}  │${RESET}  ${TIM}$ ${vi_du_full}${RESET}"
    fi

    echo -e "${TIM}  └──────────────────────────────────────────────────┘${RESET}"
    echo ""
}

# ===== HIỂN THỊ DANH SÁCH =====
hien_danh_sach() {
    local title="$1"
    local results="$2"
    local dem=0

    echo -e "\n${HONG}${title}${RESET}\n"
    printf "   ${TRANG}%-15s %s${RESET}\n" "Lệnh" "Mô tả"
    echo -e "   ${VANG}$(printf '%.0s─' {1..50})${RESET}"

    while IFS= read -r dong; do
        [ -z "$dong" ] && continue
        local ten; ten=$(echo "$dong" | cut -d'|' -f1 | xargs)
        local mo_ta; mo_ta=$(echo "$dong" | cut -d'|' -f2 | xargs)
        printf "   ${TIM}%-15s${RESET} %s\n" "$ten" "$mo_ta"
        dem=$((dem+1))
    done <<< "$results"

    echo -e "\n   ${VANG}Tổng: ${dem} lệnh${RESET}"
    echo -e "   ${VANG}Dùng ${TIM}hoc <tên_lệnh>${VANG} để xem chi tiết${RESET}\n"
}

# ===== CẤU HÌNH GROQ AI =====
HOC_CONFIG="$HOME/.hoc_config"

# Đọc key từ file config nếu chưa có trong môi trường
if [ -z "${GROQ_API_KEY:-}" ] && [ -f "$HOC_CONFIG" ]; then
    # shellcheck source=/dev/null
    source "$HOC_CONFIG" 2>/dev/null
fi
GROQ_KEY="${GROQ_API_KEY:-}"
GROQ_MODEL="llama-3.3-70b-versatile"
AI_CACHE_FILE="$HOME/.hoc_ai_cache.txt"

# ===== KNOWN CORRECTIONS — sửa lỗi hallucinate phổ biến =====
sua_lenh_sai() {
    local cmd="$1"
    # wget: -o (log) vs -O (output file)
    cmd=$(echo "$cmd" | sed 's/wget \(.*\) -o /wget \1 -O /g' | sed 's/wget -o /wget -O /g')
    # tar: thứ tự flag phổ biến bị sai
    cmd=$(echo "$cmd" | sed 's/tar -xvzf/tar -xzf/g' | sed 's/tar -cvzf/tar -czf/g')
    # chmod: hay bị nhầm 777 → nhắc nhở nhưng giữ nguyên
    echo "$cmd"
}

# ===== DRY-RUN VALIDATION — kiểm tra option có tồn tại không =====
kiem_tra_option() {
    local lenh="$1" option="$2"
    # Chỉ kiểm tra nếu lệnh có sẵn trên hệ thống
    command -v "$lenh" &>/dev/null || return 0
    # Thử --help và man để xác minh option
    if "$lenh" --help 2>&1 | grep -qw -- "$option" 2>/dev/null; then
        return 0  # Option hợp lệ
    fi
    return 1  # Option không tìm thấy
}

# ===== TÌM KIẾM AI QUA GROQ =====
tim_bang_ai() {
    local mo_ta="$1"

    # Kiểm tra API key
    if [ -z "$GROQ_KEY" ]; then
        error "❌ Chưa có Groq API key!"
        warn "   Lấy key miễn phí tại: https://console.groq.com"
        warn "   Sau đó lưu vào file config:"
        warn "   ${TIM}echo 'GROQ_API_KEY=\"gsk_your_key\"' >> ~/.hoc_config${RESET}"
        return 1
    fi

    # Kiểm tra cache trước
    if [ -f "$AI_CACHE_FILE" ]; then
        local cache_hit; cache_hit=$(grep -i "^${mo_ta}|" "$AI_CACHE_FILE" 2>/dev/null || true)
        if [ -n "$cache_hit" ]; then
            local dong_lenh; dong_lenh=$(echo "$cache_hit" | cut -d'|' -f2-)
            hien_lenh "$dong_lenh"
            return 0
        fi
    fi

    echo -e "\n${VANG}🤖 Đang hỏi AI...${RESET}"

    # ── PROMPT JSON — yêu cầu chính xác, không hallucinate ──
    local PROMPT="Tìm lệnh Linux CHÍNH XÁC để: \"${mo_ta}\".

QUAN TRỌNG:
- Không được sai option, phân biệt chữ hoa/thường (vd: wget -O vs -o)
- Ưu tiên lệnh đơn giản, đúng mục đích nhất
- Phải chạy được ngay trên Ubuntu

Trả lời JSON hợp lệ, không giải thích gì thêm:
{
  \"command\": \"tên_lệnh_đơn\",
  \"description\": \"mô tả ngắn\",
  \"options\": \"-flag1 (ý nghĩa);; -flag2 (ý nghĩa);; -flag3 (ý nghĩa)\",
  \"related\": \"lệnh1, lệnh2\",
  \"example\": \"lệnh_hoàn_chỉnh_chạy_được_ngay\"
}"

    local PROMPT_JSON
    PROMPT_JSON=$(python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$PROMPT" 2>/dev/null) || {
        error "❌ Lỗi encode prompt."
        return 1
    }

    local RESPONSE
    RESPONSE=$(curl -s "https://api.groq.com/openai/v1/chat/completions" \
        -H "Authorization: Bearer ${GROQ_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"${GROQ_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":${PROMPT_JSON}}],\"max_tokens\":300,\"temperature\":0.1}" \
        2>/dev/null) || true

    # Kiểm tra lỗi API
    local err_msg
    err_msg=$(echo "$RESPONSE" | python3 -c "
import json,sys
d=json.load(sys.stdin)
if 'error' in d:
    print(d['error'].get('message','Unknown error'))
" 2>/dev/null || true)
    if [ -n "$err_msg" ]; then
        error "❌ Groq API lỗi: ${err_msg}"
        return 1
    fi

    # Parse JSON response
    local KET_QUA
    KET_QUA=$(echo "$RESPONSE" | python3 -c "
import json, sys, re
try:
    d = json.load(sys.stdin)
    text = d['choices'][0]['message']['content'].strip()
    # Tìm JSON block trong response
    json_match = re.search(r'\{[^{}]+\}', text, re.DOTALL)
    if not json_match:
        sys.exit(1)
    obj = json.loads(json_match.group())
    cmd     = re.sub(r'[^\w\-]', '', obj.get('command','').strip().strip('\`'))
    desc    = obj.get('description','').strip()
    opts    = obj.get('options','').strip()
    related = obj.get('related','').strip()
    example = obj.get('example','').strip()
    if cmd:
        print(f'{cmd}|{desc}|{opts}|{related}|2|{example}')
except Exception as e:
    pass
" 2>/dev/null)

    if [ -z "$KET_QUA" ] || [[ "$KET_QUA" != *"|"* ]]; then
        error "❌ AI trả về kết quả không hợp lệ."
        warn "   Thử lại hoặc dùng: hoc --mo-ta <từ_khóa>"
        return 1
    fi

    # ── GUARD RULES — sửa lỗi hallucinate phổ biến ──
    local vi_du_ai; vi_du_ai=$(echo "$KET_QUA" | cut -d'|' -f6)
    local vi_du_fixed; vi_du_fixed=$(sua_lenh_sai "$vi_du_ai")
    if [ "$vi_du_fixed" != "$vi_du_ai" ]; then
        warn "   ⚠ Đã tự động sửa lệnh ví dụ (guard rule)"
        KET_QUA=$(echo "$KET_QUA" | python3 -c "
import sys
parts = sys.stdin.read().rstrip('\n').split('|')
parts[5] = '${vi_du_fixed}'
print('|'.join(parts))
" 2>/dev/null) || true
    fi

    # ── DRY-RUN VALIDATION — kiểm tra option qua --help ──
    local ten_check; ten_check=$(echo "$KET_QUA" | cut -d'|' -f1)
    local opts_check; opts_check=$(echo "$KET_QUA" | cut -d'|' -f3)
    if command -v "$ten_check" &>/dev/null; then
        local help_text; help_text=$("$ten_check" --help 2>&1 || true)
        local canh_bao=""
        # Kiểm tra từng option trong danh sách
        echo "$opts_check" | python3 -c "
import sys
opts = sys.argv[1] if len(sys.argv) > 1 else ''
for o in opts.split(';;'):
    o = o.strip()
    flag = o.split('(')[0].strip()
    if flag:
        print(flag)
" "$opts_check" 2>/dev/null | while read -r flag; do
            flag_clean="${flag%% *}"
            if [ -n "$flag_clean" ] && [ -n "$help_text" ]; then
                if ! echo "$help_text" | grep -qF "$flag_clean" 2>/dev/null; then
                    echo -e "   ${VANG}⚠ Option ${flag_clean} không tìm thấy trong --help của ${ten_check}${RESET}"
                fi
            fi
        done
    fi

    # ── VALIDATION — ưu tiên DB nếu lệnh đã có ──
    local ten_ai; ten_ai=$(echo "$KET_QUA" | cut -d'|' -f1)
    local db_hit; db_hit=$(grep -i "^${ten_ai}|" "$DB_FILE" 2>/dev/null | head -1 || true)
    if [ -n "$db_hit" ]; then
        # Dùng options từ DB (đã kiểm chứng) + ví dụ hoàn chỉnh từ AI
        local vi_du_keep; vi_du_keep=$(echo "$KET_QUA" | cut -d'|' -f6)
        KET_QUA="${db_hit}|${vi_du_keep}"
    fi

    # Lưu vào cache
    echo "${mo_ta}|${KET_QUA}" >> "$AI_CACHE_FILE"
    # Giữ tối đa 200 dòng cache
    tail -200 "$AI_CACHE_FILE" > "$AI_CACHE_FILE.tmp" 2>/dev/null && mv "$AI_CACHE_FILE.tmp" "$AI_CACHE_FILE"
    hien_lenh "$KET_QUA"
}

# ===== XEM / XÓA AI CACHE =====
quan_ly_cache() {
    case "${1:-xem}" in
        xem)
            if [ ! -f "$AI_CACHE_FILE" ] || [ ! -s "$AI_CACHE_FILE" ]; then
                warn "Cache AI trống."
                return
            fi
            echo -e "\n${HONG}🗄️  AI CACHE (${AI_CACHE_FILE}):${RESET}\n"
            local so=1
            while IFS='|' read -r mo_ta ten rest; do
                printf "   ${TIM}%-4s${RESET} ${VANG}%-30s${RESET} → ${XANH}%s${RESET}\n" "${so}." "$mo_ta" "$ten"
                so=$((so+1))
            done < "$AI_CACHE_FILE"
            echo ""
            ;;
        xoa)
            : > "$AI_CACHE_FILE"
            info "✔ Đã xóa toàn bộ AI cache."
            ;;
    esac
}



if [ -z "${1:-}" ]; then
    TONG=$(grep -c '.' "$DB_FILE" 2>/dev/null || echo 0)
    echo -e "\n${TIM}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${TIM}║         📘  HOC LENH LINUX                         ║${RESET}"
    echo -e "${TIM}╚════════════════════════════════════════════════════╝${RESET}\n"
    echo -e "   ${VANG}DB:${RESET} $DB_FILE ${VANG}(${TONG} lệnh)${RESET}\n"
    echo -e "${XANH}Cách dùng:${RESET}"
    printf "   ${TIM}%-30s${RESET} %s\n" "hoc <tên_lệnh>"        "Tra cứu lệnh cụ thể"
    printf "   ${TIM}%-30s${RESET} %s\n" "hoc --danh-sach"       "Xem toàn bộ ${TONG} lệnh"
    printf "   ${TIM}%-30s${RESET} %s\n" "hoc --tim <từ_khóa>"   "Tìm theo tên gần đúng (fuzzy)"
    printf "   ${TIM}%-30s${RESET} %s\n" "hoc --mo-ta <từ_khóa>" "Tìm theo mô tả / công dụng"
    printf "   ${TIM}%-30s${RESET} %s\n" "hoc --ai <mô tả>"      "🤖 Hỏi AI (Groq) tìm lệnh"
    printf "   ${TIM}%-30s${RESET} %s\n" "hoc --nghe <tên_lệnh>" "🔊 Đọc to mô tả + các option"
    printf "   ${TIM}%-30s${RESET} %s\n" "hoc --cache [xoa]"     "Xem/xóa cache kết quả AI"
    echo ""
    exit 0
fi

# ===== DANH SÁCH =====
if [ "$1" = "--danh-sach" ] || [ "$1" = "-l" ]; then
    KQ=$(grep -v '^\s*$' "$DB_FILE" 2>/dev/null || true)
    hien_danh_sach "📋 Toàn bộ lệnh trong DB:" "$KQ"
    exit 0
fi

# ===== TÌM THEO TÊN GẦN ĐÚNG (FUZZY) =====
if [ "$1" = "--tim" ] || [ "$1" = "-t" ]; then
    TU_KHOA="${2:-}"
    [ -z "$TU_KHOA" ] && echo -e "${DO}❌ Thiếu từ khóa! Dùng: hoc --tim <từ_khóa>${RESET}" && exit 1

    # Tìm chính xác trước
    KQ_CHINH=$(grep -i "^${TU_KHOA}|" "$DB_FILE" 2>/dev/null || true)

    # Tìm gần đúng: tên bắt đầu bằng, rồi tên chứa
    KQ_FUZZY=$(grep -iv "^${TU_KHOA}|" "$DB_FILE" 2>/dev/null | grep -i "^${TU_KHOA:0:2}" 2>/dev/null || true)
    [ -z "$KQ_FUZZY" ] && KQ_FUZZY=$(grep -i "^[^|]*${TU_KHOA}" "$DB_FILE" 2>/dev/null || true)

    KQ=$(printf '%s\n%s' "$KQ_CHINH" "$KQ_FUZZY" | grep -v '^\s*$' | sort -u || true)

    if [ -z "$KQ" ]; then
        echo -e "\n${VANG}Không tìm thấy lệnh nào gần với '${TU_KHOA}'${RESET}"
        echo -e "${VANG}Thử: ${TIM}hoc --mo-ta ${TU_KHOA}${RESET}\n"
        exit 0
    fi

    DEM=$(echo "$KQ" | grep -c '.' || true)
    if [ "$DEM" -eq 1 ]; then
        # Chỉ 1 kết quả → hiện luôn chi tiết
        hien_lenh "$KQ"
    else
        hien_danh_sach "🔍 Kết quả tìm kiếm '${TU_KHOA}':" "$KQ"
    fi
    exit 0
fi

# ===== TÌM THEO MÔ TẢ / CÔNG DỤNG =====
if [ "$1" = "--mo-ta" ] || [ "$1" = "-m" ]; then
    TU_KHOA="${2:-}"
    [ -z "$TU_KHOA" ] && echo -e "${DO}❌ Thiếu từ khóa! Dùng: hoc --mo-ta <từ_khóa>${RESET}" && exit 1

    # Tìm trong mô tả (cột 2) và options (cột 3)
    KQ=$(grep -i "${TU_KHOA}" "$DB_FILE" 2>/dev/null || true)

    if [ -z "$KQ" ]; then
        echo -e "\n${VANG}Không tìm thấy lệnh nào liên quan đến '${TU_KHOA}'${RESET}\n"
        exit 0
    fi

    DEM=$(echo "$KQ" | grep -c '.' || true)
    if [ "$DEM" -eq 1 ]; then
        hien_lenh "$KQ"
    else
        hien_danh_sach "🔍 Lệnh liên quan đến '${TU_KHOA}':" "$KQ"
    fi
    exit 0
fi

# ===== TÌM BẰNG AI (GROQ) =====
if [ "$1" = "--ai" ] || [ "$1" = "-ai" ]; then
    shift
    MO_TA_AI="$*"
    [ -z "$MO_TA_AI" ] && error "❌ Thiếu mô tả! Dùng: hoc --ai xóa cả thư mục con" && exit 1

    # Tìm trong DB trước — chỉ so khớp cột 2 (mô tả) để tránh match nhầm
    KQ_DB=$(awk -F'|' -v q="${MO_TA_AI}" 'tolower($2) ~ tolower(q)' "$DB_FILE" 2>/dev/null | head -1 || true)
    if [ -n "$KQ_DB" ]; then
        hien_lenh "$KQ_DB"
        exit 0
    fi

    # Không có trong DB → gọi Groq
    tim_bang_ai "$MO_TA_AI"
    exit 0
fi

# ===== QUẢN LÝ AI CACHE =====
if [ "$1" = "--cache" ]; then
    quan_ly_cache "${2:-xem}"
    exit 0
fi

# ===== NGHE GIẢI THÍCH LỆNH (đọc to mô tả + các option) =====
if [ "$1" = "--nghe" ] || [ "$1" = "nghe" ] || [ "$1" = "--speak" ]; then
    shift
    LENH_NGHE="$*"
    # Cắt khoảng trắng đầu/cuối — không dùng xargs (có thể nuốt mất ký tự "-"
    # nếu tên lệnh gõ vào bắt đầu bằng dấu gạch ngang)
    LENH_NGHE="${LENH_NGHE#"${LENH_NGHE%%[! ]*}"}"
    LENH_NGHE="${LENH_NGHE%"${LENH_NGHE##*[! ]}"}"
    [ -z "$LENH_NGHE" ] && error "❌ Thiếu tên lệnh! Dùng: hoc --nghe cp" && exit 1

    DONG_NGHE=$(grep -i "^${LENH_NGHE}|" "$DB_FILE" 2>/dev/null | head -1 || true)
    if [ -z "$DONG_NGHE" ]; then
        error "❌ Không tìm thấy '${LENH_NGHE}' trong DB."
        warn "   Thử: ${TIM}hoc --tim ${LENH_NGHE}${RESET}"
        exit 1
    fi

    # Hiện khung thông tin y hệt "hoc <lệnh>" bình thường
    hien_lenh "$DONG_NGHE"

    TEN_NGHE=$(echo "$DONG_NGHE" | cut -d'|' -f1 | xargs)
    MO_TA_NGHE=$(echo "$DONG_NGHE" | cut -d'|' -f2 | xargs)
    OPTIONS_NGHE=$(echo "$DONG_NGHE" | cut -d'|' -f3)

    # Ghép văn bản để đọc: tên lệnh + mô tả + từng option (tách flag/nghĩa cho
    # tự nhiên hơn khi đọc, thay vì đọc nguyên "-r (sao chép thư mục)")
    VAN_BAN_DOC="Lệnh ${TEN_NGHE}. ${MO_TA_NGHE}."
    OPTION_TEXT=$(python3 -c "
import sys, re
opts = sys.argv[1]
parts = []
for opt in opts.split(';;'):
    opt = opt.strip()
    if not opt:
        continue
    m = re.match(r'^(\S+)\s*\((.*)\)\s*\$', opt)
    if m:
        flag, mota = m.group(1), m.group(2)
        parts.append(f'{flag}: {mota}')
    else:
        parts.append(opt)
print('. '.join(parts))
" "$OPTIONS_NGHE" 2>/dev/null)
    [ -n "$OPTION_TEXT" ] && [[ "$OPTION_TEXT" != "("* ]] && VAN_BAN_DOC="${VAN_BAN_DOC} Các tùy chọn: ${OPTION_TEXT}."

    echo -e "${VANG}🔊 Đang đọc...${RESET}"
    if ! doc "$VAN_BAN_DOC" "vi"; then
        warn "   ⚠ Không tìm thấy công cụ đọc. Chạy: ${TIM}bash cai-dat.sh --thu-vien${RESET}"
    fi
    echo ""
    exit 0
fi



# ===== TRA CỨU LỆNH CỤ THỂ =====
LENH="$1"

# Tìm chính xác trong DB
DONG=$(grep -i "^${LENH}|" "$DB_FILE" 2>/dev/null || true)

if [ -n "$DONG" ]; then
    # Tìm thấy trong DB → hiện từ DB
    hien_lenh "$DONG"

    # Kiểm tra lệnh có tồn tại trong hệ thống không
    if ! command -v "$LENH" &>/dev/null; then
        echo -e "   ${VANG}⚠ Lệnh '${LENH}' chưa được cài trên máy này.${RESET}"
        echo -e "   ${VANG}   Thử: ${TIM}sudo apt install ${LENH}${RESET}\n"
    fi
else
    # Không có trong DB → thử fuzzy gợi ý
    echo -e "\n${VANG}Không tìm thấy '${LENH}' trong DB.${RESET}"

    GOI_Y=$(grep -i "^${LENH:0:2}" "$DB_FILE" 2>/dev/null | head -5 || true)
    if [ -n "$GOI_Y" ]; then
        echo -e "${VANG}Có phải bạn muốn nói:${RESET}\n"
        while IFS= read -r dong; do
            [ -z "$dong" ] && continue
            local_ten=$(echo "$dong" | cut -d'|' -f1 | xargs)
            local_mo=$(echo "$dong"  | cut -d'|' -f2 | xargs)
            printf "   ${TIM}%-15s${RESET} %s\n" "$local_ten" "$local_mo"
        done <<< "$GOI_Y"
        echo ""
    fi

    # Thử tìm trong man nếu lệnh tồn tại
    if command -v "$LENH" &>/dev/null; then
        echo -e "   ${VANG}Lệnh '${LENH}' tồn tại trên hệ thống. Dùng:${RESET}"
        echo -e "   ${TIM}man ${LENH}${RESET}  hoặc  ${TIM}${LENH} --help${RESET}\n"
    fi
fi
