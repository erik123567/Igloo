"""Generates Igloo's original pixel-art sprites into art/. Run: python3 tools/make_sprites.py
All art made by this script is original and released under CC0 (see ASSETS.md)."""
import math, os, random
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "art")
os.makedirs(OUT, exist_ok=True)

K = (30, 32, 44, 255)
PAL = {
    ".": (0, 0, 0, 0), "K": K,
    "R": (204, 72, 52, 255), "r": (150, 46, 38, 255),
    "F": (138, 98, 66, 255), "f": (186, 146, 104, 255),
    "S": (240, 202, 168, 255), "E": (40, 30, 30, 255),
    "M": (72, 80, 150, 255), "P": (62, 62, 84, 255), "B": (70, 46, 30, 255),
    "W": (122, 126, 138, 255), "w": (84, 88, 102, 255), "L": (178, 182, 192, 255),
    "Y": (255, 214, 60, 255), "N": (20, 20, 24, 255),
    "H": (196, 178, 150, 255), "h": (150, 132, 108, 255), "T": (250, 250, 252, 255),
}


def from_rows(rows):
    w = max(len(r) for r in rows)
    img = Image.new("RGBA", (w, len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, c in enumerate(row.ljust(w, ".")):
            img.putpixel((x, y), PAL[c])
    return img


def mirror_half(rows):
    return [r + r[::-1] for r in rows]


def save(img, name):
    img.save(os.path.join(OUT, name + ".png"))


def outline(img, color=K):
    w, h = img.size
    out = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    out.paste(img, (1, 1))
    px = out.load()
    src = [[px[x, y][3] > 0 for y in range(h + 2)] for x in range(w + 2)]
    for x in range(w + 2):
        for y in range(h + 2):
            if src[x][y]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w + 2 and 0 <= ny < h + 2 and src[nx][ny]:
                    px[x, y] = color
                    break
    return out


# ---------------- Player ----------------
head_down = [".....KKK", "....KfFF", "...KfFSS", "...KFSES", "...KFSSS", "...KfFSS", "....KfFF"]
head_up = [".....KKK", "....KfFF", "...KfFFF", "...KFFFF", "...KFFFF", "...KfFFF", "....KfFF"]
torso_down = ["...KKRRR", "..KRRRRR", ".KMKRRRr", ".KMKRRRr", ".KKKRRRr", "...KRRRR", "...Kffff"]
torso_up = ["...KKRRR", "..KRRRRR", ".KMKRRRR", ".KMKRRRR", ".KKKRRRR", "...KRRRR", "...Kffff"]
legs = [
    ["...KPPK..KPPK...", "...KPPK..KPPK...", "...KBBK..KBBK...", "...KKKK..KKKK..."],
    ["...KPPK..KPPK...", "...KBBK..KPPK...", "...KKKK..KBBK...", ".........KKKK..."],
]
legs.append([r[::-1] for r in legs[1]])
for view, head, torso in (("down", head_down, torso_down), ("up", head_up, torso_up)):
    for i, lg in enumerate(legs):
        save(from_rows(mirror_half(head + torso) + lg), f"player_{view}_{i}")

side_body = [
    "......KKKKK.....", ".....KfFFFFK....", "....KfFFFSSFK...", "....KFFFSSESK...",
    "....KFFFSSSSK...", "....KfFFFSSFK...", ".....KfFFFFK....", ".....KRRRRRK....",
    "....KRRRRRRRK...", "....KRRRKMMK....", "....KRRRKMMK....", "....KRRRRKK.....",
    "....KRRRRRRK....", "....KfffffffK...",
]
side_legs = [
    [".....KPPPPK.....", ".....KPPPPK.....", ".....KBBBBKK....", ".....KKKKKK....."],
    ["....KPPK.KPPK...", "...KPPK...KPPK..", "...KBBK...KBBK..", "...KKKK...KKKK.."],
]
for i, lg in enumerate(side_legs):
    save(from_rows(side_body + lg), f"player_side_{i}")

# ---------------- Wolf ----------------
wolf_body = [
    "...................K.K..",
    "..................KwKwK.",
    ".................KWWWWWK",
    "KK..............KWWWYWWKK",
    "KwK...KKKKKKKKKKWWWWWWWNK",
    ".KwKKKWWWWWWWWWWWWWWWKKK.",
    "..KwWWWWWWWWWWWWWWWWWK...",
    "...KWWWWWWWWWWWWWWWWK....",
    "...KWWWLLLLLLLLLLLWWK....",
    "...KWWKKLLLLLLLLKKWWK....",
]
wolf_legs = [
    ["....KwK.KwK.....KwK.KwK.", "....KwK.KwK.....KwK.KwK.", "....KKK.KKK.....KKK.KKK."],
    ["...KwK...KwK...KwK...KwK", "..KwK.....KwK.KwK.....KwK", "..KKK.....KKK.KKK.....KKK"],
]
for i, lg in enumerate(wolf_legs):
    save(from_rows(wolf_body + lg), f"wolf_{i}")

# ---------------- Hare ----------------
hare_top = [".......K.K..", "......KhKhK.", "......KhKhK.", ".......KHHK.", "..KKKKKHHEHK",
            ".KTHHHHHHHHK", "KTTHHHHHHHK.", ".KHHHHHHHK.."]
save(from_rows(hare_top + ["..KHHKKHHK..", "..KKK..KKK.."]), "hare_0")
save(from_rows(hare_top + ["..KHHHHHHK..", ".KHK....KHK.", ".KK......KK."]), "hare_1")


# ---------------- Ground tile (seamless) ----------------
def ground():
    n = 128
    img = Image.new("RGBA", (n, n))
    rnd = random.Random(3)
    waves = [(rnd.randint(1, 4), rnd.randint(1, 4), rnd.random() * 6.28, rnd.random() * 6.28) for _ in range(6)]
    for y in range(n):
        for x in range(n):
            v = 0.0
            for fx, fy, px, py in waves:
                v += math.sin(2 * math.pi * fx * x / n + px) * math.cos(2 * math.pi * fy * y / n + py)
            v /= len(waves)
            if v > 0.25:
                c = (247, 250, 254)
            elif v > -0.15:
                c = (240, 244, 250)
            elif v > -0.4:
                c = (233, 239, 248)
            else:
                c = (227, 234, 245)
            img.putpixel((x, y), c + (255,))
    for _ in range(40):
        x, y = rnd.randrange(n), rnd.randrange(n)
        img.putpixel((x, y), (255, 255, 255, 255))
    for _ in range(25):
        x, y = rnd.randrange(n), rnd.randrange(n)
        img.putpixel((x, y), (200, 212, 232, 255))
    save(img, "snow_tile")


ground()


# ---------------- Pine tree ----------------
def pine():
    w, h = 30, 44
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = w // 2
    d.rectangle([cx - 2, h - 9, cx + 1, h - 2], fill=(100, 64, 36, 255))
    d.rectangle([cx + 1, h - 9, cx + 1, h - 2], fill=(76, 48, 28, 255))
    tiers = [(h - 8, 14, 15), (h - 19, 11, 13), (h - 29, 8, 12)]
    for base, half, height in tiers:
        top = base - height
        for y in range(top, base + 1):
            t = (y - top) / height
            hw = int(round(half * t))
            for x in range(cx - hw, cx + hw):
                shade = (34, 82, 58) if x < cx - 1 else (26, 64, 48)
                if (x + y) % 5 == 0:
                    shade = (48, 104, 72)
                img.putpixel((x, y), shade + (255,))
            # snow on the upper part and left edge of each tier
            if t < 0.45:
                for x in range(cx - hw, cx + max(hw - 1, 0)):
                    img.putpixel((x, y), (242, 246, 252, 255))
            elif hw > 1 and y % 3 == 0:
                img.putpixel((cx - hw, y), (230, 238, 250, 255))
                img.putpixel((cx - hw + 1, y), (230, 238, 250, 255))
    save(outline(img), "pine")


pine()


# ---------------- Rocks, sticks, drifts, bushes, meat ----------------
def blob(w, h, color, light, dark, seed, flat_bottom=True):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    rnd = random.Random(seed)
    cx, cy = w / 2, h / 2 + (2 if flat_bottom else 0)
    for y in range(h):
        for x in range(w):
            dx, dy = (x + 0.5 - cx) / (w / 2), (y + 0.5 - cy) / (h / 2)
            ang = math.atan2(dy, dx)
            r = 1.0 + 0.05 * math.sin(ang * 4 + seed) + 0.03 * math.sin(ang * 7 + seed * 2)
            if dx * dx + dy * dy <= r * r * 0.78 and not (flat_bottom and y > h - 2):
                c = color
                if dy < -0.35 + rnd.random() * 0.05:
                    c = light
                elif dx > 0.45 or dy > 0.55:
                    c = dark
                img.putpixel((x, y), c + (255,))
    return img


rock = blob(32, 22, (118, 120, 130), (150, 152, 162), (88, 90, 102), 1)
cap = ImageDraw.Draw(rock)
for y in range(2, 7):
    for x in range(7, 24):
        if rock.getpixel((x, y))[3] > 0 and (y < 5 or x % 3):
            rock.putpixel((x, y), (242, 246, 252, 255))
empty = outline(rock.copy())
for p in [(8, 11), (14, 13), (20, 10), (24, 14), (11, 16)]:
    for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1), (2, 1)):
        rock.putpixel((p[0] + dx, p[1] + dy), (34, 34, 46, 255))
    rock.putpixel(p, (90, 96, 120, 255))
