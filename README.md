# JunkCode

A home for random scripts and utilities that I've written

## Contents
- [ArduPilot](#ardupilot)

## ArduPilot
Lua scripts for use with ArduPilot.

- check_ekf.lua: A script that checks EKF status and wiggles the elevons when the EKF origin is set.
- mission_planner.lua: A script that plans a mission onboard the aircraft based on a received MAVLink message with coordinates and landing direction.
- reverse_thrust.lua: A shitty way to implement innov8tive style reverse thrust with ArduPilot, which expects zero throttle at 1500us. Innov8tive ESCs act on a switch, so we basically read from the throttle channel and do some logic to determine what the real output should be.
