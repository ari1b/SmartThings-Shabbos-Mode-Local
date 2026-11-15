# Shabbos Mode Local — installation guide

Version 1.0 • November 13, 2026

This custom SmartThings Edge driver creates **Shabbos Mode Local**, a virtual switch whose Shabbos/Yom Tov schedule runs on your hub. It calculates the Hebrew calendar and sunset locally, without AWS, PATs, a calendar API, a subscription, or an always-on computer. The computer is needed only to install, update, or troubleshoot it. Initial setup and driver downloads require internet and your Samsung account.

**Test status:** Calendar, solar calculations, simulated lifecycle tests, and an official CLI package build passed. This has **not been installed or tested on a physical SmartThings hub**. Start with the new switch disconnected from your real routines, and verify it before retiring your working setup.

## 1. Install the SmartThings CLI on Windows

You need an Edge-capable SmartThings hub, such as a SmartThings v2/v3 or Aeotec Smart Home Hub. Use the Samsung account that owns that hub. An old v1 hub is not supported by this driver.

1. Open https://github.com/SmartThingsCommunity/smartthings-cli/releases/latest
2. Download the official Windows installer, normally named **smartthings.msi**, and run it.
3. Open a **new PowerShell window** after installing it.
4. Run:

```powershell
smartthings --version
```

The package was built here with CLI 3.0.1. A current CLI should support the same commands. If Windows says the command is not recognized, close and reopen PowerShell; if necessary rerun the installer and check that it added the CLI to PATH.

## 2. Extract this download

Save **shabbos-edge.zip** in your Downloads folder. In PowerShell run:

```powershell
Expand-Archive -LiteralPath "$HOME\Downloads\shabbos-edge.zip" -DestinationPath "$HOME\Documents"
Set-Location "$HOME\Documents\shabbos-edge"
Get-ChildItem
```

You should see **driver**, **channel.json**, **START-HERE.html**, and **README.md**. If your browser renamed the download, use its actual filename in the first command. If Documents is redirected to OneDrive, these commands still use the folder under your Windows user directory; it need not be your redirected Documents folder.

If you already have a folder at that destination, extract somewhere new rather than overwriting your previous copy. To read this guide in a browser, double-click **START-HERE.html**.

## 3. Log in using the CLI's browser flow

```powershell
smartthings locations
```

A browser should open. Sign in to the same Samsung account used in your SmartThings app, approve CLI access, and return to PowerShell. Select the appropriate region if prompted. The command should list your location(s).

**Do not supply a PAT or use `--token`.** The CLI uses its own supported browser authentication. If you previously configured a PAT in the CLI, remove the `token:` setting from its configuration first. On Windows the current documentation places that configuration at `%LOCALAPPDATA%\@smartthings\cli\config.yaml`. Also check whether you set the `SMARTTHINGS_TOKEN` environment variable; remove it from this PowerShell session with `Remove-Item Env:SMARTTHINGS_TOKEN` if it exists. Do not change the token in your working AWS setup yet.

## 4. Create a private driver channel

From the extracted **shabbos-edge** folder, run:

```powershell
smartthings edge:channels:create --input .\channel.json
```

The command creates **Shabbos Local Private** and prints its channel ID. You do not need to copy the ID for the interactive steps below. If prompted to choose an organization, use your personal developer organization/account.

The included channel file uses the MIT license URL as its terms URL. Creating a channel does not publish a public invitation; no public sharing is needed for your own hub. Skip this step on future updates if you already created this channel.

## 5. Enroll your hub

```powershell
smartthings edge:channels:enroll
```

When prompted, choose **Shabbos Local Private** and your home hub. Prompt order can vary by CLI version. If it reports that the hub is already enrolled, continue.

## 6. Upload and install the driver

```powershell
smartthings edge:drivers:package .\driver --install
```

Choose **Shabbos Local Private** and your home hub when prompted. This command packages the source, uploads it under your account, assigns it to your channel, and installs it on the selected hub. It is expected to contact SmartThings during installation. Wait for successful completion and allow a few minutes for the hub to receive the driver.

You can confirm it is installed using:

```powershell
smartthings edge:drivers:installed
```

Choose your hub and look for **Shabbos Mode Local**. The prebuilt **shabbos-mode-local-driver.zip** is also included for convenience; the source-install command above is the recommended path and does not require a separate Lua installation.

## 7. Create the switch in the SmartThings app

1. Open the SmartThings app and select the correct location.
2. Tap **+ → Add device**.
3. Choose **Scan nearby** (some app versions call this **Scan for nearby devices**).
4. Wait for **Shabbos Mode Local** to appear. It may land in **No room assigned**.
5. Open the device and move it to your preferred room.

The driver deliberately creates one switch per hub. Installing the driver by itself does not create the switch; the nearby scan triggers creation. Do not create it with the Advanced Web App's cloud virtual-device tool. If it does not appear, see Troubleshooting below.

## 8. Configure the switch

Open **Shabbos Mode Local → three-dot menu → Settings**. Initially leave **Automatic scheduling OFF**.

