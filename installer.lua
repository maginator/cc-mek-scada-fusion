-- SCADA System Installer for ComputerCraft
-- Downloads and installs SCADA components from GitHub repository
-- Usage: pastebin get <pastebin-id> installer && installer <component>

local GITHUB_REPO = "maginator/cc-mek-scada-fusion"
local GITHUB_BRANCH = "main"
local BASE_URL = "https://raw.githubusercontent.com/" .. GITHUB_REPO .. "/" .. GITHUB_BRANCH .. "/"

local COMPONENTS = {
    ["configure"] = {
        name = "Configuration Wizard",
        description = "Interactive setup wizard for SCADA components",
        files = {
            {src = "configurator.lua", dst = "configurator.lua", startup = false},
        },
        requirements = {
            "Run this first to configure your SCADA system",
            "Detects hardware and sets up component configuration"
        }
    },

    ["server"] = {
        name = "SCADA Server",
        description = "Central data acquisition and control server",
        files = {
            {src = "scada_server.lua", dst = "scada_server.lua", startup = true},
        },
        requirements = {
            "Wireless Modem (auto-detected or configured)",
            "Computer with adequate storage",
            "Run 'configurator' first for custom setup"
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
            {src = "configurator.lua", dst = "configurator.lua"},
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
    install_path = "/",
    backup_path = "/backup/",
    log_file = "/install.log"
}

function Installer:log(message)
    print(message)
    
    local file = fs.open(self.log_file, "a")
    if file then
        file.writeLine(os.date("[%Y-%m-%d %H:%M:%S] ") .. message)
        file.close()
    end
end

function Installer:downloadFile(url, destination)
    self:log("Downloading: " .. url)
    
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
    local startup_content = string.format([[
-- Auto-generated startup script for %s
-- Generated by SCADA Installer

print("Starting %s...")
print("Main file: %s")

-- Check if main file exists
if not fs.exists("%s") then
    print("ERROR: Main file not found: %s")
    print("Please reinstall the component")
    return
end

-- Load and run the main program
local success, error = pcall(dofile, "%s")
if not success then
    print("ERROR starting %s:")
    print(error)
    print("")
    print("Press any key to open shell...")
    os.pullEvent("key")
    shell.run("shell")
end
]], component_name, component_name, main_file, main_file, main_file, main_file, component_name)

    local file = fs.open(self.install_path .. "startup.lua", "w")
    if file then
        file.write(startup_content)
        file.close()
        self:log("Created startup script for " .. component_name)
    else
        self:log("WARNING: Failed to create startup script")
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
        self:showMenu()
        return
    end
    
    self.component = args[1]:lower()
    
    if self.component == "help" or self.component == "--help" or self.component == "-h" then
        self:showMenu()
        return
    end
    
    if self.component == "list" then
        self:showMenu()
        return
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