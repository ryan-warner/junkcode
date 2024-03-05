local DUMMY_THROTTLE_CHANNEL_FUNCTION = 70 -- Throttle
local TRUE_THROTTLE_CHANNEL_FUNCTION = 94 -- Script1
local REVERSE_CHANNEL_FUNCTION = 95 -- Script2

function update()
    local current_throttle_output = SRV_Channels:get_output_pwm(DUMMY_THROTTLE_CHANNEL_FUNCTION)

    if current_throttle_output < 1500 then
        SRV_Channels:set_output_pwm(REVERSE_CHANNEL_FUNCTION, 2000)
        SRV_Channels:set_output_pwm(TRUE_THROTTLE_CHANNEL_FUNCTION, (2 * math.abs(current_throttle_output - 1500)) + 1000)
    else
        SRV_Channels:set_output_pwm(REVERSE_CHANNEL_FUNCTION, 1000)
        SRV_Channels:set_output_pwm(TRUE_THROTTLE_CHANNEL_FUNCTION, (2 * (current_throttle_output - 1500)) + 1000)
    end

    return update, 1
end

return update, 1000 -- Initial delay of 1 second