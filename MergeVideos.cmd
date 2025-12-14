@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "$env:MV_SELF='%~f0'; $c=Get-Content -Raw -LiteralPath $env:MV_SELF; $m=[regex]::Match($c,'(?m)^\:PSCODE\s*$'); if(!$m.Success){ exit 1 }; iex $c.Substring($m.Index+$m.Length)"
exit /b
:PSCODE
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

function Q([string]$s) { '"' + ($s -replace '"', '\"') + '"' }

function Show-ErrorWindow([string]$title, [string]$header, [string]$details) {
  $ef = New-Object System.Windows.Forms.Form
  $ef.Text = $title
  $ef.StartPosition = "CenterScreen"
  $ef.Size = New-Object System.Drawing.Size(920, 580)
  $ef.TopMost = $true
  $ef.BackColor = [System.Drawing.Color]::FromArgb(18, 18, 22)
  $ef.FormBorderStyle = "FixedDialog"
  $ef.MaximizeBox = $false

  $f1 = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
  $f2 = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Regular)

  $h = New-Object System.Windows.Forms.Label
  $h.Location = New-Object System.Drawing.Point(14, 12)
  $h.Size = New-Object System.Drawing.Size(880, 28)
  $h.Font = $f1
  $h.ForeColor = [System.Drawing.Color]::FromArgb(255, 200, 90)
  $h.Text = $header

  $tb = New-Object System.Windows.Forms.TextBox
  $tb.Location = New-Object System.Drawing.Point(14, 48)
  $tb.Size = New-Object System.Drawing.Size(880, 440)
  $tb.Font = $f2
  $tb.Multiline = $true
  $tb.ScrollBars = "Both"
  $tb.ReadOnly = $true
  $tb.WordWrap = $false
  $tb.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 34)
  $tb.ForeColor = [System.Drawing.Color]::FromArgb(235, 235, 235)
  $tb.Text = $details

  $btnCopy = New-Object System.Windows.Forms.Button
  $btnCopy.Location = New-Object System.Drawing.Point(14, 502)
  $btnCopy.Size = New-Object System.Drawing.Size(160, 36)
  $btnCopy.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
  $btnCopy.Text = "Copy error"
  $btnCopy.BackColor = [System.Drawing.Color]::FromArgb(60, 120, 255)
  $btnCopy.ForeColor = [System.Drawing.Color]::White
  $btnCopy.FlatStyle = "Flat"
  $btnCopy.Add_Click({ [System.Windows.Forms.Clipboard]::SetText($tb.Text) })

  $btnClose = New-Object System.Windows.Forms.Button
  $btnClose.Location = New-Object System.Drawing.Point(734, 502)
  $btnClose.Size = New-Object System.Drawing.Size(160, 36)
  $btnClose.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
  $btnClose.Text = "Close"
  $btnClose.BackColor = [System.Drawing.Color]::FromArgb(44, 44, 54)
  $btnClose.ForeColor = [System.Drawing.Color]::White
  $btnClose.FlatStyle = "Flat"
  $btnClose.Add_Click({ $ef.Close() })

  $ef.Controls.AddRange(@($h, $tb, $btnCopy, $btnClose))
  $ef.ShowDialog() | Out-Null
}

function Format-Time([double]$sec) {
  if ($sec -lt 0) { return "Calculating..." }
  $ts = [TimeSpan]::FromSeconds([int]$sec)
  if ($ts.TotalHours -ge 1) { return "{0:00}:{1:00}:{2:00}" -f [int]$ts.TotalHours, $ts.Minutes, $ts.Seconds }
  return "{0:00}:{1:00}" -f $ts.Minutes, $ts.Seconds
}

function PadNumbers([string]$s) {
  [regex]::Replace($s, '\d+', { param($m) $m.Value.PadLeft(20, '0') })
}

$ffmpegCmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
$ffprobeCmd = Get-Command ffprobe -ErrorAction SilentlyContinue
if (-not $ffmpegCmd -or -not $ffprobeCmd) {
  Show-ErrorWindow "Merge Videos" "FFmpeg not found" "Install FFmpeg and make sure ffmpeg.exe and ffprobe.exe are available in PATH."
  return
}

$enc = (& ffmpeg -hide_banner -encoders 2>$null | Out-String)
$hasH264Nvenc = ($enc -match 'h264_nvenc')
$hasHevcNvenc = ($enc -match 'hevc_nvenc')
$hasLibx265 = ($enc -match 'libx265')

