# Ride540NB 1.0

Full-screen Connect IQ cycling data field for Garmin Edge 540 / 540 Solar (246 × 322).

## Features

- Large speed and 3-second power, ride averages and lap statistics.
- Heart rate, cadence, ascent, calculated grade and local clock.
- Sprint screen: speed, instantaneous power, cadence, heart rate and ride time. Entry/exit use 3-second power: 600 W entry and below 550 W for 3 s exit by default.
- Speed and distance follow device distance units: km/h + km, or mi/h + mi. Ascent independently follows elevation units: m or ft. Internal calculations remain metric. Speed above 100 in the displayed unit uses integers.
- Automatic dark colors follow the device night-mode flag or black data-field background. No time-of-day guess. All foreground/background color constants use RGB222; firmware controls glyph antialiasing.
- Optional 24-hour clock (default: 12-hour with am/pm). Ride/lap duration formatting is independent.

## Install and upgrade

Copy `Ride540NB.prg` to `GARMIN/APPS`, safely eject and restart. Select a one-field full-screen data page, then Connect IQ → Ride540NB. The application UUID and signing key are retained. Remove the old RideMosaic540.prg or Garmin540RideNB.prg file when replacing it to avoid duplicate copies. Do not delete saved settings unless you want a reset.

## Settings

Connect IQ application settings include 24-hour clock, sprint entry threshold (1–10000 W), automatic sprint screen, exit threshold and signal-loss timeout. The exit threshold is capped at the entry threshold.

On-device settings: UP/DOWN change threshold in 10 W steps; MENU toggles 12/24-hour time; ENTER saves both and shows confirmation. BACK asks before discarding edits. View replacement is used to work around firmware ignoring requestUpdate in data-field settings. This workaround still needs physical-device confirmation.

## Build

Install Connect IQ SDK 9.3.0+ with Edge 540 definitions. Generated fonts are included.

```sh
CIQ_SDK=/path/to/sdk CIQ_KEY=/private/developer.der bash tools/build.sh --tests
$CIQ_SDK/bin/monkeydo bin/Ride540NB-tests.prg edge540 -t
python tools/check_layout.py
```

`CIQ_KEY` must stay private and be reused for future releases. Without it, the script generates a local key under ignored `.keys/`. SDK 9.3.0's gradual checker crashes on this model, so compilation uses `-l 0`. Python/Pillow are only needed to regenerate fonts or render layout previews. Font license: `assets/OFL.txt`.

Export an IQ Store upload package:

```sh
CIQ_SDK=/path/to/sdk CIQ_KEY=/private/developer.der bash tools/export-store.sh
```

## Data limitations

Grade is calculated from distance/altitude observations, not Garmin's native grade field. Lap history is unavailable when loading mid-ride without a stored boundary. Missing power is excluded from the lap average; zero power is included. Firmware averaging settings may differ. Sensor availability depends on paired accessories. Simulator tests do not establish daylight readability, power consumption, physical-device stability or successful settings navigation.
