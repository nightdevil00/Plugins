import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var shell: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateDir: home + "/.local/state/omarchy/indicators"
  readonly property string statePath: stateDir + "/white.nights"

  property bool noSleep: false
  property bool stateLoaded: false
  property bool desired: false
  property bool hasPendingPersist: false
  property bool pendingPersist: false

  function logEvent(event, details) {
    var suffix = details === undefined || details === null || details === "" ? "" : ": " + String(details)
    console.log("white.nights " + new Date().toISOString() + " " + event + suffix)
  }

  function setInhibitor(running) {
    root.desired = running
    if (running) {
      if (inhibitProcess.running) return
      logEvent("inhibit-start")
      inhibitProcess.running = true
    } else {
      if (!inhibitProcess.running) return
      logEvent("inhibit-stop")
      inhibitProcess.running = false
    }
  }

  function applyNoSleep(value, persist, reason) {
    var enabled = !!value
    if (persist) persistState(enabled)
    var changed = !root.stateLoaded || root.noSleep !== enabled
    root.noSleep = enabled
    root.stateLoaded = true
    if (changed) {
      logEvent("set", (enabled ? "blocked" : "allowed") + (reason ? " " + reason : ""))
      setInhibitor(enabled)
    }
  }

  function setNoSleep(value) {
    applyNoSleep(value, true, "ipc")
  }

  function toggle() {
    applyNoSleep(!root.noSleep, true, "ipc")
  }

  function statusJson() {
    return JSON.stringify({
      enabled: root.noSleep,
      stateLoaded: root.stateLoaded,
      statePath: root.statePath,
      inhibitorRunning: inhibitProcess.running
    })
  }

  function persistState(value) {
    var command = value
      ? "mkdir -p \"" + root.stateDir + "\" && touch \"" + root.statePath + "\""
      : "rm -f \"" + root.statePath + "\""
    if (stateWriter.running) {
      root.pendingPersist = !!value
      root.hasPendingPersist = true
      return
    }
    stateWriter.command = ["bash", "-lc", command]
    stateWriter.running = true
  }

  Process {
    id: inhibitProcess
    command: ["systemd-inhibit",
      "--what=sleep:handle-lid-switch:handle-suspend-key:handle-hibernate-key",
      "--mode=block",
      "--who=white.nights",
      "--why=System stays on with the screen off",
      "sleep", "infinity"]
    onExited: function(exitCode, exitStatus) {
      root.logEvent("inhibit-exit", "exitCode=" + exitCode + " status=" + exitStatus)
      if (root.desired && root.noSleep) {
        logEvent("inhibit-restart")
        inhibitProcess.running = true
      }
    }
  }

  Process {
    id: stateProbe
    command: ["bash", "-c", "mkdir -p \"" + root.stateDir + "\"; if [[ -f \"" + root.statePath + "\" ]]; then echo yes; else echo no; fi"]
    stdout: SplitParser {
      onRead: function(line) { root.applyNoSleep(String(line).trim() === "yes", false, "state-file") }
    }
  }

  Process {
    id: stateWriter
    onExited: function() {
      if (root.hasPendingPersist) {
        var pending = root.pendingPersist
        root.hasPendingPersist = false
        root.persistState(pending)
        return
      }
      if (!stateProbe.running) stateProbe.running = true
    }
  }

  FileView {
    id: stateDirWatcher
    path: root.stateDir
    watchChanges: true
    printErrors: false
    onFileChanged: if (!stateProbe.running) stateProbe.running = true
  }

  Component.onCompleted: {
    logEvent("service-ready")
    if (!stateProbe.running) stateProbe.running = true
  }

  Component.onDestruction: {
    setInhibitor(false)
  }

  IpcHandler {
    target: "no-sleep"

    function status(): string {
      return root.statusJson()
    }

    function toggle(): string {
      root.toggle()
      return root.statusJson()
    }

    function enable(): string {
      root.setNoSleep(true)
      return root.statusJson()
    }

    function disable(): string {
      root.setNoSleep(false)
      return root.statusJson()
    }
  }
}
