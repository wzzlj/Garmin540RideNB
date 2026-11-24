using Toybox.Application;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

class SprintSettings extends WatchUi.View {
    var value;
    var active = false;
    var saved = false;
    var original;
    var dialog = 0;
    var discard = false;
    function initialize() {
        View.initialize();
        var setting = Application.Properties.getValue("PowerThreshold");
        value = setting instanceof Lang.Number && setting >= 1 && setting <= 10000 ? setting : 600;
        original = value;
    }
    function onShow() { active = true; }
    function onHide() { active = false; }
    function adjust(delta) {
        value += delta;
        if (value < 1) { value = 1; }
        if (value > 10000) { value = 10000; }
        saved = false;
    }
    function commit() {
        Application.Properties.setValue("PowerThreshold", value);
        Application.getApp().onSettingsChanged();
        saved = true;
        original = value;
        dialog = 1;
    }
    function dirty() { return value != original; }
    function requestBack() {
        if (dialog != 0) { dialog = 0; return false; }
        if (dirty()) { dialog = 2; discard = false; return false; }
        return true;
    }
    function confirm() {
        if (dialog == 1) { dialog = 0; return false; }
        if (dialog == 2) {
            if (discard) { value = original; dialog = 0; return true; }
            dialog = 0; return false;
        }
        commit(); return false;
    }
    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.clear();
        dc.setColor(0x555555, Graphics.COLOR_WHITE);
        var center = dc.getWidth() / 2;
        var height = dc.getHeight();
        var textFont = WatchUi.loadResource(Rez.Fonts.SettingsText);
        var numberFont = WatchUi.loadResource(Rez.Fonts.LapNumber);
        dc.drawText(center, 12, textFont, "Sprint v1.0", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(center, 40, textFont, "3s average power", Graphics.TEXT_JUSTIFY_CENTER);
        var digits = value.format("%d");
        var numberWidth = dc.getTextWidthInPixels(digits, numberFont);
        var unitWidth = dc.getTextWidthInPixels("W", textFont);
        var left = center - (numberWidth + 3 + unitWidth) / 2;
        dc.drawText(left, height / 2 - 30, numberFont, digits, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(left + numberWidth + 3, height / 2 - 11, textFont, "W", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(center, height - 92, textFont, "UP +10 / DOWN -10", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(center, height - 56, textFont, saved ? "Saved" : "ENTER: Save", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(center, height - 26, textFont, "BACK: Exit", Graphics.TEXT_JUSTIFY_CENTER);
        if (dialog != 0) {
            var top = height / 2 - 66;
            dc.setColor(0x555555, Graphics.COLOR_WHITE);
            dc.fillRectangle(8, top, dc.getWidth() - 16, 140);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(center, top + 18, textFont, dialog == 1 ? "Saved successfully" : "Discard changes", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(center, top + 58, textFont, dialog == 1 ? value.format("%d") + " W" : (discard ? "Discard and exit" : "Keep editing"), Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(center, top + 102, textFont, "ENTER: Confirm", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
class SprintSettingsDelegate extends WatchUi.BehaviorDelegate {
    var editor;
    function initialize(view) { BehaviorDelegate.initialize(); editor = view; }
    function refresh() {
        if (!editor.active) { WatchUi.requestUpdate(); return; }
        var next = new SprintSettings();
        next.value = editor.value;
        next.original = editor.original;
        next.saved = editor.saved;
        next.dialog = editor.dialog;
        next.discard = editor.discard;
        WatchUi.switchToView(next, new SprintSettingsDelegate(next), WatchUi.SLIDE_IMMEDIATE);
    }
    function move(delta) {
        if (editor.dialog == 2) { editor.discard = !editor.discard; }
        else if (editor.dialog == 0) { editor.adjust(delta); }
        refresh(); return true;
    }
    function onPreviousPage() { return move(10); }
    function onNextPage() { return move(-10); }
    function onSelect() {
        if (editor.confirm()) { WatchUi.popView(WatchUi.SLIDE_IMMEDIATE); }
        refresh(); return true;
    }
    function onBack() {
        if (editor.requestBack()) { return false; }
        refresh(); return true;
    }
    // Handle raw Edge button events too; a consumed behavior event does not
    // fall through here, so one physical press changes the value exactly once.
    function onKey(event) {
        var key = event.getKey();
        if (key == WatchUi.KEY_UP) { return onPreviousPage(); }
        if (key == WatchUi.KEY_DOWN) { return onNextPage(); }
        if (key == WatchUi.KEY_ENTER) { return onSelect(); }
        if (key == WatchUi.KEY_ESC) { return onBack(); }
        return false;
    }
}
