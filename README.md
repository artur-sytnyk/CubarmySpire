# Cubarmy Spire

Cubarmy Spire is a solo roguelike auto-battler built in Godot 4 as the practical part of my bachelor thesis at the Czech Technical University in Prague, Faculty of Electrical Engineering. The thesis explores recurring technical obstacles in independent game development; this project applies those ideas in a complete game loop with deliberately controlled scope.

This is the Godot bachelor-project implementation. It is distinct from my earlier Java/JavaFX semester project, which served as an initial exploration of the concept.

## What is implemented

- Persistent army and barracks management
- Real-time automated battles with light RTS controls
- Unit selection, group selection, formation movement, projectiles, and combat effects
- Run-based stages, temporary stackable power-ups, and difficulty scaling
- Persistent gold, materials, equipment, crafting, and unit progression
- JSON-based save data and data-driven unit, equipment, and power-up definitions
- Campaign, garrison, armory, market, battle, settings, and results interfaces

The player prepares an army, starts a run, progresses through increasingly difficult battles, chooses power-ups between victories, and returns with persistent rewards after the run ends.

## Technical overview

- **Engine:** Godot 4.2
- **Language:** GDScript
- **Architecture:** scene- and node-based, with signals for event-driven communication
- **Persistence:** custom JSON save system
- **Data:** JSON definitions for units, equipment, and power-ups

Global services such as `SaveManager`, `RunState`, `SceneManager`, and `SoundManager` are implemented as autoloads. Runtime responsibilities are separated between persistent save data, run-scoped state, battle orchestration, army lifecycle, and individual unit behavior.

## Run locally

1. Install Godot 4.2 or a compatible Godot 4 release.
2. Clone this repository.
3. Import `project.godot` in the Godot Project Manager.
4. Run the project; the main scene is `ui/Root.tscn`.

## Documentation

- [User guide](UserGuide.md)
- [Technical documentation](TechnicalDocumentation.md)

## Project status

Cubarmy Spire is preserved as a bachelor-thesis project and technical case study. It demonstrates the implemented architecture and development decisions rather than representing an actively supported commercial release. Known limitations include a single save slot, limited automated test coverage, and several deliberately unfinished content extensions.

## Author and use

Created by **Artur Sytnyk** as a bachelor project at CTU FEL.

No open-source license is currently granted. The repository is public for portfolio, educational, and evaluation purposes; third-party assets may have their own terms.
