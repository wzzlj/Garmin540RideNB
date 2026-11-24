using Toybox.Activity;
using Toybox.Application;
using Toybox.Test;

// Regression tests for the v5 audit findings.
(:test)
function auditSlowClimbGrade(logger) {
    Application.Storage.deleteValue("lap");
    var m = new RideModel();
    for (var i = 0; i <= 30; i += 1) {
        var s = new RideSample(i * 1000, i * 1.0, 200);
        s.currentSpeed = 1.0;
        s.altitude = 100.0 + i * 0.1;
        m.update(s, i * 1000);
    }
    logger.debug("3.6 km/h, 10% climb, 30 s: grade=" + m.grade);
    Test.assert(m.grade != null);
    return true;
}

(:test)
function auditMissingTimerClearsLap(logger) {
    Application.Storage.deleteValue("lap");
    var m = new RideModel();
    m.update(new RideSample(0, 0.0, 200), 0);
    m.update(new RideSample(4000, 20.0, 200), 4000);
    m.update(new RideSample(null, 25.0, 200), 5000);
    logger.debug("missing timer: lapTime=" + m.lapTime + " lapSpeed=" + m.lapSpeed);
    Test.assert(m.lapTime == null && m.lapSpeed == null);
    return true;
}

(:test)
function auditIncompleteStoredState(logger) {
    Application.Storage.setValue("lap", {"version" => 1, "ride" => 1700000000});
    var m = new RideModel();
    Application.Storage.deleteValue("lap");
    m.update(new RideSample(5000, 25.0, 200), 0);
    Test.assert(m.lapTime == null);
    return true;
}

(:test)
function auditUnobservedLowPowerGap(logger) {
    var mode = new DisplayMode();
    mode.update(700, 0);
    mode.update(500, 1000);
    mode.update(500, 11000);
    logger.debug("10-second callback gap: high=" + mode.high);
    Test.assert(mode.high);
    return true;
}

(:test)
function auditNegativeGrade(logger) {
    Application.Storage.deleteValue("lap");
    var m = new RideModel();
    m.update(new RideSample(0, 0.0, 200), 0);
    var s = new RideSample(1000, 20.0, 200);
    s.altitude = 98.0;
    m.update(s, 1000);
    Test.assertEqual(m.grade, -10.0);
    return true;
}

(:test)
function auditClockWrapRecovery(logger) {
    var mode = new DisplayMode();
    mode.update(700, 2000000000);
    mode.update(500, 2000001000);
    mode.update(500, -2000000000);
    Test.assert(mode.high);
    mode.update(500, -1999999000);
    mode.update(500, -1999998000);
    mode.update(500, -1999997000);
    Test.assert(!mode.high);
    return true;
}

(:test)
function auditRepeatedTransitions(logger) {
    var mode = new DisplayMode();
    for (var i = 0; i < 1000; i += 1) {
        var t = i * 6000;
        mode.update(600, t);
        Test.assert(mode.high);
        mode.update(549, t + 1000);
        mode.update(549, t + 2000);
        mode.update(549, t + 3000);
        mode.update(549, t + 3999);
        Test.assert(mode.high);
        mode.update(549, t + 4000);
        Test.assert(!mode.high);
    }
    return true;
}

(:test)
function auditLongRideSampleBounds(logger) {
    Application.Storage.deleteValue("lap");
    var m = new RideModel();
    for (var i = 0; i < 3600; i += 1) {
        var s = new RideSample(i * 1000, i * 5.0, 200);
        s.altitude = 100.0 + i * 0.25;
        m.update(s, i * 1000);
        Test.assert(m.powerSamples.size() <= 3);
        Test.assert(m.gradeSamples.size() <= 31);
    }
    Test.assertEqual(m.lapPower, 200.0);
    Test.assertEqual(m.lapSpeed, 18.0);
    return true;
}

(:test)
function auditRoundedEntryBoundary(logger) {
    var f = new RideField();
    var mode = new DisplayMode();
    mode.update(599.67, 0);
    logger.debug("599.67 W displayed=" + f.integer(599.67) + ", high=" + mode.high);
    Test.assertEqual(f.integer(599.67), "600");
    Test.assert(!mode.high);
    return true;
}

