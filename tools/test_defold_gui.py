"""Headless smoke test for defold/main/camp.gui_script.

There is no Defold toolchain in this sandbox, so the gui API is mocked: every
call the script makes is recorded and the interesting outcomes (text written to
each node, colours, messages posted, errors) are asserted.  This catches the
class of bug that shipped in defold-1: a nil node, a bad string.format, an
empty profession table -- anything that would abort init() or update() on
device and leave a frozen picture.
"""
import sys

from lupa import LuaRuntime

SCRIPT = "/home/user/Bunker/defold/main/camp.gui_script"
CONTENT = "/home/user/Bunker/defold/main/data/content.lua"

lua = LuaRuntime(unpack_returned_tuples=True)
G = lua.globals()

# --- mock the Defold gui/msg/vmath surface -------------------------------
lua.execute(
    """
    gui = { nodes = {}, texts = {}, colors = {}, flipbooks = {}, enabled = {} }
    local function node(id)
        if gui.nodes[id] == nil then gui.nodes[id] = { id = id } end
        return gui.nodes[id]
    end
    gui.get_node = node
    gui.set_text = function(n, s) gui.texts[n.id] = s end
    gui.set_color = function(n, c) gui.colors[n.id] = c end
    gui.play_flipbook = function(n, h) gui.flipbooks[n.id] = h end
    gui.set_enabled = function(n, b) gui.enabled[n.id] = b end
    gui.pick_node = function(n, x, y) return gui.pick_result == true end
    gui.get_screen_size = function() return 2460, 1080 end
    vmath = {
        vector4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end,
        vector3 = function(x, y, z) return { x = x, y = y, z = z } end,
    }
    gui.set_position = function(n, p) gui.positions = gui.positions or {}; gui.positions[n.id] = p end
    hash = function(s) return s end
    posted = {}
    msg = { post = function(to, what, m)
        posted[#posted + 1] = { to = to, what = what, x = m and m.x, y = m and m.y }
    end }
    """
)

with open(CONTENT, encoding="utf-8") as fh:
    content_src = fh.read()
G.package.preload["main.data.content"] = lua.eval("function() %s end" % content_src.replace(
    "return {", "return {"))

with open(SCRIPT, encoding="utf-8") as fh:
    src = fh.read()

chunk = G.load(src, "camp.gui_script")
assert chunk is not None, "script does not compile"
chunk()  # defines init/update/on_input/on_message in globals

init = G.init
update = G.update
on_input = G.on_input
on_message = G.on_message
assert callable(init) and callable(update) and callable(on_input) and callable(on_message)

state = lua.table()

init(state)
texts = G.gui.texts
assert "ТЕЛЕВИЗОР" in texts["caption"], texts["caption"]
assert texts["card_name"] != "ПРОФЕССИЯ", "card must start with a real profession"
assert "тапов: 0" in texts["hint"], texts["hint"]
assert G.posted[1].to == ".", G.posted[1]
assert G.posted[1].what == "acquire_input_focus"

# splash fades out on its own -> the first thing the player sees is motion
for _ in range(20):
    update(state, 0.1)
assert G.gui.positions and G.gui.positions["scanline"], "scanline never moved"
first = G.gui.positions["scanline"].y
for _ in range(30):
    update(state, 0.1)
assert G.gui.positions["scanline"].y != first, "scanline is frozen"
assert G.gui.enabled["splash"] is False, "splash never disappeared"
assert G.gui.enabled["splash_title"] is False

# a tap anywhere switches the channel
before = texts["caption"]
on_input(state, "touch", lua.table(x=300, y=400, pressed=True))
assert texts["caption"] != before, "tap did not change the channel"
assert "тапов: 1" in texts["hint"], texts["hint"]
assert "300,400" in texts["hint"], texts["hint"]

# three taps cycle back to the first channel
on_input(state, "touch", lua.table(x=310, y=410, pressed=True))
on_input(state, "touch", lua.table(x=320, y=420, pressed=True))
assert texts["caption"] == before, texts["caption"]

# a tap on the card gives a new profession -- even when pick_node misses, the
# right-hand column ratio is used
profession = texts["card_name"]
found_new = False
for i in range(12):
    on_input(state, "touch", lua.table(x=1900, y=700 + i, pressed=True))
    if texts["card_name"] != profession:
        found_new = True
        break
assert found_new, "card tap never produced a new profession"

# ... and a tap on the left side still cycles channels
caption_before = texts["caption"]
on_input(state, "touch", lua.table(x=600, y=500, pressed=True))
assert texts["caption"] != caption_before, "left-side tap must change the channel"

# the forwarded path (camp.script -> gui) works ...
G.gui.pick_result = False


def tap_count():
    return int(texts["hint"].split("тапов: ")[1].split(" ")[0])


# ... and the same press arriving through both paths is counted once
base = tap_count()
on_message(state, "tap", lua.table(x=901, y=301), None)
assert tap_count() == base + 1, (base, tap_count())
on_input(state, "touch", lua.table(x=901, y=301, pressed=True))
assert tap_count() == base + 1, "duplicate press counted twice"
# a genuinely new press is counted even at the same pixel
update(state, 0.016)
update(state, 0.016)
update(state, 0.016)
on_input(state, "touch", lua.table(x=901, y=301, pressed=True))
assert tap_count() == base + 2, tap_count()

# releases and unknown messages must not crash or count
on_input(state, "touch", lua.table(x=900, y=300, pressed=False))
on_message(state, "something_else", lua.table(), None)

# long run: anime reel keeps flipping without errors
on_input(state, "touch", lua.table(x=900, y=800, pressed=True))  # -> channel 1
for _ in range(200):
    update(state, 0.05)

professions = 0
content_tbl = lua.eval("function() return require('main.data.content') end")()
for k in content_tbl.professions:
    professions += 1
assert professions >= 70, professions

# --- the game object script that forwards taps --------------------------
lua.execute("posted = {}")
with open("/home/user/Bunker/defold/main/camp.script", encoding="utf-8") as fh:
    go_src = fh.read()
assert lua.eval("function(s) return load(s) end")(go_src) is not None, "camp.script does not compile"
lua.execute(go_src)
gstate = lua.table()
G.init(gstate)
assert G.posted[1].to == "." and G.posted[1].what == "acquire_input_focus", G.posted[1]
assert G.on_input(gstate, "touch", lua.table(x=11, y=22, pressed=True)) is True
assert G.posted[2].to == "#camp" and G.posted[2].what == "tap", G.posted[2]
assert (G.posted[2].x, G.posted[2].y) == (11, 22), G.posted[2]
assert G.on_input(gstate, "touch", lua.table(x=11, y=22, pressed=False)) is False
print("camp.script OK: forwards presses to the gui")

print("camp.gui_script OK: %d professions, %d messages, last hint: %s" % (
    professions, len(G.posted), texts["hint"]))
