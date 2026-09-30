// ==UserScript==
// @onlyonce
// ==/UserScript==

(function() {
    const PREF_NAME     = "mod.sameerasw.zen_transparency_color";
    const CSS_VAR_NAME  = "--mod-sameerasw-zen_transparency_color";
    const WATCH_FILE    = "C:\\Users\\MrDLi\\.config\\yasb\\zen_bg.txt";

    let lastColor = null;

    console.log("[ZenThemeLive] Скрипт запущен. Pref:", PREF_NAME, "CSS var:", CSS_VAR_NAME);

    async function readColorFromFile() {
        try {
            const exists = await IOUtils.exists(WATCH_FILE);
            if (!exists) return null;
            const data = await IOUtils.readUTF8(WATCH_FILE);
            return data.trim();
        } catch (e) {
            console.error("[ZenThemeLive] Ошибка чтения файла:", e);
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
                console.error("[ZenThemeLive] Ошибка установки CSS var в окне:", e);
            }
        }
        return count;
    }

    async function applyColor() {
        const color = await readColorFromFile();
        if (!color) return;
        if (color === lastColor) return;

        try {
            // 1. Обновляем pref — чтобы значение сохранилось в prefs.js
            //    и переживало перезапуск браузера.
            Services.prefs.setStringPref(PREF_NAME, color);
            Services.prefs.savePrefFile(null);

            // 2. Обновляем CSS-переменную во всех открытых окнах.
            //    Это и даёт визуальное изменение «на лету».
            const n = applyCssVarToAllWindows(color);

            lastColor = color;
            console.log(`[ZenThemeLive] Цвет применён: ${color} (окон: ${n})`);
        } catch (e) {
            console.error("[ZenThemeLive] Ошибка применения:", e);
        }
    }

    // Применяем сразу при запуске (на случай, если pref уже сохранён,
    // но Zen не успел его показать)
    applyColor();

    // И далее — раз в секунду
    setInterval(applyColor, 1000);

    // Небольшой хак: иногда после запуска Zen перезаписывает переменную
    // при инициализации окна. Через 3 секунды принудительно повторяем.
    setTimeout(() => { lastColor = null; applyColor(); }, 3000);
})();