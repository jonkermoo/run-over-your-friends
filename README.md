# Roblox game template

```
rokit install            # installs pinned tools from rokit.toml
./scripts/check.sh       # or scripts\check.ps1 on Windows: the 4 checks
rojo serve               # then connect from Roblox Studio
```

- Tunable numbers: `src/shared/Config/`
- Client/server messages: `src/shared/Net.luau` only
- Place IDs and which env var holds this game's Open Cloud key: `roblox.json` (key values never go in the repo)
- Large binaries (`.fbx`, `.blend`, textures, `.rbxm`) use Git LFS
- Log every asset in `ASSETS_LICENSES.md`
