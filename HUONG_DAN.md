# 📦 BỘ CÔNG CỤ TOOLSET — Hướng dẫn cài đặt & sử dụng

Bộ gồm **4 nhóm độc lập**, cài chọn lọc qua **một trình cài đặt duy nhất**:

| # | Nhóm | Lệnh sau khi cài | Mô tả |
|---|------|------|------|
| 1 | **Các thư viện cần thiết** (rất quan trọng) | — | Gói apt + pip nền tảng cho cả 3 nhóm dưới |
| 2 | Mỗi ngày một lệnh Linux | `hoc`, `hoc-linux` | Tra cứu + học lệnh Linux (quiz, flashcard...) |
| 3 | Học từ mới tiếng Trung | `tu` | Tra từ vựng tiếng Trung + nghe phát âm |
| 4 | Công cụ cho máy tính của bạn | `donrac`, `pin` | Dọn dẹp hệ thống + giám sát pin |

Có thể cài 1, vài, hay cả 4 nhóm — không nhóm nào phụ thuộc nhóm khác, nhưng **máy
mới nên cài mục 1 trước tiên** vì nhóm 2-4 đều cần `python3` và một số công cụ CLI
mà mục 1 cài sẵn.

---

## 🚀 CÀI ĐẶT

```bash
unzip bo-cong-cu-toolset.zip
cd bo-cong-cu-toolset
bash cai-dat.sh
```

Sẽ hiện menu:

```
Chọn (các) mục muốn cài đặt:

   1)  Cài đặt các thư viện cần thiết (rất quan trọng)
   2)  Mỗi ngày một lệnh Linux     (hoc, hoc-linux)
   3)  Học từ mới tiếng Trung       (tu)
   4)  Công cụ cho máy tính của bạn (donrac, pin)
   5)  Cài tất cả
   0)  Thoát

Có thể chọn nhiều mục, cách nhau bằng dấu cách (vd: 1 2 4)
Máy mới nên chọn mục 1 trước tiên.
➜ Nhập STT:
```

Gõ số tương ứng, ví dụ `1 2` để cài thư viện + nhóm Linux, hoặc `5` để cài hết.

### Cài không cần menu (cho script/CI/onboarding hàng loạt)

```bash
bash cai-dat.sh --tat-ca       # cài cả 4 nhóm (kể cả thư viện), không hỏi
bash cai-dat.sh --thu-vien     # chỉ cài thư viện cần thiết (apt + pip)
bash cai-dat.sh --hoc-linux    # chỉ cài hoc, hoc-linux
bash cai-dat.sh --hoc-trung    # chỉ cài tu
bash cai-dat.sh --may-tinh     # chỉ cài donrac, pin
```

Sau khi cài, **mở terminal mới** (hoặc `source ~/.bashrc`) để áp dụng.

---

## 🔄 CẬP NHẬT / CÀI THÊM NHÓM KHÁC

Chạy lại `bash cai-dat.sh` và chọn nhóm muốn cài/cập nhật — script tự nhận ra
nhóm nào đã cài và chỉ ghi đè đúng phần đó, không đụng các nhóm khác.

---

## 🗑️ GỠ CÀI ĐẶT

```bash
bash cai-dat.sh --go-cai-dat
```

Sẽ hiện menu chọn gỡ từng nhóm hoặc gỡ tất cả — tương tự lúc cài.

## 🔍 KIỂM TRA TRẠNG THÁI

```bash
bash cai-dat.sh --kiem-tra
```

---

## 📦 NHÓM 1 — CÁC THƯ VIỆN CẦN THIẾT (rất quan trọng)

Cài gói hệ thống (apt) + thư viện Python cho tính năng phát âm, **không dùng
virtualenv** — cài thẳng vào hệ thống theo `requirements.txt` đi kèm gói.

Gói apt sẽ cài (nếu chưa có): `python3`, `python3-pip`, `curl`, `bc`, `bluez`,
`upower`, `espeak-ng`. Gói pip (từ `requirements.txt`): `edge-tts`, `gTTS`.

```bash
bash cai-dat.sh --thu-vien
```

