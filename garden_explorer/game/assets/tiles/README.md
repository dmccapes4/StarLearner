# Sprout Lands for Garden Explorer

This folder and `Sprout Lands - Sprites - premium pack` are symlinks into
`ant_explorer/game/assets/tiles/` so both games share one licensed copy.

See ant_explorer sprout_lands README for license. Re-link if broken:

```bash
cd game/assets/tiles
ln -sfn ../../../../ant_explorer/game/assets/tiles/sprout_lands sprout_lands
ln -sfn "../../../../ant_explorer/game/assets/tiles/Sprout Lands - Sprites - premium pack" \
  "Sprout Lands - Sprites - premium pack"
```
