// ==UserScript==
// @onlyonce
// ==/UserScript==

(function() {
    const PREF_NAME     = "mod.sameerasw.zen_transparency_color";
    const CSS_VAR_NAME  = "--mod-sameerasw-zen_transparency_color";

    // Собираем путь к файлу-мосту из домашней директории пользователя.
    // Это избавляет от хардкода конкретного имени профиля.
    const HOME_DIR = Services.dirsvc.get("Home", Ci.nsIFile).path;
    const WATCH_FILE = PathUtils.join(HOME_DIR, ".config", "yasb", "zen_bg.txt");

    let lastColor = null;

    console.log("[ZenThemeLive] Script started. Watching:", WATCH_FILE);

    async function readColorFromFile() {
        try {
            const exists = await IOUtils.exists(WATCH_FILE);
            if (!exists) return null;
            const data = await IOUtils.readUTF8(WATCH_FILE);
            return data.trim();
        } catch (e) {
            console.error("[ZenThemeLive] File read error:", e);
            return null;
        }
    }

    function applyCssVarToAllWindows(color) {
        let count = 0;
        for (const win of Services.wm.getEnumerator("navigator:browser")) {
            try {
                if (win && win.document && win.document.documentElement) {
                    win.document.documentElement.style.setProperty(CSS_VAR_NAME, color);
                    count++;
                }
            } catch (e) {
                console.error("[ZenThemeLive] Failed to set CSS var:", e);
            }
        }
        return count;
    }

    async function applyColor() {
        const color = await readColorFromFile();
        if (!color) return;
        if (color === lastColor) return;

        try {
            Services.prefs.setStringPref(PREF_NAME, color);
            Services.prefs.savePrefFile(null);

            const n = applyCssVarToAllWindows(color);

            lastColor = color;
            console.log(`[ZenThemeLive] Color applied: ${color} (windows: ${n})`);
        } catch (e) {
            console.error("[ZenThemeLive] Apply error:", e);
        }
    }

    applyColor();
    setInterval(applyColor, 1000);

    // Повторное применение после инициализации окна Zen
    setTimeout(() => { lastColor = null; applyColor(); }, 3000);
})();
