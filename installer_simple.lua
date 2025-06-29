-- SCADA Simple Installer
-- Streamlined installation workflow for ComputerCraft SCADA system

local GITHUB_REPO = "maginator/cc-mek-scada-fusion"
local GITHUB_BRANCH = "main"
local BASE_URL = "https://raw.githubusercontent.com/" .. GITHUB_REPO .. "/" .. GITHUB_BRANCH .. "/"

-- Simplified installation workflows
local WORKFLOWS = {
    ["quickstart"] = {
        name = "🚀 Quick Start Setup",
        description = "Automatic setup with smart defaults - just follow the prompts!",
        steps = {
            {action = "detect", message = "Detecting computer capabilities and hardware..."},
            {action = "install_gui", message = "Installing graphical interface..."},
            {action = "configure", message = "Running configuration wizard..."},
            {action = "install_components", message = "Installing SCADA components based on hardware..."},
            {action = "complete", message = "Setup complete!"}
        }
    },
    
    ["server"] = {
        name = "🖥️ SCADA Server Setup", 
        description = "Install central SCADA server for data collection and control",
        files = {"scada_server.lua"},
        startup = "scada_server.lua"
    },
    
    ["control"] = {
        name = "🎮 Control Station Setup",
        description = "Install operator interface with monitor and touch controls", 
        files = {"scada_gui.lua", "scada_hmi.lua"},
        startup = "scada_hmi.lua"
    },
    
    ["monitor"] = {
        name = "📊 Monitoring Station Setup",
        description = "Install auto-detecting RTU for any Mekanism equipment",
        files = {"universal_rtu.lua"},
        startup = "universal_rtu.lua"
    },
    
    ["custom"] = {
        name = "⚙️ Custom Installation",
        description = "Advanced users - choose specific components manually",
        action = "show_advanced"
    }
}

local SimpleInstaller = {
    w = 51, h = 19
}

function SimpleInstaller:init()
    self.w, self.h = term.getSize()
    term.clear()
    term.setCursorPos(1, 1)
end

function SimpleInstaller:log(message)
    print("[" .. os.date("%H:%M:%S") .. "] " .. message)
end

function SimpleInstaller:drawHeader()
    term.clear()
    term.setCursorPos(1, 1)
    
    -- Header
    term.setTextColor(colors.cyan)
    print("════════════════════════════════════════════════════")
    term.setTextColor(colors.white)
    print("        MEKANISM FUSION REACTOR SCADA INSTALLER")
    term.setTextColor(colors.lightGray) 
    print("               Simplified Setup Wizard")
    term.setTextColor(colors.cyan)
    print("════════════════════════════════════════════════════")
    term.setTextColor(colors.white)
    print()
end

function SimpleInstaller:showMainMenu()
    self:drawHeader()
    
    print("Welcome! This installer will help you set up your SCADA system.")
    print("Choose the type of computer you're setting up:")
    print()
    
    local index = 1
    local workflows = {}
    
    for key, workflow in pairs(WORKFLOWS) do
        print(string.format("  %d. %s", index, workflow.name))
        print(string.format("     %s", workflow.description))
        print()
        workflows[index] = key
        index = index + 1
    end
    
    print("Enter choice (1-" .. (index-1) .. ") or 'q' to quit: ")
    local input = read()
    
    if input:lower() == "q" then
        return nil
    end
    
    local choice = tonumber(input)
    if choice and choice >= 1 and choice < index then
        return workflows[choice]
    end
    
    print("Invalid choice. Press any key to try again...")
    os.pullEvent("key")
    return self:showMainMenu()
end

function SimpleInstaller:downloadFile(url, destination)
    local response = http.get(url)
    if not response then
        error("Failed to download: " .. url)
    end
    
    local content = response.readAll()
    response.close()
    
    if not content or content == "" then
        error("Downloaded file is empty: " .. url)
    end
    
    local file = fs.open(destination, "w")
    if not file then
        error("Failed to create file: " .. destination)
    end
    
    file.write(content)
    file.close()
    
    return true
end

function SimpleInstaller:detectHardware()
    local hardware = {
        monitors = {},
        wireless_modems = {},
        cable_modems = {},
        mekanism_devices = {},
        is_advanced = term.isColor(),
        can_gui = term.isColor()
    }
    
    -- Detect peripherals
    for _, side in ipairs({"top", "bottom", "left", "right", "front", "back"}) do
        local ptype = peripheral.getType(side)
        if ptype == "monitor" then
            table.insert(hardware.monitors, side)
        elseif ptype == "modem" then
            local modem = peripheral.wrap(side)
            if modem then
                if modem.isWireless() then
                    table.insert(hardware.wireless_modems, side)
                else
                    table.insert(hardware.cable_modems, side)
                    
                    -- Check for Mekanism devices
                    local devices = modem.getNamesRemote()
                    for _, device in ipairs(devices) do
                        local name_lower = device:lower()
                        if name_lower:find("reactor") or name_lower:find("induction") or 
                           name_lower:find("tank") or name_lower:find("laser") then
                            table.insert(hardware.mekanism_devices, device)
                        end
                    end
                end
            end
        end
    end
    
    return hardware
end

