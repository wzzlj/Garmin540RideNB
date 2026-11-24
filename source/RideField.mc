using Toybox.Activity;
using Toybox.Application;
using Toybox.Graphics;
using Toybox.Math;
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;

class RideField extends WatchUi.DataField {
    var imperial = false;
    var feet = false;
    var hour24 = false;
    var night = false;
    var background = 0xffffff;
    var model;
    var fonts;
    var displayMode;

    function initialize() {
        DataField.initialize();
        model = new RideModel();
        displayMode = new DisplayMode();
        loadSettings();
        // Keep resource IDs here. Loading every font at once can exceed a
        // data field's heap even though the executable fits in flash.
        fonts = [Rez.Fonts.TopTime, Rez.Fonts.TopNumber,
            Rez.Fonts.SpeedAverage, Rez.Fonts.PowerAverage,
            Rez.Fonts.SpeedHero, Rez.Fonts.PowerHero,
            Rez.Fonts.SideNumber, Rez.Fonts.LapNumber,
            Rez.Fonts.LapSpeed, Rez.Fonts.LapDistance,
            Rez.Fonts.SmallNumber, Rez.Fonts.Unit11,
            Rez.Fonts.Unit12, Rez.Fonts.Unit13,
            Rez.Fonts.HighSpeed, Rez.Fonts.HighPower, Rez.Fonts.HighSide,
            Rez.Fonts.HighTime, Rez.Fonts.Clock, Rez.Fonts.HighPowerThree, Rez.Fonts.Grade];
    }

    function loadSettings() {
        hour24 = Application.Properties.getValue("Clock24") == true;
        var threshold = Application.Properties.getValue("PowerThreshold");
        displayMode.threshold = threshold instanceof Lang.Number && threshold >= 1 && threshold <= 10000 ? threshold : 600;
        var exit = Application.Properties.getValue("ExitThreshold");
        var timeout = Application.Properties.getValue("MissingSeconds");
        displayMode.enabled = Application.Properties.getValue("AutoSwitch") != false;
        displayMode.exitThreshold = exit instanceof Lang.Number && exit >= 1 && exit <= 10000 ? exit : 550;
        if (displayMode.exitThreshold > displayMode.threshold) {
            displayMode.exitThreshold = displayMode.threshold;
        }
        displayMode.missingTimeout = timeout instanceof Lang.Number && timeout >= 1 && timeout <= 60 ? timeout * 1000 : 5000;
        displayMode.belowSince = null;
        displayMode.missingSince = null;
        if (!displayMode.enabled) { displayMode.reset(); }
    }

    function compute(info) {
        model.update(info, System.getTimer());
        displayMode.update(model.power3, System.getTimer());
        return model.power3;
    }

    function onTimerLap() {
        model.beginLap(Activity.getActivityInfo(), System.getTimer());
        model.save();
    }

    function onTimerPause() {
        model.powerSamples = [];
        model.gradeSamples = [];
    }

    function onTimerStop() {
        model.powerSamples = [];
        model.gradeSamples = [];
        model.save();
    }

    function onTimerReset() {
        model.reset();
        displayMode.reset();
        Application.Storage.deleteValue("lap");
    }

    function saveState() {
        model.save();
    }

