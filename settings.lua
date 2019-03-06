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
    },

    -- When true, the mod logs its actions fairly extensively for
    -- diagnostic purposes.
    {
        type = "bool-setting",
        name = "cliff-deconstruct-logging",
        setting_type = "runtime-global",
        default_value = false
    },

    -- When true, the graphics for the cliff explosives include a box that
    -- shows their area of effect (assuming the default radius of 1.5).
    {
        type = "bool-setting",
        name = "cliff-deconstruct-show-area-of-effect",
        setting_type = "startup",
        default_value = false
    },
});
