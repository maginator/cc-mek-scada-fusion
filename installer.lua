-- SCADA System Installer for ComputerCraft
-- Downloads and installs SCADA components from GitHub repository
-- Usage: pastebin get <pastebin-id> installer && installer <component>

local GITHUB_REPO = "maginator/cc-mek-scada-fusion"
local GITHUB_BRANCH = "main"
local BASE_URL = "https://raw.githubusercontent.com/" .. GITHUB_REPO .. "/" .. GITHUB_BRANCH .. "/"

-- Installation directories
local INSTALL_DIR = "/scada/"
local BACKUP_DIR = "/scada_backup/"
local CONFIG_FILE = INSTALL_DIR .. "config.lua"

local COMPONENTS = {
    ["server"] = {
        name = "SCADA Server Setup",
        description = "Install central SCADA server for data collection and control",
        files = {
            {src = "scada_server.lua", dst = "scada_server.lua", startup = true},
        },
        requirements = {
            "Wireless modem (any side)",
            "Central computer for SCADA network",
            "Start this component first"
        }
    },
    
    ["control"] = {
        name = "Control Station Setup", 
        description = "Install operator interface with monitor and touch controls",
        files = {
            {src = "scada_gui.lua", dst = "scada_gui.lua", startup = false},
            {src = "scada_hmi.lua", dst = "scada_hmi.lua", startup = true},
        },
        requirements = {
            "Monitor (any side)",
            "Wireless modem (any side)", 
            "Advanced Computer recommended for touch controls"
        }
    },
    
    ["monitor"] = {
        name = "Monitor Station Setup",
        description = "Install auto-detecting RTU for monitoring Mekanism equipment",
        files = {
            {src = "universal_rtu.lua", dst = "universal_rtu.lua", startup = true},
        },
        requirements = {
            "Cable modem connected to Mekanism devices",
            "Wireless modem for SCADA communication",
            "Automatically detects equipment type"
        }
    },

    ["gui"] = {
        name = "GUI Components",
        description = "Graphical user interface library and installer",
        files = {
            {src = "scada_gui.lua", dst = "scada_gui.lua", startup = false},
            {src = "scada_installer_gui_fixed.lua", dst = "scada_installer_gui_fixed.lua", startup = false},
            {src = "configurator_compact.lua", dst = "configurator_compact.lua", startup = false},
            {src = "installer_gui_auto.lua", dst = "installer_gui.lua", startup = false},
        },
        requirements = {
            "Advanced Computer required",
            "Monitor recommended for best experience",
            "Optimized for ComputerCraft screen dimensions (51x19)"
        }
    },

    ["configure"] = {
        name = "Configuration Wizard",
        description = "Interactive setup wizard for SCADA components",
        files = {
            {src = "configurator_compact.lua", dst = "configurator.lua", startup = false},
        },
        requirements = {
            "Run this first to configure your SCADA system",
            "Detects hardware and sets up component configuration",
            "Optimized for ComputerCraft screen dimensions"
        }
    },
    
    ["hmi"] = {
        name = "HMI Client", 
        description = "Human Machine Interface for operator control",
        files = {
            {src = "scada_hmi.lua", dst = "scada_hmi.lua", startup = true},
        },
        requirements = {
            "Monitor (auto-detected or configured)",
            "Wireless Modem (auto-detected)",
            "Run 'configurator' first for custom setup"
        }
    },
    
    ["rtu"] = {
        name = "Universal RTU/PLC",
        description = "Auto-detecting RTU for any Mekanism system",
        files = {
            {src = "universal_rtu.lua", dst = "universal_rtu.lua", startup = true},
        },
        requirements = {
            "Wireless Modem (auto-detected)",
            "Cable Modem (auto-detected) connected to Mekanism devices",
            "Automatically detects: Reactor, Energy, Fuel, or Laser systems",
            "Run 'configurator' first for custom setup"
        }
    },
    
    ["reactor"] = {
        name = "Reactor RTU/PLC",
        description = "Dedicated fusion reactor control unit",
        files = {
            {src = "fusion_reactor_mon.lua", dst = "reactor_rtu.lua", startup = true},
        },
        requirements = {
            "Cable Modem connected to reactor",
            "Wireless Modem for SCADA communication",
            "Direct connection to Mekanism Fusion Reactor",
            "Use 'rtu' component for auto-detecting alternative"
        }
    },
    
    ["energy"] = {
        name = "Energy RTU/PLC", 
        description = "Dedicated energy storage monitoring unit",
        files = {
            {src = "energy_storage.lua", dst = "energy_rtu.lua", startup = true},
        },
        requirements = {
            "Cable Modem connected to energy storage",
            "Wireless Modem for SCADA communication",
            "Connection to Mekanism Energy Storage",
            "Use 'rtu' component for auto-detecting alternative"
        }
    },
    
    ["fuel"] = {
        name = "Fuel RTU/PLC",
        description = "Dedicated fuel system monitoring unit", 
        files = {
            {src = "fuel_control.lua", dst = "fuel_rtu.lua", startup = true},
        },
        requirements = {
            "Cable Modem connected to fuel systems",
            "Wireless Modem for SCADA communication",
            "Connection to Mekanism Dynamic Tanks",
            "Use 'rtu' component for auto-detecting alternative"
        }
    },
    
    ["laser"] = {
        name = "Laser RTU/PLC",
        description = "Dedicated fusion laser control unit",
        files = {
            {src = "laser_control.lua", dst = "laser_rtu.lua", startup = true},
        },
        requirements = {
            "Cable Modem connected to laser systems", 
            "Wireless Modem for SCADA communication",
            "Connection to Mekanism Fusion Lasers",
            "Use 'rtu' component for auto-detecting alternative"
        }
    },
    
    ["historian"] = {
        name = "Data Historian",
        description = "Historical data storage and trending",
        files = {
            {src = "scada_historian.lua", dst = "historian.lua", startup = true},
        },
        requirements = {
            "Wireless Modem (back side)",
            "Adequate storage space for historical data",
            "Optional: Advanced Computer for better performance"
        }
    },
    
    ["all"] = {
        name = "Complete SCADA System",
        description = "Install all components (for testing/development)",
        files = {
            {src = "installer_fixed.lua", dst = "installer_fixed.lua"},
            {src = "scada_gui.lua", dst = "scada_gui.lua"},
            {src = "scada_installer_gui_fixed.lua", dst = "scada_installer_gui_fixed.lua"},
            {src = "configurator_compact.lua", dst = "configurator_compact.lua"},
            {src = "scada_server.lua", dst = "scada_server.lua"},
            {src = "scada_hmi.lua", dst = "scada_hmi.lua"},
            {src = "universal_rtu.lua", dst = "universal_rtu.lua"},
            {src = "fusion_reactor_mon.lua", dst = "reactor_rtu.lua"},
            {src = "energy_storage.lua", dst = "energy_rtu.lua"},
            {src = "fuel_control.lua", dst = "fuel_rtu.lua"},
            {src = "laser_control.lua", dst = "laser_rtu.lua"},
            {src = "scada_historian.lua", dst = "historian.lua"},
        },
        requirements = {
            "This installs ALL components - only use for development/testing",
            "Typically you would run different components on separate computers"
        }
    }
}

