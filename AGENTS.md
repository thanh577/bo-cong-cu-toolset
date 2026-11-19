# AGENTS.md

## What this repo is

**Bộ công cụ BBI-TEK** — gộp 3 nhóm công cụ Vietnamese-language độc lập cho việc
onboarding Windows→Ubuntu, cài đặt qua **một trình cài đặt duy nhất** (`cai-dat.sh`)
với menu chọn lọc. Không build system, không test, không CI.

## Kiến trúc

```
cai-dat.sh          ← trình cài đặt gộp (menu 1-5/0 + cờ --thu-vien/--hoc-linux/--hoc-trung/--may-tinh/--tat-ca)
requirements.txt     ← gói pip cho tính năng phát âm (edge-tts, gTTS) — cài KHÔNG dùng venv
hoc-linux/           ← Nhóm: Mỗi ngày một lệnh Linux
  hoc-lenh.sh         (cài thành lệnh `hoc`)
  hoc-linux.sh        (cài thành lệnh `hoc-linux`)
  lib.sh
  lenh_linux_db.txt
hoc-trung/           ← Nhóm: Học từ mới tiếng Trung
  tu.sh               (cài thành lệnh `tu`)
  lib.sh
  tiengtrung_db.txt
may-tinh/            ← Nhóm: Công cụ cho máy tính của bạn
  don-rac.sh          (cài thành lệnh `donrac`)
  giam-sat-pin.sh     (cài thành lệnh `pin`)
  lib.sh
```

Menu cài đặt trong `cai-dat.sh` có 4 nhóm hiển thị theo thứ tự:
`1) thu-vien` (gói apt/pip nền tảng) → `2) hoc-linux` → `3) hoc-trung` → `4) may-tinh`
→ `5) cài tất cả`. "Thu-vien" không tương ứng 1 thư mục riêng — nó là hàm
`cai_thu_vien()` cài gói apt (`python3`, `python3-pip`, `curl`, `bc`, `bluez`,
`upower`, `espeak-ng`) và chạy `pip install -r requirements.txt --break-system-packages`
(không venv, vì đây là máy cá nhân/nội bộ dùng riêng cho bộ công cụ này).

3 nhóm còn lại **độc lập hoàn toàn về mặt cài đặt** — có thể cài 1, vài hay cả 3
mà không phụ thuộc lẫn nhau. Mỗi nhóm tự mang bản sao `lib.sh` riêng (chấp nhận
trùng lặp code nhỏ) để gỡ cài đặt nhóm này không ảnh hưởng nhóm khác. Nhóm
"thu-vien" là ngoại lệ duy nhất được các nhóm kia phụ thuộc (cần `python3`/`curl`
để chạy), nên nên cài trước — nhưng `cai-dat.sh` không ép buộc thứ tự, chỉ khuyến
nghị qua UI ("Máy mới nên chọn mục 1 trước tiên").

## Đích cài đặt trên hệ thống

| Nhóm | Thư mục cài | Lệnh | Symlink |
|---|---|---|---|
| hoc-linux | `/opt/lenh-linux/scripts/` | `hoc`, `hoc-linux` | `/usr/local/bin/{hoc,hoc-linux}` |
| may-tinh  | `/opt/lenh-linux/scripts/` | `donrac`, `pin` | `/usr/local/bin/{donrac,pin}` |
| hoc-trung | `/opt/hoc-trung/scripts/` + `/opt/hoc-trung/data/` | `tu` | `/usr/local/bin/tu` |

`hoc-linux` và `may-tinh` dùng chung thư mục cài `/opt/lenh-linux` (vì cùng chủ đề
"onboarding Ubuntu"), nhưng vẫn cài/gỡ độc lập theo lựa chọn menu.

### File dữ liệu người dùng (tạo lúc chạy, trong `$HOME`)

- `~/.lenh_linux_db.txt` — bản cài của DB lệnh Linux
- `~/.tiengtrung_db.txt` — bản cài của DB tiếng Trung
- `~/.hoclinux_favorites`, `~/.hoclinux_history`, `~/.hoclinux_difficulty`, `~/.hoclinux_streak` — trạng thái học tập (hoc-linux)
- `~/.hoc_ai_cache.txt` — cache kết quả Groq AI (dùng chung bởi `hoc --ai` và `tu`)
- `~/.hoc_config` — chứa `GROQ_API_KEY` (dùng chung bởi `hoc --ai` và `tu`)
- `~/.donrac_history` — nhật ký dọn dẹp

## Cách chạy trực tiếp (trước khi cài)

