#!/usr/bin/env python3
"""Backdrop plates for the pygame renderer (pg_video.py). Places only — no people, no text.
gpt-image-1 1536x1024 medium. Re-runs skip existing files."""
import os, sys, base64, concurrent.futures as cf
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_video as bv

OUT = os.path.join(HERE, "plates"); os.makedirs(OUT, exist_ok=True)
PAL = ("Dark, moody, flat-colour watercolour-and-ink illustration. Palette strictly: deep forest green and bottle green, aubergine, magenta, "
       "crimson, plum, with a little ember orange where there is flame or lamplight; black ink shadows; everything else nearly black. "
       "Wide cinematic composition, lots of empty dark space. ABSOLUTELY NO PEOPLE, NO FIGURES, NO ANIMALS, NO TEXT, NO LETTERS, NO NUMBERS. ")
PLATES = {
 "wall_bench":  "A tall stone wall of an old courtroom at night. In front of it, a plain folding table used as a judge's bench, empty, with a small cigarette lighter on it. A sand floor with a faint circle drawn in it. Two tall narrow windows with night sky.",
 "wall_witness":"A tall stone wall with one narrow arched window showing a dark green night sky. In front of it a single empty wooden witness chair on a sand floor. A faint magenta-crimson glow from an unseen lamp to the left.",
 "wall_gallery":"Rows of empty old wooden benches, a public gallery, receding into darkness. Stone wall behind. One ember-orange lantern hanging. Sand floor.",
 "alcove":      "A dark stone wall, and set back into it, high up, an arched recess like a monk's alcove, with a tiny wooden desk and an antique typewriter on it, one candle burning ember orange. The recess is empty. Below it, the dark wall continues; a ledge; nothing else.",
 "passage":     "A long narrow dark stone passage going away from the viewer, almost entirely black, with a faint green-magenta light at the far end and wet stone floor reflecting it.",
 "yard":        "Seen from inside a dark stone room, a heavy wooden door standing open onto a bright yard: sunlight, a single old apple tree, green grass, a wall, open sky. The inside of the room is nearly black; the doorway is the only light. Broken glass glinting on the sand floor inside.",
 "lab_bench":   "A dark wooden workbench in an old laboratory at night: glass tubes, a shallow dish, a brass instrument, a small flame, bottles; deep shadows; one candle. Nothing written anywhere.",
 "space":       "Black space, a huge crimson-orange sun low in the frame with a dark green corona haze, tiny faint stars, a small grey planet silhouetted against the sun's edge.",
 "sand_circle": "A circle drawn in sand, seen from above at a slight angle, with a plain folding table at its centre and a small flame on the table, in near darkness; deep green and plum shadows, one crimson highlight.",
 "desk_hume":   "A small writing desk in a dark study: a small brown book lying open, a quill, a candle; a heavy curtain behind; nobody present; the chair pushed back and empty.",
 "glove_bag":   "A clear plastic evidence bag lying on a plain folding table, with a single dark left-hand glove inside it, lit by one small flame, deep darkness around.",
 "mountain":    "A broad dark mountain (a rounded extinct volcano) under a plum-and-green dusk sky, with a path winding up to a bare summit; nothing on the path; very dark foreground.",
}

def one(name):
    path = os.path.join(OUT, name + ".png")
    if os.path.exists(path): return name, "skip"
    c = bv.client()
    r = c.images.generate(model="gpt-image-1", prompt=PAL + PLATES[name], size="1536x1024", quality="medium", n=1)
    open(path, "wb").write(base64.b64decode(r.data[0].b64_json)); return name, "ok"

if __name__ == "__main__":
    names = sys.argv[1:] or list(PLATES)
    with cf.ThreadPoolExecutor(4) as ex:
        for n, st in ex.map(one, names): print(n, st, flush=True)
