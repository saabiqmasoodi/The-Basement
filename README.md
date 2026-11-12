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
