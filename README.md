# Not To Love

A first-person basement horror game built with Godot 4.7 (Forward+).

## Run

Open `project.godot` in Godot and run the project, or launch the main scene:

```sh
godot --path .
```

The start menu is `scenes/ui/menu.tscn`. The main gameplay scene is
`scenes/world/World.tscn`.

## Project layout

```text
assets/
  audio/sfx/                 Music and one-shot sound effects
  models/characters/         Character models, animations, and scenes
  models/props/              Gameplay props and environment models
  source/                    Source art archives that are not imported by Godot
  textures/                  Environment, prop, and UI textures
scenes/
  player/                    Player and interaction scenes
  props/                     Reusable prop scenes
  ui/                        Menus and HUD scenes
  world/                     Main gameplay scene
scripts/
  characters/                Character behavior
  core/                      Global state and graphics settings
  horror/                    Atmosphere, horror direction, and cutscene logic
  player/                    Player, interaction, and appearance
  ui/                        Menu, pause menu, and HUD
  world/                     Doors, lights, fuses, and world interactions
materials/
  generated/                 Generated horror textures and decals
  shaders/                   Gameplay and menu shaders
resources/
  lighting/                  Lighting resources
tools/                       Editor and capture utilities
addons/                      Third-party Godot plugins
build/                       Local exports and archives (ignored by Git)
```

`default_bus_layout.tres`, `export_presets.cfg`, `icon.svg`, and
`project.godot` intentionally remain at the project root.

## Controls

- `WASD` — Move
- `E` — Interact
- `F` — Flashlight
- `Shift` — Sprint
- `Space` — Jump
- `Esc` — Pause
- `F5` — Save

## Development

The project uses typed GDScript, [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit)
for linting and formatting, and a headless smoke-test suite.

```sh
python3 -m pip install --user -r requirements-dev.txt

make format        # format scripts/tests/tools
make lint          # gdlint
make typecheck     # Godot --check-only on every script
make test          # headless project and scene smoke tests
make check         # everything above, plus resource-reference checks
```

Set `GODOT_BIN` if `godot` is not on your `PATH`:

```sh
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot make check
```

### CI

`.github/workflows/ci.yml` runs on every push and pull request:

1. GDScript lint, format, and `res://` reference checks.
2. Godot `--check-only` type checks and headless tests.
3. Release exports for Windows, Linux, and macOS. Builds are uploaded as
   GitHub Actions artifacts (`NotToLove-windows`, `NotToLove-linux`,
   `NotToLove-macos`) for 14 days.

Export templates for the exact Godot version must be installed locally for
`make build`. Release builds are written to `build/releases/` and zipped into
`build/artifacts/`; both directories are ignored by Git.

The project defaults are tuned for responsive play: Jolt Physics at a 60 Hz
simulation tick, 4× anisotropic filtering, render-scale reduction on high-DPI
displays, and TAA only in the High and Very High quality presets.
