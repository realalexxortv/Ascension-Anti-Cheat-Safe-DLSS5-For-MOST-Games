#!/usr/bin/env python3
"""Local game picker for Ascension. Lists installed Steam games and lets the
user tick the ones that should get the Vulkan layer via a Steam launch option.
Nothing here writes into a game directory.
"""

import os
import sys

SKIP_NAMES = (
    "proton ",
    "steam linux runtime",
    "steamworks common redistributables",
)
SKIP_APPIDS = {
    "228980",
    "1070560",
    "1391110",
    "1628350",
    "1493710",
}


def unescape(value):
    out = []
    i = 0
    while i < len(value):
        if value[i] == "\\" and i + 1 < len(value):
            out.append(value[i + 1])
            i += 2
        else:
            out.append(value[i])
            i += 1
    return "".join(out)


class Parser:
    def __init__(self, text):
        self.s = text
        self.i = 0
        self.n = len(text)

    def peek(self):
        return self.s[self.i] if self.i < self.n else ""

    def skip(self):
        while self.i < self.n and self.s[self.i] in " \t\r\n":
            self.i += 1

    def string(self):
        self.skip()
        if self.peek() != '"':
            raise ValueError("string")
        self.i += 1
        chars = []
        while self.i < self.n:
            c = self.s[self.i]
            if c == "\\":
                self.i += 1
                if self.i >= self.n:
                    break
                chars.append(self.s[self.i])
                self.i += 1
                continue
            if c == '"':
                self.i += 1
                return "".join(chars)
            chars.append(c)
            self.i += 1
        raise ValueError("unterminated")

    def value(self):
        self.skip()
        if self.peek() == '"':
            return ("str", self.string())
        if self.peek() == "{":
            return ("obj", self.obj())
        raise ValueError("value")

    def obj(self):
        self.i += 1
        items = []
        while True:
            self.skip()
            if self.peek() == "}":
                self.i += 1
                return items
            if self.i >= self.n:
                raise ValueError("unclosed")
            key = self.string()
            items.append((key, self.value()))


def parse_vdf(text):
    if text.startswith("\ufeff"):
        text = text[1:]
    parser = Parser(text)
    top = []
    while True:
        parser.skip()
        if parser.i >= parser.n:
            break
        key = parser.string()
        top.append((key, parser.value()))
    return top


def flat_manifest(path):
    try:
        raw = open(path, "rb").read()
    except OSError:
        return {}
    if b"\x00" in raw:
        return {}
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError:
        return {}
    try:
        top = parse_vdf(text)
    except ValueError:
        return {}
    fields = {}
    for key, val in top:
        if key == "AppState" and val[0] == "obj":
            for child, cval in val[1]:
                if cval[0] == "str":
                    fields[child] = cval[1]
    return fields


def library_paths(root):
    paths = []
    vdf = os.path.join(root, "steamapps", "libraryfolders.vdf")
    if os.path.isfile(vdf):
        try:
            raw = open(vdf, "rb").read()
            text = raw.decode("utf-8", "replace")
            top = parse_vdf(text)
        except (OSError, ValueError):
            top = []
        def walk(items):
            found = []
            for key, val in items:
                if key == "path" and val[0] == "str":
                    found.append(val[1])
                elif val[0] == "obj":
                    found.extend(walk(val[1]))
            return found
        for key, val in top:
            if val[0] == "obj":
                paths.extend(walk(val[1]))
    paths.append(root)
    out = []
    seen = set()
    for path in paths:
        path = os.path.expanduser(path)
        if not os.path.isdir(path):
            continue
        real = os.path.realpath(path)
        if real in seen:
            continue
        seen.add(real)
        out.append(real)
    return out


def enabled_ids(roots):
    found = set()
    seen = set()
    for root in roots:
        user = os.path.join(root, "userdata")
        if not os.path.isdir(user):
            continue
        for name in os.listdir(user):
            path = os.path.join(user, name, "config", "localconfig.vdf")
            if not os.path.isfile(path):
                continue
            real = os.path.realpath(path)
            if real in seen:
                continue
            seen.add(real)
            try:
                raw = open(path, "rb").read()
            except OSError:
                continue
            if b"\x00" in raw:
                continue
            try:
                text = raw.decode("utf-8")
                top = parse_vdf(text)
            except (UnicodeDecodeError, ValueError):
                continue
            found.update(apps_with_layer(top))
    return found