| Setting | Initial value / action |
| --- | --- |
| Automatic scheduling | **OFF** while configuring and testing |
| Latitude | Set your address's decimal latitude. Example Bergenfield NJ: **40.9276** |
| Longitude | Set your address's decimal longitude. Example Bergenfield NJ: **-73.9974**; west must be negative |
| Minutes before sunset | **18**, or your chosen candle-lighting offset |
| Minutes after sunset | **72**, or your chosen fixed Havdalah offset |
| Include Yom Tov | **ON** to reproduce Shabbos + Yom Tov behavior |
| Israel holiday calendar | **OFF** for New Jersey; ON for Israel holiday lengths |
| Elevation in meters | **0** for standard sea-level sunset; change only if matching an elevation-adjusted schedule |
| Sunset adjustment minutes | **0** normally; changes both entry and exit times |

Use your actual coordinates rather than assuming the sample is your house. Copy decimal coordinates from a map; use a decimal point, not a comma. The device defaults are an approximate Bergenfield example and have not been obtained from your existing AWS configuration.

No timezone setting is required. Calculations use the geographic Gregorian day and absolute UTC timestamps. DST is handled naturally, without changing offsets twice a year. The driver does not rely on the hub's local timezone to calculate an event; the hub must still have a correct clock.

**Match your old settings:** This v1 supports a fixed number of minutes after sunset. It does not implement a solar-angle or seasonal-minute Havdalah method. Sea-level vs elevation-adjusted sunset, rounding, and different astronomy libraries can produce small differences from a printed calendar or your AWS program. Compare your existing values and preferred calendar before enabling it.

## 9. Test the new switch before changing real routines

With automatic scheduling still OFF and no real routines connected, turn the switch ON and OFF in the app. It should respond like a normal virtual switch.

To inspect calculated transitions, put your computer on the hub's home network and run:

```powershell
smartthings edge:drivers:logcat
```

Enter the hub's LAN IP address if prompted, then choose **Shabbos Mode Local**. If discovery of the hub address fails, use the router's device list to find its IP address, then run the explicit command below, replacing the example address:

```powershell
smartthings edge:drivers:logcat --hub-address 192.168.1.50
```

With logging open, pull down to refresh the device page in the SmartThings app. A summary should appear, for example:

```text
auto=false; calendar=off; next=on at 2026-11-13 21:21:05 UTC; override=none
```

Log times are **UTC**, not local clock times. For the included Bergenfield example with 18 minutes before / 72 minutes after, zero elevation and zero adjustment:

| Transition | Local time in New Jersey |
| --- | --- |
| Friday November 13, 2026: ON | Approximately **4:21 PM EST** |
| Saturday November 14, 2026: OFF | Approximately **5:50 PM EST** |
| Friday November 20, 2026: ON | Approximately **4:16 PM EST** |
| Saturday November 21, 2026: OFF | Approximately **5:45 PM EST** |

**example-transitions-2026-2030.csv** contains the example location's transitions in UTC and New Jersey local time. It is only a reference: changing the device's settings does not update this file.

Now turn **Automatic scheduling ON**. The switch should immediately change to the calculated current state. On a normal weekday it will be OFF; during a Shabbos/Yom Tov interval it will be ON. Tapping it manually with automatic scheduling enabled temporarily overrides it for at most five minutes, or until the next natural transition, whichever is sooner. Refresh immediately cancels an override. With automatic scheduling disabled, the last manually selected output stays until you change it or enable scheduling.

## 10. Connect your routines and retire the AWS trigger

Once the independent switch test and times look right:

1. Keep the old virtual switch for now. Do not delete it or all your routines.
2. Edit each relevant routine's **IF** condition to use **Shabbos Mode Local** instead of the old **Shabbos Mode Switch**. Keep its intended ON/OFF behavior and actions.
3. If your current setup uses two routines to change the location mode, change those two trigger conditions. Other routines using that location mode may be able to stay as they are.
4. Confirm the new switch is currently in the expected state. Editing a routine does not necessarily fire it immediately; apply the appropriate current mode yourself if needed.
5. Disable the AWS EventBridge triggers **Get_Sunset_Activator** and **Run_Shabbos_Mode** once you are satisfied with the replacement. Disable rather than delete them initially, so you can roll back while the old method still works.
6. Observe the next actual entry and exit transitions, and verify the intended devices/mode changes.

The driver changes its **own** switch. It cannot directly operate the old switch or change your location mode without a routine. Using the local switch directly in routine conditions gives the best chance of fully local execution. SmartThings executes a routine locally only when every condition and action supports it; cloud devices/services or location-mode actions must be checked separately. This driver does not make an otherwise cloud-dependent routine local.

## What the calendar includes

- Every Shabbos.
- Rosh Hashanah: both days in both calendars.
- Yom Kippur.
- Sukkos: first day, plus second day in diaspora.
- Shemini Atzeres / Simchas Torah: one day in Israel, two days in diaspora.
- Pesach: first and seventh days, plus second and eighth days in diaspora.
- Shavuos: one day in Israel, two days in diaspora.

