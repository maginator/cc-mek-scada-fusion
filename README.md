# CC-Mek-SCADA-Fusion

A comprehensive SCADA (Supervisory Control and Data Acquisition) system for Mekanism Fusion Reactors in ComputerCraft.

## Overview

This system provides industrial-grade monitoring and control for Mekanism fusion reactor installations using ComputerCraft computers. The architecture follows standard SCADA principles with distributed RTU/PLC units, centralized data acquisition, and modern HMI interfaces.

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   HMI Client    │◄──►│  SCADA Server    │◄──►│   Data Logger   │
│  (Operator UI)  │    │  (Central Hub)   │    │  (Historian)    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                    ┌───────────┼───────────┐
                    │           │           │
            ┌───────▼───┐ ┌─────▼─────┐ ┌───▼──────┐
            │Reactor RTU│ │Energy RTU │ │Laser RTU │
            │    PLC    │ │    PLC    │ │   PLC    │
            └───────────┘ └───────────┘ └──────────┘
                    │           │           │
            ┌───────▼───┐ ┌─────▼─────┐ ┌───▼──────┐
            │  Fusion   │ │  Energy   │ │  Laser   │
            │ Reactor   │ │ Storage   │ │ Systems  │
            └───────────┘ └───────────┘ └──────────┘
