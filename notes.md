## How you actually know you're "connected" (there's no formal handshake)

This is worth clarifying because it's simpler than it sounds — MAVLink has no special "connect" packet, no handshake step, no login. Here's literally what happens:

1. Your app opens its UDP socket and starts listening.
2. The drone has been broadcasting HEARTBEAT once/second the whole time, connected or not.
3. **"Connected" is just a label your own app assigns itself** based on one simple rule you write: *"if I've received a HEARTBEAT within the last N seconds, I consider myself connected. If not, I consider myself disconnected."*

That's it — there's no official MAVLink concept of "connected" at all. It's a convention your app invents and enforces using the HEARTBEAT's regular arrival as the signal. This is exactly the logic from Monday's connection-loss detection task: a timer that resets every time a HEARTBEAT arrives, and flips to "disconnected" if too much time passes without one.

One extra nuance: **your app should also send its own HEARTBEAT** (once/second, describing itself as `MAV_TYPE_GCS` — a ground control station) back to the drone. This isn't strictly required for you to receive telemetry, but it's the convention every MAVLink tool follows, and some ArduPilot failsafe behavior (like GCS failsafe) specifically depends on *it* seeing a heartbeat from your app — so skipping this could mean the flight controller thinks no ground station is present at all.

## Every field, explained in plain terms + how you'd touch it in Dart

**HEARTBEAT** (sent by both)
- `type` — literally "what kind of thing is this." Your drone sends something like "I'm a quadcopter." Your app, when it sends its own heartbeat, sends "I'm a ground control station." In code: `heartbeat.type == MavType.quadrotor` — you'd mostly just read this to confirm you're talking to a drone, not misuse it further.
- `autopilot` — "which autopilot software am I running." You'd check this once, mostly to confirm you're talking to ArduPilot and not accidentally connected to something else: `heartbeat.autopilot == MavAutopilot.ardupilotmega`.
- `base_mode` — a single number where individual *bits* act like separate on/off switches packed together. One specific bit (128, in binary `10000000`) means "armed." In Dart: `bool armed = (heartbeat.baseMode & 128) != 0;` — the `&` (bitwise AND) checks just that one bit without caring about the others.
- `custom_mode` — just a plain number representing the current flight mode, but you need ArduPilot's own lookup table to know what the number means (e.g., is 5 "Loiter"? You look that up once, then just compare: `if (heartbeat.customMode == 5) currentModeText = "Loiter";`).
- `system_status` — a general health/state label — you'd mostly just display this as-is or use it to show a warning if it says "critical" or "emergency."

**SYS_STATUS** (drone only)
- `voltage_battery` — a raw number in millivolts (thousandths of a volt), because MAVLink avoids sending decimals where possible. In Dart: `double volts = sysStatus.voltageBattery / 1000;` to get a normal-looking number like 11.4V.
- `current_battery` — similar idea, in centiamps (hundredths of an amp): `double amps = sysStatus.currentBattery / 100;`
- `battery_remaining` — this one's already a plain percentage (0-100), no conversion needed: `int batteryPct = sysStatus.batteryRemaining;`
- `onboard_control_sensors_health` — another bitmask, like base_mode, where each bit represents one specific sensor's health. You'd only check specific bits if you care about a particular sensor (e.g., GPS health); for a basic app you might not touch this field at all initially.

**GLOBAL_POSITION_INT** (drone only)
- `lat`, `lon` — GPS coordinates, but multiplied by 10,000,000 and stored as whole numbers, purely so MAVLink doesn't have to send decimal points (avoids some cross-platform floating-point precision issues). In Dart: `double latitude = globalPos.lat / 1e7;`
- `alt` — altitude above sea level, in millimeters: `double altMeters = globalPos.alt / 1000;` — not usually what you display, since sea-level altitude isn't intuitive to a pilot.
- `relative_alt` — altitude relative to wherever the drone took off, also in millimeters — this is the one you'd actually show in your UI ("You are 12 meters up"), since it's the number that makes sense to a person flying.
- `vx`, `vy`, `vz` — how fast it's moving in each direction, in centimeters/second — mostly optional for a basic app, useful if you want to show speed.
- `hdg` — compass heading, in centidegrees (hundredths of a degree): `double heading = globalPos.hdg / 100;` — gives you a normal 0-360 degree value.

**COMMAND_LONG** (app only) — already broken down in detail last message; this is the one you *build* rather than read, e.g. `CommandLong(targetSystem: 1, targetComponent: 1, command: MavCmd.componentArmDisarm, param1: 1)`.

**COMMAND_ACK** (drone only)
- `command` — tells you which command this is a response *to* — important because you might send several commands close together, and need to match this ACK back to the right one: `if (ack.command == MavCmd.componentArmDisarm) { ... }`
- `result` — did it work? In Dart you'd typically branch on this: `if (ack.result == MavResult.accepted) { showSuccess(); } else { showError(ack.result); }`

