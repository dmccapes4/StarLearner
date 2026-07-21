**Refined concept: “Ant Colony Explorer” — a dedicated landscape interactive documentary viewer for a 6-year-old.**

The phone becomes a single-purpose device. It boots into landscape orientation with a minimal custom launcher showing one large tile labeled “ants”. Tapping it launches a 2D top-down (or slight isometric) colony simulation where your daughter controls one worker ant. The colony is a living but dramatically simplified simulation of a leaf-cutter ant nest. Exploration is the core loop; learning is the reward.

### Core Design Numbers
- **Total living ants**: hard cap of 90–100 (including the player ant). This keeps the world feeling busy without performance or visual clutter issues on the Snapdragon 680 / 4 GB RAM hardware.
- **Caste breakdown (approximate steady state)**:
  - 1 Queen
  - 12–15 Soldiers
  - 30–35 Media/foragers
  - 25–30 Minors/gardeners/nurses
  - 15–25 Brood (larvae + pupae combined; numbers fluctuate)
- **Map structure**: 7–9 connected chambers/zones linked by tunnels (graph of nodes).
  - Surface foraging area (small outdoor patch with leaf sources)
  - Main entrance / vestibule
  - Fungal garden chambers (2)
  - Brood / nursery chamber
  - Queen chamber
  - Waste dump / refuse chamber
  - Soldier outpost / defensive tunnel
- **Movement**: Click/tap destination on a path or chamber. Ant walks along predefined tunnel paths or open space. Pheromone trails are visible glowing paths that NPCs follow; tapping a trail assigns the player ant to that task (forage, garden, nurse, defend, etc.).
- **Simulation tick**: Accelerated. One real-time minute ≈ several colony “hours.” Larvae progress through stages, pupae eclose into adults of appropriate caste, older workers die and are carried to the dump. Population stays roughly stable via simple birth/death rates tied to fungal garden “health.”
- **Stars / knowledge nodes**: 12–15 glowing star animations placed at key locations. Approaching or clicking a star moves the player ant there and plays a short (1–4 min) documentary segment. Stars can be re-watched anytime. Goal = collect/view all of them (map fully explored + all content seen). Progress is saved.

Fungal garden is mandatory and central: workers deposit leaf fragments, gardeners tend the fungus, larvae are fed on it, garden health affects brood survival and overall activity level.

Soldier ants periodically detect and push back simple “invader” events (small groups of enemy ants that appear at the entrance). Player can join the defense by tapping the relevant pheromone trail.

### Hardware & OS Plan (Moto G Play 2024 / XT2413)
The device is inexpensive, has a 6.5″ 1600×720 90 Hz LCD, Snapdragon 680, 4 GB RAM, 5000 mAh battery, and microSD. It is rootable.

1. Unlock bootloader via Motorola’s official site (requires account and unique unlock code).
2. Extract `init_boot.img` from the matching stock firmware.
3. Patch with Magisk (v27+ or Canary) and flash via fastboot. Root is reliable on this model when using `init_boot` rather than `boot`.
4. Install a kiosk / single-app launcher (Fully Kiosk Browser in app mode, or a lightweight custom launcher, or Nova Launcher locked down). Force landscape orientation system-wide. Disable status bar, navigation gestures, and app drawer so only the “ants” tile is visible.
5. Optional but useful: Magisk modules for further lockdown, ad-blocking, and battery optimization. Expand storage with a fast microSD card for video assets.
6. Full Linux distro replacement (postmarketOS, Ubuntu Touch, etc.) is not practical on this specific model right now. Stay on rooted Android + kiosk mode. It is more stable for a child’s dedicated device and easier to maintain.

The game itself will be an Android APK (Godot 4 recommended — excellent 2D performance, simple agent simulation, easy Android export, and you already think in state graphs).

### Documentary Content (12 knowledge stars)
Each star plays a curated short clip (ideally offline MP4s you extract and store on the device). Primary high-quality sources:

