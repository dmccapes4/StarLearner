#!/usr/bin/env python3
"""
Educational video of FABLE_HUME_V_SPOCK_20261010.md  (Part Two)

Same machinery as ../video/build_video.py (Part One): the narration is the written
fable, exactly, one or two sentences per shot; one ElevenLabs narrator (Matilda)
for everything outside quotation marks, a distinct ElevenLabs voice per speaker;
one gpt-image-1 picture per shot.

Part Two flavour: the same wet watercolour-and-ink medium, but DARK — deep forest
green, umber brown, aubergine purple, magenta, bruise violet, bottle green — a
night court lit by a cigarette lighter.  Widukind of Corvey is the court reporter
in this fable, so the text names him; he sits where he sat in Part One — high on
the back wall in the alcove (the fable itself makes the alcove the point), at a
typewriter, motionless, a flat silhouette whose colour switches shot by shot
through the dark palette.  The right-hand panel is his typed record: the actual
statements, verbatim.  At the very end he types his name and pulls the sheet.

Stages: parse | scenes | images | audit | fixloop N | tts | frames | video | story
Usage: build_video.py <stage> [--only S007,S008]
"""
import os, sys, re, json, base64, wave, textwrap, subprocess, concurrent.futures as cf, time, random, urllib.request, urllib.error
HERE = os.path.dirname(os.path.abspath(__file__))
DEV = "/home/dylanmccapes/dev"
sys.path.insert(0, os.path.join(DEV, "BeginningToNoww/scripts/six"))
from common import api_key  # OpenAI key (star_learning/.env)  # noqa
FABLE = os.path.join(HERE, "..", "FABLE_HUME_V_SPOCK_20261010.md")
ELEVEN_ENV = os.path.join(DEV, "star_learning/ant_explorer/tools/secrets/elevenlabs.env")
OUT_MP4 = "fable_hume_v_spock.mp4"
IMG = os.path.join(HERE, "images"); AUD = os.path.join(HERE, "audio"); FRM = os.path.join(HERE, "frames"); CLIP = os.path.join(HERE, "clips"); CARDS = os.path.join(HERE, "cards")
for d in (IMG, AUD, FRM, CLIP, CARDS): os.makedirs(d, exist_ok=True)
FONT_HAND = os.path.join(HERE, "fonts/SpecialElite.ttf"); FONT_SERIF = os.path.join(HERE, "fonts/IMFellEnglish.ttf"); FONT_ITAL = os.path.join(HERE, "fonts/IMFellEnglishItalic.ttf")

# ───────────────────────── the flavor ─────────────────────────
STYLE = ("Dark, moody, fluid watercolour-and-ink cartoon illustration. The palette is strictly DEEP and DARK colours — forest green, bottle green, umber and chocolate brown, "
         "aubergine and bruise purple, magenta and plum, with black ink — laid down as wet, bleeding washes that flow into one another; the only light in the room "
         "comes from a cigarette lighter's small flame and from the colours themselves glowing out of the dark. Loose black ink line work drawn over the colour. "
         "IMPORTANT: every human face in the picture is scratched out — obliterated by a dense scribble of ink strokes, so that NO eyes, nose, mouth or expression "
         "is visible on anyone. The characters remain identifiable only by silhouette, hair, clothing and props. "
         "Absolutely no text, letters, numbers or captions anywhere in the image. "
         "Setting: the same tall stone room as before, with a circle drawn in sand on the floor, now arranged as a courtroom at night: the folding table is the judge's bench, "
         "a single witness chair stands beside the sand circle, twelve empty jury chairs in two rows, and a gallery of wooden benches at the back. ")

