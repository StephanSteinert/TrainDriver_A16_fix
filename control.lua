require "util"
require "utils.set"
require "utils.train"

function init_player_table(player_index)
    global.active_texts[player_index] = global.active_texts[player_index] or {}

    if global.directions_active[player_index] == nil then
        global.directions_active[player_index] = true
    end
end

-- Create flying text for given player
function make_flying_text(text, pos, player_index)
    local player = game.players[player_index]
    local fly    = player.surface.create_entity{
        name     = "flying-text",
        text     = text,
        color    = player.color,
        position = pos
    }
    fly.active   = false    

    table.insert(global.active_texts[player_index], fly)
    
    return fly
end

-- destroy all flying texts for given player
function erase_current_marks(player_index)
    for active_text_id, active_text in pairs(global.active_texts[player_index]) do
        if active_text.valid then
            active_text.destroy()
        end
        
        table.remove(global.active_texts[player_index], active_text_id)
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

function find_rail(player, train, front_rail, fwd_dir, depth)
    if depth > 10 then
        -- too far away
        return
    end

    local player_index  = player.index
    local fwd_straight  = front_rail.get_connected_rail{rail_direction = fwd_dir, rail_connection_direction = defines.rail_connection_direction.straight}
    local fwd_left      = front_rail.get_connected_rail{rail_direction = fwd_dir, rail_connection_direction = defines.rail_connection_direction.left}
    local fwd_right     = front_rail.get_connected_rail{rail_direction = fwd_dir, rail_connection_direction = defines.rail_connection_direction.right}
    local present_count = 0
    local present_val   = nil
    
    if fwd_straight then
        present_val   = fwd_straight
        present_count = present_count + 1
    end
    
    if fwd_left then
        present_val   = fwd_left
        present_count = present_count + 1
    end
    
    if fwd_right then
        present_val   = fwd_right
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
        
        return find_rail(player, train, present_val, new_fwd_dir, depth + 1)
    end
    
    if fwd_straight and player.mod_settings["train_driver_show_straight"].value then
        make_flying_text({"message.train_driver_straight"}, fwd_straight.position, player_index)
    end
    
    local carriage_type = get_carriage_type(train, player.vehicle)

    if fwd_left then
        if (train.speed >= 0 and carriage_type == "front_mover") or (train.speed <= 0 and carriage_type == "back_mover") or carriage_type == "carriage" then
            make_flying_text({"message.train_driver_left"}, fwd_left.position, player_index)
        else
            make_flying_text({"message.train_driver_right"}, fwd_left.position, player_index)
        end
    end

    if fwd_right then
        if (train.speed >= 0 and carriage_type == "front_mover") or (train.speed <= 0 and carriage_type == "back_mover") or carriage_type == "carriage" then
            make_flying_text({"message.train_driver_right"}, fwd_right.position, player_index)
        else
            make_flying_text({"message.train_driver_left"}, fwd_right.position, player_index)
        end
    end
end

function print_directions()
    for _, player in pairs(game.players) do
        local player_index = player.index

        init_player_table(player_index)

        if global.directions_active[player_index] == false then 
            erase_current_marks(player_index)
            return 
        end
        
        if player.vehicle == nil or 
           (player.vehicle.type ~= "locomotive" and player.vehicle.type ~= "cargo-wagon") or 
           player.vehicle.train == nil or 
           not player.vehicle.train.manual_mode then
            erase_current_marks(player_index)
            return
        end

        local train      = player.vehicle.train
        local front_rail = nil
        local fwd_dir    = nil

        erase_current_marks(player_index)
        if train.speed > 0 then
            find_rail(player, train, train.front_rail, train.rail_direction_from_front_rail, 0)
        end

        if train.speed < 0 then
            fwd_dir = train.rail_direction_from_back_rail
    
            if fwd_dir == defines.rail_direction.front then
                fwd_dir = defines.rail_direction.back
            else
                fwd_dir = defines.rail_direction.front
            end

            find_rail(player, train, train.back_rail, fwd_dir, 0)
        end

        if train.speed == 0 then
            find_rail(player, train, train.front_rail, train.rail_direction_from_front_rail, 0)

            fwd_dir = train.rail_direction_from_back_rail
            if fwd_dir == defines.rail_direction.front then
                fwd_dir = defines.rail_direction.back
            else
                fwd_dir = defines.rail_direction.front
            end
            find_rail(player, train, train.back_rail, fwd_dir, 0)
        end
    end
end

function init()
    global.active_texts      = global.active_texts or {}
    global.directions_active = global.directions_active or {}
end

script.on_init(init)
script.on_configuration_changed(init)

script.on_nth_tick(10, function(event)
    print_directions()
end)

-- Toogle display of directions with key combo
script.on_event("train_driver_directions", function(event)
    local player_index = event.player_index

    if global.directions_active[player_index] == true then
        global.directions_active[player_index] = false
        game.players[player_index].print({"message.train_driver_disabled"})

        erase_current_marks(player_index)
    else
        global.directions_active[player_index] = true
        game.players[player_index].print({"message.train_driver_enabled"})
    end
end)
