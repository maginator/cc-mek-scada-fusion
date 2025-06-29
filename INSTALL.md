# Installation Guide

## Quick Start

### 1. Download Installer
In ComputerCraft, run:
```lua
pastebin get <pastebin-id> installer
```

### 2. Install Component
```lua
installer <component>
```

Available components: `server`, `hmi`, `reactor`, `energy`, `fuel`, `laser`, `historian`, `all`

## Detailed Setup

### Typical Multi-Computer Setup

#### Central Server (Computer #1)
```lua
installer server
```
**Requirements:**
- Wireless Modem (back side)
- Central location with good wireless range

#### Control Room HMI (Computer #2) 
```lua
installer hmi
```
**Requirements:**
- Monitor (top side) - preferably Advanced Monitor
- Wireless Modem (back side)
- Located in control room for operator access

#### Reactor Control (Computer #3)
```lua
installer reactor
```
**Requirements:**
- Cable Modem (back side) connected to Fusion Reactor via Wired Modem
- Wireless Modem (top side)
- Located near the fusion reactor

#### Energy Management (Computer #4)
```lua
installer energy
```
**Requirements:**
- Cable Modem (back side) connected to Induction Matrix/Energy Cubes
- Wireless Modem (top side)
- Located near energy storage systems

#### Fuel Management (Computer #5)
```lua
installer fuel
```
**Requirements:**
- Cable Modem (back side) connected to Dynamic Tanks
- Wireless Modem (top side)  
- Located near fuel production/storage area

#### Laser Control (Computer #6)
```lua
installer laser
```
**Requirements:**
- Cable Modem (back side) connected to Fusion Lasers
- Wireless Modem (top side)
- Located near laser systems

### Physical Network Setup

1. **Place Wired Modems on Mekanism blocks:**
   - Fusion Reactor Controller
   - Induction Matrix Controller
   - Dynamic Tank Controller
   - Laser blocks

2. **Connect Cable Modems to Wired Modems using Network Cable**

3. **Place Wireless Modems on all computers**

4. **Ensure wireless range covers all computers**

### Startup Sequence

1. **Start SCADA Server first**
2. **Start RTU/PLC computers (reactor, energy, fuel, laser)**
3. **Start HMI Client**
4. **Verify all components are communicating**

## Single Computer Testing

For development/testing, install all components on one computer:
```lua
installer all
```

Then manually start individual services:
```lua
scada_server.lua      -- Terminal 1
scada_hmi.lua         -- Terminal 2 (if monitor available)
reactor_rtu.lua       -- Terminal 3
-- etc.
```

## Configuration

### Channel Configuration
Default channels (100-106) should work for most setups. To change:

1. Edit channel numbers in each component file
2. Ensure all components use matching channels
3. Restart all components after changes

### Peripheral Sides
Default peripheral sides:
- Monitors: `top`
- Wireless Modems: `back`  
- Cable Modems: `back`

To change, edit the `CONFIG` section in each component file.

## Troubleshooting

### Installation Issues

**"HTTP API is disabled"**
- Enable HTTP API in ComputerCraft config
- Restart Minecraft/server

**"No internet connection"**
- Check server internet connectivity
- Verify HTTP API allows external requests

**"Failed to download"**
- Check GitHub repository is accessible
- Verify file names and paths are correct

### Runtime Issues

**"No modem found"**
- Check modem placement and side configuration
- Ensure modems are properly placed

**"No Fusion Reactor gefunden"**
- Verify cable modem connection to reactor
- Check reactor is properly formed
- Ensure wired network is complete

**Components not communicating**
- Verify SCADA Server is running first
- Check wireless modem range
- Verify channel configuration matches

**HMI shows "DISCONNECTED"**
- Check SCADA Server is running
- Verify wireless communication
- Check HMI and Server are on same channel (104)

### Performance Issues

**Slow response/lag**
- Reduce update intervals in CONFIG sections
- Use Advanced Computers for better performance
- Minimize wireless network traffic

**High memory usage**
- Restart computers periodically
- Reduce historical data retention
- Use separate historian computer

## Updates

### Auto-update all components:
```lua
update
```

### Update specific component:
```lua  
update <component>
```

### Update installer:
```lua
update installer
```

## Advanced Configuration

### Custom Channel Assignment
Edit CONFIG sections in each component:
```lua
local CONFIG = {
    REACTOR_CHANNEL = 200,  -- Change from default 100
    -- etc.
}
```

### Custom Update Intervals  
```lua
local CONFIG = {
    UPDATE_INTERVAL = 0.5,  -- Faster updates (default 1-2 seconds)
    -- etc.
}
```

### Custom Peripheral Sides
```lua
local CONFIG = {
    MONITOR_SIDE = "right",     -- Change from default "top"
    MODEM_SIDE = "left",        -- Change from default "back"
    -- etc.
}
```

## Security Considerations

### Network Security
- Use unique channel numbers for your installation
- Consider channel ranges: 100-106 (default), 200-206, etc.
- Monitor for interference from other ComputerCraft systems

### Access Control
- Place computers in secure locations
- Limit physical access to control systems
- Consider adding authentication to HMI systems

### Backup Strategy
- Installer automatically creates backups during updates
- Manual backups: copy important files to backup computers
- Document your configuration changes

## Support

- **Repository:** https://github.com/maginator/cc-mek-scada-fusion
- **Issues:** Report via GitHub Issues
- **Documentation:** See README.md and repository wiki

## Component Compatibility

### ComputerCraft Versions
- Tested with CC: Tweaked 1.19+
- Should work with ComputerCraft 1.8+

### Mekanism Versions  
- Designed for Mekanism 10.4+
- Compatible with most Mekanism 10.x versions
- May require adjustments for other versions

### Minecraft Versions
- Tested with Minecraft 1.19+
- Should work with most modern versions with compatible mods