$scriptDir = Split-Path -Parent $env:MV_SELF
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

$setup = New-Object System.Windows.Forms.Form
$setup.Text = "Merge Videos"
$setup.StartPosition = "CenterScreen"
$setup.Size = New-Object System.Drawing.Size(860, 420)
$setup.TopMost = $true
$setup.BackColor = [System.Drawing.Color]::FromArgb(18, 18, 22)
$setup.FormBorderStyle = "FixedDialog"
$setup.MaximizeBox = $false

$ft = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$fs = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)

$ttl = New-Object System.Windows.Forms.Label
$ttl.Location = New-Object System.Drawing.Point(16, 14)
$ttl.Size = New-Object System.Drawing.Size(820, 28)
$ttl.Font = $ft
$ttl.ForeColor = [System.Drawing.Color]::FromArgb(90, 200, 255)
$ttl.Text = "Merge videos into one file"

$lblIn = New-Object System.Windows.Forms.Label
$lblIn.Location = New-Object System.Drawing.Point(16, 62)
$lblIn.Size = New-Object System.Drawing.Size(200, 20)
$lblIn.Font = $fs
$lblIn.ForeColor = [System.Drawing.Color]::White
$lblIn.Text = "Input folder"

$txtIn = New-Object System.Windows.Forms.TextBox
$txtIn.Location = New-Object System.Drawing.Point(16, 86)
$txtIn.Size = New-Object System.Drawing.Size(670, 26)
$txtIn.Font = $fs
$txtIn.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 34)
$txtIn.ForeColor = [System.Drawing.Color]::FromArgb(235, 235, 235)

$btnIn = New-Object System.Windows.Forms.Button
$btnIn.Location = New-Object System.Drawing.Point(702, 84)
$btnIn.Size = New-Object System.Drawing.Size(130, 30)
$btnIn.Font = $fs
$btnIn.Text = "Browse"
$btnIn.BackColor = [System.Drawing.Color]::FromArgb(44, 44, 54)
$btnIn.ForeColor = [System.Drawing.Color]::White
$btnIn.FlatStyle = "Flat"

$lblOut = New-Object System.Windows.Forms.Label
$lblOut.Location = New-Object System.Drawing.Point(16, 122)
$lblOut.Size = New-Object System.Drawing.Size(300, 20)
$lblOut.Font = $fs
$lblOut.ForeColor = [System.Drawing.Color]::White
$lblOut.Text = "Output file (optional)"

$txtOut = New-Object System.Windows.Forms.TextBox
$txtOut.Location = New-Object System.Drawing.Point(16, 146)
$txtOut.Size = New-Object System.Drawing.Size(670, 26)
$txtOut.Font = $fs
$txtOut.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 34)
$txtOut.ForeColor = [System.Drawing.Color]::FromArgb(235, 235, 235)

$btnOut = New-Object System.Windows.Forms.Button
$btnOut.Location = New-Object System.Drawing.Point(702, 144)
$btnOut.Size = New-Object System.Drawing.Size(130, 30)
$btnOut.Font = $fs
$btnOut.Text = "Browse"
$btnOut.BackColor = [System.Drawing.Color]::FromArgb(44, 44, 54)
$btnOut.ForeColor = [System.Drawing.Color]::White
$btnOut.FlatStyle = "Flat"

$lblFmt = New-Object System.Windows.Forms.Label
$lblFmt.Location = New-Object System.Drawing.Point(16, 186)
$lblFmt.Size = New-Object System.Drawing.Size(160, 20)
$lblFmt.Font = $fs
$lblFmt.ForeColor = [System.Drawing.Color]::White
$lblFmt.Text = "Format"

$cmbFmt = New-Object System.Windows.Forms.ComboBox
$cmbFmt.Location = New-Object System.Drawing.Point(16, 210)
$cmbFmt.Size = New-Object System.Drawing.Size(160, 26)
$cmbFmt.Font = $fs
$cmbFmt.DropDownStyle = "DropDownList"
$cmbFmt.Items.Add("MKV") | Out-Null
$cmbFmt.Items.Add("MP4") | Out-Null
$cmbFmt.SelectedIndex = 0

