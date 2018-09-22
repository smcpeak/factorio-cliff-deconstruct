function box_non_zero(box)
    return box.right_bottom.x - box.left_top.x > 0 and box.right_bottom.y - box.left_top.y > 0
end

function box_around(position, radius)
    return {
        left_top = {x = position.x - radius, y = position.y - radius},
        right_bottom = {x = position.x + radius, y = position.y + radius}
    }
end

function point_str(pt)
    return "(" .. pt.x .. "," .. pt.y .. ")"
end

function deconstruct_area(box, player, force, surface)
    log("deconstruct_area: " .. point_str(box.left_top) .. "-" .. point_str(box.right_bottom))
    if box_non_zero(box) then
        local cliffs = surface.find_entities_filtered({area = box, type = "cliff"})
        for k, cliff in pairs(cliffs) do
            log("  found cliff at " .. point_str(cliff.position))

            -- Check to see if there is an existing ghost.  Normally there is not
            -- because the base game deconstruction logic clears them.  However, the
            -- 'find_entities' function returns entities that are "nearby", and
            -- existing ghosts for them will not have been cleared.
            --
            -- Alternatively, it might be sufficient to check whether the cliff
            -- position is inside the 'box' area, and ignore if not.
            local existing_ghosts =
                surface.find_entities_filtered(
                {
                    name = "entity-ghost",

                    -- For some reason, filtering using "position = cliff.position"
                    -- does not work.  So, search a tiny area instead.
                    area = box_around(cliff.position, 0.1),

                    ghost_name = "cliff-explosive-proxy",
                    force = force
                })
            if (#existing_ghosts > 0) then
                log("    NOT placing ghost entity there because there already is one")
            else
                log("    placing ghost entity there")
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
            end
        end
    end
end

function cancel_deconstruct(box, player, force, surface)
    log("cancel_deconstruct: " .. point_str(box.left_top) .. "-" .. point_str(box.right_bottom))
    if box_non_zero(box) then
        local ghosts =
            surface.find_entities_filtered(
            {
                area = box,
                name = "entity-ghost",
                ghost_name = "cliff-explosive-proxy",
                force = force
            })
        for k, ghost in pairs(ghosts) do
            log("  removing ghost at (" .. ghost.position.x .. "," .. ghost.position.y .. ")")
            ghost.destroy()
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
            log("robot built cliff-explosive-proxy at " .. point_str(entity.position))
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
                log("  creating actual explosive")
                entity.surface.create_entity(
                    {name = "cliff-explosives", target = entity, position = entity.position, speed = 100}
                )
            else
                log("  no cliffs here, returning explosive to the robot")
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
            log("player built a cliff-explosive-proxy!  refunding as explosives")
            entity.destroy()
            local player = game.players[event.player_index]
            player.insert({name = "cliff-explosives", count = 1})
        end
    end
)

script.on_configuration_changed(
    -- This is called when loading a save from a prior version of the mod.
    function()
        log("CliffDeconstruct on_configuration_changed called")

        if (global.placed_explosives) then
            -- Versions prior to 0.1.0 used a global array that is no longer
            -- needed, but which grew without bound.  Remove it so as not to
            -- waste space in memory and on disk.
            log("clearing old placed_explosives")
            global.placed_explosives = nil
        end
    end
)
