#!/usr/bin/env bash
set -euo pipefail
SELF_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$SELF_DIR/lib.sh"

# Dùng SELF_DIR (đã resolve symlink ở trên) — tránh lỗi khi chạy qua lệnh đã
# cài (symlink ở /usr/local/bin) khiến đường dẫn dự phòng trỏ sai chỗ.
SCRIPT_DIR="$SELF_DIR"
CN_DB_FILE="${HOC_CN_DB:-$HOME/.tiengtrung_db.txt}"
[ ! -f "$CN_DB_FILE" ] && CN_DB_FILE="$SCRIPT_DIR/../data/tiengtrung_db.txt"

if [ ! -f "$CN_DB_FILE" ]; then
    error "❌ Không tìm thấy DB tiếng Trung: $CN_DB_FILE"
    exit 1
fi

# ===== GROQ AI =====
HOC_CONFIG="$HOME/.hoc_config"
if [ -z "${GROQ_API_KEY:-}" ] && [ -f "$HOC_CONFIG" ]; then
    source "$HOC_CONFIG" 2>/dev/null
fi
GROQ_KEY="${GROQ_API_KEY:-}"
GROQ_MODEL="llama-3.3-70b-versatile"
AI_CACHE_FILE="$HOME/.hoc_ai_cache.txt"

