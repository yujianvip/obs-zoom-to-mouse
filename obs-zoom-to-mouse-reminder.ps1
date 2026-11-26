param(
    [Parameter(Mandatory = $true)]
    [string]$StateFile
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class ObsZoomReminderNative {
    [DllImport("user32.dll", EntryPoint = "GetWindowLongW")]
    public static extern int GetWindowLong(IntPtr hWnd, int index);
    [DllImport("user32.dll", EntryPoint = "SetWindowLongW")]
    public static extern int SetWindowLong(IntPtr hWnd, int index, int value);
}
'@

$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$form.ShowInTaskbar = $false
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$form.Size = New-Object System.Drawing.Size(230, 58)
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 34, 42)
$form.Opacity = 0.94
$form.TopMost = $true
$form.Padding = New-Object System.Windows.Forms.Padding(8)

$label = New-Object System.Windows.Forms.Label
$label.Dock = [System.Windows.Forms.DockStyle]::Fill
$label.Text = '放大中...'
$label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$label.ForeColor = [System.Drawing.Color]::FromArgb(255, 224, 96)
$label.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 18, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($label)

$handle = $form.Handle
$style = [ObsZoomReminderNative]::GetWindowLong($handle, -20)
# Click through, stay out of the taskbar, and never take keyboard focus.
[void][ObsZoomReminderNative]::SetWindowLong($handle, -20, $style -bor 0x20 -bor 0x80 -bor 0x08000000)

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 100
$lastFontDimensions = ''
$timer.Add_Tick({
    try {
        $parts = [System.IO.File]::ReadAllText($StateFile).Trim().Split('|')
        if ($parts.Count -lt 2) { return }

        $state = $parts[0]
        if ($state -eq 'STOP') {
            $timer.Stop()
            $form.Close()
            [System.Windows.Forms.Application]::ExitThread()
            return
        }

        $heartbeat = 0L
        if (-not [long]::TryParse($parts[1], [ref]$heartbeat) -or
            ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $heartbeat) -gt 5) {
            $timer.Stop()
            $form.Close()
            [System.Windows.Forms.Application]::ExitThread()
            return
        }

        $reminderX = -1
        $reminderY = -1
        $reminderWidth = 230
        $reminderHeight = 58
        $reminderOpacity = 94
        if ($parts.Count -ge 11) {
            [void][int]::TryParse($parts[6], [ref]$reminderX)
            [void][int]::TryParse($parts[7], [ref]$reminderY)
            [void][int]::TryParse($parts[8], [ref]$reminderWidth)
            [void][int]::TryParse($parts[9], [ref]$reminderHeight)
            [void][int]::TryParse($parts[10], [ref]$reminderOpacity)
        }
        $reminderWidth = [Math]::Max(100, [Math]::Min(1200, $reminderWidth))
        $reminderHeight = [Math]::Max(40, [Math]::Min(500, $reminderHeight))
        $reminderOpacity = [Math]::Max(10, [Math]::Min(100, $reminderOpacity))
        if ($form.Width -ne $reminderWidth -or $form.Height -ne $reminderHeight) {
            $form.Size = New-Object System.Drawing.Size($reminderWidth, $reminderHeight)
        }
        $form.Opacity = $reminderOpacity / 100.0
        $dimensions = "$reminderWidth`x$reminderHeight"
        if ($lastFontDimensions -ne $dimensions) {
            $availableWidth = [Math]::Max(20, $reminderWidth - 24)
            $availableHeight = [Math]::Max(20, $reminderHeight - 20)
            $bestFontSize = 10
            for ($candidateSize = 10; $candidateSize -le 240; $candidateSize++) {
                $candidateFont = New-Object System.Drawing.Font('Microsoft YaHei UI', [single]$candidateSize, [System.Drawing.FontStyle]::Bold)
                $textSize = [System.Windows.Forms.TextRenderer]::MeasureText($label.Text, $candidateFont)
                $candidateFont.Dispose()
                if ($textSize.Width -gt $availableWidth -or $textSize.Height -gt $availableHeight) { break }
                $bestFontSize = $candidateSize
            }
            $label.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', [single]$bestFontSize, [System.Drawing.FontStyle]::Bold)
            $lastFontDimensions = $dimensions
        }

        if ($parts.Count -ge 6) {
            $monitorX = 0
            $monitorY = 0
            $monitorWidth = 0
            $monitorHeight = 0
            if ([int]::TryParse($parts[2], [ref]$monitorX) -and
                [int]::TryParse($parts[3], [ref]$monitorY) -and
                [int]::TryParse($parts[4], [ref]$monitorWidth) -and
                [int]::TryParse($parts[5], [ref]$monitorHeight) -and
                $monitorWidth -gt 0 -and $monitorHeight -gt 0) {
                $center = New-Object System.Drawing.Point(($monitorX + [int]($monitorWidth / 2)), ($monitorY + [int]($monitorHeight / 2)))
                $screen = [System.Windows.Forms.Screen]::FromPoint($center)
                $area = $screen.WorkingArea
                $targetX = if ($reminderX -ge 0) { $screen.Bounds.Left + $reminderX } else { $area.Right - $form.Width - 24 }
                $targetY = if ($reminderY -ge 0) { $screen.Bounds.Top + $reminderY } else { $area.Bottom - $form.Height - 36 }
                $targetX = [Math]::Max($screen.Bounds.Left, [Math]::Min($screen.Bounds.Right - $form.Width, $targetX))
                $targetY = [Math]::Max($screen.Bounds.Top, [Math]::Min($screen.Bounds.Bottom - $form.Height, $targetY))
                $target = New-Object System.Drawing.Point($targetX, $targetY)
                if ($form.Location -ne $target) { $form.Location = $target }
            }
        }

        if ($state -eq 'ON') {
            if (-not $form.Visible) { $form.Show() }
            $form.TopMost = $true
        } elseif ($form.Visible) {
            $form.Hide()
        }
    } catch {
        # Wait for the next state-file update if OBS is writing it now.
    }
})

$timer.Start()
[System.Windows.Forms.Application]::Run()
try { [System.IO.File]::Delete($StateFile) } catch { }
