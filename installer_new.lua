-- SCADA Universal Installer
-- Automatically detects computer capabilities and launches appropriate interface

local GITHUB_REPO = "maginator/cc-mek-scada-fusion"
local GITHUB_BRANCH = "main" 
local BASE_URL = "https://raw.githubusercontent.com/" .. GITHUB_REPO .. "/" .. GITHUB_BRANCH .. "/"

local Installer = {
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

function Installer:checkRequirements()
    -- Check HTTP API
    if not http then
        error("HTTP API is disabled. Enable it in ComputerCraft config and restart.")
    end
    
    -- Test internet connectivity
    local test_response = http.get("https://httpbin.org/get")
    if not test_response then
        error("No internet connection available")
    end
    test_response.close()
    
    -- Check disk space
    local free_space = fs.getFreeSpace("/")
    if free_space < 50000 then -- Less than ~50KB
        error("Insufficient disk space. Need at least 50KB free.")
    end
    
    self:log("System requirements check passed")
    return true
end

function Installer:detectCapabilities()
    local capabilities = {
        advanced_computer = term.isColor(),
        has_monitor = peripheral.find("monitor") ~= nil,
        has_mouse = term.isColor(), -- Advanced computers support mouse
        screen_size = {term.getSize()}
    }
    
    self:log("Computer capabilities:")
    self:log("  Advanced Computer: " .. (capabilities.advanced_computer and "Yes" or "No"))
    self:log("  External Monitor: " .. (capabilities.has_monitor and "Yes" or "No"))  
    self:log("  Mouse Support: " .. (capabilities.has_mouse and "Yes" or "No"))
    self:log("  Screen Size: " .. capabilities.screen_size[1] .. "x" .. capabilities.screen_size[2])
    
    return capabilities
end

function Installer:downloadGUIComponents()
    self:log("Downloading GUI components...")
    
    local gui_files = {
        {src = "scada_gui.lua", dst = "scada_gui.lua"},
        {src = "scada_installer_gui.lua", dst = "scada_installer_gui.lua"}
    }
    
    for _, file in ipairs(gui_files) do
        local url = BASE_URL .. file.src
        local response = http.get(url)
        
        if response then
            local content = response.readAll()
            response.close()
            
            local local_file = fs.open(file.dst, "w")
            if local_file then
                local_file.write(content)
                local_file.close()
                self:log("Downloaded: " .. file.dst)
            else
                error("Failed to save: " .. file.dst)
            end
        else
            error("Failed to download: " .. url)
        end
    end
    
    return true
end

function Installer:launchGUIInstaller()
    self:log("Launching graphical installer...")
    
    -- Check if GUI files exist, download if needed
    if not fs.exists("scada_gui.lua") or not fs.exists("scada_installer_gui.lua") then
        self:downloadGUIComponents()
    end
    
    -- Launch GUI installer
    local success, error = pcall(dofile, "scada_installer_gui.lua")
    
    if not success then
        self:log("GUI installer failed: " .. tostring(error))
        self:log("Falling back to command line installer...")
        return false
    end
    
    return true
end

function Installer:showWelcome()
    term.clear()
    term.setCursorPos(1, 1)
    
    print("╔══════════════════════════════════════════════════════╗")
    print("║               SCADA SYSTEM INSTALLER                ║")
    print("║          Mekanism Fusion Reactor Control            ║")
    print("╚══════════════════════════════════════════════════════╝")
    print()
    print("Repository: " .. GITHUB_REPO)
    print("Detecting system capabilities...")
    print()
end

function Installer:showCapabilityDetection(capabilities)
    print("System Detection Results:")
    print("========================")
    
    if capabilities.advanced_computer then
        print("✓ Advanced Computer - Full GUI support available")
    else
        print("• Standard Computer - Text-based interface")
    end
    
    if capabilities.has_monitor then
        print("✓ External Monitor - Enhanced display available")
    else
        print("• Using built-in display")
    end
    
    if capabilities.has_mouse then
        print("✓ Mouse/Touch Support - Interactive controls enabled")
    else
        print("• Keyboard-only interface")
    end
    
    print()
    print("Screen: " .. capabilities.screen_size[1] .. "x" .. capabilities.screen_size[2] .. " characters")
    print()
end

function Installer:promptInterface(capabilities)
    if capabilities.advanced_computer then
        print("Interface Options:")
        print("==================")
        print("1. Graphical Interface (Recommended)")
        print("   • Modern GUI with mouse/touch support")
        print("   • Visual component selection")
        print("   • Integrated configuration wizard")
        print("   • Real-time installation progress")
        print()
        print("2. Command Line Interface")
        print("   • Traditional text-based installer")
        print("   • Keyboard navigation")
        print("   • Faster for experienced users")
        print()
        
        while true do
            write("Select interface (1=GUI, 2=CLI, Enter=GUI): ")
            local choice = read()
            
            if choice == "" or choice == "1" then
                return "gui"
            elseif choice == "2" then
                return "cli"
            else
                print("Invalid choice. Please enter 1 or 2.")
            end
        end
    else
        print("Using command line interface (Advanced Computer required for GUI)")
        print("Press Enter to continue...")
        read()
        return "cli"
    end
end

function Installer:launchCLIInstaller()
    self:log("Launching command line installer...")
    
    -- Download CLI installer if not present
    if not fs.exists("installer.lua") then
        self:log("Downloading command line installer...")
        local url = BASE_URL .. "installer.lua"
        local response = http.get(url)
        
        if response then
            local content = response.readAll()
            response.close()
            
            local file = fs.open("installer.lua", "w")
            if file then
                file.write(content)
                file.close()
                self:log("Downloaded installer.lua")
            end
        else
            error("Failed to download command line installer")
        end
    end
    
    -- Launch CLI installer
    shell.run("installer.lua")
end

function Installer:run()
    self:showWelcome()
    
    -- Check system requirements
    local success, error = pcall(self.checkRequirements, self)
    if not success then
        print("❌ " .. error)
        print("\nInstallation cannot continue.")
        return false
    end
    
    -- Detect capabilities
    local capabilities = self:detectCapabilities()
    self:showCapabilityDetection(capabilities)
    
    -- Prompt for interface choice
    local interface_choice = self:promptInterface(capabilities)
    
    print()
    self:log("User selected interface: " .. interface_choice)
    
    if interface_choice == "gui" then
        local gui_success = self:launchGUIInstaller()
        if not gui_success then
            print("\nGUI installer failed, launching command line installer...")
            self:launchCLIInstaller()
        end
    else
        self:launchCLIInstaller()
    end
    
    return true
end

-- Usage information
function Installer:showUsage()
    print("SCADA Universal Installer")
    print("========================")
    print()
    print("Usage:")
    print("  installer                    - Interactive installer with interface detection")
    print("  installer gui               - Force graphical interface")
    print("  installer cli               - Force command line interface")
    print("  installer help              - Show this help")
    print()
    print("Components available:")
    print("  server      - SCADA Server (central control)")
    print("  hmi         - HMI Client (operator interface)")
    print("  rtu         - Universal RTU (auto-detecting)")
    print("  historian   - Data Historian (logging)")
    print("  configure   - Configuration Wizard")
    print()
    print("Examples:")
    print("  installer               # Interactive installation")
    print("  installer gui           # Force GUI mode")
    print("  installer cli server    # CLI install SCADA server")
end

-- Main execution
local args = {...}

-- Error handling wrapper
local function safeRun()
    local success, error = pcall(function()
        if #args == 0 then
            -- Interactive mode
            return Installer:run()
        elseif args[1] == "gui" then
            -- Force GUI mode
            local capabilities = Installer:detectCapabilities()
            if capabilities.advanced_computer then
                Installer:checkRequirements()
                Installer:launchGUIInstaller()
            else
                print("Advanced Computer required for GUI mode")
                print("Use 'installer cli' for command line installation")
            end
        elseif args[1] == "cli" then
            -- Force CLI mode or pass arguments to CLI installer
            Installer:checkRequirements()
            if #args > 1 then
                -- Pass remaining arguments to CLI installer
                local cli_args = {}
                for i = 2, #args do
                    table.insert(cli_args, args[i])
                end
                -- Download and run CLI installer with arguments
                shell.run("installer.lua", table.unpack(cli_args))
            else
                Installer:launchCLIInstaller()
            end
        elseif args[1] == "help" or args[1] == "--help" or args[1] == "-h" then
            Installer:showUsage()
        else
            -- Direct component installation via CLI
            Installer:checkRequirements()
            shell.run("installer.lua", table.unpack(args))
        end
    end)
    
    if not success then
        print("INSTALLER ERROR: " .. error)
        print("\nFor help, run: installer help")
        return false
    end
    
    return true
end

-- Check if GUI library is available for advanced computers
if term.isColor() and peripheral.find("monitor") then
    print("🖥️  Advanced Computer with Monitor detected")
    print("🖱️  Enhanced GUI experience available")
    print()
end

safeRun()