.pragma library

// Omarchy Settings — the settings surface.
//
// Every entry is data. The UI renders it generically; the store reads its
// live value from Hyprland (`hyprctl -j getoption`) and writes only the
// values the user changed into ~/.config/hypr/settings.lua, which is
// required last so it wins over Omarchy's defaults and the user's own files.
//
// Fields:
//   id       unique key, also the persistence key
//   page     which page renders it
//   group    section heading within the page (rows with the same group sit
//            under one heading; no dividers — whitespace only)
//   label    row title
//   desc     one line of muted help text
//   type     "bool" | "int" | "float" | "enum" | "string"
//   hypr     hyprctl getoption name; absent means the value is app-only
//            (an animation leaf, for example) and is read back from state
//   lua      path into the settings.lua hl.config() table
//   default  the Omarchy/Hyprland default, shown when nothing manages it
//   min/max/step   range for numeric types
//   options  [{value,label}] for enum
//   percent  numeric display as a percentage (floats)
//   leaf     when set, emitted as hl.animation() with this leaf instead of
//            entering the hl.config() tree (motion page)

var pages = [
  { id: "appearance", label: "Appearance",   icon: "󰸌", desc: "Theme, type, depth, and the shape of windows." },
  { id: "window",     label: "Window",        icon: "", desc: "Gaps, borders, and the tiling layout." },
  { id: "motion",     label: "Motion",        icon: "󰓅", desc: "How the compositor moves between states." },
  { id: "input",      label: "Input",         icon: "", desc: "Keyboard, pointer, and touchpad behaviour." },
  { id: "display",    label: "Display",       icon: "󰍹", desc: "Monitors, resolution, scale, and arrangement." },
  { id: "environment", label: "Environment", icon: "󰒓", desc: "Environment variables for Hyprland, Aquamarine, and toolkits." },
  { id: "bar",        label: "Bar & Plugins", icon: "󰍜", desc: "The menu bar and the shell plugins it hosts." },
  { id: "idle",       label: "Idle & Lock",   icon: "󱄄", desc: "Screensaver and lock timing." },
  { id: "nightlight", label: "Night Light",   icon: "󰔎", desc: "Warm the screen after dark." },
  { id: "updates",    label: "Updates",       icon: "", desc: "Channel, availability, and the update actions." },
  { id: "about",      label: "About",         icon: "\uF02D", desc: "Version, health, and ways back." }
]

