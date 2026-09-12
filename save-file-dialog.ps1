param(
    [Parameter(Mandatory = $true)][string]$InitialDirectory,
    [string]$FileName = '',
    [ValidateSet('Open', 'Save')][string]$Mode = 'Save',
    [string]$OwnerHandle = '0'
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()
$dialog = if ($Mode -eq 'Open') {
    [System.Windows.Forms.OpenFileDialog]::new()
} else {
    [System.Windows.Forms.SaveFileDialog]::new()
}
$ownerWindow = $null
try {
    $dialog.AutoUpgradeEnabled = $true
    $dialog.Title = if ($Mode -eq 'Open') { 'Open' } else { 'Save As' }
    $dialog.InitialDirectory = $InitialDirectory
    $dialog.FileName = $FileName
    $dialog.Filter = 'All files (*.*)|*.*'
    $dialog.AddExtension = $false
    if ($Mode -eq 'Save') {
        $dialog.OverwritePrompt = $true
    } else {
        $dialog.CheckFileExists = $true
        $dialog.Multiselect = $false
    }
    $dialog.CheckPathExists = $true
    $dialog.RestoreDirectory = $true
    $parsedHandle = 0L
    if ([long]::TryParse($OwnerHandle, [ref]$parsedHandle) -and $parsedHandle -ne 0) {
        $ownerWindow = [System.Windows.Forms.NativeWindow]::new()
        $ownerWindow.AssignHandle([IntPtr]::new($parsedHandle))
        $result = $dialog.ShowDialog($ownerWindow)
    } else {
        $result = $dialog.ShowDialog()
    }
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        [Console]::Write($dialog.FileName)
    } else {
        exit 2
    }
} finally {
    $dialog.Dispose()
    if ($null -ne $ownerWindow) { $ownerWindow.ReleaseHandle() }
}