CHAR = {
    "FEYNMAN": "Judge Richard Feynman — a wiry man in white shirtsleeves rolled to the elbow, loosened dark tie, wild hair, a cigarette lighter in hand for a gavel",
    "McCLANE": "Bailiff John McClane — a thick-shouldered man in a torn, dirty white tank top, barefoot, standing by the bench",
    "WIDUKIND": "the court reporter",
    "HUME": "David Hume — a large, stout 18th-century Scot in a plain brown coat and white wig, holding a small brown book",
    "SPOCK": "Spock — a tall, lean figure in a blue tunic with pointed ears and a severe black fringe, hands clasped behind his back",
    "KIRK": "Kirk — a confident man in a gold tunic lounging in the witness chair, one arm along the rail",
    "EARS": "an actor in the gallery with pointed prosthetic ears, in a cardigan",
    "VOICE": "an actor in the gallery with a toupee and a loud sports jacket",
    "TEACHER": "a schoolteacher with a clipboard, standing beside eleven small children on a gallery bench",
    "KIDS": "eleven small schoolchildren sitting very still on a gallery bench",
    "CHAUFFEUR": "a chauffeur in a grey cap and grey coat, half-standing in the back row",
    "TORRICELLI": "Torricelli — a 17th-century Italian in a dark doublet holding a long glass tube of quicksilver inverted in a dish",
    "PERIER": "Périer — a 17th-century Frenchman in travelling clothes with a barometer tube strapped to his back and a walking stick",
    "FAHRENHEIT": "Fahrenheit — an 18th-century Dutch-German instrument maker in a leather apron holding a thin sealed glass thermometer",
    "CELSIUS": "Celsius — an 18th-century Swedish astronomer in a blue coat holding a thermometer and a small staircase model",
    "GOLDMANN": "Goldmann — a 1950s ophthalmologist in a white coat with a small brass applanation tonometer",
    "LEVERRIER": "Le Verrier — a very upright 19th-century Frenchman in a frock coat holding a pencil and a sheet of orbital calculations",
    "LESCARBAULT": "Lescarbault — a country doctor in a rumpled coat holding a telescope the size of a loaf of bread and a chalked plank",
    "EINSTEIN": "Einstein — an older man in a baggy jumper with unaccountable white hair and a moustache, his face a dark scribbled blot",
    "NEWTON": "Newton — a 17th-century Englishman in a long grey wig and dark coat holding a glass prism",
    "OPPENHEIMER": "Oppenheimer — a gaunt man in a wide-brimmed hat and loose suit, in the gallery",
    "PLUTARCH": "Plutarch — a Greek with a short beard wearing a Roman toga",
    "ARCHIMEDES": "Archimedes — an old, lean Greek with sand on his hands and a wooden stick",
    "ARISTARCHUS": "an empty wooden chair in the witness box",
    "BESSEL": "Bessel — a 19th-century German astronomer in a dark coat with a small brass heliometer",
    "BRUNO": "Bruno — a faceless silhouette of a robed man standing in a doorway, backlit by orange flame",
    "GALILEO": "Galileo — an old bearded man in a dark robe seated in the gallery, a small telescope across his knees",
    "COPERNICUS": "Copernicus — a Renaissance canon in a fur-trimmed robe and flat cap, at the back",
    "AQUINAS": "Aquinas — an enormous, gentle friar in a black-and-white Dominican habit holding a quill",
    "KANT": "Kant — a small, exact man in a powdered wig and 18th-century coat consulting a pocket watch, his face a dense black scribble",
    "TESLA": "Tesla — a very tall, gaunt man in a black suit, his face a dark scribbled blot",
    "RONTGEN": "Röntgen — a bearded 19th-century German in a dark suit beside a glowing Crookes tube",
    "SPENCER": "Spencer — a 1940s engineer in shirtsleeves holding a melted chocolate bar and a magnetron",
    "MARCONI": "Marconi — an Edwardian Italian in a dark suit and bow tie with a kite trailing antenna wire",
    "RIEBEECK": "Jan van Riebeeck — a small, exact 17th-century Dutchman in a white collar with a thick ledger under his arm, writing in it",
    "AUTSHUMATO": "Autshumato — a lean Khoikhoi man in a mix of skin cloak and a Dutch sailor's jacket, standing in the witness box",
    "KIDD": "William Kidd — a 17th-century sea captain in a long coat and tricorne, swaying slightly, in the gallery",
    "BILLY": "Billy the Kid — a slight young man in a battered hat and waistcoat with a pistol on his hip, far back in the gallery",
    "DINGANE": "Dingane — a large, very still Zulu king in a leopard-skin cloak and a headring, seated in the witness box",
    "KAMEHAMEHA": "Kamehameha — a tall Hawaiian king in a feathered cloak and crested helmet, standing in the gallery",
    "JUSTINIAN": "Justinian — a tired Byzantine emperor in purple robes holding two books, one in each hand",
    "JAKOB": "Jakob Grimm — a thin, exact 19th-century German scholar in a dark coat holding a thick grammar",
    "WILHELM": "Wilhelm Grimm — a rounder, warmer 19th-century German in a brown coat holding a book of tales",
    "HORDE": "the Marxists — a faceless horde of identical dark silhouettes with red pamphlets pressing at the door",
}
DARK_CYCLE = ["magenta", "dark emerald green", "deep violet", "plum", "bottle green", "crimson-purple", "amber-brown"]
def CHRONICLER(color):
    return (f"High on the back wall, far behind everyone and above their heads, at the exact top centre of the picture, there is a small arched stone alcove — a recess set back out of the light. "
            f"In it sits a small motionless figure at a typewriter on a small desk, typing. The figure is a flat featureless silhouette of pure, solid, glowing {color} "
            f"— the only part of the picture in that single flat colour — and is always in that same alcove, the same size, in the same pose, in every picture. "
            f"Nobody in the room looks at it. ")
PALETTE = STYLE.split("IMPORTANT:")[0]
ALCOVE = ("A single arched stone alcove — a recess set back in a dark wall — fills the whole picture, seen straight on and very close. Inside it, one small figure — a flat, featureless "
          "silhouette of pure, solid, glowing {color}, no face, no lines inside it — sits at a small desk with an old typewriter. {action} Nothing and nobody else is in the picture; "
          "the stones of the alcove are washed in bleeding dark green, brown, purple and magenta. No text anywhere.")
SIGN_ACTION = "Its fingers rest on the keys, striking the last letters of the final line on a sheet of blank paper in the typewriter."
CLOSE_ACTION = "It is pulling the finished sheet up out of the typewriter with both hands, the paper curling, the room beyond gone fully dark."
SIGNATURE = "— Widukind of Corvey"
RGB = {"magenta": (190, 40, 130), "dark emerald green": (20, 110, 70), "deep violet": (90, 40, 150), "plum": (120, 40, 90), "bottle green": (30, 80, 50),
       "crimson-purple": (140, 30, 80), "amber-brown": (150, 90, 30)}

# ───────────────────────── ElevenLabs voices ─────────────────────────
V = dict(MATILDA="XrExE9yKIg1WjnnlVkGX", CHRISLAW="rh459EDIzUEWS6bBNWMV", ADAM="pNInz6obpgDQGcFmaJgB", BILL="pqHfZKP75CvOlQylNhV4", BRIAN="nPczCjzI2devNBz1zQrb",
         GEORGE="JBFqnCBsd6RMkjVDRZzb", ROGER="CwhRBWXzGAHq8TQ4Fs17", LIAM="TX3LPaxmHKxFdv7VOQHJ", ERIC="cjVigY5qzO86Huf0OWal", CALLUM="N2lVS1w4EtoT3dr4eOWO",
         CHRIS="iP95p4xoKVk53GoZ742B", WILL="bIHbv24MWmeRgasZH58o", DANIEL="onwK4e9ZLuTAKqWW03F9", HARRY="SOYHLrjzK2X1ezoPC6cr", RIVER="SAz9YHcvj6GT2YYXdXww",
         CHARLIE="IKne3meq5aSn9XLyUdCD", ALICE="Xb7hH8MSUJpSbSDYk0k2", LILY="pFZP5JQG7iQjIQuC4Bku")