```

## Quick Start

### Installation

#### **🖥️ Modern Graphical Installer (Recommended)**

1. **Download the universal installer:**
   ```lua
   pastebin get <pastebin-id> installer
   ```

2. **Launch interactive installer:**
   ```lua
   installer
   ```
   
   The installer automatically detects your computer capabilities:
   - **Advanced Computer + Monitor** → Modern GUI with mouse/touch controls (optimized for 51x19 screens)
   - **Standard Computer** → Enhanced command-line interface
   
3. **Follow the graphical wizard:**
   - 🔍 **Hardware Scan** - Automatic detection of peripherals and Mekanism devices
   - ⚙️ **Configuration** - Smart setup with auto-configuration options
   - 📦 **Component Selection** - Visual component browser with categories
   - 📊 **Installation Progress** - Real-time progress and status updates

#### **⌨️ Command Line Installation (Advanced Users)**

For direct component installation:
```lua
installer cli <component>    # Force CLI mode
installer server            # Install specific component
installer configure         # Configuration wizard only
```

### Available Components

| Component | Description | Purpose |
|-----------|-------------|---------|
| `gui` | **GUI Components** | **Modern graphical interface library** |
| `configure` | Configuration Wizard | Interactive setup for custom configuration |
| `server` | SCADA Server | Central data acquisition and control |
| `hmi` | HMI Client | Operator interface with touchscreen |
| `rtu` | **Universal RTU/PLC** | **Auto-detecting RTU for any Mekanism system** |
| `reactor` | Reactor RTU/PLC | Dedicated fusion reactor control |
| `energy` | Energy RTU/PLC | Dedicated energy storage monitoring |
| `fuel` | Fuel RTU/PLC | Dedicated fuel system management |
| `laser` | Laser RTU/PLC | Dedicated fusion laser control |
| `historian` | Data Historian | Historical data and trending |
| `all` | Complete System | All components (dev/testing) |

### Quick Setup Examples

#### **🖥️ Graphical Setup (Recommended)**

1. **Any Computer with Advanced Computer + Monitor:**
   ```lua
   installer              # Launches GUI installer
   ```
   - Follow the visual wizard
   - Hardware auto-detection
   - Point-and-click component selection
   - Integrated configuration

#### **⚡ Quick 3-Computer Setup:**

1. **Central Server Computer:**
   ```lua
   installer server       # Or use GUI installer
   ```

2. **Control Room Computer (with Monitor):**
   ```lua
   installer hmi          # Enhanced GUI with touch controls
   ```

3. **Any RTU Computer (connected to Mekanism devices):**
   ```lua
   installer rtu          # Auto-detects: Reactor, Energy, Fuel, or Laser
   ```

The Universal RTU automatically detects what Mekanism systems are connected and configures itself accordingly!

### Traditional Setup (Dedicated RTUs)

For dedicated RTU computers, use specific components:

1. **Reactor Computer:** `installer reactor`
2. **Energy Computer:** `installer energy`  
3. **Fuel Computer:** `installer fuel`
4. **Laser Computer:** `installer laser`

## Configuration System

### Interactive Configuration Wizard

The configuration wizard automatically detects your hardware and helps set up custom configurations:

```lua
installer configure
configurator
```

**Features:**
- **Hardware Auto-Detection:** Automatically finds monitors, modems, and Mekanism devices
- **Component Type Detection:** Determines if computer should be Server, HMI, or RTU
- **Custom Channel Assignment:** Configure communication channels for your network
- **RTU Auto-Configuration:** Sets up RTU type and ID based on connected devices
- **Peripheral Side Detection:** Auto-detects which sides have modems and monitors

**Generated Configuration:**
- Creates `scada_config.lua` with your custom settings
- All SCADA components automatically load this configuration
- Override default settings without modifying code

### Universal RTU/PLC

The Universal RTU automatically adapts to whatever Mekanism systems are connected:

**Auto-Detection Features:**
- **Device Type Recognition:** Automatically classifies connected Mekanism devices
- **RTU Type Assignment:** Configures as Reactor, Energy, Fuel, or Laser RTU
- **Peripheral Auto-Discovery:** Finds cable and wireless modems on any side
- **Dynamic Configuration:** Adapts behavior based on detected equipment

**Supported Systems:**
- **Reactor:** Fusion Reactor Controllers, Reactor Frames
- **Energy:** Induction Matrix, Energy Cubes (all tiers)
- **Fuel:** Dynamic Tanks, Chemical Tanks, Electrolytic Separators  
- **Laser:** Fusion Lasers, Laser Amplifiers

**Usage:**
```lua
installer rtu    # Install universal RTU
universal_rtu    # Runs auto-detection and configuration
```

## Component Details

### SCADA Server
- **File:** `scada_server.lua`
- **Purpose:** Central data acquisition and control coordination
- **Requirements:**
  - Wireless Modem (back side)
  - Computer with adequate storage
- **Features:**
  - Real-time data collection from all RTUs
  - Command execution and coordination
  - Built-in alarm management
  - HMI client coordination

### HMI Client
- **File:** `scada_hmi.lua`
- **Purpose:** Human Machine Interface for operators
- **Requirements:**
  - Monitor (top side)
  - Wireless Modem (back side)
  - Touch-capable monitor recommended
- **Features:**
  - Real-time system overview
  - Touch controls for reactor operations
  - Emergency SCRAM functionality
  - Multi-screen navigation
  - Alarm display and management

### Reactor RTU/PLC
- **File:** `fusion_reactor_mon.lua` → `reactor_rtu.lua`
- **Purpose:** Direct fusion reactor control
- **Requirements:**
  - Cable Modem (back side) connected to reactor
  - Wireless Modem (top side) for SCADA communication
  - Direct connection to Mekanism Fusion Reactor
- **Features:**
  - Real-time reactor monitoring
  - Temperature and pressure control
  - Emergency shutdown capabilities
  - Ignition control

### Energy RTU/PLC
- **File:** `energy_storage.lua` → `energy_rtu.lua`
- **Purpose:** Energy storage system monitoring
- **Requirements:**
  - Cable Modem (back side) connected to energy storage
  - Wireless Modem (top side) for SCADA communication
  - Connection to Induction Matrix or Energy Cubes
- **Features:**
  - Energy level monitoring
  - Charge/discharge rate tracking
  - Multiple storage unit support
  - Capacity management

### Fuel RTU/PLC
- **File:** `fuel_control.lua` → `fuel_rtu.lua`
- **Purpose:** Fuel system monitoring and control
- **Requirements:**
  - Cable Modem (back side) connected to fuel systems
  - Wireless Modem (top side) for SCADA communication
  - Connection to Dynamic Tanks and Chemical systems
- **Features:**
  - Deuterium and Tritium level monitoring
  - Production rate tracking
  - Multiple tank support
  - Separator status monitoring

### Laser RTU/PLC
- **File:** `laser_control.lua` → `laser_rtu.lua`
- **Purpose:** Fusion laser system control
- **Requirements:**
  - Cable Modem (back side) connected to laser systems
  - Wireless Modem (top side) for SCADA communication
  - Connection to Mekanism Fusion Lasers
- **Features:**
  - Laser activation/deactivation
  - Energy level monitoring
  - Multi-laser coordination
  - Pulse control capabilities

### Data Historian
- **File:** `scada_historian.lua` → `historian.lua`
- **Purpose:** Historical data storage and analysis
- **Requirements:**
  - Wireless Modem (back side)
  - Adequate storage for historical data
  - Advanced Computer recommended
- **Features:**
  - Automated data collection
  - Multi-level aggregation (realtime, hourly, daily)
  - Trend analysis
  - Data retention management
  - File-based persistence

## Communication Channels

| Channel | Purpose | Components |
|---------|---------|------------|
| 100 | Reactor Control | Server ↔ Reactor RTU |
| 101 | Fuel Management | Server ↔ Fuel RTU |
| 102 | Energy Storage | Server ↔ Energy RTU |
| 103 | Laser Control | Server ↔ Laser RTU |
| 104 | HMI Interface | Server ↔ HMI Client |
| 105 | Alarm System | Server → All Clients |
| 106 | Data Historian | Server ↔ Historian |

## Setup Guide

### 1. Physical Setup

1. **Place computers near their respective systems:**
   - Reactor computer next to fusion reactor
   - Energy computer connected to induction matrix
   - Fuel computer connected to dynamic tanks
   - Laser computer connected to laser systems

2. **Install required peripherals:**
   - Cable modems for equipment connections
   - Wireless modems for SCADA communication
   - Monitor for HMI client

3. **Configure peripheral sides as needed**

### 2. Network Setup

1. **Ensure all wireless modems are within range**
2. **Verify channel availability (100-106)**
3. **Test basic connectivity between computers**

### 3. Installation

1. **Install SCADA Server first:**
   ```lua
   installer server
   ```

2. **Install RTU/PLC units:**
   ```lua
   installer reactor    -- On reactor computer
   installer energy     -- On energy computer
   installer fuel       -- On fuel computer
   installer laser      -- On laser computer
   ```

3. **Install HMI Client:**
   ```lua
   installer hmi        -- On control room computer
   ```

4. **Optional - Install Historian:**
   ```lua
   installer historian  -- On dedicated storage computer
   ```

### 4. Startup

1. **Start SCADA Server first**
2. **Start RTU/PLC units**
3. **Start HMI Client**
4. **Start Historian (if installed)**

All components will auto-start on computer reboot after installation.

## Features

### ✅ SCADA Standard Compliance
- Hierarchical control structure
- Distributed monitoring points
- Centralized data acquisition
- Human-machine interface
- Alarm management system

### ✅ Real-time Monitoring
- Live reactor status and parameters
- Energy storage levels and rates
- Fuel system status and production
- Laser system readiness and control

### ✅ Safety Features
- Emergency SCRAM functionality
- Temperature monitoring and alarms
- Fuel level warnings
- Equipment status monitoring
- Automatic system shutdown on critical conditions

### ✅ Data Management
- Real-time data collection
- Historical data storage
- Trend analysis capabilities
- Data retention policies
- Automated aggregation

### ✅ User Interface
- Touch-screen operation
- Multiple view screens
- Visual status indicators
- Command feedback
- Alarm notifications

## Troubleshooting

### Common Issues

1. **"No modem found" error:**
   - Check modem placement and side configuration
   - Ensure modem is properly connected

2. **"No internet connection" during install:**
   - Verify HTTP API is enabled in ComputerCraft config
   - Check internet connectivity

3. **Components not communicating:**
   - Verify wireless modems are within range
   - Check channel configuration (100-106)
   - Ensure SCADA Server is running first

4. **"Kein Fusion Reactor gefunden" (No reactor found):**
   - Verify cable modem connection to reactor
   - Check reactor is properly formed
   - Ensure correct peripheral sides

### Debug Mode

Enable debug output by editing component files and uncommenting debug print statements.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly in ComputerCraft
5. Submit a pull request

## License

This project is open source. Use and modify as needed for your installations.

## Credits

Developed for ComputerCraft and Mekanism integration. Follows industrial SCADA principles adapted for Minecraft automation.

---

**Repository:** https://github.com/maginator/cc-mek-scada-fusion  
**Issues:** Report bugs and feature requests via GitHub Issues  
**Wiki:** Additional documentation available in repository wiki