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
Grant Termux storage access
```bash
termux-setup-storage
```

Clone the script 
```bash
git clone https://github.com/priscy82/Twin
```

Go to the script's directory
```bash
cd Twin
```

Make the script executable
```bash
chmod +x test.sh
```

Run the script
```bash
./test.sh
```

Run in background (optional)
```bash
nohup ./test.sh &> test_log.txt &
```

Stop safely: create the panic file
```bash
touch /sdcard/omega_stop
```