VOICE = {   # voice_id, stability, speed
    "NARRATOR": (V["MATILDA"], 0.55, 0.92),
    "FEYNMAN": (V["CHRISLAW"], 0.45, 1.00), "McCLANE": (V["ADAM"], 0.60, 0.95), "WIDUKIND": (V["GEORGE"], 0.75, 0.88),
    "HUME": (V["BILL"], 0.60, 0.95), "SPOCK": (V["RIVER"], 0.85, 0.95), "KIRK": (V["CHARLIE"], 0.45, 1.00),
    "EARS": (V["ERIC"], 0.50, 1.00), "VOICE": (V["CHRIS"], 0.45, 1.00), "TEACHER": (V["ALICE"], 0.55, 1.00), "CHAUFFEUR": (V["WILL"], 0.50, 1.00),
    "TORRICELLI": (V["BRIAN"], 0.60, 0.95), "PERIER": (V["LIAM"], 0.50, 1.00), "FAHRENHEIT": (V["CALLUM"], 0.60, 0.95), "CELSIUS": (V["DANIEL"], 0.60, 0.95),
    "GOLDMANN": (V["ERIC"], 0.65, 0.92), "LEVERRIER": (V["GEORGE"], 0.60, 0.95), "LESCARBAULT": (V["WILL"], 0.45, 1.00),
    "EINSTEIN": (V["BRIAN"], 0.65, 0.90), "NEWTON": (V["GEORGE"], 0.65, 0.92), "OPPENHEIMER": (V["CALLUM"], 0.70, 0.90),
    "PLUTARCH": (V["ERIC"], 0.60, 0.95), "ARCHIMEDES": (V["ROGER"], 0.55, 0.95), "BESSEL": (V["DANIEL"], 0.60, 0.95), "BRUNO": (V["CALLUM"], 0.60, 0.90),
    "GALILEO": (V["BILL"], 0.65, 0.90), "COPERNICUS": (V["CHRIS"], 0.60, 0.95), "AQUINAS": (V["BRIAN"], 0.70, 0.88), "KANT": (V["DANIEL"], 0.70, 0.95),
    "TESLA": (V["CALLUM"], 0.60, 0.92), "RONTGEN": (V["DANIEL"], 0.55, 0.98), "SPENCER": (V["WILL"], 0.45, 1.02), "MARCONI": (V["ERIC"], 0.55, 1.00),
    "RIEBEECK": (V["DANIEL"], 0.70, 0.95), "AUTSHUMATO": (V["HARRY"], 0.65, 0.95), "KIDD": (V["CHARLIE"], 0.40, 0.98), "BILLY": (V["LIAM"], 0.40, 1.02),
    "DINGANE": (V["BRIAN"], 0.75, 0.88), "KAMEHAMEHA": (V["ROGER"], 0.65, 0.92), "JUSTINIAN": (V["GEORGE"], 0.65, 0.90),
    "JAKOB": (V["DANIEL"], 0.65, 0.95), "WILHELM": (V["WILL"], 0.55, 0.95), "HORDE": (V["HARRY"], 0.30, 1.05),
}
NAME_MAP = {"THE ONE WITH THE EARS": "EARS", "THE ONE WITH THE VOICE": "VOICE", "THE TEACHER": "TEACHER", "THE CHAUFFEUR": "CHAUFFEUR",
            "PÉRIER": "PERIER", "LE VERRIER": "LEVERRIER", "RÖNTGEN": "RONTGEN", "JAN VAN RIEBEECK": "RIEBEECK", "BILLY THE KID": "BILLY",
            "DINGANE KASENZANGAKHONA": "DINGANE", "JAKOB GRIMM": "JAKOB", "WILHELM GRIMM": "WILHELM", "THE HORDE": "HORDE", "A VOICE FROM THE HORDE": "HORDE",
            "AN EMPTY CHAIR": None, "A SILHOUETTE": None}
DISPLAY = {"McCLANE": "McClane", "FEYNMAN": "Feynman", "HORDE": "The horde", "EARS": "The one with the ears", "VOICE": "The one with the voice", "TEACHER": "The teacher",
           "CHAUFFEUR": "The chauffeur", "PERIER": "Périer", "LEVERRIER": "Le Verrier", "RONTGEN": "Röntgen", "RIEBEECK": "Van Riebeeck", "BILLY": "Billy the Kid",
           "JAKOB": "Jakob Grimm", "WILHELM": "Wilhelm Grimm", "LESCARBAULT": "Lescarbault", "KIDD": "Kidd", "WIDUKIND": "Widukind"}
ELEVEN_MODEL = "eleven_multilingual_v2"

# ───────────────────────── parse the fable, exactly ─────────────────────────
MAXCH = 230

def strip_md(t):
    t = re.sub(r"\*\*(.+?)\*\*", r"\1", t); t = re.sub(r"\*(.+?)\*", r"\1", t); t = t.replace("`", "")
    return t.replace("  ", " ").strip()

def sentences(t):
    parts = re.split(r"(?<=[.!?…])\s+(?=[\"'(A-Z—*“‘])|(?<=[.!?]\")\s+", t.strip())
    return [p for p in parts if p]

def chunk(text, limit=MAXCH):
    out, cur = [], ""
    for s in sentences(text):
        if len(s) > 320 and " · " in s:                      # long lists in the header block
            items = s.split(" · "); grp = []
            for it in items:
                grp.append(it)
                if len(" · ".join(grp)) > limit: out.append((cur + " " if cur else "") + " · ".join(grp) + " ·"); cur = ""; grp = []
            if grp: s = " · ".join(grp)
            else: continue
        if cur and len(cur) + 1 + len(s) > limit: out.append(cur); cur = s
        else: cur = (cur + " " + s).strip()
    if cur: out.append(cur)
    return out

def tokenize_dialogue(rest):
    toks, i, buf = [], 0, ""
    while i < len(rest):
        if rest[i] == '"':
            j = rest.find('"', i + 1)
            if j < 0: j = len(rest)
            if buf.strip(): toks.append(("nar", buf.strip())); buf = ""
            toks.append(("say", rest[i + 1:j].strip())); i = j + 1
        else:
            buf += rest[i]; i += 1
    if buf.strip(): toks.append(("nar", buf.strip()))
    return toks

def who_display(w):
    return DISPLAY.get(w, w.title() if w else "")

def resolve_speaker(name):
    key = name.upper().replace("MCCLANE", "McCLANE").replace("KASENZANGAKHONA", "KASENZANGAKHONA")
    if key in NAME_MAP: return NAME_MAP[key]
    k2 = key.split()[0] if key.split() else key
    k2 = {"PÉRIER": "PERIER", "RÖNTGEN": "RONTGEN"}.get(k2, k2)
    if key in VOICE: return key
    if k2 in VOICE: return k2
    return None

