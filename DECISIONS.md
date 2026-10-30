# Decision log

One entry per decision: date, decision, reason.

- Code lives in files and syncs to Studio with Rojo. Studio is a viewer only.
- 2026-10-30: The map is built by `src/server/MapBuilder.luau` at server start from `Config/World` (same seed every time), so the world lives in code like everything else.
- 2026-10-30: Vehicles pass through players, NPCs, debris and each other (collision groups). NPC hits, building breaks and Wrecker hits are found by the driver's client with an overlap box and checked on the server.
- 2026-10-30: Vehicle meshes are built in Blender (`tools/blender/export_vehicles.py`), uploaded once, downloaded back and packed into `assets/Vehicles.rbxm` (`tools/lune/import_vehicles.luau`); rigs are built in code at spawn (`VehicleBuilder`).
- 2026-10-30: Game pass ids are 0 until the passes exist; in Studio the store toggles them for testing.
- 2026-10-30: First session: spawn a car (garage opens and glows) → run over 3 people (a crowd of 12 always waits at the spawn plaza, an arrow marks the nearest one) → $250 bonus and confetti → "Next ride" savings bar toward the cheapest vehicle you don't own; every purchase gets a confetti moment. Step saved in the profile (`tutorial`); saves from before it skip it.
