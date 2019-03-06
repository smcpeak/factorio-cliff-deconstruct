-- control.lua
-- Code to handle various things as they occur while the game is running.

-- When true, log various actions.
local verbose = false;

-- Log something when 'verbose' is true.
local function diagnostic(str)
     if verbose then
         log(str);
     end;
end;

-- Re-read the setting that controls the 'verbose' flag.
local function read_verbose_setting()
    diagnostic("read_verbose_setting started");
    verbose = settings.global["cliff-deconstruct-logging"].value;
    diagnostic("read_verbose_setting finished");
end;

-- Do it once on startup, then afterward in response to the
-- on_runtime_mod_setting_changed event.
read_verbose_setting();
script.on_event(defines.events.on_runtime_mod_setting_changed, read_verbose_setting);

local function box_non_zero(box)
    return box.right_bottom.x - box.left_top.x > 0 and box.right_bottom.y - box.left_top.y > 0;
end;

local function box_around(position, radius)
    return {
        left_top = {x = position.x - radius, y = position.y - radius},
        right_bottom = {x = position.x + radius, y = position.y + radius}
    };
end;

local function point_str(pt)
    return "(" .. pt.x .. "," .. pt.y .. ")";
end;

local function string_contains(haystack, needle)
    return haystack:find(needle, 1, true) ~= nil;
end;

-- https://stackoverflow.com/questions/1252539/most-efficient-way-to-determine-if-a-lua-table-is-empty-contains-no-entries
local function table_is_empty(t)
    return next(t) == nil;
end;

local function table_is_not_empty(t)
    return not table_is_empty(t);
end;

local function is_cliff_end(cliff)
    return string_contains(cliff.cliff_orientation, "none");
end;

-- Insert 'object' into 'map', indexed by 2D 'point'.
-- In this file a map is a 2d array, referenced by position [x][y].
local function map_insert(map, point, object)
    map[point.x] = map[point.x] or {};
    map[point.x][point.y] = object;
end;

-- Get the thing with index 'point' or nil if none.
local function map_lookup(map, point)
    local inner = map[point.x];
    if inner ~= nil then
        return inner[point.y];
    end;
    return nil;
end;

-- True if 'map' contains something with index 'point'.
local function map_contains(map, point)
    return map_lookup(map, point) ~= nil;
end;

-- Remove any existing object indexed by 'point'.
local function map_remove(map, point)
    local inner = map[point.x];
    if inner ~= nil then
        inner[point.y] = nil;
        if (table_is_empty(inner)) then
            -- Remove the now-empty inner map too.
            map[point.x] = nil;
        end;
    end;
end;

-- Return the average of a set of entity positions, presented in an array.
local function midpoint_of_entities(entities)
    if #entities == 0 then
        return { x=0, y=0 };
    else
        local x_sum = 0;
        local y_sum = 0;
        for _, ent in ipairs(entities) do
            x_sum = x_sum + ent.position.x;
            y_sum = y_sum + ent.position.y;
        end;
        return {
            x = x_sum / #entities,
            y = y_sum / #entities
        };
    end;
end;

-- Place a proxy entity at 'position', marking it as a location for
-- robots to place cliff-explosives.
local function place_proxy(force, surface, position)
    diagnostic("      destroying cliffs at " .. point_str(position));

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
            -- For some reason, filtering using "position = position"
            -- does not work.  So, search a tiny area instead.
            area = box_around(position, 0.1),

            name = "entity-ghost",
            ghost_name = "cliff-explosive-proxy",
            force = force
        });
    if (table_is_not_empty(existing_ghosts)) then
        diagnostic("        NOT placing ghost entity there because there already is one");
    else
        diagnostic("        placing ghost entity there");
        surface.create_entity(
            {
                name = "entity-ghost",
                expires = false,
                force = force,
                position = position,
                inner_name = "cliff-explosive-proxy"
            }
        );
    end;
end;

-- Return the box that will be hit by a cliff explosive at 'point'.
local function cliff_explosives_target_box(point)
    return box_around(
        point,
        game.item_prototypes["cliff-explosives"].capsule_action.radius
    );
end;