save(outline(rock), "flint_rock")
save(empty, "flint_rock_empty")

stone = blob(10, 8, (124, 126, 136), (164, 166, 176), (92, 94, 104), 4)
save(outline(stone), "stone")

sticks = Image.new("RGBA", (18, 10), (0, 0, 0, 0))
sd = ImageDraw.Draw(sticks)
sd.line([(1, 7), (16, 3)], fill=(120, 80, 42, 255), width=2)
sd.line([(2, 2), (15, 8)], fill=(96, 62, 32, 255), width=2)
sd.line([(5, 8), (12, 1)], fill=(140, 96, 52, 255), width=1)
save(outline(sticks), "sticks")

drift = blob(30, 16, (226, 234, 247), (250, 252, 255), (196, 212, 236), 7)
save(outline(drift, (176, 194, 224, 255)), "snow_drift")


def bush(berries):
    img = Image.new("RGBA", (24, 20), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for (x, y, r, c) in [(7, 12, 6, (30, 74, 44)), (16, 12, 6, (26, 64, 40)), (11, 7, 6, (40, 92, 56))]:
        d.ellipse([x - r, y - r, x + r, y + r], fill=c + (255,))
    d.ellipse([8, 1, 15, 5], fill=(242, 246, 252, 255))
    if berries:
        for (x, y) in [(5, 10), (9, 14), (15, 9), (18, 14), (12, 11)]:
            d.rectangle([x, y, x + 1, y + 1], fill=(214, 30, 54, 255))
            img.putpixel((x, y), (255, 120, 130, 255))
    return outline(img)


save(bush(True), "bush_berries")
save(bush(False), "bush_empty")

meat = Image.new("RGBA", (16, 10), (0, 0, 0, 0))
md = ImageDraw.Draw(meat)
md.ellipse([0, 1, 11, 9], fill=(186, 60, 70, 255))
md.ellipse([2, 2, 7, 5], fill=(220, 110, 116, 255))
md.line([(10, 5), (14, 7)], fill=(240, 232, 214, 255), width=2)
save(outline(meat), "meat")

# ---------------- Campfire ----------------
base = Image.new("RGBA", (26, 14), (0, 0, 0, 0))
bd = ImageDraw.Draw(base)
for i in range(9):
    a = math.tau * i / 9
    x, y = 13 + math.cos(a) * 11, 8 + math.sin(a) * 4.5
    bd.ellipse([x - 2, y - 2, x + 2, y + 1], fill=(120, 122, 132, 255))
bd.line([(5, 10), (21, 5)], fill=(120, 78, 40, 255), width=3)
bd.line([(5, 5), (21, 10)], fill=(92, 58, 30, 255), width=3)
save(outline(base), "fire_base")
ash = base.copy()
ImageDraw.Draw(ash).ellipse([8, 5, 18, 11], fill=(70, 70, 76, 255))
save(outline(ash), "fire_ash")
for f in range(3):
    fl = Image.new("RGBA", (14, 20), (0, 0, 0, 0))
    rnd = random.Random(f + 10)
    for y in range(20):
        t = y / 19
        hw = 6 * math.sin(t * math.pi * 0.95) * (0.6 + 0.4 * t)
        off = math.sin(y * 0.7 + f * 2) * (1.5 * (1 - t))
        for x in range(14):
            dx = abs(x + 0.5 - 7 - off)
            if dx <= hw:
                inner = dx <= hw * 0.45 and t > 0.35
                c = (255, 226, 110) if inner else (255, 120, 30) if dx < hw * 0.8 else (214, 60, 20)
                if y < 4 and rnd.random() < 0.5:
                    continue
                fl.putpixel((x, y), c + (255,))
    save(fl, f"flame_{f}")

# ---------------- Igloo ----------------
def igloo():
    w, h = 80, 58
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cx, base = w / 2, h - 6
    rx, ry = 37, 46
    for y in range(h):
        for x in range(w):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - base) / ry
            if dy <= 0 and dx * dx + dy * dy <= 1:
                light = -dx * 0.6 - dy * 0.4
                c = (246, 249, 255) if light > 0.25 else (232, 240, 251) if light > -0.1 else (210, 222, 242)
                img.putpixel((x, y), c + (255,))
    # block rows
    line = (180, 198, 226, 255)
    for row in range(1, 5):
        yy = base - row * 10
        for x in range(w):
            if img.getpixel((x, int(yy)))[3] > 0:
                img.putpixel((x, int(yy)), line)
        step = 12 - row
        for x in range(int(cx - rx), int(cx + rx), step):
            xx = x + (row % 2) * step // 2
            for y in range(int(yy), int(yy + 10)):
                if 0 <= xx < w and y < base and img.getpixel((xx, y))[3] > 0:
                    img.putpixel((xx, y), line)
    # base row lines
    for x in range(int(cx - rx), int(cx + rx), 10):
        for y in range(int(base - 10), int(base)):
            if img.getpixel((x, y))[3] > 0:
                img.putpixel((x, y), line)
    # entrance tunnel
    d = ImageDraw.Draw(img)
    d.rectangle([cx - 11, base - 14, cx + 11, base + 5], fill=(236, 243, 252, 255))
    d.ellipse([cx - 11, base - 24, cx + 11, base - 4], fill=(236, 243, 252, 255))
    d.rectangle([cx - 7, base - 8, cx + 7, base + 5], fill=(36, 44, 66, 255))
    d.ellipse([cx - 7, base - 16, cx + 7, base - 2], fill=(36, 44, 66, 255))
    return outline(img)