local Installer = {
    component = nil,
    install_path = INSTALL_DIR,
    backup_path = BACKUP_DIR,
    log_file = INSTALL_DIR .. "install.log"
}

function Installer:log(message)
    print(message)
    
    -- Ensure install directory exists
    if not fs.exists(INSTALL_DIR) then
        fs.makeDir(INSTALL_DIR)
    end
    
    local file = fs.open(self.log_file, "a")
    if file then
        file.writeLine(os.date("[%Y-%m-%d %H:%M:%S] ") .. message)
        file.close()
    end
end

function Installer:downloadFile(url, destination)
    self:log("Downloading: " .. url)
    
    -- Ensure destination is in install directory unless it's a temp file
    if not destination:match("^" .. INSTALL_DIR) and not destination:match("^temp_") then
        destination = INSTALL_DIR .. destination
    end
    
    -- Ensure install directory exists
    if not fs.exists(INSTALL_DIR) then
        fs.makeDir(INSTALL_DIR)
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
    
    -- Check if content looks like Lua code
    if not content:match("^%s*%-%-") and not content:match("^%s*local") and not content:match("^%s*function") then
        error("Downloaded content doesn't appear to be a Lua file: " .. url)
    end
    
    local file = fs.open(destination, "w")
    if not file then
        error("Failed to create file: " .. destination)
    end
    
    file.write(content)
    file.close()
    
    self:log("Downloaded: " .. destination .. " (" .. #content .. " bytes)")
    return true
end

function Installer:backupExistingFiles(component_config)
    if not fs.exists(self.backup_path) then
        fs.makeDir(self.backup_path)
    end
    
    local backup_timestamp = os.date("%Y%m%d_%H%M%S")
    local backup_dir = self.backup_path .. backup_timestamp .. "/"
    fs.makeDir(backup_dir)
    
    for _, file_config in ipairs(component_config.files) do
        local dst_path = self.install_path .. file_config.dst
        if fs.exists(dst_path) then
            local backup_path = backup_dir .. file_config.dst
            fs.copy(dst_path, backup_path)
            self:log("Backed up: " .. dst_path .. " -> " .. backup_path)
        end
    end
    
    return backup_dir
end

function Installer:installComponent(component_name)
    local component_config = COMPONENTS[component_name]
    if not component_config then
        error("Unknown component: " .. component_name)
    end
    
    self:log("=== Installing " .. component_config.name .. " ===")
    self:log("Description: " .. component_config.description)
    
    -- Show requirements
    self:log("Requirements:")
    for _, req in ipairs(component_config.requirements) do
        self:log("  - " .. req)
    end
    
    print()
    
    -- Special handling for configuration component
    if component_name == "configure" then
        print("This will install the configuration wizard.")
        print("Run 'configurator' after installation to setup your SCADA system.")
        print("Continue with installation? (Y/n)")
        local input = read()
        if input:lower() == "n" or input:lower() == "no" then
            self:log("Installation cancelled by user")
            return false
        end
    else
        print("TIP: Run 'installer configure' first to setup custom configuration")
        print("Continue with installation? (y/N)")
        local input = read()
        if input:lower() ~= "y" and input:lower() ~= "yes" then
            self:log("Installation cancelled by user")
            return false
        end
    end
    
    -- Backup existing files
    local backup_dir = self:backupExistingFiles(component_config)
    self:log("Backup created in: " .. backup_dir)
    
    -- Download and install files
    local success_count = 0
    for _, file_config in ipairs(component_config.files) do
        local url = BASE_URL .. file_config.src
        local dst_path = self.install_path .. file_config.dst
        
        local success, error = pcall(self.downloadFile, self, url, dst_path)
        if success then
            success_count = success_count + 1
            
            -- Set up startup script if specified
            if file_config.startup and component_name ~= "all" then
                self:createStartupScript(file_config.dst, component_config.name)
            end
        else
            self:log("ERROR: " .. error)
            return false
        end
    end
    
    self:log("Successfully installed " .. success_count .. " files")
    
    -- Installation complete
    self:log("=== Installation Complete ===")
    self:log("Component: " .. component_config.name)
    self:log("Files installed: " .. success_count)
    
    if component_name ~= "all" then
        self:log("To start the service, run: " .. component_config.files[1].dst)
        self:log("Or reboot the computer to auto-start")
    else
        self:log("All components installed. Start individual services as needed.")
    end
    
    return true
end

function Installer:createStartupScript(main_file, component_name)
    local full_path = INSTALL_DIR .. main_file
    local startup_content = string.format([[
-- Auto-generated startup script for %s
-- Generated by SCADA Installer
-- SCADA Directory: %s

print("Starting %s...")
print("Main file: %s")

-- Check if main file exists
if not fs.exists("%s") then
    print("ERROR: Main file not found: %s")
    print("Installation directory: %s")
    print("Run 'scada_status' to check installation")
    print("Press any key to open shell...")
    os.pullEvent("key")
    shell.run("shell")
    return
end

-- Add SCADA directory to path
if shell then
    local scada_path = "%s"
    local current_path = shell.path()
    if not current_path:find(scada_path) then
        shell.setPath(current_path .. ":" .. scada_path)
    end
end

-- Load and run the main program
local success, error = pcall(dofile, "%s")
if not success then
    print("ERROR starting %s:")
    print(error)
    print("")
    print("Check installation with: scada_status")
    print("Uninstall with: scada_uninstall")
    print("Press any key to open shell...")
    os.pullEvent("key")
    shell.run("shell")
end
]], component_name, INSTALL_DIR, component_name, full_path, full_path, full_path, INSTALL_DIR, INSTALL_DIR, full_path, component_name)

    local file = fs.open("startup.lua", "w")
    if file then
        file.write(startup_content)
        file.close()
        self:log("Created startup script for " .. component_name)
    else
        self:log("WARNING: Failed to create startup script")
    end
    
    -- Create management scripts
    self:createManagementScripts()
end

function Installer:createManagementScripts()
    -- Create uninstall script
    local uninstall_script = string.format([[
-- SCADA Uninstaller
print("SCADA System Uninstaller")
print("========================")
print("This will remove all SCADA components from: %s")
print()

if fs.exists("%s") then
    local config_success, config = pcall(dofile, "%s")
    if config_success and config and config.install_info then
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
        local backup_path = "%s" .. os.date("%%Y%%m%%d_%%H%%M%%S") .. "/"
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
    if fs.exists("scada_status") then fs.delete("scada_status") end
    
    print("[+] SCADA system uninstalled successfully!")
    print("To reinstall, run: installer")
else
    print("Uninstall cancelled.")
end
]], INSTALL_DIR, CONFIG_FILE, CONFIG_FILE, INSTALL_DIR, BACKUP_DIR, INSTALL_DIR, INSTALL_DIR, INSTALL_DIR, INSTALL_DIR, INSTALL_DIR, INSTALL_DIR)

    local file = fs.open("scada_uninstall", "w")
    if file then
        file.write(uninstall_script)
        file.close()
    end
    
    -- Create status script
    local status_script = string.format([[
-- SCADA Status Check
print("SCADA System Status")
print("===================")

if fs.exists("%s") then
    print("Installation directory: %s")
    print("Configuration: Found")
    
    local config_success, config = pcall(dofile, "%s")
    if config_success and config then
        if config.install_info then
            print("Role: " .. (config.install_info.role or "unknown"))
            print("Install date: " .. (config.install_info.install_date or "unknown"))
            print("Files: " .. #(config.install_info.installed_files or {}))
        end
        
        if config.network then
            print("Base channel: " .. (config.network.channels.reactor or "100"))
        end
    else
        print("Configuration: Error reading config file")
    end
    
    print()
    print("Files in " .. "%s" .. ":")
    for _, file in pairs(fs.list("%s")) do
        print("  " .. file .. " (" .. fs.getSize("%s" .. file) .. " bytes)")
    end
    
    print()
    print("Management commands:")
    print("  scada_uninstall - Remove SCADA system")
    print("  scada_status - Show this status")
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

function Installer:showMenu()
    print("=== MEKANISM FUSION REACTOR SCADA INSTALLER ===")
    print("Repository: " .. GITHUB_REPO)
    print("")
    print("Available Components:")
    print("")
    
    local sorted_components = {}
    for name, config in pairs(COMPONENTS) do
        table.insert(sorted_components, {name = name, config = config})
    end
    
    -- Sort by name, but put 'all' at the end
    table.sort(sorted_components, function(a, b)
        if a.name == "all" then return false end
        if b.name == "all" then return true end
        return a.name < b.name
    end)
    
    for _, comp in ipairs(sorted_components) do
        print(string.format("  %-12s - %s", comp.name, comp.config.name))
        print(string.format("               %s", comp.config.description))
        print("")
    end
    
    print("Usage: installer <component>")
    print("Example: installer server")
    print("")
end

function Installer:checkHttpApi()
    if not http then
        error("HTTP API is disabled. Enable it in ComputerCraft config.")
    end
    
    -- Test internet connectivity
    local test_response = http.get("https://httpbin.org/get")
    if not test_response then
        error("No internet connection available")
    end
    test_response.close()
    
    self:log("HTTP API and internet connectivity confirmed")
end

function Installer:checkDiskSpace()
    local free_space = fs.getFreeSpace("/")
    if free_space < 10000 then -- Less than ~10KB
        error("Insufficient disk space. Need at least 10KB free.")
    end
    
    self:log("Disk space check passed: " .. free_space .. " bytes free")
end

function Installer:run(args)
    -- Initialize log
    self:log("=== SCADA Installer Started ===")
    self:log("Repository: " .. GITHUB_REPO)
    
    -- Pre-flight checks
    self:checkHttpApi()
    self:checkDiskSpace()
    
    -- Parse arguments
    if #args == 0 then
        -- No arguments - try simple installer first
        if self:trySimpleInstaller() then
            return true
        end
        -- Fall back to menu
        self:showMenu()
        return
    end
    
    self.component = args[1]:lower()
    
    -- Handle special commands
    if self.component == "help" or self.component == "--help" or self.component == "-h" then
        self:showMenu()
        return
    end
    
    if self.component == "list" then
        self:showMenu()
        return
    end
    
    if self.component == "simple" or self.component == "easy" or self.component == "quick" then
        return self:runSimpleInstaller()
    end
    
    if self.component == "gui" then
        -- Install GUI then launch graphical installer
        local success = self:installComponent("gui")
        if success then
            print("GUI installed! Launching graphical installer...")
            sleep(1)
            if fs.exists("installer_gui.lua") then
                dofile("installer_gui.lua")
            end
        end
        return success
    end
    
    -- Install component
    local success, error = pcall(self.installComponent, self, self.component)
    if not success then
        self:log("INSTALLATION FAILED: " .. error)
        print("")
        print("Installation failed. Check install.log for details.")
        return false
    end
    
    return true
end

function Installer:trySimpleInstaller()
    -- Check if we should use simple installer
    local w, h = term.getSize()
    
    -- Offer simple installer for better UX
    print("=== MEKANISM FUSION REACTOR SCADA INSTALLER ===")
    print("")
    print("Choose installation method:")
    print("  1. [*] Quick Setup (Recommended) - Automatic configuration")
    print("  2. [A] Advanced Setup - Manual component selection")
    print("  3. [G] Graphical Installer - GUI interface")
    print("")
    print("Enter choice (1-3) or ENTER for Quick Setup: ")
    
    local input = read()
    
    if input == "" or input == "1" then
        return self:runSimpleInstaller()
    elseif input == "2" then
        return false  -- Use advanced menu
    elseif input == "3" then
        -- Try to install and run GUI
        print("Installing GUI components...")
        if self:installComponent("gui") then
            if fs.exists("installer_gui.lua") then
                dofile("installer_gui.lua")
                return true
            end
        end
        print("GUI installation failed, falling back to menu...")
        return false
    else
        print("Invalid choice, using advanced menu...")
        return false
    end
end

function Installer:runSimpleInstaller()
    -- Download and run the fixed simple installer
    local url = BASE_URL .. "installer_fixed.lua"
    local temp_file = "temp_simple_installer.lua"
    
    local success, error = pcall(self.downloadFile, self, url, temp_file)
    if success then
        dofile(temp_file)
        fs.delete(temp_file)
        return true
    else
        self:log("Failed to download simple installer: " .. error)
        print("Simple installer unavailable, using advanced menu...")
        return false
    end
end

-- Main execution
local args = {...}

-- Error handling wrapper
local function safeRun()
    local success, error = pcall(Installer.run, Installer, args)
    if not success then
        print("INSTALLER ERROR: " .. error)
        print("Check install.log for details")
        return false
    end
    return true
end

safeRun()