-- Return true if an explosive at 'point' would hit all of the listed
-- target entities (possibly among others).
local function explosion_hits_targets(surface, point, target_entities)
    -- Get the entities that are hit.
    local hits = surface.find_entities_filtered({
          area = cliff_explosives_target_box(point),
          type = "cliff"
    });

    -- Mark all of the positions that are hit.
    local hit_positions = {};
    for _, entity in pairs(hits) do
        map_insert(hit_positions, entity.position, true);
    end;

    -- Check that all targets are hit.
    for _, target in ipairs(target_entities) do
        if not map_contains(hit_positions, target.position) then
            return false;
        end;
    end;
    return true;
end;

-- If there is a neighbor of 'cliff' in its chain in 'remaining_cliffs'
-- in direction 'dir', add it to the 'neighbors' map.  The added map
-- entry uses 'dir' as the key.
--
-- Return true unless 'dir' is unrecognized.
local function add_neighbor(neighbors, remaining_cliffs, cliff, dir)
    -- Translate 'dir' into an offset where we will look for the neighbor.
    local dx = 0;
    local dy = 0;
    if dir == "north" then
        dy = -4;
    elseif dir == "south" then
        dy = 4;
    elseif dir == "east" then
        dx = 4;
    elseif dir == "west" then
        dx = -4;
    elseif dir == "none" then
        -- We recognize this "direction", but there is no neighbor.
        return true;
    else
        -- Unrecognized direction.
        diagnostic("warning: cliff at " .. point_str(cliff.position) ..
                   " has unrecognized direction: " .. dir);
        return false;
    end;

    local neighbor = map_lookup(remaining_cliffs,
        {x = cliff.position.x + dx, y = cliff.position.y + dy});
    if neighbor ~= nil then
        neighbors[dir] = neighbor;
    end;
    return true;
end;

-- Return a map containing up to two neighbors of 'cliff' that are in
-- 'remaining_cliffs'.
local function neighbors_of(remaining_cliffs, cliff)
    -- Extract the two adjacent directions from the cliff orientation,
    -- which is something like "north-to-east".
    local orientation = cliff.cliff_orientation;
    local sep_start = orientation:find("-to-");
    if sep_start == nil then
        -- Orientation does not have the expected form.
        diagnostic("warning: cliff at " .. point_str(cliff.position) ..
                   " has unrecognized orientation: " .. orientation);
        return {};
    end;
    local dir1 = orientation:sub(1, sep_start-1);
    local dir2 = orientation:sub(sep_start+4);

    -- Add each direction as a neighbor.
    local neighbors = {};
    if add_neighbor(neighbors, remaining_cliffs, cliff, dir1) and
       add_neighbor(neighbors, remaining_cliffs, cliff, dir2) then
        return neighbors;
    else
        -- At least one of the neighbor directions is unrecognized, so
        -- we conservatively will say there are none.
        return {};
    end;
end;

-- Return (arbitrarily) one of the neighbors of 'cliff', or nil if there
-- are no neighbors in 'remaining_cliffs'.
local function neighbor_of(remaining_cliffs, cliff)
    local neighbors = neighbors_of(remaining_cliffs, cliff);
    for _, n in pairs(neighbors) do
        return n;
    end;
    return nil;
end;

local function inner_find_chain_end(remaining_cliffs, chain_elements, cliff, limit)
    -- Fail-safe in case the 'chain_elements' logic gets busted.  Factorio
    -- itself does not provide a safeguard for a runaway script.
    if limit < 1 then
        diagnositc("warning: inner_find_chain_end seems to be hung");
        return cliff;
    end;

    -- Mark 'cliff' as being part of the chain.
    map_insert(chain_elements, cliff.position, cliff);

    -- Examine its neighbors.
    local neighbors = neighbors_of(remaining_cliffs, cliff);

    -- Exclude those already known to be in the chain.
    for k, n in pairs(neighbors) do
        if map_contains(chain_elements, n.position) then
            neighbors[k] = nil;
        end;
    end;

    if table_is_empty(neighbors) then
        -- This is a chain end.
        return cliff;
    else
        -- Continue search from an arbitrary neighbor.
        for _, n in pairs(neighbors) do
            return inner_find_chain_end(remaining_cliffs, chain_elements, n, limit-1);
        end;
    end;
end;

-- Return an endpoint of the chain containing 'cliff'.
local function find_chain_end(remaining_cliffs, cliff)
    return inner_find_chain_end(remaining_cliffs, {}, cliff, 1000)
end;

