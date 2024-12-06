-- Define the base class
BaseClass = {}
BaseClass.__index = BaseClass

function BaseClass:new()
    local instance = setmetatable({}, self)
    return instance
end

function BaseClass:getValue()
    -- Use rawget to get the value directly from the instance
    return rawget(self, "value")
end

function BaseClass:setValue(val)
    -- Use rawset to set the value directly on the instance
    rawset(self, "value", val)
end

-- Define the derived class
DerivedClass = setmetatable({}, BaseClass)
DerivedClass.__index = DerivedClass

function DerivedClass:new()
    local instance = setmetatable({}, self)
    return instance
end

-- Proxying the value using __index and __newindex
local function proxyTable(instance)
    return setmetatable({}, {
        __index = function(_, key)
            -- Use rawget to get the value from the instance
            return rawget(instance, key)
        end,
        __newindex = function(_, key, value)
            -- Use rawset to set the value on the instance
            rawset(instance, key, value)
        end
    })
end

-- Observer implementation with optimizations
local function Observer(state)
    local observer = {
        state = state, -- Reference to the observed state
        callbacks = {}, -- Store callbacks for changes
        force = false, -- For forcing updates
    }

    -- Internal function to notify all callbacks
    local function notify()
        for _, callback in ipairs(observer.callbacks) do
            callback()
        end
    end

    -- Cleanup method for releasing resources
    local function cleanup(self)
        self.callbacks = nil -- Remove references to callbacks
        self.state = nil -- Remove reference to state
    end

    -- Metatable for the observer
    setmetatable(observer, {
        __index = {
            onChange = function(self, callback)
                table.insert(self.callbacks, callback)
                -- Return a function to disconnect the specific callback
                return function()
                    for i, cb in ipairs(self.callbacks) do
                        if cb == callback then
                            table.remove(self.callbacks, i)
                            break
                        end
                    end
                end
            end,
            onBind = function(self, callback)
                callback() -- Immediately trigger the callback
                return self:onChange(callback)
            end,
            update = function(self, newValue)
                -- Use rawset directly to set the value, bypassing comparison logic
                rawset(self.state, "value", newValue)
                notify() -- Notify observers directly
            end,
            forceUpdate = function(self)
                -- Force update triggers notify, without checking the value
                self.force = true
                notify()
            end,
            destroy = function(self)
                cleanup(self) -- Explicitly clean up resources
            end,
        },
        __gc = function(self)
            cleanup(self) -- Cleanup when garbage collected
        end,
    })

    return observer
end

-- State object to encapsulate the value
local function State(initialValue)
    local state = { value = initialValue }
    setmetatable(state, {
        __index = function(_, key)
            if key == "get" then
                return function()
                    return state.value
                end
            elseif key == "set" then
                return function(_, newValue)
                    state.value = newValue
                end
            end
        end,
    })
    return state
end

-- Example Usage
local health = State(100)
local observer = Observer(health)

-- Observe changes
observer:onBind(function()
    print("Health changed to:", health:get())
end)

-- Simulate changes
observer:update(200) -- Fires callback with the new value
observer:update(200) -- Fires again as we bypass the check logic
observer:forceUpdate() -- Forces update regardless of value

-- Explicitly destroy the observer (optional, not required for garbage collection)
observer:destroy()

return {
  State = State,
  Observer = Observer
}