save(igloo(), "igloo")

block = Image.new("RGBA", (10, 14), (236, 243, 252, 255))
bdraw = ImageDraw.Draw(block)
bdraw.rectangle([0, 0, 9, 3], fill=(250, 252, 255, 255))
bdraw.rectangle([7, 4, 9, 13], fill=(208, 220, 240, 255))
save(outline(block), "snow_block")

# ---------------- Stump ----------------
stump = Image.new("RGBA", (14, 9), (0, 0, 0, 0))
sdr = ImageDraw.Draw(stump)
sdr.rectangle([1, 3, 12, 8], fill=(100, 64, 36, 255))
sdr.rectangle([9, 3, 12, 8], fill=(76, 48, 28, 255))
sdr.ellipse([1, 0, 12, 5], fill=(196, 160, 110, 255))
sdr.ellipse([4, 1, 9, 4], fill=(170, 130, 84, 255))
save(outline(stump), "stump")

# ---------------- Polar bear ----------------
PAL.update({"O": (236, 232, 214, 255), "o": (204, 198, 176, 255), "Q": (40, 36, 34, 255)})
bear_body = [
    "......................KK.....",
    ".....................KoOK....",
    "..........KKKKKKKKKKKOOOOK...",
    "......KKKKOOOOOOOOOOOOOOOOK..",
    ".....KOOOOOOOOOOOOOOOOOOQOOK.",
    "....KOOOOOOOOOOOOOOOOOOOOOOOK",
    "...KOOOOOOOOOOOOOOOOOOOOOOQQK",
    "..KoOOOOOOOOOOOOOOOOOOOOOOKK.",
    "..KoOOOOOOOOOOOOOOOOOOOOK....",
    "..KooOOOOOOOOOOOOOOOOOOoK....",
    "...KooooOOOOOOOOOOOooooK.....",
]
bear_legs = [
    ["...KooK.KooK......KooK.KooK..", "...KooK.KooK......KooK.KooK..", "...KQQK.KQQK......KQQK.KQQK..", "...KKKK.KKKK......KKKK.KKKK.."],
    ["..KooK...KooK....KooK...KooK.", ".KooK.....KooK..KooK.....KooK", ".KQQK.....KQQK..KQQK.....KQQK", ".KKKK.....KKKK..KKKK.....KKKK"],
]
for i, lg in enumerate(bear_legs):
    save(from_rows(bear_body + lg), f"bear_{i}")