def build_segments():
    segs, sec, last_who = [], -1, None
    lines = open(FABLE, encoding="utf-8").read().split("\n")
    i = 0
    def add(kind, who, text, sec_=None):
        for c in (chunk(text) if kind in ("nar", "say") else [text]):
            segs.append(dict(sec=sec if sec_ is None else sec_, who=who, text=c, kind=kind, card=None))
    while i < len(lines):
        ln = lines[i].rstrip(); i += 1
        if not ln.strip() or ln.strip() == "---": continue
        if ln.startswith("# "): add("head", "NARRATOR", ln[2:].strip()); continue
        if ln.startswith("### "): add("head", "NARRATOR", ln[4:].strip()); continue
        if ln.startswith("## "):
            m = re.match(r"## (\d+)\. (.*)", ln)
            if m: sec = int(m.group(1)); add("head", "NARRATOR", f"{m.group(1)}. {m.group(2)}")
            else: sec += 1; add("head", "NARRATOR", ln[3:].strip())
            continue
        if ln.startswith("> "): add("nar", "NARRATOR", strip_md(ln[2:])); continue
        if ln.startswith("|"):                       # table → cards; rows read by the narrator with the column headers
            rows = []
            while i <= len(lines) and ln.startswith("|"):
                cells = [strip_md(c) for c in ln.strip().strip("|").split("|")]
                if not set("".join(cells)) <= set("-: "): rows.append(cells)
                ln = lines[i].rstrip() if i < len(lines) else ""; i += 1
            i -= 1
            hdr, body = rows[0], rows[1:]
            per = 2 if len(hdr) >= 4 else 3
            card = f"table{sum(1 for s in segs if s['kind']=='table' and s.get('first'))+1}"
            for k in range(0, len(body), per):
                parts = []
                for r in body[k:k + per]:
                    lead = r[0]
                    cells = [f"{hdr[j]}: {r[j]}" if hdr[j] else r[j] for j in range(1, len(r)) if r[j].strip()]
                    parts.append((lead + ". " if lead else "") + " — ".join(cells).rstrip(".") + ".")
                segs.append(dict(sec=sec, who="NARRATOR", text="  ".join(parts), kind="table", card=card, hdr=hdr, rows=body,
                                 hi=list(range(k, min(k + per, len(body)))), first=(k == 0)))
            continue
        if ln.startswith('"') and last_who:         # continuation paragraph of the same speech (the verdict)
            for kind, t in tokenize_dialogue(ln):
                add("say" if kind == "say" else "nar", last_who if kind == "say" else "NARRATOR", strip_md(t))
            continue
        m = re.match(r"^\*\*([^*]+?)\*\*(.*)$", ln)
        who = resolve_speaker(m.group(1).strip().rstrip(":")) if m else None
        if m and who:
            rest = m.group(2).strip()
            if rest.startswith(":"): rest = rest[1:].strip()
            toks = tokenize_dialogue(rest)
            if not any(k == "say" for k, _ in toks):
                r2 = strip_md(rest)
                if r2.startswith("types:"):
                    segs.append(dict(sec=sec, who="NARRATOR", text=f"{who_display(who)} types: {r2[6:].strip()}", kind="write", card=None, writer=who))
                elif r2.startswith("(writes)"):
                    segs.append(dict(sec=sec, who="NARRATOR", text=f"{who_display(who)} writes: {r2[8:].strip()}", kind="write", card=None, writer=who))
                else: add("nar", "NARRATOR", f"{who_display(who)} {r2}")
                continue
            last_who = who
            for ti, (kind, t) in enumerate(toks):
                if kind == "say": add("say", who, strip_md(t))
                else:
                    t2 = strip_md(t).strip()
                    if t2.startswith("(writes)") and len(t2) > 8:
                        segs.append(dict(sec=sec, who="NARRATOR", text=f"{who_display(who)} writes: {t2[8:].strip()}", kind="write", card=None, writer=who))
                    elif t2:
                        if ti == 0: t2 = f"{who_display(who)} {t2}"
                        add("nar", "NARRATOR", t2)
            continue
        if m and m.group(1).strip().rstrip(":").upper() in NAME_MAP and NAME_MAP[m.group(1).strip().rstrip(":").upper()] is None:
            add("nar", "NARRATOR", strip_md(ln).replace("AN EMPTY CHAIR", "An empty chair").replace("A SILHOUETTE", "A silhouette")); continue
        add("nar", "NARRATOR", strip_md(ln).replace("A SILHOUETTE", "A silhouette").replace("AN EMPTY CHAIR", "An empty chair"))
    for k, s in enumerate(segs): s["id"] = f"S{k:03d}"
    return segs

S = build_segments()
S.append(dict(sec=99, who=None, text="", kind="sign", card=None, id=f"S{len(S):03d}"))
S.append(dict(sec=99, who=None, text="", kind="close", card=None, id=f"S{len(S):03d}"))
IDX = {s["id"]: i for i, s in enumerate(S)}

def spoken(s):
    t = s["text"]
    t = t.replace("20261010", "2026-10-10").replace("20261009", "2026-10-09").replace("§9", "section nine").replace("§", "section ")
    t = re.sub(r"^(\d+)\. ", lambda m: {"0": "Zero. "}.get(m.group(1), m.group(1) + ". "), t)
    t = t.replace("½", "one half").replace("−∞", "minus infinity").replace("−", "minus ").replace("″", " arcseconds").replace("µs", " microseconds")
    t = t.replace("_", " ").replace("/", " / ")
    t = re.sub(r"\bc\. (?=\d)", "circa ", t); t = re.sub(r"\bd\. (?=\d)", "died ", t)
    return t

# ───────────────────────── scenes (gpt-4.1) ─────────────────────────
SCENES_PATH = os.path.join(HERE, "scenes.json")
def load_scenes(): return json.load(open(SCENES_PATH)) if os.path.exists(SCENES_PATH) else {}

SCENE_SYS = ("You write one-sentence scene descriptions for an illustrator making one picture per narrated shot of a fable. "
             "Keep every shot inside the same stone room — a circle drawn in sand, now arranged as a night courtroom: the folding table is the bench, a witness chair, twelve empty jury chairs, "
             "a gallery of benches with two actors, a chauffeur, a teacher and eleven children — unless the text itself leaves the room (a mountain, a telescope on the Sun, a hotel room, the Cape, a yard with a tree). Refer to characters ONLY with these placeholders, which will be replaced by full "
             "descriptions: " + ", ".join("{%s}" % k for k in CHAR) + ". Describe pose, action, props, where the camera is, and what is lit. "
             "Vary the camera: wide, medium, close on hands/objects, low angle, overhead. Never describe faces. Never put text in the picture. "
             "Do NOT mention any chronicler, scribe, alcove or book-keeper; that is added separately. Never depict dates, numerals, writing, labels, signs, "
             "calendars or anything that would require text in the picture — show objects and gestures instead. 25–45 words per scene. "
             "Return a JSON object {\"scenes\": [\"...\", ...]} with exactly one entry per shot, in order.")

