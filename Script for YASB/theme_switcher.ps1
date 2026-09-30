# theme_switcher.ps1 — Requires PowerShell 7+ (pwsh).
$StylesPath      = Join-Path $env:USERPROFILE ".config\yasb\styles.css"
$YasbColorsPath  = Join-Path $env:USERPROFILE ".config\yasb\yasb_colors.css"
$TackyConfigPath = Join-Path $env:USERPROFILE ".config\tacky-borders\config.yaml"

# Bridge file for Zen: userChrome.js reads it and applies the pref without a restart
$ZenBridgeFile   = Join-Path $env:USERPROFILE ".config\yasb\zen_bg.txt"

# State file: stores the SHA256 of yasb_colors.css to detect Windows accent changes
$AccentStateFile = Join-Path $env:USERPROFILE ".config\yasb\.accent_state"

# Automatically locate Windows Terminal's settings.json.
function Get-WtSettingsPath {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json")
        (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json")
        (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalCanary_8wekyb3d8bbwe\LocalState\settings.json")
        (Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json")
        (Join-Path $env:USERPROFILE ".config\wt\settings.json")
    )
    foreach ($p in $candidates) {
        if (Test-Path -LiteralPath $p) { return $p }
    }
    $packagesRoot = Join-Path $env:LOCALAPPDATA "Packages"
    if (Test-Path -LiteralPath $packagesRoot) {
        $pkgs = Get-ChildItem -LiteralPath $packagesRoot -Directory -Filter "Microsoft.WindowsTerminal*" -ErrorAction SilentlyContinue
        foreach ($pkg in $pkgs) {
            $candidate = Join-Path $pkg.FullName "LocalState\settings.json"
            if (Test-Path -LiteralPath $candidate) { return $candidate }
        }
    }
    return $null
}

$WtSettingsPath = Get-WtSettingsPath

$UpdateAllProfiles = $true
$ServiceComments = @("colors", "root variables")

$rawAction = if ($args.Count -ge 1) { [string]$args[0] } else { "get" }
$Action    = $rawAction -replace '^-+', ''
$ThemeName = if ($args.Count -ge 2) { [string]$args[1] } else { $null }


# ========== styles.css ==========

function Get-RootRange {
    param($Lines)
    $start = -1; $end = -1; $depth = 0
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i]
        if ($start -lt 0) {
            if ($line -match '^\s*:root\s*\{') {
                $start = $i
                $depth = ([regex]::Matches($line, '\{')).Count - ([regex]::Matches($line, '\}')).Count
                if ($depth -eq 0) { return @{ Start = $start; End = $start } }
            }
            continue
        }
        $depth += ([regex]::Matches($line, '\{')).Count - ([regex]::Matches($line, '\}')).Count
        if ($depth -le 0) { return @{ Start = $start; End = $i } }
    }
    if ($start -ge 0) { return @{ Start = $start; End = ($Lines.Count - 1) } }
    return $null
}

function Get-Themes {
    param($Lines)
    $themes = New-Object System.Collections.ArrayList
    $root = Get-RootRange -Lines $Lines
    if ($null -eq $root) { return ,$themes }

    $rootStart = [int]$root.Start
    $rootEnd   = [int]$root.End

    $currentName  = $null
    $currentStart = -1

    for ($i = $rootStart; $i -le $rootEnd; $i++) {
        $line = $Lines[$i]
        $m = [regex]::Match($line, '^\s*/\*\s*([^*]+?)\s*\*/\s*$')
        if ($m.Success -and $line -notmatch '--') {
            $name = $m.Groups[1].Value.Trim()
            if ($name -and ($ServiceComments -notcontains $name.ToLower())) {
                if ($null -ne $currentName) {
                    [void]$themes.Add(@{ Name = $currentName; Start = $currentStart; End = ($i - 1) })
                }
                $currentName  = $name
                $currentStart = $i + 1
            }
        }
    }
    if ($null -ne $currentName) {
        [void]$themes.Add(@{ Name = $currentName; Start = $currentStart; End = $rootEnd })
    }

    $final = New-Object System.Collections.ArrayList
    foreach ($t in $themes) {
        $first = [int]$t.Start
        $last  = [int]$t.End
        while ($first -le $last -and $Lines[$first] -notmatch '--') { $first++ }
        while ($last  -ge $first -and $Lines[$last]  -notmatch '--') { $last-- }
        if ($first -le $last) {
            [void]$final.Add(@{ Name = $t.Name; Start = $first; End = $last })
        }
    }
    return ,$final
}