Script tự kiểm tra từng gói, gói nào đã có sẽ bỏ qua, không cài lại. Nếu máy
không có mạng ra `pypi.org`, phần apt vẫn chạy được — chỉ phần `pip install` sẽ
báo lỗi, chạy lại sau khi có mạng.

---

## 📖 NHÓM 2 — HOC / HOC-LINUX (Mỗi ngày một lệnh Linux)

### Tra cứu nhanh: `hoc`

```bash
hoc ls                    # Tra cứu lệnh cụ thể
hoc --danh-sach           # Xem toàn bộ lệnh trong DB
hoc --tim gr              # Tìm gần đúng theo tên → grep, groups...
hoc --mo-ta "nén file"    # Tìm theo mô tả → tar, zip, gzip...
hoc --ai "xóa file lớn hơn 100MB"   # 🤖 Hỏi AI (Groq) tìm lệnh
hoc --nghe cp             # 🔊 Đọc to mô tả + các option của lệnh
hoc --cache [xoa]         # Xem/xóa cache kết quả AI
```

### Học tương tác: `hoc-linux`

```bash
hoc-linux            # Mở menu chọn số
hoc-linux quiz 5      # 5 câu trắc nghiệm ngẫu nhiên
hoc-linux flash       # Flashcard (Enter=tiếp, s=lưu favorites, q=thoát)
hoc-linux fav         # Xem/thêm/xóa lệnh yêu thích
hoc-linux his         # Lịch sử học tập + thống kê
hoc-linux stats       # Streak, huy hiệu, top lệnh học nhiều nhất
hoc-linux explain "grep -r -n pattern /path"   # Giải thích từng phần của lệnh
hoc-linux cheat tar   # Cheatsheet nhanh
```

### Thêm lệnh mới vào DB

Mở `~/.lenh_linux_db.txt`, thêm dòng theo định dạng:
```
tên|mô tả ngắn|option1;; option2;; option3|lệnh liên quan|độ khó (1-3)|ví dụ hoàn chỉnh
```

---

## 🀄 NHÓM 3 — TU (Học từ mới tiếng Trung)

```bash
tu 你好              # Tra từ — có trong DB thì hiện luôn, chưa có thì hỏi AI
tu 加油              # Từ mới / tiếng lóng → AI tra, hỏi có lưu vào DB không
tu nghe 你好          # 🔊 Nghe phát âm (cần edge-tts / gtts-cli / espeak-ng)
tu --list            # Xem toàn bộ từ trong DB
tu --cache [xoa]      # Xem/xóa cache kết quả AI
```

### Thêm từ mới vào DB

Mở `~/.tiengtrung_db.txt`, thêm dòng:
```
Chữ Hán|pinyin|nghĩa tiếng Việt|câu ví dụ|phiên âm Việt|phiên âm câu ví dụ
```

### 🔇 "Đang đọc" hiện chữ nhưng không nghe thấy gì?

Nguyên nhân thường gặp, thử lần lượt:

1. **Chưa cài mục 1 (thư viện)** → chạy `bash cai-dat.sh --thu-vien` để có `espeak-ng`
   (đọc offline, không cần mạng) và `mpv` (phát file mp3).
2. **`edge-tts`/`gTTS` cần mạng** — nếu máy không có mạng lúc đó, bản mới sẽ tự
   chuyển sang `espeak-ng` (giọng robot nhưng chạy offline được). Nếu vẫn im lặng
   hoàn toàn, kiểm tra tay:
   ```bash
   espeak-ng -v vi "xin chào"      # nghe thử espeak-ng trực tiếp
   command -v mpv espeak-ng edge-tts gtts-cli   # xem cái nào đã cài
   ```
3. **Loa/âm lượng hệ thống đang tắt hoặc mute** — kiểm tra bằng `pactl list sinks`
   hoặc thử phát 1 file mp3/âm thanh bất kỳ bằng `mpv` xem có tiếng không.

---

## 🧹 NHÓM 4 — DONRAC / PIN (Công cụ cho máy tính của bạn)

