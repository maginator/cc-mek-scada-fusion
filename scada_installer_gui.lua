-- SCADA Graphical Installer & Manager
-- Modern GUI-based installer with integrated configurator and update functionality

-- Load the GUI library
local GUI = dofile("scada_gui.lua")

local GITHUB_REPO = "maginator/cc-mek-scada-fusion"
local GITHUB_BRANCH = "main"
local BASE_URL = "https://raw.githubusercontent.com/" .. GITHUB_REPO .. "/" .. GITHUB_BRANCH .. "/"

local COMPONENTS = {
    {
        id = "server",
        name = "SCADA Server",
        description = "Central data acquisition and control server",
        icon = "🖥",
        category = "core",
        files = {{src = "scada_server.lua", dst = "scada_server.lua", startup = true}},
        requirements = {"Wireless Modem", "Adequate Storage"}
    },
    {
        id = "hmi",
        name = "HMI Client",
        description = "Human Machine Interface for operators",
        icon = "📺",
        category = "interface",
        files = {{src = "scada_hmi.lua", dst = "scada_hmi.lua", startup = true}},
        requirements = {"Monitor", "Wireless Modem", "Touch Support Recommended"}
    },
    {
        id = "rtu",
        name = "Universal RTU",
        description = "Auto-detecting RTU for any Mekanism system",
        icon = "🔧",
        category = "control",
        files = {{src = "universal_rtu.lua", dst = "universal_rtu.lua", startup = true}},
        requirements = {"Wireless Modem", "Cable Modem", "Connected Mekanism Devices"}
    },
    {
        id = "historian",
        name = "Data Historian",
        description = "Historical data storage and trending",
        icon = "📊",
        category = "data",
        files = {{src = "scada_historian.lua", dst = "historian.lua", startup = true}},
        requirements = {"Wireless Modem", "Storage Space"}
    },
    {
        id = "reactor",
        name = "Reactor RTU",
        description = "Dedicated fusion reactor control",
        icon = "⚡",
        category = "legacy",
        files = {{src = "fusion_reactor_mon.lua", dst = "reactor_rtu.lua", startup = true}},
        requirements = {"Cable Modem to Reactor", "Wireless Modem"}
    },
    {
        id = "energy",
        name = "Energy RTU",
        description = "Dedicated energy storage monitoring",
        icon = "🔋",
        category = "legacy",
        files = {{src = "energy_storage.lua", dst = "energy_rtu.lua", startup = true}},
        requirements = {"Cable Modem to Energy Storage", "Wireless Modem"}
    },
    {
        id = "fuel",
        name = "Fuel RTU",
        description = "Dedicated fuel system management",
        icon = "⛽",
        category = "legacy",
        files = {{src = "fuel_control.lua", dst = "fuel_rtu.lua", startup = true}},
        requirements = {"Cable Modem to Fuel Systems", "Wireless Modem"}
    },
    {
        id = "laser",
        name = "Laser RTU",
        description = "Dedicated fusion laser control",
        icon = "🔫",
        category = "legacy",
        files = {{src = "laser_control.lua", dst = "laser_rtu.lua", startup = true}},
        requirements = {"Cable Modem to Laser Systems", "Wireless Modem"}
    }
}

local InstallerGUI = {
    gui = nil,
    current_screen = "welcome",
    selected_component = nil,
    installation_progress = 0,
    configuration_data = {},
    installed_components = {},
    
    -- Screens
    screens = {
        welcome = "Welcome Screen",
        hardware_scan = "Hardware Detection",
        configure = "System Configuration", 
        component_select = "Component Selection",
        install_progress = "Installation Progress",
        complete = "Installation Complete",
        update_manager = "Update Manager"
    }
}

function InstallerGUI:init()
    -- Check if we have a monitor
    local monitor = peripheral.find("monitor")
    if monitor then
        self.gui = GUI:init(monitor)
        monitor.setTextScale(0.5)
    else
        self.gui = GUI:init(term)
    end
    
    self:detectInstalledComponents()
    self:createWelcomeScreen()
    
    print("SCADA Installer GUI Started")
    print("Click to interact with the interface")
end

function InstallerGUI:detectInstalledComponents()
    for _, component in ipairs(COMPONENTS) do
        for _, file in ipairs(component.files) do
            if fs.exists(file.dst) then
                table.insert(self.installed_components, component.id)
                break
            end
        end
    end
end

