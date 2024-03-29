local left = {
    function_num = 77,
    channel = nil,
    min = nil,
    max = nil,
    reversed = nil
}
local right = {
    function_num = 78,
    channel = nil,
    min = nil,
    max = nil,
    reversed = nil
}

local counter = 1

function check_ekf()
    if ahrs:initialised() then
        origin = ahrs:get_origin()
        if origin then
            -- TODO - Remove
            gcs:send_text(0, "Origin: " .. origin:lat() .. ", " .. origin:lng() .. ", " .. origin:alt())


            if origin:alt() == 0 then
                gcs:send_text(0, "Origin altitude is 0, trying again in 0.01 second.")
                return check_ekf, 10
            end
            -- Set home altitude to current ekf origin altitude
            gcs:send_text(0, "Origin altitude: " .. origin:alt())

            -- Find Servo Channels - This should work, little more resilient to shit changing
            left.channel = SRV_Channels:find_channel(left.function_num) + 1
            right.channel = SRV_Channels:find_channel(right.function_num) + 1

            -- Get max and min values of servos
            left.min = param:get("SERVO" .. left.channel .. "_MIN")
            left.max = param:get("SERVO" .. left.channel .. "_MAX")
            left.reversed = ((param:get("SERVO" .. left.channel .. "_REVERSED") == 1) and { true } or { false })[1]

            right.min = param:get("SERVO" .. right.channel .. "_MIN")
            right.max = param:get("SERVO" .. right.channel .. "_MAX")
            right.reversed = ((param:get("SERVO" .. right.channel .. "_REVERSED") == 1) and { true } or { false })[1]

            right.channel = right.channel - 1
            left.channel = left.channel - 1
            -- Wiggle elevons :)
            return wiggle_elevons()
        else
            return check_ekf, 1000
        end
    end
    return check_ekf, 100
end

function wiggle_elevons()
    if counter < 4 then
        if counter % 2 == 0 then
            SRV_Channels:set_output_pwm_chan_timeout(right.channel, right.max, 350)
            SRV_Channels:set_output_pwm_chan_timeout(left.channel,
                ((right.reversed == left.reversed) and { left.min } or { left.max })[1], 250)
        else
            SRV_Channels:set_output_pwm_chan_timeout(right.channel, right.min, 350)
            SRV_Channels:set_output_pwm_chan_timeout(left.channel,
                ((right.reversed == left.reversed) and { left.max } or { left.min })[1], 250)
        end
        counter = counter + 1

        return wiggle_elevons, 350
    else
        return arming_helper, 1000
    end
end

function arming_helper()
    if arming:arm() then
        gcs:send_text(0, "Armed!")
    end
end

return check_ekf, 1000