$lblCodec = New-Object System.Windows.Forms.Label
$lblCodec.Location = New-Object System.Drawing.Point(196, 186)
$lblCodec.Size = New-Object System.Drawing.Size(200, 20)
$lblCodec.Font = $fs
$lblCodec.ForeColor = [System.Drawing.Color]::White
$lblCodec.Text = "Video codec"

$cmbCodec = New-Object System.Windows.Forms.ComboBox
$cmbCodec.Location = New-Object System.Drawing.Point(196, 210)
$cmbCodec.Size = New-Object System.Drawing.Size(200, 26)
$cmbCodec.Font = $fs
$cmbCodec.DropDownStyle = "DropDownList"
$cmbCodec.Items.Add("H.264") | Out-Null
$cmbCodec.Items.Add("H.265") | Out-Null
$cmbCodec.SelectedIndex = 0

$lblAcc = New-Object System.Windows.Forms.Label
$lblAcc.Location = New-Object System.Drawing.Point(416, 186)
$lblAcc.Size = New-Object System.Drawing.Size(180, 20)
$lblAcc.Font = $fs
$lblAcc.ForeColor = [System.Drawing.Color]::White
$lblAcc.Text = "Acceleration"

$cmbAcc = New-Object System.Windows.Forms.ComboBox
$cmbAcc.Location = New-Object System.Drawing.Point(416, 210)
$cmbAcc.Size = New-Object System.Drawing.Size(200, 26)
$cmbAcc.Font = $fs
$cmbAcc.DropDownStyle = "DropDownList"
$cmbAcc.Items.Add("Auto") | Out-Null
$cmbAcc.Items.Add("NVIDIA GPU") | Out-Null
$cmbAcc.Items.Add("CPU") | Out-Null
$cmbAcc.SelectedIndex = 0

$lblQ = New-Object System.Windows.Forms.Label
$lblQ.Location = New-Object System.Drawing.Point(636, 186)
$lblQ.Size = New-Object System.Drawing.Size(200, 20)
$lblQ.Font = $fs
$lblQ.ForeColor = [System.Drawing.Color]::White
$lblQ.Text = "Quality"

$cmbQ = New-Object System.Windows.Forms.ComboBox
$cmbQ.Location = New-Object System.Drawing.Point(636, 210)
$cmbQ.Size = New-Object System.Drawing.Size(196, 26)
$cmbQ.Font = $fs
$cmbQ.DropDownStyle = "DropDownList"
$cmbQ.Items.Add("Lossless (huge)") | Out-Null
$cmbQ.Items.Add("Very High") | Out-Null
$cmbQ.Items.Add("High") | Out-Null
$cmbQ.Items.Add("Medium") | Out-Null
$cmbQ.Items.Add("Small") | Out-Null
$cmbQ.SelectedIndex = 2

$lblSpeed = New-Object System.Windows.Forms.Label
$lblSpeed.Location = New-Object System.Drawing.Point(16, 250)
$lblSpeed.Size = New-Object System.Drawing.Size(160, 20)
$lblSpeed.Font = $fs
$lblSpeed.ForeColor = [System.Drawing.Color]::White
$lblSpeed.Text = "Speed"

$cmbSpeed = New-Object System.Windows.Forms.ComboBox
$cmbSpeed.Location = New-Object System.Drawing.Point(16, 274)
$cmbSpeed.Size = New-Object System.Drawing.Size(160, 26)
$cmbSpeed.Font = $fs
$cmbSpeed.DropDownStyle = "DropDownList"
$cmbSpeed.Items.Add("Fast") | Out-Null
$cmbSpeed.Items.Add("Balanced") | Out-Null
$cmbSpeed.Items.Add("Slow") | Out-Null
$cmbSpeed.SelectedIndex = 1

$lblAudio = New-Object System.Windows.Forms.Label
$lblAudio.Location = New-Object System.Drawing.Point(196, 250)
$lblAudio.Size = New-Object System.Drawing.Size(220, 20)
$lblAudio.Font = $fs
$lblAudio.ForeColor = [System.Drawing.Color]::White
$lblAudio.Text = "Audio"

$cmbAudio = New-Object System.Windows.Forms.ComboBox
$cmbAudio.Location = New-Object System.Drawing.Point(196, 274)
$cmbAudio.Size = New-Object System.Drawing.Size(240, 26)
$cmbAudio.Font = $fs
$cmbAudio.DropDownStyle = "DropDownList"
$cmbAudio.Items.Add("AAC (compatible)") | Out-Null
$cmbAudio.Items.Add("Lossless (FLAC)") | Out-Null
$cmbAudio.SelectedIndex = 0