def stage_scenes(only=None):
    c = client(); sc = load_scenes()
    secs = sorted(set(s["sec"] for s in S))
    for sec in secs:
        shots_all = [s for s in S if s["sec"] == sec and s["kind"] in ("nar", "say", "write", "head") and (only is None or s["id"] in only) and s["id"] not in sc]
        if not shots_all: continue
        for b0 in range(0, len(shots_all), 12):
          shots = shots_all[b0:b0 + 12]
          listing = "\n".join(f"{s['id']} [{s['who'] if s['kind']=='say' else 'NARRATOR'}]: {s['text']}" for s in shots)
          full = "\n".join(f"[{s['who'] if s['kind']=='say' else 'NARRATOR'}]: {s['text']}" for s in S if s["sec"] == sec and s["text"])
          msg = f"Section text for context:\n{full}\n\nShots needing a scene (one per line, keep order):\n{listing}"
          for attempt in range(4):
              try:
                  r = c.chat.completions.create(model="gpt-4.1", temperature=0.7, response_format={"type": "json_object"},
                                                messages=[{"role": "system", "content": SCENE_SYS}, {"role": "user", "content": msg}])
                  arr = json.loads(r.choices[0].message.content)["scenes"]
                  if len(arr) != len(shots): raise ValueError(f"got {len(arr)} scenes for {len(shots)} shots")
                  for s, d in zip(shots, arr): sc[s["id"]] = d
                  json.dump(sc, open(SCENES_PATH, "w"), indent=1, ensure_ascii=False); print(f"scenes §{sec}: {len(shots)}", flush=True); break
              except Exception as e:
                  print(f"scenes §{sec} attempt {attempt+1}: {type(e).__name__} {str(e)[:100]}", flush=True); time.sleep(3 * 2 ** attempt)

# ───────────────────────── prompt assembly ─────────────────────────
def color_for(idx): return DARK_CYCLE[idx % len(DARK_CYCLE)]

def prompt_for(idx):
    s = S[idx]; sc = load_scenes(); color = color_for(idx)
    if s["kind"] == "sign": return PALETTE + ALCOVE.format(color=color, action=SIGN_ACTION), color
    if s["kind"] == "close": return PALETTE + ALCOVE.format(color=color, action=CLOSE_ACTION), color
    scene = sc.get(s["id"], "The courtroom in the sand: the bench, the witness chair, the empty jury chairs, the gallery.")
    scene = re.sub(r"\{(\w+)\}", lambda m: CHAR.get(m.group(1).upper().replace("MCCLANE", "McCLANE"), m.group(1)), scene)
    return STYLE + scene + " " + CHRONICLER(color), color

# ───────────────────────── OpenAI stages ─────────────────────────
def client():
    from openai import OpenAI
    return OpenAI(api_key=api_key(), timeout=180, max_retries=2)

def gen_image(idx, c):
    s = S[idx]
    if s["card"]: return None
    out = os.path.join(IMG, s["id"] + ".png")
    if os.path.exists(out): return out
    prompt, _ = prompt_for(idx)
    for attempt in range(5):
        try:
            r = c.images.generate(model="gpt-image-1", prompt=prompt, size="1536x1024", quality="medium", n=1)
            open(out, "wb").write(base64.b64decode(r.data[0].b64_json))
            print("image", s["id"], flush=True); return out
        except Exception as e:
            w = min(120, 8 * 2 ** attempt) + random.uniform(0, 3)
            print(f"image {s['id']} attempt {attempt+1} failed ({type(e).__name__}: {str(e)[:120]}); sleeping {w:.0f}s", flush=True); time.sleep(w)
    raise RuntimeError(s["id"])

def stage_images(only=None):
    c = client()
    idxs = [i for i in range(len(S)) if not S[i]["card"] and (only is None or S[i]["id"] in only)]
    with cf.ThreadPoolExecutor(4) as ex:
        list(ex.map(lambda i: gen_image(i, c), idxs))

AUDIT_Q = ("List every human figure in this drawing. For each one, say in 5 words what they look like, then answer: does this figure have drawn eyes "
           "AND a drawn mouth (a clearly rendered, recognisable face)? A face covered by scribbles, a blank face, or a flat silhouette counts as NOT drawn. "
           "Also: is there any readable text, letters or numbers anywhere? And: is there a small flat single-colour silhouette figure high up at the back of the room, "
           "in the upper part of the picture, at a lectern or desk with a book? Output ONLY JSON: "
           '{"figures": [{"who": "...", "face_drawn": true|false}], "text_visible": true|false, "chronicler_high_at_back": true|false}')

