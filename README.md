# 𝕴 𝖆𝖒 𝖍𝖎𝖒 — Ultimate Destructive Mode

**Termux Edition · Use on devices you own only**

---

## ⚠️ WARNING
This script is **highly disruptive**. Run **only** on devices you own.  
It may reboot, lock, or require a factory reset.  
Default lockscreen password (if set by the script): `iamhim957`  
You accept full responsibility.

---

## Features
- Battery spoofing (levels, unplug)  
- Force-stop / try-disable apps (Chrome, Facebook, WhatsApp)  
- Toggle Wi-Fi, mobile data, Bluetooth  
- Screen chaos: rotation, brightness flicker, on/off toggle  
- Random taps, swipes, vibrations, keyboard spam  
- Volume max, notification spam, random app launches  
- Infinite playback of a single direct `.mp4` link  
- Panic-stop file: `/sdcard/omega_stop` or `$HOME/omega_stop`  
- Attempts root/system commands but continues if they fail

---

## Quick Start (copy & paste)
```bash
# grant Termux storage access
termux-setup-storage

# clone the script 
git clone https://github.com/priscy82/Twin

# go to the script's directory
cd Twin

# make the script executable
chmod +x test.sh

# run the script
./test.sh

# run in background (optional)
nohup ./test.sh &> test_log.txt &

# stop safely: create the panic file
touch /sdcard/omega_stop