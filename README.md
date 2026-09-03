# 📦 Bộ công cụ BBI-TEK

Bộ công cụ tiếng Việt cho người mới chuyển Windows → Ubuntu: học lệnh Linux mỗi ngày, học từ mới tiếng Trung, dọn rác và giám sát pin. Cài chọn lọc qua **một trình cài đặt duy nhất**.

| # | Nhóm | Lệnh sau khi cài | Mô tả |
|---|------|------------------|-------|
| 1 | Các thư viện cần thiết | — | Gói apt + pip nền tảng (nên cài trước trên máy mới) |
| 2 | Mỗi ngày một lệnh Linux | `hoc`, `hoc-linux` | Tra cứu + học lệnh Linux (quiz, flashcard…) |
| 3 | Học từ mới tiếng Trung | `tu` | Tra từ vựng + nghe phát âm |
| 4 | Công cụ cho máy tính | `donrac`, `pin` | Dọn dẹp hệ thống + giám sát pin |

Chi tiết cách dùng từng lệnh: xem [HUONG_DAN.md](HUONG_DAN.md).

---

## 🚀 Cài đặt 1 lệnh (máy mới)

```bash
curl -fsSL https://raw.githubusercontent.com/thanh577/bo-cong-cu-toolset/main/install.sh | bash -s -- --tat-ca
```

Cài chọn lọc thì đổi đuôi:

```bash
curl -fsSL https://raw.githubusercontent.com/thanh577/bo-cong-cu-toolset/main/install.sh | bash -s -- --thu-vien
curl -fsSL https://raw.githubusercontent.com/thanh577/bo-cong-cu-toolset/main/install.sh | bash -s -- --hoc-linux
curl -fsSL https://raw.githubusercontent.com/thanh577/bo-cong-cu-toolset/main/install.sh | bash -s -- --hoc-trung
curl -fsSL https://raw.githubusercontent.com/thanh577/bo-cong-cu-toolset/main/install.sh | bash -s -- --may-tinh
```

## 🛠️ Cài thủ công (tải zip / clone)

```bash
git clone https://github.com/thanh577/bo-cong-cu-toolset.git
cd bo-cong-cu-toolset
bash cai-dat.sh            # mở menu chọn 1-5/0
bash cai-dat.sh --tat-ca   # cài tất cả, không hỏi (cho script/CI)
```

Các cờ khác:

```bash
bash cai-dat.sh --thu-vien    # chỉ cài thư viện (apt + pip)
bash cai-dat.sh --hoc-linux   # chỉ cài hoc, hoc-linux
bash cai-dat.sh --hoc-trung   # chỉ cài tu
bash cai-dat.sh --may-tinh    # chỉ cài donrac, pin
bash cai-dat.sh --go-cai-dat  # gỡ cài đặt (menu chọn)
bash cai-dat.sh --kiem-tra    # kiểm tra trạng thái
```

Sau khi cài, **mở terminal mới** (hoặc `source ~/.bashrc`) để áp dụng.

---

## ⚙️ Yêu cầu hệ thống

- Ubuntu 20.04 / 22.04 / 24.04 hoặc Debian tương đương
- Bash 4.0+, quyền `sudo`
- Có mạng (để `apt`, `pip` và tải gói từ GitHub)

Mục 1 (thư viện) sẽ tự cài nếu thiếu — không cần cài tay:

- apt: `python3`, `python3-pip`, `curl`, `bc`, `bluez`, `upower`, `espeak-ng`, `mpv`
- pip (từ `requirements.txt`, không dùng venv): `edge-tts`, `gTTS`

Máy mới nên cài mục 1 trước tiên vì các nhóm 2–4 đều cần `python3`/`curl`.

---

## 🤖 Groq AI (tùy chọn, dùng chung cho `hoc --ai` và `tu`)

1. Vào https://console.groq.com tạo API key miễn phí (bắt đầu bằng `gsk_`)
2. Lưu key:
   ```bash
   echo 'GROQ_API_KEY="gsk_cua_ban"' >> ~/.hoc_config
   ```
3. Dùng thử: `hoc --ai "xóa file log lớn hơn 100MB"` hoặc `tu 你好`

Không cần cài thêm gì — script gọi API qua `curl` + `python3` có sẵn.

---

## 🗑️ Gỡ / kiểm tra

```bash
bash cai-dat.sh --go-cai-dat
bash cai-dat.sh --kiem-tra
```
