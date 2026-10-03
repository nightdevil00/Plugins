// Pure helpers for the renderer panel. Everything here takes the JSON the
// lib/mihai-renderer.sh script emits and returns plain values, so the QML
// only has to render them.

// Read any list as a plain array.
//
// Quickshell's Repeater does not hand a delegate the object its model held, it
// hands the delegate a wrapped copy, and a wrapped array is array-like without
// passing Array.isArray. So inside a delegate every array reads as "not an
// array" and a guard like `Array.isArray(x) ? x : []` quietly turns a list into
// nothing at all. That is how a monitor plugged into every card was reported as
// "none plugged in": the length and the indexing both work, only the identity
// check lies. Length plus indexing is what actually holds on both sides, so
// that is what this uses.
function list(value) {
  if (value === null || value === undefined) return []
  var n = typeof value.length === "number" ? value.length : -1
  if (n < 0) return []
  var out = []
  for (var i = 0; i < n; i++) out.push(value[i])
  return out
}

// Normalise the PCI address lists the script hands over. Anything that is
// not a plain "0000:00:00.0" string is dropped, so a hand-edited order file
// can never make the panel build a nonsense command line.
function pciList(value) {
  var items = list(value)
  var out = []
  for (var i = 0; i < items.length; i++) {
    var pci = String(items[i] || "").replace(/^\s+|\s+$/g, "").toLowerCase()
    if (!/^[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]$/.test(pci)) continue
    if (out.indexOf(pci) >= 0) continue
    out.push(pci)
  }
  return out
}

// Same length, same order. Both sides go through pciList first, so a bad
// address cannot make two different lists look identical.
function listEquals(a, b) {
  var left = pciList(a)
  var right = pciList(b)
  if (left.length !== right.length) return false
  for (var i = 0; i < left.length; i++) {
    if (left[i] !== right[i]) return false
  }
  return true
}

// GPUs a person can actually pick: virtual ones are not renderers.
function pickableGpus(state) {
  var gpus = (state && state.gpus) || []
  var out = []
  for (var i = 0; i < gpus.length; i++) {
    var gpu = gpus[i]
    if (!gpu || !gpu.pci) continue
    if (gpu.kind === "virtual") continue
    out.push(gpu)
  }
  return out
}

function gpuAt(state, pci) {
  var gpus = pickableGpus(state)
  for (var i = 0; i < gpus.length; i++) {
    if (gpus[i].pci === pci) return gpus[i]
  }
  return null
}

function kindLabel(gpu) {
  if (!gpu) return ""
  if (gpu.kind === "integrated") return "integrated"
  if (gpu.kind === "dedicated") return "dedicated"
  return String(gpu.kind || "")
}

// "Intel · UHD Graphics" style title: the brand is already shown on the
// detail rows, so the title keeps just the marketing name.
// "Intel UHD Graphics" -> "UHD Graphics": the brand has its own row, so
// repeating it in the title only makes the text longer.
function gpuName(gpu) {
  if (!gpu) return ""
  var label = String(gpu.name || "").replace(/^\s+|\s+$/g, "")
  if (!label) return String(gpu.brand || "GPU")
  if (gpu.brand && label.indexOf(String(gpu.brand)) === 0) {
    label = label.substring(String(gpu.brand).length).replace(/^\s+/, "")
  }
  return label || String(gpu.brand || "GPU")
}

function title(gpu) {
  if (!gpu) return ""
  return gpuName(gpu) || String(gpu.brand || "GPU")
}

// What fits in a bar slot: the vendor, not the marketing name.
function brand(gpu) {
  if (!gpu) return ""
  var label = String(gpu.brand || "").replace(/^\s+|\s+$/g, "")
  return label || title(gpu)
}

function hasKind(gpus, kind) {
  for (var i = 0; i < gpus.length; i++) {
    if (gpus[i].kind === kind) return true
  }
  return false
}

function gpusOfKind(gpus, kind) {
  var out = []
  for (var i = 0; i < gpus.length; i++) {
    if (gpus[i].kind === kind) out.push(gpus[i])
  }
  return out
}