var settings = [
  // ------------------------------------------------------------- appearance
  { id: "decoration.rounding", page: "appearance", group: "Shape",
    label: "Corner radius", desc: "Round windows. 0 is square; 24 matches the shell's cards.",
    type: "int", hypr: "decoration:rounding", lua: ["decoration", "rounding"],
    default: 0, min: 0, max: 40, step: 1, unit: "px" },

  { id: "decoration.rounding_power", page: "appearance", group: "Shape",
    label: "Rounding power", desc: "Power of corners (2 is a circle).",
    type: "int", hypr: "decoration:rounding_power", lua: ["decoration", "rounding_power"],
    default: 2, min: 2, max: 10, step: 1 },

  { id: "decoration.active_opacity", page: "appearance", group: "Depth",
    label: "Focused opacity", desc: "Opacity of the window you are using.",
    type: "float", hypr: "decoration:active_opacity", lua: ["decoration", "active_opacity"],
    default: 1, min: 0.5, max: 1, step: 0.01, percent: true },

  { id: "decoration.inactive_opacity", page: "appearance", group: "Depth",
    label: "Unfocused opacity", desc: "Opacity of every window behind the focused one.",
    type: "float", hypr: "decoration:inactive_opacity", lua: ["decoration", "inactive_opacity"],
    default: 1, min: 0.3, max: 1, step: 0.01, percent: true },

  { id: "decoration.fullscreen_opacity", page: "appearance", group: "Depth",
    label: "Fullscreen opacity", desc: "Opacity of fullscreen windows.",
    type: "float", hypr: "decoration:fullscreen_opacity", lua: ["decoration", "fullscreen_opacity"],
    default: 1, min: 0, max: 1, step: 0.01, percent: true },

  { id: "decoration.dim_inactive", page: "appearance", group: "Depth",
    label: "Dim unfocused", desc: "Darken windows that are not focused.",
    type: "bool", hypr: "decoration:dim_inactive", lua: ["decoration", "dim_inactive"],
    default: false },

  { id: "decoration.dim_modal", page: "appearance", group: "Depth",
    label: "Dim modal", desc: "Dim parents of modal windows.",
    type: "bool", hypr: "decoration:dim_modal", lua: ["decoration", "dim_modal"],
    default: true },

  { id: "decoration.dim_special", page: "appearance", group: "Depth",
    label: "Dim special", desc: "Dim the rest of the screen when a special workspace is open.",
    type: "float", hypr: "decoration:dim_special", lua: ["decoration", "dim_special"],
    default: 0.2, min: 0, max: 1, step: 0.01, percent: true },

  { id: "decoration.dim_around", page: "appearance", group: "Depth",
    label: "Dim around", desc: "Dim around the dimaround window rule.",
    type: "float", hypr: "decoration:dim_around", lua: ["decoration", "dim_around"],
    default: 0.4, min: 0, max: 1, step: 0.01, percent: true },

  { id: "decoration.dim_strength", page: "appearance", group: "Depth",
    label: "Dim strength", desc: "How far unfocused windows are pushed down.",
    type: "float", hypr: "decoration:dim_strength", lua: ["decoration", "dim_strength"],
    default: 0.15, min: 0, max: 1, step: 0.01, percent: true },

  { id: "decoration.blur.enabled", page: "appearance", group: "Glass",
    label: "Blur", desc: "Blur what sits behind translucent windows.",
    type: "bool", hypr: "decoration:blur:enabled", lua: ["decoration", "blur", "enabled"],
    default: false },

  { id: "decoration.blur.size", page: "appearance", group: "Glass",
    label: "Blur size", desc: "Radius of the blur kernel.",
    type: "int", hypr: "decoration:blur:size", lua: ["decoration", "blur", "size"],
    default: 8, min: 0, max: 100, step: 1 },

  { id: "decoration.blur.passes", page: "appearance", group: "Glass",
    label: "Blur passes", desc: "Amount of passes to perform.",
    type: "int", hypr: "decoration:blur:passes", lua: ["decoration", "blur", "passes"],
    default: 1, min: 0, max: 10, step: 1 },

  { id: "decoration.blur.ignore_opacity", page: "appearance", group: "Glass",
    label: "Blur ignore opacity", desc: "Blur layer ignores window opacity.",
    type: "bool", hypr: "decoration:blur:ignore_opacity", lua: ["decoration", "blur", "ignore_opacity"],
    default: true },

  { id: "decoration.blur.new_optimizations", page: "appearance", group: "Glass",
    label: "Blur optimizations", desc: "Further optimizations to blur. Recommended.",
    type: "bool", hypr: "decoration:blur:new_optimizations", lua: ["decoration", "blur", "new_optimizations"],
    default: true },

  { id: "decoration.blur.xray", page: "appearance", group: "Glass",
    label: "Blur xray", desc: "Floating windows ignore tiled windows in blur.",
    type: "bool", hypr: "decoration:blur:xray", lua: ["decoration", "blur", "xray"],
    default: false },

  { id: "decoration.blur.noise", page: "appearance", group: "Glass",
    label: "Blur noise", desc: "Noise to apply.",
    type: "float", hypr: "decoration:blur:noise", lua: ["decoration", "blur", "noise"],
    default: 0.0117, min: 0, max: 1, step: 0.001 },

  { id: "decoration.blur.contrast", page: "appearance", group: "Glass",
    label: "Blur contrast", desc: "Contrast modulation for blur.",
    type: "float", hypr: "decoration:blur:contrast", lua: ["decoration", "blur", "contrast"],
    default: 0.8916, min: 0, max: 2, step: 0.01 },

  { id: "decoration.blur.brightness", page: "appearance", group: "Glass",
    label: "Blur brightness", desc: "Brightness modulation for blur.",
    type: "float", hypr: "decoration:blur:brightness", lua: ["decoration", "blur", "brightness"],
    default: 0.8172, min: 0, max: 2, step: 0.01 },

  { id: "decoration.blur.vibrancy", page: "appearance", group: "Glass",
    label: "Blur vibrancy", desc: "Increase saturation of blurred colors.",
    type: "float", hypr: "decoration:blur:vibrancy", lua: ["decoration", "blur", "vibrancy"],
    default: 0.1696, min: 0, max: 1, step: 0.01 },

  { id: "decoration.blur.vibrancy_darkness", page: "appearance", group: "Glass",
    label: "Blur vibrancy darkness", desc: "How strong vibrancy is on dark areas.",
    type: "float", hypr: "decoration:blur:vibrancy_darkness", lua: ["decoration", "blur", "vibrancy_darkness"],
    default: 0, min: 0, max: 1, step: 0.01 },

  { id: "decoration.blur.special", page: "appearance", group: "Glass",
    label: "Blur special", desc: "Blur behind the special workspace.",
    type: "bool", hypr: "decoration:blur:special", lua: ["decoration", "blur", "special"],
    default: false },

  { id: "decoration.blur.popups", page: "appearance", group: "Glass",
    label: "Blur popups", desc: "Blur popups (e.g. right-click menus).",
    type: "bool", hypr: "decoration:blur:popups", lua: ["decoration", "blur", "popups"],
    default: false },

  { id: "decoration.blur.popups_ignorealpha", page: "appearance", group: "Glass",
    label: "Blur popups ignorealpha", desc: "Don't blur if pixel opacity below this value.",
    type: "float", hypr: "decoration:blur:popups_ignorealpha", lua: ["decoration", "blur", "popups_ignorealpha"],
    default: 0.2, min: 0, max: 1, step: 0.01 },

  { id: "decoration.blur.input_methods", page: "appearance", group: "Glass",
    label: "Blur input methods", desc: "Blur input methods (e.g. fcitx5).",
    type: "bool", hypr: "decoration:blur:input_methods", lua: ["decoration", "blur", "input_methods"],
    default: false },

  { id: "decoration.blur.input_methods_ignorealpha", page: "appearance", group: "Glass",
    label: "Blur input methods ignorealpha", desc: "Don't blur input methods if pixel opacity below this value.",
    type: "float", hypr: "decoration:blur:input_methods_ignorealpha", lua: ["decoration", "blur", "input_methods_ignorealpha"],
    default: 0.2, min: 0, max: 1, step: 0.01 },

  { id: "decoration.shadow.enabled", page: "appearance", group: "Glass",
    label: "Window shadows", desc: "A soft shadow behind each window.",
    type: "bool", hypr: "decoration:shadow:enabled", lua: ["decoration", "shadow", "enabled"],
    default: false },

  { id: "decoration.shadow.range", page: "appearance", group: "Glass",
    label: "Shadow range", desc: "Shadow range in layout px.",
    type: "int", hypr: "decoration:shadow:range", lua: ["decoration", "shadow", "range"],
    default: 4, min: 0, max: 100, step: 1 },

  { id: "decoration.shadow.render_power", page: "appearance", group: "Glass",
    label: "Shadow render power", desc: "Power to render the falloff.",
    type: "int", hypr: "decoration:shadow:render_power", lua: ["decoration", "shadow", "render_power"],
    default: 3, min: 1, max: 4, step: 1 },

  { id: "decoration.shadow.sharp", page: "appearance", group: "Glass",
    label: "Shadow sharp", desc: "Sharp shadow.",
    type: "bool", hypr: "decoration:shadow:sharp", lua: ["decoration", "shadow", "sharp"],
    default: false },

  { id: "decoration.shadow.color", page: "appearance", group: "Glass",
    label: "Shadow color", desc: "Shadow color. Alpha dictates opacity.",
    type: "color", hypr: "decoration:shadow:color", lua: ["decoration", "shadow", "color"],
    default: "0xee1a1a1a" },

  { id: "decoration.shadow.color_inactive", page: "appearance", group: "Glass",
    label: "Shadow color inactive", desc: "Inactive shadow color.",
    type: "color", hypr: "decoration:shadow:color_inactive", lua: ["decoration", "shadow", "color_inactive"],
    default: "-1" },

  { id: "decoration.shadow.offset", page: "appearance", group: "Glass",
    label: "Shadow offset", desc: "Shadow rendering offset.",
    type: "vec2", hypr: "decoration:shadow:offset", lua: ["decoration", "shadow", "offset"],
    default: { x: -250, y: -250 } },

  { id: "decoration.shadow.scale", page: "appearance", group: "Glass",
    label: "Shadow scale", desc: "Shadow scale.",
    type: "float", hypr: "decoration:shadow:scale", lua: ["decoration", "shadow", "scale"],
    default: 1, min: 0, max: 1, step: 0.01 },

  { id: "decoration.glow.enabled", page: "appearance", group: "Glass",
    label: "Inner glow", desc: "Inner glow on windows.",
    type: "bool", hypr: "decoration:glow:enabled", lua: ["decoration", "glow", "enabled"],
    default: false },

  { id: "decoration.glow.range", page: "appearance", group: "Glass",
    label: "Glow range", desc: "Glow range in layout px.",
    type: "int", hypr: "decoration:glow:range", lua: ["decoration", "glow", "range"],
    default: 10, min: 0, max: 100, step: 1 },

  { id: "decoration.glow.render_power", page: "appearance", group: "Glass",
    label: "Glow render power", desc: "Power to render the glow falloff.",
    type: "int", hypr: "decoration:glow:render_power", lua: ["decoration", "glow", "render_power"],
    default: 3, min: 1, max: 4, step: 1 },

  { id: "decoration.glow.color", page: "appearance", group: "Glass",
    label: "Glow color", desc: "Glow color. Alpha dictates opacity.",
    type: "color", hypr: "decoration:glow:color", lua: ["decoration", "glow", "color"],
    default: "0xee33ccff" },

  { id: "decoration.glow.color_inactive", page: "appearance", group: "Glass",
    label: "Glow color inactive", desc: "Inactive glow color.",
    type: "color", hypr: "decoration:glow:color_inactive", lua: ["decoration", "glow", "color_inactive"],
    default: "0x0033ccff" },

  { id: "decoration.border_part_of_window", page: "appearance", group: "Glass",
    label: "Border part of window", desc: "Border treated as part of the window.",
    type: "bool", hypr: "decoration:border_part_of_window", lua: ["decoration", "border_part_of_window"],
    default: true },

  { id: "decoration.screen_shader", page: "appearance", group: "Glass",
    label: "Screen shader", desc: "Path to a custom shader to apply at end of rendering.",
    type: "string", hypr: "decoration:screen_shader", lua: ["decoration", "screen_shader"],
    default: "" },

  // ----------------------------------------------------------------- window
  { id: "general.layout", page: "window", group: "Layout",
    label: "Tiling layout", desc: "How new windows are placed on a workspace.",
    type: "enum", hypr: "general:layout", lua: ["general", "layout"],
    default: "dwindle",
    options: [
      { value: "dwindle",   label: "Dwindle" },
      { value: "master",    label: "Master" },
      { value: "scrolling", label: "Scrolling" },
      { value: "monocle",   label: "Monocle" }
    ] },

  { id: "general.gaps_in", page: "window", group: "Spacing",
    label: "Inner gaps", desc: "Space between adjacent windows.",
    type: "int", hypr: "general:gaps_in", lua: ["general", "gaps_in"],
    default: 5, min: 0, max: 50, step: 1, unit: "px" },

  { id: "general.gaps_out", page: "window", group: "Spacing",
    label: "Outer gaps", desc: "Space between windows and the screen edge.",
    type: "int", hypr: "general:gaps_out", lua: ["general", "gaps_out"],
    default: 10, min: 0, max: 100, step: 1, unit: "px" },

  { id: "general.border_size", page: "window", group: "Spacing",
    label: "Border size", desc: "Thickness of the window border.",
    type: "int", hypr: "general:border_size", lua: ["general", "border_size"],
    default: 2, min: 0, max: 10, step: 1, unit: "px" },

  { id: "general.allow_tearing", page: "window", group: "Layout",
    label: "Allow tearing", desc: "Master switch for allowing tearing.",
    type: "bool", hypr: "general:allow_tearing", lua: ["general", "allow_tearing"],
    default: false },

  { id: "general.no_focus_fallback", page: "window", group: "Layout",
    label: "No focus fallback", desc: "Don't focus the window on focus fallback.",
    type: "bool", hypr: "general:no_focus_fallback", lua: ["general", "no_focus_fallback"],
    default: false },

  { id: "general.modal_parent_blocking", page: "window", group: "Layout",
    label: "Modal parent blocking", desc: "Parent windows of modals are not interactive.",
    type: "bool", hypr: "general:modal_parent_blocking", lua: ["general", "modal_parent_blocking"],
    default: true },

  { id: "general.locale", page: "window", group: "Layout",
    label: "Locale", desc: "Overrides the system locale.",
    type: "string", hypr: "general:locale", lua: ["general", "locale"],
    default: "" },

  { id: "general.snap.enabled", page: "window", group: "Snap",
    label: "Snap enabled", desc: "Enable snapping for floating windows.",
    type: "bool", hypr: "general:snap:enabled", lua: ["general", "snap", "enabled"],
    default: false },

  { id: "general.snap.window_gap", page: "window", group: "Snap",
    label: "Snap window gap", desc: "Minimum gap before snapping.",
    type: "int", hypr: "general:snap:window_gap", lua: ["general", "snap", "window_gap"],
    default: 10, min: 0, max: 100, step: 1, unit: "px" },

  { id: "general.snap.monitor_gap", page: "window", group: "Snap",
    label: "Snap monitor gap", desc: "Minimum gap between window and monitor edges.",
    type: "int", hypr: "general:snap:monitor_gap", lua: ["general", "snap", "monitor_gap"],
    default: 10, min: 0, max: 100, step: 1, unit: "px" },

  { id: "general.snap.border_overlap", page: "window", group: "Snap",
    label: "Snap border overlap", desc: "Only one border's worth of space between windows.",
    type: "bool", hypr: "general:snap:border_overlap", lua: ["general", "snap", "border_overlap"],
    default: false },

  { id: "general.snap.respect_gaps", page: "window", group: "Snap",
    label: "Snap respect gaps", desc: "Snapping respects gaps between windows.",
    type: "bool", hypr: "general:snap:respect_gaps", lua: ["general", "snap", "respect_gaps"],
    default: false },

  { id: "general.resize_on_border", page: "window", group: "Layout",
    label: "Resize on border", desc: "Drag the border to resize instead of to move.",
    type: "bool", hypr: "general:resize_on_border", lua: ["general", "resize_on_border"],
    default: false },

  { id: "dwindle.preserve_split", page: "window", group: "Dwindle",
    label: "Preserve split", desc: "Keep the split direction when the window changes.",
    type: "bool", hypr: "dwindle:preserve_split", lua: ["dwindle", "preserve_split"],
    default: false },

  { id: "dwindle.force_split", page: "window", group: "Dwindle",
    label: "Force split", desc: "Which side a newly opened window lands on.",
    type: "enum", hypr: "dwindle:force_split", lua: ["dwindle", "force_split"],
    default: "0",
    options: [
      { value: "0", label: "Follow mouse" },
      { value: "1", label: "Left / top" },
      { value: "2", label: "Right / bottom" }
    ] },

  { id: "dwindle.smart_split", page: "window", group: "Dwindle",
    label: "Smart split", desc: "Split based on cursor position (enables preserve_split).",
    type: "bool", hypr: "dwindle:smart_split", lua: ["dwindle", "smart_split"],
    default: false },

  { id: "dwindle.smart_resizing", page: "window", group: "Dwindle",
    label: "Smart resizing", desc: "Resize direction from mouse position on window.",
    type: "bool", hypr: "dwindle:smart_resizing", lua: ["dwindle", "smart_resizing"],
    default: true },

  { id: "dwindle.permanent_direction_override", page: "window", group: "Dwindle",
    label: "Permanent direction override", desc: "Make preselect direction persist.",
    type: "bool", hypr: "dwindle:permanent_direction_override", lua: ["dwindle", "permanent_direction_override"],
    default: false },

  { id: "dwindle.split_width_multiplier", page: "window", group: "Dwindle",
    label: "Split width multiplier", desc: "Auto-split width multiplier for widescreen.",
    type: "float", hypr: "dwindle:split_width_multiplier", lua: ["dwindle", "split_width_multiplier"],
    default: 1.0, min: 0.5, max: 2.0, step: 0.1 },

  { id: "dwindle.use_active_for_splits", page: "window", group: "Dwindle",
    label: "Use active for splits", desc: "Prefer active window over mouse for splits.",
    type: "bool", hypr: "dwindle:use_active_for_splits", lua: ["dwindle", "use_active_for_splits"],
    default: true },

  { id: "dwindle.default_split_ratio", page: "window", group: "Dwindle",
    label: "Default split ratio", desc: "Default split ratio on window open (1 = 50/50).",
    type: "float", hypr: "dwindle:default_split_ratio", lua: ["dwindle", "default_split_ratio"],
    default: 1.0, min: 0.1, max: 1.9, step: 0.05 },

  { id: "dwindle.split_bias", page: "window", group: "Dwindle",
    label: "Split bias", desc: "Which window receives the split ratio.",
    type: "enum", hypr: "dwindle:split_bias", lua: ["dwindle", "split_bias"],
    default: "0",
    options: [
      { value: "0", label: "Directional (top/left)" },
      { value: "1", label: "Current window" }
    ] },

  { id: "dwindle.precise_mouse_move", page: "window", group: "Dwindle",
    label: "Precise mouse move", desc: "Drop windows more precisely based on mouse position.",
    type: "bool", hypr: "dwindle:precise_mouse_move", lua: ["dwindle", "precise_mouse_move"],
    default: false },

  { id: "dwindle.single_window_aspect_ratio", page: "window", group: "Dwindle",
    label: "Single window aspect ratio", desc: "Aspect ratio for single window on workspace.",
    type: "vec2", hypr: "dwindle:single_window_aspect_ratio", lua: ["dwindle", "single_window_aspect_ratio"],
    default: { x: 0, y: 0 } },

  { id: "dwindle.single_window_aspect_ratio_tolerance", page: "window", group: "Dwindle",
    label: "Single window aspect tolerance", desc: "Tolerance for single window aspect ratio.",
    type: "float", hypr: "dwindle:single_window_aspect_ratio_tolerance", lua: ["dwindle", "single_window_aspect_ratio_tolerance"],
    default: 0.1, min: 0, max: 1, step: 0.05 },

  { id: "dwindle.pseudotile", page: "window", group: "Dwindle",
    label: "Pseudotile", desc: "Pseudotiled windows retain floating size when tiled.",
    type: "bool", hypr: "dwindle:pseudotile", lua: ["dwindle", "pseudotile"],
    default: false },

  { id: "master.new_status", page: "window", group: "Master",
    label: "New window role", desc: "Whether a new window becomes the master.",
    type: "enum", hypr: "master:new_status", lua: ["master", "new_status"],
    default: "master",
    options: [
      { value: "master", label: "Master" },
      { value: "slave",  label: "Slave" },
      { value: "inherit", label: "Inherit" }
    ] },

  { id: "master.orientation", page: "window", group: "Master",
    label: "Orientation", desc: "Default placement of the master area.",
    type: "enum", hypr: "master:orientation", lua: ["master", "orientation"],
    default: "left",
    options: [
      { value: "left",   label: "Left" },
      { value: "right",  label: "Right" },
      { value: "top",    label: "Top" },
      { value: "bottom", label: "Bottom" },
      { value: "center", label: "Center" }
    ] },

  { id: "master.mfact", page: "window", group: "Master",
    label: "Master factor", desc: "Proportion of screen for master area (0.1-0.9).",
    type: "float", hypr: "master:mfact", lua: ["master", "mfact"],
    default: 0.55, min: 0.1, max: 0.9, step: 0.05, percent: true },

  { id: "master.smart_resizing", page: "window", group: "Master",
    label: "Smart resizing", desc: "Resize direction from mouse position on window.",
    type: "bool", hypr: "master:smart_resizing", lua: ["master", "smart_resizing"],
    default: true },

  { id: "master.special_scale_factor", page: "window", group: "Master",
    label: "Special scale factor", desc: "Scale of windows on special workspace [0-1].",
    type: "float", hypr: "master:special_scale_factor", lua: ["master", "special_scale_factor"],
    default: 1.0, min: 0, max: 1, step: 0.1 },

  { id: "master.slave_count_for_center_master", page: "window", group: "Master",
    label: "Slave count for center master", desc: "Number of slaves before center master.",
    type: "int", hypr: "master:slave_count_for_center_master", lua: ["master", "slave_count_for_center_master"],
    default: 2, min: 1, max: 10, step: 1 },

  { id: "master.center_master_fallback", page: "window", group: "Master",
    label: "Center master fallback", desc: "Fallback direction for center master.",
    type: "enum", hypr: "master:center_master_fallback", lua: ["master", "center_master_fallback"],
    default: "left",
    options: [
      { value: "left",   label: "Left" },
      { value: "right",  label: "Right" },
      { value: "top",    label: "Top" },
      { value: "bottom", label: "Bottom" }
    ] },

  { id: "master.center_ignores_reserved", page: "window", group: "Master",
    label: "Center ignores reserved", desc: "Center master ignores reserved areas.",
    type: "int", hypr: "master:center_ignores_reserved", lua: ["master", "center_ignores_reserved"],
    default: 0, min: 0, max: 1, step: 1 },

  { id: "master.new_on_active", page: "window", group: "Master",
    label: "New on active", desc: "Where new windows open relative to master.",
    type: "enum", hypr: "master:new_on_active", lua: ["master", "new_on_active"],
    default: "none",
    options: [
      { value: "none",   label: "None" },
      { value: "top",    label: "Top" },
      { value: "bottom", label: "Bottom" }
    ] },

  { id: "master.new_on_top", page: "window", group: "Master",
    label: "New on top", desc: "New windows open on top.",
    type: "bool", hypr: "master:new_on_top", lua: ["master", "new_on_top"],
    default: false },

  { id: "master.allow_small_split", page: "window", group: "Master",
    label: "Allow small split", desc: "Allow small splits in master layout.",
    type: "bool", hypr: "master:allow_small_split", lua: ["master", "allow_small_split"],
    default: false },

  { id: "master.drop_at_cursor", page: "window", group: "Master",
    label: "Drop at cursor", desc: "Drop windows at cursor position.",
    type: "bool", hypr: "master:drop_at_cursor", lua: ["master", "drop_at_cursor"],
    default: true },

  { id: "master.always_keep_position", page: "window", group: "Master",
    label: "Always keep position", desc: "Always keep window position.",
    type: "bool", hypr: "master:always_keep_position", lua: ["master", "always_keep_position"],
    default: false },

  { id: "monocle.no_gap_when_only", page: "window", group: "Monocle",
    label: "No gap when only", desc: "No gap when only one window.",
    type: "bool", hypr: "monocle:no_gap_when_only", lua: ["monocle", "no_gap_when_only"],
    default: false },

  { id: "monocle.gaps_when_only", page: "window", group: "Monocle",
    label: "Gaps when only", desc: "Gaps when only one window.",
    type: "int", hypr: "monocle:gaps_when_only", lua: ["monocle", "gaps_when_only"],
    default: 0, min: 0, max: 50, step: 1, unit: "px" },

  { id: "scrolling.column_width", page: "window", group: "Scrolling",
    label: "Column width", desc: "Width of a scrolling column as a fraction of the screen.",
    type: "float", hypr: "scrolling:column_width", lua: ["scrolling", "column_width"],
    default: 0.5, min: 0.1, max: 1, step: 0.01, percent: true },

  { id: "scrolling.direction", page: "window", group: "Scrolling",
    label: "Direction", desc: "Direction in which new windows appear and layout scrolls.",
    type: "enum", hypr: "scrolling:direction", lua: ["scrolling", "direction"],
    default: "right",
    options: [
      { value: "right", label: "Right" },
      { value: "left",  label: "Left" },
      { value: "down",  label: "Down" },
      { value: "up",    label: "Up" }
    ] },

  { id: "scrolling.fullscreen_on_one_column", page: "window", group: "Scrolling",
    label: "Fullscreen on one column", desc: "Single column spans entire screen.",
    type: "bool", hypr: "scrolling:fullscreen_on_one_column", lua: ["scrolling", "fullscreen_on_one_column"],
    default: true },

  { id: "scrolling.smart_resizing", page: "window", group: "Scrolling",
    label: "Smart resizing", desc: "Resize direction from mouse position on window.",
    type: "bool", hypr: "scrolling:smart_resizing", lua: ["scrolling", "smart_resizing"],
    default: true },

  { id: "scrolling.wrap_focus", page: "window", group: "Scrolling",
    label: "Wrap focus", desc: "Focus wraps around at beginning/end.",
    type: "bool", hypr: "scrolling:wrap_focus", lua: ["scrolling", "wrap_focus"],
    default: true },

  { id: "scrolling.wrap_swapcol", page: "window", group: "Scrolling",
    label: "Wrap swap column", desc: "Column swap wraps around at beginning/end.",
    type: "bool", hypr: "scrolling:wrap_swapcol", lua: ["scrolling", "wrap_swapcol"],
    default: true },

  { id: "scrolling.focus_fit_method", page: "window", group: "Scrolling",
    label: "Focus fit method", desc: "How to bring focused column into view.",
    type: "enum", hypr: "scrolling:focus_fit_method", lua: ["scrolling", "focus_fit_method"],
    default: "1",
    options: [
      { value: "0", label: "Center" },
      { value: "1", label: "Fit" }
    ] },

  { id: "scrolling.follow_focus", page: "window", group: "Scrolling",
    label: "Follow focus", desc: "Auto-scroll to bring focused window into view.",
    type: "bool", hypr: "scrolling:follow_focus", lua: ["scrolling", "follow_focus"],
    default: true },

  { id: "scrolling.follow_min_visible", page: "window", group: "Scrolling",
    label: "Follow min visible", desc: "Min fraction visible before auto-follow [0-1].",
    type: "float", hypr: "scrolling:follow_min_visible", lua: ["scrolling", "follow_min_visible"],
    default: 0.4, min: 0, max: 1, step: 0.1 },

  { id: "scrolling.explicit_column_widths", page: "window", group: "Scrolling",
    label: "Explicit column widths", desc: "Comma-separated preconfigured widths for colresize.",
    type: "string", hypr: "scrolling:explicit_column_widths", lua: ["scrolling", "explicit_column_widths"],
    default: "0.333, 0.5, 0.667, 1.0" },

  // ----------------------------------------------------------------- motion
  { id: "animations.enabled", page: "motion", group: "Global",
    label: "Animations", desc: "The master switch for compositor motion.",
    type: "bool", hypr: "animations:enabled", lua: ["animations", "enabled"],
    default: true },

  { id: "motion.windows_speed", page: "motion", group: "Windows",
    label: "Window speed", desc: "Open, close, and move. Higher is slower.",
    type: "int", hypr: null, lua: null, leaf: "windows",
    default: 4, min: 0, max: 15, step: 1 },

  { id: "motion.windows_style", page: "motion", group: "Windows",
    label: "Window style", desc: "How a window enters and leaves.",
    type: "enum", hypr: null, lua: null, leaf: "windowsIn",
    default: "slide",
    options: [
      { value: "slide", label: "Slide" },
      { value: "slidefade", label: "Slide + fade" },
      { value: "popin 87%", label: "Pop" }
    ] },

  { id: "motion.workspaces_speed", page: "motion", group: "Workspaces",
    label: "Workspace speed", desc: "Sliding between workspaces. Higher is slower.",
    type: "int", hypr: null, lua: null, leaf: "workspaces",
    default: 8, min: 0, max: 20, step: 1 },

  { id: "motion.workspaces_style", page: "motion", group: "Workspaces",
    label: "Workspace style", desc: "How a workspace change reads.",
    type: "enum", hypr: null, lua: null, leaf: "workspaces",
    default: "slide",
    options: [
      { value: "slide", label: "Slide" },
      { value: "slidefade", label: "Slide + fade" },
      { value: "slidefadevert 20%", label: "Vertical" },
      { value: "fade", label: "Fade" }
    ] },

  // ------------------------------------------------------------------ input
  { id: "input.kb_layout", page: "input", group: "Keyboard",
    label: "Layout", desc: "XKB layout, e.g. us or us,de.",
    type: "string", hypr: "input:kb_layout", lua: ["input", "kb_layout"],
    default: "us" },

  { id: "input.kb_variant", page: "input", group: "Keyboard",
    label: "Variant", desc: "Optional XKB variant, e.g. intl.",
    type: "string", hypr: "input:kb_variant", lua: ["input", "kb_variant"],
    default: "" },

  { id: "input.repeat_rate", page: "input", group: "Keyboard",
    label: "Repeat rate", desc: "Key repeats per second when held.",
    type: "int", hypr: "input:repeat_rate", lua: ["input", "repeat_rate"],
    default: 40, min: 10, max: 100, step: 1 },

  { id: "input.repeat_delay", page: "input", group: "Keyboard",
    label: "Repeat delay", desc: "Milliseconds before a held key repeats.",
    type: "int", hypr: "input:repeat_delay", lua: ["input", "repeat_delay"],
    default: 250, min: 100, max: 1000, step: 10, unit: "ms" },

  { id: "input.numlock_by_default", page: "input", group: "Keyboard",
    label: "Numlock on by default", desc: "Start the session with numlock active.",
    type: "bool", hypr: "input:numlock_by_default", lua: ["input", "numlock_by_default"],
    default: true },

  { id: "input.capslock_behavior", page: "input", group: "Keyboard",
    label: "CapsLock behavior", desc: "What the CapsLock key does.",
    type: "enum", hypr: "input:kb_options", lua: ["input", "kb_options"],
    default: "compose",
    options: [
      { value: "compose", label: "Compose key (default)" },
      { value: "normal", label: "Normal CapsLock" },
      { value: "ctrl", label: "Control key" },
      { value: "escape", label: "Escape key" },
      { value: "none", label: "Disabled" }
    ] },

  { id: "input.mouse.accel_profile", page: "input", group: "Mouse",
    label: "Acceleration profile", desc: "Adaptive accelerates with speed; flat is linear.",
    type: "enum", hypr: null, lua: ["input", "mouse", "accel_profile"],
    default: "adaptive",
    options: [
      { value: "adaptive", label: "Adaptive" },
      { value: "flat",     label: "Flat" },
      { value: "",         label: "Default" }
    ] },

  { id: "input.mouse.sensitivity", page: "input", group: "Mouse",
    label: "Sensitivity", desc: "Pointer speed. 0 is unchanged.",
    type: "float", hypr: null, lua: ["input", "mouse", "sensitivity"],
    default: 0, min: -1, max: 1, step: 0.01 },

  { id: "input.mouse.natural_scroll", page: "input", group: "Mouse",
    label: "Natural scroll", desc: "Scroll content with the gesture, not against it.",
    type: "bool", hypr: null, lua: ["input", "mouse", "natural_scroll"],
    default: false },

  { id: "input.touchpad.accel_profile", page: "input", group: "Touchpad",
    label: "Acceleration profile", desc: "Adaptive accelerates with speed; flat is linear.",
    type: "enum", hypr: null, lua: ["input", "touchpad", "accel_profile"],
    default: "adaptive",
    options: [
      { value: "adaptive", label: "Adaptive" },
      { value: "flat",     label: "Flat" },
      { value: "",         label: "Default" }
    ] },

  { id: "input.touchpad.sensitivity", page: "input", group: "Touchpad",
    label: "Sensitivity", desc: "Pointer speed. 0 is unchanged.",
    type: "float", hypr: null, lua: ["input", "touchpad", "sensitivity"],
    default: 0, min: -1, max: 1, step: 0.01 },

  { id: "input.touchpad.natural_scroll", page: "input", group: "Touchpad",
    label: "Natural scroll", desc: "Reverse the touchpad scroll direction.",
    type: "bool", hypr: "input:touchpad:natural_scroll", lua: ["input", "touchpad", "natural_scroll"],
    default: false },

  { id: "input.touchpad.clickfinger_behavior", page: "input", group: "Touchpad",
    label: "Tap to right-click", desc: "Two fingers tap for a right click.",
    type: "bool", hypr: "input:touchpad:clickfinger_behavior", lua: ["input", "touchpad", "clickfinger_behavior"],
    default: true },

  { id: "input.touchpad.tap_to_click", page: "input", group: "Touchpad",
    label: "Tap to click", desc: "A single tap is a primary click.",
    type: "bool", hypr: "input:touchpad:tap-to-click", lua: ["input", "touchpad", "tap_to_click"],
    default: true },

  { id: "input.touchpad.disable_while_typing", page: "input", group: "Touchpad",
    label: "Disable while typing", desc: "Ignore the touchpad while keys are pressed.",
    type: "bool", hypr: "input:touchpad:disable_while_typing", lua: ["input", "touchpad", "disable_while_typing"],
    default: true },

  { id: "input.touchpad.scroll_factor", page: "input", group: "Touchpad",
    label: "Scroll factor", desc: "Touchpad scroll speed multiplier.",
    type: "float", hypr: "input:touchpad:scroll_factor", lua: ["input", "touchpad", "scroll_factor"],
    default: 0.4, min: 0, max: 2, step: 0.05 },

  { id: "input.trackpoint.accel_profile", page: "input", group: "Trackpoint",
    label: "Acceleration profile", desc: "Adaptive accelerates with speed; flat is linear.",
    type: "enum", hypr: null, lua: ["input", "trackpoint", "accel_profile"],
    default: "adaptive",
    options: [
      { value: "adaptive", label: "Adaptive" },
      { value: "flat",     label: "Flat" },
      { value: "",         label: "Default" }
    ] },

  { id: "input.trackpoint.sensitivity", page: "input", group: "Trackpoint",
    label: "Sensitivity", desc: "Pointer speed. 0 is unchanged.",
    type: "float", hypr: null, lua: ["input", "trackpoint", "sensitivity"],
    default: 0, min: -1, max: 1, step: 0.01 },

  { id: "input.trackpoint.natural_scroll", page: "input", group: "Trackpoint",
    label: "Natural scroll", desc: "Scroll content with the gesture, not against it.",
    type: "bool", hypr: null, lua: ["input", "trackpoint", "natural_scroll"],
    default: false },

  { id: "input.follow_mouse", page: "input", group: "Mouse",
    label: "Follow mouse", desc: "Focus follows the cursor.",
    type: "enum", hypr: "input:follow_mouse", lua: ["input", "follow_mouse"],
    default: "1",
    options: [
      { value: "0", label: "Disabled" },
      { value: "1", label: "Full" },
      { value: "2", label: "Loose" },
      { value: "3", label: "No follow" }
    ] },

  { id: "input.left_handed", page: "input", group: "Mouse",
    label: "Left handed", desc: "Swap the primary and secondary mouse buttons.",
    type: "bool", hypr: "input:left_handed", lua: ["input", "left_handed"],
    default: false },

  { id: "gesture.workspace_swipe", page: "input", group: "Gestures",
    label: "Workspace swipe", desc: "Swipe with 3 or 4 fingers to change workspaces.",
    type: "bool", hypr: null, lua: null,
    default: true },

  { id: "gesture.workspace_swipe_fingers", page: "input", group: "Gestures",
    label: "Swipe fingers", desc: "Number of fingers required for workspace swipe.",
    type: "enum", hypr: null, lua: null,
    default: "3",
    options: [
      { value: "3", label: "3 fingers" },
      { value: "4", label: "4 fingers" }
    ] },

  { id: "gesture.pinch_zoom", page: "input", group: "Gestures",
    label: "Pinch to zoom", desc: "Enable pinch gesture for cursor zoom.",
    type: "bool", hypr: null, lua: null,
    default: true },

  // ------------------------------------------------------------ environment
  { id: "env.HYPRLAND_TRACE", page: "environment", group: "Hyprland",
    label: "Hyprland trace", desc: "Enable verbose logging (\"1\").",
    type: "string", hypr: null, lua: ["env", "HYPRLAND_TRACE"],
    default: "" },

  { id: "env.HYPRLAND_NO_RT", page: "environment", group: "Hyprland",
    label: "No realtime priority", desc: "Disable realtime priority setting.",
    type: "string", hypr: null, lua: ["env", "HYPRLAND_NO_RT"],
    default: "" },

  { id: "env.HYPRLAND_NO_SD_NOTIFY", page: "environment", group: "Hyprland",
    label: "No sd notify", desc: "Disable sd_notify calls to systemd.",
    type: "string", hypr: null, lua: ["env", "HYPRLAND_NO_SD_NOTIFY"],
    default: "" },

  { id: "env.HYPRLAND_NO_SD_VARS", page: "environment", group: "Hyprland",
    label: "No sd vars", desc: "Disable management of variables in systemd/dbus.",
    type: "string", hypr: null, lua: ["env", "HYPRLAND_NO_SD_VARS"],
    default: "" },

  { id: "env.HYPRLAND_CONFIG", page: "environment", group: "Hyprland",
    label: "Hyprland config", desc: "Custom path to hyprland.lua.",
    type: "string", hypr: null, lua: ["env", "HYPRLAND_CONFIG"],
    default: "" },

  { id: "env.AQ_TRACE", page: "environment", group: "Aquamarine",
    label: "Aquamarine trace", desc: "Enable verbose logging for backend.",
    type: "string", hypr: null, lua: ["env", "AQ_TRACE"],
    default: "" },

  { id: "env.AQ_DRM_DEVICES", page: "environment", group: "Aquamarine",
    label: "AQ DRM devices", desc: "Colon-separated list of DRM device paths.",
    type: "string", hypr: null, lua: ["env", "AQ_DRM_DEVICES"],
    default: "" },

  { id: "env.AQ_FORCE_LINEAR_BLIT", page: "environment", group: "Aquamarine",
    label: "AQ force linear blit", desc: "Disable forcing linear modifiers on Multi-GPU buffers.",
    type: "string", hypr: null, lua: ["env", "AQ_FORCE_LINEAR_BLIT"],
    default: "" },

  { id: "env.AQ_MGPU_NO_EXPLICIT", page: "environment", group: "Aquamarine",
    label: "AQ MGPU no explicit", desc: "Disable explicit syncing on multi-GPU buffers.",
    type: "string", hypr: null, lua: ["env", "AQ_MGPU_NO_EXPLICIT"],
    default: "" },

  { id: "env.AQ_NO_MODIFIERS", page: "environment", group: "Aquamarine",
    label: "AQ no modifiers", desc: "Disable modifiers for DRM buffers.",
    type: "string", hypr: null, lua: ["env", "AQ_NO_MODIFIERS"],
    default: "" },

  { id: "env.AQ_NO_ATOMIC", page: "environment", group: "Aquamarine",
    label: "AQ no atomic", desc: "Force legacy DRM interface instead of atomic mode setting.",
    type: "string", hypr: null, lua: ["env", "AQ_NO_ATOMIC"],
    default: "" },

  { id: "env.GDK_BACKEND", page: "environment", group: "Toolkits",
    label: "GDK backend", desc: "Force Wayland native protocols.",
    type: "string", hypr: null, lua: ["env", "GDK_BACKEND"],
    default: "" },

  { id: "env.NIXOS_OZONE_WL", page: "environment", group: "Toolkits",
    label: "NixOS Ozone", desc: "Electron Ozone platform hint for NixOS.",
    type: "string", hypr: null, lua: ["env", "NIXOS_OZONE_WL"],
    default: "" },

  { id: "env.XDG_CURRENT_DESKTOP", page: "environment", group: "Toolkits",
    label: "XDG desktop", desc: "Desktop environment identity for portals.",
    type: "string", hypr: null, lua: ["env", "XDG_CURRENT_DESKTOP"],
    default: "" },

  { id: "env.XDG_SESSION_TYPE", page: "environment", group: "Toolkits",
    label: "XDG session type", desc: "Session type (wayland/x11).",
    type: "string", hypr: null, lua: ["env", "XDG_SESSION_TYPE"],
    default: "" },

  { id: "env.WLR_NO_HARDWARE_CURSORS", page: "environment", group: "Toolkits",
    label: "WLR no hardware cursors", desc: "Disable hardware cursors.",
    type: "string", hypr: null, lua: ["env", "WLR_NO_HARDWARE_CURSORS"],
    default: "" },

  { id: "env.WLR_RENDERER", page: "environment", group: "Toolkits",
    label: "WLR renderer", desc: "Force renderer (vulkan/opengl).",
    type: "string", hypr: null, lua: ["env", "WLR_RENDERER"],
    default: "" },

  { id: "env.WLR_DRM_NO_ATOMIC", page: "environment", group: "Toolkits",
    label: "WLR DRM no atomic", desc: "Force legacy DRM interface.",
    type: "string", hypr: null, lua: ["env", "WLR_DRM_NO_ATOMIC"],
    default: "" },

  { id: "env.NVD_BACKEND", page: "environment", group: "NVIDIA",
    label: "NVD backend", desc: "NVIDIA direct rendering backend.",
    type: "string", hypr: null, lua: ["env", "NVD_BACKEND"],
    default: "" },

  { id: "env.__GL_GSYNC_ALLOWED", page: "environment", group: "NVIDIA",
    label: "GL GSYNC allowed", desc: "Control G-Sync VRR.",
    type: "string", hypr: null, lua: ["env", "__GL_GSYNC_ALLOWED"],
    default: "" },

  { id: "env.__GL_VRR_ALLOWED", page: "environment", group: "NVIDIA",
    label: "GL VRR allowed", desc: "Control Adaptive Sync.",
    type: "string", hypr: null, lua: ["env", "__GL_VRR_ALLOWED"],
    default: "" },

  { id: "env.__EGL_VENDOR_LIBRARY_NAME", page: "environment", group: "NVIDIA",
    label: "EGL vendor library", desc: "NVIDIA EGL vendor library.",
    type: "string", hypr: null, lua: ["env", "__EGL_VENDOR_LIBRARY_NAME"],
    default: "" },

  { id: "env.__GLX_VENDOR_LIBRARY_NAME", page: "environment", group: "NVIDIA",
    label: "GLX vendor library", desc: "NVIDIA GLX vendor library.",
    type: "string", hypr: null, lua: ["env", "__GLX_VENDOR_LIBRARY_NAME"],
    default: "" },

  { id: "env.__GL_RENDERER", page: "environment", group: "NVIDIA",
    label: "GL renderer", desc: "Force NVIDIA as GL renderer.",
    type: "string", hypr: null, lua: ["env", "__GL_RENDERER"],
    default: "" },

  { id: "env.GTK_THEME", page: "environment", group: "Theming",
    label: "GTK theme", desc: "Manually set the GTK theme.",
    type: "string", hypr: null, lua: ["env", "GTK_THEME"],
    default: "" },

  { id: "env.XCURSOR_THEME", page: "environment", group: "Theming",
    label: "XCURSOR theme", desc: "Cursor theme name.",
    type: "string", hypr: null, lua: ["env", "XCURSOR_THEME"],
    default: "" },

  { id: "env.XCURSOR_SIZE", page: "environment", group: "Theming",
    label: "XCURSOR size", desc: "Cursor size.",
    type: "string", hypr: null, lua: ["env", "XCURSOR_SIZE"],
    default: "" },

  { id: "env.QT_QPA_PLATFORM", page: "environment", group: "Toolkits",
    label: "Qt platform", desc: "Qt platform plugin.",
    type: "string", hypr: null, lua: ["env", "QT_QPA_PLATFORM"],
    default: "" },

  { id: "env.CLUTTER_BACKEND", page: "environment", group: "Toolkits",
    label: "Clutter backend", desc: "Clutter backend.",
    type: "string", hypr: null, lua: ["env", "CLUTTER_BACKEND"],
    default: "" },

  { id: "env.SDL_VIDEODRIVER", page: "environment", group: "Toolkits",
    label: "SDL video driver", desc: "SDL video driver.",
    type: "string", hypr: null, lua: ["env", "SDL_VIDEODRIVER"],
    default: "" },

  { id: "env._JAVA_AWT_WM_NONREPARENTING", page: "environment", group: "Toolkits",
    label: "Java AWM", desc: "Java AWT non-reparenting.",
    type: "string", hypr: null, lua: ["env", "_JAVA_AWT_WM_NONREPARENTING"],
    default: "" },

  { id: "env.GBM_BACKEND", page: "environment", group: "Toolkits",
    label: "GBM backend", desc: "GBM backend.",
    type: "string", hypr: null, lua: ["env", "GBM_BACKEND"],
    default: "" },

  { id: "env.WLR_BACKEND", page: "environment", group: "Toolkits",
    label: "WLR backend", desc: "WLR backend.",
    type: "string", hypr: null, lua: ["env", "WLR_BACKEND"],
    default: "" },

  { id: "env.WLR_LIBINPUT_NO_DEVICES", page: "environment", group: "Toolkits",
    label: "WLR libinput", desc: "WLR libinput no devices.",
    type: "string", hypr: null, lua: ["env", "WLR_LIBINPUT_NO_DEVICES"],
    default: "" },

  { id: "env.WLR_RENDERER_ALLOW_SOFTWARE", page: "environment", group: "Toolkits",
    label: "WLR software renderer", desc: "Allow software renderer.",
    type: "string", hypr: null, lua: ["env", "WLR_RENDERER_ALLOW_SOFTWARE"],
    default: "" },

  { id: "env.WLR_DRM_DEVICES", page: "environment", group: "Toolkits",
    label: "WLR DRM devices", desc: "WLR DRM devices.",
    type: "string", hypr: null, lua: ["env", "WLR_DRM_DEVICES"],
    default: "" }
]

