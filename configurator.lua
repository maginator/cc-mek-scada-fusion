-- SCADA System Configurator
-- Interactive configuration setup for SCADA components

local CONFIG_FILE = "scada_config.lua"

local Configurator = {
    config = {
        -- Network Configuration
        network = {
            channels = {
                reactor = 100,
                fuel = 101,
                energy = 102,
                laser = 103,
                hmi = 104,
                alarm = 105,
                historian = 106
            },
            wireless_range = 64,
            broadcast_strength = 64
        },
        
        -- Component IDs
        components = {
            server_id = "SCADA_SERVER_01",
            hmi_id = "HMI_CLIENT_01",
            historian_id = "HISTORIAN_01"
        },
        
        -- RTU Configuration
        rtu = {
            auto_detect = true,
            update_interval = 1,
            timeout = 5
        },
        
        -- HMI Configuration
        hmi = {
            monitor_side = "auto",
            touch_enabled = true,
            screen_scale = 0.5,
            theme = "default"
        },
        
        -- Server Configuration
        server = {
            data_retention = {
                realtime = 3600,
                hourly = 604800,
                daily = 2592000
            },
            alarm_enabled = true,
            historian_enabled = true
        }
    }
}

function Configurator:detectPeripherals()
    local peripherals = {
        monitors = {},
        modems = {wireless = {}, cable = {}},
        sides = {"top", "bottom", "left", "right", "front", "back"}
    }
    
    for _, side in ipairs(peripherals.sides) do
        local peripheral_type = peripheral.getType(side)
        if peripheral_type then
            if peripheral_type == "monitor" then
                table.insert(peripherals.monitors, {side = side, type = peripheral_type})
            elseif peripheral_type == "modem" then
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
    end
    
    return peripherals
end

function Configurator:detectMekanismDevices()
    local devices = {
        reactor = {},
        energy = {},
        fuel = {},
        laser = {},
        unknown = {}
    }
    
    local peripherals = self:detectPeripherals()
    
    for _, cable_modem in ipairs(peripherals.modems.cable) do
        local modem = cable_modem.modem
        local connected_devices = modem.getNamesRemote()
        
        for _, device_name in ipairs(connected_devices) do
            local device_type = self:classifyDevice(device_name)
            table.insert(devices[device_type], {
                name = device_name,
                cable_side = cable_modem.side,
                modem = modem
            })
        end
    end
    
    return devices
end

function Configurator:classifyDevice(device_name)
    local name_lower = device_name:lower()
    
    -- Reactor devices
    if name_lower:find("fusion_reactor") or name_lower:find("reactor_controller") then
        return "reactor"
    end
    
    -- Energy storage devices
    if name_lower:find("induction_matrix") or name_lower:find("induction_casing") or 
       name_lower:find("energy_cube") or name_lower:find("induction_cell") then
        return "energy"
    end
    
    -- Fuel system devices
    if name_lower:find("dynamic_tank") or name_lower:find("chemical_tank") or
       name_lower:find("electrolytic_separator") then
        return "fuel"
    end
    
    -- Laser devices
    if name_lower:find("laser") then
        return "laser"
    end
    
    return "unknown"
end