function Test-Commented {
    param($Line)
    if ($null -eq $Line) { return $false }
    return $Line.TrimStart().StartsWith('/*')
}

function Get-ActiveTheme {
    param($Lines, $Themes)
    foreach ($t in $Themes) {
        if (-not (Test-Commented $Lines[$t.Start])) { return $t.Name }
    }
    return $null
}

function Set-ThemeState {
    param($Lines, [int]$First, [int]$Last, [bool]$Comment)
    if ($Comment) {
        if (-not (Test-Commented $Lines[$First])) {
            $indent = $Lines[$First].Length - $Lines[$First].TrimStart().Length
            $Lines[$First] = (' ' * $indent) + '/* ' + $Lines[$First].TrimStart()
            $Lines[$Last]  = $Lines[$Last].TrimEnd() + ' */'
        }
    } else {
        if (Test-Commented $Lines[$First]) {
            $Lines[$First] = $Lines[$First] -replace '^(\s*)/\*\s*', '$1'
            $Lines[$Last]  = $Lines[$Last]  -replace '\s*\*/\s*$', ''
        }
    }
}

function Set-Theme {
    param($Lines, $Themes, [string]$Target)
    foreach ($t in $Themes) {
        Set-ThemeState -Lines $Lines -First $t.Start -Last $t.End -Comment ($t.Name -ne $Target)
    }
}

function Get-BlockVars {
    param($Lines, [int]$First, [int]$Last)
    $vars = @{}
    for ($i = $First; $i -le $Last; $i++) {
        $m = [regex]::Match($Lines[$i].Trim(), '^--([\w-]+):\s*(.+?);')
        if ($m.Success) { $vars[$m.Groups[1].Value] = $m.Groups[2].Value.Trim() }
    }
    return $vars
}

