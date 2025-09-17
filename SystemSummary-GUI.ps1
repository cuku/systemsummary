

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function FormatHeaderLine {
    param ([string]$label, [int]$width)
    $label = " $($label.ToUpper()) "
    $sideLength = [Math]::Floor(($width - $label.Length) / 2)
    $left = "=" * $sideLength
    $right = "=" * ($width - $sideLength - $label.Length)
    return "$left$label$right"
}

function Get-SystemInfoText {
    $nl = "`r`n"
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS
    $cpu = Get-CimInstance Win32_Processor
    $memory = "{0:N2} GB" -f ($cs.TotalPhysicalMemory / 1GB)

    $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
    $diskInfo = $disks | ForEach-Object {
        "$($_.DeviceID): $([math]::Round($_.Size / 1GB, 2)) GB total, $([math]::Round($_.FreeSpace / 1GB, 2)) GB free"
    } -join $nl

    $netAdapters = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE"
    $ipInfo = $netAdapters | ForEach-Object {
        "$($_.Description): $($_.IPAddress -join ', ')"
    } -join $nl

    $summary = ""
    $summary += FormatHeaderLine "System" 60 + $nl
    $summary += "Name: $($cs.Name)$nl"
    $summary += "User: $($cs.UserName)$nl"
    $summary += "Manufacturer: $($cs.Manufacturer)$nl"
    $summary += "Model: $($cs.Model)$nl"
    $summary += "Memory: $memory$nl$nl"

    $summary += FormatHeaderLine "Operating System" 60 + $nl
    $summary += "OS: $($os.Caption)$nl"
    $summary += "Version: $($os.Version)$nl"
    $summary += "Architecture: $($os.OSArchitecture)$nl"
    $summary += "BIOS: $($bios.SMBIOSBIOSVersion)$nl$nl"

    $summary += FormatHeaderLine "Processor" 60 + $nl
    $summary += "CPU: $($cpu.Name)$nl"
    $summary += "Cores: $($cpu.NumberOfCores), Logical: $($cpu.NumberOfLogicalProcessors)$nl$nl"

    $summary += FormatHeaderLine "Disk Info" 60 + $nl
    $summary += "$diskInfo$nl$nl"

    $summary += FormatHeaderLine "Network Info" 60 + $nl
    $summary += "$ipInfo$nl"

    return $summary
}

$form = New-Object Windows.Forms.Form
$form.Text = "System Summary"
$form.Size = New-Object Drawing.Size(720, 520)
$form.StartPosition = "CenterScreen"

$textBox = New-Object Windows.Forms.TextBox
$textBox.Multiline = $true
$textBox.ReadOnly = $true
$textBox.ScrollBars = "Vertical"
$textBox.Dock = "Fill"
$textBox.Font = New-Object Drawing.Font("Consolas", 10)
$textBox.Text = Get-SystemInfoText

$form.Controls.Add($textBox)
$form.ShowDialog()
