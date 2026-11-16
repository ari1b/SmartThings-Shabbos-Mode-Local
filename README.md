# Shabbos Mode Local — installation guide

Version 1.2

This custom SmartThings Edge driver creates **Shabbos Mode Local**, a virtual switch whose Shabbos/Yom Tov schedule runs on your hub. It calculates the Hebrew calendar and sunset locally, without AWS, PATs, a calendar API, a subscription, or an always-on computer.

**[Install Shabbos Mode Local](https://bestow-regional.api.smartthings.com/invite/JVMk7zqNPkMG)**

The shared-channel installation below needs only a browser and the SmartThings app. You do not need PowerShell, the SmartThings CLI, a GitHub download, or your own driver channel for normal installation. Initial setup and driver downloads require internet and your Samsung account.

## 1. Install from the shared channel

You need an Edge-capable SmartThings hub, such as a SmartThings v2/v3 or Aeotec Smart Home Hub. Use the Samsung account that owns that hub. An old v1 hub is not supported by this driver.

1. Open the **[installation link](https://bestow-regional.api.smartthings.com/invite/JVMk7zqNPkMG)**.
2. Sign in to the Samsung account used for your SmartThings hub.
3. Accept the **Shabbos Mode Local** channel invitation.
4. Find the hub you want to use and click **Enroll**.
5. Click **Available Drivers**, select **Shabbos Mode Local**, then click **Install**.
6. Wait for installation to complete and allow a few minutes for your hub to receive the driver.

Enrolling gives your hub access to this channel's driver; it does not move your SmartThings location or change your existing devices and routines. The driver creates its switch in the next step.

**Already using this driver?** Installing the same driver from the shared channel does not create another switch on the same hub or reset the existing switch's coordinates. Keep your working switch; a new installation is not necessary just to view the public invitation. The source-install method is available in the optional appendix for developers and users who want to maintain their own copy.

## 2. Create the switch in the SmartThings app

1. Open the SmartThings app and select the correct location.
2. Tap **+ → Add device**.
3. Choose **Scan nearby** (some app versions call this **Scan for nearby devices**).
4. Wait for **Shabbos Mode Local** to appear. It may land in **No room assigned**.
5. Open the device and move it to your preferred room.

The driver deliberately creates one switch per hub. If a working Shabbos Mode Local switch already exists on this hub, a scan will not create a duplicate. Installing the driver by itself does not create the switch; the nearby scan triggers creation. Do not create it with the Advanced Web App's cloud virtual-device tool. If it does not appear, see Troubleshooting below.

## 3. Configure the switch

Open **Shabbos Mode Local → three-dot menu → Settings**. Initially leave **Automatic scheduling OFF**.

| Setting | Initial value / action |
| --- | --- |
| Automatic scheduling | **OFF** while configuring and testing |
| Latitude | Set your address's decimal latitude. Example NYC, NY: **40.757256** |
| Longitude | Set your address's decimal longitude. Example NYC, NY: **-73.846237**; west must be negative |
| Minutes before sunset | **18**, or your chosen candle-lighting offset |
| Minutes after sunset | **72**, or your chosen fixed Havdalah offset |
| Include Yom Tov | **ON** to reproduce Shabbos + Yom Tov behavior |
| Israel holiday calendar | **OFF** outside Israel; **ON** for Israel holiday lengths |
| Elevation in meters | **0** for standard sea-level sunset; change only if matching an elevation-adjusted schedule |
| Sunset adjustment minutes | **0** normally; changes both entry and exit times |
| Display timezone | **America/New_York** by default; controls only the event display |

Use your actual coordinates. Copy decimal coordinates from a map; use a decimal point, not a comma. The device defaults have not been obtained from your existing configuration.

No timezone setting is required for scheduling. Display timezone changes only the displayed time. Calculations use the geographic Gregorian day and absolute UTC timestamps. DST is handled naturally, without changing offsets twice a year. The driver does not rely on the hub's local timezone to calculate an event; the hub must still have a correct clock.

**Match your old settings:** This v1 supports a fixed number of minutes after sunset. It does not implement a solar-angle or seasonal-minute Havdalah method. Sea-level vs elevation-adjusted sunset, rounding, and different astronomy libraries can produce small differences from a printed calendar.

## Next two events display

The device page uses fixed headings **Next event** and **Following event**. Each value contains a short action/date line and a short local-time line, for example `ON 11/20` and `4:15 PM`. Dates are month/day. The selected Display timezone determines both cells; the timezone can be checked in Settings.

SmartThings controls the font and column sizes. This layout avoids attribute templates in headings and long sentences in values. Each time line has at most eight characters. Actual rendering still depends on the mobile app and accessibility settings.

A **~** prefix indicates a preview while automatic scheduling is OFF. A **\*** prefix indicates return from a manual override. The next actual return from an opposite manual hold appears before the next natural calendar event. Refresh cancels the hold and forcibly resends all display values.

Display timezone defaults to **America/New_York**, with automatic EST/EDT handling for the date of each event. Other supported zones include US Central, Mountain, Pacific, Arizona, Alaska, Hawaii, UK, Central Europe, Israel, Sydney and UTC. Display settings do not change switching calculations.

The calendar and scheduling core are unchanged. The following event is cached until settings or the next event change; it does not add another schedule calculation to unchanged minute checks.

**Existing devices:** Keep the existing device and routines. See **UPGRADE.md** for the in-place repair if the previous compact display showed literal template labels or blank values. The repair uses the registered capability ID already in your local source.

## 4. Test the new switch before changing real routines

With automatic scheduling still OFF and no real routines connected, turn the switch ON and OFF in the app. It should respond like a normal virtual switch.

**Optional: view diagnostic logs.** A computer and the SmartThings CLI are needed only for this diagnostic step; they are not required for normal installation or operation. See the optional appendix for CLI installation. Put the computer on the hub's home network and run:

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

Log times are **UTC**, not local clock times. Compare the next transition with your chosen local calendar, using your configured coordinates, offsets and elevation. Example times from a different location or configuration should not be used to verify your setup.

Now turn **Automatic scheduling ON**. The switch should immediately change to the calculated current state. On a normal weekday it will be OFF; during a Shabbos/Yom Tov interval it will be ON. Tapping it manually with automatic scheduling enabled temporarily overrides it for at most five minutes, or until the next natural transition, whichever is sooner. Refresh immediately cancels an override. With automatic scheduling disabled, the last manually selected output stays until you change it or enable scheduling.

## 5. Connect your routines (and retire the AWS trigger if transitioning from AWS)

For a new setup, create routines with **Shabbos Mode Local ON** and **Shabbos Mode Local OFF** as their respective triggers. Choose the actions you want, such as changing your location mode or controlling selected devices. Test with notification-only actions first if you want to observe the schedule before connecting real controls.

If you are migrating from the original AWS setup, once the independent switch test and times look right:

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

**Shared-channel installation:** When an updated version is published, follow this repository's release instructions. If prompted to install/update from the channel, return to the **[installation link](https://bestow-regional.api.smartthings.com/invite/JVMk7zqNPkMG)**, select your enrolled hub, and use the available driver installation/update action. Keep the existing switch and its settings; creating a second switch is not the update procedure.

**Your own source/private-channel installation:** Download the updated source, then run from its project folder:

```powershell
smartthings edge:drivers:package .\driver --install
```

Choose your own channel and hub. Keep **packageKey** and the profile name unchanged to preserve the driver's identity and existing switch. If the CLI offers reinstall/update choices, update the existing driver. Do not run the channel-create command again. Maintaining your own copy is separate from installing a release through the shared channel.

To stop automatic control, turn **Automatic scheduling OFF**. That preserves the current output; it does not force it OFF. To remove it entirely, first remove or retarget routines that depend on it, then delete the device in the SmartThings app. The hub's driver list can be used to uninstall the now-unused driver.

## Troubleshooting

**No hub appears in the invitation:** Check that you signed in to the Samsung account that owns your hub, and confirm the hub is online and supports Edge drivers. If you are using the optional CLI method, account/organization differences can also matter.

**A command mentions permissions or login:** Use the browser login flow, not a PAT; confirm you installed the current official CLI. Inspect the actual error before signing up for any paid API plan. Samsung's published policy keeps local Edge driver tooling free.

**Driver installed but no switch:** First check whether Shabbos Mode Local already exists on this hub; discovery will not create another copy. Otherwise, confirm you clicked Install after enrolling in the channel, then use Add device → Scan nearby in the correct SmartThings location. If needed, confirm installation in the hub's driver list or use the optional logcat diagnostic. Device creation needs SmartThings cloud connectivity during setup. Wait 30 seconds between retry scans. Check for the new device in No room assigned and other rooms.

**Settings or the device page fail to load:** Close and reopen the app, confirm the driver install completed, then check logcat. Share the actual error and hub model/firmware when requesting help.

**Switch goes back after I tap it:** With scheduling ON, manual control lasts no more than five minutes. Disable scheduling if you need unrestricted manual tests. Refresh resumes the automatic state immediately.

**Switch is correct but a light/mode did not change:** Check the routine trigger and target, the routine's enabled state, and whether it requires the cloud. The driver emits state changes when the value changes, not an ON event every minute.

**Time is hours wrong:** Logcat displays UTC. Check longitude's sign and your local UTC/DST offset before adjusting the astronomy settings.

**Time differs by minutes:** Compare coordinates, elevation, entry/exit offsets, and the sunset convention used by the other source. The sunset adjustment moves BOTH entry and exit; changing candle or Havdalah minutes changes only the relevant boundary.

## Credits

Thank you to **Rafael** for the original [SmartThings Shabbos Mode project](https://github.com/clippycoder/Smartthings-Shabbos-Mode), which inspired this local version. This driver was built with help from **ChatGPT**.

## Files and verification

- **driver/**: Source package for inspection, development, or optional CLI installation.
- **shabbos-mode-local-driver.zip**: CLI-built archive, if included; a separate build artifact that may not reflect later source edits.
- **channel.json**: Optional private-channel creation input for users maintaining their own copy.
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

## Optional: install your own copy with PowerShell

**Skip this appendix for normal installation.** Use the shared-channel link above unless you specifically want to maintain your own source build. This alternative creates your own private channel and installs your own copy. It is not required to use the public channel.

<details>
<summary>Show Windows CLI and private-channel installation instructions</summary>

### A. Install the SmartThings CLI on Windows

You need an Edge-capable SmartThings hub, such as a SmartThings v2/v3 or Aeotec Smart Home Hub. Use the Samsung account that owns that hub. An old v1 hub is not supported by this driver.

1. Open https://github.com/SmartThingsCommunity/smartthings-cli/releases/latest
2. Download the official Windows installer, normally named **smartthings.msi**, and run it.
3. Open a **new PowerShell window** after installing it.
4. Run:

```powershell
smartthings --version
```

The package was built here with CLI 3.0.1. A current CLI should support the same commands. If Windows says the command is not recognized, close and reopen PowerShell; if necessary rerun the installer and check that it added the CLI to PATH.

### B. Download and extract the source

Save **SmartThings-Shabbos-Mode-Local-main.zip** in your Downloads folder. In PowerShell run:

```powershell
Expand-Archive -LiteralPath "$HOME\Downloads\SmartThings-Shabbos-Mode-Local-main.zip" -DestinationPath "$HOME\Documents"
Set-Location "$HOME\Documents\SmartThings-Shabbos-Mode-Local-main"
Get-ChildItem
```

You should see **driver**, **channel.json**, and **README.md**. If your browser renamed the download, use its actual filename in the first command.

If you already have a folder at that destination, extract somewhere new rather than overwriting your previous copy.

### C. Log in using the CLI's browser flow

```powershell
smartthings locations
```

A browser should open. Sign in to the same Samsung account used in your SmartThings app, approve CLI access, and return to PowerShell. Select the appropriate region if prompted. The command should list your location(s).

**Do not supply a PAT or use `--token`.** The CLI uses its own supported browser authentication. If you previously configured a PAT in the CLI, remove the `token:` setting from its configuration first. On Windows the current documentation places that configuration at `%LOCALAPPDATA%\@smartthings\cli\config.yaml`. Also check whether you set the `SMARTTHINGS_TOKEN` environment variable; remove it from this PowerShell session with `Remove-Item Env:SMARTTHINGS_TOKEN` if it exists. Do not change the token in your working AWS setup yet.

### D. Create your own private driver channel

From the extracted **SmartThings-Shabbos-Mode-Local-main** folder, run:

```powershell
smartthings edge:channels:create --input .\channel.json
```

The command creates **Shabbos Local Private** and prints its channel ID. You do not need to copy the ID for the interactive steps below.

### E. Enroll your hub in your private channel

```powershell
smartthings edge:channels:enroll
```

When prompted, choose **Shabbos Local Private** and your home hub. Prompt order can vary by CLI version. If it reports that the hub is already enrolled, continue.

### F. Upload and install your own copy

```powershell
smartthings edge:drivers:package .\driver --install
```

Choose **Shabbos Local Private** and your home hub when prompted. This command packages the source, uploads it under your account, assigns it to your channel, and installs it on the selected hub. It is expected to contact SmartThings during installation. Wait for successful completion and allow a few minutes for the hub to receive the driver.

You can confirm it is installed using:

```powershell
smartthings edge:drivers:installed
```

Choose your hub and look for **Shabbos Mode Local**. The source-install command above builds the driver from the files you downloaded and does not require a separate Lua installation. If a prebuilt archive is also present, it is a separate build artifact; it may not reflect later source edits.

</details>

## Primary documentation

- SmartThings CLI installation and browser authentication: https://developer.smartthings.com/docs/sdks/cli
- Edge driver channels and installation: https://developer.smartthings.com/docs/devices/hub-connected/driver-channels
- Edge driver structure: https://developer.smartthings.com/docs/devices/hub-connected/driver-components-and-structure
- Local execution requirements for rules: https://developer.smartthings.com/docs/automations/rules
- Free Edge tooling policy: https://blog.smartthings.com/smartthings-updates/smartthings-api-additional-details-for-developers-and-business-partners/
- NOAA/Meeus solar equations and assumptions: https://gml.noaa.gov/grad/solcalc/calcdetails.html
- Original AWS project being replaced: https://github.com/clippycoder/Smartthings-Shabbos-Mode