$chkKeep = New-Object System.Windows.Forms.CheckBox
$chkKeep.Location = New-Object System.Drawing.Point(456, 276)
$chkKeep.Size = New-Object System.Drawing.Size(220, 24)
$chkKeep.Font = $fs
$chkKeep.ForeColor = [System.Drawing.Color]::FromArgb(210, 210, 220)
$chkKeep.Text = "Keep temp files"
$chkKeep.Checked = $false

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Location = New-Object System.Drawing.Point(702, 318)
$btnStart.Size = New-Object System.Drawing.Size(130, 40)
$btnStart.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$btnStart.Text = "Start"
$btnStart.BackColor = [System.Drawing.Color]::FromArgb(60, 180, 120)
$btnStart.ForeColor = [System.Drawing.Color]::White
$btnStart.FlatStyle = "Flat"

$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Location = New-Object System.Drawing.Point(16, 318)
$btnExit.Size = New-Object System.Drawing.Size(130, 40)
$btnExit.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$btnExit.Text = "Exit"
$btnExit.BackColor = [System.Drawing.Color]::FromArgb(44, 44, 54)
$btnExit.ForeColor = [System.Drawing.Color]::White
$btnExit.FlatStyle = "Flat"
$btnExit.Add_Click({ $setup.Close() })

$setup.Controls.AddRange(@($ttl, $lblIn, $txtIn, $btnIn, $lblOut, $txtOut, $btnOut, $lblFmt, $cmbFmt, $lblCodec, $cmbCodec, $lblAcc, $cmbAcc, $lblQ, $cmbQ, $lblSpeed, $cmbSpeed, $lblAudio, $cmbAudio, $chkKeep, $btnStart, $btnExit))

$btnIn.Add_Click({
    $fb = New-Object System.Windows.Forms.FolderBrowserDialog
    $fb.Description = "Select the folder that contains your videos"
    $fb.SelectedPath = $scriptDir
    if ($txtIn.Text -and (Test-Path -LiteralPath $txtIn.Text)) { $fb.SelectedPath = $txtIn.Text }
    if ($fb.ShowDialog() -eq "OK") { $txtIn.Text = $fb.SelectedPath }
  })

$btnOut.Add_Click({
    $sf = New-Object System.Windows.Forms.SaveFileDialog
    $sf.Title = "Save merged video as"
    $sf.InitialDirectory = $scriptDir
    $sf.FileName = "merged." + ($cmbFmt.SelectedItem.ToString().ToLower())
    $sf.Filter = "Video files|*.mkv;*.mp4|All files|*.*"
    if ($txtOut.Text) {
      try {
        $sf.InitialDirectory = Split-Path -Parent $txtOut.Text
        $sf.FileName = Split-Path -Leaf $txtOut.Text
      }
      catch {}
    }
    if ($sf.ShowDialog() -eq "OK") { $txtOut.Text = $sf.FileName }
  })

$cmbFmt.Add_SelectedIndexChanged({
    $fmt = $cmbFmt.SelectedItem.ToString().ToLower()
    if ($fmt -eq "mp4") {
      if ($cmbAudio.SelectedIndex -eq 1) { $cmbAudio.SelectedIndex = 0 }
      $cmbAudio.Enabled = $false
    }
    else {
      $cmbAudio.Enabled = $true
    }
  })

