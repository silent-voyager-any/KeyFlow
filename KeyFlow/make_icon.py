#!/usr/bin/env python3
# Converts icon.png -> KeyFlow.icns using macOS sips + iconutil
import subprocess, os, shutil

src = "icon.png"
iconset = "KeyFlow.iconset"
os.makedirs(iconset, exist_ok=True)

sizes = [16, 32, 64, 128, 256, 512]
for s in sizes:
    subprocess.run(["sips", "-z", str(s), str(s), src,
                    "--out", f"{iconset}/icon_{s}x{s}.png"], capture_output=True)
    s2 = s * 2
    subprocess.run(["sips", "-z", str(s2), str(s2), src,
                    "--out", f"{iconset}/icon_{s}x{s}@2x.png"], capture_output=True)

subprocess.run(["iconutil", "-c", "icns", iconset, "-o", "KeyFlow.icns"])
shutil.rmtree(iconset)
print("KeyFlow.icns written")
