# CubarmySpire

**CubarmySpire** is a roguelike auto-battler developed in **Godot 4** as part of a bachelor thesis focused on technical challenges in independent game development.
The project emphasizes maintainable architecture, scoped feature design, and efficient development practices within a solo development context.

---

## Overview

CubarmySpire combines:

* **Army management**
* **Automated real-time combat**
* **Run-based progression (roguelike loop)**

The player builds and upgrades an army, progresses through increasingly difficult stages, and improves long-term strength through persistent rewards.

---

## Key Features

* **Auto-Battler Combat**

  * Units fight automatically in real time
  * Player provides light RTS-style input (selection & movement)

* **Roguelike Progression**

  * Each run is temporary
  * Powerups are gained during runs
  * Rewards persist between runs

* **Army Management**

  * Active army and reserve (barracks)
  * Unit leveling and composition strategy

* **Equipment System**

  * Weapons, armor, artifacts
  * Stat modifiers and special effects

* **Economy & Crafting**

  * Gold and material resources
  * Shop and alchemy systems

* **Difficulty Scaling**

  * Multiple difficulty levels
  * Enemy scaling based on stage progression

---

## Project Context (Bachelor Thesis)

This project was developed as a **practical implementation** accompanying a thesis on:

> *Technical analysis of the most common obstacles in independent game development*

The implementation focuses on:

* Maintainable **node-based architecture (Godot)**
* **Event-driven design** using signals
* Clear separation between:

  * Persistent data (Save)
  * Run-based state (RunState)
  * Gameplay systems (Army, Battle, Managers)

---

## Tech Stack

* **Engine:** Godot 4
* **Language:** GDScript
* **Architecture Style:** Node-based + event-driven
* **Data Storage:** JSON (custom save system)

---

## Getting Started

### Requirements

* Godot Engine 4.x

### Running the Project

1. Clone the repository
2. Open the project in Godot
3. Run the main scene

---

## Documentation

* **User Guide:** `UserGuide.md`
  → Explains gameplay, controls, and features

* **Technical Documentation:** `TechnicalDocumentation.md`
  → Describes architecture, systems, and implementation details

---

## Project Structure (Simplified)

```
assets/        # Images, sounds, materials
scenes/        # Game scenes (UI, battle, menus)
scripts/       # Core logic and systems
data/          # Game definitions and balance data
```

---

## Current Limitations

* Single save slot (hardcoded)
* Minimal UI/stat tracking in some areas
* Focus on core gameplay loop over content volume

---

## Purpose & Scope

This project is not intended as a commercial product but as:

* A **technical prototype**
* A **research-backed implementation**
* A demonstration of **indie-friendly architecture and scope management**

---

## Author

**Artur Sytnyk**
Bachelor Thesis — Czech Technical University in Prague
Faculty of Electrical Engineering
Department of Computer Science

---

## License

This project is provided for educational and demonstration purposes.
