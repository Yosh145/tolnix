

<h1 align="center">Tolnix Cabin Announcement</h1>

<p align="center">
  <b>Cabin Announcements for the Toliss A32X Family in X-Plane 12</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-1.0.1-blue?style=flat-square" alt="Version">
  <img src="https://img.shields.io/badge/simulator-X--Plane_12-0a84ff?style=flat-square" alt="X-Plane 12">

  
</p>

<p align="center">
  <img src="https://img.shields.io/badge/lua-%232C2D72.svg?style=for-the-badge&logo=lua&logoColor=white" alt="FlyWithLua">
</p>

The **Toliss A319 / A320 / A321** family for X-Plane 12 ships without cabin announcements. Meanwhile, the Fenix community has produced high-quality, freely available announcement soundpacks in OGG format.

**TolnixCabin** is a single-file FlyWithLua script that plays Fenix-format soundpacks directly inside X-Plane 12 through its native FMOD audio engine, with a clean in-sim GUI for manual control.

---

## Features

- Fenix Soundpack Compatibility: drop in any Fenix-format announcement folder
- Time-of-Day Awareness: automatically selects `[Morning]`, `[Afternoon]`, `[Evening]`, or `[Night]` variants based on sim local time
- Crew Voice Consistency: numbered variations (e.g. `[1]`, `[2]`, `[3]`) are rolled once per flight
- Aircraft Type Filtering: respects `[A319]`, `[A320]`, `[A321]` tags to play type-specific announcements
- Category-Based GUI: 6 pages (Boarding, Taxi, Takeoff, Cruise, Landing, After Landing) navigated with arrow buttons
- Multi-Airline Support: organise soundpacks by ICAO code and switch between them via dropdown
- Boarding Music Loop: automatically offers to loop short boarding music tracks (< 5 min)
- Native Audio Integration: plays through X-Plane's Interior audio bus via FMOD, respecting your volume settings
- Visual Button States: green (playing), dark red (available), grey (missing file) at a glance

---

## Requirements

| Requirement | Version |
|---|---|
| X-Plane | 12.04+ (SDK 4.0 for FMOD access) |
| FlyWithLua | NG+ (latest recommended) |
| Aircraft | Any Toliss A3x0 (or any aircraft) |
| Soundpacks | Fenix-format `.ogg` files |

---

## Installation

### 1. Install the Script

Copy `TolnixCabin.lua` to your FlyWithLua scripts folder:

```
X-Plane 12/
└── Resources/
    └── plugins/
        └── FlyWithLua/
            └── Scripts/
                └── TolnixCabin.lua
```

### 2. Add Announcement Soundpacks

Create an `Announcements` folder alongside the script, with ICAO-coded subfolders containing your `.ogg` files:

```
X-Plane 12/
└── Resources/
    └── plugins/
        └── FlyWithLua/
            └── Scripts/
                ├── TolnixCabin.lua
                └── Announcements/
                    ├── BAW/                ← British Airways
                    │   ├── BoardingWelcome.ogg
                    │   ├── BoardingWelcome[Morning][1].ogg
                    │   ├── BoardingWelcome[Morning][2].ogg
                    │   ├── BoardingMusic.ogg
                    │   ├── ArmDoors[1].ogg
                    │   ├── ArmDoors[2].ogg
                    │   ├── SafetyBriefing[A320].ogg
                    │   └── ...
                    ├── DLH/                ← Lufthansa
                    │   └── ...
                    └── UAE/                ← Emirates
                        └── ...
```

### 3. Launch & Open

1. Start X-Plane 12
2. FlyWithLua loads the script automatically
3. Open the window from the menu:
   **Plugins → FlyWithLua → FlyWithLua Macros → TolnixCabin: Toggle Window**

> **Tip:** Bind the command `FlyWithLua/TolnixCabin/toggle` to a keyboard shortcut or joystick button for quick access.

---

## Soundpack Format

