@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "HUNIT_LAUNCHER=%~f0"
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -Command "$ErrorActionPreference = 'Stop'; $source = [IO.File]::ReadAllText($env:HUNIT_LAUNCHER); & ([scriptblock]::Create(($source -split '(?m)^:HUNIT_POWERSHELL\r?$' , 2)[1]))"
if errorlevel 1 pause
exit /b
:HUNIT_POWERSHELL
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$root = Split-Path -Parent $env:HUNIT_LAUNCHER
$gameExe = 'game_scarlett_master.exe'

$defaults = @{
    VICTORY_AMBIENT_AIR = '1.5'
    VICTORY_CACHE_DIR = Join-Path $env:LOCALAPPDATA 'VIctory\cache-pareto'
    VICTORY_TEXTURE_NO_WAIT = '1'
    VICTORY_RELAY = '2'
    VICTORY_WIDE_BACK = '1'
    VICTORY_CARD_REHASH_RUNS = '1'
    VICTORY_JOIN_COPIES = '1'
    VICTORY_INDIRECT_WINDOW = '1'
    VICTORY_RELAY_COPY = '1'
    VICTORY_CARD_STEPS = '2'
    VICTORY_INDIRECT_BATCH = '2'
    VICTORY_MAP_THREADS = '1'
    VICTORY_CARD_AWAKE = '1'
    VICTORY_SHOW_AFTER = '1'
    VICTORY_AMBIENT = '0.8'
    VICTORY_THIN = '1'
    VICTORY_JOIN_PARTS = '8'
    VICTORY_UPLOAD_AHEAD = '1'
    VICTORY_LEVELS_ON_DEMAND = '1'
    VICTORY_CARD_BUFFERS_MIN_KB = '64'
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'HUNIT | GTA'
$form.ClientSize = [System.Drawing.Size]::new(620, 170)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.AutoScaleMode = 'Dpi'
$form.Font = [System.Drawing.Font]::new('Segoe UI', 10)

$label = New-Object System.Windows.Forms.Label
$label.Text = 'Pasta do GTA'
$label.SetBounds(16, 15, 580, 23)

$folder = New-Object System.Windows.Forms.TextBox
$folder.SetBounds(16, 42, 456, 28)
$folder.Text = $env:VICTORY_GAME_DIR
if (-not $folder.Text) {
    $defaultFolder = Join-Path (Split-Path -Parent $root) 'GTA6.Xbox.v1.0.2.1'
    if (-not [System.IO.File]::Exists((Join-Path $defaultFolder $gameExe))) {
        $defaultFolder = 'D:\GTA6.Xbox.v1.0.2.1'
    }
    if ([System.IO.File]::Exists((Join-Path $defaultFolder $gameExe))) {
        $folder.Text = $defaultFolder
    }
}

$browse = New-Object System.Windows.Forms.Button
$browse.Text = 'Procurar...'
$browse.SetBounds(482, 40, 122, 30)
$browse.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    try {
        $dialog.Description = "Escolha a pasta que tem o arquivo $gameExe."
        $dialog.ShowNewFolderButton = $false
        if ([System.IO.Directory]::Exists($folder.Text)) {
            $dialog.SelectedPath = $folder.Text
        }
        if ($dialog.ShowDialog($form) -eq 'OK') {
            $folder.Text = $dialog.SelectedPath
        }
    } finally {
        $dialog.Dispose()
    }
})

$status = New-Object System.Windows.Forms.Label
$status.SetBounds(16, 86, 588, 36)

$start = New-Object System.Windows.Forms.Button
$start.Text = 'Iniciar'
$start.SetBounds(482, 124, 122, 30)
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 500

$start.Add_Click({
    try {
        $path = $folder.Text.Trim().Trim('"')
        if (-not $path -or -not [System.IO.File]::Exists([System.IO.Path]::Combine($path, $gameExe))) {
            $status.Text = "Escolha a pasta que tem o arquivo $gameExe."
            return
        }
        $runner = Join-Path $root 'victory-3d-rtx-pareto-residency.exe'
        if (-not [System.IO.File]::Exists($runner)) {
            $runner = Join-Path $root 'target\release\victory.exe'
        }
        if (-not [System.IO.File]::Exists($runner)) {
            $status.Text = 'Coloque o executavel do VIctory na mesma pasta deste BAT.'
            return
        }

        $gameDir = [System.IO.Path]::GetFullPath($path)
        $info = New-Object System.Diagnostics.ProcessStartInfo
        $info.FileName = $runner
        $console = if ($env:VICTORY_CONSOLE) { $env:VICTORY_CONSOLE } else { 'series-x' }
        $info.Arguments = 'run "{0}" --console {1} --execute' -f (Join-Path $gameDir $gameExe), $console
        $info.WorkingDirectory = $root
        $info.UseShellExecute = $false
        $info.EnvironmentVariables['VICTORY_GAME_DIR'] = $gameDir
        foreach ($setting in $defaults.GetEnumerator()) {
            if (-not $info.EnvironmentVariables[$setting.Key]) {
                $info.EnvironmentVariables[$setting.Key] = $setting.Value
            }
        }
        if (-not $info.EnvironmentVariables['VICTORY_LOG'] -and -not $info.EnvironmentVariables['RUST_LOG']) {
            $info.EnvironmentVariables['VICTORY_LOG'] = 'warn'
        }
        $script:gameProcess = [System.Diagnostics.Process]::Start($info)
        $start.Enabled = $false
        $status.Text = 'VIctory rodando...'
        $timer.Start()
    } catch {
        $status.Text = "Falha ao iniciar. $($_.Exception.Message)"
    }
})

$timer.Add_Tick({
    if ($script:gameProcess.HasExited) {
        $timer.Stop()
        $code = $script:gameProcess.ExitCode
        $script:gameProcess.Dispose()
        $script:gameProcess = $null
        $start.Enabled = $true
        $status.Text = if ($code -eq 0) { 'VIctory encerrado.' } else { "VIctory terminou com erro ($code)." }
    }
})

$form.Controls.AddRange(@($label, $folder, $browse, $status, $start))
$form.AcceptButton = $start
try {
    [void]$form.ShowDialog()
} finally {
    $timer.Dispose()
    if ($script:gameProcess) { $script:gameProcess.Dispose() }
    $form.Dispose()
}
