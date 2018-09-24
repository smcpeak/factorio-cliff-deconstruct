-- settings.lua
-- Defines configuration settings for CliffDeconstruct.

data:extend({
    -- When true, the mod responds to uses of the
    -- deconstruction planner.  Note that not everything the mod does
    -- can be disabled, however; in particular, whenever the mod is
    -- loaded, the game thinks cliff-explosives can be placed.
    {
        type = "bool-setting",
        name = "cliff-deconstruct-enabled",
        setting_type = "runtime-per-user",
        default_value = true
    }
});

-- EOF
