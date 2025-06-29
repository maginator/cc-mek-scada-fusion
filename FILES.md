# SCADA System Files

## Installation System

| File | Description | Usage |
|------|-------------|-------|
| `installer.lua` | Main installer with streamlined workflow | `installer` (starts Quick Setup) |
| `installer_simple.lua` | Simple installer with automatic configuration | Auto-downloaded by main installer |

## Core SCADA Components

| File | Description | Usage |
|------|-------------|-------|
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

## Streamlined Installation Workflow

### ⚡ Quick Setup (Recommended)
1. **Download installer:** `pastebin get <id> installer`
2. **Run installer:** `installer`
3. **Choose "Quick Setup":** Automatically detects hardware and installs appropriate components
4. **Done!** Computer is configured and ready to use

### Alternative Workflows
- **Graphical:** `installer` → Choose "Graphical Installer" 
- **Manual:** `installer server|control|monitor` for specific roles
- **Advanced:** `installer` → Choose "Advanced Setup" for traditional component selection

## Computer Roles (Auto-Detected)

| Hardware Configuration | Auto-Assigned Role | Components Installed |
|------------------------|-------------------|---------------------|
| Wireless modem only | SCADA Server | `scada_server.lua` |
| Monitor + wireless modem | Control Station | `scada_gui.lua`, `scada_hmi.lua` |
| Cable modem + wireless modem | Monitor Station | `universal_rtu.lua` |
| Advanced computer | Enhanced features | GUI components included |

## Manual Installation (Advanced Users)
- **Server:** `installer server`
- **Control:** `installer control` 
- **Monitor:** `installer monitor`
- **Traditional components:** `installer hmi|rtu|reactor|energy|fuel|laser|historian`

All components are optimized for ComputerCraft screen dimensions (51x19) and include proper SCADA architecture with wireless communication.