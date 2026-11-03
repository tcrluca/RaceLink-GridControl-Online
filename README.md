# RaceLink GridControl Online

Companion online scripts for the RaceLink GridControl CSP Lua app.

## Diagnostic 0.1.0

`diagnostic.lua` checks whether CSP grants physics permissions to a server-loaded
online script. It displays `physics.allowed` and the availability of the collision
and overlap APIs, and logs changes to `custom_shaders_patch.log`.

It never changes collisions, controls, penalties, files, or car physics. It makes
no network requests and does not collect or transmit driver information.

Add the following to the server's CSP **Extra Options**, replacing 97cd25505c4698ca6e267d85c75deb567f66138f
with the full commit containing the reviewed script:

```ini
[SCRIPT_RACELINK_DIAGNOSTIC]
SCRIPT = https://raw.githubusercontent.com/tcrluca/RaceLink-GridControl-Online/97cd25505c4698ca6e267d85c75deb567f66138f/diagnostic.lua
REQUIRED = 0
REFRESH_PERIOD = 0
```

Preserve existing server script sections and other CSP settings. Save and restart
the test race when convenient, then reconnect. A separate diagnostic panel should
appear near the left side of the screen. `REQUIRED=0` means a download failure
does not make this script mandatory for joining the server.

`allowed=true` confirms the permission query succeeds in this context. It does
not yet demonstrate physical ghosting. `allowed=false` means the permission is
still unavailable in this context. This is a diagnostic release, not a working
online rolling-start collision controller.

To remove the diagnostic, remove only its configuration section and restart the
test race. The installed GridControl app is not modified.

Reference: [CSP online scripts](https://github.com/ac-custom-shaders-patch/acc-extension-config/wiki/Misc-%E2%80%93-Server-extra-options#online-scripts).
