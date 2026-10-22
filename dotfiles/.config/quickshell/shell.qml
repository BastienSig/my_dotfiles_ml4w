//@ pragma UseQApplication

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "WelcomeApp"
import "PowerApp"
import "SidebarApp"
import "CalendarApp"
import "WallpaperApp"
import "StatusbarApp"
import "CustomTheme"

ShellRoot {
    id: shellRoot
    // Test IPC tools: qs ipc show

    IpcHandler {
        target: "theme-manager"
        function reload(): void {
            Theme.reloadTheme()
        }
    }

    WelcomeWindow {}
    PowerWindow {}
    SidebarWindow {}
    CalendarWindow {}
    WallpaperWindow {}

    // One statusbar per screen. Instances are created/destroyed automatically
    // when monitors are plugged in or removed.
    Variants {
        id: statusbars
        model: Quickshell.screens
        StatusbarWindow {
            required property var modelData
            screen: modelData
        }
    }

    // The bar on the currently focused monitor (falls back to the first one).
    function focusedBar() {
        const bars = statusbars.instances
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        for (let i = 0; i < bars.length; i++)
            if (bars[i].screen && bars[i].screen.name === name)
                return bars[i]
        return bars.length > 0 ? bars[0] : null
    }

    function eachBar(fn) {
        const bars = statusbars.instances
        for (let i = 0; i < bars.length; i++)
            fn(bars[i])
    }

    // Persist a bar flag once (through the first bar) and apply the written
    // text to every bar so all screens stay in sync.
    function setBarFlag(key, on) {
        const bars = statusbars.instances
        if (bars.length === 0)
            return
        const text = bars[0].persistBarFlag(key, on)
        eachBar(b => b.applySettings(text))
    }

    // Single IPC entry point for all statusbars (a handler per bar would
    // register the same target several times).
    IpcHandler {
        target: "statusbar"
        function toggle(): void {
            const b = shellRoot.focusedBar()
            if (b) shellRoot.setBarFlag("enabled", !b.settings.bar.enabled)
        }
        // Named enable/disable rather than show/hide: "show" is a reserved
        // subcommand of "qs ipc" and would never reach the function.
        function enable(): void { shellRoot.setBarFlag("enabled", true) }
        function disable(): void { shellRoot.setBarFlag("enabled", false) }
        function alwaysExpand(): void { shellRoot.setBarFlag("alwaysExpanded", true) }
        function autoCollapse(): void { shellRoot.setBarFlag("alwaysExpanded", false) }
        function refresh(): void { shellRoot.eachBar(b => b.reloadSettings()) }
        function reload(): void { shellRoot.eachBar(b => b.reloadSettings()) }
        // SUPER + SPACE: only the bar on the focused monitor grabs the keyboard.
        function focus(): void {
            const b = shellRoot.focusedBar()
            if (b) b.focusBar()
        }
        function expand(): void {
            const b = shellRoot.focusedBar()
            if (b) b.barExpanded = !b.barExpanded
        }
        function collapse(): void { shellRoot.eachBar(b => b.barExpanded = false) }
    }

    IpcHandler {
        target: "updates"
        function reset(): void { shellRoot.eachBar(b => b.forEachModule(m => { if (m.count !== undefined && typeof m.refresh === "function") m.count = 0 })) }
        function refresh(): void { shellRoot.eachBar(b => b.forEachModule(m => { if (m.count !== undefined && typeof m.refresh === "function") m.refresh() })) }
    }
}