(:test)
function malformedStorageVariants(logger) {
    var bad = [42, "bad", [], {"version" => 1, "ride" => "bad"},
        {"version" => 1, "ride" => 1700000000, "last" => 5000,
         "timer" => 6000, "distance" => 0.0, "energy" => 0.0, "duration" => 0, "valid" => true}];
    for (var i = 0; i < bad.size(); i += 1) {
        Application.Storage.setValue("lap", bad[i]);
        var m = new RideModel();
        m.update(new RideSample(5000, 25.0, 200), 0);
        Test.assert(m.lapTime == null);
        Test.assert(Application.Storage.getValue("lap") == null);
    }
    return true;
}

(:test)
function missingTimerRecoversAccumulation(logger) {
    Application.Storage.deleteValue("lap");
    var m = new RideModel();
    m.update(new RideSample(0, 0.0, 200), 0);
    m.update(new RideSample(1000, 5.0, 200), 1000);
    m.update(new RideSample(null, 5.0, 200), 1500);
    Test.assert(m.lapTime == null && m.lapPower == null);
    m.update(new RideSample(2000, 10.0, 200), 2000);
    Test.assertEqual(m.lapTime, 2000);
    Test.assertEqual(m.lapPower, 200.0);
    Test.assertEqual(m.lapDistance, 10.0);
    return true;
}

(:test)
function gradeWindowExpiresAndStationaryClears(logger) {
    Application.Storage.deleteValue("lap");
    var m = new RideModel();
    for (var i = 0; i < 90; i += 1) {
        var s = new RideSample(i * 1000, i * 0.6, 200);
        s.currentSpeed = 0.6;
        s.altitude = 100.0 + i * 0.06;
        m.update(s, i * 1000);
        Test.assert(m.gradeSamples.size() <= 31);
    }
    Test.assert(m.grade > 9.9 && m.grade < 10.1);
    var stopped = new RideSample(90000, 54.0, 0);
    stopped.currentSpeed = 0.0;
    m.update(stopped, 90000);
    Test.assert(m.grade == null && m.gradeSamples.size() == 0);
    return true;
}

(:test)
function rawPowerControlsSmoothedSwitch(logger) {
    Application.Storage.deleteValue("lap");
    var m = new RideModel();
    var mode = new DisplayMode();
    for (var i = 0; i < 3; i += 1) {
        m.update(new RideSample(i * 1000, i * 5.0, 250), i * 1000);
        mode.update(m.power3, i * 1000);
    }
    m.update(new RideSample(3000, 15.0, 1000), 3000);
    mode.update(m.power3, 3000);
    Test.assertEqual(m.power3, 500.0);
    Test.assert(!mode.high);
    m.update(new RideSample(4000, 20.0, 1000), 4000);
    mode.update(m.power3, 4000);
    Test.assertEqual(m.power3, 750.0);
    Test.assertEqual(m.info.currentPower, 1000);
    Test.assert(mode.high);
    return true;
}

(:test)
function configuredEntryThresholdChangesSwitch(logger) {
    var field = new RideField();
    Application.Properties.setValue("PowerThreshold", 1000);
    field.loadSettings();
    field.displayMode.update(900, 0);
    Test.assert(!field.displayMode.high);
    Application.Properties.setValue("PowerThreshold", 800);
    field.loadSettings();
    field.displayMode.update(900, 1000);
    Test.assert(field.displayMode.high);
    Application.Properties.setValue("PowerThreshold", 600);
    return true;
}

(:test)
function deviceThresholdEditorSaveAndLimits(logger) {
    Application.Properties.setValue("PowerThreshold", 600);
    var editor = new SprintSettings();
    editor.adjust(10);
    Test.assertEqual(Application.Properties.getValue("PowerThreshold"), 600);
    editor.commit();
    Test.assertEqual(Application.Properties.getValue("PowerThreshold"), 610);
    Test.assert(editor.saved);
    editor.adjust(-20000);
    Test.assertEqual(editor.value, 1);
    editor.adjust(20000);
    Test.assertEqual(editor.value, 10000);
    Application.Properties.setValue("PowerThreshold", 600);
    return true;
}

