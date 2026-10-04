pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

Item {
    id: root

    property var shell: null
    property var manifest: null
    property bool opened: false

    // Paths are passed to `find` as argv, so they must be real absolute
    // paths -- a literal "$HOME" would reach find unexpanded. root.home is
    // Quickshell.env("HOME"); write plain absolute paths below.
    readonly property string home: Quickshell.env("HOME") || ""

    // The original flat folder. Always the first category, labelled
    // "Unsorted".
    property string defaultDir: root.home + "/Pictures/Wallpapers"
    // Root of the sorted tree. Every immediate subfolder of it becomes its
    // own category, so adding a folder under here is all it takes to add a
    // new tab -- no plugin edits. Images sitting directly in this root are
    // offered as a "Sorted" category of their own.
    property string sortedDir: root.home + "/Pictures/Wallpapers-sorted"

    // Where thumbnails.sh mirrors previews of the above. The layout is the
    // source tree with the leading slash dropped, which lets thumbPath()
    // below answer for any wallpaper with one string concatenation -- there
    // is no index to keep in sync and nothing to invalidate by hand.
    readonly property string cacheHome:
        Quickshell.env("XDG_CACHE_HOME") || (root.home + "/.cache")
    readonly property string thumbRoot:
        root.cacheHome + "/wallpicker-grid/thumbs"

    // Reflects the current category only. True means every wallpaper in it has
    // a cached preview, so the grid never decodes a full-size file. Set by
    // parseListing() below, which asks the same `find` that already walks the
    // category whether each thumbnail exists -- no extra process per category.
    property bool anyThumbs: true
    // True while thumbnails.sh is running for this category.
    property bool thumbsBuilding: false

    // Set recursive to true to also pick up images in subfolders.
    property bool recursive: false

    property int columns: 5
    property int gridSpacing: 14
    property int hoveredIndex: -1
    property bool loading: false
    property string statusText: ""

    property int currentCategory: 0
    // Bumped on every listing request so a slow `find` that finishes after
    // the user already moved on can't stomp the current category's grid.
    property int requestId: 0
    // path -> string[] of files. Only ever read/written from JS, never bound.
    property var cache: ({})

    readonly property var currentEntry: categoryModel.count > 0
        && currentCategory >= 0 && currentCategory < categoryModel.count
        ? categoryModel.get(currentCategory) : null

    readonly property color bg: "#0a0a0a"
    readonly property color fg: "#efe6d2"
    readonly property color muted: "#8c8274"
    readonly property color subtle: "#5c564c"
    readonly property color accent: "#efe6d2"
    readonly property color chipBg: "#141410"
    readonly property color chipBorder: "#23231c"

    // Pixels per logical pixel for the grid's decode sizing. panel.screen is
    // null until the layer surface exists, and 1 is the safe default there.
    readonly property real devicePixelRatio:
        panel.screen ? panel.screen.devicePixelRatio : 1

    ListModel { id: categoryModel }
    ListModel { id: imageModel }

    function extensionFilter() {
        // find -iname is case-insensitive per pattern, so list each once.
        var exts = ["png", "jpg", "jpeg", "webp", "bmp", "gif", "tiff"]
        var parts = []
        for (var i = 0; i < exts.length; i++)
            parts.push("-iname '*." + exts[i] + "'")
        return parts.join(" -o ")
    }

    function baseName(path) {
        var parts = String(path).split("/")
        return parts[parts.length - 1]
    }

    // Mirrors what thumbnails.sh writes: the source path without its leading
    // slash, under the cache root, with .jpg appended.
    //   ~/Pictures/Wallpapers-sorted/anime/foo.jpg
    //   ~/.cache/wallpicker-grid/thumbs/home/.../Wallpapers-sorted/anime/foo.jpg.jpg
    function thumbPath(path) {
        return root.thumbRoot + "/" + String(path).substring(1) + ".jpg"
    }

    // Absolute path of the bundled generator. Qt.resolvedUrl() finds it next to
    // this QML file, and fromFileUrl() undoes Util.fileUrl()'s encoding.
    readonly property string thumbScriptPath: fromFileUrl(Qt.resolvedUrl("thumbnails.sh"))

    // Longest-edge size to generate. Sized off the real cell width rather than
    // hardcoded, so a wider monitor or a HiDPI scale gets previews that still
    // cover the pixels they are drawn into -- generating 4K previews for a
    // 370 px cell would cost disk and decode time for nothing. The 1.25 is
    // margin over the exact cell width for rounding; the existing cache stays
    // valid because it is only ever compared against missing previews.
    readonly property int thumbSize: Math.max(320, Math.min(1280,
        Math.ceil((panel.width > 0 ? panel.width / root.columns : 384)
            * root.devicePixelRatio * 1.25)))

    // Inverse of Util.fileUrl, which percent-encodes each path segment.
    function fromFileUrl(url) {
        return String(url).replace(/^file:\/\//, "").split("/").map(decodeURIComponent).join("/")
    }

    function titleCase(name) {
        return String(name)
            .replace(/[-_]+/g, " ")
            .replace(/\b\w/g, function (c) { return c.toUpperCase() })
    }

    // Builds the category list. The script receives both roots as positional
    // parameters ($1 / $2) instead of being interpolated into the source, so
    // a path with spaces or quotes in it can't break the command.
    function discover() {
        var filter = extensionFilter()
        var script = [
            "emit() { printf '%s\\t%s\\n' \"$1\" \"$2\"; }",
            "has() { [ -d \"$1\" ] || return 1; find \"$1\" -maxdepth 1 -type f \\( " + filter + " \\) 2>/dev/null | grep -q .; }",
            "if has \"$1\"; then emit 'Unsorted' \"$1\"; fi",
            "if [ -d \"$2\" ]; then",
            "  if has \"$2\"; then emit 'Sorted' \"$2\"; fi",
            "  find \"$2\" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | while IFS= read -r d; do",
            "    emit \"$(basename \"$d\")\" \"$d\"",
            "  done",
            "fi"
        ].join("\n")
        categoryProc.command = ["bash", "-c", script, "bash", root.defaultDir, root.sortedDir]
        categoryProc.running = false
        categoryProc.running = true
    }

    function fill(entries) {
        // Plain append loop: ListModel.beginReset()/endReset() are C++-only
        // and throw TypeError when called from QML.
        for (var i = 0; i < entries.length; i++)
            imageModel.append(entries[i])
    }

    // Turns one listing into model entries, remembering which wallpapers
    // already have a preview. `find` does the existence test as it goes, so
    // this costs one `test` per image inside a process that was already
    // running -- and it means a missing preview is known up front instead of
    // being discovered by an Image that failed.
    //
    // Output format is "1<TAB>path" / "0<TAB>path", path last and taken as
    // everything after the first tab, so a filename containing a tab or a
    // newline still round-trips.
    function parseListing(text) {
        var entries = []
        var cachedCount = 0
        var rows = text.split("\n")
        for (var i = 0; i < rows.length; i++) {
            var row = rows[i]
            if (row.length === 0) continue
            var tab = row.indexOf("\t")
            if (tab < 0) continue
            var has = row.slice(0, tab) === "1"
            var path = row.slice(tab + 1)
            if (path.length === 0) continue
            if (has) cachedCount++
            entries.push({
                path: path,
                thumb: has ? root.thumbPath(path) : ""
            })
        }
        return { entries: entries, cached: cachedCount }
    }

    // The listing script, shared by the initial load and by the refresh after
    // thumbnails finish generating. Emits the preview flag before each path.
    function listCommand(dir) {
        // Joined into one string: `bash -c` takes the script as a single
        // argument, so an array of lines would run the first line and pass the
        // rest as positional parameters.
        var script = [
            "thumb=\"" + root.thumbRoot + "\"",
            "while IFS= read -r f; do",
            "  t=\"$thumb$f.jpg\"",
            "  if [ -s \"$t\" ]; then printf '1\\t%s\\n' \"$f\";",
            "  else printf '0\\t%s\\n' \"$f\"; fi",
            "done < <(find \"$1\" -maxdepth " + (root.recursive ? "99" : "1") +
            " -type f \\( " + extensionFilter() + " \\) 2>/dev/null | sort)"
        ].join("\n")
        return ["bash", "-c", script, "bash", dir]
    }

    function selectCategory(index, scrollIntoView) {
        if (index < 0 || index >= categoryModel.count) return
        root.currentCategory = index
        root.hoveredIndex = -1
        root.statusText = ""
        root.loading = true
        imageModel.clear()
        if (scrollIntoView !== false)
            centerChip(index)
        grid.positionViewAtBeginning()

        var entry = categoryModel.get(index)
        var cached = root.cache[entry.path]
        if (cached) {
            root.loading = false
            root.anyThumbs = cached.cached > 0
            root.fill(cached.entries)
            if (cached.entries.length === 0)
                root.statusText = "No images found in " + entry.path
            root.maybeBuildThumbs()
            return
        }

        root.requestId++
        listProc.token = root.requestId
        listProc.refresh = false
        listProc.category = entry.path
        listProc.command = root.listCommand(entry.path)
        listProc.running = false
        listProc.running = true
    }

    // Generates previews for the current category when it has none. The bundled
    // script is incremental, so this tops the cache up and does nothing for
    // wallpapers that already have one -- it is safe to reach a category
    // repeatedly. Bounded to one category at a time so a 1300-image folder
    // can't spend all 12 cores while the overlay is open.
    function maybeBuildThumbs() {
        if (root.thumbsBuilding || root.anyThumbs) return
        if (imageModel.count === 0) return
        var entry = categoryModel.get(root.currentCategory)
        if (!entry) return

        root.thumbsBuilding = true
        thumbBuildProc.category = entry.path
        root.statusText = "Building previews for " + entry.label
            + "… this is cached, later visits are instant."
        thumbBuildProc.command = ["bash", root.thumbScriptPath,
            "--size", String(root.thumbSize), entry.path]
        // Deliberately not stopped-and-restarted. Setting `running = false`
        // first would emit Process.exited for the stop, which onThumbsBuilt
        // would treat as the build finishing and clear thumbsBuilding while
        // the new run was still going. The guard above already guarantees
        // nothing else is running.
        if (!thumbBuildProc.running)
            thumbBuildProc.running = true
    }

    // One build at a time, keyed on the category it was started for. If the
    // user switched categories while it ran, the finished build is left to do
    // its job for the cache and thumbsBuilding simply clears -- the category
    // now on screen picks up its own build on the next switch, rather than two
    // generators competing for the same cores.
    function onThumbsBuilt() {
        if (!root.thumbsBuilding) return
        var entry = root.currentEntry
        if (entry && thumbBuildProc.category === entry.path) {
            root.refreshCurrent()
        } else {
            root.thumbsBuilding = false
        }
    }

    // Re-lists the current category without touching the in-memory image list
    // order, so freshly written previews replace the full-size fallbacks
    // in place instead of the grid emptying and refilling.
    function refreshCurrent() {
        root.thumbsBuilding = false
        if (imageModel.count === 0) return
        root.requestId++
        listProc.token = root.requestId
        listProc.refresh = true
        listProc.category = categoryModel.get(root.currentCategory).path
        listProc.command = root.listCommand(listProc.category)
        listProc.running = false
        listProc.running = true
    }

    // Fills in the thumb role for the wallpapers that were showing a full-size
    // file. The listing is sorted identically to the one the model was built
    // from, so indices line up; the path check keeps a surprise reordering
    // from pointing a cell at the wrong preview.
    function applyThumbs(entries) {
        var patched = 0
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i]
            if (entry.thumb === "") continue
            var existing = imageModel.get(i)
            if (!existing || existing.path !== entry.path) continue
            if (existing.thumb !== "") continue
            imageModel.setProperty(i, "thumb", entry.thumb)
            patched++
        }
        return patched
    }

    function stepCategory(delta) {
        if (categoryModel.count === 0) return
        selectCategory((root.currentCategory + delta + categoryModel.count) % categoryModel.count)
    }

    function centerChip(index) {
        var chip = chipRow.children[index]
        if (!chip) return
        chipStrip.contentX = Math.max(0,
            Math.min(chipStrip.contentWidth - chipStrip.width,
                chip.x + chip.width / 2 - chipStrip.width / 2))
    }

    function setWallpaper(path) {
        root.statusText = "Applying " + baseName(path) + "…"
        // Omarchy's own CLI is what actually owns the background symlink +
        // swaybg reload. Shelling that out ourselves (as the first version
        // of this plugin did) fought the CLI over that state and silently
        // no-opped on current Omarchy releases. Let the CLI do it.
        Util.execDetached("omarchy theme bg set " + Util.shellQuote(path))
        applyCloseTimer.restart()
    }

    Timer {
        id: applyCloseTimer
        interval: 240
        repeat: false
        onTriggered: root.dismiss()
    }

    Process {
        id: categoryProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                categoryModel.clear()
                var rows = text.split("\n")
                for (var i = 0; i < rows.length; i++) {
                    if (rows[i].length === 0) continue
                    var parts = rows[i].split("\t")
                    if (parts.length < 2) continue
                    categoryModel.append({ label: parts[0], path: parts[1] })
                }
                if (categoryModel.count === 0)
                    root.statusText = "No wallpaper folders found in "
                        + root.defaultDir + " or " + root.sortedDir
                selectCategory(Math.min(root.currentCategory,
                    Math.max(0, categoryModel.count - 1)))
            }
        }
    }

    Process {
        id: listProc
        property int token: 0
        property string category: ""
        // Set for the re-list that follows thumbnail generation, so the result
        // patches the existing grid instead of appending to it.
        property bool refresh: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if (listProc.token !== root.requestId)
                    return // a newer category was requested; its result wins
                var parsed = root.parseListing(text)
                root.cache[listProc.category] = parsed

                if (listProc.refresh) {
                    // Patch only the thumb role. Clearing and refilling would
                    // blank the grid and re-request every image, which is
                    // exactly the work the previews just made cheap.
                    var patched = root.applyThumbs(parsed.entries)
                    root.anyThumbs = parsed.cached > 0
                    root.thumbsBuilding = false
                    root.statusText = patched > 0
                        ? "Cached " + patched + " previews in "
                            + baseName(listProc.category)
                        : ""
                    return
                }

                // Clear the spinner before filling, so a throw inside fill()
                // can't strand the header on "loading…".
                root.loading = false
                root.fill(parsed.entries)
                root.anyThumbs = parsed.cached > 0
                if (parsed.entries.length === 0)
                    root.statusText = "No images found in " + listProc.category
                root.maybeBuildThumbs()
            }
        }
    }

    Process {
        id: thumbBuildProc
        // The bundled generator, run on one category directory. Its output is
        // irrelevant -- the re-listing that follows is the source of truth.
        // Both exit paths call the same handler: waitForEnd covers a normal
        // run, onExited covers a failure to start, and onThumbsBuilt() is
        // idempotent so seeing both is fine.
        property string category: ""
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.onThumbsBuilt()
        }
        onExited: root.onThumbsBuilt()
    }

    function open(payloadJson) {
        root.opened = true
        root.statusText = ""
        if (categoryModel.count === 0)
            root.discover()
        else
            root.selectCategory(root.currentCategory)
        Qt.callLater(function () { keyCatcher.forceActiveFocus() })
    }

    function close() { root.opened = false }

    function dismiss() {
        root.opened = false
        if (root.shell && typeof root.shell.hide === "function")
            root.shell.hide((root.manifest && root.manifest.id) || "wallpicker.grid")
    }

    function toggle() {
        if (root.opened) root.dismiss()
        else root.open("{}")
    }

    IpcHandler {
        target: "wallpicker"
        function toggle(): void { root.toggle() }
        function open(): void { root.open("{}") }
        function close(): void { root.dismiss() }
        function status(): string { return root.opened ? "open" : "closed" }
        function next(): void { root.stepCategory(1) }
        function prev(): void { root.stepCategory(-1) }
        function category(): string {
            return root.currentEntry ? root.currentEntry.label : ""
        }
        function categorySet(name: string): void {
            for (var i = 0; i < categoryModel.count; i++) {
                if (categoryModel.get(i).label.toLowerCase() === String(name).toLowerCase()) {
                    root.selectCategory(i)
                    return
                }
            }
        }
    }

    PanelWindow {
        id: panel
        visible: root.opened
        anchors { top: true; bottom: true; left: true; right: true }
        color: "#0a0a0a"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "wallpicker-grid"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Item {
            id: keyCatcher
            anchors.fill: parent
            focus: true
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_Escape) {
                    root.dismiss()
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Left
                    || (event.key === Qt.Key_H && !(event.modifiers & Qt.ControlModifier))) {
                    root.stepCategory(-1)
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Right
                    || (event.key === Qt.Key_L && !(event.modifiers & Qt.ControlModifier))) {
                    root.stepCategory(1)
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Tab) {
                    root.stepCategory(event.modifiers & Qt.ShiftModifier ? -1 : 1)
                    event.accepted = true
                    return
                }
                if (event.text.length === 1 && event.text >= "1" && event.text <= "9") {
                    root.selectCategory(parseInt(event.text, 10) - 1)
                    event.accepted = true
                }
            }

            Rectangle {
                anchors.fill: parent
                color: root.bg
            }

            Column {
                id: header
                width: parent.width
                topPadding: 22
                leftPadding: 28
                rightPadding: 28
                spacing: 8

                Item {
                    width: parent.width - 56
                    height: 28

                    Text {
                        text: "WALLPAPERS"
                        color: root.muted
                        font.pixelSize: 11
                        font.letterSpacing: 3
                        font.weight: Font.Medium
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: root.loading ? "loading…"
                            : (root.currentEntry
                                ? root.currentEntry.label + " · " + imageModel.count + " images"
                                : "no categories")
                        color: root.subtle
                        font.pixelSize: 11
                        font.letterSpacing: 1
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Category strip. A plain Row inside a Flickable so any
                // number of categories fits, however narrow the screen is.
                Flickable {
                    id: chipStrip
                    width: parent.width - 56
                    height: 32
                    contentWidth: chipRow.width
                    contentHeight: height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.HorizontalFlick

                    Row {
                        id: chipRow
                        height: parent.height
                        spacing: 6

                        Repeater {
                            model: categoryModel

                            delegate: Rectangle {
                                id: chip
                                required property int index
                                required property string label

                                readonly property bool active: root.currentCategory === chip.index

                                width: chipText.implicitWidth + 26
                                height: 30
                                radius: 8
                                color: chip.active ? Qt.alpha(root.accent, 0.16) : root.chipBg
                                border.width: 1
                                border.color: chip.active ? root.accent : root.chipBorder

                                Text {
                                    id: chipText
                                    anchors.centerIn: parent
                                    text: (chip.index < 9 ? (chip.index + 1) + "  " : "") + chip.label
                                    color: chip.active ? root.fg : root.muted
                                    font.pixelSize: 12
                                    font.weight: chip.active ? Font.Medium : Font.Normal
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectCategory(chip.index)
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: root.statusText.length > 0
                    text: root.statusText
                    color: root.muted
                    font.pixelSize: 12
                }

                // Only when this category really has no previews, so the
                // fallback path never silently reintroduces the old cost.
                // Only when this category has no previews cached at all, so the fallback
                // never silently reintroduces the old cost -- and a partly
                // built cache, which is normal while thumbnails.sh runs,
                // doesn't nag.
                Text {
                    visible: !root.anyThumbs && imageModel.count > 0
                        && !root.thumbsBuilding
                    text: "No cached previews — showing full-size files."
                    color: root.muted
                    font.pixelSize: 12
                    elide: Text.ElideMiddle
                    width: parent.width
                }
            }

            GridView {
                id: grid
                anchors.top: header.bottom
                anchors.bottom: footer.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 28
                anchors.topMargin: 8
                // GridView fits N columns by floor(width / cellWidth), so
                // cellWidth must be <= width/columns or it silently rounds
                // down to one fewer column. Math.floor guards the edge case
                // where floating-point rounding makes it land a hair over.
                cellWidth: Math.floor(width / root.columns)
                cellHeight: Math.floor((cellWidth - root.gridSpacing) * 9 / 16) + root.gridSpacing
                model: imageModel
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                // Recycles delegates as they scroll out. Without this a
                // 1300-image category tears down and rebuilds an entire
                // Image per cell while scrolling, which is where the old
                // picker spent most of its time.
                reuseItems: true

                delegate: Item {
                    id: cell
                    required property string path
                    required property string thumb
                    required property int index
                    width: grid.cellWidth - root.gridSpacing
                    height: grid.cellHeight - root.gridSpacing

                    // Set when a preview that the listing said exists turns out to be
                    // unreadable, so a half-written or corrupt cache entry
                    // falls back to the original too. A plain local property:
                    // reuseItems re-injects the roles above for every recycled
                    // delegate, and this one has to reset with the delegate
                    // rather than leak into the next wallpaper shown.
                    property bool thumbBroken: false

                    // Empty thumb means the listing already found no preview
                    // for this wallpaper, so the original is the intended
                    // source rather than a fallback.
                    readonly property string previewPath:
                        (!cell.thumb || cell.thumbBroken) ? cell.path : cell.thumb

                    Rectangle {
                        anchors.fill: parent
                        radius: root.hoveredIndex === cell.index ? 0 : 10
                        color: "#141410"
                        border.width: root.hoveredIndex === cell.index ? 2 : 0
                        border.color: root.accent
                        clip: true

                        Image {
                            id: thumb
                            anchors.fill: parent
                            anchors.margins: root.hoveredIndex === cell.index ? 2 : 0
                            // Util.fileUrl percent-encodes each segment, so
                            // paths with spaces survive. cell.previewPath is a
                            // cached preview when one exists and the original
                            // otherwise.
                            source: Util.fileUrl(cell.previewPath)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                            // Decode at the size actually drawn. This is the
                            // safety net for the fallback path: one wallpaper
                            // in this collection is 7475x4319, which is ~120 MB
                            // as RGBA per cell if decoded at native size. Same
                            // trick omarchy-background uses for wallpapers.
                            sourceSize.width: Math.ceil(width * root.devicePixelRatio)
                            sourceSize.height: Math.ceil(height * root.devicePixelRatio)

                            onStatusChanged: {
                                // A preview the listing vouched for didn't
                                // load: retry with the original once. The
                                // thumbBroken guard means a genuinely broken
                                // original settles on the error tile instead of
                                // flip-flopping between the two sources.
                                if (status === Image.Error
                                        && !cell.thumbBroken && cell.thumb !== "")
                                    cell.thumbBroken = true
                            }

                            Rectangle {
                                visible: thumb.status !== Image.Ready
                                anchors.fill: parent
                                color: "#1b1b16"

                                Text {
                                    anchors.centerIn: parent
                                    text: thumb.status === Image.Error ? "✕" : "…"
                                    color: root.subtle
                                    font.pixelSize: 20
                                }
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 26
                            visible: root.hoveredIndex === cell.index
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#00000000" }
                                GradientStop { position: 1.0; color: "#c0000000" }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 6
                                elide: Text.ElideMiddle
                                text: root.baseName(cell.path)
                                color: root.fg
                                font.pixelSize: 11
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.hoveredIndex = cell.index
                        onExited: if (root.hoveredIndex === cell.index) root.hoveredIndex = -1
                        onClicked: root.setWallpaper(cell.path)
                    }
                }
            }

            Item {
                id: footer
                width: parent.width
                height: 44
                anchors.bottom: parent.bottom

                Text {
                    anchors.centerIn: parent
                    text: "Click a wallpaper to apply it · ← → switch category · 1-9 jump · Esc to close"
                    color: root.subtle
                    font.pixelSize: 12
                }
            }
        }
    }
}