.pragma library

// Turns the managed setting map into ~/.config/hypr/settings.lua.
//
// The file is intentionally the last require() in hyprland.lua so its
// hl.config() / hl.animation() calls win over Omarchy defaults and the
// user's own files. It only ever contains values the user changed; removing
// a setting from the map removes the line, letting the original value apply.

function roundFloat(value) {
  return Math.round(value * 1e6) / 1e6
}

function luaNumberString(value) {
  if (typeof value === "number") {
    return value === Math.floor(value) ? String(value) : String(roundFloat(value))
  }
  return null
}

function needsQuotes(raw) {
  if (typeof raw !== "string") return false
  return !/^-?[0-9]+(\.[0-9]+)?$/.test(raw)
}

function quote(s) {
  return "\"" + String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\""
}

function scalar(value, type) {
  if (type === "bool") return value ? "true" : "false"
  if (type === "int" || type === "float") {
    var n = Number(value)
    return isNaN(n) ? "0" : (n === Math.floor(n) ? String(n) : String(roundFloat(n)))
  }
  // enums and strings: numeric-looking enum members stay numeric
  if (typeof value === "number") return String(roundFloat(value))
  return needsQuotes(value) ? quote(value) : String(value)
}

function setPath(root, path, value) {
  var node = root
  for (var i = 0; i < path.length - 1; i++) {
    var key = path[i]
    if (!node[key] || typeof node[key] !== "object") node[key] = {}
    node = node[key]
  }
  node[path[path.length - 1]] = value
}

function renderTable(obj, indent) {
  var pad = "  "
  var inner = ""
  var keys = Object.keys(obj)
  for (var i = 0; i < keys.length; i++) {
    var k = keys[i]
    var v = obj[k]
    var prefix = indent + pad + k + " = "
    if (v !== null && typeof v === "object") {
      inner += prefix + "{\n" + renderTable(v, indent + pad) + indent + pad + "},\n"
    } else {
      inner += prefix + v + ",\n"
    }
  }
  return inner
}

function animationLine(leaf, opts) {
  var parts = ["leaf = " + quote(leaf)]
  if (opts.enabled !== undefined) parts.push("enabled = " + (opts.enabled ? "true" : "false"))
  if (opts.speed !== undefined) parts.push("speed = " + luaNumberString(opts.speed))
  if (opts.bezier) parts.push("bezier = " + quote(opts.bezier))
  if (opts.style) parts.push("style = " + quote(opts.style))
  return "hl.animation({ " + parts.join(", ") + " })\n"
}

function monitorLine(m) {
  var parts = ["output = " + quote(m.output)]
  if (m.enabled === false) {
    parts.push("disabled = true")
  } else {
    if (m.mode) parts.push("mode = " + quote(m.mode))
    if (m.scale !== undefined && m.scale !== null) parts.push("scale = " + luaNumberString(Number(m.scale)))
    if (m.x !== undefined && m.y !== undefined) parts.push("position = " + quote(m.x + "x" + m.y))
    if (m.transform) parts.push("transform = " + luaNumberString(Number(m.transform)))
  }
  return "hl.monitor({ " + parts.join(", ") + " })\n"
}

function gestureLine(managed, schema) {
  var out = ""
  var has = function (id) { return Object.prototype.hasOwnProperty.call(managed, id) }

  // Gestures are enabled by default; only skip if explicitly disabled in managed.
  var workspaceSwipe = has("gesture.workspace_swipe") ? managed["gesture.workspace_swipe"] : true
  var pinchZoom = has("gesture.pinch_zoom") ? managed["gesture.pinch_zoom"] : true

  if (workspaceSwipe === true) {
    var fingers = has("gesture.workspace_swipe_fingers") ? Number(managed["gesture.workspace_swipe_fingers"]) : 3
    out += "hl.gesture({ fingers = " + fingers + ", direction = \"horizontal\", action = \"workspace\" })\n"
  }

  if (pinchZoom === true) {
    out += "hl.gesture({ fingers = 2, direction = \"pinch\", action = \"cursor_zoom\", zoom_level = 1.5, mode = \"mult\" })\n"
  }

  return out
}

function envLine(key, value) {
  return "hl.env({ " + quote(key) + ", " + quote(String(value)) + " })\n"
}

function kbOptionsString(managed) {
  var has = function (id) { return Object.prototype.hasOwnProperty.call(managed, id) }
  var capslock = has("input.capslock_behavior") ? managed["input.capslock_behavior"] : "compose"

  var parts = ["shift:both_capslock_cancel", "grp:alts_toggle"]

  if (capslock === "compose") parts.unshift("compose:caps")
  else if (capslock === "ctrl") parts.unshift("ctrl:nocaps")
  else if (capslock === "escape") parts.unshift("caps:escape")
  else if (capslock === "normal") {} // no capslock option = normal behavior
  else if (capslock === "none") parts.unshift("caps:none")

  return parts.join(",")
}

