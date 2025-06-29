-- SCADA GUI Library
-- Advanced graphical user interface library for ComputerCraft Advanced Computers
-- Provides modern UI components with mouse/touch support

local GUI = {}

-- Color scheme for modern UI
GUI.COLORS = {
    -- Base colors
    PRIMARY = colors.blue,
    SECONDARY = colors.cyan,
    ACCENT = colors.lightBlue,
    
    -- Background colors
    BG_DARK = colors.black,
    BG_LIGHT = colors.gray,
    BG_PANEL = colors.lightGray,
    
    -- Text colors
    TEXT_PRIMARY = colors.white,
    TEXT_SECONDARY = colors.lightGray,
    TEXT_ACCENT = colors.cyan,
    TEXT_MUTED = colors.gray,
    
    -- Status colors
    SUCCESS = colors.lime,
    WARNING = colors.orange,
    ERROR = colors.red,
    INFO = colors.lightBlue,
    
    -- Interactive colors
    BUTTON_DEFAULT = colors.gray,
    BUTTON_PRIMARY = colors.blue,
    BUTTON_SUCCESS = colors.green,
    BUTTON_WARNING = colors.orange,
    BUTTON_DANGER = colors.red,
    BUTTON_HOVER = colors.lightGray,
    BUTTON_ACTIVE = colors.white,
    
    -- Border colors
    BORDER_LIGHT = colors.lightGray,
    BORDER_DARK = colors.gray,
    SHADOW = colors.black
}

-- Initialize GUI system
function GUI:init(monitor)
    self.monitor = monitor or term
    self.width, self.height = self.monitor.getSize()
    self.components = {}
    self.focused_component = nil
    self.mouse_handlers = {}
    self.running = true
    
    -- Set up initial state
    self.monitor.setBackgroundColor(self.COLORS.BG_DARK)
    self.monitor.clear()
    
    return self
end

-- Component base class
function GUI:createComponent(type, x, y, width, height)
    local component = {
        type = type,
        x = x,
        y = y,
        width = width,
        height = height,
        visible = true,
        enabled = true,
        background = self.COLORS.BG_PANEL,
        foreground = self.COLORS.TEXT_PRIMARY,
        border = true,
        border_color = self.COLORS.BORDER_LIGHT,
        shadow = false,
        onclick = nil,
        onhover = nil,
        children = {}
    }
    
    table.insert(self.components, component)
    return component
end

-- Draw a filled rectangle
function GUI:fillRect(x, y, width, height, color)
    self.monitor.setBackgroundColor(color)
    for row = 0, height - 1 do
        self.monitor.setCursorPos(x, y + row)
        self.monitor.write(string.rep(" ", width))
    end
end

-- Draw a border around a rectangle
function GUI:drawBorder(x, y, width, height, color, style)
    style = style or "single"
    self.monitor.setBackgroundColor(color)
    self.monitor.setTextColor(color)
    
    if style == "single" then
        -- Top and bottom borders
        for col = 0, width - 1 do
            self.monitor.setCursorPos(x + col, y)
            self.monitor.write(" ")
            self.monitor.setCursorPos(x + col, y + height - 1)
            self.monitor.write(" ")
        end
        
        -- Left and right borders
        for row = 0, height - 1 do
            self.monitor.setCursorPos(x, y + row)
            self.monitor.write(" ")
            self.monitor.setCursorPos(x + width - 1, y + row)
            self.monitor.write(" ")
        end
    elseif style == "thick" then
        -- Thick border (2 pixel width)
        for col = 0, width - 1 do
            self.monitor.setCursorPos(x + col, y)
            self.monitor.write(" ")
            self.monitor.setCursorPos(x + col, y + 1)
            self.monitor.write(" ")
            self.monitor.setCursorPos(x + col, y + height - 2)
            self.monitor.write(" ")
            self.monitor.setCursorPos(x + col, y + height - 1)
            self.monitor.write(" ")
        end
        
        for row = 0, height - 1 do
            self.monitor.setCursorPos(x, y + row)
            self.monitor.write(" ")
            self.monitor.setCursorPos(x + 1, y + row)
            self.monitor.write(" ")
            self.monitor.setCursorPos(x + width - 2, y + row)
            self.monitor.write(" ")
            self.monitor.setCursorPos(x + width - 1, y + row)
            self.monitor.write(" ")
        end
    end
