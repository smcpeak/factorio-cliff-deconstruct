

-- Given something that could be a string or an object with
-- a name, yield it as a string.  I use this mainly for the
-- "force" attribute of entities.
function string_or_name_of(e)
  if type(e) == "string" then
    return e;
  else
    return e.name;
  end;
end;

-- Get various entity attributes as a table that can be converted
-- to an informative string using 'serpent'.  The input object, 'e',
-- is a Lua userdata object which serpent cannot usefully print,
-- even though it otherwise appears to be a normal Lua table.
function entity_info(e)
  return {
    name = e.name,
    type = e.type,
    active = e.active,
    health = e.health,
    position = e.position,
    --bounding_box = e.bounding_box,
    valid = e.valid,
    force = string_or_name_of(e.force),
    unit_number = e.unit_number,
  };
end;



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

function dump_placed_explosives(force_name)
    log("  placed_explosives for " .. force_name .. ":")
    for x, column in pairs(global.placed_explosives[force_name]) do
        log("    column " .. x .. ":")
        for y, entity in pairs(column) do
            log("      row " .. y .. ":")
            if (entity.valid) then
                log("        valid: true")
            else
                log("        valid: false")
            end
        end
    end
end

function dump_all_placed_explosives()
    log("  all placed_explosives follow:")
    for force_name, _ in pairs(global.placed_explosives) do
        dump_placed_explosives(force_name)
    end
end

function dump_entity(entity)
    log("      " .. serpent.line(entity_info(entity)))
end

function deconstruct_area(box, player, force, surface)
    log("deconstruct_area: " .. point_str(box.left_top) .. "-" .. point_str(box.right_bottom))
    dump_placed_explosives(force.name)
    if box_non_zero(box) then
        local cliffs = surface.find_entities_filtered({area = box, type = "cliff"})
        for k, cliff in pairs(cliffs) do
            log("  found cliff at " .. point_str(cliff.position))

            -- Temporary proof of concept: we do not need 'placed_explosives'
            -- since we can directly check for existing ghosts.
            local existing_ghosts =
                surface.find_entities_filtered(
                {
                    type = "entity-ghost",

                    -- For some reason, filtering using "position = cliff.position"
                    -- does not work.  So, search a tiny area instead.
                    area = box_around(cliff.position, 0.1),

                    ghost_name = "cliff-explosive-proxy",
                    force = force
                })
            if (#existing_ghosts > 0) then
                log("    existing ghosts:")
                for _, entity in pairs(existing_ghosts) do
                    dump_entity(entity)
                end
            else
                log("    there is NOT already a ghost there")
            end

            if
                ((not global.placed_explosives[force.name][cliff.position.x]) or
                    not (global.placed_explosives[force.name][cliff.position.x][cliff.position.y])) or
                    (not global.placed_explosives[force.name][cliff.position.x][cliff.position.y].valid)
             then
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
                global.placed_explosives[force.name][cliff.position.x] =
                    global.placed_explosives[force.name][cliff.position.x] or {}
                global.placed_explosives[force.name][cliff.position.x][cliff.position.y] = ghost
            else
                log("    NOT placing ghost entity there because there already is one")
            end
        end
    end
    dump_placed_explosives(force.name)
end

function cancel_deconstruct(box, player, force, surface)
    log("cancel_deconstruct: " .. point_str(box.left_top) .. "-" .. point_str(box.right_bottom))
    dump_placed_explosives(force.name)
    if box_non_zero(box) then
        local ghosts = surface.find_entities_filtered({area = box, name = "entity-ghost", force = force})
        for k, ghost in pairs(ghosts) do
            if ghost.ghost_name == "cliff-explosive-proxy" then
                log("  removing ghost at (" .. ghost.position.x .. "," .. ghost.position.y .. ")")
                if global.placed_explosives[force.name][ghost.position.x] then
                    global.placed_explosives[force.name][ghost.position.x][ghost.position.y] = nil
                end
                ghost.destroy()
            end
        end
    end
    dump_placed_explosives(force.name)
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

            dump_all_placed_explosives()
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

function init()
    log("CliffDeconstruct init called")
    global.placed_explosives = global.placed_explosives or {}
    for k, force in pairs(game.forces) do
        global.placed_explosives[force.name] = global.placed_explosives[force.name] or {}
        dump_placed_explosives(force.name)
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
