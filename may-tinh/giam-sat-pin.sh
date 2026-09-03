#!/usr/bin/env bash
# shellcheck source=lib.sh
SELF_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$SELF_DIR/lib.sh"
# ============================================================
#  GIÁM SÁT PIN - Xem trạng thái, sức khoẻ và thời gian pin
#  Phiên bản: 2.0
# ============================================================


echo -e "\n${TIM}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${TIM}║            🔋  GIÁM SÁT PIN HỆ THỐNG               ║${RESET}"
echo -e "${TIM}╚════════════════════════════════════════════════════╝${RESET}\n"

# ===== TÌM PIN (BAT0 hoặc BAT1) =====
THU_MUC_PIN=""
for pin in BAT0 BAT1 BAT2; do
    if [ -d "/sys/class/power_supply/$pin" ]; then
        THU_MUC_PIN="/sys/class/power_supply/$pin"
        TEN_PIN="$pin"
        break
    fi
done

# ===== MÁY BÀN / KHÔNG CÓ PIN =====
if [ -z "$THU_MUC_PIN" ]; then
    echo -e " 🖥️  ${VANG}Máy bàn hoặc không phát hiện được pin${RESET}"
    echo -e "\n ${TIM}Thông tin nguồn điện:${RESET}"

    # Xem adapter AC
    for ac in AC ADP0 ACAD; do
        if [ -f "/sys/class/power_supply/$ac/online" ]; then
            DANG_CAM=$(cat "/sys/class/power_supply/$ac/online" 2>/dev/null)
            if [ "$DANG_CAM" = "1" ]; then
                echo -e "   ⚡ Đang cắm điện lưới: ${XANH}Có${RESET}"
            else
                echo -e "   ⚡ Đang cắm điện lưới: ${DO}Không${RESET}"
            fi
            break
        fi
    done
    echo -e "\n${VANG}════════════════════════════════════════════════════════${RESET}\n"
    exit 0
fi

# ===== ĐỌC THÔNG SỐ PIN =====
MUC_PIN=$(cat "$THU_MUC_PIN/capacity" 2>/dev/null || echo "?")
TRANG_THAI=$(cat "$THU_MUC_PIN/status" 2>/dev/null || echo "Không rõ")

# Dịch trạng thái sang tiếng Việt
case "$TRANG_THAI" in
    "Charging")    TRANG_THAI_VI="Đang sạc" ;    BIEU_TUONG="⚡" ;;
    "Discharging") TRANG_THAI_VI="Đang dùng pin"; BIEU_TUONG="🔋" ;;
    "Full")        TRANG_THAI_VI="Đã đầy" ;       BIEU_TUONG="✅" ;;
    "Not charging")TRANG_THAI_VI="Cắm nhưng không sạc"; BIEU_TUONG="🔌" ;;
    *)             TRANG_THAI_VI="$TRANG_THAI" ;  BIEU_TUONG="❓" ;;
esac

# ===== MÀU THEO MỨC PIN =====
if [ "$MUC_PIN" != "?" ]; then
    if [ "$MUC_PIN" -ge 60 ]; then
        MAU_PIN=$XANH
    elif [ "$MUC_PIN" -ge 25 ]; then
        MAU_PIN=$VANG
    else
        MAU_PIN=$DO
    fi
else
    MAU_PIN=$RESET
fi

