# Get More Ram (ram-6itoon)

A simple [StosSign](https://github.com/stossy11/StosSign) wrapper app that allows you to enable **"Increased Memory Limit"** for your sideloaded apps without using Xcode.

## Fixes included (Oct 2026)

- **Fixed error -80045** and **503 Service Temporarily Unavailable**
  - Default Anisette server changed to `https://ani.jkcoxson.com` (same approach used by [iloader](https://github.com/nab138/iloader))
  - Client-Info / User-Agent are now fetched from the Anisette server (Windows client info that Apple currently accepts)
  - Fallback to known-working Windows headers if the server does not provide them

- **Persian (فارسی) language support** added

## How to use

1. Sideload this app (with SideStore / AltStore / iloader / etc.)
2. Go to **Settings**, sign in with the same Apple ID you used to sign the target app
3. Go to **App IDs** page
4. Tap **Refresh**
5. Tap the app you want to enable "Increased Memory Limit"
6. Tap **Add Increased Memory Limit**
7. Reinstall the app from SideStore / AltStore
8. Check if you have "Increased Memory Limit"

### If login still fails

1. In Settings → **Clean Up Keychain**
2. Change Anisette Server URL if needed (recommended: `https://ani.jkcoxson.com` or `https://ani2.stikstore.app`)
3. Force-close the app and try again
4. Or import your SideStore account (export from SideStore settings)

## Language

The app supports:
- English
- Persian (فارسی) – follows system language

## Credits

- Stossy11 – for StosSign
- SideStore – Anisette Data fetching code originally from SideStore
- nab138 / iloader – for the working Anisette server approach that fixed -80045 / 503
- hugeBlack – original GetMoreRam

## License

Based on the original GetMoreRam project.
