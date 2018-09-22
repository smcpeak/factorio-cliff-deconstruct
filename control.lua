function box_non_zero(box)
    return box.right_bottom.x - box.left_top.x > 0 and box.right_bottom.y - box.left_top.y > 0
end

function box_around(position, radius)
    return {
        left_top = {x = position.x - radius, y = position.y - radius},
        right_bottom = {x = position.x + radius, y = position.y + radius}
    }
end

function deconstruct_area(box, player, force, surface)
    if box_non_zero(box) then
        local cliffs = surface.find_entities_filtered({area = box, type = "cliff"})
        for k, cliff in pairs(cliffs) do
            if
                ((not global.placed_explosives[force.name][cliff.position.x]) or
                    not (global.placed_explosives[force.name][cliff.position.x][cliff.position.y])) or
                    (not global.placed_explosives[force.name][cliff.position.x][cliff.position.y].valid)
             then
                local ghost =
                    surface.create_entity(
                    {
                        name = "entity-ghost",
                        expires = false,
                        force = force,
                        position = cliff.position,
                        inner_name = "cliff-explosive-proxy"
                    }
                )
                global.placed_explosives[force.name][cliff.position.x] =
                    global.placed_explosives[force.name][cliff.position.x] or {}
                global.placed_explosives[force.name][cliff.position.x][cliff.position.y] = ghost
            end
        end
    end
end

function cancel_deconstruct(box, player, force, surface)
    if box_non_zero(box) then
        local ghosts = surface.find_entities_filtered({area = box, name = "entity-ghost", force = force})
        for k, ghost in pairs(ghosts) do
            if ghost.ghost_name == "cliff-explosive-proxy" then
                if global.placed_explosives[force.name][ghost.position.x] then
                    global.placed_explosives[force.name][ghost.position.x][ghost.position.y] = nil
                end
                ghost.destroy()
            end
        end
    end
end

script.on_event(
    defines.events.on_player_deconstructed_area,
    function(event)
        local box = event.area
        local player = game.players[event.player_index]
        local force = player.force
        local surface = player.surface
        if event.alt then
            cancel_deconstruct(box, player, force, surface)
        else
            deconstruct_area(box, player, force, surface)
        end
    end
)

script.on_event(
    defines.events.on_robot_built_entity,
    function(event)
        local entity = event.created_entity
        if entity.name == "cliff-explosive-proxy" then
            if
                #entity.surface.find_entities_filtered(
                    {
                        area = box_around(
                            entity.position,
                            game.item_prototypes["cliff-explosives"].capsule_action.radius
                        ),
                        type = "cliff"
                    }
                ) > 0
             then
                entity.surface.create_entity(
                    {name = "cliff-explosives", target = entity, position = entity.position, speed = 100}
                )
            else
                event.robot.get_inventory(defines.inventory.robot_cargo).insert({name = "cliff-explosives", count = 1})
            end
            entity.destroy()
        end
    end
)

script.on_event(
    defines.events.on_built_entity,
    function(event)
        local entity = event.created_entity
        if entity.name == "cliff-explosive-proxy" then
            entity.destroy()
            local player = game.players[event.player_index]
            player.insert({name = "cliff-explosives", count = 1})
        end
    end
)

function init()
    global.placed_explosives = global.placed_explosives or {}
    for k, force in pairs(game.forces) do
        global.placed_explosives[force.name] = global.placed_explosives[force.name] or {}
    end
end

script.on_init(init)
script.on_configuration_changed(init)
script.on_event(
    defines.events.on_force_created,
    function(event)
        global.placed_explosives[event.force.name] = global.placed_explosives[event.force.name] or {}
    end
)
