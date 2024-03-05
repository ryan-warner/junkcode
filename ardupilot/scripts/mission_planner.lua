local MISSION_OUTLINE = {
    --{distance = 0, heading = 0, alt = 0, acceptance_radius = 20, is_landing = false},
    --{ distance = 76,   heading = 270, alt = 30, acceptance_radius = 20, is_landing = false },
    { distance = 100,  heading_change = 60, alt = 30, acceptance_radius = 20, is_landing = false },
    { distance = 60.4, heading_change = 60, alt = 30, acceptance_radius = 20, is_landing = false },
    { distance = 60.8, heading_change = 60, alt = 25, acceptance_radius = 30, is_landing = false },
    { distance = 52.7, heading_change = 0,  alt = 20, acceptance_radius = 30, is_landing = false },
    { distance = 111.1, heading_change = 0, alt = 15, acceptance_radius = 20, is_landing = false },
    -- {distance = 0, heading = 0, alt = 0, acceptance_radius = 0, is_landing = true}, -- Home!
}

-- COMMAND_INT has the following fields:
-- param1, param2, param3, param4, x, y, z, command, target_system, target_component, frame, command, current, autocontinue
-- x, y are lat, long in int
-- z is alt in float
-- command is unsigned 16 bit int

local TARGET_LOCATION = Location()
local LANDING_DIRECTION = 187

local EARTH_RADIUS = 6366707.0195 -- Earth radius in meters

TARGET_LOCATION:lat(334296748)  --7173-- Big int: # * 1e7
TARGET_LOCATION:lng(-841697205) --7185
TARGET_LOCATION:alt(0)

local function back_propagate_waypoint(prev_waypoint, waypoint_content, running_heading, reverse_pattern)
    local new_waypoint = mavlink_mission_item_int_t() -- all ints
    local latitude_offset = -waypoint_content.distance * math.cos(math.rad(((reverse_pattern) and { -waypoint_content.heading_change } or { waypoint_content.heading_change })[1] + running_heading))
    local longitude_offset = -waypoint_content.distance * math.sin(math.rad(((reverse_pattern) and { -waypoint_content.heading_change } or { waypoint_content.heading_change })[1] + running_heading))

    latitude_offset = math.deg(latitude_offset / EARTH_RADIUS)
    longitude_offset = math.deg(longitude_offset / EARTH_RADIUS) /
    math.cos(math.rad(prev_waypoint:x() / 1e7))                                                                -- Have to handle conversion to float

    new_waypoint:x(prev_waypoint:x() + math.floor(latitude_offset * 1e7))                                      -- Back to big int
    new_waypoint:y(prev_waypoint:y() + math.floor(longitude_offset * 1e7))
    new_waypoint:z(waypoint_content.alt)

    new_waypoint:command((new_waypoint.is_landing and { 21 } or { 16 })[1])

    new_waypoint:frame(6)                                   -- MAV_FRAME_GLOBAL_RELATIVE_ALT_INT

    new_waypoint:param2(waypoint_content.acceptance_radius) -- Acceptance Radius is Param2
    return new_waypoint
end

local function add_waypoint(latitude, longitude, altitude, acceptance_radius, waypoint_type, waypoint_number)
    local waypoint = mavlink_mission_item_int_t()
    waypoint:x(latitude)
    waypoint:y(longitude)
    waypoint:z(altitude)
    waypoint:command(waypoint_type)
    waypoint:frame(6)                  -- MAV_FRAME_GLOBAL_RELATIVE_ALT_INT (No need to convert lat long to decimal degrees)
    waypoint:param2(acceptance_radius) -- Should be param2? I think
    waypoint:seq(waypoint_number)
    -- Let's assume everything else is properly initialized
    return waypoint
end