| # | Topic | Suggested Source Material |
|---|-------|---------------------------|
| 1 | Queen & egg-laying | BBC *Planet Ant: Life Inside the Colony* (McGavin/Hart) – queen chamber sequences |
| 2 | Larvae & nursing | Same BBC documentary + AntsCanada leafcutter farm videos |
| 3 | Pupae & caste determination | BBC *Planet Ant* + educational segments on size-based castes |
| 4 | Fungal garden cultivation | AntsCanada “My Dream Ant Farm: Leafcutter Ants”, Canadian Museum of Nature leafcutter feature, Deep Look / PBS |
| 5 | Leaf cutting & foraging trails | National Geographic *A Real Bug’s Life* leafcutter episode, AntsCanada foraging footage |
| 6 | Pheromone communication | BBC *Planet Ant* leafcutter Y-trail / scent-talk (~56:00) |
| 7 | Soldier caste & defense | BBC *Planet Ant* defense sequences + general leafcutter soldier footage |
| 8 | Waste management / dump | AntsCanada and museum exhibit videos showing refuse chambers |
| 9 | Division of labor / social structure | Deep Look “Where Are the Ants Carrying All Those Leaves?”, Science Nation |
| 10 | Symbiotic bacteria & garden hygiene | Academic/museum explainers (e.g., Central Texas Mycological Society talk or PNNL-related shorts) |
| 11 | Colony architecture & tunnels | BBC *Planet Ant* nest excavation and chamber views |
| 12 | Invaders & colony resilience | Clips of army ant raids or defensive responses from the same major documentaries |

You can expand to 14–15 later (e.g., nuptial flights, founding a new colony, comparison with other ant species). Prefer short, high-visual, low-narration-heavy segments suitable for a young child. Download and trim the clips yourself so everything works offline.

### Development Phases (Practical Steps)
**Phase 0 – Research & Assets (1–2 weeks)**  
Collect and trim the 12 video segments. Gather simple 2D ant sprites (different sizes for castes), tunnel/chamber tiles, fungus garden tiles, pheromone trail effects, and star animations. Decide on art style (cute but still recognizably leaf-cutter).

**Phase 1 – Prototype Core Loop (1–2 weeks)**  
Godot 4 project. Single chamber + a few tunnels. Player ant click-to-move. 20–30 NPC ants with basic state machines (idle, walk trail, forage, tend garden, nurse). Simple pheromone trail rendering. One star that plays a video.

**Phase 2 – Full Map & Simulation (2–3 weeks)**  
Build the 7–9 chamber graph. Implement population dynamics (larval progression, eclosion into correct caste, aging/death, dump carrying). Fungal garden health metric that influences brood survival. Occasional invader events. Save system for stars collected and colony state.

**Phase 3 – Polish & Kiosk Integration (1–2 weeks)**  
Landscape-only, touch-friendly UI (minimal text, large targets). Progress indicator for stars. Soft tutorial (first few stars are obvious). Battery and thermal considerations for long play sessions. Package as APK, install on the rooted device, lock the launcher.

**Phase 4 – Daughter Testing & Iteration**  
Play sessions with her. Watch what she gravitates toward (fungal garden? soldiers? stars?). Adjust difficulty of navigation, density of ants, frequency of events, and which stars appear where. Keep the simulation “alive” enough that the colony feels real but never chaotic or frustrating.

**Later expansions** (after the core is loved)  
- Additional colonies or seasonal variations  
- Simple “help the colony” goals that temporarily boost garden health or repel invaders  
- Voice-over or very short on-device explanations in addition to the videos  
- More sophisticated local simulation if desired (still capped near 100 ants)

### Why This Works for Her (and You)
It matches the construction of *Purple’s Galaxy Quest*: clear navigation, state-driven agents, exploration as the main activity, and educational payoff that feels like discovery rather than a lesson. The pheromone trails and task participation give agency without complex controls. The hard star-collection goal creates a gentle completionist loop. The simplified 100-ant sim is enough for the world to feel alive while remaining completely tractable on the hardware and for a solo developer.

This is a very buildable, high-delight project. Start with the rooted phone + one-chamber prototype + two or three video stars and you will quickly see whether the core fantasy lands with her. Everything else scales from there.
