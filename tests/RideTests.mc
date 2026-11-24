using Toybox.Activity;
using Toybox.Application;
using Toybox.Test;
using Toybox.Time;

(:test)
class RideSample {
    var timerTime = 0;
    var startTime;
    var elapsedDistance = 0.0;
    var currentPower = 0;
    var currentSpeed = 5.0;
    var altitude = 100.0;
    var timerState = Activity.TIMER_STATE_ON;

    function initialize(timer, distance, power) {
        startTime = new Time.Moment(1700000000);
        timerTime = timer;
        elapsedDistance = distance;
        currentPower = power;
    }
}

(:test)
function powerWindowIncludesZero(logger) {
    Application.Storage.deleteValue("lap");
    var model = new RideModel();
    model.update(new RideSample(0, 0.0, 100), 0);
    model.update(new RideSample(1000, 5.0, 200), 1000);
    model.update(new RideSample(2000, 10.0, 0), 2000);
    Test.assertEqual(model.power3, 100.0);
    model.update(new RideSample(3000, 15.0, 400), 3000);
    Test.assertEqual(model.power3, 200.0);
    return true;
}

(:test)
function missingPowerShowsMissing(logger) {
    Application.Storage.deleteValue("lap");
    var model = new RideModel();
    model.update(new RideSample(0, 0.0, 250), 0);
    model.update(new RideSample(1000, 5.0, null), 1000);
    Test.assert(model.power3 == null);
    model.update(new RideSample(2000, 10.0, 100), 2000);
    Test.assertEqual(model.power3, 100.0);
    return true;
}

(:test)
function lapBoundaryUsesLatestActivity(logger) {
    Application.Storage.deleteValue("lap");
    var model = new RideModel();
    model.update(new RideSample(0, 0.0, 100), 0);
    model.update(new RideSample(1000, 5.0, 200), 1000);
    model.beginLap(new RideSample(1500, 7.5, 200), 1500);
    model.update(new RideSample(2500, 17.5, 300), 2500);
    Test.assertEqual(model.lapTime, 1000);
    Test.assertEqual(model.lapDistance, 10.0);
    Test.assert(model.lapSpeed == null);
    Test.assertEqual(model.lapPower, 300.0);
    model.update(new RideSample(3500, 27.5, 300), 3500);
    model.update(new RideSample(4500, 37.5, 300), 4500);
    Test.assertEqual(model.lapSpeed, 36.0);
    return true;
}

(:test)
function pauseDoesNotAddPowerOrTime(logger) {
    Application.Storage.deleteValue("lap");
    var model = new RideModel();
    model.update(new RideSample(0, 0.0, 100), 0);
    model.update(new RideSample(1000, 5.0, 200), 1000);
    model.update(new RideSample(1000, 5.0, 900), 10000);
    Test.assertEqual(model.lapTime, 1000);
    Test.assertEqual(model.lapPower, 200.0);
    return true;
}

(:test)
function recordingGapInvalidatesLapPower(logger) {
    Application.Storage.deleteValue("lap");
    var model = new RideModel();
    model.update(new RideSample(0, 0.0, 100), 0);
    model.update(new RideSample(1000, 5.0, 200), 1000);
    model.update(new RideSample(10000, 50.0, 250), 10000);
    Test.assert(model.lapPower == null);
    Test.assertEqual(model.lapTime, 10000);
    return true;
}

(:test)
function timerResetStartsFreshLap(logger) {
    Application.Storage.deleteValue("lap");
    var model = new RideModel();
    model.update(new RideSample(0, 0.0, 100), 0);
    model.update(new RideSample(1000, 5.0, 200), 1000);
    model.update(new RideSample(0, 0.0, 300), 2000);
    Test.assertEqual(model.lapTime, 0);
    Test.assertEqual(model.lapDistance, 0.0);
    Test.assert(model.lapPower == null);
    Test.assertEqual(model.power3, 300.0);
    return true;
}

