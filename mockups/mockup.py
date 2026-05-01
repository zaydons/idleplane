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

    assigned = tab_index >= 3  # tabs 3+ show assigned state
    real_idx = tab_index if tab_index < 3 else tab_index - 3
    if real_idx == 0:
        _draw_fleet(d, cy, assigned)
    elif real_idx == 1:
        if tab_index == 4:
            _draw_routes_picker(d, cy)
        else:
            _draw_routes(d, cy, assigned)
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


def _small_btn(d, x, y, label, color):
    bbox = d.textbbox((0, 0), label, font=F10)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    pad_x, pad_y = 6, 3
    bx0, by0 = x, y - pad_y
    bx1, by1 = x + tw + pad_x * 2, y + th + pad_y
    bg = tuple(int(c * 0.15) for c in color[:3]) + (255,)
    d.rectangle([bx0, by0, bx1, by1], fill=color[:3] + (38,))
    d.rectangle([bx0, by0, bx1, by1], outline=color, width=1)
    d.text((bx0 + pad_x, y), label, font=F10, fill=color)
    return bx1  # right edge

def _draw_fleet(d, cy, assigned=False):
    d.text((8, cy + 6), "FLEET", font=F12, fill=C_ACCENT)
    y = cy + 26

    cx0, cx1 = 8, W - 8
    card_h = 88
    _card_bg(d, cx0, y, cx1, y + card_h)
    iy = y + 6
    ix = cx0 + 8

    d.text((ix, iy), "Cessna 208 Caravan", font=F11, fill=C_TEXT); iy += 16
    status_text = "Seats: 9  |  Status: Assigned (PHL → AVP)" if assigned else "Seats: 9  |  Status: Grounded"
    status_color = C_ACCENT if assigned else C_DIM
    d.text((ix, iy), status_text, font=F10, fill=status_color); iy += 14

    d.line([ix, iy + 2, cx1 - 8, iy + 2], fill=C_BORDER); iy += 8

    cond_text = "Condition  %s  100%%" % bar(100)
    d.text((ix, iy), cond_text, font=F10, fill=C_GREEN); iy += 14
    d.text((ix, iy), "No repairs needed", font=F10, fill=C_DIM)


def _draw_routes(d, cy, assigned=False):
    d.text((8, cy + 6), "ROUTES", font=F12, fill=C_ACCENT)
    y = cy + 26

    cx0, cx1 = 8, W - 8
    card_h = 96
    _card_bg(d, cx0, y, cx1, y + card_h)
    iy = y + 6
    ix = cx0 + 8

    d.text((ix, iy), "PHL  →  AVP", font=F12, fill=C_TEXT); iy += 17
    d.text((ix, iy), "Philadelphia → Wilkes-Barre", font=F10, fill=C_DIM); iy += 14
    d.text((ix, iy), "81 mi  |  Ticket: $89", font=F10, fill=C_DIM); iy += 14

    d.line([ix, iy + 2, cx1 - 8, iy + 2], fill=C_BORDER); iy += 8

    if assigned:
        aircraft_text = "Aircraft: Cessna 208 Caravan"
        d.text((ix, iy), aircraft_text, font=F10, fill=C_GREEN)
        btn_x = cx1 - 8 - 72
        _small_btn(d, btn_x, iy, "Unassign", C_RED)
    else:
        d.text((ix, iy), "Aircraft: none", font=F10, fill=C_YELLOW)
        btn_x = cx1 - 8 - 56
        _small_btn(d, btn_x, iy, "Assign", C_ACCENT)


def _draw_routes_picker(d, cy):
    """Routes tab with the assign picker open."""
    _draw_routes(d, cy, assigned=False)
    # Dim overlay
    overlay = Image.new("RGBA", (W, CONTENT_H), (0, 5, 20, 210))
    base = Image.new("RGB", (W, CONTENT_H))
    base.paste(overlay, mask=overlay.split()[3])
    # We'll just draw a darkened rectangle
    d.rectangle([0, cy, W-1, cy + CONTENT_H - 1], fill=(2, 6, 16))
    d.text((8, cy + 6), "ROUTES", font=F12, fill=C_ACCENT)
    # Picker card
    card_w, card_h = 240, 90
    cx = (W - card_w) // 2
    card_y = cy + (CONTENT_H - card_h) // 2
    d.rectangle([cx, card_y, cx + card_w, card_y + card_h], fill=C_CARD)
    d.rectangle([cx, card_y, cx + card_w, card_y + card_h], outline=C_ACCENT, width=1)
    iy = card_y + 8
    ix = cx + 10
    # Title
    title = "SELECT AIRCRAFT"
    bbox = d.textbbox((0,0), title, font=F11)
    tw = bbox[2] - bbox[0]
    d.text((cx + (card_w - tw) // 2, iy), title, font=F11, fill=C_ACCENT); iy += 18
    d.line([ix, iy, cx + card_w - 10, iy], fill=C_BORDER); iy += 8
    # Plane option
    d.text((ix, iy), "Cessna 208 Caravan", font=F10, fill=C_TEXT); iy += 18
    d.line([ix, iy, cx + card_w - 10, iy], fill=C_BORDER); iy += 8
    # Cancel
    cancel = "Cancel"
    bbox = d.textbbox((0,0), cancel, font=F10)
    tw = bbox[2] - bbox[0]
    d.text((cx + (card_w - tw) // 2, iy), cancel, font=F10, fill=C_DIM)


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


out_dir = "/home/user/idleplane/mockups"

# Unassigned state (original)
for i, name in enumerate(["fleet", "routes", "finances"]):
    draw_tab(i).save(f"{out_dir}/mockup_{name}.png")

# Assigned state
draw_tab(3).save(f"{out_dir}/mockup_fleet_assigned.png")
draw_tab(4).save(f"{out_dir}/mockup_routes_picker.png")
draw_tab(5).save(f"{out_dir}/mockup_routes_assigned.png")

print("Done.")
