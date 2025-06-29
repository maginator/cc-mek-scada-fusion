# SCADA System Files

## Core System Components

| File | Description | Usage |
|------|-------------|-------|
| `installer.lua` | Main installer for all components | `installer <component>` |
| `scada_server.lua` | Central SCADA server | Auto-starts after installation |
| `scada_hmi.lua` | Human Machine Interface client | Auto-starts after installation |
| `universal_rtu.lua` | Auto-detecting RTU for any Mekanism system | Auto-starts after installation |
| `scada_historian.lua` | Data historian and trending | Auto-starts after installation |

## Dedicated RTU Components

| File | Description | Usage |
|------|-------------|-------|
| `fusion_reactor_mon.lua` | Dedicated reactor RTU/PLC | Auto-starts after installation |
| `energy_storage.lua` | Dedicated energy storage RTU/PLC | Auto-starts after installation |
| `fuel_control.lua` | Dedicated fuel system RTU/PLC | Auto-starts after installation |
| `laser_control.lua` | Dedicated laser control RTU/PLC | Auto-starts after installation |

## GUI System

| File | Description | Usage |
|------|-------------|-------|
| `scada_gui.lua` | GUI library for advanced computers | Loaded by GUI components |
| `scada_installer_gui_fixed.lua` | Compact graphical installer | Loaded by `installer_gui_auto.lua` |
| `installer_gui_auto.lua` | GUI installer entry point | `installer gui` then `installer_gui` |
| `configurator_compact.lua` | Compact configuration wizard | `installer configure` then `configurator` |

## Documentation

| File | Description |
|------|-------------|
| `README.md` | Complete system documentation and setup guide |
| `FILES.md` | This file - summary of all components |

## Installation Workflow

1. **Download installer:** `pastebin get <id> installer`
2. **Install GUI components:** `installer gui` (optional, for graphical interface)
3. **Install configuration:** `installer configure`
4. **Run configurator:** `configurator`
5. **Install SCADA components:** `installer server`, `installer hmi`, `installer rtu`

## Recommended Minimal Setup

- **Server Computer:** `installer server`
- **Control Room Computer:** `installer hmi` 
- **RTU Computer(s):** `installer rtu` (auto-detecting) or specific RTU types
- **Optional:** `installer historian` for data logging

All components are optimized for ComputerCraft screen dimensions (51x19) and include proper SCADA architecture with wireless communication.