    function applySystem(settings, fieldBackground) {
        imperial = settings.distanceUnits == System.UNIT_STATUTE;
        feet = settings.elevationUnits == System.UNIT_STATUTE;
        night = fieldBackground == Graphics.COLOR_BLACK ||
            ((settings has :isNightModeEnabled) && settings.isNightModeEnabled);
        background = night ? 0x000000 : 0xffffff;
    }
    function speedUnit() { return imperial ? "mi/h" : "km/h"; }
    function distanceUnit() { return imperial ? "mi" : "km"; }
    function ascentUnit() { return feet ? "ft" : "m"; }
    function ascent(value) { return integer(value == null ? null : value * (feet ? 3.280839895 : 1.0)); }
    function clockUnit(hour) { return hour24 ? "" : (hour < 12 ? "am" : "pm"); }
    function ink(color) {
        if (!night) { return color; }
        if (color == 0x0055aa) { return 0x55aaff; }
        if (color == 0x5500aa) { return 0xaa55ff; }
        if (color == 0xaa0000) { return 0xff5555; }
        if (color == 0x00aa55) { return 0x55ffaa; }
        if (color == 0xaa5500) { return 0xffaa55; }
        if (color == 0x000000 || color == 0x555555) { return 0xaaaaaa; }
        return color;
    }
    function onUpdate(dc) {
        applySystem(System.getDeviceSettings(), getBackgroundColor());
        dc.setColor(background, background);
        dc.clear();
        if (dc.getWidth() != 246 || dc.getHeight() != 322) {
            // A full-page field must be selected to get the approved layout.
            dc.setColor(ink(0x000000), background);
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2,
                Graphics.FONT_NUMBER_MEDIUM, integer(model.power3),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        if (displayMode.high) {
            drawHighPower(dc);
            return;
        }
        dc.setColor(0x0055aa, Graphics.COLOR_WHITE);
        dc.fillRoundedRectangle(118, 65, 126, 74, 3);
        dc.setColor(0x5500aa, Graphics.COLOR_WHITE);
        dc.fillRoundedRectangle(2, 141, 146, 104, 3);

        var clock = System.getClockTime();
        var info = model.info;
        var timer = info == null ? null : info.timerTime;
        var distance = info == null ? null : info.elapsedDistance;
        cell(dc, clockText(clock.hour, clock.min), clockUnit(clock.hour), 4, 3, 104, 18, 0x555555, false);
        cell(dc, duration(timer, true), "", 112, 3, 130, 0, 0x000000, true);
        cell(dc, ascent(info == null ? null : info.totalAscent), ascentUnit(), 4, 35, 111, 1, 0xaa5500, false);
        cell(dc, kilometers(distance), distanceUnit(), 116, 35, 126, 1, 0x000000, true);
        cell(dc, speed(info == null ? null : info.averageSpeed), speedUnit(), 4, 68, 111, 2, 0x0055aa, false);
        cell(dc, integer(info == null ? null : info.averagePower), "W", 4, 105, 111, 3, 0x5500aa, false);
        cell(dc, speed(info == null ? null : info.currentSpeed), "", 121, 68, 120, 4, Graphics.COLOR_WHITE, true);
        cell(dc, integer(model.power3), "", 5, 143, 140, 5, Graphics.COLOR_WHITE, false);
        cell(dc, integer(info == null ? null : info.currentHeartRate), "bpm", 151, 143, 91, 6, 0xaa0000, true);
        cell(dc, integer(info == null ? null : info.currentCadence), "rpm", 151, 178, 91, 6, 0x00aa55, true);
        cell(dc, percent(model.grade), "%", 151, 213, 91, 20, 0xaa5500, true);
        cell(dc, integer(model.lapPower), "W", 4, 249, 109, 7, 0x5500aa, false);
        cell(dc, duration(model.lapTime, false), "", 116, 249, 126, 7, 0x000000, true);
        cell(dc, speedText(model.lapSpeed), speedUnit(), 4, 286, 116, 8, 0x0055aa, false);
        cell(dc, kilometers(model.lapDistance), distanceUnit(), 124, 286, 118, 9, 0x000000, true);
    }

    function drawHighPower(dc) {
        var info = model.info;
        dc.setColor(0x0055aa, Graphics.COLOR_WHITE);
        dc.fillRectangle(0, 0, 246, 64);
        dc.setColor(0x5500aa, Graphics.COLOR_WHITE);
        dc.fillRectangle(0, 65, 246, 105);
        cell(dc, speed(info == null ? null : info.currentSpeed), speedUnit(), 3, 3, 240, 14, Graphics.COLOR_WHITE, true);
        cell(dc, integer(info == null ? null : info.currentPower), "W", 3, 67, 240, 15, Graphics.COLOR_WHITE, false);
        cell(dc, integer(info == null ? null : info.currentCadence), "rpm", 3, 175, 240, 16, 0x00aa55, true);
        cell(dc, integer(info == null ? null : info.currentHeartRate), "bpm", 3, 230, 240, 16, 0xaa0000, true);
        cell(dc, duration(info == null ? null : info.timerTime, true), "", 3, 285, 240, 17, 0x000000, true);
    }

    function clockText(hour, minute) {
        if (hour24) { return hour.format("%02d") + ":" + minute.format("%02d"); }
        var twelveHour = hour % 12;
        if (twelveHour == 0) { twelveHour = 12; }
        return twelveHour.format("%d") + ":" + minute.format("%02d");
    }

    // Measure every value, retaining the unit and using a smaller font only
    // for values wider than the approved sample, such as four-digit power.
    function cell(dc, value, unit, x, y, width, index, color, right) {
        var font = WatchUi.loadResource(fonts[index == 15 && value.length() <= 3 ? 19 : index]);
        var rowHeight = dc.getFontHeight(font);
        var unitFont = unit == "" ? null : WatchUi.loadResource(fonts[index == 3 || index == 7 ? 13 : 11]);
        var unitWidth = unit == "" ? 0 : dc.getTextWidthInPixels(unit, unitFont) + 1;
        var stacked = unit.equals("km/h") || unit.equals("mi/h");
        var upperUnit = imperial ? "mi" : "km";
        if (stacked) {
            var upperWidth = dc.getTextWidthInPixels(upperUnit, unitFont);
            var lowerWidth = dc.getTextWidthInPixels("/h", unitFont);
            unitWidth = (upperWidth > lowerWidth ? upperWidth : lowerWidth) + 1;
        }
        var valueWidth = dc.getTextWidthInPixels(value, font);
        if (valueWidth + unitWidth > width) {
            // The speed font is large enough for a four-digit power value.
            font = WatchUi.loadResource(fonts[index == 5 ? 4 : 10]);
            valueWidth = dc.getTextWidthInPixels(value, font);
        }
        if (valueWidth + unitWidth > width) {
            value = compact(value);
            valueWidth = dc.getTextWidthInPixels(value, font);
        }
        if (valueWidth + unitWidth > width) {
            value = "--";
            valueWidth = dc.getTextWidthInPixels(value, font);
        }
        if (index >= 14 && index <= 17) {
            x += (width - valueWidth - unitWidth) / 2;
        } else if (right) {
            x += width - valueWidth - unitWidth;
        }
        y += (rowHeight - dc.getFontHeight(font)) / 2;
        dc.setColor(ink(color), Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, value, Graphics.TEXT_JUSTIFY_LEFT);
        if (unitWidth > 0) {
            var bottom = y + dc.getFontHeight(font);
            var unitHeight = dc.getFontHeight(unitFont);
            if (stacked) {
                dc.drawText(x + valueWidth + 1, bottom - unitHeight * 2 - 1, unitFont, upperUnit, Graphics.TEXT_JUSTIFY_LEFT);
                dc.drawText(x + valueWidth + 1, bottom - unitHeight, unitFont, "/h", Graphics.TEXT_JUSTIFY_LEFT);
            } else {
                dc.drawText(x + valueWidth + 1, bottom - unitHeight, unitFont, unit, Graphics.TEXT_JUSTIFY_LEFT);
            }
        }
    }

    function integer(value) {
        return value == null ? "--" : Math.round(value).toNumber().format("%d");
    }

    function decimal(value, places) {
        if (value == null) { return "--"; }
        return value.format(places == 2 ? "%.2f" : "%.1f");
    }

    function speed(value) {
        return speedText(value == null ? null : value * 3.6);
    }

    function speedText(kmh) {
        if (kmh == null) { return "--"; }
        if (imperial) { kmh /= 1.609344; }
        return Math.round(kmh * 10) >= 1000 ? integer(kmh) : decimal(kmh, 1);
    }

    function kilometers(value) {
        if (value == null) { return "--"; }
        var km = value / (imperial ? 1609.344 : 1000.0);
        if (km >= 1000) { return integer(km); }
        return decimal(km, km < 100 ? 2 : 1);
    }

    function percent(value) {
        if (value == null) { return "--"; }
        return (value >= 0 ? "+" : "") + value.format("%.1f");
    }

    function compact(value) {
        var point = value.find(".");
        return point == null ? value : value.substring(0, point);
    }

    function duration(milliseconds, hoursAlways) {
        if (milliseconds == null) { return "--:--"; }
        var seconds = (milliseconds / 1000).toNumber();
        var hours = (seconds / 3600).toNumber();
        var minutes = ((seconds % 3600) / 60).toNumber();
        var tail = minutes.format("%02d") + ":" + (seconds % 60).format("%02d");
        return hoursAlways || hours > 0 ? hours.format("%d") + ":" + tail : tail;
    }
}