Chol Hamoed, Chanukah, Purim, and other fast days are not treated as Yom Tov. When holy days touch, the output stays continuously ON, from before the first sunset through Havdalah after the final day. It does not momentarily turn OFF between them or treat later candle-lighting times as an exit. With Include Yom Tov OFF it schedules Shabbos alone.

## Restart, outage, and error behavior

The driver calculates its current state on startup, checks it every minute, and sets a one-shot timer for the next transition. Timers are rebuilt after a hub or driver restart. A hub that comes back during Shabbos recalculates ON, rather than waiting until the next Friday. A missed exit is also corrected when the hub returns with a valid clock. No device can act while the hub has no power.

Invalid settings or an obviously invalid clock preserve the output, log the error, and retry every minute. The device is marked offline until the problem resolves. Output preservation during a calculation error is intentional; it is not a guarantee about downstream devices' behavior after a power outage. Brief manual overrides are persisted, although an abrupt power cut can lose the most recent datastore write; the calendar itself is recomputed.

Supported operating years are **2026–2099**. Settings accept latitudes **60°S to 60°N** and longitudes **170°W to 170°E**. Do not use this version for polar/high-latitude practice or unusual International Date Line conventions. Its astronomy uses standard apparent sunset, with optional geometric elevation adjustment; it does not model mountains or building shading.

## Updating and removing it

For an update, replace the source files with the new version, then run from the same project folder:

```powershell
smartthings edge:drivers:package .\driver --install
```

Choose the same channel and hub. Keep **packageKey** and the profile name unchanged to preserve the driver's identity and existing switch. If the CLI offers reinstall/update choices, update the existing driver. Do not run the channel-create command again.

To stop automatic control, turn **Automatic scheduling OFF**. That preserves the current output; it does not force it OFF. To remove it entirely, first remove or retarget routines that depend on it, then delete the device in the SmartThings app. The hub's driver list can be used to uninstall the now-unused driver.

## Troubleshooting

**No hub appears in the CLI:** Check the Samsung account, location, hub ownership, hub online status, and Edge support. Account/organization differences can matter.

**A command mentions permissions or login:** Use the browser login flow, not a PAT; confirm you installed the current official CLI. Inspect the actual error before signing up for any paid API plan. Samsung's published policy keeps local Edge driver tooling free.

**Driver installed but no switch:** Confirm Shabbos Mode Local appears in the installed-drivers list for the right hub. Run logcat, then use Add device → Scan nearby again. Device creation needs SmartThings cloud connectivity during setup. Wait 30 seconds between retry scans. Check for the new device in No room assigned and other rooms.

**Settings or the device page fail to load:** Close and reopen the app, confirm the driver install completed, then check logcat. Share the actual error and hub model/firmware when requesting help. Device UI behavior still needs to be verified on your hub.

**Switch goes back after I tap it:** With scheduling ON, manual control lasts no more than five minutes. Disable scheduling if you need unrestricted manual tests. Refresh resumes the automatic state immediately.

**Switch is correct but a light/mode did not change:** Check the routine trigger and target, the routine's enabled state, and whether it requires the cloud. The driver emits state changes when the value changes, not an ON event every minute.

**Time is hours wrong:** Logcat displays UTC. Check longitude's sign and your local UTC/DST offset before adjusting the astronomy settings.

**Time differs by minutes:** Compare coordinates, elevation, entry/exit offsets, and the sunset convention used by the other source. The sunset adjustment moves BOTH entry and exit; changing candle or Havdalah minutes changes only the relevant boundary.

## Files and verification

- **driver/**: Source package to install with the CLI.
- **shabbos-mode-local-driver.zip**: Official CLI-built driver archive, not the outer download ZIP.
- **channel.json**: Personal channel creation input.
- **example-transitions-2026-2030.csv**: Bergenfield example, not a downloaded live schedule.
- **tests/** and **VALIDATION.txt**: Reproducible developer tests and recorded results.
- **LICENSE.txt**: MIT license.

Developer tests require Python packages `lupa`, `pyluach`, `astral`, and `pyyaml`. From this project directory:

```text
python -m pip install lupa pyluach astral pyyaml
python tests/test_reference.py
python tests/run_driver_test.py
smartthings edge:drivers:package ./driver --build-only ./shabbos-mode-local-driver.zip
```

These tests are not required for normal installation. The runtime driver is pure Lua and includes no downloaded third-party runtime dependencies.

## Primary documentation

- SmartThings CLI installation and browser authentication: https://developer.smartthings.com/docs/sdks/cli
- Edge driver channels and installation: https://developer.smartthings.com/docs/devices/hub-connected/driver-channels
- Edge driver structure: https://developer.smartthings.com/docs/devices/hub-connected/driver-components-and-structure
- Local execution requirements for rules: https://developer.smartthings.com/docs/automations/rules
- Free Edge tooling policy: https://blog.smartthings.com/smartthings-updates/smartthings-api-additional-details-for-developers-and-business-partners/
- NOAA/Meeus solar equations and assumptions: https://gml.noaa.gov/grad/solcalc/calcdetails.html
- Original AWS project being replaced: https://github.com/clippycoder/Smartthings-Shabbos-Mode
