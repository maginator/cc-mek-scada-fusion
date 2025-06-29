-- SCADA System Installer - ComputerCraft Compatible
-- Fixed version with ASCII characters and proper directory structure

local GITHUB_REPO = "maginator/cc-mek-scada-fusion"
local GITHUB_BRANCH = "main"
local BASE_URL = "https://raw.githubusercontent.com/" .. GITHUB_REPO .. "/" .. GITHUB_BRANCH .. "/"

-- Installation directory structure
local INSTALL_DIR = "/scada/"
local BACKUP_DIR = "/scada_backup/"
local CONFIG_FILE = INSTALL_DIR .. "config.lua"

-- Simplified installation workflows using ASCII only
local WORKFLOWS = {
    ["quickstart"] = {
        name = "[*] Quick Start Setup",
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
        name = "[S] SCADA Server Setup", 
        description = "Install central SCADA server for data collection and control",
        files = {"scada_server.lua"},
        startup = "scada_server.lua"
    },
    
    ["control"] = {
        name = "[C] Control Station Setup",
        description = "Install operator interface with monitor and touch controls", 
        files = {"scada_gui.lua", "scada_hmi.lua"},
        startup = "scada_hmi.lua"
    },
    
    ["monitor"] = {
        name = "[M] Monitoring Station Setup",
        description = "Install auto-detecting RTU for any Mekanism equipment",
        files = {"universal_rtu.lua"},
        startup = "universal_rtu.lua"
    },
    
    ["custom"] = {
        name = "[A] Advanced Installation",
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
    
    -- Create installation directory
    if not fs.exists(INSTALL_DIR) then
        fs.makeDir(INSTALL_DIR)
    end
end

function SimpleInstaller:log(message)
    print("[" .. os.date("%H:%M:%S") .. "] " .. message)
end

function SimpleInstaller:drawHeader()
    term.clear()
    term.setCursorPos(1, 1)
    
    -- Header with ASCII characters only
    term.setTextColor(colors.cyan)
    print("====================================================")
    term.setTextColor(colors.white)
    print("     MEKANISM FUSION REACTOR SCADA INSTALLER")
    term.setTextColor(colors.lightGray) 
    print("            Simplified Setup Wizard")
    term.setTextColor(colors.cyan)
    print("====================================================")
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
    -- Ensure destination is in install directory
    if not destination:match("^" .. INSTALL_DIR) then
        destination = INSTALL_DIR .. destination
    end
    
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
    
    self:log("Downloaded: " .. destination)
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
    print("[*] QUICK START SETUP")
    print("This will automatically configure your SCADA system...")
    print()
    
    -- Step 1: Detect hardware
    self:log("Detecting hardware...")
    local hardware = self:detectHardware()
    
    print("Hardware detected:")
    print("  + Advanced Computer: " .. (hardware.is_advanced and "Yes" or "No"))
    print("  + Monitors: " .. #hardware.monitors)
    print("  + Wireless Modems: " .. #hardware.wireless_modems) 
    print("  + Cable Modems: " .. #hardware.cable_modems)
    print("  + Mekanism Devices: " .. #hardware.mekanism_devices)
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
        hardware = hardware,
        install_info = {
            role = role,
            install_dir = INSTALL_DIR,
            installed_files = {},
            install_date = os.date()
        }
    }
    
    local config_file = fs.open(CONFIG_FILE, "w")
    if config_file then
        config_file.write("return " .. textutils.serialize(config))
        config_file.close()
    end
    
    -- Step 4: Install components based on role
    self:log("Installing " .. role .. " components...")
    local workflow = WORKFLOWS[role]
    
    for _, filename in ipairs(workflow.files) do
        self:downloadFile(BASE_URL .. filename, filename)
        -- Track installed files
        if config.install_info then
            table.insert(config.install_info.installed_files, INSTALL_DIR .. filename)
        end
    end
    
    -- Update config with installed files
    local config_file = fs.open(CONFIG_FILE, "w")
    if config_file then
        config_file.write("return " .. textutils.serialize(config))
        config_file.close()
    end
    
    -- Step 5: Create startup script
    if workflow.startup then
        self:createStartupScript(workflow.startup, workflow.name)
    end
    
    -- Step 6: Success
    print()
    term.setTextColor(colors.lime)
    print("[+] Installation Complete!")
    term.setTextColor(colors.white)
    print()
    print("Your computer is now configured as: " .. workflow.name)
    print("Installation directory: " .. INSTALL_DIR)
    
    if workflow.startup then
        print("Restart the computer to auto-start, or run:")
        print("  " .. INSTALL_DIR .. workflow.startup)
    end
    
    print()
    print("Management commands:")
    print("  scada_uninstall - Remove all SCADA components")
    print("  scada_update - Update to latest version")
    
    print()
    print("Next Steps:")
    if role == "server" then
        print("  1. Set up Control Station computers with 'control' option")
        print("  2. Set up Monitoring computers near Mekanism equipment")
    elseif role == "control" then 
        print("  1. Ensure SCADA Server is running")
        print("  2. Set up Monitoring computers near equipment")
    elseif role == "monitor" then
        print("  1. Ensure SCADA Server is running")
        print("  2. This computer will auto-detect connected equipment")
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
        
        print("This will install to: " .. INSTALL_DIR)
        print("Files to install:")
        for _, file in ipairs(workflow.files) do
            print("  + " .. file)
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
        print("[+] Installation complete!")
        term.setTextColor(colors.white)
        print("Press any key to exit...")
        os.pullEvent("key")
        
        return true
    end
end

function SimpleInstaller:createStartupScript(main_file, component_name)
    local startup_content = string.format([[
-- Auto-startup for %s
-- SCADA installation directory: %s

print("Starting %s...")

local main_file = "%s%s"
if not fs.exists(main_file) then
    print("ERROR: Main file not found: " .. main_file)
    print("Try reinstalling with: installer")
    return
end

-- Add SCADA directory to path
if not shell then
    print("Shell not available")
    return
end

local scada_path = "%s"
local current_path = shell.path()
if not current_path:find(scada_path) then
    shell.setPath(current_path .. ":" .. scada_path)
end

local success, error = pcall(dofile, main_file)
if not success then
    print("ERROR: " .. error)
    print("Check installation with: scada_status")
    print("Press any key to open shell...")
    os.pullEvent("key")
    shell.run("shell")
end
]], component_name, INSTALL_DIR, component_name, INSTALL_DIR, main_file, INSTALL_DIR)

    local file = fs.open("startup.lua", "w")
    if file then
        file.write(startup_content)
        file.close()
        self:log("Created startup script")
    end
    
    -- Create management scripts
    self:createManagementScripts()
end

function SimpleInstaller:createManagementScripts()
    -- Uninstall script
    local uninstall_script = string.format([[
-- SCADA Uninstaller
print("SCADA System Uninstaller")
print("This will remove all SCADA components from: %s")
print()

if fs.exists("%s") then
    local config = dofile("%s")
    if config and config.install_info then
        print("Installed as: " .. (config.install_info.role or "unknown"))
        print("Install date: " .. (config.install_info.install_date or "unknown"))
        print("Files to remove: " .. #(config.install_info.installed_files or {}))
    end
end

print()
print("WARNING: This will delete all SCADA files!")
print("Continue? (y/N): ")
local confirm = read()

if confirm:lower() == "y" then
    -- Create backup
    if fs.exists("%s") then
        local backup_path = "/scada_backup_" .. os.date("%%Y%%m%%d_%%H%%M%%S") .. "/"
        fs.makeDir(backup_path)
        for _, file in pairs(fs.list("%s")) do
            if fs.exists("%s" .. file) then
                fs.copy("%s" .. file, backup_path .. file)
            end
        end
        print("Backup created: " .. backup_path)
    end
    
    -- Remove SCADA directory
    if fs.exists("%s") then
        fs.delete("%s")
        print("Removed: %s")
    end
    
    -- Remove startup script
    if fs.exists("startup.lua") then
        fs.delete("startup.lua")
        print("Removed: startup.lua")
    end
    
    -- Remove management scripts
    if fs.exists("scada_uninstall") then fs.delete("scada_uninstall") end
    if fs.exists("scada_update") then fs.delete("scada_update") end
    if fs.exists("scada_status") then fs.delete("scada_status") end
    
    print("SCADA system uninstalled successfully!")
    print("To reinstall, run: installer")
else
    print("Uninstall cancelled.")
end
]], INSTALL_DIR, CONFIG_FILE, CONFIG_FILE, INSTALL_DIR, INSTALL_DIR, INSTALL_DIR, INSTALL_DIR, INSTALL_DIR, INSTALL_DIR, INSTALL_DIR)

    local file = fs.open("scada_uninstall", "w")
    if file then
        file.write(uninstall_script)
        file.close()
    end
    
    -- Status script
    local status_script = string.format([[
-- SCADA Status Check
print("SCADA System Status")
print("===================")

if fs.exists("%s") then
    print("Installation directory: %s")
    print("Configuration: Found")
    
    local config = dofile("%s")
    if config then
        if config.install_info then
            print("Role: " .. (config.install_info.role or "unknown"))
            print("Install date: " .. (config.install_info.install_date or "unknown"))
            print("Files: " .. #(config.install_info.installed_files or {}))
        end
        
        if config.network then
            print("Network channels: " .. textutils.serialize(config.network.channels))
        end
    end
    
    print()
    print("Files in " .. "%s" .. ":")
    for _, file in pairs(fs.list("%s")) do
        print("  " .. file .. " (" .. fs.getSize("%s" .. file) .. " bytes)")
    end
else
    print("SCADA not installed")
    print("Run 'installer' to install")
end
]], INSTALL_DIR, INSTALL_DIR, CONFIG_FILE, INSTALL_DIR, INSTALL_DIR, INSTALL_DIR)

    local file = fs.open("scada_status", "w")
    if file then
        file.write(status_script)
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