```bash
donrac              # Dọn cache APT, thumbnail, cache >30 ngày, journal logs,
                     # snap revision cũ, /tmp — rồi hỏi có muốn gỡ phần mềm không
donrac --lich-su     # Xem lịch sử các lần dọn dẹp
donrac --uoc-tinh    # Ước tính dung lượng sẽ giải phóng trước khi dọn thật

pin                  # Trạng thái pin, sức khoẻ pin, thời gian còn lại, nhiệt độ
                     # CPU, danh sách thiết bị Bluetooth đang kết nối + pin từng thiết bị
```

⚠️ Khi `donrac` hỏi có gỡ phần mềm không, các gói thuộc nhóm "🔒 Hệ thống Ubuntu"
luôn bị khóa, không thể chọn xóa. Nhóm "⚙️ Thư viện hệ thống" vẫn cho gỡ nhưng có
cảnh báo đỏ — cân nhắc kỹ trước khi xác nhận vì gỡ sai có thể ảnh hưởng phần mềm khác.

---

## 🤖 GROQ AI — CÀI ĐẶT (dùng chung cho `hoc --ai` và `tu`)

1. Vào https://console.groq.com, đăng ký miễn phí, tạo API key (bắt đầu bằng `gsk_`)
2. Lưu key:
   ```bash
   echo 'GROQ_API_KEY="gsk_day_cua_ban"' >> ~/.hoc_config
   ```
3. Dùng thử:
   ```bash
   hoc --ai tìm file lớn hơn 100MB
   tu 内卷
   ```

Không cần cài thêm gì — script gọi API qua `curl` + `python3` (có sẵn trên Ubuntu).

---

## 🌅 HIỂN THỊ HỌC TẬP MỖI KHI MỞ TERMINAL

Nếu đã cài nhóm 2 và/hoặc nhóm 3, mỗi lần mở terminal sẽ tự hiện:

```
💡 LỆNH HÔM NAY: grep — Tìm kiếm chuỗi văn bản trong tệp
   Ví dụ: grep -i "loi" nhat_ky.log

🀄 TIẾNG TRUNG HÔM NAY: 天气  tiān qì  Thời tiết
   Ví dụ: 今天天气怎么样？(Hôm nay thời tiết thế nào?)
```

Nếu chỉ cài 1 trong 2 nhóm, chỉ dòng tương ứng hiện ra. Gỡ nhóm nào thì dòng đó
cũng biến mất khỏi `~/.bashrc` (script tự dọn đúng phần, không đụng phần còn lại).

---

## ⚙️ YÊU CẦU HỆ THỐNG

- Ubuntu 20.04 / 22.04 / 24.04 hoặc Debian tương đương
- Bash 4.0+, quyền sudo (cho cài đặt và `donrac`)
- Chạy **mục 1 (Các thư viện cần thiết)** sẽ tự lo hết các mục dưới đây:
  - `python3`, `python3-pip` (AI JSON parsing, cả nhóm 2 và 3)
  - `curl` (gọi Groq API)
  - `bc` (tính dung lượng trong `donrac`)
  - `bluez` (Bluetooth cho `pin`)
  - `upower` (thời gian pin cho `pin`)
  - `espeak-ng` + `edge-tts`/`gTTS` (phát âm cho `tu nghe`)
  - `mpv` (phát file mp3 do `edge-tts`/`gTTS` sinh ra — thiếu cái này thì thấy chữ
    "Đang đọc" nhưng không có tiếng, vì không có gì phát file mp3 cả)

---

## 📝 GHI CHÚ

- Tất cả lệnh hoạt động từ **bất kỳ thư mục nào** sau khi cài
- File DB nằm tại `~/` — không bị xóa khi gỡ cài đặt riêng lẻ nhóm 2 hoặc nhóm 3
  (chỉ mất khi gỡ đúng nhóm chứa nó)
- File lịch sử/favorites của hoc-linux: `~/.hoclinux_history`, `~/.hoclinux_favorites`
- Chỉnh `.bashrc` thủ công: `nano ~/.bashrc` → `source ~/.bashrc` để áp dụng