# ---------------- Cabin stages ----------------
def log_rows(img, x0, y0, x1, y1, horizontal=True):
    d = ImageDraw.Draw(img)
    light, mid, dark = (150, 104, 62, 255), (122, 82, 46, 255), (88, 58, 32, 255)
    y = y0
    while y + 5 <= y1:
        d.rectangle([x0, y, x1, y + 4], fill=mid)
        d.line([(x0, y), (x1, y)], fill=light)
        d.line([(x0, y + 4), (x1, y + 4)], fill=dark)
        for x in range(x0 + 7, x1, 13):
            img.putpixel((x, y + 2), dark)
        d.ellipse([x0 - 2, y, x0 + 2, y + 4], fill=(196, 160, 110, 255))
        d.ellipse([x1 - 2, y, x1 + 2, y + 4], fill=(196, 160, 110, 255))
        y += 5


W, H = 100, 84
floor = Image.new("RGBA", (W, H), (0, 0, 0, 0))
fd = ImageDraw.Draw(floor)
fd.rectangle([4, 40, 95, 79], fill=(132, 92, 54, 255))
for x in range(4, 96, 7):
    fd.line([(x, 40), (x, 79)], fill=(104, 70, 40, 255))
fd.rectangle([4, 40, 95, 79], outline=K)
save(floor, "cabin_floor")

