#!/usr/bin/env bash
set -euo pipefail
# ============================================================
#  BOOTSTRAP CÀI ĐẶT 1 LỆNH — tải gói toolset từ internet rồi
#  gọi cai-dat.sh bên trong. Dùng sau khi đã push repo lên GitHub.
#
#  Máy mới chỉ cần:
#    curl -fsSL https://raw.githubusercontent.com/<USER>/<REPO>/main/install.sh | bash -s -- --tat-ca
# ============================================================

# TODO: sửa 2 dòng này theo GitHub thật của bạn sau khi push
GITHUB_USER="thanh577"
GITHUB_REPO="bo-cong-cu-toolset"
NHANH="main"

URL_ZIP="https://github.com/${GITHUB_USER}/${GITHUB_REPO}/archive/refs/heads/${NHANH}.zip"

kiem_tra_lenh() {
    if ! command -v "$1" &>/dev/null; then
        echo "❌ Thiếu lệnh '$1'. Cài trước: sudo apt install -y $1"
        exit 1
    fi
}

kiem_tra_lenh curl
kiem_tra_lenh unzip

THU_MUC_TAM="$(mktemp -d)"
trap 'rm -rf "$THU_MUC_TAM"' EXIT

echo "⏳ Đang tải bộ công cụ từ $URL_ZIP ..."
curl -fsSL -o "$THU_MUC_TAM/toolset.zip" "$URL_ZIP"

unzip -q -o "$THU_MUC_TAM/toolset.zip" -d "$THU_MUC_TAM"

# Tìm thư mục vừa bung (bo-cong-cu-toolset-main/...)
THU_MUC_GOI="$(find "$THU_MUC_TAM" -maxdepth 1 -type d -name "${GITHUB_REPO}*" | head -n 1)"
if [ -z "${THU_MUC_GOI:-}" ] || [ ! -f "$THU_MUC_GOI/cai-dat.sh" ]; then
    echo "❌ Không tìm thấy cai-dat.sh trong gói tải về."
    exit 1
fi

echo "🚀 Đang chạy cài đặt ..."
bash "$THU_MUC_GOI/cai-dat.sh" "$@"
