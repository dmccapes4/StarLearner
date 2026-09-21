#!/usr/bin/env bash
# narrate_555.sh — flip + label + narrate the raw frames into the final video.
# Usage: bash game/tools/narrate_555.sh
# Must be run from the solar_system_explorer directory.
set -euo pipefail

FRAMES="game/docs/video/mars_cancer_gemini_555"
OUT="game/docs/video/mars_cancer_gemini_555.mp4"
FPS=30

# ── Star label positions (FLIPPED 1280×600, field-centre RA 8.2h Dec +22°) ──
# px/deg ≈ (600/2) / tan(22.5°) = 12.63 px/deg
# x_unflip = 640 + (RA_star-8.2h)*15*cos(Dec_avg) * 12.63
# x_flip   = 1280 - x_unflip
# y        = 300  - (Dec_star-22) * 12.63
#
# Castor α Gem  RA 7.5765h Dec +31.9°  x_flip≈745  y≈175
# Pollux β Gem  RA 7.7553h Dec +28.0°  x_flip≈716  y≈224
# M44 Beehive   RA 8.667h  Dec +19.9°  x_flip≈557  y≈327
# Gemini ctr    RA 7.1h    Dec +24°    x_flip≈844  y≈275
# Cancer ctr    RA 8.65h   Dec +21°    x_flip≈561  y≈313

# Labels placed slightly off the star for readability
CASTOR_LX=753
CASTOR_LY=158
POLLUX_LX=665
POLLUX_LY=228
M44_LX=563
M44_LY=337
GEM_LX=830
GEM_LY=88
CNC_LX=410
CNC_LY=88

# ── Narration timing (seconds) ─────────────────────────────────────────────
# PAD=45 days before retrograde start (Nov 23, 557) → retro at t≈15 s
# 0.10 d/frame, 1700 frames, 30 fps → 56.7 s total
# Station 1 (Nov 23): frame 450 → t=15.0 s
# Peak (Jan  2, 558): frame 850 → t=28.3 s
# Station 2 (Feb 11): frame 1250 → t=41.7 s
# End       (Mar 28): frame 1700 → t=56.7 s

echo "Encoding ${OUT} from frames in ${FRAMES}…"

ffmpeg -y -r $FPS -i "${FRAMES}/frame_%05d.png" \
  -vf "
hflip,
drawtext=text='Mars Retrograde':
  x=(w-tw)/2:y=14:fontsize=26:fontcolor=white:
  shadowcolor=black:shadowx=2:shadowy=2,
drawtext=text='557 CE  --  Cancer and Gemini':
  x=(w-tw)/2:y=46:fontsize=18:fontcolor=0xFFCC55:
  shadowcolor=black:shadowx=1:shadowy=1,
drawtext=text='Gemini':
  x=${GEM_LX}:y=${GEM_LY}:fontsize=20:fontcolor=0xFFE88A:
  shadowcolor=black:shadowx=2:shadowy=2,
drawtext=text='Cancer':
  x=${CNC_LX}:y=${CNC_LY}:fontsize=20:fontcolor=0xFFE88A:
  shadowcolor=black:shadowx=2:shadowy=2,
drawtext=text='Castor':
  x=${CASTOR_LX}:y=${CASTOR_LY}:fontsize=15:fontcolor=white:
  shadowcolor=black:shadowx=1:shadowy=1,
drawtext=text='Pollux':
  x=${POLLUX_LX}:y=${POLLUX_LY}:fontsize=15:fontcolor=0xFFAA44:
  shadowcolor=black:shadowx=1:shadowy=1,
drawtext=text='Beehive M44':
  x=${M44_LX}:y=${M44_LY}:fontsize=13:fontcolor=0xAABBFF:
  shadowcolor=black:shadowx=1:shadowy=1,
drawtext=text='Winter 557 CE. Mars drifts eastward each night through Gemini (twins) and Cancer (crab).':
  x=20:y=552:fontsize=16:fontcolor=yellow:box=1:boxcolor=black@0.65:boxborderw=5:
  enable='between(t\,0\,14)',
drawtext=text='Castor and Pollux are the twin heads of Gemini. The Beehive cluster is the heart of Cancer.':
  x=20:y=552:fontsize=16:fontcolor=yellow:box=1:boxcolor=black@0.65:boxborderw=5:
  enable='between(t\,14\,15)',
drawtext=text='Mars slows and reverses near the Beehive -- Earth is overtaking it on the inner orbit.':
  x=20:y=552:fontsize=16:fontcolor=0xFFAA44:box=1:boxcolor=black@0.65:boxborderw=5:
  enable='between(t\,15\,19)',
drawtext=text='For 80 days Mars traces a retrograde arc -- from near Pollux eastward past the Beehive.':
  x=20:y=552:fontsize=16:fontcolor=yellow:box=1:boxcolor=black@0.65:boxborderw=5:
  enable='between(t\,19\,30)',
drawtext=text='The arc is drawn between the twins and the crab. Castor-to-Pollux * pi ~ Pollux-to-Beehive.':
  x=20:y=552:fontsize=16:fontcolor=0x88FFFF:box=1:boxcolor=black@0.65:boxborderw=5:
  enable='between(t\,30\,41)',
drawtext=text='Mars reaches its second station and resumes eastward. The retrograde loop is sealed.':
  x=20:y=552:fontsize=16:fontcolor=yellow:box=1:boxcolor=black@0.65:boxborderw=5:
  enable='between(t\,41\,47)',
drawtext=text='Ancient sky-watchers recorded this arc -- the loop between the crab and the twins.':
  x=20:y=552:fontsize=16:fontcolor=0xFFCC55:box=1:boxcolor=black@0.65:boxborderw=5:
  enable='between(t\,47\,57)'
  " \
  -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p "${OUT}"

echo "Done: ${OUT}"
