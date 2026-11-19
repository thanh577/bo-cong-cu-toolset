#!/usr/bin/env bash
# toolset — Liệt kê tất cả công cụ trong bộ toolset

# Mới - không emoji trong khung, thẳng tắp:
echo -e "\e[1;36m╔══════════════════════════════════════════════╗\e[0m"
echo -e "\e[1;36m║              BỘ CÔNG CỤ TOOLSET              ║\e[0m"
echo -e "\e[1;36m╚══════════════════════════════════════════════╝\e[0m"
echo ""

hien() {
    if command -v "$1" &>/dev/null; then
        echo -e "$2"
    else
        echo -e "  \e[1;31m✗ $1\e[0m — chưa cài, chạy bash cai-dat.sh để cài"
    fi
}

hien hoc "  \e[1;33mhoc <lệnh>\e[0m          Học 1 lệnh Linux, vd: \e[0;37mhoc ls\e[0m"
hien hoc-linux "  \e[1;33mhoc-linux quiz\e[0m     Trắc nghiệm Linux"
if command -v tu &>/dev/null; then
    echo -e "  \e[1;33mtu <từ>\e[0m            Học tiếng Trung, vd: \e[0;37mtu 你好\e[0m"
    echo -e "  \e[1;33mtu nghe <từ>\e[0m       Nghe phát âm"
else
    echo -e "  \e[1;31m✗ tu\e[0m — chưa cài, chạy bash cai-dat.sh để cài"
fi
hien donrac "  \e[1;33mdonrac\e[0m             Dọn rác máy tính"
hien pin "  \e[1;33mpin\e[0m                Xem pin + Bluetooth"
hien thoi-tiet "  \e[1;33mthoi-tiet [thành phố]\e[0m Xem thời tiết, vd: \e[0;37mthoi-tiet \"Hà Nội\"\e[0m"
echo ""
echo -e "  \e[0;37mGõ \e[1;33m<tên lệnh> --help\e[0m để xem thêm, vd: \e[1;33mhoc --help\e[0m\e[0m"
echo -e "  \e[0;37mMuốn gỡ bớt? Chạy: \e[1;33mbash cai-dat.sh --go-cai-dat\e[0m"