def apps_with_layer(items, path=None):
    path = path or []
    found = set()
    for key, val in items:
        if val[0] != "obj":
            continue
        nxt = path + [key]
        if key == "apps" and any(part.lower() == "steam" for part in path):
            for appid, app in val[1]:
                if app[0] != "obj" or not appid.isdigit():
                    continue
                for field, fval in app[1]:
                    if field == "LaunchOptions" and fval[0] == "str" and "VKLAYER_DLSS5=" in fval[1].upper():
                        found.add(appid)
        found.update(apps_with_layer(val[1], nxt))
    return found


def skip_game(appid, name):
    if appid in SKIP_APPIDS or not appid.isdigit():
        return True
    low = name.lower()
    return any(low.startswith(prefix) for prefix in SKIP_NAMES)


def scan(roots):
    on = enabled_ids(roots)
    games = {}
    libs = []
    seen_lib = set()
    for root in roots:
        for lib in library_paths(root):
            if lib not in seen_lib:
                seen_lib.add(lib)
                libs.append(lib)
    for lib in libs:
        apps = os.path.join(lib, "steamapps")
        if not os.path.isdir(apps):
            continue
        for name in os.listdir(apps):
            if not (name.startswith("appmanifest_") and name.endswith(".acf")):
                continue
            fields = flat_manifest(os.path.join(apps, name))
            appid = fields.get("appid") or name[len("appmanifest_") : -4]
            flags = fields.get("StateFlags")
            if flags and flags.isdigit() and (int(flags) & 4) == 0:
                continue
            installdir = fields.get("installdir") or ""
            title = fields.get("name") or installdir or appid
            title = title.replace("\t", " ").replace("\n", " ").strip()
            if skip_game(appid, title):
                continue
            folder = os.path.join(apps, "common", installdir) if installdir else ""
            if folder and os.path.isdir(folder):
                folder = os.path.realpath(folder)
            else:
                folder = ""
            games[appid] = {
                "appid": appid,
                "name": title,
                "dir": folder,
                "enabled": appid in on,
            }
    rows = list(games.values())
    rows.sort(key=lambda row: (row["appid"] != "3393110", row["name"].lower()))
    return rows


def cmd_list(roots):
    for row in scan(roots):
        flag = "1" if row["enabled"] else "0"
        sys.stdout.write("%s\t%s\t%s\t%s\n" % (row["appid"], row["name"], row["dir"], flag))


def read_rows(stream):
    rows = []
    for line in stream:
        line = line.rstrip("\n")
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) < 2 or not parts[0].isdigit():
            continue
        while len(parts) < 4:
            parts.append("")
        rows.append(
            {
                "appid": parts[0],
                "name": parts[1],
                "dir": parts[2],
                "on": parts[3] == "1" or parts[0] == "3393110" and parts[3] != "0",
            }
        )
    # Pre-tick only games already using the layer. AION 2 is pre-ticked when
    # nothing is on yet, so the original game stays the default.
    if rows and not any(row["on"] for row in rows):
        for row in rows:
            if row["appid"] == "3393110":
                row["on"] = True
    return rows