$script:cfg = $null
$btnStart.Add_Click({
    if (-not $txtIn.Text -or -not (Test-Path -LiteralPath $txtIn.Text)) {
      Show-ErrorWindow "Merge Videos" "Input folder not set" "Choose a valid input folder."
      return
    }

    $fmt = $cmbFmt.SelectedItem.ToString().ToLower()
    $codec = $cmbCodec.SelectedItem.ToString()
    $acc = $cmbAcc.SelectedItem.ToString()
    $quality = $cmbQ.SelectedItem.ToString()
    $speed = $cmbSpeed.SelectedItem.ToString()
    $audio = $cmbAudio.SelectedItem.ToString()
    $keep = $chkKeep.Checked

    if ($codec -eq "H.265" -and -not $hasLibx265 -and -not $hasHevcNvenc) {
      Show-ErrorWindow "Merge Videos" "H.265 not available" "Your FFmpeg build does not show libx265 or hevc_nvenc."
      return
    }

    if ($acc -eq "NVIDIA GPU") {
      if ($codec -eq "H.264" -and -not $hasH264Nvenc) {
        Show-ErrorWindow "Merge Videos" "NVIDIA H.264 encoder not available" "This FFmpeg build does not show h264_nvenc."
        return
      }
      if ($codec -eq "H.265" -and -not $hasHevcNvenc) {
        Show-ErrorWindow "Merge Videos" "NVIDIA H.265 encoder not available" "This FFmpeg build does not show hevc_nvenc."
        return
      }
    }

    $out = $txtOut.Text
    if (-not $out -or $out.Trim().Length -eq 0) {
      $out = Join-Path $scriptDir ("merged." + $fmt)
    }
    else {
      $ext = [IO.Path]::GetExtension($out)
      if (-not $ext) { $out = $out + "." + $fmt }
    }

    $outDir = Split-Path -Parent $out
    if (-not $outDir -or $outDir.Trim().Length -eq 0) { $outDir = $scriptDir; $out = Join-Path $outDir ("merged." + $fmt) }
    try { New-Item -ItemType Directory -Force $outDir | Out-Null } catch { Show-ErrorWindow "Merge Videos" "Cannot create output folder" $outDir; return }

    $script:cfg = [pscustomobject]@{
      Src       = $txtIn.Text
      Out       = $out
      Fmt       = $fmt
      Codec     = $codec
      Acc       = $acc
      Quality   = $quality
      Speed     = $speed
      Audio     = $audio
      Keep      = $keep
      ScriptDir = $scriptDir
    }
    $setup.Close()
  })

$setup.ShowDialog() | Out-Null
if (-not $script:cfg) { return }

$src = $script:cfg.Src
$out = $script:cfg.Out
$fmt = $script:cfg.Fmt
$codec = $script:cfg.Codec
$acc = $script:cfg.Acc
$quality = $script:cfg.Quality
$speed = $script:cfg.Speed
$audioChoice = $script:cfg.Audio
$keepTemp = $script:cfg.Keep

$tmpRoot = Join-Path (Split-Path -Parent $out) ("_tmp_merge_" + ([guid]::NewGuid().ToString("N")))
New-Item -ItemType Directory -Force $tmpRoot | Out-Null

$main = New-Object System.Windows.Forms.Form
$main.Text = "Merging videos"
$main.StartPosition = "CenterScreen"
$main.Size = New-Object System.Drawing.Size(860, 320)
$main.TopMost = $true
$main.BackColor = [System.Drawing.Color]::FromArgb(18, 18, 22)
$main.FormBorderStyle = "FixedDialog"
$main.MaximizeBox = $false

$fontTitle = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$fontText = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$fontSmall = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)

$hdr = New-Object System.Windows.Forms.Label
$hdr.Location = New-Object System.Drawing.Point(16, 12)
$hdr.Size = New-Object System.Drawing.Size(820, 28)
$hdr.Font = $fontTitle
$hdr.ForeColor = [System.Drawing.Color]::FromArgb(90, 200, 255)
$hdr.Text = "Progress"

$lblStage = New-Object System.Windows.Forms.Label
$lblStage.Location = New-Object System.Drawing.Point(16, 52)
$lblStage.Size = New-Object System.Drawing.Size(820, 22)
$lblStage.Font = $fontText
$lblStage.ForeColor = [System.Drawing.Color]::White
$lblStage.Text = "Starting..."

$lblFile = New-Object System.Windows.Forms.Label
$lblFile.Location = New-Object System.Drawing.Point(16, 76)
$lblFile.Size = New-Object System.Drawing.Size(820, 22)
$lblFile.Font = $fontSmall
$lblFile.ForeColor = [System.Drawing.Color]::FromArgb(210, 210, 220)
$lblFile.Text = ""

$pbAll = New-Object System.Windows.Forms.ProgressBar
$pbAll.Location = New-Object System.Drawing.Point(16, 110)
$pbAll.Size = New-Object System.Drawing.Size(820, 18)
$pbAll.Minimum = 0
$pbAll.Maximum = 100