function pageById(id) {
  for (var i = 0; i < pages.length; i++) if (pages[i].id === id) return pages[i]
  return null
}

function settingById(id) {
  for (var i = 0; i < settings.length; i++) if (settings[i].id === id) return settings[i]
  return null
}

function settingsForPage(pageId) {
  var out = []
  for (var i = 0; i < settings.length; i++) if (settings[i].page === pageId) out.push(settings[i])
  return out
}

// Grouped rows preserve schema order and the order a group first appears.
function groupsForPage(pageId) {
  var order = []
  var map = {}
  var list = settingsForPage(pageId)
  for (var i = 0; i < list.length; i++) {
    var g = list[i].group || ""
    if (!map[g]) { map[g] = []; order.push(g) }
    map[g].push(list[i])
  }
  var out = []
  for (var j = 0; j < order.length; j++) out.push({ name: order[j], items: map[order[j]] })
  return out
}

function matchesSetting(s, query) {
  var q = String(query || "").toLowerCase()
  if (q.length === 0) return true
  return (s.label.toLowerCase().indexOf(q) !== -1)
    || (String(s.desc || "").toLowerCase().indexOf(q) !== -1)
    || (String(s.group || "").toLowerCase().indexOf(q) !== -1)
    || (s.id.toLowerCase().indexOf(q) !== -1)
}

function pageHasMatch(pageId, query) {
  var p = pageById(pageId)
  if (p && String(query || "").length > 0 && p.label.toLowerCase().indexOf(String(query).toLowerCase()) !== -1) return true
  var list = settingsForPage(pageId)
  for (var i = 0; i < list.length; i++) if (matchesSetting(list[i], query)) return true
  return false
}

function matchingSettings(query) {
  var out = []
  for (var i = 0; i < settings.length; i++) if (matchesSetting(settings[i], query)) out.push(settings[i])
  return out
}

function hyprOptions() {
  var out = []
  for (var i = 0; i < settings.length; i++) if (settings[i].hypr) out.push(settings[i].hypr)
  return out
}