end

-- Draw shadow effect
function GUI:drawShadow(x, y, width, height)
    self.monitor.setBackgroundColor(self.COLORS.SHADOW)
    
    -- Right shadow
    for row = 1, height do
        self.monitor.setCursorPos(x + width, y + row)
        self.monitor.write(" ")
    end
    
    -- Bottom shadow
    for col = 1, width do
        self.monitor.setCursorPos(x + col, y + height)
        self.monitor.write(" ")
    end
end

-- Draw text with alignment
function GUI:drawText(x, y, text, color, align, max_width)
    color = color or self.COLORS.TEXT_PRIMARY
    align = align or "left"
    max_width = max_width or #text
    
    -- Truncate text if too long
    if #text > max_width then
        text = text:sub(1, max_width - 3) .. "..."
    end
    
    local text_x = x
    if align == "center" then
        text_x = x + math.floor((max_width - #text) / 2)
    elseif align == "right" then
        text_x = x + max_width - #text
    end
    
    self.monitor.setCursorPos(text_x, y)
    self.monitor.setTextColor(color)
    self.monitor.write(text)
end

-- Panel component
function GUI:createPanel(x, y, width, height, title)
    local panel = self:createComponent("panel", x, y, width, height)
    panel.title = title
    panel.title_color = self.COLORS.TEXT_ACCENT
    panel.padding = 1
    
    function panel:draw()
        -- Draw shadow if enabled
        if self.shadow then
            GUI:drawShadow(self.x, self.y, self.width, self.height)
        end
        
        -- Draw background
        GUI:fillRect(self.x, self.y, self.width, self.height, self.background)
        
        -- Draw border
        if self.border then
            GUI:drawBorder(self.x, self.y, self.width, self.height, self.border_color)
        end
        
        -- Draw title
        if self.title then
            local title_bg = GUI.COLORS.PRIMARY
            GUI:fillRect(self.x + 1, self.y, self.width - 2, 1, title_bg)
            GUI:drawText(self.x + 2, self.y, self.title, self.title_color, "left", self.width - 4)
        end
    end
    
    return panel
end

-- Button component
function GUI:createButton(x, y, width, height, text, style)
    local button = self:createComponent("button", x, y, width, height)
    button.text = text or ""
    button.style = style or "default"
    button.hovered = false
    button.pressed = false
    button.icon = nil
    
    -- Set colors based on style
    if style == "primary" then
        button.background = self.COLORS.BUTTON_PRIMARY
        button.foreground = self.COLORS.TEXT_PRIMARY
    elseif style == "success" then
        button.background = self.COLORS.BUTTON_SUCCESS
        button.foreground = self.COLORS.TEXT_PRIMARY
    elseif style == "warning" then
        button.background = self.COLORS.BUTTON_WARNING
        button.foreground = self.COLORS.TEXT_PRIMARY
    elseif style == "danger" then
        button.background = self.COLORS.BUTTON_DANGER
        button.foreground = self.COLORS.TEXT_PRIMARY
    else
        button.background = self.COLORS.BUTTON_DEFAULT
        button.foreground = self.COLORS.TEXT_PRIMARY
    end
    
    function button:draw()
        local bg_color = self.background
        local text_color = self.foreground
        
        -- State-based color adjustments
        if not self.enabled then
            bg_color = GUI.COLORS.BG_LIGHT
            text_color = GUI.COLORS.TEXT_MUTED
        elseif self.pressed then
            bg_color = GUI.COLORS.BUTTON_ACTIVE
            text_color = GUI.COLORS.BG_DARK
        elseif self.hovered then
            bg_color = GUI.COLORS.BUTTON_HOVER
        end
        
        -- Draw shadow
        if self.shadow and self.enabled then
            GUI:drawShadow(self.x, self.y, self.width, self.height)
        end
        
        -- Draw button background
        GUI:fillRect(self.x, self.y, self.width, self.height, bg_color)
        
        -- Draw border
        if self.border then
            GUI:drawBorder(self.x, self.y, self.width, self.height, self.border_color)
        end
        
        -- Draw highlight effect when pressed
        if self.pressed then
            GUI:fillRect(self.x, self.y, self.width, 1, GUI.COLORS.TEXT_PRIMARY)
        elseif not self.pressed and self.enabled then
            GUI:fillRect(self.x, self.y, self.width, 1, colors.white)
        end
        
        -- Draw text with icon
        local display_text = self.text
        if self.icon then
            display_text = self.icon .. " " .. self.text
        end
        
        GUI:drawText(self.x, self.y + math.floor(self.height / 2), 
                    display_text, text_color, "center", self.width)
    end
    
    function button:isPointInside(px, py)
        return px >= self.x and px < self.x + self.width and
               py >= self.y and py < self.y + self.height
    end
    
    function button:onMouseClick(x, y, button)
        if self:isPointInside(x, y) and self.enabled then
            self.pressed = true
            if self.onclick then
                self.onclick(self, x, y, button)
            end
            return true
        end
        return false
    end
    
    function button:onMouseHover(x, y)
        local inside = self:isPointInside(x, y)
        if inside ~= self.hovered then
            self.hovered = inside
            if inside and self.onhover then
                self.onhover(self, x, y)
            end
        end
    end
    
    function button:onMouseRelease()
        self.pressed = false
    end
    
    return button
end

-- Progress bar component
function GUI:createProgressBar(x, y, width, height, value, max_value)
    local progress = self:createComponent("progress", x, y, width, height)
    progress.value = value or 0
    progress.max_value = max_value or 100
    progress.show_text = true
    progress.text_format = "%d%%"
    progress.bar_color = self.COLORS.SUCCESS
    progress.bg_color = self.COLORS.BG_LIGHT
    
    function progress:draw()
        -- Draw background
        GUI:fillRect(self.x, self.y, self.width, self.height, self.bg_color)
        
        -- Draw border
        if self.border then
            GUI:drawBorder(self.x, self.y, self.width, self.height, self.border_color)
        end
        
        -- Calculate progress width
        local percentage = math.max(0, math.min(100, (self.value / self.max_value) * 100))
        local progress_width = math.floor((percentage / 100) * (self.width - 2))
        
        -- Draw progress fill
        if progress_width > 0 then
            GUI:fillRect(self.x + 1, self.y + 1, progress_width, self.height - 2, self.bar_color)
        end
        
        -- Draw text
        if self.show_text then
            local text = string.format(self.text_format, percentage)
            GUI:drawText(self.x + 1, self.y + math.floor(self.height / 2), 
                        text, self.foreground, "center", self.width - 2)
        end
    end
    
    function progress:setValue(value)
        self.value = math.max(0, math.min(self.max_value, value))
    end
    
    return progress
end

-- List component
function GUI:createList(x, y, width, height, items)
    local list = self:createComponent("list", x, y, width, height)
    list.items = items or {}
    list.selected_index = 1
    list.scroll_offset = 0
    list.item_height = 1
    list.selectable = true
    list.multi_select = false
    list.selected_bg = self.COLORS.PRIMARY
    list.selected_fg = self.COLORS.TEXT_PRIMARY
    list.hover_bg = self.COLORS.BG_LIGHT
    
    function list:draw()
        -- Draw background
        GUI:fillRect(self.x, self.y, self.width, self.height, self.background)
        
        -- Draw border
        if self.border then
            GUI:drawBorder(self.x, self.y, self.width, self.height, self.border_color)
        end
        
        -- Calculate visible area
        local content_y = self.y + (self.border and 1 or 0)
        local content_height = self.height - (self.border and 2 or 0)
        local visible_items = math.floor(content_height / self.item_height)
        
        -- Draw items
        for i = 1, visible_items do
            local item_index = i + self.scroll_offset
            if item_index <= #self.items then
                local item = self.items[item_index]
                local item_y = content_y + (i - 1) * self.item_height
                
                -- Draw item background
                local bg_color = self.background
                local text_color = self.foreground
                
                if item_index == self.selected_index and self.selectable then
                    bg_color = self.selected_bg
                    text_color = self.selected_fg
                end
                
                GUI:fillRect(self.x + 1, item_y, self.width - 2, self.item_height, bg_color)
                
                -- Draw item text
                local display_text = type(item) == "table" and item.text or tostring(item)
                GUI:drawText(self.x + 2, item_y, display_text, text_color, "left", self.width - 4)
            end
        end
    end
    
    function list:onMouseClick(x, y, button)
        if self:isPointInside(x, y) and self.selectable then
            local content_y = self.y + (self.border and 1 or 0)
            local relative_y = y - content_y
            local clicked_item = math.floor(relative_y / self.item_height) + 1 + self.scroll_offset
            
            if clicked_item >= 1 and clicked_item <= #self.items then
                self.selected_index = clicked_item
                if self.onclick then
                    self.onclick(self, self.items[clicked_item], clicked_item)
                end
                return true
            end
        end
        return false
    end
    
    function list:isPointInside(px, py)
        return px >= self.x and px < self.x + self.width and
               py >= self.y and py < self.y + self.height
    end
    
    function list:addItem(item)
        table.insert(self.items, item)
    end
    
    function list:getSelectedItem()
        if self.selected_index >= 1 and self.selected_index <= #self.items then
            return self.items[self.selected_index]
        end
        return nil
    end
    
    return list
end

-- Card component (modern panel with rounded appearance)
function GUI:createCard(x, y, width, height, title, content)
    local card = self:createComponent("card", x, y, width, height)
    card.title = title
    card.content = content or {}
    card.title_color = self.COLORS.TEXT_ACCENT
    card.padding = 2
    card.shadow = true
    
    function card:draw()
        -- Draw shadow
        if self.shadow then
            GUI:drawShadow(self.x, self.y, self.width, self.height)
        end
        
        -- Draw background
        GUI:fillRect(self.x, self.y, self.width, self.height, self.background)
        
        -- Draw subtle border
        GUI:drawBorder(self.x, self.y, self.width, self.height, self.border_color)
        
        -- Draw title area
        if self.title then
            GUI:fillRect(self.x + 1, self.y + 1, self.width - 2, 2, GUI.COLORS.PRIMARY)
            GUI:drawText(self.x + 2, self.y + 1, self.title, self.title_color, "left", self.width - 4)
        end
        
        -- Draw content area
        local content_y = self.y + (self.title and 3 or 1) + self.padding
        for i, line in ipairs(self.content) do
            if content_y + i - 1 < self.y + self.height - self.padding then
                GUI:drawText(self.x + self.padding, content_y + i - 1, 
                           line, self.foreground, "left", self.width - self.padding * 2)
            end
        end
    end
    
    function card:setContent(content)
        self.content = type(content) == "table" and content or {tostring(content)}
    end
    
    return card
end

-- Window management
function GUI:createWindow(title, width, height)
    local window = {}
    window.title = title
    window.width = width or self.width
    window.height = height or self.height
    window.x = math.floor((self.width - window.width) / 2)
    window.y = math.floor((self.height - window.height) / 2)
    window.components = {}
    window.modal = false
    window.closable = true
    
    function window:addComponent(component)
        table.insert(self.components, component)
        return component
    end
    
    function window:draw()
        -- Draw window background
        GUI:fillRect(self.x, self.y, self.width, self.height, GUI.COLORS.BG_PANEL)
        
        -- Draw window border
        GUI:drawBorder(self.x, self.y, self.width, self.height, GUI.COLORS.BORDER_DARK, "thick")
        
        -- Draw title bar
        GUI:fillRect(self.x + 2, self.y + 2, self.width - 4, 3, GUI.COLORS.PRIMARY)
        GUI:drawText(self.x + 4, self.y + 3, self.title, GUI.COLORS.TEXT_PRIMARY, "left", self.width - 8)
        
        -- Draw close button if closable
        if self.closable then
            GUI:drawText(self.x + self.width - 4, self.y + 3, "X", GUI.COLORS.ERROR, "center", 1)
        end
        
        -- Draw all components
        for _, component in ipairs(self.components) do
            if component.visible and component.draw then
                component:draw()
            end
        end
    end
    
    function window:handleClick(x, y, button)
        -- Check close button
        if self.closable and x == self.x + self.width - 4 and y == self.y + 3 then
            return "close"
        end
        
        -- Handle component clicks
        for _, component in ipairs(self.components) do
            if component.visible and component.enabled and component.onMouseClick then
                if component:onMouseClick(x, y, button) then
                    return true
                end
            end
        end
        return false
    end
    
    return window
end

-- Main render loop
function GUI:render()
    self.monitor.setBackgroundColor(self.COLORS.BG_DARK)
    self.monitor.clear()
    
    -- Draw all components
    for _, component in ipairs(self.components) do
        if component.visible and component.draw then
            component:draw()
        end
    end
end

-- Event handling
function GUI:handleMouseClick(x, y, button)
    for i = #self.components, 1, -1 do
        local component = self.components[i]
        if component.visible and component.enabled and component.onMouseClick then
            if component:onMouseClick(x, y, button) then
                return true
            end
        end
    end
    return false
end

function GUI:handleMouseDrag(x, y, button)
    for _, component in ipairs(self.components) do
        if component.visible and component.enabled and component.onMouseDrag then
            component:onMouseDrag(x, y, button)
        end
    end
end

function GUI:handleMouseUp(x, y, button)
    for _, component in ipairs(self.components) do
        if component.onMouseRelease then
            component:onMouseRelease()
        end
    end
end

-- Utility functions
function GUI:showMessage(title, message, type)
    type = type or "info"
    local color = self.COLORS.INFO
    
    if type == "error" then
        color = self.COLORS.ERROR
    elseif type == "warning" then
        color = self.COLORS.WARNING
    elseif type == "success" then
        color = self.COLORS.SUCCESS
    end
    
    local window = self:createWindow(title, 40, 10)
    window.modal = true
    
    local panel = window:addComponent(self:createPanel(window.x + 4, window.y + 6, window.width - 8, window.height - 8))
    panel.background = color
    panel.border = false
    
    -- Add message text
    local lines = {}
    for line in message:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    
    for i, line in ipairs(lines) do
        self:drawText(window.x + 6, window.y + 7 + i, line, self.COLORS.TEXT_PRIMARY)
    end
    
    local ok_button = window:addComponent(
        self:createButton(window.x + window.width - 12, window.y + window.height - 4, 8, 2, "OK", "primary")
    )
    
    ok_button.onclick = function()
        window.visible = false
    end
    
    return window
end

-- Animation helpers
function GUI:animateProperty(component, property, target_value, duration, callback)
    -- Simple animation system
    local start_value = component[property]
    local start_time = os.epoch("utc")
    local end_time = start_time + duration * 1000
    
    local function updateAnimation()
        local current_time = os.epoch("utc")
        if current_time >= end_time then
            component[property] = target_value
            if callback then callback() end
            return
        end
        
        local progress = (current_time - start_time) / (duration * 1000)
        component[property] = start_value + (target_value - start_value) * progress
        
        -- Schedule next update
        os.startTimer(0.05)
    end
    
    updateAnimation()
end

return GUI