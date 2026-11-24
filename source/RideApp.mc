using Toybox.Application;

class RideApp extends Application.AppBase {
    var field;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        field = new RideField();
        return [field];
    }

    function getSettingsView() {
        var editor = new SprintSettings();
        return [editor, new SprintSettingsDelegate(editor)];
    }

    function onSettingsChanged() {
        if (field != null) { field.loadSettings(); }
    }

    function onStop(state) {
        if (field != null) {
            field.saveState();
        }
    }
}
