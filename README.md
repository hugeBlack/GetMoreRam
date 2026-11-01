# Get More Ram
A simple [StosSign](https://github.com/stossy11/StosSign) wrapper app that allows you to enable "Increased Memory Limit" for your sideloaded apps without using Xcode.

# Fork changes: more reliable sign in
Signing in needs "anisette data" from an anisette server. Upstream uses one hardcoded server, so sign in fails whenever that server is slow or down. This fork:

- Uses a pool of anisette v3 servers, from [SideStore's public server list](https://servers.sidestore.io/servers.json) plus a bundled fallback list.
- Tries the server that worked last time first. If it fails, it probes every server at once and goes through the reachable ones, fastest and most reliable first, until one works.
- Retries the Apple sign in, up to 3 times, with anisette data from a different server when Apple rejects the anisette data or the connection drops. A wrong password, a locked account or an incorrect 2FA code is never retried, and it never sends a second 2FA prompt.
- Uses longer, consistent timeouts (15 s) so slow servers don't fail the provisioning step.
- Settings → Anisette Server: leave it empty for automatic (recommended), or enter a custom server, which is tried first with the pool as backup. "Test Servers" shows which servers are up and their latency.
- Changing the server in Settings now takes effect immediately; before, it needed an app restart.

Your provisioning data (`adi.pb`) is stored on the device, so switching servers doesn't require signing in again.

# How to use
1. Sideload this app
2. Go to settings, sign in your account that you used to sign the app you want to enable "Increased Memory Limit"
3. Go to "App IDs" page
4. Tap Refresh
5. Tap the app you want to enable "Increased Memory Limit"
6. Tap "Add Increased Memory Limit"
7. Reinstall the app from SideStore/AltStore
8. Check if you have "Increased Memory Limit"

# Credits
Stossy11 - For StosSign.
SideStore - Anisette Data fetching codes are stolen from SideStore
