# Sprout Lands tiles

Warm cozy top-down 16×16 terrain for Ant Explorer (replaces the harsh Kenney iso dungeon cubes).

## Pack layout

Unzip the premium pack so the inner root sits beside this README. Symlinks give clean `res://` paths:

```
game/assets/tiles/sprout_lands/
├── README.md
├── Tilesets/   → ../Sprout Lands - …/Tilesets
└── Objects/    → ../Sprout Lands - …/Objects
```

`TerrainCatalog.gd` loads floor textures from `Tilesets/ground tiles/` (atlas mid cells and cutout PNGs).
Kenney iso cubes remain a **fallback only** if Sprout Lands assets are missing.

## License

- Page: https://cupnooble.itch.io/sprout-lands-asset-pack
- Premium pack (≥ $3.99): commercial/non-commercial use; may modify; **do not resell/redistribute** the raw art.
- Credit "Cup Nooble" appreciated.