class Face:
    def __init__(self, path, pixel):
        import ctypes
        from ctypes import CDLL, POINTER, byref, c_char_p, c_int, c_int32, c_long, c_uint, c_ulong, c_void_p

        self.ct = ctypes
        ft = CDLL("libfreetype.so.6")
        ft.FT_Init_FreeType.argtypes = [POINTER(c_void_p)]
        ft.FT_Init_FreeType.restype = c_int
        ft.FT_New_Face.argtypes = [c_void_p, c_char_p, c_long, POINTER(c_void_p)]
        ft.FT_New_Face.restype = c_int
        ft.FT_Set_Pixel_Sizes.argtypes = [c_void_p, c_uint, c_uint]
        ft.FT_Set_Pixel_Sizes.restype = c_int
        ft.FT_Load_Char.argtypes = [c_void_p, c_ulong, c_int32]
        ft.FT_Load_Char.restype = c_int
        lib = c_void_p()
        if ft.FT_Init_FreeType(byref(lib)) != 0:
            raise OSError("freetype")
        face = c_void_p()
        if ft.FT_New_Face(lib, path.encode(), 0, byref(face)) != 0:
            raise OSError(path)
        if ft.FT_Set_Pixel_Sizes(face, 0, pixel) != 0:
            raise OSError("size")
        self.ft = ft
        self.face = face
        self.cache = {}
        self.height = pixel

    def glyph(self, ch):
        cached = self.cache.get(ch)
        if cached is not None:
            return cached
        import struct

        err = self.ft.FT_Load_Char(self.face, ord(ch), 4)
        if err != 0:
            self.cache[ch] = None
            return None
        raw = bytes((self.ct.c_ubyte * 176).from_address(self.face.value))
        slot = struct.unpack_from("<Q", raw, 152)[0]
        sb = bytes((self.ct.c_ubyte * 220).from_address(slot))
        rows, width = struct.unpack_from("<II", sb, 152)
        pitch = struct.unpack_from("<i", sb, 160)[0]
        buf = struct.unpack_from("<Q", sb, 168)[0]
        left = struct.unpack_from("<i", sb, 192)[0]
        top = struct.unpack_from("<i", sb, 196)[0]
        advance = struct.unpack_from("<q", sb, 80)[0] // 64
        blob = b""
        if buf and rows and width and pitch > 0:
            blob = bytes((self.ct.c_ubyte * (rows * pitch)).from_address(buf))
        info = (blob, rows, width, pitch, left, top, max(advance, width))
        self.cache[ch] = info
        return info


def find_font():
    candidates = (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/TTF/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
        "/usr/share/fonts/liberation/LiberationSans-Regular.ttf",
    )
    for path in candidates:
        if os.path.isfile(path):
            return path
    try:
        import subprocess

        found = subprocess.check_output(["fc-match", "-f", "%{file}", "sans"], text=True).strip()
        if found and os.path.isfile(found):
            return found
    except (OSError, subprocess.CalledProcessError):
        pass
    return ""