walls = floor.copy()
log_rows(walls, 4, 30, 95, 44)          # back wall
for x0 in (4, 91):                       # side walls
    ImageDraw.Draw(walls).rectangle([x0, 30, x0 + 4, 79], fill=(122, 82, 46, 255), outline=(88, 58, 32, 255))
log_rows(walls, 4, 65, 40, 80)           # front wall left of door
log_rows(walls, 60, 65, 95, 80)          # front wall right of door
save(outline(walls), "cabin_walls")

full = Image.new("RGBA", (W, H), (0, 0, 0, 0))
log_rows(full, 4, 44, 95, 80)
fdr = ImageDraw.Draw(full)
fdr.polygon([(0, 46), (50, 6), (99, 46)], fill=(96, 62, 36, 255))
for i in range(0, 40, 4):
    fdr.line([(50 - i * 1.25, 6 + i), (50 + i * 1.25, 6 + i)], fill=(110, 72, 42, 255))
fdr.polygon([(0, 46), (50, 6), (99, 46), (99, 42), (50, 10), (0, 42)], fill=(242, 246, 252, 255))
fdr.polygon([(10, 38), (50, 6), (90, 38), (82, 38), (50, 13), (18, 38)], fill=(242, 246, 252, 255))
fdr.rectangle([42, 56, 58, 80], fill=(70, 44, 24, 255))
fdr.rectangle([43, 57, 57, 79], fill=(96, 62, 34, 255))
full.putpixel((55, 68), (230, 200, 90, 255))
fdr.rectangle([14, 54, 28, 64], fill=(60, 74, 100, 255))
fdr.rectangle([72, 54, 86, 64], fill=(60, 74, 100, 255))
save(outline(full), "cabin_roof")
lit = full.copy()
ld = ImageDraw.Draw(lit)
ld.rectangle([14, 54, 28, 64], fill=(255, 196, 90, 255))
ld.rectangle([72, 54, 86, 64], fill=(255, 196, 90, 255))
ld.rectangle([70, 8, 78, 26], fill=(110, 110, 118, 255))
save(outline(lit), "cabin_lit")
chim = full.copy()
ImageDraw.Draw(chim).rectangle([70, 8, 78, 26], fill=(110, 110, 118, 255))
save(outline(chim), "cabin_stove")

