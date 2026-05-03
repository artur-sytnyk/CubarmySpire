# CubarmySpire — Technical Documentation

---

## 1. Introduction

This document describes the **technical architecture, systems, and implementation details** of *CubarmySpire*.
It serves as a reference for developers, reviewers, and academic evaluation.

The project emphasizes:

* Maintainable architecture
* Clear separation of concerns
* Event-driven communication
* Controlled scope suitable for solo development

---

## 2. Technology Stack

| Category     | Technology                |
| ------------ | ------------------------- |
| Engine       | Godot 4                   |
| Language     | GDScript                  |
| Architecture | Node-based, event-driven  |
| Data Storage | JSON (custom save system) |

---

## 3. High-Level Architecture

The project follows a **layered responsibility model**:

```
SaveData (persistent)
    ↓
RunState (run-scoped)
    ↓
ArmyManager (battle orchestration)
    ↓
Army (unit lifecycle)
    ↓
Unit (individual behavior)
```

### Key Principles

* **Autoloads = global systems**
* **Scenes = modular components**
* **Signals = communication layer**
* **Data-driven design via JSON**

---

## 4. Core Systems

---

### 4.1 Save System

#### Overview

Handles persistent player data using JSON files.

#### Responsibilities

* Save/load game state
* Manage inventory, army, resources
* Track progression

#### Key Class

`SaveManager`

#### Data Model (`SaveData`)

```gdscript
var gold: int
var materials_inv: Dictionary
var equipment_inv: Array
var army_active: Array
var army_barracks: Array
var shop_equipment: Array
var max_stage_reached: Dictionary
var selected_difficulty: String
```

#### Characteristics

* Full file rewrite on save
* Single save slot (hardcoded)
* Data sanitization on load

---

### 4.2 RunState (Run-Scoped System)

#### Overview

Stores temporary state during a run.

#### Responsibilities

* Track stage progression
* Store active powerups
* Accumulate rewards
* Hold snapshot of army and equipment

#### Key Data

```gdscript
var stage: int
var difficulty: String
var active_powerups: Dictionary
var gold_collected: int
var loot_collected: Dictionary
var unit_defs: Array
var active_equipment: Array
```

#### Lifecycle

* Initialized from SaveData
* Persists across scene reloads
* Finalized on run end

---

### 4.3 Scene Management

#### System

`SceneManager` (autoload)

#### Responsibilities

* Scene transitions
* Navigation history
* UI state consistency

#### Features

* Slide transitions
* Scene stack (back navigation)
* Scene-specific UI control (NavBar visibility)

---

### 4.4 Army System

#### Overview

Core gameplay system managing units.

---

#### ArmyManager

**Role:** Orchestrates battle

Responsibilities:

* Initializes player and enemy armies
* Applies powerups and equipment effects
* Determines win/loss condition

Signals:

```gdscript
signal battle_won
signal battle_lost
```

---

#### Army

**Role:** Manages unit lifecycle

Responsibilities:

* Spawn units
* Maintain active and reserve units
* Handle deaths and loot

Key Data:

```gdscript
var alive_units: Array
var reserve_queue: Array
var active_limit: int
var max_army_size: int
var pending_loot: Dictionary
var pending_gold: int
```

---

#### Unit Lifecycle

1. Spawn
2. Apply stats
3. Enter battle
4. On death:

   * Remove from active list
   * Drop loot (if enemy)
   * Trigger respawn from reserve

---

### 4.5 Battle System

#### Scene

`Battle.tscn`

#### Responsibilities

* Initialize combat
* Handle input (RTS-style)
* Manage UI overlays
* Control battle flow

---

#### Flow

**Win:**

```
Battle → Collect loot → Powerup selection → Next stage
```

**Loss:**

```
Battle → Finalize run → Show results → Return to Campaign
```

---

#### Input System

| Input        | Action           |
| ------------ | ---------------- |
| Left click   | Select unit      |
| Drag         | Multi-select     |
| Double click | Select same type |
| Right click  | Move command     |

---

### 4.6 Stats Calculation

#### System

`BattleStatsCalculator`

#### Responsibilities

* Compute final unit stats
* Apply scaling, equipment, powerups

---

#### Player Calculation

```
Base Stats
→ Level Scaling
→ Equipment Modifiers
→ Powerup Multipliers
→ Behavior Flags
```

---

#### Enemy Scaling

```
Base Stats
→ Level Scaling
→ Stage Scaling (exponential)
```

---

### 4.7 Powerup System

#### Characteristics

* Run-based (temporary)
* Stackable
* Stored as:

```gdscript
active_powerups[id] = accumulated_value
```

#### Types

* Stat modifiers
* Army size changes
* Special effects (events)

---

### 4.8 Equipment System

#### Structure

```gdscript
{
  "id": String,
  "level": int,
  "grade": int,
  "equipped_slot": String
}
```

#### Categories

* Stat multipliers
* One-time effects
* (Partially implemented) loot modifiers

#### Application

* Snapshot taken at run start
* Applied in stat calculation or ArmyManager

---

### 4.9 Economy System

#### Resources

* Gold
* Materials (graded)

#### Sources

* Enemy drops
* Run completion

#### Usage

* Market purchases
* Crafting (Alchemy)
* Equipment management

---

## 5. Data Flow

### Run Start

```
SaveData → RunState.init()
        → ArmyManager.setup()
```

### During Battle

```
Unit death → Army → pending_loot
           → BattleScene → RunState accumulation
```

### Run End

```
RunState.finalize()
→ SaveData update
→ JSON write
```

---

## 6. Event-Driven Communication

The system heavily relies on **signals**:

### Examples

| Signal          | Source      | Target      |
| --------------- | ----------- | ----------- |
| `unit.died`     | Unit        | Army        |
| `all_dead`      | Army        | ArmyManager |
| `battle_won`    | ArmyManager | BattleScene |
| `run_finalized` | RunState    | UI          |

### Benefits

* Loose coupling
* High modularity
* Easier debugging and extension

---

## 7. Project Structure

```
assets/
  images/
  sounds/
  materials/

scenes/
  menus/
  battle/
  ui/

scripts/
  managers/
  systems/
  ui/

data/
  json definitions
```

---

## 8. Design Decisions

### 8.1 Node-Based Architecture

* Native to Godot
* Encourages modular scenes
* Easier debugging and visualization

---

### 8.2 Autoload Usage

Used for:

* Global state (RunState)
* Systems (SaveManager, SceneManager)

---

### 8.3 Separation of Data Layers

| Layer           | Purpose    |
| --------------- | ---------- |
| SaveData        | Persistent |
| RunState        | Temporary  |
| Runtime Systems | Execution  |

---

### 8.4 Scope Control

Implemented via:

* Limited feature set
* Focus on core loop
* Avoidance of premature optimization

---

## 9. Known Limitations

* Single save slot
* No checkpoint system within runs
* Loot multiplier system incomplete
* Limited UI feedback in some areas
* No multiplayer or networking

---

## 10. Extensibility

The architecture supports future expansion:

### Possible Extensions

* Additional unit types
* More powerups and equipment
* Multiple save slots
* Expanded UI systems
* Balance tuning via JSON

---

## 11. Conclusion

CubarmySpire demonstrates a **structured, maintainable approach** to indie game development using Godot.

The implementation highlights:

* Effective use of event-driven systems
* Clear separation of responsibilities
* Scalable design within constrained scope

It serves both as:

* A playable prototype
* A technical case study for indie development practices
