# Asset license log

Every third-party or generated asset gets one row before it ships.

| Asset | Source / tool | License | Date | Notes |
| --- | --- | --- | --- | --- |
| Vehicle meshes (hatchback, sedan, taxi, muscle car, supercar, ice-cream truck, fire truck, semi, monster truck body) and palette texture | "Low Poly City Vehicles Pack" v1.2 by Pavel 3D, https://pavel-3d.itch.io/low-poly-city-vehicles-pack | CC BY 4.0 (credit "Pavel 3D") | 2026-10-30 | Credited in the in-game store and the game description. Monster truck = pickup with scaled wheels and a lift kit (`tools/blender/export_vehicles.py`) |
| Bulldozer, scooter, shopping cart meshes | Made in Blender by script (`tools/blender/export_vehicles.py`), coloured with the pack palette | Own work | 2026-10-30 | |
| Roadster mesh (simplified) | Sketchfab-style 2020 roadster model, reduced and recoloured in Blender | Check before release: source licence and look-alike risk | 2026-10-30 | No badges or brand names in game |
| Engine, road, wind and tyre sound loops | Synthesised with numpy | Own work | 2026-10-29 | |
| Impact, comic boink, squeal, cash register, whoosh, crash, glass, explosion and sting sounds (ids in `src/client/Fx.luau`) | Roblox audio library, Pro Sound Effects partner sounds | Free for use in Roblox experiences (Roblox licensed library) | 2026-10-30 | Played by id, not re-uploaded |