# ---------------- Iron rock, hide, bone ----------------
iron = blob(30, 20, (104, 96, 96), (140, 130, 126), (78, 70, 70), 9)
for y in range(1, 5):
    for x in range(8, 22):
        if iron.getpixel((x, y))[3] > 0 and (y < 4 or x % 2):
            iron.putpixel((x, y), (242, 246, 252, 255))
for p in [(7, 10), (13, 8), (19, 12), (11, 14), (22, 9)]:
    for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
        iron.putpixel((p[0] + dx, p[1] + dy), (176, 92, 44, 255))
    iron.putpixel(p, (220, 130, 70, 255))
save(outline(iron), "iron_rock")
iron_empty = blob(30, 20, (104, 96, 96), (140, 130, 126), (78, 70, 70), 9)
save(outline(iron_empty), "iron_rock_empty")

hide = Image.new("RGBA", (14, 10), (0, 0, 0, 0))
hd = ImageDraw.Draw(hide)
hd.polygon([(1, 2), (5, 0), (9, 1), (13, 3), (12, 8), (7, 9), (2, 8), (0, 5)], fill=(170, 160, 150, 255))
hd.polygon([(3, 3), (8, 2), (10, 5), (6, 7), (3, 6)], fill=(200, 192, 182, 255))
save(outline(hide), "hide")

bone = Image.new("RGBA", (12, 6), (0, 0, 0, 0))
bnd = ImageDraw.Draw(bone)
bnd.line([(2, 3), (9, 3)], fill=(236, 230, 210, 255), width=2)
for cx in (1, 10):
    bnd.ellipse([cx - 1, 0, cx + 1, 2], fill=(236, 230, 210, 255))
    bnd.ellipse([cx - 1, 3, cx + 1, 5], fill=(236, 230, 210, 255))
save(outline(bone), "bone")

# ---------------- Base structures, food, loot sites ----------------
WOOD, WOOD_D, WOOD_L = (122, 82, 46, 255), (88, 58, 32, 255), (150, 104, 62, 255)
SNOWC = (242, 246, 252, 255)