```bash
bash hoc-linux/hoc-lenh.sh ls                   # tra cứu lệnh
bash hoc-linux/hoc-lenh.sh --mo-ta "nén file"   # tìm theo mô tả
bash hoc-linux/hoc-lenh.sh --ai "xóa file log"  # tìm bằng AI
bash hoc-linux/hoc-linux.sh quiz 5              # quiz 5 câu
bash hoc-trung/tu.sh 你好                        # tra từ tiếng Trung
bash may-tinh/don-rac.sh                        # dọn dẹp hệ thống
bash may-tinh/giam-sat-pin.sh                   # xem pin
```

### Sau khi cài

Lệnh có sẵn tùy nhóm đã chọn: `hoc`, `hoc-linux`, `tu`, `donrac`, `pin`.

## Quy ước style

- UI text hoàn toàn bằng **tiếng Việt**
- Tên biến/hàm dùng snake_case tiếng Việt (vd `lay_dung_luong_da_dung_bytes`)
- Màu định nghĩa trong `lib.sh`: `XANH` (xanh lá), `DO` (đỏ), `VANG` (vàng), `TIM` (cyan), `HONG` (magenta), `TRANG` (trắng)
- Khung viền Unicode: `╔══╗║╚══╝`
- Xác nhận theo mẫu `"co/khong"` (không dùng y/n)
- Mỗi bashrc block dùng marker riêng để idempotent + gỡ sạch:
  `# >>> <tên> bashrc block >>>` ... `# <<< <tên> bashrc block <<<`

## Lưu ý kỹ thuật quan trọng (đã từng là bug, đừng lặp lại)

- **Không dùng `xargs` để trim chuỗi có thể bắt đầu bằng dấu `-`** (vd cột "options"
  trong `lenh_linux_db.txt`, có dòng bắt đầu bằng `-n`/`-e`). Khi không truyền lệnh,
  `xargs` mặc định gọi `echo`, và `echo -n`/`echo -e` sẽ nuốt mất chính flag đó khỏi
  output. Dùng parameter-expansion trim thủ công thay thế (xem `them_bashrc_block`
  trong `cai-dat.sh` hoặc `hien_lenh()` trong `hoc-lenh.sh`).
- **Luôn tính `SCRIPT_DIR`/đường dẫn dự phòng DB từ `SELF_DIR` đã resolve symlink**
  (`dirname "$(readlink -f "${BASH_SOURCE[0]}")"`), không phải từ `BASH_SOURCE[0]`
  trực tiếp — vì sau khi cài, lệnh chạy qua symlink ở `/usr/local/bin`, và
  `dirname` không tự resolve symlink.
- **`local` chỉ dùng được bên trong hàm.** Nếu thêm nhánh mới vào `case` điều phối
  ở top-level của script, không dùng `local` cho biến tạm ở đó — dùng biến thường.
- `set -euo pipefail` dùng trong `hoc-lenh.sh`, `hoc-linux.sh`, `tu.sh`, `cai-dat.sh`
  — `don-rac.sh` và `giam-sat-pin.sh` cố tình không dùng (có nhiều lệnh được phép lỗi).
- Biến môi trường ghi đè: `HOC_DB`, `DB_FILE` (DB Linux); `HOC_CN_DB` (DB tiếng Trung).
- **Cài pip không dùng venv, không giả định `--break-system-packages` luôn có.**
  Ubuntu 23.04+/24.04 chặn `pip install` hệ thống theo PEP 668, cần cờ này; bản
  pip cũ hơn (một số Debian/Ubuntu cũ) không hiểu cờ và sẽ báo lỗi "unrecognized
  argument". `cai_thu_vien()` trong `cai-dat.sh` thử có cờ trước, không được thì
  thử lại không cờ — giữ nguyên pattern này nếu sửa lại phần cài pip.
- **`doc()` trong `lib.sh` (TTS) không được coi edge-tts/gtts-cli "thành công"
  chỉ vì lệnh chạy xong không lỗi.** Cả hai đều gọi API qua mạng; nếu mất mạng,
  lệnh vẫn thoát mã 0 nhưng để lại file mp3 rỗng (vì output bị redirect vào
  `/dev/null` nên không thấy lỗi). Tương tự, nếu sinh file thành công nhưng máy
  không có `mpv`/`ffplay`/`aplay`/`paplay` nào, không có gì phát ra loa cả. Từng
  có bug thật: người dùng thấy dòng "Đang đọc: ..." nhưng hoàn toàn im lặng, vì
  cả hai trường hợp trên đều bị coi là thành công (`return 0` vô điều kiện). Sửa
  bằng cách kiểm tra `[ -s "$file" ]` trước khi phát VÀ kiểm tra `_phat_file` có
  tìm được trình phát không — nếu một trong hai thất bại, phải rơi xuống thử
  phương án kế (`espeak-ng` → `espeak`) thay vì trả về thành công giả. Giữ
  nguyên `mpv` trong `GOI_HE_THONG_CAN` để luôn có ít nhất 1 trình phát khả dụng.
