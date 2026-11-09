#!/usr/bin/env bash
set -Eeuo pipefail
if [[ "${TIXUN_SMOKE_INNER:-}" != 1 ]]; then
  export TIXUN_SMOKE_INNER=1
  exec timeout 90s "$0" "$@"
fi
# Run a TIXUN_DEMO=true Linux build, with bounded lifetime and no real keys.
cd "$(dirname "$0")/.."
artifact_dir="${TIXUN_ARTIFACTS:-$PWD/artifacts/gui}"
mkdir -p "$artifact_dir"
if [[ -z "${DISPLAY:-}" ]]; then
  exec timeout 90s xvfb-run -a -s '-screen 0 1440x1100x24' "$0" "$@"
fi
binary="${1:-build/linux/x64/release/bundle/tixun}"
app_pid=''
cleanup() { if [[ -n "$app_pid" ]]; then kill -- "-$app_pid" 2>/dev/null || true; wait "$app_pid" 2>/dev/null || true; fi; }
trap cleanup EXIT INT TERM
trap 'status=$?; echo "GUI smoke failed at line $LINENO" >&2; capture failure 2>/dev/null || true; tail -60 "$artifact_dir/app.log" >&2; exit "$status"' ERR
export LIBGL_ALWAYS_SOFTWARE=1
export GDK_BACKEND=x11
# A private session bus avoids requiring a logged-in desktop/keyring in Mock mode.
setsid dbus-run-session -- "$binary" >"$artifact_dir/app.log" 2>&1 &
app_pid=$!
window=''
for _ in $(seq 1 100); do
  kill -0 "$app_pid" 2>/dev/null || { cat "$artifact_dir/app.log"; exit 1; }
  window=$(xdotool search --onlyvisible --class 'org.tixun.tixun' 2>/dev/null | head -1 || true)
  if [[ -n "$window" ]] && rg -q 'TIXUN_READY demo=true' "$artifact_dir/app.log"; then break; fi
  sleep .2
done
[[ -n "$window" ]] && rg -q 'TIXUN_READY demo=true' "$artifact_dir/app.log" || { cat "$artifact_dir/app.log"; exit 1; }
xdotool windowsize "$window" 1280 860
xdotool windowfocus --sync "$window"
sleep 1
capture() { if command -v magick >/dev/null; then magick import -window "$window" "$artifact_dir/$1.png"; else import -window "$window" "$artifact_dir/$1.png"; fi; }
capture desktop-study
xdotool key --clearmodifiers ctrl+2
sleep 1
capture desktop-chat-math
previous_composers=$(rg -c TIXUN_COMPOSER_POINT "$artifact_dir/app.log" || true)
xdotool key --clearmodifiers ctrl+n
for _ in $(seq 1 100); do
  ready_composers=$(rg -c TIXUN_COMPOSER_POINT "$artifact_dir/app.log" || true)
  if (( ${ready_composers:-0} > ${previous_composers:-0} )); then break; fi
  sleep .1
done
(( ${ready_composers:-0} > ${previous_composers:-0} ))
read -r _ input_x input_y < <(rg TIXUN_COMPOSER_POINT "$artifact_dir/app.log" | tail -1)
xdotool windowfocus --sync "$window"
xdotool mousemove --window "$window" "$input_x" "$input_y" click 1
xdotool type --clearmodifiers --delay 25 'Explain quadratic functions'
for _ in $(seq 1 50); do
  rg -q TIXUN_DRAFT_READY "$artifact_dir/app.log" && break
  sleep .1
done
rg -q TIXUN_DRAFT_READY "$artifact_dir/app.log"
# Click the real rendered send control. Keyboard shortcuts are independently
# exercised through Flutter's integration harness.
# The send control only appears once the composer has text (the action slot
# morphs from the image button to send), so its point is logged after typing;
# wait for it instead of reading a possibly not-yet-logged point.
for _ in $(seq 1 50); do
  rg -q TIXUN_SEND_POINT "$artifact_dir/app.log" && break
  sleep .1
done
rg -q TIXUN_SEND_POINT "$artifact_dir/app.log"
read -r _ send_x send_y < <(rg TIXUN_SEND_POINT "$artifact_dir/app.log" | tail -1)
xdotool mousemove --window "$window" "$send_x" "$send_y" click 1
for _ in $(seq 1 40); do
  rg -q TIXUN_GENERATION_STARTED "$artifact_dir/app.log" && break
  sleep .1
done
rg -q TIXUN_GENERATION_STARTED "$artifact_dir/app.log"
sleep .3
capture desktop-streaming
for _ in $(seq 1 80); do
  rg -q 'TIXUN_GENERATION_FINISHED status=complete' "$artifact_dir/app.log" && break
  sleep .1
done
rg -q 'TIXUN_GENERATION_FINISHED status=complete' "$artifact_dir/app.log"
sleep .8
capture desktop-chat-answer
xdotool key --clearmodifiers ctrl+5
sleep 1
capture desktop-knowledge
xdotool mousemove --window "$window" 700 310 click 1
sleep 1
capture desktop-knowledge-detail
xdotool key --clearmodifiers ctrl+4
sleep 1
capture desktop-mistakes
xdotool mousemove --window "$window" 700 310 click 1
sleep 1
capture desktop-mistake-detail
xdotool key --clearmodifiers ctrl+3
sleep 1
capture desktop-settings
xdotool windowsize "$window" 390 844
sleep 1
capture phone-settings
xdotool key --clearmodifiers ctrl+2
sleep 1
capture phone-chat
xdotool key --clearmodifiers ctrl+1
sleep 1
capture phone-study
xdotool key --clearmodifiers ctrl+5
sleep 1
capture phone-knowledge
xdotool mousemove --window "$window" 180 305 click 1
sleep 1
capture phone-knowledge-detail
xdotool key --clearmodifiers ctrl+4
sleep 1
capture phone-mistakes
xdotool mousemove --window "$window" 180 305 click 1
sleep 1
capture phone-mistake-detail
if rg -n 'EXCEPTION CAUGHT|A RenderFlex overflowed|Unhandled Exception|Error while opening' "$artifact_dir/app.log"; then exit 1; fi
printf 'GUI smoke passed. Screenshots require separate visual review: %s\n' "$artifact_dir"
