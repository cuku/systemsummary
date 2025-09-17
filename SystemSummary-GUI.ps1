# Relaunch self in STA if needed (WinForms requires STA)
if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = (Get-Process -Id $PID).Path
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -STA -File `"$PSCommandPath`""
    $null = [Diagnostics.Process]::Start($psi)
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function FormatHeaderLine {
    param ([string]$label, [int]$width = 60)
    $label = " $($label.ToUpper()) "
    $sideLength = [Math]::Floor(($width - $label.Length) / 2)
    $left = "=" * [Math]::Max(0,$sideLength)
    $right = "=" * [Math]::Max(0, $width - $sideLength - $label.Length)
    return "$left$label$right"
}

function Get-SystemInfoText {
    $nl = "`r`n"
    try { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop } catch { $os = $null }
    try { $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop } catch { $cs = $null }
    try { $bios = Get-CimInstance Win32_BIOS -ErrorAction Stop } catch { $bios = $null }
    try { $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop } catch { $cpu = $null }

    $totalMem = if ($cs -and $cs.TotalPhysicalMemory) { "{0:N2} GB" -f ($cs.TotalPhysicalMemory / 1GB) } else { "N/A" }

    $disks = @()
    try {
        $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop
    } catch {}
    $diskInfo = if ($disks) {
        $disks | ForEach-Object {
            $sizeGB = if ($_.Size) { [math]::Round($_.Size / 1GB, 2) } else { 0 }
            $freeGB = if ($_.FreeSpace) { [math]::Round($_.FreeSpace / 1GB, 2) } else { 0 }
            "$($_.DeviceID): $sizeGB GB total, $freeGB GB free"
        } -join $nl
    } else { "N/A" }

    $adapters = @()
    try {
        $adapters = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE" -ErrorAction Stop
    } catch {}
    $ipInfo = if ($adapters) {
        $adapters | ForEach-Object {
            $ips = @($_.IPAddress) | Where-Object {
                $_ -and ($_ -notmatch '^fe80:') # skip IPv6 link-local noise
            }
            $desc = $_.Description
            $mac  = $_.MACAddress
            $gw   = @($_.DefaultIPGateway) -join ', '
            $dns  = @($_.DNSServerSearchOrder) -join ', '
            "$desc`n  MAC: $mac`n  IP: $(@($ips) -join ', ')`n  GW: $gw`n  DNS: $dns"
        } -join $nl + $nl
    } else { "N/A" }

    $uptime = "N/A"
    if ($os -and $os.LastBootUpTime) {
        $boot = ([Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime))
        $uptime = (New-TimeSpan -Start $boot -End (Get-Date)) | ForEach-Object {
            "{0}d {1}h {2}m" -f $_.Days, $_.Hours, $_.Minutes
        }
    }

    $summary = ""
    $summary += FormatHeaderLine "System" 60 + $nl
    $summary += "Name: $($cs.Name        | ForEach-Object {$_} ?? 'N/A')$nl"
    $summary += "User: $($cs.UserName    | ForEach-Object {$_} ?? 'N/A')$nl"
    $summary += "Manufacturer: $($cs.Manufacturer | ForEach-Object {$_} ?? 'N/A')$nl"
    $summary += "Model: $($cs.Model      | ForEach-Object {$_} ?? 'N/A')$nl"
    $summary += "Memory: $totalMem$nl"
    $summary += "Uptime: $uptime$nl$nl"

    $summary += FormatHeaderLine "Operating System" 60 + $nl
    $summary += "OS: $($os.Caption          | ForEach-Object {$_} ?? 'N/A')$nl"
    $summary += "Version: $($os.Version     | ForEach-Object {$_} ?? 'N/A')$nl"
    $summary += "Architecture: $($os.OSArchitecture | ForEach-Object {$_} ?? 'N/A')$nl"
    $summary += "BIOS: $($bios.SMBIOSBIOSVersion   | ForEach-Object {$_} ?? 'N/A')$nl$nl"

    $summary += FormatHeaderLine "Processor" 60 + $nl
    $summary += "CPU: $($cpu.Name | Select-Object -First 1 | ForEach-Object {$_} ?? 'N/A')$nl"
    if ($cpu) {
        $cores   = ($cpu | Select-Object -First 1).NumberOfCores
        $logical = ($cpu | Select-Object -First 1).NumberOfLogicalProcessors
        $summary += "Cores: $cores, Logical: $logical$nl$nl"
    } else {
        $summary += "Cores: N/A, Logical: N/A$nl$nl"
    }

    $summary += FormatHeaderLine "Disk Info" 60 + $nl
    $summary += "$diskInfo$nl$nl"

    $summary += FormatHeaderLine "Network Info" 60 + $nl
    $summary += "$ipInfo"

    return $summary
}

$form = New-Object Windows.Forms.Form
$form.Text = "System Summary"
$form.Size = New-Object Drawing.Size(780, 560)
$form.StartPosition = "CenterScreen"

$textBox = New-Object Windows.Forms.TextBox
$textBox.Multiline = $true
$textBox.ReadOnly = $true
$textBox.ScrollBars = "Vertical"
$textBox.Dock = "Fill"
$textBox.Font = New-Object Drawing.Font("Consolas", 10)
$textBox.Text = Get-SystemInfoText

$form.Controls.Add($textBox)
[void]$form.ShowDialog()
