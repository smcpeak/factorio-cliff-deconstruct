-- data.lua
-- Modify data tables for Cliff Deconstruct.

-- This controls the appearance of the placed ghost entity
-- as well as the preview ghost held under the mouse cursor.
local function cliff_explosive_picture()
    if settings.startup["cliff-deconstruct-show-area-of-effect"].value then
        -- I have added a yellow border that shows the box where the
        -- explosives do damage (assuming the default capsule action
        -- radius of 1.5).  Any cliff whose collision rectangle
        -- intersects the yellow square will be destroyed.
        return {
            filename = "__CliffDeconstruct__/graphics/cliff-explosives-3x.png",
            width = 96,
            height = 96
        };
    else
        return {
            filename = "__base__/graphics/icons/cliff-explosives.png",
            width = 32,
            height = 32
        };
    end;
end;

data:extend(
    {
        -- This proxy entity is only meant to be created as a ghost.
        -- It marks the spot where a cliff is to be destroyed.
        {
            name = "cliff-explosive-proxy",
            type = "container",
            icon = "__base__/graphics/icons/cliff-explosives.png",
            icon_size = 32,
            inventory_size = 16,
            flags = {"not-on-map", "placeable-off-grid", "player-creation"},
            collision_mask = {"doodad-layer", "not-colliding-with-itself"},
            picture = cliff_explosive_picture(),
            selectable_in_game = true,
            selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
        }
    }
)

-- This line says that the proxy can be created from the cliff-explosive item.
-- Thus, when we create a ghost of a proxy, it informs nearby robots they need
-- to retrieve a cliff-explosive item, carry it to the spot, and then consume
-- it in order to build the proxy.  All of that just uses the normal blueprint
-- construction logic once the association is established.
--
-- Then, when the proxy is built by a robot, code in control.lua converts it
-- into an explosion that destroys the cliffs.
--
-- The "cliff-explosive" inventory item happens to be in the "capsule" category
-- in data.raw because it is deployed by throwing.
--
-- This also makes the game regard cliff-explosives as a thing that can be
-- placed into the world.  That in turn has three interesting effects:
--
-- 1. The player can click nearby to place one.  In that case, code in control.lua
-- immediately "refunds" the explosives, so it appears that nothing happened.
--
-- 2. The player can shift-click anywhere to place a proxy ghost.  Robots will
-- then try to build it, either destoying cliffs there or refunding the explosive.
--
-- 3. When holding cliff-explosives in hand, the icon is partially transparent
-- when beyond build distance, indicating that ordinary placement is impossible
-- but shift-clicking is.  This is unfortunate, as that distance is irrelevant
-- and potentially confusing, since ordinary clicking on cliffs is still possible,
-- per the "capsule" behavior aspect, if within the capsule deployment radius.
data.raw["capsule"]["cliff-explosives"].place_result = "cliff-explosive-proxy"

-- This is a bug fix for base Factorio, somewhat randomly included in this mod.
-- Early versions of 0.16 had explosives.png (red) instead of cliff-explosives.png
-- (blue).  It was fixed sometime between 0.16.5 and 0.16.35, so when running a
-- recent version of Factorio, this line has no effect.
data.raw["projectile"]["cliff-explosives"].animation.filename = "__base__/graphics/icons/cliff-explosives.png"