$pbCur = New-Object System.Windows.Forms.ProgressBar
$pbCur.Location = New-Object System.Drawing.Point(16, 140)
$pbCur.Size = New-Object System.Drawing.Size(820, 18)
$pbCur.Minimum = 0
$pbCur.Maximum = 100

$lblStats = New-Object System.Windows.Forms.Label
$lblStats.Location = New-Object System.Drawing.Point(16, 172)
$lblStats.Size = New-Object System.Drawing.Size(820, 22)
$lblStats.Font = $fontSmall
$lblStats.ForeColor = [System.Drawing.Color]::FromArgb(210, 210, 220)
$lblStats.Text = ""

$lblEta = New-Object System.Windows.Forms.Label
$lblEta.Location = New-Object System.Drawing.Point(16, 196)
$lblEta.Size = New-Object System.Drawing.Size(820, 22)
$lblEta.Font = $fontSmall
$lblEta.ForeColor = [System.Drawing.Color]::FromArgb(210, 210, 220)
$lblEta.Text = ""

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Location = New-Object System.Drawing.Point(16, 236)
$btnCancel.Size = New-Object System.Drawing.Size(130, 40)
$btnCancel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$btnCancel.Text = "Cancel"
$btnCancel.BackColor = [System.Drawing.Color]::FromArgb(255, 80, 80)
$btnCancel.ForeColor = [System.Drawing.Color]::White
$btnCancel.FlatStyle = "Flat"

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Location = New-Object System.Drawing.Point(706, 236)
$btnClose.Size = New-Object System.Drawing.Size(130, 40)
$btnClose.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$btnClose.Text = "Close"
$btnClose.BackColor = [System.Drawing.Color]::FromArgb(44, 44, 54)
$btnClose.ForeColor = [System.Drawing.Color]::White
$btnClose.FlatStyle = "Flat"
$btnClose.Enabled = $false
$btnClose.Add_Click({ $main.Close() })

$main.Controls.AddRange(@($hdr, $lblStage, $lblFile, $pbAll, $pbCur, $lblStats, $lblEta, $btnCancel, $btnClose))
$main.Show()
[System.Windows.Forms.Application]::DoEvents() | Out-Null

$script:cancel = $false
$script:proc = $null
$btnCancel.Add_Click({
    $script:cancel = $true
    if ($script:proc -and -not $script:proc.HasExited) {
      try { $script:proc.Kill() | Out-Null } catch {}
    }
  })

$exts = @(".mp4", ".mkv", ".mov", ".webm", ".avi", ".flv", ".m4v", ".ts", ".mts", ".m2ts", ".wmv")
$files = Get-ChildItem -LiteralPath $src -File | Where-Object { $exts -contains $_.Extension.ToLower() } | Sort-Object @{Expression = { PadNumbers($_.Name.ToLower()) } }, Name
if (-not $files -or $files.Count -eq 0) {
  Show-ErrorWindow "Merge Videos" "No video files found" ("Folder: " + $src)
  $main.Close()
  return
}

$N = $files.Count
$dur = @{}
$tot = 0.0
$k = 0

$lblStage.Text = "Scanning durations..."
$pbAll.Value = 0
$pbCur.Value = 0
[System.Windows.Forms.Application]::DoEvents() | Out-Null

foreach ($f in $files) {
  if ($script:cancel) { $main.Close(); return }
  $k++
  $lblFile.Text = "($k / $N) $($f.Name)"
  $pbAll.Value = [Math]::Min(100, [int](100 * $k / $N))
  [System.Windows.Forms.Application]::DoEvents() | Out-Null
  $dRaw = (ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 (Q $f.FullName) 2>$null)
  $d = 0.0
  if ($dRaw) { [double]::TryParse(($dRaw -replace ',', '.'), [ref]$d) | Out-Null }
  if ($d -le 0) { $d = 1.0 }
  $dur[$f.FullName] = $d
  $tot += $d
}

function Get-CRFOrCQ([string]$q) {
  switch -regex ($q) {
    '^Lossless' { return $null }
    '^Very High' { return 14 }
    '^High' { return 18 }
    '^Medium' { return 22 }
    '^Small' { return 28 }
    default { return 18 }
  }
}

function Get-CPUPreset([string]$s) {
  switch ($s) {
    'Fast' { return 'veryfast' }
    'Balanced' { return 'medium' }
    'Slow' { return 'slow' }
    default { return 'medium' }
  }
}

