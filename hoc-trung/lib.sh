#!/usr/bin/env bash
# ============================================================
#  LIB.SH — Thư viện chung cho bộ công cụ học Linux
#  Source file này ở đầu mỗi script:
#    source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# ============================================================

# ===== MÀU SẮC =====
# shellcheck disable=SC2034  # Các biến màu được dùng bởi script khác qua source
if [ -t 1 ] && [ "${TERM:-}" != "dumb" ]; then
    XANH='\e[1;32m'
    DO='\e[1;31m'
    VANG='\e[1;33m'
    TIM='\e[1;36m'
    HONG='\e[1;35m'
    TRANG='\e[1;37m'
    CAM='\e[38;5;208m'
    RESET='\e[0m'
else
    XANH=''; DO=''; VANG=''; TIM=''; HONG=''; TRANG=''; CAM=''; RESET=''
fi

# ===== HÀM LOG =====
info()    { echo -e "${XANH}$*${RESET}"; }
warn()    { echo -e "${VANG}$*${RESET}"; }
error()   { echo -e "${DO}$*${RESET}"; }
thanh()   { echo -e "${TIM}$*${RESET}"; }   # tiêu đề/khung

# ===== IN HEADER =====
in_header() {
    local tieu_de="$1"
    echo -e "\n${TIM}╔════════════════════════════════════════════════════╗${RESET}"
    printf "${TIM}║${RESET}  %-50s${TIM}║${RESET}\n" "$tieu_de"
    echo -e "${TIM}╚════════════════════════════════════════════════════╝${RESET}\n"
}

# ===== KIỂM TRA LỆNH TỒN TẠI =====
kiem_tra_lenh() {
    local lenh="$1"
    command -v "$lenh" >/dev/null 2>&1
}

# ===== KIỂM TRA NHIỀU LỆNH =====
kiem_tra_cac_lenh() {
    local thieu=0
    for cmd in "$@"; do
        if ! kiem_tra_lenh "$cmd"; then
            error "❌ Thiếu lệnh '$cmd' — hãy cài trước khi chạy."
            thieu=1
        fi
    done
    [ "$thieu" -eq 1 ] && return 1
    return 0
}

# ===== TEXT-TO-SPEECH (đọc thành tiếng) =====
doc() {
    local text="$1" lang="${2:-zh}"

    [ -z "$text" ] && return 0

    # Helper: phát file audio với trình phát có sẵn.
    # Trả về 0 nếu tìm được trình phát và đã gọi nó, 1 nếu không có trình phát
    # nào cài sẵn (mpv/ffplay/aplay/paplay) — quan trọng: nếu không check giá
    # trị trả về này, edge-tts/gtts-cli sẽ "thành công" giả (sinh file mp3 xong
    # nhưng không ai phát ra loa cả) mà không báo lỗi gì.
    _phat_file() {
        local file="$1"
        if kiem_tra_lenh "mpv"; then
            mpv --really-quiet "$file" &>/dev/null &
        elif kiem_tra_lenh "ffplay"; then
            ffplay -nodisp -autoexit "$file" &>/dev/null &
        elif kiem_tra_lenh "aplay"; then
            aplay "$file" &>/dev/null &
        elif kiem_tra_lenh "paplay"; then
            paplay "$file" &>/dev/null &
        else
            return 1
        fi
        return 0
    }

    # edge-tts/gtts-cli cần mạng để gọi API — nếu mất mạng hoặc API lỗi, lệnh
    # vẫn "chạy xong" nhưng để lại file mp3 rỗng (vì output bị chuyển hướng vào
    # /dev/null nên không thấy lỗi). Kiểm tra file có dữ liệu thật trước khi coi
    # là thành công, nếu không thì rơi xuống thử phương án kế tiếp thay vì báo
    # thành công giả.
    _file_hop_le() { [ -s "$1" ]; }

    # 1. edge-tts (Microsoft neural) — tự nhiên nhất, cần mạng
    if kiem_tra_lenh "edge-tts"; then
        local giong
        case "$lang" in
            vi) giong="vi-VN-HoaiMyNeural" ;;
            zh) giong="zh-CN-XiaoxiaoNeural" ;;
            *)  giong="zh-CN-XiaoxiaoNeural" ;;
        esac
        local out; out=$(mktemp /tmp/doc_XXXXXX.mp3 2>/dev/null)
        edge-tts --voice "$giong" --text "$text" --write-media "$out" &>/dev/null
        if _file_hop_le "$out" && _phat_file "$out"; then
            return 0
        fi
        rm -f "$out" 2>/dev/null
        # Không return ở đây — rơi xuống thử gtts-cli / espeak-ng / espeak
    fi

    # 2. gtts-cli (Google TTS) — cần mạng
    if kiem_tra_lenh "gtts-cli"; then
        local glang
        case "$lang" in
            vi) glang="vi" ;;
            zh) glang="zh-CN" ;;
            *)  glang="zh-CN" ;;
        esac
        local out; out=$(mktemp /tmp/doc_XXXXXX.mp3 2>/dev/null)
        gtts-cli --lang "$glang" "$text" --output "$out" &>/dev/null
        if _file_hop_le "$out" && _phat_file "$out"; then
            return 0
        fi
        rm -f "$out" 2>/dev/null
    fi

    # 3. espeak-ng — offline, giọng robot, tự phát ra loa, không cần trình phát riêng
    if kiem_tra_lenh "espeak-ng"; then
        espeak-ng -v "$lang" "$text" &>/dev/null &
        return 0
    fi

    # 4. espeak — fallback cuối
    if kiem_tra_lenh "espeak"; then
        espeak "$text" &>/dev/null &
        return 0
    fi

    return 1
}

# ===== ĐƯỜNG DẪN SCRIPT =====
# Dùng để tìm file DB cùng thư mục với script
lay_script_dir() {
    cd "$(dirname "${BASH_SOURCE[1]}")" && pwd
}