# Reads yasb_colors.css in full, strips comments, and collects ALL
# `--name: value;` definitions regardless of whether they are wrapped
# in :root or not.
function Get-ImportedColors {
    if (-not (Test-Path $YasbColorsPath)) { return @{} }

    $raw = Get-Content -LiteralPath $YasbColorsPath -Raw -Encoding utf8

    # Strip block comments /* ... */ (including multiline)
    $clean = [regex]::Replace(
        $raw,
        '/\*.*?\*/',
        '',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    # Strip line comments //
    $clean = [regex]::Replace($clean, '//[^\r\n]*', '')

    $vars = @{}
    foreach ($m in [regex]::Matches($clean, '--([\w-]+)\s*:\s*([^;]+);')) {
        $name  = $m.Groups[1].Value
        $value = $m.Groups[2].Value.Trim()
        if ($name -and $value) { $vars[$name] = $value }
    }
    return $vars
}

# Expands var(--xxx) into a concrete value by looking up xxx in the theme's
# local variables and in yasb_colors.css.
# Recurses (up to 5 levels) in case a variable references another one.
function Resolve-Var {
    param($Value, $LocalVars, $ImportedVars, [int]$Depth = 0)
    if (-not $Value) { return $null }
    if ($Depth -gt 5) { return $Value }
    if (-not $Value.StartsWith('var(')) { return $Value }
    $m = [regex]::Match($Value, 'var\(--([\w-]+)\)')
    if (-not $m.Success) { return $Value }
    $varName = $m.Groups[1].Value
    $resolved = $null
    if ($LocalVars.ContainsKey($varName))        { $resolved = $LocalVars[$varName] }
    elseif ($ImportedVars.ContainsKey($varName)) { $resolved = $ImportedVars[$varName] }
    else { return $Value }
    if ($resolved -eq $Value) { return $Value }  # guard against self-reference
    return Resolve-Var -Value $resolved -LocalVars $LocalVars -ImportedVars $ImportedVars -Depth ($Depth + 1)
}

function ConvertTo-Hex {
    param($Value)
    if (-not $Value) { return $null }
    $Value = $Value.Trim()
    if ($Value.StartsWith('#')) { return $Value.ToUpper() }
    $m = [regex]::Match($Value, 'rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)')
    if ($m.Success) {
        return ('#{0:X2}{1:X2}{2:X2}' -f [int]$m.Groups[1].Value, [int]$m.Groups[2].Value, [int]$m.Groups[3].Value)
    }
    $parts = @($Value -split ',' | ForEach-Object { $_.Trim() })
    if ($parts.Count -eq 3 -and (@($parts | Where-Object { $_ -match '^\d+$' })).Count -eq 3) {
        return ('#{0:X2}{1:X2}{2:X2}' -f [int]$parts[0], [int]$parts[1], [int]$parts[2])
    }
    return $Value
}

function Test-AccentChanged {
    if (-not (Test-Path -LiteralPath $YasbColorsPath)) { return $false }
    try {
        $hash = (Get-FileHash -LiteralPath $YasbColorsPath -Algorithm SHA256).Hash
    } catch {
        return $false
    }
    $prev = if (Test-Path -LiteralPath $AccentStateFile) {
        (Get-Content -LiteralPath $AccentStateFile -Raw -ErrorAction SilentlyContinue).Trim()
    } else { "" }

    if ($hash -ne $prev) {
        $dir = Split-Path -Parent $AccentStateFile
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
        }
        Set-Content -LiteralPath $AccentStateFile -Value $hash -Encoding utf8 -NoNewline
        return $true
    }
    return $false
}


# ========== Windows Terminal ==========

function Update-TerminalScheme {
    param([string]$Target)
    if (-not $WtSettingsPath) {
        Write-Warning "[WT] settings.json not found in any of the known locations"
        return
    }
    if (-not (Test-Path -LiteralPath $WtSettingsPath)) { return }
    try {
        $json = Get-Content -LiteralPath $WtSettingsPath -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
    } catch {
        Write-Warning "[WT] JSON parse error: $_"
        return
    }
    if (-not $json.ContainsKey('profiles')) { return }
    $profiles = $json['profiles']
    if (-not $profiles.ContainsKey('defaults')) { $profiles['defaults'] = @{} }
    $profiles['defaults']['colorScheme'] = $Target

    if ($UpdateAllProfiles -and $profiles.ContainsKey('list')) {
        foreach ($prof in $profiles['list']) {
            if ($prof -is [System.Collections.IDictionary]) {
                $prof['colorScheme'] = $Target
            }
        }
    }
    $json | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $WtSettingsPath -Encoding utf8
}


# ========== Tacky Borders ==========

function Update-TackyBorders {
    param([string]$ActiveColor, [string]$InactiveColor)
    if (-not (Test-Path $TackyConfigPath)) { return }
    $lines = Get-Content -LiteralPath $TackyConfigPath -Encoding utf8
    $output = foreach ($line in $lines) {
        if ($line -match '^(\s*active_color:\s*).*$') {
            $Matches[1] + '"' + $ActiveColor + '"'
        } elseif ($line -match '^(\s*inactive_color:\s*).*$') {
            $Matches[1] + '"' + $InactiveColor + '"'
        } else {
            $line
        }
    }
    $output | Set-Content -LiteralPath $TackyConfigPath -Encoding utf8
}


# ========== Zen Browser (live via bridge file) ==========