function SimpleInstaller:runQuickStart()
    self:drawHeader()
    print("🚀 QUICK START SETUP")
    print("This will automatically configure your SCADA system...")
    print()
    
    -- Step 1: Detect hardware
    self:log("Detecting hardware...")
    local hardware = self:detectHardware()
    
    print("Hardware detected:")
    print("  • Advanced Computer: " .. (hardware.is_advanced and "Yes" or "No"))
    print("  • Monitors: " .. #hardware.monitors)
    print("  • Wireless Modems: " .. #hardware.wireless_modems) 
    print("  • Cable Modems: " .. #hardware.cable_modems)
    print("  • Mekanism Devices: " .. #hardware.mekanism_devices)
    print()
    
    -- Determine computer role
    local role = "server"  -- Default
    
    if #hardware.mekanism_devices > 0 and #hardware.wireless_modems > 0 then
        role = "monitor"  -- RTU for equipment monitoring
    elseif #hardware.monitors > 0 and #hardware.wireless_modems > 0 then
        role = "control"  -- HMI client
    elseif #hardware.wireless_modems > 0 then
        role = "server"   -- SCADA server
    end
    
    print("Recommended role: " .. WORKFLOWS[role].name)
    print("Continue with this setup? (Y/n): ")
    local confirm = read()
    
    if confirm:lower() == "n" then
        return false
    end
    
    -- Step 2: Install GUI if advanced computer
    if hardware.is_advanced then
        self:log("Installing GUI components...")
        self:downloadFile(BASE_URL .. "scada_gui.lua", "scada_gui.lua")
        self:downloadFile(BASE_URL .. "scada_installer_gui_fixed.lua", "scada_installer_gui_fixed.lua")
        self:downloadFile(BASE_URL .. "configurator_compact.lua", "configurator_compact.lua")
    end
    
    -- Step 3: Auto-configure
    self:log("Creating configuration...")
    local config = {
        network = {
            channels = {reactor = 100, fuel = 101, energy = 102, laser = 103, hmi = 104, alarm = 105}
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
        },
        hardware = hardware
    }
    
    local config_file = fs.open("scada_config.lua", "w")
    if config_file then
        config_file.write("return " .. textutils.serialize(config))
        config_file.close()
    end
    
    -- Step 4: Install components based on role
    self:log("Installing " .. role .. " components...")
    local workflow = WORKFLOWS[role]
    
    for _, filename in ipairs(workflow.files) do
        self:downloadFile(BASE_URL .. filename, filename)
    end
    
    -- Step 5: Create startup script
    if workflow.startup then
        self:createStartupScript(workflow.startup, workflow.name)
    end
    
    -- Step 6: Success
    print()
    term.setTextColor(colors.lime)
    print("✓ Installation Complete!")
    term.setTextColor(colors.white)
    print()
    print("Your computer is now configured as: " .. workflow.name)
    
    if workflow.startup then
        print("Restart the computer to auto-start, or run: " .. workflow.startup)
    end
    
    print()
    print("Next Steps:")
    if role == "server" then
        print("  1. Set up Control Station computers with 'control' option")
        print("  2. Set up Monitoring computers near Mekanism equipment with 'monitor' option")
    elseif role == "control" then 
        print("  1. Ensure SCADA Server is running")
        print("  2. Set up Monitoring computers near equipment")
    elseif role == "monitor" then
        print("  1. Ensure SCADA Server is running")
        print("  2. This computer will auto-detect and monitor connected equipment")
    end
    
    print()
    print("Press any key to exit...")
    os.pullEvent("key")
    
    return true
end

function SimpleInstaller:runWorkflow(workflow_key)
    local workflow = WORKFLOWS[workflow_key]
    
    if workflow_key == "quickstart" then
        return self:runQuickStart()
    elseif workflow_key == "custom" then
        -- Fall back to original installer
        print("Loading advanced installer...")
        sleep(1)
        shell.run("installer")
        return true
    else
        -- Simple component installation
        self:drawHeader()
        print(workflow.name)
        print(workflow.description)
        print()
        
        print("This will install:")
        for _, file in ipairs(workflow.files) do
            print("  • " .. file)
        end
        print()
        
        print("Continue? (Y/n): ")
        local confirm = read()
        if confirm:lower() == "n" then
            return false
        end
        
        for _, file in ipairs(workflow.files) do
            self:log("Downloading " .. file .. "...")
            self:downloadFile(BASE_URL .. file, file)
        end
        
        if workflow.startup then
            self:createStartupScript(workflow.startup, workflow.name)
        end
        
        term.setTextColor(colors.lime)
        print("✓ Installation complete!")
        term.setTextColor(colors.white)
        print("Press any key to exit...")
        os.pullEvent("key")
        
        return true
    end
end

function SimpleInstaller:createStartupScript(main_file, component_name)
    local startup_content = string.format([[
-- Auto-startup for %s
print("Starting %s...")

if not fs.exists("%s") then
    print("ERROR: Main file not found")
    return
end

local success, error = pcall(dofile, "%s")
if not success then
    print("ERROR: " .. error)
    print("Press any key to open shell...")
    os.pullEvent("key")
    shell.run("shell")
end
]], component_name, component_name, main_file, main_file)

    local file = fs.open("startup.lua", "w")
    if file then
        file.write(startup_content)
        file.close()
    end
end

function SimpleInstaller:checkRequirements()
    if not http then
        error("HTTP API required. Enable in ComputerCraft config.")
    end
    
    local test = http.get("https://httpbin.org/get")
    if not test then
        error("No internet connection")
    end
    test.close()
end

function SimpleInstaller:run()
    self:init()
    
    -- Check requirements
    local success, error = pcall(self.checkRequirements, self)
    if not success then
        print("ERROR: " .. error)
        return false
    end
    
    -- Main workflow
    while true do
        local choice = self:showMainMenu()
        if not choice then
            break
        end
        
        local success = self:runWorkflow(choice)
        if success then
            break
        end
    end
    
    term.clear()
    term.setCursorPos(1, 1)
    print("Thank you for using SCADA Installer!")
end

-- Main execution
SimpleInstaller:run()