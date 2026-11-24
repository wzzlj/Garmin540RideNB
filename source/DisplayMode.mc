// Switch using displayed three-second power, with separate entry/exit levels.
class DisplayMode {
    var enabled = true;
    var threshold = 600;
    var exitThreshold = 550;
    var missingTimeout = 5000;
    var high = false;
    var belowSince = null;
    var missingSince = null;
    var lastUpdate = null;

    function initialize() {
    }

    function update(power, now) {
        if (lastUpdate != null && (now < lastUpdate || now - lastUpdate > 2000)) {
            belowSince = null;
            missingSince = null;
        }
        lastUpdate = now;
        if (!enabled) {
            reset();
            return;
        }
        if (power == null) {
            belowSince = null;
            if (high) {
                if (missingSince == null || now < missingSince) { missingSince = now; }
                if (now - missingSince >= missingTimeout) { reset(); }
            }
            return;
        }
        missingSince = null;
        if (power >= threshold) {
            high = true;
            belowSince = null;
        } else if (high && power < exitThreshold) {
            if (belowSince == null || now < belowSince) { belowSince = now; }
            if (now - belowSince >= 3000) { reset(); }
        } else {
            belowSince = null;
        }
    }

    function reset() {
        high = false;
        lastUpdate = null;
        belowSince = null;
        missingSince = null;
    }
}
