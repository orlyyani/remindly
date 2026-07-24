import os, math
from PIL import Image, ImageDraw

PROJ = "/Users/orly/Documents/Workspace/Dev/Mobile/reminder-app"
PURPLE = (108, 92, 231, 255)
PURPLE_DK = (74, 60, 170, 255)
ORANGE = (245, 166, 35, 255)
PINK = (232, 106, 166, 255)
WHITE = (255, 255, 255, 255)
CREAM = (244, 241, 236, 255)
INK = (45, 42, 50, 255)

SS = 4  # supersample

def draw_clock(d, cx, cy, R, ring_color, face_color, hand_color, foot_color):
    # feet
    fw = int(R * 0.14)
    d.line([(cx - R*0.55, cy + R*0.9), (cx - R*0.9, cy + R*1.18)], fill=foot_color, width=fw)
    d.line([(cx + R*0.55, cy + R*0.9), (cx + R*0.9, cy + R*1.18)], fill=foot_color, width=fw)
    # bells (two orange humps up top)
    bw = int(R * 0.20)
    br = R * 0.42
    for sign in (-1, 1):
        bx = cx + sign * R * 0.62
        by = cy - R * 0.98
        box = [bx - br, by - br, bx + br, by + br]
        d.arc(box, start=200, end=340, fill=ORANGE, width=bw)
    # body ring
    d.ellipse([cx - R, cy - R, cx + R, cy + R], fill=ring_color)
    # face
    fr = R * 0.80
    d.ellipse([cx - fr, cy - fr, cx + fr, cy + fr], fill=face_color)
    # hands
    hw = int(R * 0.06)
    d.line([(cx, cy), (cx, cy - R * 0.52)], fill=hand_color, width=hw)  # minute up
    d.line([(cx, cy), (cx + R * 0.42, cy + R * 0.20)], fill=hand_color, width=hw)  # hour
    # center dot
    cd = R * 0.07
    d.ellipse([cx - cd, cy - cd, cx + cd, cy + cd], fill=INK)
    # decorative dots
    dd = R * 0.07
    d.ellipse([cx - R*1.08 - dd, cy + R*0.35 - dd, cx - R*1.08 + dd, cy + R*0.35 + dd], fill=ORANGE)
    dd2 = R * 0.085
    d.ellipse([cx + R*1.08 - dd2, cy + R*0.5 - dd2, cx + R*1.08 + dd2, cy + R*0.5 + dd2], fill=PINK)

def new_canvas(size, bg):
    img = Image.new("RGBA", (size*SS, size*SS), bg)
    return img, ImageDraw.Draw(img)

def finish(img, size, path):
    img = img.resize((size, size), Image.LANCZOS)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("wrote", path)

S = 1024

# 1) Full icon: purple bg, white-body clock (pops on purple), orange accents.
img, d = new_canvas(S, PURPLE)
cx = cy = S*SS/2
draw_clock(d, cx, cy - S*SS*0.02, R=S*SS*0.30, ring_color=WHITE, face_color=(246,244,255,255),
           hand_color=ORANGE, foot_color=WHITE)
finish(img, S, f"{PROJ}/assets/icon/icon.png")

# 2) Adaptive foreground: transparent, same white clock, smaller (safe zone ~66%).
img, d = new_canvas(S, (0,0,0,0))
draw_clock(d, cx, cy - S*SS*0.02, R=S*SS*0.24, ring_color=WHITE, face_color=(246,244,255,255),
           hand_color=ORANGE, foot_color=WHITE)
finish(img, S, f"{PROJ}/assets/icon/icon_foreground.png")

# 3) Splash logo: transparent, the colourful brand mascot (purple ring) — sits on cream bg.
img, d = new_canvas(S, (0,0,0,0))
draw_clock(d, cx, cy - S*SS*0.02, R=S*SS*0.30, ring_color=PURPLE, face_color=WHITE,
           hand_color=ORANGE, foot_color=PURPLE)
finish(img, S, f"{PROJ}/assets/splash/splash_logo.png")

print("done")