def gui(rows):
    import struct
    from ctypes import (
        CDLL,
        POINTER,
        byref,
        c_char_p,
        c_int,
        c_long,
        c_ubyte,
        c_uint,
        c_ulong,
        c_void_p,
        create_string_buffer,
    )

    font_path = find_font()
    if not font_path:
        raise OSError("no font")
    title_face = Face(font_path, 28)
    body = Face(font_path, 15)
    small = Face(font_path, 13)

    x11 = CDLL("libX11.so.6")
    x11.XOpenDisplay.argtypes = [c_char_p]
    x11.XOpenDisplay.restype = c_void_p
    for name, args, rest in (
        ("XDefaultScreen", [c_void_p], c_int),
        ("XDefaultDepth", [c_void_p, c_int], c_int),
        ("XDefaultVisual", [c_void_p, c_int], c_void_p),
        ("XRootWindow", [c_void_p, c_int], c_ulong),
        ("XBlackPixel", [c_void_p, c_int], c_ulong),
        ("XWhitePixel", [c_void_p, c_int], c_ulong),
        ("XCreateSimpleWindow", [c_void_p, c_ulong, c_int, c_int, c_uint, c_uint, c_uint, c_ulong, c_ulong], c_ulong),
        ("XStoreName", [c_void_p, c_ulong, c_char_p], c_int),
        ("XSelectInput", [c_void_p, c_ulong, c_long], c_int),
        ("XMapWindow", [c_void_p, c_ulong], c_int),
        ("XFlush", [c_void_p], c_int),
        ("XNextEvent", [c_void_p, c_void_p], c_int),
        ("XPending", [c_void_p], c_int),
        ("XCreateGC", [c_void_p, c_ulong, c_ulong, c_void_p], c_void_p),
        ("XCreateImage", [c_void_p, c_void_p, c_uint, c_int, c_int, c_void_p, c_uint, c_uint, c_int, c_int], c_void_p),
        ("XPutImage", [c_void_p, c_ulong, c_void_p, c_void_p, c_int, c_int, c_int, c_int, c_uint, c_uint], c_int),
        ("XInternAtom", [c_void_p, c_char_p, c_int], c_ulong),
        ("XSetWMProtocols", [c_void_p, c_ulong, POINTER(c_ulong), c_int], c_int),
        ("XDestroyImage", [c_void_p], c_int),
    ):
        fn = getattr(x11, name)
        fn.argtypes = args
        fn.restype = rest

    dpy = x11.XOpenDisplay(None)
    if not dpy:
        raise OSError("display")
    screen = x11.XDefaultScreen(dpy)
    depth = x11.XDefaultDepth(dpy, screen)
    visual = x11.XDefaultVisual(dpy, screen)
    root = x11.XRootWindow(dpy, screen)
    width, height = 640, 720
    win = x11.XCreateSimpleWindow(
        dpy, root, 80, 60, width, height, 0, x11.XBlackPixel(dpy, screen), x11.XBlackPixel(dpy, screen)
    )
    x11.XStoreName(dpy, win, b"Ascension")
    wm = c_ulong(x11.XInternAtom(dpy, b"WM_DELETE_WINDOW", 0))
    x11.XSetWMProtocols(dpy, win, byref(wm), 1)
    masks = (1 << 0) | (1 << 2) | (1 << 3) | (1 << 13) | (1 << 15) | (1 << 17)
    x11.XSelectInput(dpy, win, masks)
    x11.XMapWindow(dpy, win)
    gc = x11.XCreateGC(dpy, win, 0, None)
    pixels = create_string_buffer(width * height * 4)
    image = x11.XCreateImage(dpy, visual, depth, 2, 0, pixels, width, height, 32, width * 4)

    bg = (0x10, 0x14, 0x0F)
    raise_c = (0x1A, 0x21, 0x18)
    ink = (0xEB, 0xE6, 0xD6)
    muted = (0x9A, 0xA3, 0x92)
    line = (0x2C, 0x34, 0x28)
    gold = (0xE0, 0xA8, 0x5C)
    gold_ink = (0x1C, 0x16, 0x0E)

    def put(x, y, color):
        if x < 0 or y < 0 or x >= width or y >= height:
            return
        offset = (y * width + x) * 4
        r, g, b = color
        struct.pack_into("<I", pixels, offset, (r << 16) | (g << 8) | b)

    def fill(x0, y0, x1, y1, color):
        x0 = max(0, int(x0))
        y0 = max(0, int(y0))
        x1 = min(width, int(x1))
        y1 = min(height, int(y1))
        if x1 <= x0 or y1 <= y0:
            return
        word = struct.pack("<I", (color[0] << 16) | (color[1] << 8) | color[2])
        span = word * (x1 - x0)
        for y in range(y0, y1):
            start = (y * width + x0) * 4
            pixels[start : start + len(span)] = span

    def blend(x, y, color, cover):
        if cover <= 0 or x < 0 or y < 0 or x >= width or y >= height:
            return
        offset = (y * width + x) * 4
        old = struct.unpack_from("<I", pixels, offset)[0]
        ob = old & 255
        og = (old >> 8) & 255
        orr = (old >> 16) & 255
        a = cover / 255
        nr = int(orr + (color[0] - orr) * a)
        ng = int(og + (color[1] - og) * a)
        nb = int(ob + (color[2] - ob) * a)
        struct.pack_into("<I", pixels, offset, (nr << 16) | (ng << 8) | nb)

    def text(face, x, y, string, color):
        pen = x
        for ch in string:
            if ch == "\n":
                continue
            info = face.glyph(ch)
            if not info:
                pen += face.height // 2
                continue
            blob, rows, gw, pitch, left, top, advance = info
            for row in range(rows):
                for col in range(gw):
                    cover = blob[row * pitch + col]
                    if cover:
                        blend(pen + left + col, y - top + row, color, cover)
            pen += advance
        return pen

    def text_width(face, string):
        pen = 0
        for ch in string:
            info = face.glyph(ch)
            pen += info[6] if info else face.height // 2
        return pen

    def clip_text(face, string, limit):
        if text_width(face, string) <= limit:
            return string
        ellipsis = "…"
        while string and text_width(face, string + ellipsis) > limit:
            string = string[:-1]
        return string + ellipsis

    query = ""
    scroll = 0
    list_top = 118
    list_bottom = height - 88
    row_h = 44
    drag = None

    def filtered():
        needle = query.strip().lower()
        if not needle:
            return rows
        return [row for row in rows if needle in row["name"].lower() or needle in row["appid"]]

    def layout():
        shown = filtered()
        view = list_bottom - list_top
        max_scroll = max(0, len(shown) * row_h - view)
        return shown, view, max_scroll

    def paint():
        fill(0, 0, width, height, bg)
        text(title_face, 28, 48, "Ascension", ink)
        text(small, 28, 78, "Tick the Steam games that should use the layer.", muted)
        text(small, 28, 98, "Nothing is written inside a game folder.", muted)
        shown, view, max_scroll = layout()
        nonlocal scroll
        if scroll > max_scroll:
            scroll = max_scroll
        fill(20, list_top - 8, width - 20, list_bottom + 8, raise_c)
        if not shown:
            text(body, 36, list_top + 36, "No installed Steam games found.", muted)
        y = list_top - scroll
        for row in shown:
            if y + row_h < list_top or y > list_bottom:
                y += row_h
                continue
            box = 18
            bx, by = 36, y + 12
            if list_top <= by <= list_bottom - box:
                fill(bx, by, bx + box, by + box, gold if row["on"] else bg)
                # border
                for i in range(box):
                    put(bx + i, by, gold)
                    put(bx + i, by + box - 1, gold)
                    put(bx, by + i, gold)
                    put(bx + box - 1, by + i, gold)
                if row["on"]:
                    for i in range(4):
                        put(bx + 4 + i, by + 9 + i, gold_ink)
                        put(bx + 5 + i, by + 9 + i, gold_ink)
                    for i in range(7):
                        put(bx + 7 + i, by + 12 - i, gold_ink)
                        put(bx + 8 + i, by + 12 - i, gold_ink)
            label = clip_text(body, row["name"], width - 160)
            text(body, 66, y + 28, label, ink)
            text(small, width - 110, y + 27, row["appid"], muted)
            y += row_h
        # scrollbar
        if max_scroll > 0:
            track_h = list_bottom - list_top
            bar_h = max(28, int(track_h * view / (view + max_scroll)))
            bar_y = list_top + int((track_h - bar_h) * scroll / max_scroll)
            fill(width - 16, bar_y, width - 10, bar_y + bar_h, gold)
        # search
        fill(20, height - 78, 250, height - 46, raise_c)
        for i in range(230):
            put(20 + i, height - 78, line)
            put(20 + i, height - 46, line)
        shown_q = query if query else "Filter"
        text(small, 30, height - 54, shown_q, ink if query else muted)
        # buttons
        fill(width - 280, height - 76, width - 150, height - 32, gold)
        label = "Apply"
        text(body, width - 280 + (130 - text_width(body, label)) // 2, height - 46, label, gold_ink)
        fill(width - 136, height - 76, width - 24, height - 32, raise_c)
        for i in range(112):
            put(width - 136 + i, height - 76, line)
            put(width - 136 + i, height - 32, line)
        label = "Cancel"
        text(body, width - 136 + (112 - text_width(body, label)) // 2, height - 46, label, ink)
        x11.XPutImage(dpy, win, gc, image, 0, 0, 0, 0, width, height)
        x11.XFlush(dpy)

    dump = os.environ.get("ASCENSION_PICKER_DUMP")
    paint()
    if dump:
        with open(dump, "w", encoding="ascii") as handle:
            handle.write("P3\n%d %d\n255\n" % (width, height))
            for y in range(height):
                vals = []
                for x in range(width):
                    word = struct.unpack_from("<I", pixels, (y * width + x) * 4)[0]
                    vals.append("%d %d %d" % ((word >> 16) & 255, (word >> 8) & 255, word & 255))
                handle.write(" ".join(vals) + "\n")
        return [row["appid"] for row in rows if row["on"]]

    event = create_string_buffer(256)
    wm_atom = wm.value

    def event_type():
        return struct.unpack_from("<i", event, 0)[0]

    def button_xy():
        x, y = struct.unpack_from("<ii", event, 64)
        button = struct.unpack_from("<I", event, 84)[0]
        return x, y, button

    def row_at(y):
        shown, _view, _max_scroll = layout()
        local = y - list_top + scroll
        if y < list_top or y > list_bottom or local < 0:
            return None
        index = local // row_h
        if index < 0 or index >= len(shown):
            return None
        return shown[index]

    while True:
        x11.XNextEvent(dpy, event)
        kind = event_type()
        if kind == 33:  # ClientMessage
            atom = struct.unpack_from("<Q", event, 56)[0]
            if atom == wm_atom:
                return None
        elif kind == 12 or kind == 15:  # Expose
            paint()
        elif kind == 2:  # KeyPress
            keysym = c_ulong()
            buf = create_string_buffer(32)
            x11.XLookupString.argtypes = [c_void_p, c_char_p, c_int, POINTER(c_ulong), c_void_p]
            x11.XLookupString.restype = c_int
            n = x11.XLookupString(event, buf, 32, byref(keysym), None)
            sym = keysym.value
            if sym in (0xFF0D, 0xFF8D):  # Return, KP_Enter
                return [row["appid"] for row in rows if row["on"]]
            if sym == 0xFF1B:  # Escape
                return None
            if sym == 0xFF08:  # BackSpace
                query = query[:-1]
                scroll = 0
                paint()
                continue
            if n > 0:
                char = buf.raw[:n].decode("utf-8", "replace")
                if char.isprintable() and char not in "\r\n":
                    query += char
                    scroll = 0
                    paint()
        elif kind == 4:  # ButtonPress
            x, y, button = button_xy()
            shown, view, max_scroll = layout()
            if button == 4:
                scroll = max(0, scroll - row_h)
                paint()
                continue
            if button == 5:
                scroll = min(max_scroll, scroll + row_h)
                paint()
                continue
            if button != 1:
                continue
            if height - 76 <= y <= height - 32 and width - 280 <= x <= width - 150:
                return [row["appid"] for row in rows if row["on"]]
            if height - 76 <= y <= height - 32 and width - 136 <= x <= width - 24:
                return None
            hit = row_at(y)
            if hit is not None:
                hit["on"] = not hit["on"]
                paint()
            elif width - 18 <= x <= width - 8 and list_top <= y <= list_bottom and max_scroll:
                drag = y
        elif kind == 6 and drag is not None:  # Motion
            _x, y, _button = button_xy()
            _shown, view, max_scroll = layout()
            track = list_bottom - list_top
            frac = min(1, max(0, (y - list_top) / track))
            scroll = int(frac * max_scroll)
            paint()
        elif kind == 5:  # ButtonRelease
            drag = None


def terminal_pick(rows):
    if not os.isatty(0):
        return None
    on = {row["appid"] for row in rows if row["on"]}
    while True:
        sys.stderr.write("\nAscension — installed Steam games\n")
        sys.stderr.write("The layer is a launch option. Game folders stay untouched.\n\n")
        if not rows:
            sys.stderr.write("No installed Steam games found.\n")
            return []
        for index, row in enumerate(rows, 1):
            mark = "x" if row["appid"] in on else " "
            sys.stderr.write("  [%s] %2d  %s\n" % (mark, index, row["name"]))
        sys.stderr.write("\nNumber toggles, a applies, q cancels: ")
        sys.stderr.flush()
        try:
            answer = input().strip().lower()
        except EOFError:
            return None
        if answer in ("a", "apply", ""):
            if answer == "":
                continue
            for row in rows:
                row["on"] = row["appid"] in on
            return [row["appid"] for row in rows if row["on"]]
        if answer in ("q", "quit", "cancel"):
            return None
        if answer.isdigit():
            index = int(answer)
            if 1 <= index <= len(rows):
                appid = rows[index - 1]["appid"]
                if appid in on:
                    on.remove(appid)
                else:
                    on.add(appid)


def cmd_pick():
    rows = read_rows(sys.stdin)
    chosen = None
    display = os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY")
    if display and os.environ.get("ASCENSION_NO_GUI") != "1":
        try:
            chosen = gui(rows)
        except OSError:
            chosen = None
            display = ""
    if not display or os.environ.get("ASCENSION_NO_GUI") == "1":
        chosen = terminal_pick(rows)
        if chosen is None and not os.isatty(0):
            # Headless re-apply: keep the pre-ticked games.
            chosen = [row["appid"] for row in rows if row["on"]]
    if chosen is None:
        sys.exit(3)
    for appid in chosen:
        sys.stdout.write(appid + "\n")


def main(argv):
    if len(argv) < 2 or argv[1] in ("-h", "--help"):
        sys.stderr.write("usage: picker.py list [--root DIR]... | pick\n")
        return 2
    if argv[1] == "list":
        roots = []
        i = 2
        while i < len(argv):
            if argv[i] == "--root" and i + 1 < len(argv):
                roots.append(argv[i + 1])
                i += 2
            else:
                i += 1
        cmd_list(roots)
        return 0
    if argv[1] == "pick":
        cmd_pick()
        return 0
    sys.stderr.write("unknown command\n")
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv) or 0)
    except BrokenPipeError:
        sys.exit(0)
