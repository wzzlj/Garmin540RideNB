using Toybox.Activity;
using Toybox.Application;
using Toybox.Math;
using Toybox.Lang;

// Timer milliseconds drive lap statistics. Wall-clock milliseconds drive the
// three-second power window, so auto-pause cannot add time to a lap.
class RideModel {
    var info;
    var power3;
    var grade;
    var lapTime;
    var lapDistance;
    var lapPower;
    var lapSpeed;
    var lapTimerBase;
    var lapPending;
    var lapDistanceBase;
    var powerEnergy;
    var powerDuration;
    var lastTimer;
    var rideKey;
    var powerSamples;
    var gradeSamples;
    var restored;

    function initialize() {
        reset();
        restored = Application.Storage.getValue("lap");
    }

    function reset() {
        info = null;
        power3 = null;
        grade = null;
        lapTime = null;
        lapDistance = null;
        lapPower = null;
        lapSpeed = null;
        lapTimerBase = null;
        lapPending = false;
        lapDistanceBase = null;
        powerEnergy = 0.0;
        powerDuration = 0;
        lapPowerValid = true;
        lastTimer = null;
        rideKey = null;
        powerSamples = [];
        gradeSamples = [];
        restored = null;
    }

    function update(sample, now) {
        var timer = sample.timerTime;
        var key = sample.startTime == null ? null : sample.startTime.value();
        if ((lastTimer != null && timer != null && timer < lastTimer) ||
            (rideKey != null && key != null && key != rideKey)) {
            reset();
        }
        info = sample;
        if (rideKey == null && key != null) {
            rideKey = key;
        }
        if (lastTimer == null) {
            restoreLap(timer);
        }

        if (lapPending && timer != null && sample.elapsedDistance != null) {
            lapTimerBase = timer;
            lapDistanceBase = sample.elapsedDistance;
            lapPending = false;
        }

        updatePower(sample.currentPower, now);
        var delta = timer == null || lastTimer == null ? 0 : timer - lastTimer;
        // Never bridge a missing callback interval with a fabricated power value.
        if (delta > 0 && delta <= 2000 && lapTimerBase != null && timer > lapTimerBase && sample.currentPower != null) {
            powerEnergy += sample.currentPower * delta.toFloat();
            powerDuration += delta;
        } else if (delta > 2000 && lapTimerBase != null && timer > lapTimerBase) {
            powerEnergy = 0.0;
            powerDuration = 0;
            // A full-lap power average is unavailable after an unobserved interval.
            lapPower = null;
            lapPowerValid = false;
        }
        if (timer != null) {
            lastTimer = timer;
        }
        updateLap();
        updateGrade(now);
    }

    var lapPowerValid = true;

    function storedNumber(value) {
        return (value instanceof Lang.Number || value instanceof Lang.Long ||
            value instanceof Lang.Float || value instanceof Lang.Double) &&
            value >= 0 && value <= 1.0e15;
    }

    function validStoredLap() {
        if (!(restored instanceof Lang.Dictionary)) { return false; }
        var fields = ["version", "ride", "last", "timer", "distance", "energy", "duration", "valid"];
        for (var i = 0; i < fields.size(); i += 1) {
            if (!restored.hasKey(fields[i])) { return false; }
        }
        if (restored["version"] != 1 || !(restored["valid"] instanceof Lang.Boolean)) { return false; }
        for (var j = 1; j < 7; j += 1) {
            if (!storedNumber(restored[fields[j]])) { return false; }
        }
        return restored["timer"] <= restored["last"] &&
            restored["duration"] <= restored["last"] - restored["timer"];
    }

    function restoreLap(timer) {
        var valid = restored != null && validStoredLap();
        if (restored != null && !valid) { Application.Storage.deleteValue("lap"); }
        if (valid && rideKey != null && restored["ride"] == rideKey &&
            timer != null && timer >= restored["last"]) {
            lapTimerBase = restored["timer"];
            lapDistanceBase = restored["distance"];
            powerEnergy = restored["energy"];
            powerDuration = restored["duration"];
            lapPowerValid = restored["valid"] && timer - restored["last"] <= 2000;
            lastTimer = restored["last"];
        } else if (timer != null && timer <= 1000) {
            lapTimerBase = 0;
            lapDistanceBase = 0.0;
            lapPowerValid = true;
        }
        restored = null;
    }

