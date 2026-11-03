# RaceLink GridControl Online

## Companion 0.2.1 — no standalone diagnostic overlay

`online.lua` is the server-loaded companion for the installed RaceLink GridControl
app **0.7.8.16.31 or newer**. All participating drivers using rolling ghosting
must update their app. The companion is downloaded automatically when joining a
configured server. This is not an anti-cheat or a replacement for the installed app.

The 0.1.0 diagnostic confirmed that CSP grants physics permissions to the online
script while the installed app remains restricted. The user confirmed the 0.2.0 integration works in the online test. Version 0.2.1
removes only the standalone UI callback; collision and bridge logic are unchanged.
Status remains available in the installed app configuration window and CSP logs.

### Server configuration

For the ACSM test setup, two built-in scripts occupy slots 0 and 1. Replace the
earlier diagnostic section with the following section in **CSP Extra Options**:

```ini
[SCRIPT_2]
SCRIPT = https://raw.githubusercontent.com/tcrluca/RaceLink-GridControl-Online/3b45156843eaa2aed5706aaddf7cd1290076c6da/online.lua
REQUIRED = 0
REFRESH_PERIOD = 0
rollingGhostEnabled = 1
```

Preserve other sections. Use the next unused numeric script slot if slot 2 is
already occupied; do not overwrite another script. Keep the existing CSP minimum
3424, core options D and enabled extra-options support for the current test.
Save, restart the test event when convenient, close Assetto Corsa to load the
updated app and reconnect. No changes to car data or track surfaces are required.
The URL is pinned to a reviewed commit. It does not automatically adopt future code.

Both the server setting above and the app/event's **rolling no collision** option
must be enabled. `rollingGhostEnabled` defaults to false if omitted. `REQUIRED=0`
allows clients to join if download fails; such a client will not receive ghosting.

### Behavior

The app owns event selection and phase calculation. On each client, it sends the
current ghosting request to the companion through a versioned CSP shared-memory
channel. The app does not call physics modification functions online. The companion
acts only on car index 0 and independently checks online/race/replay state, native
permissions and CSP build support.

- Formation, pre-start and Safety Car In: request collision disable.
- Green or option OFF: wait for known separation from all connected cars for 0.5
  seconds, then restore collisions. Unknown overlap data holds restoration.
- Missing app heartbeat for more than 2 simulation seconds: request restoration,
  using the same overlap check. Pausing freezes timers.
- Failed native calls are retried. Unloading the companion attempts to undo its
  own collision change, as in the existing offline controller.

An `ONLINE / DISABLED / LOCAL CAR` status means the native call completed without
an error; verify physical overlap during the controlled test. After green, verify
`NORMAL / RESTORED`. Every participating client must run the updated app and
companion; mismatched clients are not guaranteed to have symmetric collisions.
No network messages, driver data, files or credentials are collected by this module.
The app's local `physics.allowed=false` diagnostic is expected online and does not
describe the companion's permission.

### Rollback

To disable the companion, set `rollingGhostEnabled=0`, save and restart the event.
To return to diagnostics, use `diagnostic.lua` from commit
`97cd25505c4698ca6e267d85c75deb567f66138f` in the same numeric slot and remove
`rollingGhostEnabled`. The installed app and server module must be kept compatible.

Reference: [CSP online scripts](https://github.com/ac-custom-shaders-patch/acc-extension-config/wiki/Misc-%E2%80%93-Server-extra-options#online-scripts).