function Get-GPUPreset([string]$s) {
  switch ($s) {
    'Fast' { return 'p1' }
    'Balanced' { return 'p4' }
    'Slow' { return 'p7' }
    default { return 'p4' }
  }
}

$useGpu = $false
if ($acc -eq "Auto") {
  if ($codec -eq "H.264" -and $hasH264Nvenc) { $useGpu = $true }
  if ($codec -eq "H.265" -and $hasHevcNvenc) { $useGpu = $true }
}
elseif ($acc -eq "NVIDIA GPU") {
  $useGpu = $true
}
else {
  $useGpu = $false
}

$lossless = ($quality -match '^Lossless')
$qVal = Get-CRFOrCQ $quality
$cpuPreset = Get-CPUPreset $speed
$gpuPreset = Get-GPUPreset $speed

$audioMode = "aac"
if ($fmt -eq "mkv") {
  if ($audioChoice -match '^Lossless') { $audioMode = "flac" } else { $audioMode = "aac" }
}
else {
  $audioMode = "aac"
}

$done = 0.0
$i = 0

$lblStage.Text = "Encoding..."
$pbAll.Value = 0
$pbCur.Value = 0
[System.Windows.Forms.Application]::DoEvents() | Out-Null

foreach ($f in $files) {
  if ($script:cancel) { $main.Close(); return }
  $i++
  $dst = Join-Path $tmpRoot ("{0:D6}.{1}" -f $i, $fmt)

  $a = (ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=nw=1:nk=1 (Q $f.FullName) 2>$null)
  $hasAudio = ($a -and $a.Trim().Length -gt 0)

  $lblFile.Text = "($i / $N) $($f.Name)"
  $pbCur.Value = 0
  [System.Windows.Forms.Application]::DoEvents() | Out-Null

  $arg = "-hide_banner -loglevel error -nostats -y -fflags +genpts -i $(Q $f.FullName) "
  if (-not $hasAudio) {
    $arg += "-f lavfi -i $(Q "anullsrc=channel_layout=stereo:sample_rate=44100") -map 0:v:0 -map 1:a:0 -shortest "
  }
  else {
    $arg += "-map 0:v:0 -map 0:a:0 "
  }

  if ($codec -eq "H.264") {
    if ($useGpu) {
      if ($lossless) {
        $v = "-c:v h264_nvenc -preset $gpuPreset -rc constqp -qp 0 -pix_fmt yuv420p "
      }
      else {
        $v = "-c:v h264_nvenc -preset $gpuPreset -rc vbr -cq $qVal -b:v 0 -pix_fmt yuv420p "
      }
    }
    else {
      if ($lossless) {
        $v = "-c:v libx264 -preset $cpuPreset -qp 0 -pix_fmt yuv420p "
      }
      else {
        $v = "-c:v libx264 -preset $cpuPreset -crf $qVal -pix_fmt yuv420p "
      }
    }
  }
  else {
    if ($useGpu) {
      if ($lossless) {
        $v = "-c:v hevc_nvenc -preset $gpuPreset -rc constqp -qp 0 -pix_fmt yuv420p "
      }
      else {
        $v = "-c:v hevc_nvenc -preset $gpuPreset -rc vbr -cq $qVal -b:v 0 -pix_fmt yuv420p "
      }
    }
    else {
      if ($lossless) {
        $v = "-c:v libx265 -preset $cpuPreset -x265-params lossless=1 "
      }
      else {
        $v = "-c:v libx265 -preset $cpuPreset -crf $qVal "
      }
    }
  }

  if ($audioMode -eq "flac") {
    $aEnc = "-c:a flac "
  }
  else {
    $aEnc = "-c:a aac -b:a 192k "
  }

  $arg += $v + $aEnc + "-progress pipe:1 " + (Q $dst)

  $p = New-Object System.Diagnostics.Process
  $p.StartInfo.FileName = "ffmpeg"
  $p.StartInfo.Arguments = $arg
  $p.StartInfo.UseShellExecute = $false
  $p.StartInfo.RedirectStandardOutput = $true
  $p.StartInfo.RedirectStandardError = $true
  $null = $p.Start()
  $script:proc = $p

  $cur = 0.0
  $spd = 0.0
  $fileDur = [double]$dur[$f.FullName]

  while (-not $p.HasExited) {
    if ($script:cancel) {
      try { $p.Kill() | Out-Null } catch {}
      $main.Close()
      return
    }
    $line = $p.StandardOutput.ReadLine()
    if ($null -eq $line) { continue }
    if ($line -match '^out_time_ms=(\d+)$') { $cur = [double]$matches[1] / 1000000.0 }
    elseif ($line -match '^speed=([\d\.]+)x$') { $spd = [double]$matches[1] }

    $curClamped = [Math]::Min($fileDur, [Math]::Max(0.0, $cur))
    $pbCur.Value = [Math]::Min(100, [int](100 * $curClamped / $fileDur))

    $g = $done + $curClamped
    $pbAll.Value = [Math]::Min(100, [int](100 * $g / $tot))

    $etaSec = -1
    if ($spd -gt 0.01) { $etaSec = ($tot - $g) / $spd }

    $lblStats.Text = ("Overall {0}% | Current {1}% | Speed {2:N2}x" -f [int](100 * $g / $tot), [int](100 * $curClamped / $fileDur), $spd)
    $lblEta.Text = ("ETA {0} | Done {1} / {2}" -f (Format-Time $etaSec), (Format-Time $g), (Format-Time $tot))
    [System.Windows.Forms.Application]::DoEvents() | Out-Null
  }

  $stderr = $p.StandardError.ReadToEnd()
  if ($p.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $dst)) {
    $msg = "Input: $($f.FullName)`r`nExitCode: $($p.ExitCode)`r`nOutput: $dst`r`n`r`nCommand:`r`nffmpeg $arg`r`n`r`nError:`r`n$stderr"
    Show-ErrorWindow "Merge Videos" "Encoding failed" $msg
    $main.Close()
    return
  }

  $done += $fileDur
}