// managed: { settingId: value }; monitors: [{output,enabled,mode,scale,x,y,transform}]
function generate(managed, schema, monitors) {
  var config = {}
  var anims = ""
  var hasConfig = false
  var envText = ""
  var hasEnv = false

  for (var i = 0; i < schema.length; i++) {
    var s = schema[i]
    if (!Object.prototype.hasOwnProperty.call(managed, s.id)) continue
    var value = managed[s.id]

    if (s.leaf) continue

    // Settings with no Hyprland keyword (hypr: null) are recorded in state
    // but must not be written into the hl.config tree -- the Omarchy loader
    // relays every tree key to Hyprland, which rejects them at parse time
    // ("unknown config key 'input.touchpad.accel_profile'"). env.* settings
    // are emitted separately via hl.env() and gestures via hl.gesture().
    if (s.hypr === null) continue

    // Special handling for kb_options - it's a composite
    if (s.id === "input.capslock_behavior") {
      var kbOpts = kbOptionsString(managed)
      setPath(config, s.lua, quote(kbOpts))
      hasConfig = true
      continue
    }

    if (s.lua) {
      setPath(config, s.lua, scalar(value, s.type))
      hasConfig = true
    }

    // Environment variables use hl.env()
    if (s.id && s.id.startsWith("env.") && s.lua && s.lua.length >= 2 && s.lua[0] === "env") {
      var envKey = s.lua[1]
      envText += envLine(envKey, value)
      hasEnv = true
    }
  }

  // Motion leaves are emitted as explicit overrides, grouped so the pair of
  // speed + style for each leaf yields one coherent animation block.
  var has = function (id) { return Object.prototype.hasOwnProperty.call(managed, id) }
  if (has("motion.windows_speed") || has("motion.windows_style")) {
    var ws = has("motion.windows_speed") ? Number(managed["motion.windows_speed"]) : 4
    var wstyle = has("motion.windows_style") ? managed["motion.windows_style"] : "slide"
    anims += animationLine("windows", { enabled: true, speed: ws, bezier: "default" })
    anims += animationLine("windowsIn", { enabled: true, speed: ws, bezier: "default", style: wstyle })
    anims += animationLine("windowsOut", { enabled: true, speed: ws, bezier: "default" })
  }
  if (has("motion.workspaces_speed") || has("motion.workspaces_style")) {
    var sp = has("motion.workspaces_speed") ? Number(managed["motion.workspaces_speed"]) : 8
    var sstyle = has("motion.workspaces_style") ? managed["motion.workspaces_style"] : "slide"
    anims += animationLine("workspaces", { enabled: true, speed: sp, bezier: "default", style: sstyle })
  }

  var gestureText = gestureLine(managed, schema)

  var monitorText = ""
  var list = monitors || []
  for (var mi = 0; mi < list.length; mi++) monitorText += monitorLine(list[mi])

  var out = ""
  out += "-- Omarchy Settings — generated. Do not edit by hand.\n"
  out += "-- Values here are managed by the Settings app and override every file\n"
  out += "-- required before it. Use Reset in the app to release a value.\n\n"

  if (hasConfig) {
    out += "hl.config({\n" + renderTable(config, "") + "})\n\n"
  }

  if (anims.length > 0) {
    out += "-- Motion overrides\n" + anims + "\n"
  }
  if (gestureText.length > 0) {
    out += "-- Gestures\n" + gestureText + "\n"
  }
  if (hasEnv) {
    out += "-- Environment variables\n" + envText + "\n"
  }
  if (monitorText.length > 0) {
    out += "-- Monitor layout\n" + monitorText
  }
  if (!hasConfig && anims.length === 0 && gestureText.length === 0 && monitorText.length === 0 && !hasEnv) {
    out += "-- No settings are currently managed.\n"
  }
  return out
}

// The idempotent marker line appended to hyprland.lua.
var REQUIRE_MARKER = "-- custom-settings:load"

function requireLine() {
  return REQUIRE_MARKER + "\nrequire(\"hypr.settings\")\n"
}

// Returns the text hyprland.lua should have. If the marker is absent the
// block is appended at the end; if present it is left untouched.
function ensureRequire(hyprlandText) {
  if (hyprlandText.indexOf(REQUIRE_MARKER) !== -1) {
    return { changed: false, text: hyprlandText }
  }
  var base = hyprlandText
  if (base.length > 0 && base.charAt(base.length - 1) !== "\n") base += "\n"
  return { changed: true, text: base + "\n" + requireLine() }
}

// Removes the marker line and the require that follows it.
function removeRequire(hyprlandText) {
  var lines = hyprlandText.split("\n")
  var out = []
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].indexOf(REQUIRE_MARKER) !== -1) {
      if (i + 1 < lines.length && lines[i + 1].indexOf("require(\"hypr.settings\")") !== -1) i++
      continue
    }
    out.push(lines[i])
  }
  return { changed: out.length !== lines.length, text: out.join("\n") }
}