def audit_image(c, path):
    b64 = base64.b64encode(open(path, "rb").read()).decode()
    for attempt in range(3):
        try:
            r = c.chat.completions.create(model="gpt-5", messages=[{"role": "user", "content": [
                {"type": "text", "text": AUDIT_Q},
                {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{b64}", "detail": "high"}}]}])
            t = r.choices[0].message.content.strip(); t = t[t.find("{"): t.rfind("}") + 1]; d = json.loads(t)
            n = sum(1 for f in d.get("figures", []) if f.get("face_drawn"))
            res = {"faces_visible": n > 0, "n_faces": n, "text_visible": bool(d.get("text_visible")), "chronicler": bool(d.get("chronicler_high_at_back")),
                   "note": "; ".join(f["who"] for f in d.get("figures", []) if f.get("face_drawn"))[:120]}
            print("audit", os.path.basename(path), "faces", n, "text", res["text_visible"], "chron", res["chronicler"], flush=True)
            return res
        except Exception as e:
            err = f"{type(e).__name__}: {str(e)[:80]}"; time.sleep(5 * 2 ** attempt)
    return {"faces_visible": None, "text_visible": None, "chronicler": None, "note": err}

def stage_audit(only=None, move=True):
    import shutil
    c = client(); rej = os.path.join(IMG, "rejected"); os.makedirs(rej, exist_ok=True)
    report, bad = {}, []
    paths = [(s["id"], os.path.join(IMG, s["id"] + ".png")) for s in S if not s["card"] and (only is None or s["id"] in only)]
    with cf.ThreadPoolExecutor(6) as ex:
        for sid, res in zip([p[0] for p in paths], ex.map(lambda p: audit_image(c, p[1]) if os.path.exists(p[1]) else {"missing": True}, paths)):
            report[sid] = res
            need_chron = S[IDX[sid]]["kind"] not in ("sign", "close")     # the two close-ups ARE the chronicler
            if res.get("faces_visible") or res.get("text_visible") or res.get("missing") or (need_chron and res.get("chronicler") is False): bad.append(sid)
    ap = os.path.join(HERE, "audit.json")
    prev = json.load(open(ap)) if os.path.exists(ap) else {}
    prev.update(report); json.dump(prev, open(ap, "w"), indent=1)
    for sid in bad:
        print("REJECT", sid, report[sid].get("note"), "" if report[sid].get("chronicler", True) else "(no chronicler)", flush=True)
        if move and os.path.exists(os.path.join(IMG, sid + ".png")):
            src = os.path.join(IMG, sid + ".png"); n = len([f for f in os.listdir(rej) if f.startswith(sid)])
            shutil.move(src, os.path.join(rej, f"{sid}_r{n}.png"))
    print(f"audit: {len(paths)} checked, {len(bad)} rejected", flush=True)
    return bad

# ───────────────────────── ElevenLabs TTS ─────────────────────────
def eleven_key():
    k = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not k and os.path.exists(ELEVEN_ENV):
        for ln in open(ELEVEN_ENV):
            if ln.startswith("ELEVENLABS_API_KEY="): k = ln.split("=", 1)[1].strip().strip('"').strip("'")
    if not k: sys.exit("ELEVENLABS_API_KEY not found")
    return k

def eleven_tts(who, text, out_wav):
    if os.path.exists(out_wav): return out_wav
    vid, stab, speed = VOICE[who]
    payload = {"text": text, "model_id": ELEVEN_MODEL,
               "voice_settings": {"stability": stab, "similarity_boost": 0.75, "style": 0.0, "use_speaker_boost": True, "speed": speed}}
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{vid}?output_format=mp3_44100_128"
    for attempt in range(6):
        req = urllib.request.Request(url, data=json.dumps(payload).encode(), method="POST",
                                     headers={"xi-api-key": eleven_key(), "Content-Type": "application/json", "Accept": "audio/mpeg"})
        try:
            with urllib.request.urlopen(req, timeout=120) as resp: mp3 = resp.read()
            tmp = out_wav + ".mp3"; open(tmp, "wb").write(mp3)
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-ac", "1", "-ar", "24000", "-c:a", "pcm_s16le", out_wav], check=True)
            os.remove(tmp); return out_wav
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", "replace")[:160]; w = min(90, 6 * 2 ** attempt) + random.uniform(0, 2)
            print(f"tts {os.path.basename(out_wav)} HTTP {e.code} {body}; sleeping {w:.0f}s", flush=True); time.sleep(w)
        except Exception as e:
            w = min(90, 6 * 2 ** attempt); print(f"tts {os.path.basename(out_wav)} {type(e).__name__}; sleeping {w}s", flush=True); time.sleep(w)
    raise RuntimeError(out_wav)

def pcm_of(path):
    raw = open(path, "rb").read(); k = raw.find(b"data"); return raw[k + 8:]

def write_wav(out, pcm, rate=24000):
    with wave.open(out, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate); w.writeframes(pcm)

def sil(sec, rate=24000): return b"\x00" * (int(rate * sec) * 2)

def stage_tts(only=None):
    def one(s):
        out = os.path.join(AUD, s["id"] + ".wav")
        if os.path.exists(out): return
        if s["kind"] in ("sign", "close"):
            write_wav(out, sil(5.0)); return
        lead, tail = (0.5, 0.9) if s["kind"] == "head" else (0.25, 0.55)
        part = eleven_tts(s["who"], spoken(s), os.path.join(AUD, f"{s['id']}_{s['who']}.wav"))
        pcm = pcm_of(part); pcm = pcm[: len(pcm) - len(pcm) % 2]
        min_total = 3.0
        body = sil(lead) + pcm + sil(tail)
        if len(body) < 24000 * 2 * min_total: body += sil(min_total - len(body) / 48000)
        write_wav(out, body); print("tts", s["id"], s["who"], f"{len(body)/48000:.1f}s", flush=True)
    todo = [s for s in S if only is None or s["id"] in only]
    with cf.ThreadPoolExecutor(3) as ex: list(ex.map(one, todo))

# ───────────────────────── frames ─────────────────────────
W, H = 1920, 1080; IMG_W, IMG_H = 1380, 920; PANEL_X = IMG_W; CAP_Y = IMG_H
BG = (14, 10, 16); PARCH = (222, 212, 190); INK = (28, 22, 30); EMBER = (120, 30, 90); CREAM = (240, 230, 205); FADE = (120, 105, 85)

def draw_card(s):
    """Appendix tables as dark parchment cards: header row + the rows being read in this shot, wrapped."""
    from PIL import Image, ImageDraw, ImageFont
    img = Image.new("RGB", (1536, 1024), PARCH); d = ImageDraw.Draw(img)
    fH = ImageFont.truetype(FONT_ITAL, 26); fR = ImageFont.truetype(FONT_SERIF, 26); fL = ImageFont.truetype(FONT_SERIF, 30)
    hdr, rows = s["hdr"], [s["rows"][k] for k in s["hi"]]
    ncol = len(hdr); x0, x1 = 70, 1466
    weights = [0.9 if j == 0 else max(2.0, min(6.0, sum(len(r[j]) for r in s["rows"]) / max(1, len(s["rows"])) / 18.0)) for j in range(ncol)]
    tot = sum(weights); widths = [int((x1 - x0) * w / tot) for w in weights]
    xs = [x0]; [xs.append(xs[-1] + w) for w in widths]
    y = 60
    for j, h in enumerate(hdr):
        if h: d.text((xs[j] + 8, y), h, font=fH, fill=EMBER)
    y += 44; d.line((x0, y, x1, y), fill=INK, width=2); y += 18
    for r in rows:
        cells = []
        for j in range(ncol):
            cpl = max(8, int(widths[j] / 13.5)); cells.append(textwrap.wrap(r[j], cpl) or [""])
        hgt = max(len(c) for c in cells) * 32
        for j, c in enumerate(cells):
            for k, wl in enumerate(c): d.text((xs[j] + 8, y + k * 32), wl, font=(fL if j == 0 else fR), fill=INK)
        y += hgt + 22; d.line((x0, y - 11, x1, y - 11), fill=FADE, width=1)
    fS = ImageFont.truetype(FONT_ITAL, 20); d.text((x0, 990), f"rows {s['hi'][0]+1}–{s['hi'][-1]+1} of {len(s['rows'])}", font=fS, fill=FADE)
    p = os.path.join(CARDS, f"{s['id']}.png"); img.save(p); return p

def fit_text(d, text, font_path, max_w, max_h, start=34, min_size=20):
    from PIL import ImageFont
    size = start
    while size >= min_size:
        f = ImageFont.truetype(font_path, size); lines = []
        for para in text.split("\n"): lines += textwrap.wrap(para, max(10, int(max_w / (size * 0.47)))) or [""]
        lh = int(size * 1.25)
        if lh * len(lines) <= max_h: return f, lines, lh
        size -= 2
    return f, lines[: max(1, max_h // lh)], lh

def record_entries(upto):
    """The actual statements made so far (verbatim), as (speaker, text), merging consecutive chunks of the same speech."""
    ents = []
    for s in S[: upto + 1]:
        if s["kind"] == "say":
            if ents and ents[-1][0] == s["who"] and ents[-1][2] == s["sec"] and ents[-1][3] == IDX[s["id"]] - 1:
                ents[-1] = (s["who"], ents[-1][1] + " " + s["text"], s["sec"], IDX[s["id"]])
            else: ents.append((s["who"], s["text"], s["sec"], IDX[s["id"]]))
        elif s["kind"] == "write":
            verb = "types" if " types: " in s["text"] else "writes"
            ents.append((s["writer"] + " " + verb, s["text"].split(f" {verb}: ", 1)[1], s["sec"], IDX[s["id"]]))
    return ents

def compose_frame(idx):
    from PIL import Image, ImageDraw, ImageFont
    s = S[idx]; out = os.path.join(FRM, s["id"] + ".png")
    src = draw_card(s) if s["card"] else os.path.join(IMG, s["id"] + ".png")
    img = Image.open(src).convert("RGB").resize((IMG_W, IMG_H), Image.LANCZOS)
    fr = Image.new("RGB", (W, H), BG); fr.paste(img, (0, 0)); d = ImageDraw.Draw(fr)
    # the record (parchment panel): actual statements, newest at the bottom and darkest
    d.rectangle((PANEL_X, 0, W, IMG_H), fill=PARCH); d.line((PANEL_X, 0, PANEL_X, IMG_H), fill=INK, width=3)
    col_sw = RGB[color_for(idx)]; d.rectangle((PANEL_X + 28, 26, PANEL_X + 44, 42), fill=col_sw); d.line((PANEL_X + 28, 56, W - 28, 56), fill=INK, width=1)
    fHand = ImageFont.truetype(FONT_HAND, 19); fWho = ImageFont.truetype(FONT_ITAL, 20); lh = 25
    ents = record_entries(idx)
    if s["kind"] in ("sign", "close"):
        ents = record_entries(len(S) - 3)
    blocks, y = [], IMG_H - 36 - (90 if s["kind"] == "sign" else 0)
    for k, (who, text, _, _) in enumerate(reversed(ents)):
        wrapped = textwrap.wrap(text, 42); hgt = lh * len(wrapped) + 26 + 8
        if y - hgt < 80 and k > 0: break
        blocks.append((who, wrapped, k)); y -= hgt
    y = max(80, y)
    for who, wrapped, k in reversed(blocks):
        fade = min(1.0, k / 4.0); col = tuple(int(a + (b - a) * fade * 0.8) for a, b in zip(INK, PARCH)); colw = tuple(int(a + (b - a) * fade * 0.8) for a, b in zip(EMBER, PARCH))
        d.text((PANEL_X + 30, y), who_display(who.split(" ")[0]) + (" " + who.split(" ")[1] if " " in who else ""), font=fWho, fill=colw); y += 26
        for wl in wrapped: d.text((PANEL_X + 30, y), wl, font=fHand, fill=col); y += lh
        y += 8
    if s["kind"] == "sign":
        fSig = ImageFont.truetype(FONT_HAND, 44); d.text((PANEL_X + 260, IMG_H - 92), "— Widukind", font=fSig, fill=INK)
    if s["kind"] == "close":
        # the book, closed
        d.rectangle((PANEL_X, 0, W, IMG_H), fill=PARCH)
        bx0, by0, bx1, by1 = PANEL_X + 120, 300, W - 120, 620
        d.rectangle((bx0 + 10, by0 + 12, bx1 + 10, by1 + 12), fill=(150, 130, 95)); d.rectangle((bx0, by0, bx1, by1), fill=(110, 60, 40), outline=INK, width=3)
        d.line((bx0 + 30, by0, bx0 + 30, by1), fill=INK, width=2)
    # caption bar: the exact text
    d.rectangle((0, CAP_Y, W, H), fill=BG); d.line((0, CAP_Y, W, CAP_Y), fill=col_sw, width=3)
    if s["text"]:
        tag = (who_display(s["who"]).upper() + ":  ") if s["kind"] == "say" else ""
        f, lines, lh2 = fit_text(d, tag + s["text"], FONT_SERIF if s["kind"] != "head" else FONT_ITAL, W - 80, H - CAP_Y - 24, start=34 if s["kind"] == "head" else 30, min_size=18)
        y = CAP_Y + 14
        for ln in lines:
            x = 40
            if tag and ln.startswith(tag): d.text((x, y), tag, font=f, fill=EMBER); x += d.textlength(tag, font=f); ln = ln[len(tag):]
            d.text((x, y), ln, font=f, fill=CREAM); y += lh2
    fId = ImageFont.truetype(FONT_ITAL, 18); d.text((W - 160, H - 26), f"§{s['sec']}  {s['id']}" if s["sec"] < 99 else s["id"], font=fId, fill=FADE)
    fr.save(out); return out

def stage_frames(only=None):
    for i, s in enumerate(S):
        if only and s["id"] not in only: continue
        compose_frame(i); print("frame", s["id"], flush=True)

# ───────────────────────── video ─────────────────────────
def wav_dur(p):
    with wave.open(p, "rb") as w: return w.getnframes() / w.getframerate()

def stage_video():
    lst = os.path.join(CLIP, "list.txt"); entries = []
    def one(s):
        fr = os.path.join(FRM, s["id"] + ".png"); au = os.path.join(AUD, s["id"] + ".wav"); clip = os.path.join(CLIP, s["id"] + ".mp4")
        if not os.path.exists(clip):
            dur = wav_dur(au)
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-loop", "1", "-framerate", "24", "-i", fr, "-i", au,
                            "-t", f"{dur:.3f}", "-vf", f"fade=t=in:st=0:d=0.3,fade=t=out:st={max(0, dur-0.3):.3f}:d=0.3,format=yuv420p",
                            "-c:v", "libx264", "-preset", "medium", "-crf", "19", "-c:a", "aac", "-b:a", "160k", "-ar", "24000", "-shortest", clip], check=True)
            print("clip", s["id"], f"{dur:.1f}s", flush=True)
        return clip
    with cf.ThreadPoolExecutor(4) as ex: clips = list(ex.map(one, S))
    open(lst, "w").write("".join(f"file '{c}'\n" for c in clips))
    out = os.path.join(HERE, OUT_MP4)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", out], check=True)
    total = sum(wav_dur(os.path.join(AUD, s["id"] + ".wav")) for s in S)
    print("video", out, f"{total/60:.1f} min", flush=True); return out, total

# ───────────────────────── storyboard ─────────────────────────
def stage_story():
    from PIL import Image, ImageDraw, ImageFont
    thumbs = [os.path.join(FRM, s["id"] + ".png") for s in S]
    per = 20; cols = 4; tw, th = 460, 259
    f = ImageFont.truetype(FONT_SERIF, 16); sheets = []
    for pg in range(0, len(thumbs), per):
        rows = (min(per, len(thumbs) - pg) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * (tw + 14) + 14, rows * (th + 34) + 14), BG); d = ImageDraw.Draw(sheet)
        for k, p in enumerate(thumbs[pg:pg + per]):
            im = Image.open(p).resize((tw, th)); x = 14 + (k % cols) * (tw + 14); y = 14 + (k // cols) * (th + 34)
            sheet.paste(im, (x, y)); s = S[pg + k]
            d.text((x, y + th + 7), f"{s['id']}  §{s['sec']}  {s['who'] or ''}  {color_for(pg+k)}", font=f, fill=CREAM)
        sp = os.path.join(HERE, f"storyboard_{pg//per+1:02d}.png"); sheet.save(sp); sheets.append(sp)
    L = ["# Storyboard — Hume v. Spock (Part Two)", "",
         "One row per shot. The text is the fable, exactly; `voice` is the ElevenLabs speaker; `colour` is the chronicler's colour in that shot. "
         "Prompts are the full text sent to the image model (style + scene + chronicler clause).", ""]
    tot = 0
    for i, s in enumerate(S):
        au = os.path.join(AUD, s["id"] + ".wav"); dur = wav_dur(au) if os.path.exists(au) else 0; tot += dur
        prompt, colour = prompt_for(i) if not s["card"] else (f"(card drawn by code: {s['card']})", color_for(i))
        L.append(f"## {s['id']} · §{s['sec']} · {s['kind']} · {colour} · {dur:.1f} s"); L.append("")
        L.append(f"![{s['id']}](frames/{s['id']}.png)"); L.append("")
        if s["text"]: L.append(f"- **{s['who']}:** {s['text']}")
        L.append(f"- <details><summary>prompt</summary>{prompt}</details>"); L.append("")
    L.insert(3, f"Shots: {len(S)} · images: {sum(1 for s in S if not s['card'])} · cards: {sum(1 for s in S if s['card'])} · runtime: {tot/60:.1f} min · sheets: " + ", ".join(os.path.basename(x) for x in sheets))
    open(os.path.join(HERE, "STORYBOARD.md"), "w").write("\n".join(L) + "\n")
    json.dump([dict(id=s["id"], sec=s["sec"], kind=s["kind"], who=s["who"], text=s["text"], card=s["card"], colour=color_for(i),
                    prompt=(prompt_for(i)[0] if not s["card"] else None)) for i, s in enumerate(S)],
              open(os.path.join(HERE, "shots.json"), "w"), indent=1, ensure_ascii=False)
    print("storyboard", len(sheets), "sheets", f"{tot/60:.1f} min")

if __name__ == "__main__":
    args = sys.argv[1:] or ["parse"]
    only = None
    if "--only" in args:
        only = set(args[args.index("--only") + 1].split(",")); args = [a for a in args if a not in ("--only", args[args.index("--only") + 1])]
    stage = args[0]
    if stage == "parse":
        for i, s in enumerate(S): print(s["id"], f"§{s['sec']}", s["kind"], s["who"], color_for(i), "|", s["text"][:150])
        print(len(S), "shots;", sum(1 for s in S if not s["card"]), "images;", sum(len(s["text"]) for s in S), "chars")
    if stage in ("scenes", "all"): stage_scenes(only)
    if stage in ("images", "all"): stage_images(only)
    if stage == "audit": stage_audit(only, move="--keep" not in sys.argv)
    if stage == "fixloop":
        for rnd in range(int(args[1]) if len(args) > 1 else 3):
            bad = stage_audit(only)
            if not bad: break
            print(f"fixloop round {rnd+1}: regenerating {len(bad)}", flush=True); stage_images(set(bad)); only = set(bad)
    if stage in ("tts", "all"): stage_tts(only)
    if stage in ("frames", "all"): stage_frames(only)
    if stage in ("video", "all"): stage_video()
    if stage in ("story", "all"): stage_story()
    if stage == "prompts":
        for i, s in enumerate(S):
            if not s["card"]: print(s["id"], color_for(i), "|", prompt_for(i)[0][len(STYLE):][:200])
