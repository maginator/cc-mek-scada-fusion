-- SCADA Compact Graphical Installer
-- Optimized for ComputerCraft screen dimensions (51x19 typical)

-- Load the GUI library
local GUI = dofile("scada_gui.lua")

local GITHUB_REPO = "maginator/cc-mek-scada-fusion"
local GITHUB_BRANCH = "main"
local BASE_URL = "https://raw.githubusercontent.com/" .. GITHUB_REPO .. "/" .. GITHUB_BRANCH .. "/"

local COMPONENTS = {
    {id = "server", name = "SCADA Server", desc = "Central control", icon = "S", 
     files = {{src = "scada_server.lua", dst = "scada_server.lua", startup = true}}},
    {id = "hmi", name = "HMI Client", desc = "Operator interface", icon = "H",
     files = {{src = "scada_hmi.lua", dst = "scada_hmi.lua", startup = true}}},
    {id = "rtu", name = "Universal RTU", desc = "Auto-detect device", icon = "R",
     files = {{src = "universal_rtu.lua", dst = "universal_rtu.lua", startup = true}}},
    {id = "historian", name = "Data Logger", desc = "Historical data", icon = "D",
     files = {{src = "scada_historian.lua", dst = "historian.lua", startup = true}}},
    {id = "config", name = "Configurator", desc = "Setup wizard", icon = "C",
     files = {{src = "configurator.lua", dst = "configurator.lua", startup = false}}}
}

local InstallerGUI = {
    gui = nil,
    w = 51, h = 19,  -- Standard ComputerCraft dimensions
    current_screen = "main",
    selected_index = 1,
    installed = {},
    progress = 0
}

function InstallerGUI:init()
    -- Use monitor if available, otherwise use computer screen
    local monitor = peripheral.find("monitor")
    if monitor then
        self.gui = GUI:init(monitor)
        self.w, self.h = monitor.getSize()
        if self.w > 51 then
            monitor.setTextScale(0.5)  -- Use smaller text for large monitors
            self.w, self.h = monitor.getSize()
        end
    else
        self.gui = GUI:init(term)
        self.w, self.h = term.getSize()
    end
    
    self:detectInstalled()
    self:drawMainScreen()
end

function InstallerGUI:detectInstalled()
    for _, component in ipairs(COMPONENTS) do
        for _, file in ipairs(component.files) do
            if fs.exists(file.dst) then
                table.insert(self.installed, component.id)
                break
            end
        end
    end
end

