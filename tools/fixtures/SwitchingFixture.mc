using Toybox.System;
using Toybox.Application;
using Toybox.Activity;
using Toybox.Time;
class FixtureInfo {
    var timerTime = 5076000;
    var elapsedDistance = 46720.0;
    var totalAscent = 684;
    var averageSpeed = 8.77;
    var averagePower = 216;
    var currentSpeed = 9.11;
    var currentHeartRate = 168;
    var currentCadence = 102;
    var currentPower = 250;
    var altitude = 100.0;
    var timerState = Activity.TIMER_STATE_ON;
    var startTime;
    function initialize() { startTime = new Time.Moment(1700000000); }
}
class SwitchingFixture extends RideField {
    var started;
    var seconds = 0;
    var previousStage = -1;
    function initialize() { RideField.initialize(); }
    function compute(unused) {
        if (started == null) { started = System.getTimer(); }
        seconds = ((System.getTimer() - started) / 1000).toNumber();
        var info = new FixtureInfo();
        info.timerTime += seconds * 1000;
        info.elapsedDistance += seconds * 9.11;
        if (seconds >= 3 && seconds < 6) { info.currentPower = 1000; }
        else if (seconds >= 6 && seconds < 9) { info.currentPower = 1500; info.currentSpeed = 34.83; }
        else if (seconds >= 9 && seconds < 12) { info.currentPower = 650; }
        else if (seconds >= 12 && seconds < 15) { info.currentPower = 575; }
        else if (seconds >= 15 && seconds < 21) { info.currentPower = 0; }
        else if (seconds >= 21 && seconds < 25) { info.currentPower = 900; }
        else if (seconds >= 25 && seconds < 33) { info.currentPower = null; info.currentHeartRate = null; info.currentCadence = null; }
        var threshold = seconds >= 24 ? 800 : seconds >= 21 ? 1000 : 600;
        if (displayMode.threshold != threshold) {
            Application.Properties.setValue("PowerThreshold", threshold);
            loadSettings();
        }
        var result = RideField.compute(info);
        model.grade = seconds % 2 == 0 ? -9.9 : -10.0;
        model.lapTime = 768000 + seconds * 1000;
        model.lapDistance = 6840.0;
        model.lapSpeed = 32.1;
        model.lapPower = 224;
        return result;
    }
    function onUpdate(dc) {
        RideField.onUpdate(dc);
        if (model.info != null && seconds != previousStage) {
            System.println("FRAME " + seconds + " POWER " + model.info.currentPower + " HIGH " + displayMode.high + " AVG " + model.power3 + " THRESHOLD " + displayMode.threshold);
            previousStage = seconds;
        }
    }
}