# ===== THANH TIẾN TRÌNH PIN =====
ve_thanh_pin() {
    local phan_tram=$1
    local do_dai=30
    local da_dien=$(( (phan_tram * do_dai) / 100 ))
    local chua_dien=$(( do_dai - da_dien ))
    local nhan="${phan_tram}%"

    # Màu theo mức pin
    local MAU_THANH
    if [ "$phan_tram" -ge 70 ]; then
        MAU_THANH='\e[1;32m'     # Xanh lá
    elif [ "$phan_tram" -ge 40 ]; then
        MAU_THANH='\e[1;33m'     # Vàng
    elif [ "$phan_tram" -ge 25 ]; then
        MAU_THANH='\e[38;5;208m' # Cam
    else
        MAU_THANH='\e[1;31m'     # Đỏ
    fi

    # Tạo chuỗi thanh bằng ký tự ASCII
    local phan_day; phan_day=$(printf '%0.s#' $(seq 1 $da_dien) 2>/dev/null || printf "%${da_dien}s" | tr ' ' '#')
    local phan_trong; phan_trong=$(printf "%${chua_dien}s" | tr ' ' '-')

    # Chèn % vào giữa
    local bar="${phan_day}${phan_trong}"
    local vi_tri=$(( do_dai / 2 - ${#nhan} / 2 ))
    local bar_voi_nhan="${bar:0:$vi_tri}${nhan}${bar:$((vi_tri + ${#nhan}))}"

    echo -e "${MAU_THANH}[${bar_voi_nhan}]\e[0m"
}

echo -e " 💻 ${XANH}LAPTOP${RESET} — $TEN_PIN\n"
echo -e "   $BIEU_TUONG Trạng thái  : ${MAU_PIN}${TRANG_THAI_VI}${RESET}"

if [ "$MUC_PIN" != "?" ]; then
    echo -ne "   🔋 Mức pin    : "
    ve_thanh_pin "$MUC_PIN"
else
    echo -e "   🔋 Mức pin    : ${VANG}Không đọc được${RESET}"
fi

# ===== SỨC KHOẺ PIN =====
NANG_LUONG_HIEN_TAI=$(cat "$THU_MUC_PIN/energy_full" 2>/dev/null || cat "$THU_MUC_PIN/charge_full" 2>/dev/null)
NANG_LUONG_BAN_DAU=$(cat "$THU_MUC_PIN/energy_full_design" 2>/dev/null || cat "$THU_MUC_PIN/charge_full_design" 2>/dev/null)

if [ -n "$NANG_LUONG_HIEN_TAI" ] && [ -n "$NANG_LUONG_BAN_DAU" ] && [ "$NANG_LUONG_BAN_DAU" -gt 0 ]; then
    SUC_KHOE=$(( (NANG_LUONG_HIEN_TAI * 100) / NANG_LUONG_BAN_DAU ))
    if [ "$SUC_KHOE" -ge 80 ]; then
        MAU_SK=$XANH; NHAN_SK="Tốt"
    elif [ "$SUC_KHOE" -ge 50 ]; then
        MAU_SK=$VANG; NHAN_SK="Trung bình"
    else
        MAU_SK=$DO; NHAN_SK="Yếu — nên thay pin"
    fi
    echo -e "   🩺 Sức khoẻ   : ${MAU_SK}${SUC_KHOE}% (${NHAN_SK})${RESET}"
fi

# ===== THỜI GIAN CÒN LẠI =====
if command -v upower &>/dev/null; then
    THOI_GIAN=$(upower -i "$(upower -e | grep -i bat | head -1)" 2>/dev/null | grep "time to" | awk '{print $4, $5}')
    if [ -n "$THOI_GIAN" ]; then
        if echo "$TRANG_THAI" | grep -q "Discharging"; then
            echo -e "   ⏱️  Còn dùng được: ${TIM}${THOI_GIAN}${RESET}"
        elif echo "$TRANG_THAI" | grep -q "Charging"; then
            echo -e "   ⏱️  Sạc đầy sau  : ${TIM}${THOI_GIAN}${RESET}"
        fi
    fi
fi

# ===== NHIỆT ĐỘ (NẾU CÓ) =====
NHIET_DO_FILE=$(find /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -1)
if [ -n "$NHIET_DO_FILE" ]; then
    NHIET_DO_RAW=$(cat "$NHIET_DO_FILE" 2>/dev/null)
    if [ -n "$NHIET_DO_RAW" ]; then
        NHIET_DO=$(( NHIET_DO_RAW / 1000 ))
        if [ "$NHIET_DO" -ge 70 ]; then
            MAU_ND=$DO
        elif [ "$NHIET_DO" -ge 50 ]; then
            MAU_ND=$VANG
        else
            MAU_ND=$XANH
        fi
        echo -e "   🌡️  Nhiệt độ    : ${MAU_ND}${NHIET_DO}°C${RESET}"
    fi
fi

# ===== CẢNH BÁO PIN YẾU =====
if [ "$MUC_PIN" != "?" ] && [ "$MUC_PIN" -le 15 ] && [ "$TRANG_THAI" = "Discharging" ]; then
    echo -e "\n   ${DO}⚠️  CẢNH BÁO: Pin yếu! Hãy cắm sạc ngay.${RESET}"
fi

# ===== THIẾT BỊ BLUETOOTH =====
echo -e "\n${TIM}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${TIM}║         📡  THIẾT BỊ BLUETOOTH KẾT NỐI            ║${RESET}"
echo -e "${TIM}╚════════════════════════════════════════════════════╝${RESET}"

if ! command -v bluetoothctl &>/dev/null; then
    echo -e "\n   ${VANG}⚠ Không tìm thấy bluetoothctl. Cài bằng:${RESET}"
    echo -e "   ${TIM}sudo apt install bluez${RESET}\n"
else
    # Kiểm tra bluetooth có bật không
    BT_POWER=$(bluetoothctl show 2>/dev/null | grep "Powered:" | awk '{print $2}')

    if [ "$BT_POWER" != "yes" ]; then
        echo -e "\n   ${VANG}📴 Bluetooth đang tắt.${RESET}"
        echo -e "   Bật bằng lệnh: ${TIM}bluetoothctl power on${RESET}\n"
    else
        # Lấy danh sách thiết bị đang kết nối
        # Dùng 2 cách: devices Connected (mới) hoặc lọc từ devices (cũ)
        DANH_SACH=$(bluetoothctl devices Connected 2>/dev/null)
        if [ -z "$DANH_SACH" ]; then
            # Fallback: lấy tất cả devices rồi kiểm tra từng cái
            DANH_SACH_TAT_CA=$(bluetoothctl devices 2>/dev/null)
            DANH_SACH=""
            while IFS= read -r dong; do
                [ -z "$dong" ] && continue
                DIA_CHI_TMP=$(echo "$dong" | awk '{print $2}')
                KIEM_TRA=$(bluetoothctl info "$DIA_CHI_TMP" 2>/dev/null | grep "Connected: yes")
                [ -n "$KIEM_TRA" ] && DANH_SACH+="$dong"$'\n'
            done <<< "$DANH_SACH_TAT_CA"
        fi

        if [ -z "$DANH_SACH" ]; then
            echo -e "\n   ${VANG}Không có thiết bị nào đang kết nối.${RESET}\n"
        else
            echo ""
            DEM=0
            while IFS= read -r dong; do
                [ -z "$dong" ] && continue
                DIA_CHI=$(echo "$dong" | awk '{print $2}')
                TEN=$(echo "$dong" | cut -d' ' -f3-)

                # Lấy thông tin chi tiết thiết bị
                THONG_TIN=$(bluetoothctl info "$DIA_CHI" 2>/dev/null)
                LOAI=$(echo "$THONG_TIN" | grep "Icon:" | awk '{print $2}')
                PIN_BT=$(echo "$THONG_TIN" | grep "Battery Percentage" | grep -oP '\d+(?=\))')

                # Biểu tượng theo loại thiết bị
                case "$LOAI" in
                    input-keyboard)   BIEU_TUONG="⌨️ " ; LOAI_VI="Bàn phím"  ;;
                    input-mouse)      BIEU_TUONG="🖱️ " ; LOAI_VI="Chuột"     ;;
                    audio-headset|\
                    audio-headphones) BIEU_TUONG="🎧" ; LOAI_VI="Tai nghe"   ;;
                    audio-card)       BIEU_TUONG="🔊" ; LOAI_VI="Loa"        ;;
                    phone)            BIEU_TUONG="📱" ; LOAI_VI="Điện thoại" ;;
                    *)                BIEU_TUONG="📶" ; LOAI_VI="Thiết bị"   ;;
                esac

                DEM=$((DEM + 1))
                echo -e "   ${BIEU_TUONG} ${XANH}${TEN}${RESET}"
                echo -e "      Loại      : ${LOAI_VI}"
                echo -e "      Địa chỉ   : ${VANG}${DIA_CHI}${RESET}"

                # Hiển thị pin thiết bị nếu có
                if [ -n "$PIN_BT" ]; then
                    if [ "$PIN_BT" -ge 60 ]; then
                        MAU_BT=$XANH
                    elif [ "$PIN_BT" -ge 25 ]; then
                        MAU_BT=$VANG
                    else
                        MAU_BT=$DO
                    fi
                    echo -e "      Pin thiết bị: ${MAU_BT}${PIN_BT}%${RESET}"
                    if [ "$PIN_BT" -le 15 ]; then
                        echo -e "      ${DO}⚠ Pin thiết bị yếu, hãy sạc!${RESET}"
                    fi
                fi
                echo ""
            done <<< "$DANH_SACH"
            echo -e "   📊 Tổng số thiết bị kết nối: ${XANH}${DEM}${RESET}"
            echo ""
        fi
    fi
fi

echo -e "${VANG}════════════════════════════════════════════════════════${RESET}\n"
