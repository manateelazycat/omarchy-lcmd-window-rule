import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    // Injected by omarchy-shell. No bar widget or panel is needed.
    property var shell: null
    property bool applied: false
    property bool pending: false
    property bool unloading: false
    property string lastError: ""
    property int reloadEvents: 0
    readonly property string ownerToken: Date.now().toString(36) + "-" + Math.random().toString(36).slice(2)
    readonly property string rulesPath: {
        const url = String(Qt.resolvedUrl("rules.lua"));
        if (url.indexOf("qs:@/qs/") === 0)
            return Quickshell.shellDir + "/" + url.slice(8);
        return decodeURIComponent(url.replace(/^file:\/\//, ""));
    }

    // Lua accepts JSON string escaping for the generated path and owner token.
    function applyCode() {
        return "dofile(" + JSON.stringify(rulesPath) + ").enable(" + JSON.stringify(ownerToken) + ")";
    }
    function disableCode() {
        return "local state = _G.omarchy_lcmd_window_rule; if state then state.disable("
            + JSON.stringify(ownerToken) + ") end";
    }
    function applyRules() {
        if (unloading) return;
        if (applyProcess.running) { pending = true; return; }
        pending = false;
        lastError = "";
        applyProcess.command = ["hyprctl", "eval", applyCode()];
        applyProcess.running = true;
    }

    Process {
        id: applyProcess
        property bool succeeded: false
        onStarted: succeeded = false
        stdout: StdioCollector {
            onStreamFinished: {
                applyProcess.succeeded = text.trim() === "ok";
                if (!applyProcess.succeeded) root.lastError = text.trim();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "") root.lastError = text.trim();
            }
        }
        onExited: function(exitCode) {
            root.applied = exitCode === 0 && succeeded;
            if (!root.applied) console.warn("LCMD Window Rule:", root.lastError || "hyprctl failed");
            if (root.pending && !root.unloading) Qt.callLater(root.applyRules);
        }
    }
    Timer { id: reapplyTimer; interval: 100; onTriggered: root.applyRules() }
    // Follow the compositor stream directly, independently of shell UI models.
    Socket {
        id: events
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/hypr/"
            + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") + "/.socket2.sock"
        connected: true
        parser: SplitParser {
            onRead: data => {
                if (data === "configreloaded>>" && !root.unloading) {
                    root.reloadEvents += 1;
                    root.applied = false;
                    reapplyTimer.restart();
                }
            }
        }
        onConnectedChanged: {
            if (root.unloading) return;
            if (connected) reapplyTimer.restart();
            else reconnectTimer.restart();
        }
        onError: { if (!root.unloading) reconnectTimer.restart(); }
    }
    Timer {
        id: reconnectTimer
        interval: 2000
        onTriggered: { if (!root.unloading) events.connected = true; }
    }
    IpcHandler {
        target: "io.github.manateelazycat.lcmd-window-rule"
        function status(): string {
            return JSON.stringify({ applied: root.applied, version: "0.1.0", error: root.lastError,
                eventSocketConnected: events.connected, reloadEvents: root.reloadEvents });
        }
    }
    Component.onCompleted: reapplyTimer.start()
    Component.onDestruction: {
        root.unloading = true;
        reapplyTimer.stop();
        reconnectTimer.stop();
        events.connected = false;
        Quickshell.execDetached(["hyprctl", "eval", root.disableCode()]);
    }
}
