#!/usr/bin/env bash
# thoi-tiet — Xem thời tiết nhanh, không cần API key
# Dùng: thoi-tiet          (mặc định: Hanoi)
#       thoi-tiet "Ho Chi Minh"

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$SCRIPT_DIR/lib.sh" ] && source "$SCRIPT_DIR/lib.sh"

THANH_PHO="${1:-Hanoi}"
THANH_PHO_URL=$(echo "$THANH_PHO" | sed 's/ /+/g')

echo -e "\e[1;36m🌦  THỜI TIẾT — ${THANH_PHO}\e[0m"
echo "────────────────────────────────────────"

if curl -s --max-time 8 "wttr.in/${THANH_PHO_URL}?format=j1&lang=vi" -o /tmp/.thoitiet.json 2>/dev/null; then
  python3 -c "
import json
d = json.load(open('/tmp/.thoitiet.json'))
c = d['current_condition'][0]
a = d['nearest_area'][0]
print(f\"📍 $THANH_PHO\")
print(f\"🌡  Nhiệt độ: {c['temp_C']}°C (cảm giác như {c['FeelsLikeC']}°C)\")
bang_dich = {'Smog': 'Sương mù ô nhiễm', 'Haze': 'Sương mù nhẹ', 'Mist': 'Sương mù', 'Fog': 'Sương mù dày', 'Thundery outbreaks': 'Dông rải rác'}
en = c.get('weatherDesc', [{}])[0].get('value', '')
vi = c.get('lang_vi', [{}])[0].get('value') if c.get('lang_vi') else None
mo_ta = None
if vi and vi != en:
    mo_ta = vi
if not mo_ta:
    mo_ta = bang_dich.get(en, en)
print(f\"☁️  Trời: {mo_ta}\")
print(f\"💧 Độ ẩm: {c['humidity']}%\")
print(f\"💨 Gió: {c['windspeedKmph']} km/h\")
print(f\"🌧  Lượng mưa: {c['precipMM']} mm\")
"
else
  echo "⚠ Không có mạng hoặc wttr.in lỗi"
  exit 1
fi
rm -f /tmp/.thoitiet.json