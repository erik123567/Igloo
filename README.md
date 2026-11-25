# Igloo

A 2D top-down arctic survival game made in Godot 4. This is the MVP: **survive your first three nights**.

You wake up alone in the snow. Keep your body temperature, hunger, energy and health up. Gather sticks, flint and stone, build a fire, build an igloo before dark, find food, and keep the wolves away until morning.

## How to play it (no coding needed)

1. **Get Godot.** Go to https://godotengine.org/download, download **Godot 4** (version 4.3 or newer, the normal "Godot Engine" one, not ".NET"). It's a zip with a single program inside: unzip it and double-click the Godot program. No install needed.
2. **Get the game files.** On this GitHub page, click the green **Code** button, then **Download ZIP**. Unzip it somewhere easy, like your Documents folder.
3. **Open the game in Godot.** In Godot's Project Manager, click **Import**, browse to the unzipped folder, pick the file `project.godot`, then click **Import** (or **Import & Edit**).
4. **Play.** Press **F5**, or click the ▶ play button in the top-right corner of Godot. The game opens in its own window. Close that window to stop.

The first time you open it, Godot may take a few seconds to set things up. That's normal.

If you see red error text at the bottom of Godot, copy it and send it to Claude.

## Controls

| Key | What it does |
| --- | --- |
| WASD / arrow keys | Move |
| Shift | Sprint (uses energy) |
| E | Gather or use the thing you're standing next to (hold to repeat) |
| Tab | Crafting menu (then 1 = campfire, 2 = igloo) |
| Q | Eat (cooked meat first, then berries, then raw meat) |
| C | Cook raw meat while standing at a fire |
| Space | Attack: hunt hares, fight off wolves |
| Z | Sleep (only inside a finished igloo, in the evening or at night) |
| H | Show or hide the help panel |
| Esc | Pause |
| R | Restart after you die |

## How to survive

1. Pick up **sticks** (under trees), **stones** (small grey pebbles) and **flint** (chip it from big grey rocks).
2. Press **Tab**, then **1** to build a **campfire** (3 sticks + 1 flint, and you need a stone to strike it). Keep it fed with sticks (E).
3. Press **Tab**, then **2** to mark an **igloo**. Cut **snow blocks** from the bluish snow drifts, then stand at the igloo and hold **E** to place 10 blocks.
4. Pick **berries** from bushes. Chase **hares** (sprint!) and hit them with Space for meat. Cook it at the fire with **C**. Raw meat makes you sick.
5. At night it gets much colder and **wolves** come out. Wolves won't come into firelight or a finished igloo.
6. Best plan: a fire inside your igloo, then press **Z** to sleep until morning.
7. Survive until the morning of day 4 to win.

## Changing the balance

All the numbers that control difficulty are at the top of the script files in `scripts/`, under "Tuning". For example, `TEMP_DRAIN_NIGHT` in `scripts/player.gd` controls how fast you get cold at night, and `DAY_LENGTH` in `scripts/main.gd` controls how long a day lasts.

## What's in the project

- `main.tscn`: the game scene Godot runs.
- `scripts/main.gd`: the world, day and night clock, crafting, sleep, spawning.
- `scripts/player.gd`: movement and the four stats.
- `scripts/hud.gd`: everything on screen.
- `scripts/campfire.gd`, `igloo.gd`, `resource_node.gd`, `wolf.gd`, `hare.gd`, `pine_tree.gd`, `ground.gd`: the things in the world.

All art is simple placeholder shapes drawn by the code, so there are no image files yet.
