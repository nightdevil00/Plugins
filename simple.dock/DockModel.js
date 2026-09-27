// Pure helpers for the dock plugin. No QML state — the host object owns the
// model; this file only turns inputs into output arrays.

function stripDesktop(id) {
  var value = String(id == null ? "" : id).trim()
  if (value.slice(-8) === ".desktop") value = value.slice(0, -8)
  return value
}

// Normalize a toplevel list. ToplevelManager.toplevels.values is a V4Sequence
// (indexable, has .length) but not a real JS array, so Array.isArray() fails.
// Copy any length/indexable sequence into a plain array.
function toArray(list) {
  if (Array.isArray(list)) return list
  if (list && typeof list.length === "number") {
    var out = []
    for (var i = 0; i < list.length; i++) out.push(list[i])
    return out
  }
  return []
}

function normalizeId(id) {
  return stripDesktop(id)
}

// Parse the persisted dock file into an ordered array of normalized desktop
// ids (no .desktop suffix). Any garbage is dropped; a missing/empty file
// yields [].
function parsePinned(raw) {
  var text = String(raw == null ? "" : raw).trim()
  if (!text) return []

  var parsed = null
  try {
    parsed = JSON.parse(text)
  } catch (e) {
    return []
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return []

  var arr = Array.isArray(parsed.pinned) ? parsed.pinned : []
  var out = []
  var seen = {}
  for (var i = 0; i < arr.length; i++) {
    var id = stripDesktop(arr[i])
    if (!id || seen[id]) continue
    seen[id] = true
    out.push(id)
  }
  return out
}

function serializePinned(pinnedIds) {
  var arr = Array.isArray(pinnedIds) ? pinnedIds : []
  var cleaned = []
  var seen = {}
  for (var i = 0; i < arr.length; i++) {
    var id = stripDesktop(arr[i])
    if (!id || seen[id]) continue
    seen[id] = true
    cleaned.push(id)
  }
  return JSON.stringify({ pinned: cleaned }, null, 2)
}

function togglePinned(pinnedIds, appId) {
  var arr = Array.isArray(pinnedIds) ? pinnedIds.slice() : []
  var id = stripDesktop(appId)
  if (!id) return arr
  var idx = arr.indexOf(id)
  if (idx >= 0) arr.splice(idx, 1)
  else arr.push(id)
  return arr
}

function isPinned(pinnedIds, appId) {
  var arr = Array.isArray(pinnedIds) ? pinnedIds : []
  return arr.indexOf(stripDesktop(appId)) >= 0
}

// Locate the desktop entry whose id matches a normalized app id. `appRows`
// is the array returned by appLibrary.sortedEntries(""), each element having
// `.entry`.
function entryFor(appRows, appId) {
  var want = stripDesktop(appId)
  if (!want || !appRows) return null
  for (var i = 0; i < appRows.length; i++) {
    var row = appRows[i]
    var entry = row && row.entry
    if (!entry) continue
    if (stripDesktop(entry.id) === want) return entry
  }
  return null
}

// Build the dock sections. Pinned apps first (in pinned order), then running
// apps that are not pinned (in window order). Running apps that are pinned
// stay in the pinned section with their running state attached.
//
// Returns { pinned: [...], running: [...] } where each entry is
// { appId, name, icon, pinned, running, windows }.
// `appLibrary` is shell.appLibrary, used for names, icons, and launch.
function buildEntries(pinnedIds, toplevels, appRows, appLibrary) {
  var pinned = Array.isArray(pinnedIds) ? pinnedIds : []
  var list = toArray(toplevels)

  var runningIds = []
  var winCounts = {}
  for (var i = 0; i < list.length; i++) {
    var toplevel = list[i]
    if (!toplevel) continue
    var appId = stripDesktop(toplevel.appId)
    if (!appId) continue
    if (!winCounts[appId]) {
      winCounts[appId] = 0
      runningIds.push(appId)
    }
    winCounts[appId] += 1
  }

  function enrich(list) {
    for (var j = 0; j < list.length; j++) {
      var entry = entryFor(appRows, list[j].appId)
      if (entry && appLibrary) {
        list[j].name = appLibrary.entryName(entry)
        list[j].icon = appLibrary.iconSource(entry.icon)
      } else {
        list[j].name = list[j].appId
        list[j].icon = ""
      }
    }
  }

  var pinnedOut = []
  var seen = {}
  var j = 0

  for (j = 0; j < pinned.length; j++) {
    var pid = stripDesktop(pinned[j])
    if (!pid || seen[pid]) continue
    seen[pid] = true
    pinnedOut.push({ appId: pid, pinned: true, running: winCounts[pid] > 0, windows: winCounts[pid] || 0 })
  }
  enrich(pinnedOut)

  var runningOut = []
  for (j = 0; j < runningIds.length; j++) {
    var rid = runningIds[j]
    if (seen[rid]) continue
    seen[rid] = true
    runningOut.push({ appId: rid, pinned: false, running: true, windows: winCounts[rid] })
  }
  enrich(runningOut)

  return { pinned: pinnedOut, running: runningOut }
}

// Normalized id of the window currently in the foreground, or "".
function activeAppId(toplevels, activeToplevel) {
  var top = activeToplevel || null
  if (top) return stripDesktop(top.appId)
  var list = toArray(toplevels)
  if (list.length > 0) return stripDesktop(list[0].appId)
  return ""
}

// Activate a window belonging to the given app. Prefers the active window
// (already focused — no-op) then the most recently focused, then any window.
function activateApp(toplevels, activeToplevel, appId) {
  var want = stripDesktop(appId)
  if (!want) return
  var list = toArray(toplevels)

  var top = activeToplevel || null
  if (top && stripDesktop(top.appId) === want) {
    if (top.activate) top.activate()
    return
  }

  for (var i = 0; i < list.length; i++) {
    var t = list[i]
    if (!t) continue
    if (stripDesktop(t.appId) === want) {
      if (t.activate) t.activate()
      return
    }
  }
}

// Close every window belonging to the app. Returns how many were closed.
function closeApp(toplevels, appId) {
  var want = stripDesktop(appId)
  if (!want) return 0
  var list = toArray(toplevels)
  var closed = 0
  for (var i = 0; i < list.length; i++) {
    var t = list[i]
    if (!t) continue
    if (stripDesktop(t.appId) === want) {
      if (t.close) t.close()
      closed += 1
    }
  }
  return closed
}
