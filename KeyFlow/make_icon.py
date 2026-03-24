#!/usr/bin/env python3
"""
Generates KeyFlow.icns — a frosted glass keyboard icon
Renders a PNG via pure Python (no Pillow needed), then uses
macOS sips + iconutil to convert to .icns
"""
import struct, zlib, math, subprocess, os, sys

def clamp(v, lo=0, hi=255):
    return max(lo, min(hi, int(v)))

def make_png(w, h, pixels):
    def chunk(name, data):
        c = zlib.crc32(name+data) & 0xffffffff
        return struct.pack('>I',len(data)) + name + data + struct.pack('>I',c)
    ihdr = struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)  # RGBA
    raw  = b''
    for row in pixels:
        raw += b'\x00'
        for r,g,b,a in row:
            raw += bytes([clamp(r),clamp(g),clamp(b),clamp(a)])
    return (b'\x89PNG\r\n\x1a\n'
            + chunk(b'IHDR', ihdr)
            + chunk(b'IDAT', zlib.compress(raw,9))
            + chunk(b'IEND', b''))

S = 512
pixels = [[(0,0,0,0)]*S for _ in range(S)]

def blend(base, over):
    r0,g0,b0,a0 = base
    r1,g1,b1,a1 = [x/255.0 for x in over]
    a0 /= 255.0
    ao = a1 + a0*(1-a1)
    if ao == 0: return (0,0,0,0)
    ro = (r1*a1 + r0*a0*(1-a1)) / ao
    go = (g1*a1 + g0*a0*(1-a1)) / ao
    bo = (b1*a1 + b0*a0*(1-a1)) / ao
    return (clamp(ro*255),clamp(go*255),clamp(bo*255),clamp(ao*255))

def fill_rect(x1,y1,x2,y2, color, radius=0):
    r,g,b,a = color
    for y in range(y1,y2):
        for x in range(x1,x2):
            if not (0<=x<S and 0<=y<S): continue
            if radius > 0:
                cx = cy = None
                if x < x1+radius and y < y1+radius: cx,cy = x1+radius, y1+radius
                elif x >= x2-radius and y < y1+radius: cx,cy = x2-radius-1, y1+radius
                elif x < x1+radius and y >= y2-radius: cx,cy = x1+radius, y2-radius-1
                elif x >= x2-radius and y >= y2-radius: cx,cy = x2-radius-1, y2-radius-1
                if cx is not None and (x-cx)**2+(y-cy)**2 > radius**2: continue
            pixels[y][x] = blend(pixels[y][x], color)

def fill_circle(cx,cy,r, color):
    for y in range(cy-r-1, cy+r+2):
        for x in range(cx-r-1, cx+r+2):
            if 0<=x<S and 0<=y<S:
                if (x-cx)**2+(y-cy)**2 <= r*r:
                    pixels[y][x] = blend(pixels[y][x], color)

def draw_ring(cx,cy,r,thickness, color):
    for y in range(cy-r-2, cy+r+3):
        for x in range(cx-r-2, cx+r+3):
            if 0<=x<S and 0<=y<S:
                d = math.sqrt((x-cx)**2+(y-cy)**2)
                if r-thickness <= d <= r:
                    alpha = min(255, int(color[3] * (1 - abs(d-(r-thickness/2))/(thickness/2))))
                    pixels[y][x] = blend(pixels[y][x], (color[0],color[1],color[2],alpha))

# ── Background: dark glass circle ───────────────────────────────
bg_r = 230
fill_circle(256,256,bg_r, (22,22,28, 210))

# Frosted glass shimmer — radial gradient overlay
for y in range(S):
    for x in range(S):
        dx,dy = x-256, y-256
        d = math.sqrt(dx*dx+dy*dy)
        if d > bg_r: continue
        angle = math.atan2(dy,dx)
        # top-left highlight
        highlight = max(0, math.cos(angle + math.pi*0.75)) * (1-d/bg_r)
        a = int(highlight * 55)
        if a > 0:
            pixels[y][x] = blend(pixels[y][x], (255,255,255,a))

# Outer ring border
draw_ring(256,256,bg_r,3, (255,255,255,70))
draw_ring(256,256,bg_r-3,2, (255,255,255,30))

# ── Keyboard body ────────────────────────────────────────────────
kx1,ky1,kx2,ky2 = 80,160,432,340
fill_rect(kx1,ky1,kx2,ky2, (255,255,255,22), radius=28)
# border
for y in range(ky1,ky2):
    for x in range(kx1,kx2):
        if not (0<=x<S and 0<=y<S): continue
        on_border = (
            (x == kx1 or x == kx2-1) or
            (y == ky1 or y == ky2-1)
        )
        if on_border:
            pixels[y][x] = blend(pixels[y][x], (255,255,255,80))

# ── Keys ────────────────────────────────────────────────────────
def key(x, y, w=28, h=24, color=(255,255,255,55)):
    fill_rect(x, y, x+w, y+h, color, radius=5)
    fill_rect(x+1, y+1, x+w-1, y+h-3, (255,255,255,25), radius=4)

# Row 1  (number row) — 12 keys
for i in range(12):
    key(90 + i*28, 170)

# Row 2 — 12 keys
for i in range(12):
    key(90 + i*28, 202)

# Row 3 — 11 keys + enter stub
for i in range(11):
    key(104 + i*28, 234)

# Row 4 — 10 keys
for i in range(10):
    key(118 + i*28, 266)

# Spacebar
fill_rect(158, 300, 354, 326, (255,255,255,55), radius=7)
fill_rect(159, 301, 353, 322, (255,255,255,22), radius=6)

# ── Blue accent key (highlighted key — "A") ──────────────────────
key(104, 234, w=28, h=24, color=(92,148,248,200))
fill_rect(106, 236, 130, 256, (140,190,255,60), radius=4)

# ── Glow under keyboard ─────────────────────────────────────────
for y in range(S):
    for x in range(S):
        dy = y - 350
        dx = x - 256
        d = math.sqrt(dx*dx*0.3 + dy*dy)
        if d < 120:
            a = int((1-d/120)**2 * 40)
            pixels[y][x] = blend(pixels[y][x], (92,148,248,a))

# ── Top sheen on circle ─────────────────────────────────────────
for y in range(100, 260):
    for x in range(100, 412):
        dx,dy = x-256, y-256
        d = math.sqrt(dx*dx+dy*dy)
        if d > bg_r: continue
        if y < 220:
            a = int((220-y)/120.0 * 30 * (1-d/bg_r))
            pixels[y][x] = blend(pixels[y][x], (255,255,255,a))

png_data = make_png(S, S, pixels)
with open('KeyFlow_icon.png', 'wb') as f:
    f.write(png_data)
print("KeyFlow_icon.png written")

# Convert to .icns using macOS tools
iconset = 'KeyFlow.iconset'
os.makedirs(iconset, exist_ok=True)
sizes = [16,32,64,128,256,512]
for s in sizes:
    subprocess.run(['sips','-z',str(s),str(s),'KeyFlow_icon.png','--out',
                    f'{iconset}/icon_{s}x{s}.png'], capture_output=True)
    s2 = s*2
    subprocess.run(['sips','-z',str(s2),str(s2),'KeyFlow_icon.png','--out',
                    f'{iconset}/icon_{s}x{s}@2x.png'], capture_output=True)
subprocess.run(['iconutil','-c','icns',iconset,'-o','KeyFlow.icns'])
import shutil; shutil.rmtree(iconset)
print("KeyFlow.icns written")