// The choices the panel offers, in the order they are listed.
//
// Automatic is always first and clears the list, letting Aquamarine decide
// (it puts the GPU with the built-in screen in front). A hybrid laptop gets
// one choice per kind: picking the dedicated GPU keeps the integrated one in
// the list too, so the built-in screen stays on. Anything else with several
// GPUs gets one choice per GPU, again keeping the rest alive.
function choices(state) {
  var gpus = pickableGpus(state)
  var out = [{ id: "auto", kind: "auto", title: "Automatic", detail: "Let Aquamarine decide", order: [] }]
  if (gpus.length < 2) return out

  var hybrid = state && state.hybrid === true
  var wanted = hybrid ? ["integrated", "dedicated"] : null
  var kinds = wanted || []
  if (!wanted) {
    for (var i = 0; i < gpus.length; i++) {
      if (kinds.indexOf(gpus[i].kind) < 0) kinds.push(gpus[i].kind)
    }
  }

  for (var k = 0; k < kinds.length; k++) {
    var kind = kinds[k]
    var group = gpusOfKind(gpus, kind)
    if (group.length === 0) continue

    if (hybrid) {
      out.push({
        id: kind,
        kind: kind,
        title: kind === "integrated" ? "Integrated graphics" : "Dedicated graphics",
        detail: group.length === 1
          ? title(group[0])
          : group.length + " GPUs",
        order: orderWithFirst(gpus, group[0].pci)
      })
      continue
    }

    for (var g = 0; g < group.length; g++) {
      out.push({
        id: group[g].pci,
        kind: group[g].kind,
        title: title(group[g]),
        detail: kindLabel(group[g]),
        order: orderWithFirst(gpus, group[g].pci)
      })
    }
  }
  return out
}

// The whole pickable list, with one GPU moved to the front. GPUs missing
// from the saved order (a laptop lid switch, a second eGPU) are appended so
// nothing that is plugged in gets dropped from AQ_DRM_DEVICES.
function orderWithFirst(gpus, pci) {
  var rest = []
  for (var i = 0; i < gpus.length; i++) {
    if (gpus[i].pci !== pci) rest.push(gpus[i].pci)
  }
  return pciList([pci].concat(rest))
}

function selectedChoiceId(state) {
  var saved = pciList(state && state.order)
  if (saved.length === 0) return "auto"
  var gpus = pickableGpus(state)
  if (gpus.length === 0) return "auto"

  // A hand-edited order that is not one of the offered choices still has to
  // show as selected, so match it back to the closest choice. An order that
  // only kept one GPU — what the `only-igpu` / `only-dgpu` presets write —
  // is matched on the GPU in front, since "keep the other one alive" is not
  // what such an order asks for.
  var list = choices(state)
  for (var i = 0; i < list.length; i++) {
    if (listEquals(list[i].order, saved)) return list[i].id
  }
  for (var j = 0; j < list.length; j++) {
    if (list[j].order.length === 0) continue
    if (list[j].order[0] === saved[0]) return list[j].id
  }
  for (var k = 0; k < list.length; k++) {
    if (list[k].order.length === 0) continue
    for (var m = 0; m < saved.length; m++) {
      if (list[k].order.indexOf(saved[m]) >= 0) return list[k].id
    }
  }
  return ""
}

// A saved order that differs from what is running needs a new login before
// the desktop switches over.
function pending(state) {
  if (!state) return false
  var saved = pciList(state.order)
  var running = pciList(state.running)
  if (saved.length === 0) return false
  if (running.length === 0) return false
  return !listEquals(saved, running)
}

// Which GPU the compositor is rendering on right now.
function activeGpu(state) {
  var running = pciList(state && state.running)
  if (running.length === 0) return null
  return gpuAt(state, running[0])
}

function barLabel(state) {
  if (!state) return ""
  var gpu = activeGpu(state)
  if (!gpu) return "?"
  return title(gpu)
}

