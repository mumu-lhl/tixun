#!/usr/bin/env bash
set -euo pipefail
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
xdotool key --clearmodifiers ctrl+n
sleep .3
# Focus composer through keyboard traversal is covered by integration_test; click
# coordinates below are tied to the explicitly fixed desktop window size.
xdotool mousemove --window "$window" 750 760 click 1
xdotool type --clearmodifiers --delay 20 'Explain quadratic functions'
xdotool key --clearmodifiers ctrl+Return
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
if rg -n 'EXCEPTION CAUGHT|A RenderFlex overflowed|Unhandled Exception|Error while opening' "$artifact_dir/app.log"; then exit 1; fi
printf 'GUI smoke passed. Screenshots require separate visual review: %s\n' "$artifact_dir"
