<div align="center">
  
  insert badges here
  
<img src="https://github.com/user-attachments/assets/2aefaadd-2863-4fae-86c0-38e1d13ced27" alt="jTDF logo" width="40%" align="center">

# Baj's Tower Defense Framework

jTDF is a Tower Defense framework that frees you from optimization hell and lets you create what you want to create

- Excellent performance
By utilizing parallel luau, jTDF is able to reach astonishing performance

environment: 8 threads, 500 enemies, 100 towers

result: jTDF takes up around 10ms of frametime, which is approximately 60% of budget. Game runs at smooth 60 FPS.

note: towers that don't have enemies near their radius are approximately 5x as efficient. This test had all towers active.

</div>

Devforum page is unavailable

If you use this framework in your games, consider giving the repo a star and donating to my broke ass

## What this framework handles:
- Data structure: towers, tower radii, enemies and paths are separate defined objects
- Towers: placement, upgrades, easy logic set up
- Radii: parallelized enemy detection, dynamic sizes,
- Enemies: health, speed, walking along path, death
- All necessary signals are defined and documented

## What this framework does not handle:
**Game logic itself** (jTDF instead provides a clear toolset to create the game YOU want),

**Rendering** (see example rendering in the demo game, jTDF is server-sided except path tools),
UI,
Lobbies,
Player data

If you want a template of those, you can find them in the demo place (will be available soon™️)

## Features:
- Lightweight: performance-heavy computations are thoroughly optimized and run in parallel
- Easy to set up new towers
- Easy to set up new enemies
- Easy to create* enemy paths
- Extremely customizable, but stays user-friendly
- Full documentation with clear examples

\* with a plugin

## Installation
You can:

1. Get the module on Creator Hub (soon™️) [recommended]

2. Download .rbxm from releases and put it in ReplicatedStorage (soon™️)

## Contributing
Just make a pr and we'll sort it out ig

## Configuration

You can find additional configs in the Config module

## License
MIT
