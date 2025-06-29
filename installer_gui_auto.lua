-- SCADA Installer GUI Auto-Selector
-- Automatically chooses the correct GUI version based on screen capabilities
-- This is the main entry point for the graphical installer

print("=== SCADA GRAPHICAL INSTALLER ===")
print("Detecting screen capabilities...")

-- Check for advanced computer capabilities
if not term.isColor() then
    print("Advanced Computer required for GUI installer")
    print("Please use command line installer:")
    print("  installer cli <component>")
    return
end

-- Get screen dimensions
local w, h = term.getSize()
local monitor = peripheral.find("monitor")
local effective_w, effective_h = w, h

-- Check if we have a monitor
if monitor then
    local mon_w, mon_h = monitor.getSize()
    effective_w, effective_h = mon_w, mon_h
    print("Monitor detected: " .. mon_w .. "x" .. mon_h)
else
    print("Computer screen: " .. w .. "x" .. h)
end

print("Effective screen size: " .. effective_w .. "x" .. effective_h)

-- Choose appropriate installer based on screen size
local installer_file = "scada_installer_gui_fixed.lua"
local configurator_file = "configurator_compact.lua" 

print("Loading optimized GUI for ComputerCraft screens...")
print("Installer: " .. installer_file)

-- Check if the GUI files exist
if not fs.exists(installer_file) then
    print("ERROR: GUI installer not found: " .. installer_file)
    print("Please install GUI components first:")
    print("  installer gui")
    return
end

if not fs.exists("scada_gui.lua") then
    print("ERROR: GUI library not found: scada_gui.lua")
    print("Please install GUI components first:")
    print("  installer gui")
    return
end

-- Load and run the appropriate installer
print("Starting graphical installer...")
print("")

local success, error = pcall(dofile, installer_file)
if not success then
    print("GUI installer failed: " .. error)
    print("")
    print("Falling back to command line installer...")
    print("Use: installer <component>")
end