# ===== HIỂN THỊ MỘT TỪ =====
in_dong_khung() {
    local label="$1" content="$2" color="$3" max_w="${4:-62}"
    local prefix="  ${TIM}│${RESET}  "
    local lines
    lines=$(python3 -c "
import unicodedata, sys
label=sys.argv[1]; content=sys.argv[2]; max_w=int(sys.argv[3])
def dw(s): return sum(2 if unicodedata.east_asian_width(c) in ('W','F') else 1 for c in s)
def best_break(s, limit):
    cw=0; last_space=-1
    for i,ch in enumerate(s):
        chw=2 if unicodedata.east_asian_width(ch) in ('W','F') else 1
        cw+=chw
        if cw>limit: break
        if ch in ' 、，。！？）》」』】;:)\\n': last_space=i
    if last_space>=0: return last_space+1
    cw=0
    for i,ch in enumerate(s):
        chw=2 if unicodedata.east_asian_width(ch) in ('W','F') else 1
        cw+=chw
        if cw>limit: return max(i,1)
    return len(s)
label_str=label+'  ' if label else ''; label_w=dw(label_str)
if dw(content)<=max_w-label_w: print(label_str+content); sys.exit(0)
cont_pad=' '*label_w; remaining=content; first=True
while remaining:
    limit=max_w-label_w if first else max_w
    brk=best_break(remaining, limit)
    chunk=remaining[:brk].rstrip(); remaining=remaining[brk:].lstrip()
    if first: print(label_str+chunk); first=False
    else: print(cont_pad+chunk)
" "$label" "$content" "$max_w")
    local first=1
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        if [ "$first" = "1" ] && [ -n "$label" ]; then
            echo -e "${prefix}${VANG}${line}${RESET}"; first=0
        elif [ "$first" = "1" ]; then
            echo -e "${prefix}${color}${line}${RESET}"; first=0
        else
            echo -e "${prefix}${color}${line}${RESET}"
        fi
    done <<< "$lines"
}

hien_tu() {
    local dong="$1"
    local hanzi=$(echo "$dong" | cut -d'|' -f1 | xargs)
    local pinyin=$(echo "$dong" | cut -d'|' -f2 | xargs)
    local nghia=$(echo "$dong" | cut -d'|' -f3 | xargs)
    local vi_du=$(echo "$dong" | cut -d'|' -f4)
    vi_du="${vi_du#"${vi_du%%[! ]*}"}"; vi_du="${vi_du%"${vi_du##*[! ]}"}"
    local phien_am=$(echo "$dong" | cut -d'|' -f5 | xargs)
    local phien_vd=$(echo "$dong" | cut -d'|' -f6)
    phien_vd="${phien_vd#"${phien_vd%%[! ]*}"}"; phien_vd="${phien_vd%"${phien_vd##*[! ]}"}"

    echo ""
    echo -e "${TIM}  ┌────────────────────────────────────────────────────────────────┐${RESET}"
    in_dong_khung "" "${hanzi}  —  ${nghia}" "${DO}"
    echo -e "${TIM}  ├────────────────────────────────────────────────────────────────┤${RESET}"
    in_dong_khung "Pinyin:" "${pinyin}" "${TRANG}"
    in_dong_khung "Đọc:" "${phien_am}" "${VANG}"
    [ -n "$vi_du" ] && echo -e "${TIM}  │${RESET}"
    if [ -n "$vi_du" ]; then
        local vd_trung="${vi_du%%\(*}"
        local vd_nghia=""
        [[ "$vi_du" == *"("* ]] && vd_nghia="(${vi_du#*\(}"
        in_dong_mau_2 "Ví dụ:" "${vd_trung}" "${vd_nghia}" "${TRANG}" "${TIM}"
    fi
    [ -n "$phien_vd" ] && in_dong_khung "Đọc ví dụ:" "${phien_vd}" "${HONG}"
    echo -e "${TIM}  └────────────────────────────────────────────────────────────────┘${RESET}"
    echo ""
}

in_dong_mau_2() {
    local label="$1" part1="$2" part2="$3" color1="$4" color2="$5"
    local prefix="  ${TIM}│${RESET}  "
    local full="${part1}"; [ -n "$part2" ] && full="${part1} ${part2}"
    local label_str="${label}  "
    local label_w=$(python3 -c "import unicodedata,sys; s=sys.argv[1]; print(sum(2 if unicodedata.east_asian_width(c) in ('W','F') else 1 for c in s))" "$label_str")
    local total_w=$(python3 -c "import unicodedata,sys; s=sys.argv[1]; print(sum(2 if unicodedata.east_asian_width(c) in ('W','F') else 1 for c in s))" "$full")
    local max_w=62
    if [ "$total_w" -le $(( max_w - label_w )) ]; then
        echo -e "${prefix}${VANG}${label_str}${RESET}${color1}${part1}${RESET} ${color2}${part2}${RESET}"
        return
    fi
    local result=$(python3 -c "
import unicodedata, sys
def dw(s): return sum(2 if unicodedata.east_asian_width(c) in ('W','F') else 1 for c in s)
def best_break(s, limit):
    cw=0; last_sp=-1
    for i,ch in enumerate(s):
        chw=2 if unicodedata.east_asian_width(ch) in ('W','F') else 1
        cw+=chw
        if cw>limit: break
        if ch in ' 、，。！？）》」』】;:)\\n': last_sp=i
    if last_sp>=0: return last_sp+1
    cw=0
    for i,ch in enumerate(s):
        chw=2 if unicodedata.east_asian_width(ch) in ('W','F') else 1
        cw+=chw
        if cw>limit: return max(i,1)
    return len(s)
p1=sys.argv[1]; p2=sys.argv[2]; lw=int(sys.argv[3]); max_w=62
first_avail=max_w-lw-dw(p1)-1
if first_avail>0 and dw(p2)>first_avail:
    brk=best_break(p2,first_avail); line1_p2=p2[:brk].rstrip(); rest_p2=p2[brk:].lstrip()
    print(f'1|{p1}\x01 {line1_p2}')
    cont_w=lw+dw(p1)+1; cont_pad=' '*cont_w; remaining=rest_p2
    while remaining:
        brk=best_break(remaining, max_w); chunk=remaining[:brk].rstrip(); remaining=remaining[brk:].lstrip()
        print(f'0|{cont_pad}\x01{chunk}')
else: print(f'1|{p1}\x01 {p2}')
" "$part1" "$part2" "$label_w")
    local first=1
    while IFS='|' read -r flag line; do
        [ -z "$line" ] && continue
        local before="${line%%$'\x01'*}"; local after="${line#*$'\x01'}"
        if [ "$first" = "1" ]; then
            echo -e "${prefix}${VANG}${label_str}${RESET}${color1}${before}${RESET}${color2}${after}${RESET}"; first=0
        else
            echo -e "${prefix}${color2}${before}${after}${RESET}"
        fi
    done <<< "$result"
}

hien_danh_sach() {
    local title="$1" results="$2" dem=0
    echo -e "\n${HONG}${title}${RESET}\n"
    printf "   ${TRANG}%-20s %-15s %s${RESET}\n" "Chữ Hán" "Pinyin" "Nghĩa"
    echo -e "   ${VANG}$(printf '%.0s─' {1..60})${RESET}"
    while IFS= read -r dong; do
        [ -z "$dong" ] && continue
        local han=$(echo "$dong" | cut -d'|' -f1 | xargs)
        local py=$(echo "$dong" | cut -d'|' -f2 | xargs)
        local ng=$(echo "$dong" | cut -d'|' -f3 | xargs)
        printf "   ${TIM}%-20s${RESET} ${TRANG}%-15s${RESET} %s\n" "$han" "$py" "$ng"
        dem=$((dem+1))
    done <<< "$results"
    echo -e "\n   ${VANG}Tổng: ${dem} từ${RESET}"
    echo -e "   ${VANG}Dùng ${TIM}tu <từ>${VANG} để xem chi tiết${RESET}\n"
}

# ===== NGHE PHÁT ÂM =====
cmd_nghe() {
    local tu_nghe="$*"
    # Cắt khoảng trắng đầu/cuối — không dùng xargs (có thể nuốt mất ký tự "-"
    # nếu từ tìm bắt đầu bằng dấu gạch ngang)
    tu_nghe="${tu_nghe#"${tu_nghe%%[! ]*}"}"
    tu_nghe="${tu_nghe%"${tu_nghe##*[! ]}"}"
    [ -z "$tu_nghe" ] && error "❌ Thiếu từ! Dùng: tu nghe 你好 (hoặc: tu nghe Nỉ hảo)" && exit 1
    local dong_cn=$(grep "^${tu_nghe}|" "$CN_DB_FILE" 2>/dev/null | head -1 || true)
    # Dò khớp một phần theo pinyin (cột 2) / phiên âm Việt (cột 5) — dùng index()
    # thay vì toán tử ~ để so khớp CHUỖI THẬT (literal), không diễn giải ký tự
    # người dùng gõ vào (vd ".", "*", "(") thành wildcard của regex. Dùng ~ trực
    # tiếp từng gây lỗi: tìm "shi.4" lại khớp nhầm sang "shiX4" vì "." là wildcard.
    [ -z "$dong_cn" ] && dong_cn=$(awk -F'|' -v q="$tu_nghe" 'BEGIN{q=tolower(q)} index(tolower($2), q) > 0' "$CN_DB_FILE" 2>/dev/null | head -1 || true)
    [ -z "$dong_cn" ] && dong_cn=$(awk -F'|' -v q="$tu_nghe" 'BEGIN{q=tolower(q)} index(tolower($5), q) > 0' "$CN_DB_FILE" 2>/dev/null | head -1 || true)
    if [ -z "$dong_cn" ]; then
        if [ -z "${GROQ_KEY:-}" ]; then
            error "❌ Không tìm thấy '${tu_nghe}' trong DB."
            exit 1
        fi
        echo -e "\n${VANG}🤖 '${tu_nghe}' chưa có trong DB. Đang hỏi AI...${RESET}"
        local p="Cho từ: \"${tu_nghe}\". Trả lời JSON: {\"hanzi\":\"\",\"pronunciation\":\"phiên âm kiểu Việt\"}"
        local pj=$(python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$p" 2>/dev/null) || { error "Lỗi encode."; exit 1; }
        local r=$(curl -s "https://api.groq.com/openai/v1/chat/completions" -H "Authorization: Bearer ${GROQ_KEY}" -H "Content-Type: application/json" -d "{\"model\":\"${GROQ_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":${pj}}],\"max_tokens\":200,\"temperature\":0.2}" 2>/dev/null) || true
        local ha=$(echo "$r" | python3 -c "import json,sys,re; d=json.load(sys.stdin); text=d['choices'][0]['message']['content'].strip(); m=re.search(r'\{[^{}]+\}',text,re.DOTALL); obj=json.loads(m.group()); print(obj.get('hanzi','') or '')" 2>/dev/null) || true
        if [ -n "$ha" ]; then
            echo -e "${XANH}🔊 Đang đọc:${RESET} ${TIM}${ha}${RESET}"
            doc "$ha" "zh" || true
            exit 0
        fi
        error "AI không trả về kết quả."; exit 1
    fi
    local h=$(echo "$dong_cn" | cut -d'|' -f1 | xargs)
    local p=$(echo "$dong_cn" | cut -d'|' -f2 | xargs)
    local n=$(echo "$dong_cn" | cut -d'|' -f3 | xargs)
    echo -e "\n${XANH}🔊 Đang đọc:${RESET} ${TIM}${h}${RESET}  (${VANG}${p}${RESET})  —  ${n}"
    if ! doc "$h" "zh"; then
        warn "   ⚠ Không tìm thấy công cụ đọc. Cài: pip install edge-tts hoặc sudo apt install espeak-ng"
    fi
    echo ""; exit 0
}

# ===== TRA CỨU / THÊM QUA AI =====
cmd_tra_cuu() {
    local tu_tra="$*"
    tu_tra="${tu_tra#"${tu_tra%%[! ]*}"}"
    tu_tra="${tu_tra%"${tu_tra##*[! ]}"}"
    [ -z "$tu_tra" ] && error "❌ Thiếu từ! Dùng: tu 你好" && exit 1
    local dong_cn=$(grep "^${tu_tra}|" "$CN_DB_FILE" 2>/dev/null | head -1 || true)
    [ -z "$dong_cn" ] && dong_cn=$(grep -i "|${tu_tra}|" "$CN_DB_FILE" 2>/dev/null | head -1 || true)
    if [ -n "$dong_cn" ]; then
        echo -e "${XANH}✔ Đã có trong DB:${RESET}"; hien_tu "$dong_cn"; exit 0
    fi
    if [ -z "$GROQ_KEY" ]; then
        error "❌ Chưa có Groq API key!"
        warn "   echo 'GROQ_API_KEY=\"gsk_...\"' >> ~/.hoc_config"; exit 1
    fi
    echo -e "\n${VANG}🤖 '${tu_tra}' chưa có trong DB. Đang hỏi AI...${RESET}"
    local PROMPT="Cho từ: \"${tu_tra}\". Trả lời JSON:
{\"hanzi\":\"${tu_tra}\",\"pinyin\":\"pinyin có dấu\",\"meaning\":\"nghĩa tiếng Việt\",\"example\":\"câu ví dụ (nghĩa TV)\",\"pronunciation\":\"phiên âm kiểu Việt\",\"example_pronunciation\":\"phiên âm câu ví dụ\"}"
    local P_JSON=$(python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$PROMPT" 2>/dev/null) || { error "Lỗi encode."; exit 1; }
    local RESP=$(curl -s "https://api.groq.com/openai/v1/chat/completions" -H "Authorization: Bearer ${GROQ_KEY}" -H "Content-Type: application/json" -d "{\"model\":\"${GROQ_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":${P_JSON}}],\"max_tokens\":500,\"temperature\":0.2}" 2>/dev/null) || true
    local KQ=$(echo "$RESP" | python3 -c "
import json,sys,re
try:
    d=json.load(sys.stdin)
    if 'error' in d: print('ERR:'+d['error'].get('message','?'),file=sys.stderr); sys.exit(1)
    text=d['choices'][0]['message']['content'].strip()
    m=re.search(r'\{[^{}]+\}',text,re.DOTALL)
    obj=json.loads(m.group())
    h=obj.get('hanzi','').strip(); p=obj.get('pinyin','').strip(); m=obj.get('meaning','').strip()
    e=obj.get('example','').strip(); pr=obj.get('pronunciation','').strip(); pe=obj.get('example_pronunciation','').strip()
    if h and p and m: print(f'{h}|{p}|{m}|{e}|{pr}|{pe}')
except: pass
" 2>/dev/null)
    if [ -z "$KQ" ] || [[ "$KQ" != *"|"* ]]; then
        error "❌ AI trả về kết quả không hợp lệ."; exit 1
    fi
    echo -e "${XANH}✔ Kết quả từ AI:${RESET}"; hien_tu "$KQ"
    echo -ne "${VANG}Lưu vào DB? (co/khong): ${RESET}"; read -r xac_nhan
    if [ "$xac_nhan" = "co" ]; then
        echo "$KQ" >> "$CN_DB_FILE"
        echo -e "${XANH}✔ Đã lưu '${tu_tra}' vào DB. Tổng: $(grep -c '.' "$CN_DB_FILE") từ${RESET}"
    else
        echo -e "${VANG}Không lưu.${RESET}"
    fi
    echo ""; exit 0
}

# ===== QUẢN LÝ AI CACHE =====
cmd_cache() {
    case "${1:-xem}" in
        xem)
            if [ ! -f "$AI_CACHE_FILE" ] || [ ! -s "$AI_CACHE_FILE" ]; then
                warn "Cache AI trống."; return
            fi
            echo -e "\n${HONG}🗄️  AI CACHE:${RESET}\n"; local so=1
            while IFS='|' read -r mo_ta ten rest; do
                printf "   ${TIM}%-4s${RESET} ${VANG}%-30s${RESET} → ${XANH}%s${RESET}\n" "${so}." "$mo_ta" "$ten"; so=$((so+1))
            done < "$AI_CACHE_FILE"; echo "" ;;
        xoa) : > "$AI_CACHE_FILE"; info "✔ Đã xóa cache." ;;
    esac
}

# ===== ĐIỀU PHỐI =====
case "${1:-}" in
    ""|"--help"|"-h")
        TONG=$(grep -c '.' "$CN_DB_FILE" 2>/dev/null || echo 0)
        echo -e "\n${TIM}╔════════════════════════════════════════════════════╗${RESET}"
        echo -e "${TIM}║         🀄  TU — Tra cứu từ tiếng Trung            ║${RESET}"
        echo -e "${TIM}╚════════════════════════════════════════════════════╝${RESET}\n"
        echo -e "   ${VANG}DB:${RESET} $CN_DB_FILE ${VANG}(${TONG} từ)${RESET}\n"
        echo -e "${XANH}Cách dùng:${RESET}"
        printf "   ${TIM}%-30s${RESET} %s\n" "tu <từ>"             "Tra cứu — gõ chữ Hán hoặc phiên âm Việt đều được"
        printf "   ${TIM}%-30s${RESET} %s\n" "tu nghe <từ>"        "🔊 Nghe phát âm — gõ chữ Hán hoặc phiên âm Việt đều được"
        printf "   ${TIM}%-30s${RESET} %s\n" "tu --list"            "Xem danh sách từ"
        printf "   ${TIM}%-30s${RESET} %s\n" "tu --cache [xoa]"     "Xem/xóa AI cache"
        echo ""; exit 0 ;;
    "nghe"|"--nghe"|"--speak")
        shift; cmd_nghe "$@" ;;
    "--list"|"-l")
        kq=$(grep -v '^\s*$' "$CN_DB_FILE" 2>/dev/null || true)
        hien_danh_sach "📋 Danh sách từ:" "$kq"; exit 0 ;;
    "--cache")
        cmd_cache "${2:-xem}"; exit 0 ;;
    *)
        cmd_tra_cuu "$@" ;;
esac
