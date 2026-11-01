# Get More Ram
A simple [StosSign](https://github.com/stossy11/StosSign) wrapper app that allows you to enable "Increased Memory Limit" for your sideloaded apps without using Xcode.

# Fork changes: more reliable sign in
Signing in needs "anisette data" (a device identity) from an anisette server. Since October 2026, Apple refuses sign ins that use anisette from **Android-based** servers, including upstream's default `ani.sidestore.io`. Those fail with **error -80045** ("This action cannot be completed at this time"), or -80046 after you enter the verification code. This fork:

- Uses only anisette servers backed by real Mac/Windows ADI, which Apple accepts:
  - `new.ani.sidestore.io` ("SideStore (New)")
  - `mac-ani.jkcoxson.com`
  - `ani.jkcoxson.com`
  - `anisette.lillq.me`
  - `win.ani.sidestore.io`
  The list is kept up to date from [SideStore's public server list](https://servers.sidestore.io/servers.json).
- Discards a stored `adi.pb` that an Android server provisioned and provisions a new one on a Mac server. The first sign in after updating may ask for your verification code again.
- Fails over automatically. It tries the server that worked last time first. If that fails, it checks all servers and tries the reachable ones in order. If a server can't read another server's `adi.pb`, it provisions a new one on that server.
- Retries the Apple sign in with fresh anisette from another server when Apple rejects the anisette data, the handshake fails or the connection drops. On -80045 it resets the anisette identity and retries **once**, since repeated attempts can make things worse.
- Never retries a wrong password, a locked account or a 2FA error, and never sends a second 2FA prompt.
- Uses longer, consistent timeouts (15 s) so slow servers don't fail the provisioning step.
- Settings → Anisette Server: leave it empty for automatic (recommended), or enter a custom server, which is tried first with the others as backup. "Test Servers" shows which servers are up. Changes take effect immediately.

If you still get -80045, tap "Clean Up Keychain", reopen the app, and sign in again. If it keeps failing, wait a while before trying again.

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