(:test)
function gradeUsesDistanceWindow(logger) {
    Application.Storage.deleteValue("lap");
    var model = new RideModel();
    model.update(new RideSample(0, 0.0, 100), 0);
    var sample = new RideSample(1000, 20.0, 100);
    sample.altitude = 101.0;
    model.update(sample, 1000);
    Test.assertEqual(model.grade, 5.0);
    sample.currentSpeed = 0.0;
    model.update(sample, 2000);
    Test.assert(model.grade == null);
    return true;
}

(:test)
function loadingMidRideDoesNotInventLap(logger) {
    Application.Storage.deleteValue("lap");
    var model = new RideModel();
    model.update(new RideSample(50000, 200.0, 100), 0);
    Test.assert(model.lapTime == null);
    model.beginLap(new RideSample(51000, 205.0, 100), 1000);
    Test.assertEqual(model.lapTime, 0);
    return true;
}

(:test)
function resumeKeepsLapBoundary(logger) {
    Application.Storage.deleteValue("lap");
    var first = new RideModel();
    first.update(new RideSample(0, 0.0, 100), 0);
    first.beginLap(new RideSample(1000, 5.0, 200), 1000);
    first.update(new RideSample(2000, 10.0, 300), 2000);
    first.save();
    var second = new RideModel();
    second.update(new RideSample(2000, 10.0, 300), 0);
    Test.assertEqual(second.lapTime, 1000);
    Test.assertEqual(second.lapDistance, 5.0);
    Test.assertEqual(second.lapPower, 300.0);
    Application.Storage.deleteValue("lap");
    return true;
}

(:test)
function formatLongRide(logger) {
    var field = new RideField();
    Test.assertEqual(field.duration(90061000, true), "25:01:01");
    Test.assertEqual(field.duration(3601000, false), "1:00:01");
    Test.assertEqual(field.kilometers(125432.0), "125.4");
    Test.assertEqual(field.integer(null), "--");
    return true;
}

(:test)
function consecutiveLapsWithMissingDistance(logger) {
    Application.Storage.deleteValue("lap");
    var model = new RideModel();
    model.update(new RideSample(0, 0.0, 200), 0);
    model.beginLap(new RideSample(1200, 7.0, 200), 1200);
    model.beginLap(new RideSample(1500, null, 200), 1500);
    Test.assert(model.lapSpeed == null);
    Test.assert(model.lapDistance == null);
    model.update(new RideSample(2000, 12.0, 210), 2000);
    Test.assertEqual(model.lapTime, 0);
    Test.assertEqual(model.lapDistance, 0.0);
    model.update(new RideSample(3000, 18.0, null), 3000);
    Test.assert(model.lapSpeed == null);
    Test.assert(model.power3 == null);
    model.update(new RideSample(4000, 24.0, 220), 4000);
    model.update(new RideSample(5000, 30.0, 220), 5000);
    Test.assertEqual(model.lapTime, 3000);
    Test.assertEqual(model.lapDistance, 18.0);
    Test.assertEqual(model.lapSpeed, 21.6);
    Test.assertEqual(model.lapPower, 220.0);
    return true;
}

(:test)
function highPowerThresholdAndReturnDelay(logger) {
    var mode = new DisplayMode();
    mode.update(599, 0);
    Test.assert(!mode.high);
    mode.update(600, 1000);
    Test.assert(mode.high);
    mode.update(549, 2000);
    mode.update(500, 3000);
    mode.update(500, 4000);
    mode.update(500, 4999);
    Test.assert(mode.high);
    mode.update(500, 5000);
    Test.assert(!mode.high);
    return true;
}

(:test)
function thresholdRecoveryRestartsDelay(logger) {
    var mode = new DisplayMode();
    mode.update(1500, 0);
    mode.update(500, 1000);
    mode.update(600, 3500);
    mode.update(549, 4000);
    mode.update(549, 5000);
    mode.update(549, 6000);
    mode.update(549, 6999);
    Test.assert(mode.high);
    mode.update(549, 7000);
    Test.assert(!mode.high);
    return true;
}