function Update-ZenBridge {
    param([string]$BackgroundColor)
    if (-not $BackgroundColor) { return }

    $dir = Split-Path -Parent $ZenBridgeFile
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    try {
        Set-Content -LiteralPath $ZenBridgeFile -Value $BackgroundColor -Encoding utf8 -NoNewline -ErrorAction Stop
    } catch {
        Write-Warning "[Zen] Failed to write to bridge file $ZenBridgeFile : $_"
    }
}


# ========== Applying theme artifacts (Tacky + Zen) ==========

function Update-CurrentThemeArtifacts {
    param($Lines, $Themes, [string]$ThemeName)
    $targetEntry = $Themes | Where-Object { $_.Name -eq $ThemeName } | Select-Object -First 1
    if (-not $targetEntry) { return }

    $themeVars = Get-BlockVars -Lines $Lines -First $targetEntry.Start -Last $targetEntry.End
    $imported  = Get-ImportedColors

    $accentRaw     = Resolve-Var -Value $themeVars['accent']     -LocalVars $themeVars -ImportedVars $imported
    $borderRaw     = Resolve-Var -Value $themeVars['border']     -LocalVars $themeVars -ImportedVars $imported
    $backgroundRaw = Resolve-Var -Value $themeVars['background'] -LocalVars $themeVars -ImportedVars $imported

    $accentHex     = ConvertTo-Hex -Value $accentRaw
    $borderHex     = ConvertTo-Hex -Value $borderRaw
    $backgroundHex = ConvertTo-Hex -Value $backgroundRaw

    # Make sure Resolve-Var actually resolved everything
    if ($accentHex -and $borderHex -and
        -not $accentHex.StartsWith('var(') -and -not $borderHex.StartsWith('var(')) {
        Update-TackyBorders -ActiveColor $accentHex -InactiveColor $borderHex
    } else {
        Write-Warning "[Tacky] Failed to resolve colors for theme '$ThemeName' (accent=$accentRaw, border=$borderRaw)"
    }

    if ($backgroundHex -and -not $backgroundHex.StartsWith('var(')) {
        Update-ZenBridge -BackgroundColor $backgroundHex
    }
}


# ========== MAIN ==========

if ($Action -eq 'debug-wt-path') {
    if ($WtSettingsPath) { Write-Output $WtSettingsPath } else { Write-Output "NOT FOUND" }
    return
}

# Diagnostics: shows how the active theme's variables resolve
if ($Action -eq 'debug-vars') {
    $linesD  = @(Get-Content -LiteralPath $StylesPath -Encoding utf8)
    $themesD = Get-Themes -Lines $linesD
    $activeD = Get-ActiveTheme -Lines $linesD -Themes $themesD
    Write-Output "Active theme: $activeD"
    if ($activeD) {
        $entry = $themesD | Where-Object { $_.Name -eq $activeD } | Select-Object -First 1
        $localVars = Get-BlockVars -Lines $linesD -First $entry.Start -Last $entry.End
        $imported  = Get-ImportedColors
        Write-Output ""
        Write-Output "Local vars in theme:"
        foreach ($k in $localVars.Keys) { Write-Output ("  --{0} = {1}" -f $k, $localVars[$k]) }
        Write-Output ""
        Write-Output "Imported from yasb_colors.css:"
        foreach ($k in $imported.Keys) { Write-Output ("  --{0} = {1}" -f $k, $imported[$k]) }
        Write-Output ""
        Write-Output ("accent resolved = {0}" -f (Resolve-Var -Value $localVars['accent'] -LocalVars $localVars -ImportedVars $imported))
        Write-Output ("border resolved = {0}" -f (Resolve-Var -Value $localVars['border'] -LocalVars $localVars -ImportedVars $imported))
    }
    return
}

if (-not (Test-Path $StylesPath)) {
    Write-Output "styles.css not found"
    return
}

$lines  = @(Get-Content -LiteralPath $StylesPath -Encoding utf8)
$themes = Get-Themes -Lines $lines

if ($themes.Count -eq 0) {
    Write-Output "No themes found"
    return
}