    function updatePower(power, now) {
        if (power == null || (powerSamples.size() > 0 && now < powerSamples[0][0])) {
            powerSamples = [];
        }
        var kept = [];
        var sum = 0.0;
        for (var i = 0; i < powerSamples.size(); i += 1) {
            if (now - powerSamples[i][0] < 3000) {
                kept.add(powerSamples[i]);
                sum += powerSamples[i][1];
            }
        }
        if (power != null && (kept.size() == 0 || now - kept[kept.size() - 1][0] >= 800)) {
            kept.add([now, power]);
            sum += power;
        }
        powerSamples = kept;
        power3 = kept.size() == 0 ? null : sum / kept.size();
    }

    function updateLap() {
        if (lapTimerBase == null || info.timerTime == null) {
            lapTime = null;
            lapDistance = null;
            lapSpeed = null;
            lapPower = null;
            return;
        }
        lapTime = info.timerTime > lapTimerBase ? info.timerTime - lapTimerBase : 0;
        lapDistance = info.elapsedDistance == null || lapDistanceBase == null ? null :
            info.elapsedDistance > lapDistanceBase ? info.elapsedDistance - lapDistanceBase : 0.0;
        // Timer and distance may advance on different callbacks immediately after a lap.
        lapSpeed = lapTime >= 3000 && lapDistance != null ? lapDistance * 3600.0 / lapTime : null;
        lapPower = lapPowerValid && powerDuration > 0 ? powerEnergy / powerDuration : null;
    }

    function beginLap(sample, now) {
        // Use a single activity snapshot for both baselines. If the lap callback
        // has incomplete data, wait for the next sample containing both values.
        if (sample != null) {
            update(sample, now);
        }
        lapPending = sample == null || sample.timerTime == null || sample.elapsedDistance == null;
        lapTimerBase = lapPending ? null : sample.timerTime;
        lapDistanceBase = lapPending ? null : sample.elapsedDistance;
        lapTime = lapPending ? null : 0;
        lapDistance = lapPending ? null : 0.0;
        lapSpeed = null;
        lapPower = null;
        powerEnergy = 0.0;
        powerDuration = 0;
        lapPowerValid = true;
    }

    function updateGrade(now) {
        grade = null;
        if (info.timerState != Activity.TIMER_STATE_ON || info.altitude == null ||
            info.elapsedDistance == null || info.currentSpeed == null || info.currentSpeed < 0.5) {
            gradeSamples = [];
            return;
        }
        var kept = [];
        for (var i = 0; i < gradeSamples.size(); i += 1) {
            if (now >= gradeSamples[i][0] && now - gradeSamples[i][0] <= 30000) {
                kept.add(gradeSamples[i]);
            }
        }
        if (kept.size() == 0 || now - kept[kept.size() - 1][0] >= 800) {
            kept.add([now, info.elapsedDistance, info.altitude]);
        }
        // Keep the shortest observed window spanning at least 15 m, bounded
        // to 30 seconds for slow climbs. Never retain stale terrain indefinitely.
        var first = 0;
        while (first + 1 < kept.size() && info.elapsedDistance - kept[first + 1][1] >= 15) {
            first += 1;
        }
        if (first > 0) { kept = kept.slice(first, kept.size()); }
        gradeSamples = kept;
        var distance = info.elapsedDistance - kept[0][1];
        if (distance >= 15) {
            grade = (info.altitude - kept[0][2]) * 100.0 / distance;
        }
    }

    function save() {
        if (rideKey != null && lastTimer != null && lapTimerBase != null) {
            Application.Storage.setValue("lap", {
                "version" => 1, "ride" => rideKey, "last" => lastTimer,
                "timer" => lapTimerBase, "distance" => lapDistanceBase,
                "energy" => powerEnergy, "duration" => powerDuration,
                "valid" => lapPowerValid
            });
        }
    }
}