(:test)
function missingPowerDoesNotCountAsLow(logger) {
    var mode = new DisplayMode();
    mode.update(650, 0);
    mode.update(500, 1000);
    mode.update(null, 2000);
    mode.update(500, 10000);
    Test.assert(mode.high);
    mode.update(500, 11000);
    mode.update(500, 12000);
    mode.update(500, 13000);
    Test.assert(!mode.high);
    mode.threshold = 800;
    mode.update(799, 14000);
    Test.assert(!mode.high);
    mode.update(800, 15000);
    Test.assert(mode.high);
    return true;
}

(:test)
function clockUsesTwelveHours(logger) {
    var field = new RideField();
    Test.assertEqual(field.clockText(0, 0), "12:00");
    Test.assertEqual(field.clockText(12, 5), "12:05");
    Test.assertEqual(field.clockText(13, 59), "1:59");
    Test.assertEqual(field.clockText(23, 0), "11:00");
    return true;
}

(:test)
function speedDropsDecimalAtOneHundred(logger) {
    var field = new RideField();
    Test.assertEqual(field.speedText(99.9), "99.9");
    Test.assertEqual(field.speedText(99.96), "100");
    Test.assertEqual(field.speedText(100.0), "100");
    Test.assertEqual(field.speedText(125.4), "125");
    return true;
}

(:test)
function settingsReloadThreshold(logger) {
    var field = new RideField();
    Application.Properties.setValue("PowerThreshold", 850);
    field.loadSettings();
    Test.assertEqual(field.displayMode.threshold, 850);
    Application.Properties.setValue("PowerThreshold", 600);
    return true;
}

(:test)
function hysteresisBandCancelsReturn(logger) {
    var mode = new DisplayMode();
    mode.update(600, 0);
    mode.update(500, 1000);
    mode.update(550, 3999);
    mode.update(575, 9000);
    Test.assert(mode.high);
    mode.update(549, 10000);
    mode.update(500, 11000);
    mode.update(500, 12000);
    mode.update(500, 13000);
    Test.assert(!mode.high);
    return true;
}

(:test)
function automaticSwitchCanBeDisabled(logger) {
    var mode = new DisplayMode();
    mode.update(1500, 0);
    mode.enabled = false;
    mode.update(1500, 1000);
    Test.assert(!mode.high);
    mode.enabled = true;
    mode.update(1500, 2000);
    Test.assert(mode.high);
    return true;
}

(:test)
function signalLossReturnsAfterTimeout(logger) {
    var mode = new DisplayMode();
    mode.update(600, 0);
    mode.update(null, 1000);
    mode.update(null, 2000);
    mode.update(null, 3000);
    mode.update(null, 4000);
    mode.update(null, 5000);
    mode.update(null, 5999);
    Test.assert(mode.high);
    mode.update(null, 6000);
    Test.assert(!mode.high);
    mode.update(650, 7000);
    mode.update(null, 8000);
    mode.update(575, 9000);
    mode.update(null, 10000);
    mode.update(null, 11000);
    mode.update(null, 12000);
    mode.update(null, 13000);
    mode.update(null, 14000);
    mode.update(null, 14999);
    Test.assert(mode.high);
    mode.update(null, 15000);
    Test.assert(!mode.high);
    return true;
}

(:test)
function settingsValidateNewOptions(logger) {
    var field = new RideField();
    Application.Properties.setValue("PowerThreshold", 400);
    Application.Properties.setValue("ExitThreshold", 550);
    Application.Properties.setValue("AutoSwitch", false);
    Application.Properties.setValue("MissingSeconds", 7);
    field.loadSettings();
    Test.assertEqual(field.displayMode.exitThreshold, 400);
    Test.assertEqual(field.displayMode.missingTimeout, 7000);
    Test.assert(!field.displayMode.enabled);
    Application.Properties.setValue("PowerThreshold", 600);
    Application.Properties.setValue("ExitThreshold", 550);
    Application.Properties.setValue("AutoSwitch", true);
    Application.Properties.setValue("MissingSeconds", 5);
    return true;
}
