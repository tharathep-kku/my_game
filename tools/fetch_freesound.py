# Fetch CC0 SFX from freesound.org (public HQ previews, no account needed).
#   python tools/fetch_freesound.py --list squeak hum   -> show candidates (index, title, duration, url)
#   python tools/fetch_freesound.py squeak hum          -> download the chosen ones
# Writes assets/sfx/<name>.ogg and appends tools/freesound_credits.txt
import os, re, sys, urllib.parse, urllib.request, html as H

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
UA = {"User-Agent": "Mozilla/5.0"}
# name: (query, min_sec, max_sec, pick)  pick = index among results (see --list)
WANT = {
    "heartbeat": ("heartbeat", 3, 20, 0),
    "drone": ("dark ambient drone", 20, 120, 0),
    "door_slam": ("door slam", 0.3, 3, 0),
    "elevator_ding": ("elevator ding", 0.3, 4, 0),
    "chair_creak": ("chair creak", 0.3, 4, 0),
    "printer": ("printer printing", 2, 12, 0),
    "whisper": ("creepy whisper", 1, 6, 0),
    "knock": ("door knock", 1, 5, 0),
    "footsteps_far": ("footsteps hallway", 2, 8, 0),
    # human voices / bodies for the coworkers (replace the old synth tones)
    "squeak": ("shoe squeak", 0.2, 2, 0),
    "hum": ("woman humming", 3, 25, 2),
    "mutter": ("man mumbling", 1, 8, 0),
    "techspeak": ("gibberish talking", 1, 8, 2),
    "guard_talk": ("man whispering", 2, 10, 0),
    "breathing": ("heavy breathing scared", 3, 25, 0),
    "gasp": ("gasp", 0.3, 2, 5),
    "sting": ("gasp", 0.3, 2, 7),   # startled gasp when a coworker spots you
    # jumpscare layers (raw material; tools/synth_jumpscare.py mixes them into scare_*.wav)
    "scream_raw": ("horror scream", 0.5, 4, 0),
    "hit_raw": ("horror impact", 0.5, 5, 0),
}

def get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60).read()

def results(q, lo, hi):
    f = f'license:"Creative Commons 0" duration:[{lo} TO {hi}]'
    page = get("https://freesound.org/search/?" + urllib.parse.urlencode({"q": q, "f": f})).decode("utf-8", "replace")
    out = []
    for ogg, sid in re.findall(r'data-ogg="(https://cdn\.freesound\.org/previews/\d+/(\d+)_\d+-lq\.ogg)"', page):
        m = re.search(r'href="/people/([^/"]+)/sounds/%s/"[^>]*>\s*([^<]+)<' % sid, page)
        user, title = (urllib.parse.unquote(m.group(1)), H.unescape(m.group(2).strip())) if m else ("?", "?")
        dur = re.search(r'data-duration="([\d.]+)"[^>]*data-ogg="%s"|data-ogg="%s"[^>]*data-duration="([\d.]+)"' % (re.escape(ogg), re.escape(ogg)), page)
        d = (dur.group(1) or dur.group(2)) if dur else "?"
        if not any(o[1] == sid for o in out):
            out.append((ogg, sid, user, title, d))
    return out

listing = "--list" in sys.argv
names = [a for a in sys.argv[1:] if not a.startswith("--")] or list(WANT)
picks = {}
for a in sys.argv[1:]:
    if a.startswith("--pick="):   # --pick=name:index
        n, i = a[7:].split(":")
        picks[n] = int(i)
credits = []
for name in names:
    q, lo, hi, pick = WANT[name]
    pick = picks.get(name, pick)
    res = results(q, lo, hi)
    if listing:
        print(f"== {name} ({q})")
        for i, (ogg, sid, user, title, d) in enumerate(res[:8]):
            print(f"  [{i}] {title}  ({d}s) by {user}  https://freesound.org/people/{user}/sounds/{sid}/")
        continue
    if len(res) <= pick:
        print("NO RESULT", name); continue
    ogg, sid, user, title, d = res[pick]
    data = get(ogg.replace("-lq.ogg", "-hq.ogg"))
    open(os.path.join(OUT, name + ".ogg"), "wb").write(data)
    page = f"https://freesound.org/people/{user}/sounds/{sid}/"
    credits.append(f"{name}.ogg | {page} | {user} | CC0 | {title}")
    print(name, len(data), title, page)
if credits:
    open(os.path.join(os.path.dirname(__file__), "freesound_credits.txt"), "a", encoding="utf-8").write("\n".join(credits) + "\n")
