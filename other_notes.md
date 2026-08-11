## COMMAND_LONG's fields, explained

COMMAND_LONG is a generic "do this thing" envelope — one packet shape reused for dozens of different actions, so it needs to carry: *who it's for*, *what to do*, and *the specific numbers that action needs*.

| Field | What it means |
|---|---|
| **target_system** | Which system (device) this command is meant for — e.g. `1` for the flight controller, so the command doesn't get accidentally interpreted by some other device listening on the same network. |
| **target_component** | Which specific component within that system — e.g. the flight controller itself, as opposed to a camera or gimbal that might also live under the same system ID. |
| **command** | The MAV_CMD number — this is the actual instruction, like "arm the vehicle" (400) or "return to launch" (20). This is the field that gives the packet meaning; everything else is context/parameters for it. |
| **confirmation** | A counter used only when *resending* the same command (e.g. if you didn't get an ACK back) — 0 for the first send, incremented on retries, so the receiver can tell a retry apart from a brand new duplicate request. |
| **param1 through param7** | Seven generic numeric slots, each meaning something different *depending on which command you picked*. For MAV_CMD_COMPONENT_ARM_DISARM, param1 means "1 = arm, 0 = disarm" and param2–7 go unused (set to 0). For a different command, param1 might mean something completely different. Think of these like a function's arguments — their meaning depends entirely on which "function" (command) you're calling. |

So the whole packet reads like: *"Hey system 1, component 1 — execute command 400 (arm/disarm), with param1 = 1 (meaning: arm)."* Same envelope, different command number and different param meanings, reused for arm, RTL, and dozens of other actions.

## Direction: who sends what

| Message | Sent by | Why |
|---|---|---|
| HEARTBEAT | **Both** | Every connected system announces itself once/sec, regardless of role |
| SYS_STATUS | **Drone** | Only the drone knows its own battery/sensor health |
| GLOBAL_POSITION_INT | **Drone** | Only the drone knows its own GPS position/altitude |
| COMMAND_LONG | **Your app** | You're the one requesting an action (arm, RTL) |
| COMMAND_ACK | **Drone** | The drone responds, confirming whether your command succeeded |
| SET_MODE | **Your app** | You're requesting a mode change |
| MANUAL_CONTROL | **Your app** | You're the one sending joystick input |

Clean way to remember it: **telemetry always flows drone → app** (the drone reporting on itself), and **commands/control always flow app → drone** (you telling it what to do), with COMMAND_ACK being the one exception that flows backward specifically to confirm a command worked.

## Full field breakdown, message by message

**HEARTBEAT** (sent by both)
- `type` — what kind of vehicle this is (quadcopter, fixed-wing, or "ground control station" if it's your app describing itself)
- `autopilot` — which autopilot firmware (ArduPilot, PX4, etc.)
- `base_mode` — a set of flag bits, one of which indicates armed/disarmed
- `custom_mode` — a number meaning a specific flight mode, interpreted according to whichever autopilot sent it (ArduPilot's numbering differs from PX4's)
- `system_status` — general state (booting, standby, active, critical, emergency, etc.)

**SYS_STATUS** (drone only)
- `voltage_battery` — battery voltage, in millivolts
- `current_battery` — current draw, in centiamps
- `battery_remaining` — remaining battery, as a percentage
- `onboard_control_sensors_health` — bitmask flags showing which sensors are currently healthy/unhealthy

**GLOBAL_POSITION_INT** (drone only)
- `lat`, `lon` — latitude/longitude, in degrees × 10⁷ (an integer-scaled format to avoid floating-point precision issues)
- `alt` — altitude above sea level, in millimeters
- `relative_alt` — altitude relative to takeoff point, in millimeters (usually the more useful one for display)
- `vx`, `vy`, `vz` — velocity components, in cm/s
- `hdg` — heading, in centidegrees (compass direction it's facing)

**COMMAND_LONG** (app only) — covered in detail above: target_system, target_component, command, confirmation, param1–7.

**COMMAND_ACK** (drone only)
- `command` — which command number this is acknowledging
- `result` — a result code: accepted, temporarily rejected, denied, unsupported, failed, or in-progress

**SET_MODE** (app only)
- `target_system` — which system should change mode
- `base_mode` — mode-related flag bits (includes a flag meaning "use the custom_mode field," since some autopilots support standard modes without it)
- `custom_mode` — the specific ArduPilot mode number you're requesting

**MANUAL_CONTROL** (app only)
- `target` — which system this control input is meant for
- `x` — pitch input
- `y` — roll input
- `z` — throttle input
- `r` — yaw input
- `buttons` — a bitmask for any auxiliary button states (often unused/zero in a basic implementation)

Want me to add this expanded field-level detail into the glossary reference file so it's all in one place, or keep the file as the condensed version and use this message as your deeper-dive notes?