(:test)
function settingsConfirmationFlow(logger) {
 Application.Properties.setValue("PowerThreshold",600);
 var e = new SprintSettings();
 var d = new SprintSettingsDelegate(e);
 d.onPreviousPage(); Test.assertEqual(e.value,610);
 d.onNextPage(); Test.assertEqual(e.value,600);
 d.onPreviousPage(); d.onSelect();
 Test.assertEqual(e.dialog,1);
 Test.assertEqual(Application.Properties.getValue("PowerThreshold"),610);
 d.onSelect(); Test.assertEqual(e.dialog,0);
 d.onPreviousPage(); Test.assert(!e.requestBack());
 Test.assertEqual(e.dialog,2); Test.assert(!e.discard);
 Test.assert(!e.confirm()); Test.assertEqual(e.value,620);
 e.requestBack(); e.discard=true; Test.assert(e.confirm());
 Test.assertEqual(e.value,610);
 Test.assertEqual(Application.Properties.getValue("PowerThreshold"),610);
 Test.assert(e.requestBack());
 Application.Properties.setValue("PowerThreshold",600);
 return true;
}

(:test)
class UnitSettingsSample {
 var distanceUnits = Toybox.System.UNIT_METRIC;
 var elevationUnits = Toybox.System.UNIT_METRIC;
 var isNightModeEnabled = false;
 function initialize() {}
}
(:test)
function automaticSystemUnitsAndNight(logger) {
 var f = new RideField(); var s = new UnitSettingsSample();
 f.applySystem(s, Toybox.Graphics.COLOR_WHITE);
 Test.assertEqual(f.speed(10.0), "36.0");
 Test.assertEqual(f.kilometers(1609.344), "1.61");
 s.distanceUnits = Toybox.System.UNIT_STATUTE;
 s.elevationUnits = Toybox.System.UNIT_STATUTE;
 f.applySystem(s, Toybox.Graphics.COLOR_WHITE);
 Test.assertEqual(f.speed(10.0), "22.4");
 Test.assertEqual(f.speedText(36.0), "22.4");
 Test.assertEqual(f.kilometers(1609.344), "1.00");
 Test.assertEqual(f.ascent(100.0), "328");
 Test.assertEqual(f.speedUnit(), "mi/h"); Test.assertEqual(f.ascentUnit(), "ft");
 s.elevationUnits = Toybox.System.UNIT_METRIC;
 f.applySystem(s, Toybox.Graphics.COLOR_BLACK);
 Test.assert(f.night); Test.assertEqual(f.ascentUnit(), "m");
 Test.assertEqual(f.ink(0x0055aa), 0x55aaff);
 s.isNightModeEnabled = true;
 f.applySystem(s, Toybox.Graphics.COLOR_WHITE); Test.assert(f.night);
 s.isNightModeEnabled = false;
 s.distanceUnits = Toybox.System.UNIT_METRIC;
 f.applySystem(s, Toybox.Graphics.COLOR_WHITE); Test.assert(!f.night && !f.imperial);
 Test.assertEqual(f.speed(null), "--"); Test.assertEqual(f.ascent(null), "--");
 return true;
}
(:test)
function clockFormatAndSettingsSave(logger) {
 Application.Properties.setValue("Clock24", false);
 var f = new RideField(); f.loadSettings();
 Test.assertEqual(f.clockText(0,5), "12:05"); Test.assertEqual(f.clockUnit(0), "am");
 var e = new SprintSettings(); var d = new SprintSettingsDelegate(e);
 d.onMenu(); Test.assert(e.dirty()); e.commit();
 f.loadSettings(); Test.assertEqual(f.clockText(0,5), "00:05");
 Test.assertEqual(f.clockText(23,59), "23:59"); Test.assertEqual(f.clockUnit(23), "");
 Application.Properties.setValue("Clock24", false);
 return true;
}
