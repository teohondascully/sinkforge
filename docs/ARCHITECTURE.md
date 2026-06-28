# Sinkforge — Technical Architecture

> The technical source of truth. Every system, its responsibility, its public API, and its relationships. Update this whenever a new system is built or refactored.

## Core Principle: Data-Driven Everything

Machines, materials, recipes, and depth layers are **Godot custom Resources (data files)**, consumed by a generic engine. Adding new content = creating/editing a data file, NOT writing new classes. This is the load-bearing architectural decision.

## Core Principle: Abstract Flow Is Source of Truth

Production math runs entirely through the abstract rate-based flow layer. Discrete falling-item sprites are a COSMETIC layer driven by the same numbers. They never feed back into production calculations. If all item sprites were removed, production counts would be identical.

---

## Systems

<!-- Add each system as it's built. Template below. -->

### [System Name]
- **Location:** `src/.../`
- **Responsibility:** What it does, in one sentence.
- **Public API:** Key methods/signals other systems use.
- **Depends on:** Other systems it relies on.
- **Used by:** Systems that rely on it.

---

## Data Schema Reference

<!-- Link to or summarize the Resource schemas once defined: Machine, Material, Recipe, Layer. -->
_Schema not yet formalized. See planned "content data schema + architecture spec."_

## Scene Tree Overview

<!-- High-level node hierarchy once scenes exist. -->
_No scenes built yet._