TolnixCabin uses the same file naming convention as Fenix. All files must be **OGG Vorbis** (`.ogg`).

### Base Filenames

Each announcement has a fixed base name. Only these are recognised:

| Category | Announcements |
|---|---|
| **Boarding** | `BoardingWelcome` · `BoardingMusic` · `BoardingComplete` |
| **Taxi** | `ArmDoors` · `PreSafetyBriefing` · `SafetyBriefing` |
| **Takeoff** | `CabinDimTakeoff` · `CrewSeatsTakeoff` · `CallCabinSecureTakeoff` |
| **Cruise** | `AfterTakeoff` · `FastenSeatbelt` |
| **Landing** | `DescentSeatbelts` · `CrewSeatsLanding` · `CallCabinSecureLanding` |
| **After Landing** | `AfterLanding` · `DisarmDoors` · `DisembarkStarted` |

### Tag System

Tags are appended in square brackets between the base name and `.ogg`:

```
BaseName[Tag1][Tag2][Tag3].ogg
```

#### Time-of-Day Tags

Matched automatically against sim local time:

| Tag | Time Range |
|---|---|
| `[Night]` | 00:00 – 05:59 |
| `[Morning]` | 06:00 – 11:59 |
| `[Afternoon]` | 12:00 – 17:59 |
| `[Evening]` | 18:00 – 23:59 |

If no time-tagged file matches the current period, files without a time tag are used as fallbacks.

#### Numbered Tags (Crew Variations)

```
ArmDoors[1].ogg     ← Cabin Crew A
ArmDoors[2].ogg     ← Cabin Crew B
ArmDoors[3].ogg     ← Cabin Crew C
```

A random number is chosen **once per flight** and reused for every announcement. This means you hear a consistent crew voice throughout. If an announcement doesn't have the selected number, a random available one is picked for that announcement only.

> **Best practice:** Use the same number of variations across all announcements that use numbered tags. Announcements that don't use numbered tags at all are fine  they'll just play as-is.

#### Aircraft Tags

Only play when the loaded aircraft matches:

```
SafetyBriefing[A319].ogg        ← only on A319
SafetyBriefing[A320].ogg        ← only on A320
SafetyBriefing.ogg              ← plays on any aircraft
```

Supported: `A319`, `A320`, `A321`, `A330`, `A340`, `A350`

#### Special Tags

Any other alphabetic tag (e.g. `[Refueling]`) is treated as a variant identifier and included in the selection pool.

#### Combined Examples

```
BoardingWelcome[Refueling][1].ogg           ← Refueling variant, crew voice 1
BoardingWelcome[Morning][2].ogg             ← Morning, crew voice 2
SafetyBriefing[A319].ogg                    ← A319-specific, no crew variation
ArmDoors[Evening][3].ogg                    ← Evening, crew voice 3
CabinDimTakeoff.ogg                         ← Universal fallback, no tags
```

Invalid tags (non-alphanumeric, unknown format) are silently ignored.

---

## GUI Overview

```
┌──────────────────────────────────────────────────────┐
│              Tolnix Cabin Announcements               │
├── ◀ ──────────── { Category } ──────────── ▶ ─ [ICAO ▼] ──┤
│  You are in {Category} Mode                           │
│  {TimeOfDay} | {HH:MM}            Loaded Airline: {ICAO} │
├──────────────────────────────────────────────────────┤
│                                                      │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐      │
│   │ Button 1 │    │ Button 2 │    │ Button 3 │      │
│   └──────────┘    └──────────┘    └──────────┘      │
│                                                      │
│        ┌──────────┐    ┌──────────┐                  │
│        │ Button 4 │    │ Button 5 │                  │
│        └──────────┘    └──────────┘                  │
│                                                      │
│                                       [New Flight]   │
└──────────────────────────────────────────────────────┘
```

### Controls