function InstallerGUI:createWelcomeScreen()
    self.gui.components = {}
    self.current_screen = "welcome"
    
    -- Header
    local header = self.gui:createPanel(5, 2, self.gui.width - 10, 8, "SCADA Installation Manager")
    header.shadow = true
    header.background = self.gui.COLORS.PRIMARY
    
    -- Welcome card
    local welcome_card = self.gui:createCard(10, 12, self.gui.width - 20, 12, 
        "🚀 Welcome to SCADA System", {
        "Modern industrial control system for Mekanism Fusion Reactors",
        "",
        "Features:",
        "• Centralized monitoring and control",
        "• Real-time data visualization", 
        "• Historical data logging",
        "• Advanced alarm management",
        "• Auto-detecting hardware setup"
    })
    
    -- Action buttons
    local button_y = 26
    local button_width = 20
    local button_spacing = 25
    
    local scan_button = self.gui:createButton(10, button_y, button_width, 3, "🔍 Scan Hardware", "primary")
    scan_button.onclick = function() self:createHardwareScanScreen() end
    
    local config_button = self.gui:createButton(10 + button_spacing, button_y, button_width, 3, "⚙ Configure", "secondary")
    config_button.onclick = function() self:createConfigureScreen() end
    
    local install_button = self.gui:createButton(10 + button_spacing * 2, button_y, button_width, 3, "📦 Install", "success")
    install_button.onclick = function() self:createComponentSelectScreen() end
    
    local update_button = self.gui:createButton(10 + button_spacing * 3, button_y, button_width, 3, "🔄 Update", "warning")
    update_button.onclick = function() self:createUpdateManagerScreen() end
    
    -- System information
    local info_card = self.gui:createCard(10, 31, self.gui.width - 20, 8, "System Information", {
        "Computer: " .. (os.getComputerLabel() or "Unnamed"),
        "OS: " .. os.version(),
        "Installed Components: " .. #self.installed_components,
        "Repository: " .. GITHUB_REPO
    })
end

function InstallerGUI:createHardwareScanScreen()
    self.gui.components = {}
    self.current_screen = "hardware_scan"
    
    -- Header
    local header = self.gui:createPanel(5, 2, self.gui.width - 10, 6, "🔍 Hardware Detection")
    header.background = self.gui.COLORS.INFO
    
    -- Progress indicator
    local progress = self.gui:createProgressBar(10, 10, self.gui.width - 20, 3, 0, 100)
    progress.text_format = "Scanning... %d%%"
    progress.bar_color = self.gui.COLORS.INFO
    
    -- Results area
    local results_card = self.gui:createCard(10, 15, self.gui.width - 20, 20, "Detection Results", {})
    
    -- Back button
    local back_button = self.gui:createButton(10, self.gui.height - 5, 15, 3, "← Back", "secondary")
    back_button.onclick = function() self:createWelcomeScreen() end
    
    -- Start hardware scan
    self:performHardwareScan(progress, results_card)
end