-- Follow the chain from the end, placing explosives periodically.
--
-- The idea is to reduce the number of used explosives by using two ideas:
--
-- 1. A cliff cannot have zero neighbors (if it would, it too is destroyed).
-- For example, destroying the second and third cliffs in each group of 3
-- leaves the first isolated, and hence destroyed.
--
-- 2. The collision rectangles for nearby cliffs in a chain can often be
-- hit with a single explosion.  Two adjacent cliffs can always be hit by
-- targeting their midpoint, and 3 or even 4 are sometimes possible.  The
-- ability to multi-target is evaluated by testing whether aiming at the
-- midpoint of a group will hit them all.
--
-- On my test map with a representative section of cliffs, these optimizations
-- reduce the number of explosives used from 24 to 12.  This matches my best
-- hand-optimized placement for that example.
local function process_chain_from_end(force, surface, remaining_cliffs, chain_end)
    diagnostic("  process_chain_from_end at " .. point_str(chain_end.position));

    -- This is the first cliff in the portion of the chain that has not
    -- yet been processed.
    local first = chain_end;

    while first ~= nil do
        diagnostic("    first: " .. point_str(first.position));
        map_remove(remaining_cliffs, first.position);

        -- Get the second cliff in the chain.
        local second = neighbor_of(remaining_cliffs, first);
        if second == nil then
            if first == chain_end then
                -- The very first cliff has no neighbor.  Destroy it directly.
                diagnostic("      first in chain has no neighbor");
                place_proxy(force, surface, first.position);
            else
                -- This is the other end, and we already marked its
                -- predecessor for destruction, so it will be destroyed too.
                diagnostic("      last in chain has no neighbor");
            end;
            return;
        end;

        -- We have a second cliff, and will destroy it in this iteration.
        diagnostic("    second: " .. point_str(second.position));
        map_remove(remaining_cliffs, second.position);

        -- Begin accumulating cliffs to directly target in an array,
        -- starting with the second (since the first will be killed by
        -- isolating it).
        local target_cliffs = {second};

        -- Iteration cap for safety.
        local iters = 0;

        while true do
            -- Get the next cliff in the chain.
            local last_cliff = target_cliffs[#target_cliffs];
            local next_cliff = neighbor_of(remaining_cliffs, last_cliff);
            if next_cliff == nil or iters > 1000 then
                if next_cliff == nil then
                    diagnostic("    no next cliff");
                else
                    -- This should only be possible if someone changes
                    -- the cliff-explosive radius to something very large.
                    diagnostic("    warning: hit target accumulation iteration limit!");
                end;

                -- Target the midpoint of the current set.
                place_proxy(force, surface, midpoint_of_entities(target_cliffs));

                -- The chain has ended.
                return;
            end;
            diagnostic("    next: " .. point_str(next_cliff.position));

            -- See if we can add the next cliff to the set of targets to
            -- kill in one shot.
            target_cliffs[#target_cliffs + 1] = next_cliff;
            local aim_point = midpoint_of_entities(target_cliffs);
            diagnostic("      aim_point: " .. point_str(aim_point));
            if explosion_hits_targets(surface, aim_point, target_cliffs) then
                -- Yes, keep the next in the current targets and keep
                -- trying to add more.
                diagnostic("      hits all targets");
                map_remove(remaining_cliffs, next_cliff.position);
            else
                -- No, cannot hit next cliff, revert and stop adding
                -- to this target set.
                target_cliffs[#target_cliffs] = nil;
                diagnostic("      does not hit all, removing next and " ..
                           "shooting at remaining " .. #target_cliffs);

                -- Target the midpoint of the current set.
                place_proxy(force, surface, midpoint_of_entities(target_cliffs));
                break;
            end;

            iters = iters+1;
        end;

        -- The loop ends after we have placed an explosive to kill
        -- everything in 'targets'.  We will now regard whatever follows
        -- the last cliff in that array as the first of the remainder of
        -- the chain.
        local last_cliff = target_cliffs[#target_cliffs];
        first = neighbor_of(remaining_cliffs, last_cliff);
    end;
end;

-- Given a cliff, place explosives along the chain containing it.
local function process_chain_containing(force, surface, remaining_cliffs, cliff)
    diagnostic("  process_chain_containing cliff at " .. point_str(cliff.position));

    -- Start processing from one of the endpoints.
    local chain_end = find_chain_end(remaining_cliffs, cliff);
    process_chain_from_end(force, surface, remaining_cliffs, chain_end);
end;

-- Place explosive proxies owned by 'force' on 'surface' in order to
-- destroy all of the 'cliffs'.
local function place_proxies(force, surface, cliffs)
    -- Build a map from cliff position to cliff entity.
    local remaining_cliffs = {};
    for _, cliff in pairs(cliffs) do
        diagnostic("  found cliff at " .. point_str(cliff.position));
        map_insert(remaining_cliffs, cliff.position, cliff);
    end;

    -- Loop over the cliffs to identify the chains.
    for _, cliff in pairs(cliffs) do
        if map_contains(remaining_cliffs, cliff.position) then
            process_chain_containing(force, surface, remaining_cliffs, cliff);
        else
            -- This cliff was already handled earlier in the loop when
            -- another element of its chain was processed.
        end;
    end;
end;

local function deconstruct_area(box, player, force, surface)
    diagnostic("deconstruct_area: " .. point_str(box.left_top) .. "-" .. point_str(box.right_bottom));
    if box_non_zero(box) then
        local cliffs = surface.find_entities_filtered({area = box, type = "cliff"});
        place_proxies(force, surface, cliffs);
    end;
end;

local function cancel_deconstruct(box, player, force, surface)
    diagnostic("cancel_deconstruct: " .. point_str(box.left_top) .. "-" .. point_str(box.right_bottom));
    if box_non_zero(box) then
        local ghosts =
            surface.find_entities_filtered(
            {
                area = box,
                name = "entity-ghost",
                ghost_name = "cliff-explosive-proxy",
                force = force
            });
        for k, ghost in pairs(ghosts) do
            diagnostic("  removing ghost at (" .. ghost.position.x .. "," .. ghost.position.y .. ")");
            ghost.destroy();
        end;
    end;
end;

script.on_event(
    defines.events.on_player_deconstructed_area,
    function(event)
        local box = event.area;
        local player = game.players[event.player_index];
        local force = player.force;
        local surface = player.surface;

        local enabled = settings.get_player_settings(
            game.players[event.player_index])["cliff-deconstruct-enabled"].value;
        if not enabled then
            diagnostic("CliffDeconstruct is currently disabled, ignoring use of deconstruction planner");
            return;
        end;

        if event.alt then
            cancel_deconstruct(box, player, force, surface);
        else
            deconstruct_area(box, player, force, surface);
        end;
    end
);

script.on_event(
    defines.events.on_robot_built_entity,
    function(event)
        local entity = event.created_entity;
        if entity.name == "cliff-explosive-proxy" then
            diagnostic("robot built cliff-explosive-proxy at " .. point_str(entity.position));

            -- Check to see if the explosion would destroy anything.  It might
            -- not if, for example, destroying nearby cliffs has destroyed the
            -- one this proxy was nominally aimed at.
            if
                table_is_not_empty(entity.surface.find_entities_filtered(
                    {
                        area = cliff_explosives_target_box(entity.position),
                        type = "cliff"
                    }
                ))
            then
                diagnostic("  creating actual explosive");
                entity.surface.create_entity(
                    {name = "cliff-explosives", target = entity, position = entity.position, speed = 100}
                );
            else
                diagnostic("  no cliffs here, returning explosive to the robot");
                event.robot.get_inventory(defines.inventory.robot_cargo).insert({name = "cliff-explosives", count = 1});
            end;
            entity.destroy();
        end;
    end
);

script.on_event(
    defines.events.on_built_entity,
    function(event)
        local entity = event.created_entity;
        if entity.name == "cliff-explosive-proxy" then
            -- This happens when the player has a cliff-explosive in hand and clicks
            -- on nearby ground (within building distance).  A proxy is momentarily
            -- created, then immediately refunded.
            diagnostic("player built a cliff-explosive-proxy; refunding as explosives");
            entity.destroy();
            local player = game.players[event.player_index];
            player.insert({name = "cliff-explosives", count = 1});
        end;
    end
);

script.on_configuration_changed(
    -- This is called when loading a save from a prior version of the mod.
    function()
        diagnostic("CliffDeconstruct on_configuration_changed called");
        if global.placed_explosives then
            -- Versions prior to 0.1.0 used a global array that is no longer
            -- needed, and which grew without bound.  Remove it so as not to
            -- waste space in memory and on disk.
            diagnostic("clearing old placed_explosives");
            global.placed_explosives = nil
        end;
    end
);
