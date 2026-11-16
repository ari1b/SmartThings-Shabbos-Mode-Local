# Compact next-two-events display

## In-place repair for literal headings or blank values

If you already registered and installed the first compact display, keep your existing folder and capability ID. From this updated ZIP, copy **only the entire `repair` folder** into your existing `shabbos-compact-display` project folder.

If logcat is running, press Ctrl+C to return to PowerShell. From your existing project folder run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\repair\Repair-Compact-Display.ps1
```

The script copies only the two display-related Lua files and presentation JSON, preserves `display_config.lua` and your profile, updates the **existing** capability presentation, then runs the private-channel install helper. Paste your private channel UUID when prompted. **Do not run Setup-Display.ps1 again for this repair.**

Reopen SmartThings and pull down to refresh the existing device. Headings should be **Next event** and **Following event**. Values now contain the date and local time on short lines, for example **ON 11/20** and **4:15 PM**. A ~ prefix means disabled preview; * means a manual-override return.

The repair replaces local attempted-event caching with comparison to SDK-reported state, retries missing values and forcibly resends all fields on Refresh/profile updates. It also reloads the capability definition on an explicit refresh and reports missing profile support instead of silently skipping it. These changes address the observed empty-value path without changing scheduling.

With logcat open, Refresh should print **Display build compact-fix-1; sent values ...**. If the driver cannot emit the values, it now prints the actual display error on each explicit refresh. If the values remain blank, share that output. Firmware acceptance and phone rendering still need the live check.

Version 1.2 uses fixed headings and compact two-line values showing ON/OFF, month/day and the local time. It also shows the following event. No calendar or scheduling rewrite was needed.

Illustrative arrangement (your times depend on your settings):

| Next event | Following event |
| --- | --- |
| ON 11/20 · 4:15 PM | OFF 11/21 · 5:45 PM |

SmartThings controls font size and column widths. This update shortens the text rather than trying to set a font size. Each time line has at most eight characters; the action/date is on its own short line. Actual rendering must still be checked on your phone.

## 1. Extract into a new folder

Save **shabbos-compact-display.zip** in Downloads, then run:

```powershell
Expand-Archive -LiteralPath "$HOME\Downloads\shabbos-compact-display.zip" -DestinationPath "$HOME\Documents"
Set-Location "$HOME\Documents\shabbos-compact-display"
```

This uses a different folder from the previous `shabbos-next-display` package. Leave the previous folder and its registered capability files intact. No in-place repair or copying over your existing source is required.

## 2. Register the separate compact display capability

Run from the new folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Setup-Display.ps1
```

This registers **Shabbos Next Events** under your Samsung account, creates its two-cell presentation and fills the returned capability ID into this driver's source/profile. Repeat runs reuse `capabilities/registered-compact-capability.json`. The previous Shabbos Schedule Display capability is not modified or deleted.

Registration is required once because this display has additional read-only fields. Registration alone does not change the working driver on your hub. Shared-channel users will not need registration or PowerShell after you publish the new driver.

## 3. Install through your private channel

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-For-Testing.ps1
```

Paste only your **Shabbos Local Private** channel UUID when asked. Select your home hub if prompted. This uploads and installs through that private channel; it does not publish to the public channel.

**Keep the existing Shabbos Mode Local device and routines. Do not delete it or scan for another switch.** The driver keeps the package key, device network ID, main component, switch capability and preference names. It requests the **shabbos-mode-local.v3** profile for the same device.

## 4. Check the two cells

Close/reopen SmartThings and refresh the existing device page. Check that:

- The **Shabbos Next Events** card has two cells: next transition on the left, following transition on the right.
- Fixed headings read **Next event** and **Following event**.
- Each value contains a short action/date line, such as **ON 11/20**, and a short local-time line such as **4:15 PM**.
- Your saved coordinates, offsets, holiday settings and Automatic scheduling value remain correct.
- Display timezone is appropriate; its default is America/New_York, with automatic EST/EDT handling for the date of each event.

When scheduling is OFF, values start with **~** to mark a preview. If an opposite manual override expires before the next natural event, its return appears first with a **\*** prefix, followed by the next natural event. Refresh cancels a manual hold as before.

The long diagnostic next-transition/status attributes are retained internally, but are not shown as large app values. Only two compact event cells are in the presentation.

Allow time for capability presentation/profile propagation. If labels appear literally as template text, fields are blank, or the result is still clipped, share a screenshot and log rather than deleting the device. The actual firmware/app rendering has not been validated on your phone yet.

## 5. Publish after verifying it locally

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Publish-Shared.ps1
```

Paste your public **Shabbos Mode Local** channel UUID. The script uploads and assigns the new version without installing it on other hubs. The existing invitation URL is unchanged:

https://bestow-regional.api.smartthings.com/invite/JVMk7zqNPkMG

After registration fills in the real compact capability ID, update the corresponding source, capability definitions and README on GitHub. Replace `driver/profiles/shabbos-mode-local.yaml`; its internal profile name is now v3. Normal shared-channel users need no capability registration.

## Scope and verification

- Calendar, solar and schedule modules match the previous baseline byte-for-byte.
- The display uses the existing schedule API to obtain the following event once and cache it. It adds no new timer or extra schedule calculation on unchanged minute checks.
- Device identity and routine triggers stay the same.
- Timezone handling, disabled previews, manual override deadlines and display-error isolation are retained.

Tests cover chronological event order, compact time lengths, caching, DST, profile migration and the existing calendar checks. A separate private-channel test is still needed to verify the mobile UI.

Optional developer tests:

```text
python -m pip install lupa pyluach astral pyyaml tzdata
python tests/test_reference.py
python tests/run_driver_test.py
python tests/test_display.py
```

Offline PowerShell verification uses a fake CLI and does not contact SmartThings:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\test_setup.ps1
```