**SET_MODE** (app only) — you build this one too, when the user taps a mode button: `SetMode(targetSystem: 1, baseMode: 1, customMode: 5)` (5 being whatever ArduPilot's number for your target mode is).

**MANUAL_CONTROL** (app only) — built fresh many times per second while flying: `ManualControl(target: 1, x: pitchValue, y: rollValue, z: throttleValue, r: yawValue, buttons: 0)`, where pitchValue etc. come straight from your virtual joystick widgets' current position.

The pattern across all of this: **telemetry fields, you read and divide/mask to get a usable number. Command/control fields, you construct fresh with the values you want to send.** Nothing here requires memorizing — once you're actually writing the code next week, you'll be looking each field up as you need it; today's goal is just recognizing these names and roughly what they're for when you see them.




Let's go through each piece.

## Confirming the flow — yes, that's right, with one small correction

Correct: the drone broadcasts HEARTBEAT continuously (1/sec), your app listens, and receiving one is what tells your app "we're connected." HEARTBEAT does carry mode, firmware type, and armed status — exactly as you said.

One small correction: **you don't "connect" *by* receiving a heartbeat** — the UDP connection is already open the moment your socket is bound (that part doesn't require anything from the drone). The heartbeat isn't what establishes the connection; it's what your app uses as *proof the connection is actually working*, since a socket can technically be "open" even if nothing is really on the other end. Subtle but worth keeping straight.

## What does your app's own heartbeat send?

The exact same message *shape* as the drone's, just describing your app instead:
- `type` = ground control station (not "quadcopter")
- `autopilot` = essentially "not applicable" (a special "invalid" value, since your app isn't running autopilot firmware)
- `base_mode` / `custom_mode` = largely meaningless for a ground station, typically left at 0
- `system_status` = active

Its entire purpose is just presence — "I'm still here" — not carrying any real information about your app's internal state.

## How often SYS_STATUS and GLOBAL_POSITION_INT are sent

Unlike HEARTBEAT (which has a fixed, standard 1/sec rate), these two **don't have a fixed rate by default** — how often they're sent is configurable on the flight controller side (via stream rate settings, or your app explicitly requesting a rate using MAV_CMD_SET_MESSAGE_INTERVAL from earlier). In practice, telemetry like battery and position is commonly streamed somewhere around 2-5 times per second — fast enough to feel live, not so fast it floods the link. Since this rate is a flight-controller-side setting, it's worth confirming with whoever manages that configuration, or requesting your own rate explicitly from your app so you're not relying on whatever the default happens to be.

## COMMAND_LONG vs. SET_MODE — which button uses which

Clear split:
- **Arm/Disarm button → always COMMAND_LONG** (with MAV_CMD_COMPONENT_ARM_DISARM). There's no SET_MODE equivalent for arming — it's specifically a command, not a mode.
- **Mode-change buttons (Stabilize/Loiter/RTL) → either works**, but they're not quite the same tool: SET_MODE is the original, simpler message just for this purpose. COMMAND_LONG with MAV_CMD_DO_SET_MODE does the same job but comes with a COMMAND_ACK response confirming success/failure, which SET_MODE doesn't give you. **Recommendation: use COMMAND_LONG for mode changes too**, specifically because getting an ACK back means your app can show "mode change failed" instead of just hoping it worked — this fits directly into your Section 6 (safety-critical) design principle of never assuming success silently.

## MANUAL_CONTROL and the joystick question — this simplifies more than you'd expect

Good instinct to ask, but here's the reassuring part: **MANUAL_CONTROL does not use the old "channel" concept at all.** Recall channels (CH1-CH10) were specific to the *transmitter/receiver* system — a low-level numbering scheme. MANUAL_CONTROL is a higher-level MAVLink message with named fields directly: `x` = pitch, `y` = roll, `z` = throttle, `r` = yaw. There's no "which joystick maps to which channel number" question to solve on your end — you just put pitch value into `x`, roll into `y`, and so on; ArduPilot's own code internally knows what to do with each named field. So your left/right virtual sticks map directly to these four named fields, not to any channel number.

**Do you need to configure the drone for this?** This is a fair, real question — and one worth explicitly confirming with your supervisor/team rather than assuming, since it touches flight-controller-side setup (out of your app's scope, per our earlier plan). The short version: ArduPilot needs to be told it's okay to accept manual control input arriving over MAVLink rather than only from a physical RC receiver — this is normal, supported behavior for GCS-based control, but it can depend on things like whether RC failsafe is configured to require a physical receiver present. This is exactly the kind of thing to flag as a setup dependency, similar to how you already flagged the bridge hardware itself.