$parts = @(Get-ChildItem -LiteralPath $tmpRoot -File -Filter ("*." + $fmt) | Sort-Object Name)
if ($parts.Count -eq 0) {
  Show-ErrorWindow "Merge Videos" "No output parts were created" $tmpRoot
  $main.Close()
  return
}

$listPath = Join-Path $tmpRoot "list.txt"
$list = @($parts | ForEach-Object { "file '$($_.FullName)'" })
[System.IO.File]::WriteAllLines($listPath, $list, (New-Object System.Text.UTF8Encoding($false)))

$lblStage.Text = "Final merge..."
$lblFile.Text = "Creating: $out"
$pbCur.Style = "Marquee"
$pbCur.MarqueeAnimationSpeed = 30
$pbAll.Value = 100
$lblStats.Text = ""
$lblEta.Text = ""
[System.Windows.Forms.Application]::DoEvents() | Out-Null

$m = New-Object System.Diagnostics.Process
$m.StartInfo.FileName = "ffmpeg"
if ($fmt -eq "mp4") {
  $m.StartInfo.Arguments = "-hide_banner -loglevel error -nostats -y -f concat -safe 0 -i $(Q $listPath) -c copy -map 0 -movflags +faststart $(Q $out)"
}
else {
  $m.StartInfo.Arguments = "-hide_banner -loglevel error -nostats -y -f concat -safe 0 -i $(Q $listPath) -c copy -map 0 $(Q $out)"
}
$m.StartInfo.UseShellExecute = $false
$m.StartInfo.RedirectStandardError = $true
$m.StartInfo.RedirectStandardOutput = $true
$null = $m.Start()
$script:proc = $m
$m.WaitForExit()
$mergeErr = $m.StandardError.ReadToEnd()

if ($m.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $out)) {
  $msg = "ExitCode: $($m.ExitCode)`r`nOutput: $out`r`n`r`nCommand:`r`nffmpeg $($m.StartInfo.Arguments)`r`n`r`nError:`r`n$mergeErr"
  Show-ErrorWindow "Merge Videos" "Final merge failed" $msg
  $main.Close()
  return
}

if (-not $keepTemp) {
  try { Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue | Out-Null } catch {}
}

$pbCur.Style = "Blocks"
$pbCur.MarqueeAnimationSpeed = 0
$pbCur.Value = 100
$lblStage.Text = "Done"
$lblFile.Text = $out
$lblStats.Text = "Completed"
$lblEta.Text = ""
$btnCancel.Enabled = $false
$btnClose.Enabled = $true
[System.Windows.Forms.Application]::DoEvents() | Out-Null