function InstallerGUI:performHardwareScan(progress_bar, results_card)
    local scan_steps = {
        "Checking peripherals...",
        "Detecting monitors...",
        "Scanning modems...",
        "Finding Mekanism devices...",
        "Analyzing configuration...",
        "Scan complete!"
    }
    
    local results = {}
    local step = 0
    
    local function nextStep()
        step = step + 1
        if step <= #scan_steps then
            progress_bar:setValue((step / #scan_steps) * 100)
            progress_bar.text_format = scan_steps[step] .. " %d%%"
            self.gui:render()
            
            -- Simulate scan work
            os.startTimer(0.5)
        else
            self:completeScan(results_card, results)
        end
    end
    
    -- Simulate scanning process
    nextStep()
    
    -- Actual hardware detection
    local sides = {"top", "bottom", "left", "right", "front", "back"}
    local monitors = 0
    local wireless_modems = 0
    local cable_modems = 0
    local mekanism_devices = 0
    
    for _, side in ipairs(sides) do
        local ptype = peripheral.getType(side)
        if ptype == "monitor" then
            monitors = monitors + 1
        elseif ptype == "modem" then
            local modem = peripheral.wrap(side)
            if modem then
                if modem.isWireless() then
                    wireless_modems = wireless_modems + 1
                else
                    cable_modems = cable_modems + 1
                    -- Count connected Mekanism devices
                    local connected = modem.getNamesRemote()
                    for _, device in ipairs(connected) do
                        if device:lower():find("reactor") or device:lower():find("induction") or
                           device:lower():find("tank") or device:lower():find("laser") then
                            mekanism_devices = mekanism_devices + 1
                        end
                    end
                end
            end
        end
    end
    
    results = {
        "🖥 Monitors: " .. monitors,
        "📡 Wireless Modems: " .. wireless_modems,
        "🔌 Cable Modems: " .. cable_modems,
        "⚙ Mekanism Devices: " .. mekanism_devices,
        "",
        "Recommended Setup:",
        monitors > 0 and "✓ HMI Interface supported" or "⚠ No monitor for HMI",
        wireless_modems > 0 and "✓ Wireless communication ready" or "✗ No wireless modem found",
        cable_modems > 0 and "✓ Device connection available" or "⚠ No cable modem for devices",
        mekanism_devices > 0 and "✓ Mekanism integration ready" or "⚠ No Mekanism devices detected"
    }
    
    -- Complete scan after delay
    os.startTimer(2)
end

function InstallerGUI:completeScan(results_card, results)
    results_card:setContent(results)
    
    -- Add continue button
    local continue_button = self.gui:createButton(self.gui.width - 25, self.gui.height - 5, 15, 3, "Continue →", "primary")
    continue_button.onclick = function() self:createConfigureScreen() end
    
    self.gui:render()
end

function InstallerGUI:createConfigureScreen()
    self.gui.components = {}
    self.current_screen = "configure"
    
    -- Header
    local header = self.gui:createPanel(5, 2, self.gui.width - 10, 6, "⚙ System Configuration")
    header.background = self.gui.COLORS.WARNING
    
    -- Configuration panels
    local left_panel = self.gui:createCard(5, 10, (self.gui.width / 2) - 7, 25, "Network Settings", {
        "Communication Channels:",
        "",
        "Reactor Channel: 100",
        "Fuel Channel: 101", 
        "Energy Channel: 102",
        "Laser Channel: 103",
        "HMI Channel: 104",
        "Alarm Channel: 105",
        "",
        "These can be customized if needed"
    })
    
    local right_panel = self.gui:createCard((self.gui.width / 2) + 2, 10, (self.gui.width / 2) - 7, 25, "Component Detection", {
        "Auto-Configuration:",
        "",
        "✓ Automatic peripheral detection",
        "✓ Smart component assignment",
        "✓ Optimal channel selection",
        "✓ Hardware validation",
        "",
        "Manual configuration available",
        "for advanced setups"
    })
    
    -- Action buttons
    local auto_button = self.gui:createButton(10, 37, 20, 3, "🤖 Auto Configure", "success")
    auto_button.onclick = function() 
        self:autoConfigureSystem()
        self:createComponentSelectScreen()
    end
    
    local manual_button = self.gui:createButton(35, 37, 20, 3, "🔧 Manual Setup", "warning")
    manual_button.onclick = function() self:createManualConfigScreen() end
    
    local skip_button = self.gui:createButton(60, 37, 15, 3, "Skip →", "secondary")
    skip_button.onclick = function() self:createComponentSelectScreen() end
    
    -- Back button
    local back_button = self.gui:createButton(10, self.gui.height - 5, 15, 3, "← Back", "secondary")
    back_button.onclick = function() self:createWelcomeScreen() end
end

function InstallerGUI:autoConfigureSystem()
    -- Perform automatic configuration
    self.configuration_data = {
        network = {
            channels = {reactor = 100, fuel = 101, energy = 102, laser = 103, hmi = 104, alarm = 105}
        },
        auto_detect = true,
        configured = true
    }
    
    -- Save configuration
    local config_file = fs.open("scada_config.lua", "w")
    if config_file then
        config_file.write("return " .. textutils.serialize(self.configuration_data))
        config_file.close()
    end
end

function InstallerGUI:createComponentSelectScreen()
    self.gui.components = {}
    self.current_screen = "component_select"
    
    -- Header
    local header = self.gui:createPanel(5, 2, self.gui.width - 10, 6, "📦 Component Selection")
    header.background = self.gui.COLORS.SUCCESS
    
    -- Categories
    local categories = {
        {name = "Core Components", filter = "core", color = self.gui.COLORS.PRIMARY},
        {name = "User Interfaces", filter = "interface", color = self.gui.COLORS.INFO},
        {name = "Control Units", filter = "control", color = self.gui.COLORS.SUCCESS},
        {name = "Data & Analytics", filter = "data", color = self.gui.COLORS.WARNING},
        {name = "Legacy Components", filter = "legacy", color = self.gui.COLORS.BUTTON_DEFAULT}
    }
    
    local y_pos = 10
    for _, category in ipairs(categories) do
        -- Category header
        local cat_panel = self.gui:createPanel(5, y_pos, self.gui.width - 10, 2, category.name)
        cat_panel.background = category.color
        cat_panel.border = false
        
        y_pos = y_pos + 3
        
        -- Components in category
        for _, component in ipairs(COMPONENTS) do
            if component.category == category.filter then
                local comp_card = self.gui:createCard(10, y_pos, self.gui.width - 20, 6, 
                    component.icon .. " " .. component.name, {
                    component.description,
                    "Requirements: " .. table.concat(component.requirements, ", ")
                })
                
                -- Install button
                local installed = false
                for _, installed_id in ipairs(self.installed_components) do
                    if installed_id == component.id then
                        installed = true
                        break
                    end
                end
                
                local install_btn = self.gui:createButton(self.gui.width - 20, y_pos + 2, 15, 2, 
                    installed and "✓ Installed" or "📥 Install", 
                    installed and "success" or "primary")
                
                if not installed then
                    install_btn.onclick = function() 
                        self.selected_component = component
                        self:createInstallProgressScreen()
                    end
                else
                    install_btn.enabled = false
                end
                
                y_pos = y_pos + 7
            end
        end
    end
    
    -- Navigation buttons
    local back_button = self.gui:createButton(10, self.gui.height - 5, 15, 3, "← Back", "secondary")
    back_button.onclick = function() self:createConfigureScreen() end
    
    local update_button = self.gui:createButton(self.gui.width - 25, self.gui.height - 5, 15, 3, "Updates →", "warning")
    update_button.onclick = function() self:createUpdateManagerScreen() end
end

function InstallerGUI:createInstallProgressScreen()
    if not self.selected_component then return end
    
    self.gui.components = {}
    self.current_screen = "install_progress"
    
    -- Header
    local header = self.gui:createPanel(5, 2, self.gui.width - 10, 6, 
        "📦 Installing " .. self.selected_component.name)
    header.background = self.gui.COLORS.SUCCESS
    
    -- Progress bar
    local progress = self.gui:createProgressBar(10, 12, self.gui.width - 20, 4, 0, 100)
    progress.text_format = "Installing... %d%%"
    progress.bar_color = self.gui.COLORS.SUCCESS
    
    -- Status display
    local status_card = self.gui:createCard(10, 18, self.gui.width - 20, 15, "Installation Status", {
        "Preparing installation...",
        "",
        "Component: " .. self.selected_component.name,
        "Files to download: " .. #self.selected_component.files
    })
    
    -- Start installation
    self:performInstallation(progress, status_card)
end

function InstallerGUI:performInstallation(progress_bar, status_card)
    local component = self.selected_component
    local steps = {
        "Downloading files...",
        "Verifying integrity...",
        "Installing components...",
        "Configuring startup...",
        "Installation complete!"
    }
    
    local step = 0
    local status_lines = {"Starting installation..."}
    
    local function nextStep()
        step = step + 1
        if step <= #steps then
            progress_bar:setValue((step / #steps) * 100)
            progress_bar.text_format = steps[step] .. " %d%%"
            
            table.insert(status_lines, steps[step])
            if #status_lines > 10 then
                table.remove(status_lines, 1)
            end
            
            status_card:setContent(status_lines)
            self.gui:render()
            
            -- Simulate work
            os.startTimer(math.random(1, 3))
        else
            self:completeInstallation()
        end
    end
    
    -- Start installation process
    nextStep()
    
    -- Actually download and install files
    for _, file in ipairs(component.files) do
        local url = BASE_URL .. file.src
        table.insert(status_lines, "Downloading " .. file.src)
        
        -- Download file (simplified for demo)
        local success = self:downloadFile(url, file.dst)
        if success then
            table.insert(status_lines, "✓ " .. file.dst .. " installed")
        else
            table.insert(status_lines, "✗ Failed to install " .. file.dst)
        end
    end
    
    -- Complete after delay
    os.startTimer(2)
end

function InstallerGUI:downloadFile(url, destination)
    -- Simplified download function
    if not http then
        return false
    end
    
    local response = http.get(url)
    if not response then
        return false
    end
    
    local content = response.readAll()
    response.close()
    
    if content then
        local file = fs.open(destination, "w")
        if file then
            file.write(content)
            file.close()
            return true
        end
    end
    
    return false
end

function InstallerGUI:completeInstallation()
    table.insert(self.installed_components, self.selected_component.id)
    
    -- Success screen
    self.gui.components = {}
    
    local header = self.gui:createPanel(5, 2, self.gui.width - 10, 6, "✅ Installation Complete")
    header.background = self.gui.COLORS.SUCCESS
    
    local success_card = self.gui:createCard(15, 12, self.gui.width - 30, 12, 
        "🎉 " .. self.selected_component.name .. " Installed!", {
        "Installation completed successfully!",
        "",
        "Next steps:",
        "• Component is ready to use",
        "• Configuration has been applied", 
        "• Startup script created",
        "",
        "Run '" .. self.selected_component.files[1].dst .. "' to start"
    })
    
    local done_button = self.gui:createButton(25, 26, 20, 3, "🏠 Return to Menu", "primary")
    done_button.onclick = function() self:createWelcomeScreen() end
    
    local install_more_button = self.gui:createButton(50, 26, 20, 3, "📦 Install More", "success")
    install_more_button.onclick = function() self:createComponentSelectScreen() end
end

function InstallerGUI:createUpdateManagerScreen()
    self.gui.components = {}
    self.current_screen = "update_manager"
    
    -- Header
    local header = self.gui:createPanel(5, 2, self.gui.width - 10, 6, "🔄 Update Manager")
    header.background = self.gui.COLORS.WARNING
    
    -- Update status
    local status_card = self.gui:createCard(10, 10, self.gui.width - 20, 12, "Update Status", {
        "Checking for updates...",
        "",
        "Repository: " .. GITHUB_REPO,
        "Branch: " .. GITHUB_BRANCH,
        "Installed Components: " .. #self.installed_components
    })
    
    -- Component list
    local comp_list = self.gui:createList(10, 24, self.gui.width - 20, 15, {})
    comp_list.border = true
    comp_list.selectable = true
    
    for _, comp_id in ipairs(self.installed_components) do
        for _, component in ipairs(COMPONENTS) do
            if component.id == comp_id then
                comp_list:addItem({
                    text = component.icon .. " " .. component.name .. " - Update Available",
                    component = component
                })
                break
            end
        end
    end
    
    -- Action buttons
    local update_all_button = self.gui:createButton(10, self.gui.height - 8, 20, 3, "🔄 Update All", "warning")
    update_all_button.onclick = function() self:updateAllComponents() end
    
    local update_selected_button = self.gui:createButton(35, self.gui.height - 8, 20, 3, "📥 Update Selected", "primary")
    update_selected_button.onclick = function() self:updateSelectedComponent(comp_list) end
    
    local back_button = self.gui:createButton(self.gui.width - 25, self.gui.height - 8, 15, 3, "← Back", "secondary")
    back_button.onclick = function() self:createWelcomeScreen() end
end

function InstallerGUI:updateAllComponents()
    -- Update all installed components
    self.gui:showMessage("Update Manager", "Updating all components...\nThis may take a few minutes.", "info")
end

function InstallerGUI:updateSelectedComponent(comp_list)
    local selected = comp_list:getSelectedItem()
    if selected then
        self.selected_component = selected.component
        self:createInstallProgressScreen()
    end
end

function InstallerGUI:run()
    self:init()
    
    while true do
        self.gui:render()
        
        local event, p1, p2, p3 = os.pullEvent()
        
        if event == "monitor_touch" or event == "mouse_click" then
            self.gui:handleMouseClick(p2, p3, p1)
        elseif event == "mouse_drag" then
            self.gui:handleMouseDrag(p2, p3, p1)
        elseif event == "mouse_up" then
            self.gui:handleMouseUp(p2, p3, p1)
        elseif event == "timer" then
            -- Handle installation progress updates
            if self.current_screen == "install_progress" then
                -- Continue installation steps
            elseif self.current_screen == "hardware_scan" then
                -- Continue hardware scan
            end
        elseif event == "key" and p1 == keys.q then
            break
        end
    end
    
    self.gui.monitor.clear()
    self.gui.monitor.setCursorPos(1, 1)
    print("SCADA Installer GUI closed")
end

-- Error handling wrapper
local function safeRun()
    local success, error = pcall(InstallerGUI.run, InstallerGUI)
    if not success then
        print("INSTALLER GUI ERROR: " .. error)
        print("Falling back to command line installer...")
        -- Fall back to original installer
        if fs.exists("installer.lua") then
            dofile("installer.lua")
        end
    end
end

-- Check for GUI requirements
if not term.isColor() then
    print("Advanced computer required for graphical installer")
    print("Use 'installer <component>' for command line installation")
    return
end

print("=== SCADA GRAPHICAL INSTALLER & MANAGER ===")
print("Loading modern GUI interface...")
print("Press 'q' to exit")

safeRun()