$active     = Get-ActiveTheme -Lines $lines -Themes $themes
$themeNames = @($themes | ForEach-Object { $_.Name })

if ($Action -eq 'reapply-accent') {
    if ($active) { Write-Output $active } else { Write-Output "Unknown" }
    if (Test-AccentChanged) {
        Update-CurrentThemeArtifacts -Lines $lines -Themes $themes -ThemeName $active
    }
    return
}

# Usage: watch-accent [timeout_seconds]
if ($Action -eq 'watch-accent') {
    if ($active) { Write-Output $active } else { Write-Output "Unknown" }

    $timeoutSec = if ($args.Count -ge 2) { [int]$args[1] } else { 30 }
    $initialHash = if (Test-Path -LiteralPath $YasbColorsPath) {
        (Get-FileHash -LiteralPath $YasbColorsPath -Algorithm SHA256).Hash
    } else { "" }

    $deadline = (Get-Date).AddSeconds($timeoutSec)
    $changed  = $false

    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 500
        $currentHash = if (Test-Path -LiteralPath $YasbColorsPath) {
            (Get-FileHash -LiteralPath $YasbColorsPath -Algorithm SHA256).Hash
        } else { "" }
        if ($currentHash -ne $initialHash) {
            $changed = $true
            break
        }
    }

    if ($changed) {
        Start-Sleep -Milliseconds 300
        $linesNow  = @(Get-Content -LiteralPath $StylesPath -Encoding utf8)
        $themesNow = Get-Themes -Lines $linesNow
        $activeNow = Get-ActiveTheme -Lines $linesNow -Themes $themesNow
        if ($activeNow) {
            Update-CurrentThemeArtifacts -Lines $linesNow -Themes $themesNow -ThemeName $activeNow
        }
        if (Test-Path -LiteralPath $YasbColorsPath) {
            (Get-FileHash -LiteralPath $YasbColorsPath -Algorithm SHA256).Hash |
                Set-Content -LiteralPath $AccentStateFile -Encoding utf8 -NoNewline
        }
        Write-Output "Accent updated for theme: $activeNow"
    } else {
        Write-Output "Accent unchanged within $timeoutSec s"
    }
    return
}

if ($Action -eq 'get') {
    if ($active) { Write-Output $active } else { Write-Output "Unknown" }
    return
}

if ($Action -eq 'list') {
    foreach ($name in $themeNames) {
        $marker = if ($name -eq $active) { ' *' } else { '' }
        Write-Output "$name$marker"
    }
    return
}

$targetTheme = $null
if ($Action -eq 'next') {
    if ($active -and ($themeNames -contains $active)) {
        $idx = [array]::IndexOf($themeNames, $active)
        $nextIdx = ($idx + 1) % $themeNames.Count
    } else {
        $nextIdx = 0
    }
    $targetTheme = $themeNames[$nextIdx]
} elseif ($Action -eq 'set') {
    if (-not $ThemeName) {
        Write-Output "Usage: theme_switcher.ps1 set <theme name>"
        return
    }
    if ($themeNames -contains $ThemeName) {
        $targetTheme = $ThemeName
    } else {
        Write-Output "Theme '$ThemeName' not found"
        return
    }
} else {
    Write-Output "Unknown argument: $Action"
    return
}

# 1) styles.css
Set-Theme -Lines $lines -Themes $themes -Target $targetTheme
$lines | Set-Content -LiteralPath $StylesPath -Encoding utf8

# 2) Windows Terminal
Update-TerminalScheme -Target $targetTheme

# 3) Tacky Borders + Zen
Update-CurrentThemeArtifacts -Lines $lines -Themes $themes -ThemeName $targetTheme

# 4) Update state file
if (Test-Path -LiteralPath $YasbColorsPath) {
    (Get-FileHash -LiteralPath $YasbColorsPath -Algorithm SHA256).Hash |
        Set-Content -LiteralPath $AccentStateFile -Encoding utf8 -NoNewline
}

Write-Output "Theme switched to: $targetTheme"