| Control | Action |
|---|---|
| `◀` / `▶` arrows | Cycle through the 6 announcement categories |
| ICAO dropdown | Switch airline soundpack |
| Announcement button | Play the announcement (click again to stop) |
| **New Flight** | Re-roll the crew voice number for a fresh flight |

### Button Colours

| Colour | Meaning |
|---|---|
| 🟢 **Green** | Currently playing |
| 🔴 **Dark Red** | File available, not playing |
| ⚫ **Grey** | No matching sound file found |

---

## How It Works

### Audio Engine

TolnixCabin uses **LuaJIT FFI** to talk directly to X-Plane 12's built-in FMOD audio system:

```
XPLMGetFMODStudio()
    → FMOD_Studio_System_GetCoreSystem()
        → FMOD_System_CreateSound()      ← loads .ogg file
        → FMOD_System_PlaySound()        ← plays on Interior bus
```

Because announcements route through X-Plane's **Interior** channel group, they automatically respond to the sim's master volume and interior volume sliders. No external audio libraries needed.

### Tag Selection Priority

When you click a button, the selection engine works through this order:

1. **Aircraft filter**  eliminate files tagged for a different aircraft type
2. **Time-of-day match**  prefer files matching current sim time; fall back to untagged
3. **Crew number**  if numbered variants exist, use the per-flight crew number; if unavailable, pick a random one

### File Scanning

On startup (and when switching airlines), the script scans the ICAO subfolder using LuaFileSystem (`lfs`, bundled with FlyWithLua) with an `io.popen` fallback. Only `.ogg` files with recognised base names are indexed.

---

## Troubleshooting

### Sound engine init FAILED

- Ensure you're running **X-Plane 12.04 or later** (SDK 4.0 required)
- Update **FlyWithLua NG+** to the latest version
- Windows: verify `fmod.dll` and `fmodstudio.dll` exist in the X-Plane root directory
- Linux: verify `libfmod.so.13` and `libfmodstudio.so.13` exist in the X-Plane root directory
- macOS: verify `libfmod.dylib` and `libfmodstudio.dylib` exist

### No soundpacks found

- Verify the folder structure: `Scripts/Announcements/{ICAO}/*.ogg`
- ICAO folder names are case-sensitive
- Files must have the `.ogg` extension
- Base filenames must exactly match the expected names (e.g. `BoardingWelcome`, not `Boarding_Welcome`)

### Button is grey (file not found)

- The announcement exists in the category but no `.ogg` file matched after tag filtering
- Check if you have aircraft-specific tags that don't match your current plane
- Check if all your files are time-tagged with no fallback (e.g. only `[Morning]` files when it's evening)

### Audio plays but no sound heard

- Check X-Plane's interior volume slider isn't muted
- Verify the `.ogg` file plays correctly in a standalone audio player

---

## Roadmap

- [ ] Automatic trigger mode (play announcements based on flight phase datarefs)
- [ ] Volume control slider in the GUI
- [ ] Destination / origin airport-aware announcements
- [ ] Integration with Toliss-specific datarefs (door state, seatbelt signs)
- [ ] Configurable category-to-announcement mapping
- [ ] Support for `.wav` and `.mp3` formats

---

## Acknowledgements

- **[Fenix Simulations](https://fenixsim.com/)**  for the cabin announcement format specification and the community soundpacks
- **[FlyWithLua](https://github.com/X-Friese/FlyWithLua)**  for making Lua scripting possible in X-Plane
- **[Toliss](https://www.toliss.com/)**  for the excellent A3x0 family aircraft

- **AI-Assisted Development**: Initial code structure, LUA help, and documentation were generated with the help of AI tools. Other help gathered from FlyWithLua Forum and X-Plane SDK documentation.

---

## License

This project is licensed under the [MIT License](LICENSE).

TolnixCabin is an independent community tool. It is not affiliated with, endorsed by, or associated with Fenix Simulations, Toliss, or Laminar Research.