def canvas(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


img, d = canvas(30, 20)
d.rectangle([1, 4, 28, 8], fill=WOOD_L)
d.line([(1, 8), (28, 8)], fill=WOOD_D)
for x in (3, 25):
    d.rectangle([x, 9, x + 2, 19], fill=WOOD)
d.rectangle([8, 1, 13, 4], fill=(120, 122, 132, 255))
d.line([(17, 3), (24, 1)], fill=(90, 90, 100, 255), width=2)
d.rectangle([2, 3, 27, 3], fill=SNOWC)
save(outline(img), "workbench")

img, d = canvas(20, 16)
d.rectangle([1, 5, 18, 15], fill=WOOD)
d.rectangle([1, 2, 18, 6], fill=WOOD_L)
d.line([(1, 6), (18, 6)], fill=WOOD_D)
d.rectangle([8, 6, 11, 9], fill=(200, 170, 80, 255))
d.rectangle([1, 1, 18, 2], fill=SNOWC)
save(outline(img), "chest")


def rack(full):
    img, d = canvas(28, 24)
    for x in (2, 24):
        d.line([(x, 23), (x + 1, 2)], fill=WOOD, width=2)
    d.line([(1, 4), (26, 4)], fill=WOOD_L, width=2)
    d.line([(1, 11), (26, 11)], fill=WOOD_L, width=1)
    if full:
        for x in range(5, 23, 5):
            d.rectangle([x, 5, x + 2, 10], fill=(150, 50, 50, 255))
            d.rectangle([x, 12, x + 2, 16], fill=(120, 40, 40, 255))
    return outline(img)


save(rack(False), "rack")
save(rack(True), "rack_full")

img, d = canvas(14, 10)
d.line([(2, 9), (7, 1)], fill=WOOD, width=1)
d.line([(12, 9), (7, 1)], fill=WOOD, width=1)
d.ellipse([3, 5, 11, 9], outline=(200, 190, 160, 255))
save(outline(img), "snare")
img2 = Image.open(os.path.join(OUT, "hare_0.png")).copy()
caught = Image.new("RGBA", (16, 13), (0, 0, 0, 0))
caught.alpha_composite(img2.rotate(90, expand=True).crop((0, 0, 13, 13)).resize((10, 10)), (3, 3))
caught.alpha_composite(Image.open(os.path.join(OUT, "snare.png")), (0, 0))
save(caught, "snare_caught")

img, d = canvas(20, 22)
for x in (1, 8, 15):
    d.rectangle([x, 3, x + 3, 21], fill=WOOD)
    d.polygon([(x, 3), (x + 1.5, 0), (x + 3, 3)], fill=WOOD_L)
    d.rectangle([x, 3, x + 3, 4], fill=SNOWC)
d.rectangle([0, 8, 19, 10], fill=WOOD_D)
d.rectangle([0, 15, 19, 17], fill=WOOD_D)
save(outline(img), "fence")


def beacon(lit):
    img, d = canvas(26, 40)
    d.line([(4, 39), (13, 6)], fill=WOOD, width=2)
    d.line([(22, 39), (13, 6)], fill=WOOD, width=2)
    d.line([(7, 28), (19, 28)], fill=WOOD_L, width=2)
    d.line([(10, 18), (16, 18)], fill=WOOD_L, width=2)
    d.rectangle([9, 30, 17, 38], fill=(80, 84, 96, 255))
    d.rectangle([11, 32, 15, 34], fill=(120, 220, 140, 255) if lit else (60, 70, 60, 255))
    d.line([(13, 6), (13, 0)], fill=(160, 160, 170, 255))
    d.ellipse([10, 0, 16, 6], fill=(255, 90, 60, 255) if lit else (110, 60, 60, 255))
    return outline(img)


save(beacon(False), "beacon")
save(beacon(True), "beacon_lit")

img, d = canvas(14, 8)
d.polygon([(1, 4), (4, 1), (10, 1), (13, 4), (10, 7), (4, 7)], fill=(150, 170, 190, 255))
d.polygon([(10, 4), (13, 1), (13, 7)], fill=(130, 150, 170, 255))
d.point((4, 3), fill=(20, 20, 30, 255))
save(outline(img), "fish")

img, d = canvas(12, 8)
d.rectangle([1, 1, 10, 6], fill=(120, 60, 40, 255))
d.line([(2, 3), (9, 3)], fill=(150, 80, 56, 255))
save(outline(img), "jerky")

img, d = canvas(12, 10)
d.rectangle([1, 2, 10, 9], fill=(60, 100, 70, 255))
d.rectangle([3, 4, 5, 6], fill=(220, 190, 80, 255))
d.rectangle([7, 4, 8, 8], fill=(180, 180, 190, 255))
d.line([(9, 2), (11, 0)], fill=(200, 200, 210, 255))
save(outline(img), "radio_part")


def crate(opened):
    img, d = canvas(18, 14)
    d.rectangle([1, 3, 16, 13], fill=WOOD)
    d.line([(1, 3), (16, 13)], fill=WOOD_D)
    d.line([(16, 3), (1, 13)], fill=WOOD_D)
    if opened:
        d.rectangle([1, 0, 16, 3], fill=WOOD_D)
        d.rectangle([3, 4, 14, 6], fill=(40, 30, 20, 255))
    else:
        d.rectangle([1, 2, 16, 3], fill=WOOD_L)
        d.rectangle([1, 1, 16, 1], fill=SNOWC)
    return outline(img)


save(crate(False), "crate")
save(crate(True), "crate_open")

# shipwreck frozen in ice
img, d = canvas(110, 54)
d.polygon([(4, 30), (96, 22), (108, 30), (96, 46), (16, 50)], fill=(86, 60, 40, 255))
d.polygon([(4, 30), (96, 22), (108, 30), (100, 32), (10, 36)], fill=(110, 78, 50, 255))
for x in range(14, 96, 8):
    d.line([(x, 33), (x - 2, 48)], fill=(70, 48, 30, 255))
d.line([(50, 28), (40, 0)], fill=(90, 64, 40, 255), width=3)
d.line([(30, 10), (52, 6)], fill=(90, 64, 40, 255), width=2)
d.polygon([(0, 46), (30, 40), (70, 44), (110, 40), (110, 54), (0, 54)], fill=(200, 222, 240, 255))
d.polygon([(20, 28), (60, 24), (90, 22), (60, 27)], fill=SNOWC)
save(outline(img), "shipwreck")

# trapper's camp: tent and a cold fire pit
img, d = canvas(56, 40)
d.polygon([(4, 38), (26, 4), (48, 38)], fill=(150, 130, 90, 255))
d.polygon([(26, 4), (48, 38), (40, 38)], fill=(120, 100, 70, 255))
d.polygon([(20, 38), (26, 22), (32, 38)], fill=(50, 40, 30, 255))
d.polygon([(14, 20), (26, 4), (36, 20), (26, 10)], fill=SNOWC)
d.ellipse([44, 32, 55, 38], fill=(90, 90, 96, 255))
save(outline(img), "camp")

# weather station: mast and hut
img, d = canvas(48, 64)
d.rectangle([4, 40, 30, 62], fill=(150, 156, 166, 255))
d.rectangle([4, 36, 30, 41], fill=SNOWC)
d.rectangle([13, 50, 20, 62], fill=(80, 84, 96, 255))
d.line([(38, 62), (38, 2)], fill=(120, 124, 134, 255), width=2)
for y in range(8, 60, 8):
    d.line([(35, y), (41, y + 4)], fill=(120, 124, 134, 255))
d.ellipse([33, 0, 43, 6], fill=(200, 60, 50, 255))
d.line([(26, 30), (44, 20)], fill=(120, 124, 134, 255))
save(outline(img), "station")

print("sprites written to", os.path.abspath(OUT))