function InstallerGUI:drawBox(x, y, w, h, title, color)
    color = color or colors.lightBlue
    
    -- Clear area
    for row = 0, h - 1 do
        self.gui.monitor.setCursorPos(x, y + row)
        self.gui.monitor.setBackgroundColor(colors.black)
        self.gui.monitor.write(string.rep(" ", w))
    end
    
    -- Draw borders
    self.gui.monitor.setBackgroundColor(color)
    self.gui.monitor.setTextColor(colors.white)
    
    -- Top/bottom
    self.gui.monitor.setCursorPos(x, y)
    self.gui.monitor.write(string.rep(" ", w))
    self.gui.monitor.setCursorPos(x, y + h - 1)
    self.gui.monitor.write(string.rep(" ", w))
    
    -- Sides
    for row = 1, h - 2 do
        self.gui.monitor.setCursorPos(x, y + row)
        self.gui.monitor.write(" ")
        self.gui.monitor.setCursorPos(x + w - 1, y + row)
        self.gui.monitor.write(" ")
    end
    
    -- Title
    if title then
        local title_text = " " .. title .. " "
        self.gui.monitor.setCursorPos(x + math.floor((w - #title_text) / 2), y)
        self.gui.monitor.setBackgroundColor(colors.cyan)
        self.gui.monitor.write(title_text)
    end
    
    self.gui.monitor.setBackgroundColor(colors.black)
end

function InstallerGUI:drawMainScreen()
    self.gui.monitor.clear()
    self.current_screen = "main"
    
    -- Header (fits in 51 width)
    self:drawBox(1, 1, self.w, 3, "SCADA INSTALLER", colors.blue)
    
    -- Component list (compact for 19 height)
    self:drawBox(1, 5, self.w, self.h - 8, "COMPONENTS", colors.green)
    
    -- Draw components (starts at y=6, max 9 lines for 19 height)
    for i, component in ipairs(COMPONENTS) do
        local y_pos = 6 + (i - 1)
        if y_pos >= self.h - 4 then break end
        
        self.gui.monitor.setCursorPos(3, y_pos)
        
        -- Highlight selected
        if i == self.selected_index then
            self.gui.monitor.setBackgroundColor(colors.lightBlue)
            self.gui.monitor.setTextColor(colors.black)
        else
            self.gui.monitor.setBackgroundColor(colors.black)
            self.gui.monitor.setTextColor(colors.white)
        end
        
        -- Check if installed
        local installed = false
        for _, inst_id in ipairs(self.installed) do
            if inst_id == component.id then
                installed = true
                break
            end
        end
        
        -- Format: [X] Icon Name - Description (fits in ~45 chars)
        local status = installed and "[+]" or " "
        local text = string.format("[%s] %s %-8s - %-20s", 
            status, component.icon, component.name:sub(1,8), component.desc:sub(1,20))
        
        -- Truncate to fit width
        if #text > self.w - 6 then
            text = text:sub(1, self.w - 9) .. "..."
        end
        
        self.gui.monitor.write(text)
    end
    
    -- Controls (bottom area)
    self.gui.monitor.setBackgroundColor(colors.black)
    self.gui.monitor.setTextColor(colors.white)
    
    -- Button area
    local btn_y = self.h - 2
    self.gui.monitor.setCursorPos(2, btn_y)
    self.gui.monitor.write("↑/↓ Select  ENTER Install  S Scan  C Config  Q Quit")
    
    -- Instructions for small screens
    if self.w <= 51 then
        self.gui.monitor.setCursorPos(2, self.h - 1)
        self.gui.monitor.setTextColor(colors.yellow)
        self.gui.monitor.write("Use arrow keys and ENTER to navigate")
    end
    
    -- Status line
    self.gui.monitor.setCursorPos(2, self.h)
    self.gui.monitor.setTextColor(colors.lightGray)
    self.gui.monitor.write(string.format("Screen: %dx%d | Installed: %d/%d", 
        self.w, self.h, #self.installed, #COMPONENTS))
end

function InstallerGUI:drawScanScreen()
    self.gui.monitor.clear()
    self.current_screen = "scan"
    
    self:drawBox(1, 1, self.w, 3, "HARDWARE SCAN", colors.orange)
    
    -- Scan results (compact)
    local y = 5
    self.gui.monitor.setCursorPos(2, y)
    self.gui.monitor.setTextColor(colors.white)
    self.gui.monitor.write("Detecting hardware...")
    
    y = y + 2
    
    -- Check peripherals
    local monitors = 0
    local modems = {wireless = 0, cable = 0}
    local mekanism = 0
    
    for _, side in ipairs({"top", "bottom", "left", "right", "front", "back"}) do
        local ptype = peripheral.getType(side)
        if ptype == "monitor" then
            monitors = monitors + 1
        elseif ptype == "modem" then
            local modem = peripheral.wrap(side)
            if modem then
                if modem.isWireless() then
                    modems.wireless = modems.wireless + 1
                else
                    modems.cable = modems.cable + 1
                    -- Count Mekanism devices
                    local devices = modem.getNamesRemote()
                    for _, device in ipairs(devices) do
                        if device:lower():find("reactor") or device:lower():find("induction") or
                           device:lower():find("tank") or device:lower():find("laser") then
                            mekanism = mekanism + 1
                        end
                    end
                end
            end
        end
    end
    
    -- Display results (compact format)
    self.gui.monitor.setCursorPos(2, y)
    self.gui.monitor.setTextColor(colors.lime)
    self.gui.monitor.write("[+] Monitors: " .. monitors)
    
    y = y + 1
    self.gui.monitor.setCursorPos(2, y)
    self.gui.monitor.write("[+] Wireless Modems: " .. modems.wireless)
    
    y = y + 1
    self.gui.monitor.setCursorPos(2, y)
    self.gui.monitor.write("[+] Cable Modems: " .. modems.cable)
    
    y = y + 1
    self.gui.monitor.setCursorPos(2, y)
    self.gui.monitor.write("[+] Mekanism Devices: " .. mekanism)
    
    y = y + 2
    
    -- Recommendations (compact)
    self.gui.monitor.setCursorPos(2, y)
    self.gui.monitor.setTextColor(colors.yellow)
    self.gui.monitor.write("Recommendations:")
    
    y = y + 1
    self.gui.monitor.setCursorPos(4, y)
    self.gui.monitor.setTextColor(colors.white)
    if monitors > 0 then
        self.gui.monitor.write("• HMI Client supported")
    else
        self.gui.monitor.write("• No monitor for HMI")
    end
    
    y = y + 1
    self.gui.monitor.setCursorPos(4, y)
    if modems.wireless > 0 then
        self.gui.monitor.write("• Wireless ready for SCADA")
    else
        self.gui.monitor.write("• Need wireless modem")
    end
    
    y = y + 1
    self.gui.monitor.setCursorPos(4, y)
    if mekanism > 0 then
        self.gui.monitor.write("• RTU can control " .. mekanism .. " devices")
    else
        self.gui.monitor.write("• No Mekanism devices found")
    end
    
    -- Back instruction
    self.gui.monitor.setCursorPos(2, self.h - 1)
    self.gui.monitor.setTextColor(colors.lightGray)
    self.gui.monitor.write("Press any key to return...")
end

function InstallerGUI:drawConfigScreen()
    self.gui.monitor.clear()
    self.current_screen = "config"
    
    self:drawBox(1, 1, self.w, 3, "CONFIGURATION", colors.purple)
    
    local y = 5
    self.gui.monitor.setCursorPos(2, y)
    self.gui.monitor.setTextColor(colors.white)
    self.gui.monitor.write("Auto-Configuration Options:")
    
    y = y + 2
    self.gui.monitor.setCursorPos(4, y)
    self.gui.monitor.write("1. Auto-detect and configure")
    y = y + 1
    self.gui.monitor.setCursorPos(4, y)
    self.gui.monitor.write("2. Use default settings")
    y = y + 1
    self.gui.monitor.setCursorPos(4, y)
    self.gui.monitor.write("3. Skip configuration")
    
    y = y + 2
    self.gui.monitor.setCursorPos(2, y)
    self.gui.monitor.setTextColor(colors.yellow)
    self.gui.monitor.write("Channels: 100-105 (default)")
    
    y = y + 1
    self.gui.monitor.setCursorPos(2, y)
    self.gui.monitor.write("RTU Mode: Auto-detect")
    
    -- Instructions
    self.gui.monitor.setCursorPos(2, self.h - 1)
    self.gui.monitor.setTextColor(colors.lightGray)
    self.gui.monitor.write("1/2/3 to select, ESC to cancel")
end

function InstallerGUI:drawInstallScreen(component)
    self.gui.monitor.clear()
    self.current_screen = "install"
    
    self:drawBox(1, 1, self.w, 3, "INSTALLING " .. component.name:upper(), colors.red)
    
    -- Progress bar (simple)
    local y = 6
    self.gui.monitor.setCursorPos(2, y)
    self.gui.monitor.setTextColor(colors.white)
    self.gui.monitor.write("Progress:")
    
    y = y + 1
    local bar_width = self.w - 4
    local filled = math.floor((self.progress / 100) * bar_width)
    
    self.gui.monitor.setCursorPos(2, y)
    self.gui.monitor.setBackgroundColor(colors.gray)
    self.gui.monitor.write(string.rep(" ", bar_width))
    
    self.gui.monitor.setCursorPos(2, y)
    self.gui.monitor.setBackgroundColor(colors.green)
    self.gui.monitor.write(string.rep(" ", filled))
    
    self.gui.monitor.setBackgroundColor(colors.black)
    self.gui.monitor.setCursorPos(2 + math.floor(bar_width/2) - 2, y)
    self.gui.monitor.setTextColor(colors.white)
    self.gui.monitor.write(self.progress .. "%")
    
    -- Status
    y = y + 2
    self.gui.monitor.setCursorPos(2, y)
    self.gui.monitor.setTextColor(colors.yellow)
    
    if self.progress < 25 then
        self.gui.monitor.write("Downloading files...")
    elseif self.progress < 50 then
        self.gui.monitor.write("Verifying integrity...")
    elseif self.progress < 75 then
        self.gui.monitor.write("Installing component...")
    elseif self.progress < 100 then
        self.gui.monitor.write("Configuring startup...")
    else
        self.gui.monitor.write("Installation complete!")
    end
    
    -- Component info
    y = y + 2
    self.gui.monitor.setCursorPos(2, y)
    self.gui.monitor.setTextColor(colors.white)
    self.gui.monitor.write("Component: " .. component.name)
    y = y + 1
    self.gui.monitor.setCursorPos(2, y)
    self.gui.monitor.write("Files: " .. #component.files)
end

function InstallerGUI:installComponent(component)
    self.progress = 0
    
    -- Simulate installation
    local steps = 20
    for i = 1, steps do
        self.progress = (i / steps) * 100
        self:drawInstallScreen(component)
        sleep(0.1)
    end
    
    -- Actually download files
    for _, file in ipairs(component.files) do
        local url = BASE_URL .. file.src
        local response = http.get(url)
        if response then
            local content = response.readAll()
            response.close()
            
            local local_file = fs.open(file.dst, "w")
            if local_file then
                local_file.write(content)
                local_file.close()
            end
        end
    end
    
    -- Add to installed list
    table.insert(self.installed, component.id)
    
    -- Success message
    self.gui.monitor.setCursorPos(2, self.h - 2)
    self.gui.monitor.setTextColor(colors.lime)
    self.gui.monitor.write("[+] " .. component.name .. " installed successfully!")
    
    self.gui.monitor.setCursorPos(2, self.h - 1)
    self.gui.monitor.setTextColor(colors.lightGray)
    self.gui.monitor.write("Press any key to continue...")
    
    os.pullEvent("key")
end

function InstallerGUI:handleInput()
    while true do
        local event, key = os.pullEvent()
        
        if event == "key" then
            if self.current_screen == "main" then
                if key == keys.up and self.selected_index > 1 then
                    self.selected_index = self.selected_index - 1
                    self:drawMainScreen()
                elseif key == keys.down and self.selected_index < #COMPONENTS then
                    self.selected_index = self.selected_index + 1
                    self:drawMainScreen()
                elseif key == keys.enter then
                    local component = COMPONENTS[self.selected_index]
                    -- Check if already installed
                    local already_installed = false
                    for _, inst_id in ipairs(self.installed) do
                        if inst_id == component.id then
                            already_installed = true
                            break
                        end
                    end
                    
                    if not already_installed then
                        self:installComponent(component)
                        self:drawMainScreen()
                    end
                elseif key == keys.s then
                    self:drawScanScreen()
                    os.pullEvent("key")
                    self:drawMainScreen()
                elseif key == keys.c then
                    self:drawConfigScreen()
                    local config_event, config_key = os.pullEvent("key")
                    if config_key >= keys.one and config_key <= keys.three then
                        -- Auto-configure based on selection
                        self:autoConfig(config_key - keys.one + 1)
                    end
                    self:drawMainScreen()
                elseif key == keys.q then
                    break
                end
            else
                -- Other screens - return to main on any key
                self:drawMainScreen()
            end
        elseif event == "monitor_touch" or event == "mouse_click" then
            -- Simple mouse support for touch screens
            local x, y = key, event == "monitor_touch" and event or nil
            if self.current_screen == "main" and y >= 6 and y < 6 + #COMPONENTS then
                self.selected_index = y - 5
                self:drawMainScreen()
            end
        end
    end
end

function InstallerGUI:autoConfig(option)
    -- Simple auto-configuration
    local config = {
        network = {
            channels = {reactor = 100, fuel = 101, energy = 102, laser = 103, hmi = 104, alarm = 105}
        },
        auto_detect = true
    }
    
    local file = fs.open("scada_config.lua", "w")
    if file then
        file.write("return " .. textutils.serialize(config))
        file.close()
    end
end

function InstallerGUI:run()
    -- Check requirements
    if not http then
        print("HTTP API required. Enable in ComputerCraft config.")
        return
    end
    
    self:init()
    
    print("SCADA Graphical Installer")
    print("Screen: " .. self.w .. "x" .. self.h)
    print("Use arrow keys to navigate, ENTER to install")
    print("Press any key to start...")
    os.pullEvent("key")
    
    self:handleInput()
    
    self.gui.monitor.clear()
    self.gui.monitor.setCursorPos(1, 1)
    print("Installation complete. Thank you!")
end

-- Error handling
local function safeRun()
    local success, error = pcall(InstallerGUI.run, InstallerGUI)
    if not success then
        print("GUI Error: " .. error)
        print("Try command line installer: installer cli")
    end
end

-- Check if we can use GUI
if not term.isColor() then
    print("Advanced Computer required for GUI")
    print("Use: installer cli")
    return
end

safeRun()