function Configurator:drawBox(x, y, width, height, title, color)
    color = color or colors.lightBlue
    
    -- Clear area
    for row = 0, height - 1 do
        term.setCursorPos(x, y + row)
        term.setBackgroundColor(colors.black)
        term.write(string.rep(" ", width))
    end
    
    -- Draw borders
    term.setBackgroundColor(color)
    term.setTextColor(colors.white)
    
    -- Top border
    term.setCursorPos(x, y)
    term.write(string.rep(" ", width))
    
    -- Bottom border  
    term.setCursorPos(x, y + height - 1)
    term.write(string.rep(" ", width))
    
    -- Side borders
    for row = 1, height - 2 do
        term.setCursorPos(x, y + row)
        term.write(" ")
        term.setCursorPos(x + width - 1, y + row)
        term.write(" ")
    end
    
    -- Title
    if title then
        local title_text = " " .. title .. " "
        term.setCursorPos(x + math.floor((width - #title_text) / 2), y)
        term.setBackgroundColor(colors.cyan)
        term.write(title_text)
    end
    
    term.setBackgroundColor(colors.black)
end

function Configurator:showStatusIcon(status)
    if status == "found" or status == "active" or status == "online" then
        term.setTextColor(colors.green)
        return "✓"
    elseif status == "warning" or status == "partial" then
        term.setTextColor(colors.orange)
        return "⚠"
    elseif status == "error" or status == "offline" then
        term.setTextColor(colors.red)
        return "✗"
    else
        term.setTextColor(colors.gray)
        return "?"
    end
end

function Configurator:showDetectedDevices()
    term.clear()
    term.setCursorPos(1, 1)
    
    -- Header
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.white)
    term.write(string.rep(" ", 51))
    term.setCursorPos(10, 1)
    term.write("🔧 SCADA HARDWARE DETECTION WIZARD 🔧")
    
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    
    local peripherals = self:detectPeripherals()
    local devices = self:detectMekanismDevices()
    
    -- Monitors section
    self:drawBox(2, 3, 24, 8, "MONITORS", colors.green)
    
    term.setCursorPos(4, 5)
    if #peripherals.monitors > 0 then
        term.write(self:showStatusIcon("found") .. " Monitors Found: " .. #peripherals.monitors)
        local y_pos = 6
        for _, monitor in ipairs(peripherals.monitors) do
            if y_pos > 9 then break end
            term.setCursorPos(6, y_pos)
            term.setTextColor(colors.lightGray)
            term.write("📺 " .. monitor.side)
            y_pos = y_pos + 1
        end
    else
        term.write(self:showStatusIcon("error") .. " No monitors detected")
    end
    
    -- Modems section
    self:drawBox(28, 3, 24, 8, "NETWORK", colors.blue)
    
    term.setCursorPos(30, 5)
    local total_modems = #peripherals.modems.wireless + #peripherals.modems.cable
    if total_modems > 0 then
        term.write(self:showStatusIcon("found") .. " Modems Found: " .. total_modems)
        
        term.setCursorPos(32, 6)
        term.setTextColor(colors.lightGray)
        term.write("📡 Wireless: " .. #peripherals.modems.wireless)
        
        term.setCursorPos(32, 7)
        term.write("🔌 Cable: " .. #peripherals.modems.cable)
    else
        term.write(self:showStatusIcon("error") .. " No modems detected")
    end
    
    -- Mekanism devices section
    self:drawBox(2, 12, 50, 10, "MEKANISM DEVICES", colors.purple)
    
    local y_pos = 14
    local has_devices = false
    
    for category, device_list in pairs(devices) do
        if category ~= "unknown" and #device_list > 0 then
            has_devices = true
            term.setCursorPos(4, y_pos)
            term.write(self:showStatusIcon("found") .. " " .. category:upper() .. " (" .. #device_list .. ")")
            y_pos = y_pos + 1
            
            for _, device in ipairs(device_list) do
                if y_pos > 20 then break end
                term.setCursorPos(6, y_pos)
                term.setTextColor(colors.lightGray)
                
                local icon = "⚙"
                if category == "reactor" then icon = "⚡"
                elseif category == "energy" then icon = "🔋"
                elseif category == "fuel" then icon = "⛽"
                elseif category == "laser" then icon = "🔫"
                end
                
                term.write(icon .. " " .. device.name:sub(1, 30))
                y_pos = y_pos + 1
            end
            y_pos = y_pos + 1
        end
    end
    
    if not has_devices then
        term.setCursorPos(4, 14)
        term.write(self:showStatusIcon("warning") .. " No Mekanism devices detected")
        term.setCursorPos(6, 15)
        term.setTextColor(colors.yellow)
        term.write("Check cable modem connections")
    end
    
    -- Continue prompt
    term.setCursorPos(2, 23)
    term.setTextColor(colors.white)
    term.write("Press [ENTER] to continue with configuration...")
    
    return peripherals, devices
end

function Configurator:configureNetwork()
    term.clear()
    
    -- Network configuration screen
    self:drawBox(5, 3, 42, 16, "NETWORK CONFIGURATION", colors.blue)
    
    term.setCursorPos(7, 5)
    term.setTextColor(colors.white)
    term.write("Current Channel Assignments:")
    
    local y_pos = 7
    for name, channel in pairs(self.config.network.channels) do
        term.setCursorPos(9, y_pos)
        term.setTextColor(colors.lightGray)
        term.write("📡 " .. name:upper() .. ": ")
        term.setTextColor(colors.cyan)
        term.write("Channel " .. channel)
        y_pos = y_pos + 1
    end
    
    term.setCursorPos(7, y_pos + 1)
    term.setTextColor(colors.white)
    term.write("Change channel assignments? (y/N): ")
    
    local change_channels = read()
    
    if change_channels:lower() == "y" or change_channels:lower() == "yes" then
        term.setCursorPos(7, y_pos + 3)
        term.write("Enter new base channel (1-65000): ")
        
        local base_channel = tonumber(read())
        
        if base_channel and base_channel > 0 and base_channel < 65000 then
            self.config.network.channels = {
                reactor = base_channel,
                fuel = base_channel + 1,
                energy = base_channel + 2,
                laser = base_channel + 3,
                hmi = base_channel + 4,
                alarm = base_channel + 5,
                historian = base_channel + 6
            }
            
            term.setCursorPos(7, y_pos + 5)
            term.setTextColor(colors.green)
            term.write("✓ Channels updated successfully!")
        else
            term.setCursorPos(7, y_pos + 5)
            term.setTextColor(colors.red)
            term.write("✗ Invalid channel, keeping defaults")
        end
        
        term.setCursorPos(7, 17)
        term.setTextColor(colors.white)
        term.write("Press [ENTER] to continue...")
        read()
    end
end

function Configurator:configureComponents(peripherals, devices)
    print("\n=== COMPONENT CONFIGURATION ===")
    
    -- Determine component type based on detected devices
    local component_type = self:determineComponentType(devices)
    
    print("Detected component type: " .. component_type:upper())
    
    if component_type == "server" then
        self:configureServer()
    elseif component_type == "hmi" then
        self:configureHMI(peripherals)
    elseif component_type == "rtu" then
        self:configureRTU(devices)
    elseif component_type == "historian" then
        self:configureHistorian()
    else
        print("Unable to auto-detect component type")
        self:manualComponentSelection()
    end
end

function Configurator:determineComponentType(devices)
    local has_devices = false
    for category, device_list in pairs(devices) do
        if category ~= "unknown" and #device_list > 0 then
            has_devices = true
            break
        end
    end
    
    local peripherals = self:detectPeripherals()
    local has_monitor = #peripherals.monitors > 0
    local has_wireless = #peripherals.modems.wireless > 0
    local has_cable = #peripherals.modems.cable > 0
    
    if has_devices and has_cable and has_wireless then
        return "rtu"
    elseif has_monitor and has_wireless then
        return "hmi"
    elseif has_wireless and not has_devices then
        return "server"
    else
        return "unknown"
    end
end

function Configurator:configureServer()
    print("Configuring SCADA Server...")
    
    print("Enter Server ID (current: " .. self.config.components.server_id .. "):")
    local server_id = read()
    if server_id ~= "" then
        self.config.components.server_id = server_id
    end
    
    print("Enable historian? (Y/n)")
    local historian = read()
    self.config.server.historian_enabled = historian:lower() ~= "n" and historian:lower() ~= "no"
    
    print("Enable alarms? (Y/n)")
    local alarms = read()
    self.config.server.alarm_enabled = alarms:lower() ~= "n" and alarms:lower() ~= "no"
end

function Configurator:configureHMI(peripherals)
    print("Configuring HMI Client...")
    
    print("Enter HMI ID (current: " .. self.config.components.hmi_id .. "):")
    local hmi_id = read()
    if hmi_id ~= "" then
        self.config.components.hmi_id = hmi_id
    end
    
    if #peripherals.monitors > 0 then
        print("Available monitors:")
        for i, monitor in ipairs(peripherals.monitors) do
            print("  " .. i .. ". " .. monitor.side)
        end
        print("Select monitor (1-" .. #peripherals.monitors .. ", or 'auto'):")
        local monitor_choice = read()
        
        if monitor_choice == "auto" then
            self.config.hmi.monitor_side = "auto"
        else
            local choice_num = tonumber(monitor_choice)
            if choice_num and choice_num >= 1 and choice_num <= #peripherals.monitors then
                self.config.hmi.monitor_side = peripherals.monitors[choice_num].side
            end
        end
    end
    
    print("Screen scale (0.5, 1.0, 1.5, 2.0) [current: " .. self.config.hmi.screen_scale .. "]:")
    local scale = tonumber(read())
    if scale and scale >= 0.5 and scale <= 2.0 then
        self.config.hmi.screen_scale = scale
    end
end

function Configurator:configureRTU(devices)
    print("Configuring RTU/PLC...")
    
    -- Determine RTU type based on detected devices
    local rtu_types = {}
    for category, device_list in pairs(devices) do
        if category ~= "unknown" and #device_list > 0 then
            table.insert(rtu_types, category)
        end
    end
    
    if #rtu_types == 1 then
        print("Auto-detected RTU type: " .. rtu_types[1]:upper())
        self.config.rtu.type = rtu_types[1]
    elseif #rtu_types > 1 then
        print("Multiple device types detected:")
        for i, rtu_type in ipairs(rtu_types) do
            print("  " .. i .. ". " .. rtu_type:upper())
        end
        print("Select primary RTU type (1-" .. #rtu_types .. "):")
        local choice = tonumber(read())
        if choice and choice >= 1 and choice <= #rtu_types then
            self.config.rtu.type = rtu_types[choice]
        end
    else
        print("No Mekanism devices detected. Manual configuration required.")
        self:manualRTUConfiguration()
        return
    end
    
    print("Enter RTU ID (e.g., REACTOR_RTU_01):")
    local rtu_id = read()
    if rtu_id ~= "" then
        self.config.rtu.id = rtu_id
    else
        self.config.rtu.id = (self.config.rtu.type or "GENERIC"):upper() .. "_RTU_01"
    end
    
    print("Update interval in seconds [current: " .. self.config.rtu.update_interval .. "]:")
    local interval = tonumber(read())
    if interval and interval > 0 then
        self.config.rtu.update_interval = interval
    end
end

function Configurator:manualRTUConfiguration()
    print("Manual RTU Configuration")
    print("Available RTU types:")
    print("  1. Reactor RTU")
    print("  2. Energy RTU") 
    print("  3. Fuel RTU")
    print("  4. Laser RTU")
    print("Select RTU type (1-4):")
    
    local choice = tonumber(read())
    local types = {"reactor", "energy", "fuel", "laser"}
    
    if choice and choice >= 1 and choice <= 4 then
        self.config.rtu.type = types[choice]
    else
        self.config.rtu.type = "generic"
    end
end

function Configurator:configureHistorian()
    print("Configuring Data Historian...")
    
    print("Enter Historian ID (current: " .. self.config.components.historian_id .. "):")
    local historian_id = read()
    if historian_id ~= "" then
        self.config.components.historian_id = historian_id
    end
    
    print("Data retention in hours - Realtime [current: " .. (self.config.server.data_retention.realtime / 3600) .. "]:")
    local realtime = tonumber(read())
    if realtime and realtime > 0 then
        self.config.server.data_retention.realtime = realtime * 3600
    end
end

function Configurator:saveConfig()
    local config_content = "-- SCADA System Configuration\n"
    config_content = config_content .. "-- Generated by SCADA Configurator\n\n"
    config_content = config_content .. "return " .. textutils.serialize(self.config)
    
    local file = fs.open(CONFIG_FILE, "w")
    if file then
        file.write(config_content)
        file.close()
        print("Configuration saved to: " .. CONFIG_FILE)
        return true
    else
        print("ERROR: Failed to save configuration")
        return false
    end
end

function Configurator:loadConfig()
    if fs.exists(CONFIG_FILE) then
        local success, loaded_config = pcall(dofile, CONFIG_FILE)
        if success and loaded_config then
            -- Merge loaded config with defaults
            for category, values in pairs(loaded_config) do
                if self.config[category] then
                    for key, value in pairs(values) do
                        self.config[category][key] = value
                    end
                else
                    self.config[category] = values
                end
            end
            print("Existing configuration loaded")
            return true
        end
    end
    print("Using default configuration")
    return false
end

function Configurator:showSummary()
    term.clear()
    
    -- Summary header
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.green)
    term.setTextColor(colors.white)
    term.write(string.rep(" ", 51))
    term.setCursorPos(12, 1)
    term.write("✓ CONFIGURATION SUMMARY ✓")
    
    term.setBackgroundColor(colors.black)
    
    -- Network section
    self:drawBox(2, 3, 24, 10, "NETWORK", colors.blue)
    
    term.setCursorPos(4, 5)
    term.setTextColor(colors.white)
    term.write("Channel Assignments:")
    
    local y_pos = 6
    for name, channel in pairs(self.config.network.channels) do
        if y_pos > 11 then break end
        term.setCursorPos(4, y_pos)
        term.setTextColor(colors.lightGray)
        term.write(name:sub(1,8) .. ": " .. channel)
        y_pos = y_pos + 1
    end
    
    -- Components section
    self:drawBox(28, 3, 24, 10, "COMPONENTS", colors.purple)
    
    term.setCursorPos(30, 5)
    term.setTextColor(colors.white)
    term.write("Component IDs:")
    
    y_pos = 6
    for name, id in pairs(self.config.components) do
        if y_pos > 11 then break end
        term.setCursorPos(30, y_pos)
        term.setTextColor(colors.lightGray)
        term.write(name:sub(1,10) .. ":")
        term.setCursorPos(30, y_pos + 1)
        term.write("  " .. id:sub(1,18))
        y_pos = y_pos + 2
    end
    
    -- RTU Configuration
    if self.config.rtu then
        self:drawBox(2, 14, 24, 6, "RTU CONFIG", colors.orange)
        
        term.setCursorPos(4, 16)
        term.setTextColor(colors.lightGray)
        term.write("Type: " .. (self.config.rtu.type or "auto"))
        
        term.setCursorPos(4, 17)
        term.write("Update: " .. self.config.rtu.update_interval .. "s")
        
        if self.config.rtu.id then
            term.setCursorPos(4, 18)
            term.write("ID: " .. self.config.rtu.id:sub(1,16))
        end
    end
    
    -- HMI Configuration
    if self.config.hmi then
        self:drawBox(28, 14, 24, 6, "HMI CONFIG", colors.cyan)
        
        term.setCursorPos(30, 16)
        term.setTextColor(colors.lightGray)
        term.write("Monitor: " .. self.config.hmi.monitor_side)
        
        term.setCursorPos(30, 17)
        term.write("Scale: " .. self.config.hmi.screen_scale)
        
        term.setCursorPos(30, 18)
        term.write("Touch: " .. (self.config.hmi.touch_enabled and "Yes" or "No"))
    end
end

function Configurator:showMenu(title, options, current_selection)
    current_selection = current_selection or 1
    
    term.clear()
    term.setCursorPos(1, 1)
    
    -- Header
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.white)
    local header = "🔧 " .. title .. " 🔧"
    local header_padding = math.floor((51 - #header) / 2)
    term.write(string.rep(" ", 51))
    term.setCursorPos(header_padding, 1)
    term.write(header)
    
    term.setBackgroundColor(colors.black)
    
    -- Menu options
    for i, option in ipairs(options) do
        term.setCursorPos(5, 3 + i * 2)
        
        if i == current_selection then
            term.setBackgroundColor(colors.lightBlue)
            term.setTextColor(colors.white)
            term.write(" ► " .. option.text .. string.rep(" ", 40 - #option.text))
        else
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.lightGray)
            term.write("   " .. option.text)
        end
    end
    
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(5, 3 + #options * 2 + 2)
    term.write("Use ↑/↓ arrows to navigate, ENTER to select")
    
    return current_selection
end

function Configurator:getUserSelection(title, options)
    local selection = 1
    
    while true do
        selection = self:showMenu(title, options, selection)
        
        local event, key = os.pullEvent("key")
        
        if key == keys.up and selection > 1 then
            selection = selection - 1
        elseif key == keys.down and selection < #options then
            selection = selection + 1
        elseif key == keys.enter then
            return selection, options[selection]
        end
    end
end

function Configurator:showProgress(title, steps, current_step)
    term.clear()
    term.setCursorPos(1, 1)
    
    -- Header
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.white)
    term.write(string.rep(" ", 51))
    term.setCursorPos(10, 1)
    term.write("🔧 " .. title .. " 🔧")
    
    term.setBackgroundColor(colors.black)
    
    -- Progress bar
    local progress = math.floor((current_step / #steps) * 40)
    term.setCursorPos(5, 3)
    term.setTextColor(colors.white)
    term.write("Progress: [")
    
    term.setTextColor(colors.green)
    term.write(string.rep("█", progress))
    
    term.setTextColor(colors.gray)
    term.write(string.rep("░", 40 - progress))
    
    term.setTextColor(colors.white)
    term.write("] " .. current_step .. "/" .. #steps)
    
    -- Steps list
    term.setCursorPos(5, 5)
    term.write("Configuration Steps:")
    
    for i, step in ipairs(steps) do
        term.setCursorPos(7, 6 + i)
        
        if i < current_step then
            term.setTextColor(colors.green)
            term.write("✓ " .. step)
        elseif i == current_step then
            term.setTextColor(colors.yellow)
            term.write("► " .. step)
        else
            term.setTextColor(colors.gray)
            term.write("  " .. step)
        end
    end
    
    term.setTextColor(colors.white)
end

function Configurator:run()
    term.clear()
    
    -- Welcome screen
    self:drawBox(5, 5, 42, 12, "SCADA CONFIGURATOR", colors.blue)
    
    term.setCursorPos(7, 7)
    term.setTextColor(colors.white)
    term.write("Welcome to the SCADA System Configurator!")
    
    term.setCursorPos(7, 9)
    term.setTextColor(colors.lightGray)
    term.write("This wizard will help you configure:")
    
    term.setCursorPos(9, 11)
    term.write("• Network settings and channels")
    term.setCursorPos(9, 12)
    term.write("• Hardware detection and setup")
    term.setCursorPos(9, 13)
    term.write("• Component identification")
    term.setCursorPos(9, 14)
    term.write("• System optimization")
    
    term.setCursorPos(7, 16)
    term.setTextColor(colors.white)
    term.write("Press [ENTER] to begin...")
    
    read()
    
    -- Configuration steps
    local steps = {
        "Hardware Detection",
        "Network Configuration", 
        "Component Setup",
        "Final Review",
        "Save Configuration"
    }
    
    -- Load existing config if available
    self:loadConfig()
    
    -- Step 1: Hardware Detection
    self:showProgress("CONFIGURING SYSTEM", steps, 1)
    sleep(1)
    local peripherals, devices = self:showDetectedDevices()
    read()
    
    -- Step 2: Network Configuration
    self:showProgress("CONFIGURING SYSTEM", steps, 2)
    sleep(1)
    self:configureNetwork()
    
    -- Step 3: Component Setup
    self:showProgress("CONFIGURING SYSTEM", steps, 3)
    sleep(1)
    self:configureComponents(peripherals, devices)
    
    -- Step 4: Final Review
    self:showProgress("CONFIGURING SYSTEM", steps, 4)
    sleep(1)
    self:showSummary()
    
    term.setCursorPos(2, 23)
    term.setTextColor(colors.white)
    term.write("Press [ENTER] to continue...")
    read()
    
    -- Step 5: Save Configuration
    self:showProgress("CONFIGURING SYSTEM", steps, 5)
    sleep(1)
    
    local save_options = {
        {text = "Save configuration and exit", value = "save"},
        {text = "Exit without saving", value = "nosave"}
    }
    
    local choice, selected = self:getUserSelection("SAVE CONFIGURATION", save_options)
    
    if selected.value == "save" then
        if self:saveConfig() then
            term.clear()
            self:drawBox(10, 8, 32, 8, "SUCCESS", colors.green)
            
            term.setCursorPos(12, 10)
            term.setTextColor(colors.white)
            term.write("✓ Configuration saved successfully!")
            
            term.setCursorPos(12, 12)
            term.setTextColor(colors.lightGray)
            term.write("File: " .. CONFIG_FILE)
            
            term.setCursorPos(12, 14)
            term.setTextColor(colors.white)
            term.write("You can now run SCADA components.")
            
            term.setCursorPos(12, 16)
            term.write("Press any key to exit...")
            
            os.pullEvent("key")
        end
    else
        term.clear()
        term.setCursorPos(1, 1)
        term.setTextColor(colors.yellow)
        print("Configuration not saved. Exiting...")
    end
end

-- Error handling wrapper
local function safeRun()
    local success, error = pcall(Configurator.run, Configurator)
    if not success then
        print("CONFIGURATOR ERROR: " .. error)
        return false
    end
    return true
end

print("Starting SCADA System Configurator...")
safeRun()