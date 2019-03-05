require "util"
require "utils.set"
require "utils.train"
require "config"

function onInit()
    global.directions_active = global.directions_active or {}
end

function onConfigurationChanged(data)
    global.directions_active = global.directions_active or {}
end

function init_player_table(player_index)
    if global.active_texts == nil then
        global.active_texts = {}
    end

    if global.active_texts[player_index] == nil then
        global.active_texts[player_index] = {}
    end
end

function make_flying_text(text, pos, player_index)
    local text_color = nil
    
    if cfg_directions_color == nil then
        text_color = game.players[player_index].color
    else
        text_color = cfg_directions_color
    end

    local fly = game.players[player_index].surface.create_entity{
        name="flying-text",
        text=text,
        color=text_color,
        position=pos}
    
    fly.active = false
    
    init_player_table(player_index)
    table.insert(global.active_texts[player_index], fly)
    
    return fly
end

function erase_current_marks(player_index)
    init_player_table(player_index)

    for i = #global.active_texts[player_index], 1, -1 do
        if global.active_texts[player_index][i] and global.active_texts[player_index][i].valid then
            global.active_texts[player_index][i].destroy()
        end
        
        table.remove(global.active_texts[player_index], i)
    end
end

function get_carriage_type(train, carriage)
    for i = 1, #train.locomotives["front_movers"] do
        if train.locomotives["front_movers"][i] == carriage then
            return "front_mover"
        end
    end
    
    for i = 1, #train.locomotives["back_movers"] do
        if train.locomotives["back_movers"][i] == carriage then
            return "back_mover"
        end
    end
    
    return "carriage"
end

function find_rail(player_index, player, train, front_rail, fwd_dir, depth)
    if depth > 10 then
        -- too far away
        return nil
    end

    local fwd_straight = front_rail.get_connected_rail{rail_direction=fwd_dir, rail_connection_direction=defines.rail_connection_direction.straight}
    local fwd_left = front_rail.get_connected_rail{rail_direction=fwd_dir, rail_connection_direction=defines.rail_connection_direction.left}
    local fwd_right = front_rail.get_connected_rail{rail_direction=fwd_dir, rail_connection_direction=defines.rail_connection_direction.right}
    
    local present_count = 0
    local present_val = nil
    
    if fwd_straight then
        present_val = fwd_straight
        present_count = present_count + 1
    end
    
    if fwd_left then
        present_val = fwd_left
        present_count = present_count + 1
    end
    
    if fwd_right then
        present_val = fwd_right
        present_count = present_count + 1
    end
    
    if present_count == 0 then
        -- no further path
        return false
    end
    
    if present_count == 1 then
        -- only one path so we need to go further
        
        -- no idea why is it so, but it helps a lot
        new_fwd_dir = fwd_dir
        
        if (present_val.direction % 2 == 1 and present_val.name == "straight-rail") then
            if fwd_dir == 0 then
                new_fwd_dir = 1
            else
                new_fwd_dir = 0
            end
        end
        
        return find_rail(player_index, player, train, present_val, new_fwd_dir, depth+1)
    end
    
    if fwd_straight and cfg_directions_show_straight then
        make_flying_text(cfg_directions_straight, fwd_straight.position, player_index)
    end
    
    local carriage_type = get_carriage_type(train, player.vehicle)

    if fwd_left then
        if (train.speed > 0 and carriage_type == "front_mover") or (train.speed < 0 and carriage_type == "back_mover") or carriage_type == "carriage" then
            make_flying_text(cfg_directions_left, fwd_left.position, player_index)
        else
            make_flying_text(cfg_directions_right, fwd_left.position, player_index)
        end
    end

    if fwd_right then
        if (train.speed > 0 and carriage_type == "front_mover") or (train.speed < 0 and carriage_type == "back_mover") or carriage_type == "carriage" then
            make_flying_text(cfg_directions_right, fwd_right.position, player_index)
        else
            make_flying_text(cfg_directions_left, fwd_right.position, player_index)
        end
    end
    
    return true
end

function print_directions(player_index, player)
    erase_current_marks(player_index)

    if player.vehicle == nil or (player.vehicle.type ~= "locomotive" and player.vehicle.type ~= "cargo-wagon") or player.vehicle.train == nil or not player.vehicle.train.manual_mode then
        return nil
    end
    
    local train = player.vehicle.train
    
    local front_rail = nil
    local fwd_dir = nil
    
    if train.speed > 0 then
        front_rail = train.front_rail
        fwd_dir = train.rail_direction_from_front_rail
    elseif train.speed < 0 then
        front_rail = train.back_rail
        fwd_dir = train.rail_direction_from_back_rail

        if fwd_dir == defines.rail_direction.front then
            fwd_dir = defines.rail_direction.back
        else
            fwd_dir = defines.rail_direction.front
        end
    else
        return nil
    end

    return find_rail(player_index, player, train, front_rail, fwd_dir, 0)
end


script.on_init(onInit)
script.on_configuration_changed(onConfigurationChanged)

script.on_event(defines.events.on_tick, function(event)
    if event.tick % 10 == 0 then
        global.directions_active = global.directions_active or {}
    
        for i = 1, #game.players do
            if global.directions_active[i] then
                print_directions(i, game.players[i])
            end
        end
    end
end)

script.on_event("train_driver_directions", function(event)
    if global.directions_active[event.player_index] then
        global.directions_active[event.player_index] = false
        erase_current_marks(event.player_index)
        game.players[event.player_index].print("Train maneuver directions disabled.")
    else
        global.directions_active[event.player_index] = true
        game.players[event.player_index].print("Train maneuver directions enabled.")
    end
end)
