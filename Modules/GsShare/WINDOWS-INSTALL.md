# Install G's Avengers on Windows

The Windows app lets the keyboard and mouse of your Windows PC drive your Mac. It is one small program (about 100 KB), installs for your user only, and needs no administrator rights.

**You need:** Windows 10 or 11, the PC and the Mac on the same home Wi-Fi, and G's Avengers already running on the Mac.

## 1. Download

From the [latest release](https://github.com/GauthamWho/GsAvengers/releases/latest), download `GsAvengers-windows-1.0.0.zip`, then right-click it → **Extract All**.

## 2. Install

Open the extracted folder and double-click **`INSTALL.cmd`**. It:

1. builds `GsAvengers.exe` from the source in `src\` with the C# compiler that is already part of Windows (if that is not possible, it uses the ready-made copy in `prebuilt\`),
2. runs a crypto self-test,
3. copies the app to `%LOCALAPPDATA%\GsAvengers`, adds a Start-menu shortcut, starts it with Windows, and opens it.

If you prefer, you can also just double-click `prebuilt\GsAvengers.exe`; it installs itself the same way.

**Windows protection:** the app is not code-signed. If SmartScreen says "Windows protected your PC", click **More info → Run anyway**. If Windows Firewall asks, allow **Private networks** (your home Wi-Fi).

## 3. Pair with the Mac

1. On the Mac, click the **GsA** icon in the menu bar → **Windows sharing**, and make sure **Share keyboard & mouse** is on.
2. The PC finds the Mac by itself within a few seconds. No IP address to type.
3. Both screens show the **same 6-digit number**. Check they match, then click **Numbers match: Pair** on the Mac and **Numbers match — Pair** on the PC.
4. Drag the screens in either window so they match where the Mac sits on your desk (left, right, above or below).

Now move the mouse off that edge of the PC screen: the pointer appears on the Mac, and the PC keyboard types there. Touch the Mac's own trackpad at any time to take the pointer back.

## Uninstall

Open G's Avengers on the PC → **Uninstall…**. It removes the start-with-Windows entry, the shortcut and `%LOCALAPPDATA%\GsAvengers`.

## Trouble?

- **The PC never finds the Mac:** both must be on the same network (not a guest network), and the Windows network must be set to *Private*. Ports used: UDP 4811 (finding) and TCP 4810 (link).
- **Keys don't work in an app on the PC running as administrator:** Windows blocks the hooks there unless G's Avengers also runs as administrator.
- Still stuck? Open an [issue](https://github.com/GauthamWho/GsAvengers/issues). Logs: `%LOCALAPPDATA%\GsAvengers\log.txt` (connection messages only, never your typing).
