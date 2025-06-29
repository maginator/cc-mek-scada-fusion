-- SCADA System Updater
-- Updates existing installations to latest version from GitHub

local GITHUB_REPO = "maginator/cc-mek-scada-fusion"
local GITHUB_BRANCH = "main"
local BASE_URL = "https://raw.githubusercontent.com/" .. GITHUB_REPO .. "/" .. GITHUB_BRANCH .. "/"

local Updater = {
    backup_path = "/update_backup/",
    log_file = "/update.log"
}

function Updater:log(message)
    print(message)
    
    local file = fs.open(self.log_file, "a")
    if file then
        file.writeLine(os.date("[%Y-%m-%d %H:%M:%S] ") .. message)
        file.close()
    end
end

function Updater:detectInstalledComponents()
    local installed = {}
    
    local component_files = {
        {file = "scada_server.lua", component = "server"},
        {file = "scada_hmi.lua", component = "hmi"},
        {file = "reactor_rtu.lua", component = "reactor"},
        {file = "energy_rtu.lua", component = "energy"},
        {file = "fuel_rtu.lua", component = "fuel"},
        {file = "laser_rtu.lua", component = "laser"},
        {file = "historian.lua", component = "historian"}
    }
    
    for _, entry in ipairs(component_files) do
        if fs.exists(entry.file) then
            table.insert(installed, entry.component)
            self:log("Detected component: " .. entry.component .. " (" .. entry.file .. ")")
        end
    end
    
    return installed
end

function Updater:downloadFile(url, destination)
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
    
    local file = fs.open(destination, "w")
    if not file then
        error("Failed to create file: " .. destination)
    end
    
    file.write(content)
    file.close()
    
    self:log("Updated: " .. destination .. " (" .. #content .. " bytes)")
    return true
end

function Updater:createBackup(files)
    if not fs.exists(self.backup_path) then
        fs.makeDir(self.backup_path)
    end
    
    local backup_timestamp = os.date("%Y%m%d_%H%M%S")
    local backup_dir = self.backup_path .. backup_timestamp .. "/"
    fs.makeDir(backup_dir)
    
    for _, file_path in ipairs(files) do
        if fs.exists(file_path) then
            local backup_path = backup_dir .. fs.getName(file_path)
            fs.copy(file_path, backup_path)
            self:log("Backed up: " .. file_path .. " -> " .. backup_path)
        end
    end
    
    return backup_dir
end

function Updater:updateComponent(component)
    local file_mappings = {
        server = {src = "scada_server.lua", dst = "scada_server.lua"},
        hmi = {src = "scada_hmi.lua", dst = "scada_hmi.lua"},
        reactor = {src = "fusion_reactor_mon.lua", dst = "reactor_rtu.lua"},
        energy = {src = "energy_storage.lua", dst = "energy_rtu.lua"},
        fuel = {src = "fuel_control.lua", dst = "fuel_rtu.lua"},
        laser = {src = "laser_control.lua", dst = "laser_rtu.lua"},
        historian = {src = "scada_historian.lua", dst = "historian.lua"}
    }
    
    local mapping = file_mappings[component]
    if not mapping then
        error("Unknown component: " .. component)
    end
    
    if not fs.exists(mapping.dst) then
        error("Component not installed: " .. component .. " (missing " .. mapping.dst .. ")")
    end
    
    -- Backup existing file
    local backup_dir = self:createBackup({mapping.dst})
    
    -- Download and update
    local url = BASE_URL .. mapping.src
    local success, error = pcall(self.downloadFile, self, url, mapping.dst)
    
    if success then
        self:log("Successfully updated component: " .. component)
        return true
    else
        self:log("ERROR updating component: " .. error)
        
        -- Restore from backup
        local backup_file = backup_dir .. fs.getName(mapping.dst)
        if fs.exists(backup_file) then
            fs.copy(backup_file, mapping.dst)
            self:log("Restored from backup: " .. mapping.dst)
        end
        
        return false
    end
end

function Updater:updateInstaller()
    self:log("Updating installer...")
    
    -- Backup current updater
    if fs.exists("update.lua") then
        local backup_dir = self:createBackup({"update.lua"})
        self:log("Backed up updater to: " .. backup_dir)
    end
    
    -- Download new installer
    local url = BASE_URL .. "installer.lua"
    local success, error = pcall(self.downloadFile, self, url, "installer.lua")
    
    if success then
        self:log("Installer updated successfully")
        return true
    else
        self:log("ERROR updating installer: " .. error)
        return false
    end
end

function Updater:run(args)
    self:log("=== SCADA System Updater Started ===")
    
    -- Check HTTP API
    if not http then
        error("HTTP API is disabled. Enable it in ComputerCraft config.")
    end
    
    if #args == 0 then
        -- Auto-detect and update all installed components
        self:log("Auto-detecting installed components...")
        
        local installed = self:detectInstalledComponents()
        
        if #installed == 0 then
            print("No SCADA components detected.")
            print("Use 'installer <component>' to install components first.")
            return
        end
        
        print("Detected components: " .. table.concat(installed, ", "))
        print("Update all components? (y/N)")
        
        local input = read()
        if input:lower() ~= "y" and input:lower() ~= "yes" then
            self:log("Update cancelled by user")
            return
        end
        
        -- Update all detected components
        local success_count = 0
        for _, component in ipairs(installed) do
            local success = self:updateComponent(component)
            if success then
                success_count = success_count + 1
            end
        end
        
        self:log("Updated " .. success_count .. " of " .. #installed .. " components")
        
        -- Update installer
        self:updateInstaller()
        
        if success_count == #installed then
            print("All components updated successfully!")
        else
            print("Some components failed to update. Check update.log for details.")
        end
        
    else
        -- Update specific component
        local component = args[1]:lower()
        
        if component == "installer" then
            local success = self:updateInstaller()
            if success then
                print("Installer updated successfully!")
            else
                print("Failed to update installer. Check update.log for details.")
            end
        else
            local success = self:updateComponent(component)
            if success then
                print("Component '" .. component .. "' updated successfully!")
            else
                print("Failed to update component. Check update.log for details.")
            end
        end
    end
    
    self:log("=== Update Complete ===")
end

-- Main execution
local args = {...}

-- Error handling wrapper
local function safeRun()
    local success, error = pcall(Updater.run, Updater, args)
    if not success then
        print("UPDATER ERROR: " .. error)
        print("Check update.log for details")
        return false
    end
    return true
end

safeRun()