local function build_mission(landing_location, landing_direction)
    local mission_len = #MISSION_OUTLINE
    local mission_len_leading_offset = 2
    local mission_len_trailing_offset = 1
    local reverse_pattern = ((landing_direction < 0) and { true } or { false })[1]
    local running_heading = math.abs(landing_direction) % 360
    local landing_offset = math.abs(landing_direction) // 360 -- Offset in m

    -- size temp mission to mission length + lead and trail
    local temp_mission = {}
    -- set size
    for i = 1, mission_len + mission_len_leading_offset + mission_len_trailing_offset do
        temp_mission[i] = mavlink_mission_item_int_t()
    end
    -- Set length to mission length

    -- Add target loc to mission
    local target_wp = add_waypoint(landing_location:lat(), landing_location:lng(), landing_location:alt(), 20, 21,
        mission_len + mission_len_trailing_offset + mission_len_leading_offset)

    local true_target_wp = back_propagate_waypoint(
        target_wp,
        {
            distance = landing_offset,
            heading_change = 0,
            alt = 0,
            acceptance_radius = 20,
            is_landing = true        
        },
        running_heading,
        reverse_pattern
    )

    -- Shitty way to offset by x meters 
    target_wp:x(true_target_wp:x())
    target_wp:y(true_target_wp:y())

    landing_location:lat(target_wp:x())
    landing_location:lng(target_wp:y())

    -- prepend mission with target location at alt 30
    local lead_in_wp = add_waypoint(landing_location:lat(), landing_location:lng(), 10, 20, 16, 1)
    local home_wp = add_waypoint(landing_location:lat(), landing_location:lng(), 0, 20, 16, 0)

    -- Add to temp mission
    temp_mission[mission_len + mission_len_leading_offset + mission_len_trailing_offset] = target_wp
    
    -- Build mission from target loc, reverse from landing location
    for i = mission_len, 1, -1 do
        local waypoint = back_propagate_waypoint(temp_mission[i + mission_len_leading_offset + 1], MISSION_OUTLINE[i], running_heading, reverse_pattern)
        temp_mission[i + mission_len_leading_offset] = waypoint
        running_heading = running_heading + ((reverse_pattern) and { -MISSION_OUTLINE[i].heading_change } or { MISSION_OUTLINE[i].heading_change })[1]
    end

    temp_mission[2] = lead_in_wp
    temp_mission[1] = home_wp
    
    mission:clear() -- Clear previous mission
    local total_len = mission_len + mission_len_leading_offset + mission_len_trailing_offset
    for i = 1, total_len do
        mission:set_item(i - 1, temp_mission[i])
    end
end

build_mission(TARGET_LOCATION, LANDING_DIRECTION)

-- Mavlink stuff
mavlink:init(1, 12)

local COMMAND_INT = { id = 75,
    fields = {
        {"param1", "<f"}, {"param2", "<f"}, {"param3", "<f"}, {"param4", "<f"},
        {"x", "<i4"}, {"y", "<i4"}, {"z", "<f"}, {"command", "<I2"},
        {"target_system", "<B"}, {"target_component", "<B"}, {"frame", "<B"},
        {"current", "<B"}, {"autocontinue", "<B"}
    }
}

local MAV_CMD_SET_TARGET_LOC = 404

-- Mark for receive
mavlink:register_rx_msgid(75)

-- Block our desired command
mavlink:block_command(MAV_CMD_SET_TARGET_LOC)

-- Utility functions
function decode_header(message)
    -- build up a map of the result
    local result = {}
  
    local read_marker = 3
  
    -- id the MAVLink version
    result.protocol_version, read_marker = string.unpack("<B", message, read_marker)
    if (result.protocol_version == 0xFE) then -- mavlink 1
      result.protocol_version = 1
    elseif (result.protocol_version == 0XFD) then --mavlink 2
      result.protocol_version = 2
    else
      error("Invalid magic byte")
    end
  
    _, read_marker = string.unpack("<B", message, read_marker) -- payload is always the second byte
  
    -- strip the incompat/compat flags
    result.incompat_flags, result.compat_flags, read_marker = string.unpack("<BB", message, read_marker)
  
    -- fetch seq/sysid/compid
    result.seq, result.sysid, result.compid, read_marker = string.unpack("<BBB", message, read_marker)
  
    -- fetch the message id
    result.msgid, read_marker = string.unpack("<I3", message, read_marker)
  
    return result, read_marker
  end


function decode(message)
    local result, offset = decode_header(message)
    if result == nil then
        return nil
    elseif result.msgid ~= 75 then
        return nil
    end
    -- map all the fields out, assuming COMMAND INT!
    for _, v in ipairs(COMMAND_INT.fields) do
        if v[3] then
            result[v[1]] = {}
            for j = 1, v[3] do
                result[v[1]][j], offset = string.unpack(v[2], message, offset)
            end
        else
            result[v[1]], offset = string.unpack(v[2], message, offset)
        end
    end
    return result;
end

function update()
    local msg, chan, ts = mavlink:receive_chan()
    if (msg ~= nil) then
        local parsed_msg = decode(msg)
        if (parsed_msg ~= nil) then
            if parsed_msg.command == 404 then
                TARGET_LOCATION:lat(parsed_msg.x)
                TARGET_LOCATION:lng(parsed_msg.y)
                build_mission(TARGET_LOCATION, parsed_msg.z)
            end
        end
    end

    return update, 1000
end

return update, 1000