-- SCADA Compact Configurator
-- Optimized for ComputerCraft screen dimensions

local CONFIG_FILE = "scada_config.lua"

local Configurator = {
    w = 51, h = 19,  -- Standard ComputerCraft screen
    config = {
        network = {
            channels = {
                reactor = 100, fuel = 101, energy = 102, 
                laser = 103, hmi = 104, alarm = 105
            }
        },
        components = {
            server_id = "SCADA_SERVER_01",
            hmi_id = "HMI_CLIENT_01",
            historian_id = "HISTORIAN_01"
        },
        rtu = {
            auto_detect = true,
            update_interval = 1,
            timeout = 5
        }
    }
}

function Configurator:init()
    self.w, self.h = term.getSize()
    term.clear()
    term.setCursorPos(1, 1)
end

function Configurator:drawBox(x, y, w, h, title, color)
    color = color or colors.lightBlue
    
    -- Clear area and draw border
    for row = 0, h - 1 do
        term.setCursorPos(x, y + row)
        term.setBackgroundColor(colors.black)
        term.write(string.rep(" ", w))
    end
    
    -- Border
    term.setBackgroundColor(color)
    term.setTextColor(colors.white)
    
    -- Top/bottom
    term.setCursorPos(x, y)
    term.write(string.rep(" ", w))
    term.setCursorPos(x, y + h - 1)
    term.write(string.rep(" ", w))
    
    -- Sides
    for row = 1, h - 2 do
        term.setCursorPos(x, y + row)
        term.write(" ")
        term.setCursorPos(x + w - 1, y + row)
        term.write(" ")
    end
    
    -- Title
    if title then
        local title_text = " " .. title .. " "
        term.setCursorPos(x + math.floor((w - #title_text) / 2), y)
        term.setBackgroundColor(colors.cyan)
        term.write(title_text)
    end
    
    term.setBackgroundColor(colors.black)
end

function Configurator:detectPeripherals()
    local peripherals = {monitors = {}, modems = {wireless = {}, cable = {}}}
    
    for _, side in ipairs({"top", "bottom", "left", "right", "front", "back"}) do
        local ptype = peripheral.getType(side)
        if ptype == "monitor" then
            table.insert(peripherals.monitors, {side = side, type = ptype})
        elseif ptype == "modem" then
            local modem = peripheral.wrap(side)
            if modem then
                if modem.isWireless() then
                    table.insert(peripherals.modems.wireless, {side = side, modem = modem})
                else
                    table.insert(peripherals.modems.cable, {side = side, modem = modem})
                end
            end
        end
    end
    
    return peripherals
end

function Configurator:detectMekanismDevices()
    local devices = {reactor = {}, energy = {}, fuel = {}, laser = {}}
    local peripherals = self:detectPeripherals()
    
    for _, cable_modem in ipairs(peripherals.modems.cable) do
        local modem = cable_modem.modem
        local connected = modem.getNamesRemote()
        
        for _, device_name in ipairs(connected) do
            local name_lower = device_name:lower()
            local device_type = "unknown"
            
            if name_lower:find("fusion_reactor") or name_lower:find("reactor_controller") then
                device_type = "reactor"
            elseif name_lower:find("induction_matrix") or name_lower:find("energy_cube") then
                device_type = "energy"  
            elseif name_lower:find("dynamic_tank") or name_lower:find("chemical_tank") then
                device_type = "fuel"
            elseif name_lower:find("laser") then
                device_type = "laser"
            end
            
            if device_type ~= "unknown" then
                table.insert(devices[device_type], {
                    name = device_name,
                    cable_side = cable_modem.side
                })
            end
        end
    end
    
    return devices, peripherals
end

function Configurator:showWelcome()
    self:drawBox(1, 1, self.w, 3, "SCADA CONFIGURATOR", colors.blue)
    
    local y = 5
    term.setCursorPos(2, y)
    term.setTextColor(colors.white)
    term.write("Welcome to the SCADA Configuration Wizard!")
    
    y = y + 2
    term.setCursorPos(2, y)
    term.setTextColor(colors.lightGray)
    term.write("This will configure:")
    
    y = y + 1
    term.setCursorPos(4, y)
    term.write("• Network channels and settings")
    y = y + 1  
    term.setCursorPos(4, y)
    term.write("• Hardware detection")
    y = y + 1
    term.setCursorPos(4, y)
    term.write("• Component identification")
    
    term.setCursorPos(2, self.h - 1)
    term.setTextColor(colors.white)
    term.write("Press ENTER to continue...")
    
    repeat
        local event, key = os.pullEvent("key")
    until key == keys.enter
end

function Configurator:showHardwareDetection()
    term.clear()
    self:drawBox(1, 1, self.w, 3, "HARDWARE DETECTION", colors.green)
    
    local devices, peripherals = self:detectMekanismDevices()
    
    local y = 5
    term.setCursorPos(2, y)
    term.setTextColor(colors.white)
    term.write("Hardware Found:")
    
    y = y + 2
    term.setCursorPos(4, y)
    term.setTextColor(colors.lime)
    term.write("✓ Monitors: " .. #peripherals.monitors)
    
    y = y + 1
    term.setCursorPos(4, y)
    term.write("✓ Wireless Modems: " .. #peripherals.modems.wireless)
    
    y = y + 1
    term.setCursorPos(4, y)
    term.write("✓ Cable Modems: " .. #peripherals.modems.cable)
    
    y = y + 2
    term.setCursorPos(2, y)
    term.setTextColor(colors.white)
    term.write("Mekanism Devices:")
    
    y = y + 1
    for device_type, device_list in pairs(devices) do
        if #device_list > 0 then
            term.setCursorPos(4, y)
            term.setTextColor(colors.yellow)
            term.write("• " .. device_type:upper() .. ": " .. #device_list)
            y = y + 1
            if y >= self.h - 2 then break end
        end
    end
    
    term.setCursorPos(2, self.h - 1)
    term.setTextColor(colors.white)
    term.write("Press ENTER to continue...")
    
    repeat
        local event, key = os.pullEvent("key")
    until key == keys.enter
    
    return devices, peripherals
end

function Configurator:configureNetwork()
    term.clear()
    self:drawBox(1, 1, self.w, 3, "NETWORK SETUP", colors.purple)
    
    local y = 5
    term.setCursorPos(2, y)
    term.setTextColor(colors.white)
    term.write("Current Channels:")
    
    y = y + 2
    for name, channel in pairs(self.config.network.channels) do
        term.setCursorPos(4, y)
        term.setTextColor(colors.cyan)
        term.write(name:upper() .. ": " .. channel)
        y = y + 1
        if y >= self.h - 5 then break end
    end
    
    term.setCursorPos(2, self.h - 4)
    term.setTextColor(colors.white)
    term.write("Change base channel? (y/N): ")
    
    local input = read()
    if input:lower() == "y" then
        term.setCursorPos(2, self.h - 2)
        term.write("Enter new base (100-500): ")
        local base = tonumber(read())
        
        if base and base >= 100 and base <= 500 then
            self.config.network.channels = {
                reactor = base, fuel = base + 1, energy = base + 2,
                laser = base + 3, hmi = base + 4, alarm = base + 5
            }
            term.setCursorPos(2, self.h - 1)
            term.setTextColor(colors.green)
            term.write("✓ Channels updated!")
            sleep(1)
        end
    end
end

function Configurator:configureComponents(devices, peripherals)
    term.clear()
    self:drawBox(1, 1, self.w, 3, "COMPONENT SETUP", colors.orange)
    
    -- Determine component type
    local has_devices = false
    for _, device_list in pairs(devices) do
        if #device_list > 0 then
            has_devices = true
            break
        end
    end
    
    local has_monitor = #peripherals.monitors > 0
    local has_wireless = #peripherals.modems.wireless > 0
    
    local y = 5
    term.setCursorPos(2, y)
    term.setTextColor(colors.white)
    term.write("Component Type Detection:")
    
    y = y + 2
    if has_devices and has_wireless then
        term.setCursorPos(4, y)
        term.setTextColor(colors.green)
        term.write("✓ RTU/PLC Configuration")
        self.config.rtu.type = "auto"
        
        -- Auto-detect primary type
        for device_type, device_list in pairs(devices) do
            if #device_list > 0 then
                self.config.rtu.type = device_type
                self.config.rtu.id = device_type:upper() .. "_RTU_01"
                break
            end
        end
        
        y = y + 1
        term.setCursorPos(6, y)
        term.setTextColor(colors.yellow)
        term.write("Primary: " .. (self.config.rtu.type or "auto"))
    end
    
    if has_monitor and has_wireless then
        y = y + 1
        term.setCursorPos(4, y)
        term.setTextColor(colors.green)
        term.write("✓ HMI Client supported")
        
        -- Auto-configure monitor
        if #peripherals.monitors > 0 then
            self.config.hmi = {
                monitor_side = peripherals.monitors[1].side,
                screen_scale = 0.5,
                touch_enabled = true
            }
        end
    end
    
    if has_wireless and not has_devices then
        y = y + 1
        term.setCursorPos(4, y)
        term.setTextColor(colors.green)
        term.write("✓ Server Configuration")
    end
    
    term.setCursorPos(2, self.h - 1)
    term.setTextColor(colors.white)
    term.write("Press ENTER to continue...")
    
    repeat
        local event, key = os.pullEvent("key")
    until key == keys.enter
end

function Configurator:showSummary()
    term.clear()
    self:drawBox(1, 1, self.w, 3, "CONFIGURATION SUMMARY", colors.lime)
    
    local y = 5
    term.setCursorPos(2, y)
    term.setTextColor(colors.white)
    term.write("Network Channels:")
    
    y = y + 1
    for name, channel in pairs(self.config.network.channels) do
        term.setCursorPos(4, y)
        term.setTextColor(colors.cyan)
        local line = name:sub(1,8) .. ": " .. channel
        term.write(line)
        y = y + 1
        if y >= self.h - 6 then break end
    end
    
    if self.config.rtu then
        y = y + 1
        term.setCursorPos(2, y)
        term.setTextColor(colors.white)
        term.write("RTU Config:")
        y = y + 1
        term.setCursorPos(4, y)
        term.setTextColor(colors.yellow)
        term.write("Type: " .. (self.config.rtu.type or "auto"))
        if self.config.rtu.id then
            y = y + 1
            term.setCursorPos(4, y)
            term.write("ID: " .. self.config.rtu.id:sub(1, 20))
        end
    end
    
    term.setCursorPos(2, self.h - 3)
    term.setTextColor(colors.white)
    term.write("Save configuration? (Y/n): ")
end

function Configurator:saveConfig()
    local config_content = "-- SCADA System Configuration\n"
    config_content = config_content .. "-- Generated by Configurator\n\n"
    config_content = config_content .. "return " .. textutils.serialize(self.config)
    
    local file = fs.open(CONFIG_FILE, "w")
    if file then
        file.write(config_content)
        file.close()
        
        term.setCursorPos(2, self.h - 1)
        term.setTextColor(colors.green)
        term.write("✓ Configuration saved to " .. CONFIG_FILE)
        sleep(2)
        return true
    else
        term.setCursorPos(2, self.h - 1)
        term.setTextColor(colors.red)
        term.write("✗ Failed to save configuration")
        sleep(2)
        return false
    end
end

function Configurator:run()
    self:init()
    
    -- Load existing config if available
    if fs.exists(CONFIG_FILE) then
        local success, loaded_config = pcall(dofile, CONFIG_FILE)
        if success and loaded_config then
            -- Merge with defaults
            for category, values in pairs(loaded_config) do
                if self.config[category] then
                    for key, value in pairs(values) do
                        self.config[category][key] = value
                    end
                else
                    self.config[category] = values
                end
            end
        end
    end
    
    -- Configuration steps
    self:showWelcome()
    local devices, peripherals = self:showHardwareDetection()
    self:configureNetwork()
    self:configureComponents(devices, peripherals)
    self:showSummary()
    
    local save_input = read()
    if save_input:lower() ~= "n" and save_input:lower() ~= "no" then
        self:saveConfig()
    end
    
    term.clear()
    term.setCursorPos(1, 1)
    print("Configuration complete!")
    print("You can now install SCADA components.")
end

-- Error handling
local function safeRun()
    local success, error = pcall(Configurator.run, Configurator)
    if not success then
        print("Configurator Error: " .. error)
    end
end

print("=== SCADA COMPACT CONFIGURATOR ===")
print("Screen: " .. select(1, term.getSize()) .. "x" .. select(2, term.getSize()))
print("Starting configuration wizard...")

safeRun()