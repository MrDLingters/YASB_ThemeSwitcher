# YASB theme switcher
Script for switching color schemes in YASB.
#### Preview
<img width="3839" height="2159" alt="image" src="https://github.com/user-attachments/assets/b5f90b6c-2360-496c-a2dc-4e565b8856d2" />

#### [Video demo](https://youtu.be/wms1QVfcSVg?si=LlvgEPMnv-NXYrrf)

#### Supported YASB themes:
- [Akira](https://github.com/MrDLingters/Akira_YASB/tree/main)     - i3WM inspired minimalistic bar with several color schemes available in one CSS.
- [Shibumi](https://github.com/MrDLingters/Shibumi_YASB/tree/main) - Hyprland inspired minimalistic bar with several color schemes available in one CSS.
- [Okinami](https://github.com/MrDLingters/Okinami_YASB)           - Minimalistic bar with waves design and several color schemes available in one CSS.

#### Supported integrations:
- Windows Terminal - color schemes
- Tacky borders - active and inactive colors
- Zen Browser - background color for Zen Transparent mod

### Installation

#### 1. Theme switcher for YASB
If you want to switch themes only for YASB:
1. Download Theme switcher version of supported YASB theme and put files in C:\Users\USERNAME\.config\yasb
<img width="944" height="438" alt="image" src="https://github.com/user-attachments/assets/d3eddb49-0875-482b-bd89-d217e6a0e61a" />

2. Download [script for YASB](https://github.com/MrDLingters/YASB_ThemeSwitcher/tree/main/Script%20for%20YASB) and put it in the same folder with YASB config: C:\Users\USERNAME\.config\yasb
3. Reload YASB

#### 2. Tacky borders
1. Set your `"active_color` and `inactive_color` in C:\Users\USERNAME\.config\tacky-borders\config.yaml to HEX values: 
<img width="440" height="100" alt="image" src="https://github.com/user-attachments/assets/78e4fd91-2eb4-4d6e-b966-6dc46c2a6537" />

2. After changing theme in YASB script will change your border's colors.

#### 3. Windows Terminal
1. Add [color schemes](https://github.com/MrDLingters/YASB_ThemeSwitcher/tree/main/Terminal%20color%20schemes) from this repo to your "settings.json" in `"schemes"` section. It can be open from Terminal settings:
<img width="986" height="749" alt="image" src="https://github.com/user-attachments/assets/71217307-1ec6-4266-a265-17b0120b89a9" />

2. After changing theme in YASB script will change your terminal's color scheme.

#### 4. Zen Browser
1. Install and setup Zen transparent mod/ I have a [guide](https://youtu.be/38YHr2Xrk4k?si=kdv5NwFT5uhAKW5G) for it.
2. Download and install [fx-autoconfig](https://github.com/MrOtherGuy/fx-autoconfig).
3. Enable the required preference in `about:config`: `toolkit.legacyUserProfileCustomizations.stylesheets`, `userChromeJS.enabled` and `devtools.chrome.enabled`.
4. Copy [script for Zen](https://github.com/MrDLingters/YASB_ThemeSwitcher/tree/main/Script%20for%20Zen%20browser) to your C:\Users\<YourUser>\AppData\Roaming\zen\Profiles\<profile>\chrome\JS\
5. Clear Zen's startup cache. Go to `about:support` and click "Clear Startup Cache".
6. After changing theme in YASB script will change Zen browser background color.


### Adding themes
#### 1. Open C:\Users\USERNAME\.config\yasb\styles.css and add your color scheme to "colors" section following for template:
```
    /* Catppuccin Latte */
    /* --background: #eff1f5; - main background
    --background2: #ccd0da; - secondary background 
    --accent: #7c7f93; - accent color
    --text: #4c4f69; - main text color
    --accentText: #eff1f5; - text on colored objects
    --hover: #bcc0cc; - hover color
    --mutedBG: #e6e9ef; - muted background
    --border: #ccd0da; - border color
    --redFlash: #d20f39; - color for "close" button in taskbar, flashing apps and secondary hover for activated buttons
    --subtext: #6c6f85; */ - muted text
```
Name of a color scheme always should stay commented. Make sure, you have only one uncommented color scheme.

#### 2. Open C:\Users\USERNAME\.config\yasb\config.yaml and add your theme for "Home" widget to "menu_list" section following for template:
```
- title: "🎨 THEME_NAME"
        command: "cmd.exe"
        args: ["/c", "pwsh", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "%USERPROFILE%/.config/yasb/theme_switcher.ps1", "set", "THEME_NAME"]
```
#### 3. If you have color scheme for terminal with your theme, add it to your settings.json in `"schemes"` section and set same name as for YASB in styles.css.
