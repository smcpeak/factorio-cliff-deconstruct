data:extend(
    {
        {
            name = "cliff-explosive-proxy",
            type = "container",
            icon = "__base__/graphics/icons/cliff-explosives.png",
            icon_size = 32,
            inventory_size = 16,
            flags = {"not-on-map", "placeable-off-grid", "player-creation"},
            collision_mask = {"doodad-layer", "not-colliding-with-itself"},
            picture = {
                filename = "__base__/graphics/icons/cliff-explosives.png",
                width = 32,
                height = 32
            },
            selectable_in_game = true,
            selection_box = {{-0.5, -0.5}, {0.5, 0.5}}
        }
    }
)

data.raw["capsule"]["cliff-explosives"].place_result = "cliff-explosive-proxy"
data.raw["projectile"]["cliff-explosives"].animation.filename = "__base__/graphics/icons/cliff-explosives.png"
