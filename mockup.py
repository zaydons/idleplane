"""Renders a pixel-accurate mockup of all three tabs at 640x360."""
from PIL import Image, ImageDraw, ImageFont
import os

W, H = 640, 360
TOP_H = 22
TAB_H = 26
CONTENT_H = H - TOP_H - TAB_H  # 312

# Palette
C_BG      = (8,   13,  26)
C_BAR     = (6,   11,  21)
C_CARD    = (13,  21,  37)
C_BORDER  = (26,  40,  64)
C_TEXT    = (192, 208, 232)
C_DIM     = (72,  88,  112)
C_ACCENT  = (80,  144, 216)
C_GOLD    = (232, 184, 48)
C_GREEN   = (56,  200, 112)
C_YELLOW  = (232, 184, 48)
C_RED     = (216, 72,  56)
C_TAB_ON  = (24,  48,  96)
C_TAB_OFF = (10,  20,  40)

# Try to load a monospace font; fall back to default
def load_font(size):
    for path in [
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf",
        "/usr/share/fonts/truetype/freefont/FreeMono.ttf",
    ]:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()

F10 = load_font(10)
F11 = load_font(11)
F12 = load_font(12)

def bar(pct, width=14):
    n = round(pct / 100 * width)
    return "█" * n + "░" * (width - n)

def draw_tab(tab_index):
    img = Image.new("RGB", (W, H), C_BG)
    d = ImageDraw.Draw(img)

    # ── Top bar ──────────────────────────────────────────────────────────
    d.rectangle([0, 0, W-1, TOP_H-1], fill=C_BAR)
    d.line([0, TOP_H-1, W-1, TOP_H-1], fill=C_BORDER, width=1)
    d.text((8, 5),  "Sky Haven Airways", font=F11, fill=C_ACCENT)
    cash = "$25,000"
    bbox = d.textbbox((0, 0), cash, font=F11)
    tw = bbox[2] - bbox[0]
    d.text((W - 8 - tw, 5), cash, font=F11, fill=C_GOLD)

    # ── Content area ─────────────────────────────────────────────────────
    cy = TOP_H
    d.rectangle([0, cy, W-1, cy + CONTENT_H - 1], fill=C_BG)

    if tab_index == 0:
        _draw_fleet(d, cy)
    elif tab_index == 1:
        _draw_routes(d, cy)
    else:
        _draw_finances(d, cy)

    # ── Tab bar ──────────────────────────────────────────────────────────
    ty = H - TAB_H
    d.rectangle([0, ty, W-1, H-1], fill=C_BAR)
    d.line([0, ty, W-1, ty], fill=C_BORDER, width=1)

    tabs = ["Fleet", "Routes", "Finances"]
    tab_w = W // len(tabs)
    for i, name in enumerate(tabs):
        x0 = i * tab_w
        x1 = x0 + tab_w - 1
        bg = C_TAB_ON if i == tab_index else C_TAB_OFF
        d.rectangle([x0, ty, x1, H-1], fill=bg)
        if i == tab_index:
            d.line([x0, ty, x1, ty], fill=C_ACCENT, width=2)
        else:
            d.line([x0, ty, x1, ty], fill=C_BORDER, width=1)
        if i > 0:
            d.line([x0, ty, x0, H-1], fill=C_BORDER, width=1)
        color = C_ACCENT if i == tab_index else C_DIM
        bbox = d.textbbox((0,0), name, font=F10)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        tx = x0 + (tab_w - tw) // 2
        ty2 = ty + (TAB_H - th) // 2
        d.text((tx, ty2), name, font=F10, fill=color)

    return img


def _card_bg(d, x0, y0, x1, y1):
    d.rectangle([x0, y0, x1, y1], fill=C_CARD)
    d.rectangle([x0, y0, x1, y1], outline=C_BORDER, width=1)


def _draw_fleet(d, cy):
    # Section header
    d.text((8, cy + 6), "FLEET", font=F12, fill=C_ACCENT)
    y = cy + 26

    # Plane card
    cx0, cx1 = 8, W - 8
    card_h = 88
    _card_bg(d, cx0, y, cx1, y + card_h)
    iy = y + 6
    ix = cx0 + 8

    d.text((ix, iy), "Cessna 208 Caravan", font=F11, fill=C_TEXT); iy += 16
    d.text((ix, iy), "Seats: 9  |  Status: Grounded",  font=F10, fill=C_DIM);  iy += 14

    # Separator
    d.line([ix, iy + 2, cx1 - 8, iy + 2], fill=C_BORDER); iy += 8

    cond_text = "Condition  %s  100%%" % bar(100)
    d.text((ix, iy), cond_text, font=F10, fill=C_GREEN); iy += 14
    d.text((ix, iy), "No repairs needed", font=F10, fill=C_DIM)


def _draw_routes(d, cy):
    d.text((8, cy + 6), "ROUTES", font=F12, fill=C_ACCENT)
    y = cy + 26

    cx0, cx1 = 8, W - 8
    card_h = 88
    _card_bg(d, cx0, y, cx1, y + card_h)
    iy = y + 6
    ix = cx0 + 8

    d.text((ix, iy), "PHL  →  AVP", font=F12, fill=C_TEXT); iy += 17
    d.text((ix, iy), "Philadelphia → Wilkes-Barre", font=F10, fill=C_DIM); iy += 14
    d.text((ix, iy), "81 mi  |  Ticket: $89", font=F10, fill=C_DIM); iy += 14

    d.line([ix, iy + 2, cx1 - 8, iy + 2], fill=C_BORDER); iy += 8

    d.text((ix, iy), "Aircraft: none assigned", font=F10, fill=C_YELLOW)


def _draw_finances(d, cy):
    d.text((8, cy + 6), "FINANCES", font=F12, fill=C_ACCENT)
    y = cy + 26

    cx0, cx1 = 8, W - 8
    card_h = 100
    _card_bg(d, cx0, y, cx1, y + card_h)
    iy = y + 6
    ix = cx0 + 8

    def row(label, value, color):
        nonlocal iy
        d.text((ix, iy), label, font=F10, fill=C_DIM)
        bbox = d.textbbox((0,0), value, font=F10)
        tw = bbox[2] - bbox[0]
        d.text((cx1 - 8 - tw, iy), value, font=F10, fill=color)
        iy += 14

    def sep():
        nonlocal iy
        d.line([ix, iy + 2, cx1 - 8, iy + 2], fill=C_BORDER)
        iy += 8

    row("Cash on hand", "$25,000", C_GOLD)
    sep()
    row("Revenue",  "$0 / flight", C_GREEN)
    row("Expenses", "$0 / flight", C_RED)
    sep()
    row("Net",      "$0 / flight", C_DIM)


# Render all three tabs side by side in a wide strip + individual saves
tabs = ["fleet", "routes", "finances"]
images = [draw_tab(i) for i in range(3)]

# Save individual tabs
out_dir = "/home/user/idleplane"
for i, name in enumerate(tabs):
    images[i].save(f"{out_dir}/mockup_{name}.png")

# Also save a 3-up comparison (3 × 640 wide)
strip = Image.new("RGB", (W * 3, H), C_BG)
for i, img in enumerate(images):
    strip.paste(img, (i * W, 0))
strip.save(f"{out_dir}/mockup_all.png")

print("Saved mockup_fleet.png, mockup_routes.png, mockup_finances.png, mockup_all.png")