// The screens a user would recognise as "the ones plugged in", plus whether the
// compositor took the card. "connected" is what the kernel sees on the
// connector, which is not the same as a monitor that is actually lit up.
function connectedOutputs(gpu) {
  var out = []
  var items = list(gpu ? gpu.outputs : null)
  for (var i = 0; i < items.length; i++) {
    var entry = items[i]
    if (entry && entry.connected) out.push(String(entry.name || ""))
  }
  return out
}

// The kernel driver and what kind of module it is. A driver that ships with the
// kernel is as different from the NVIDIA one as it gets, and the two are
// maintained and updated completely separately, so it is worth saying which.
function driverLabel(gpu) {
  if (!gpu) return ""
  var name = String(gpu.driver || "").replace(/^\s+|\s+$/g, "")
  if (!name) return "not loaded"
  var flavour = String(gpu.driverFlavour || "").replace(/^\s+|\s+$/g, "")
  return flavour ? name + " · " + flavour : name
}

// The version that driver calls itself. Anything in the kernel tree reports the
// kernel release instead, because there is no separate version to report.
function driverVersionLabel(gpu) {
  if (!gpu) return ""
  var version = String(gpu.driverVersion || "").replace(/^\s+|\s+$/g, "")
  return version || "no version of its own"
}

// One line per GPU: what is driving it, and what that means for the screens
// plugged into it. The PCI address, the card number and integrated/dedicated are
// all still in the JSON — they are what the hook is keyed on — but they are not
// what anyone needs told, so they stay out of the panel.
function gpuDetails(gpu) {
  if (!gpu) return []
  var rows = []
  rows.push({ label: "Driver", value: driverLabel(gpu) })
  rows.push({ label: "Version", value: driverVersionLabel(gpu) })

  var outputs = connectedOutputs(gpu)
  rows.push({ label: "Screens", value: outputs.length > 0 ? outputs.join(", ") : "none plugged in" })
  rows.push({ label: "Name", value: gpu.link ? "/dev/dri/" + String(gpu.link) : "none (cannot render)" })
  return rows
}

// Everything worth telling the user before they pick something. Each entry is
// { text, action } where action is an id the panel knows how to run, or "".
function warnings(state) {
  var out = []
  if (!state) return out

  // A screen the kernel can see but the compositor never modesets. This is what
  // an NVIDIA card with kernel modesetting switched off looks like from the
  // outside: the monitor is plugged in, sysfs reports it connected, and the
  // picture never arrives. Worth saying, because nothing else on screen would.
  var gpus = pickableGpus(state)
  for (var g = 0; g < gpus.length; g++) {
    var gpu = gpus[g]
    var screens = connectedOutputs(gpu)
    if (screens.length === 0) continue
    if (gpu.modeset === false) {
      out.push({
        text: brand(gpu) + " has " + screens.join(", ") + " plugged in, but the compositor never opened it, so that screen stays dark.",
        action: ""
      })
      continue
    }
    if (!gpu.driver) {
      out.push({
        text: brand(gpu) + " has " + screens.join(", ") + " plugged in, but no kernel driver is bound to it.",
        action: ""
      })
    }
  }

  // Only worth saying when there is something to preserve. In automatic mode
  // the hook is written on the next choice, so a missing one is not a problem
  // the user has to hear about before they have picked anything.
  if (pciList(state.order).length > 0) {
    if (state.hook === "stale") {
      out.push({ text: "The login hook does not match the saved order. It is rewritten the next time you pick.", action: "" })
    } else if (state.hook === "missing") {
      out.push({ text: "The login hook is missing, so the saved order would not survive a restart.", action: "" })
    }
  }

  var duplicates = list(state.duplicates)
  for (var i = 0; i < duplicates.length; i++) {
    out.push({ text: "Another config also sets AQ_DRM_DEVICES: " + String(duplicates[i]), action: "" })
  }

  var stray = list(state.stray)
  for (var s = 0; s < stray.length; s++) {
    out.push({ text: "Something else sets AQ_DRM_DEVICES: " + String(stray[s]), action: "" })
  }

  if (state.multi && state.rules === "missing") {
    out.push({ text: "No stable GPU names yet. Cards can be numbered differently after an update, so install them.", action: "links-install" })
  }
  return out
}
