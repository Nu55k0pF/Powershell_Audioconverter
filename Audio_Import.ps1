# SET FOLDER TO WATCH + FILES TO WATCH + SUBFOLDERS YES/NO
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = "C:\Users\Johannes Schnurrenbe\Desktop\Test_Links" # adjust as needed
$watcher.Filter = "*.*"
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true  

# helper: wait until file is ready for read (avoids copying partial files)
function Wait-ForFileReady {
    param($Path, $Retries = 10, $DelaySec = 1)
    for ($i = 0; $i -lt $Retries; $i++) {
        try {
            $stream = [System.IO.File]::Open($Path, 'Open', 'Read', 'None')
            $stream.Close()
            return $true
        } catch {
            Start-Sleep -Seconds $DelaySec
        }
    }
    return $false
}

# Logging setup: write all messages to a log file with timestamps
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Get-Location }
$LogFile = Join-Path $ScriptDir "Audio_Import.log" # adjust as needed

function Write-Log {
    param(
        [Parameter(Mandatory=$true)][ValidateSet('INFO','WARN','ERROR','DEBUG')] $Level,
        [Parameter(Mandatory=$true)] [string] $Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    try {
        $entry | Out-File -FilePath $LogFile -Encoding UTF8 -Append
    } catch {
        # If logging fails, fallback to host so user can see an issue
        Write-Host "Logging failed: $_"
    }
}

# DEFINE ACTIONS AFTER AN EVENT IS DETECTED
$action = { 
    $path = $Event.SourceEventArgs.FullPath
    $changeType = $Event.SourceEventArgs.ChangeType
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [INFO] $changeType, $path"
    $entry | Out-File -FilePath $Event.MessageData.LogFile -Encoding UTF8 -Append
    Write-Host "Logged event: $entry"
}

$action2 = { 
		# DESTINATION FOR COPIED MP3 FILES (adjust as needed)
		$DestinationRoot = "C:\Users\Johannes Schnurrenbe\Desktop\Test_Rechts" # adjust as needed
        $infile = $Event.SourceEventArgs.FullPath
        
        $path = $Event.SourceEventArgs.FullPath
        $changeType = $Event.SourceEventArgs.ChangeType
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $entry = "[$timestamp] [INFO] $changeType, $path"
        $entry | Out-File -FilePath $Event.MessageData.LogFile -Encoding UTF8 -Append
        
        $filenameOnly = [System.IO.Path]::GetFileName($infile)
		$nameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($filenameOnly)
        $destFile = Join-Path $DestinationRoot $filenameOnly
        
        $entry = "[$timestamp] [INFO] Attempting copy to: $destFile"
        $entry | Out-File -FilePath $Event.MessageData.LogFile -Encoding UTF8 -Append
	
        try {
            # force terminating error on failure so catch block runs
            Copy-Item -Path $infile -Destination $destFile -Force -ErrorAction Stop
            $entry = "[$timestamp] [INFO] Copied MP3 to: $destFile"
            $entry | Out-File -FilePath $Event.MessageData.LogFile -Encoding UTF8 -Append
        } catch {
            $entry = "[$timestamp] [ERROR] Failed to copy $infile -> $destFile : $($_.Exception.Message)"
            $entry | Out-File -FilePath $Event.MessageData.LogFile -Encoding UTF8 -Append
            return
        }
        # create .txt file next to copied file, content derived from filename
        $txtFile = [System.IO.Path]::ChangeExtension($destFile, ".txt")

        $dateStr = (Get-Date).ToString('dd.MM.yyyy')
        $timeStr = (Get-Date).ToString('HH:mm:ss')
		$Number = "-01"
		$filed1 = $nameWithoutExt + $Number
		$ID = $filed1 -replace '\s', ''    # removes all whitespace from filename
		$entry = "[$timestamp] [DEBUG] $ID"
        $entry | Out-File -FilePath $Event.MessageData.LogFile -Encoding UTF8 -Append
        
        $txtContent = "$ID;BLR;$nameWithoutExt;autoimport $dateStr $timeStr;13;-1;-1;-1"

        try {
            Set-Content -Path $txtFile -Value $txtContent -ErrorAction Stop
            $entry = "[$timestamp] [INFO] Created txt: $txtFile"
            $entry | Out-File -FilePath $Event.MessageData.LogFile -Encoding UTF8 -Append
        } catch {
            $entry = "[$timestamp] [ERROR] Failed to write txt file $txtFile : $($_.Exception.Message)"
            $entry | Out-File -FilePath $Event.MessageData.LogFile -Encoding UTF8 -Append
        }
		# cleanup: delete the original file after successful processing
        try {
            Remove-Item -Path $infile -Force -ErrorAction Stop
        } catch {
            $entry = "[$timestamp] [WARN] Failed to delete original file $infile : $($_.Exception.Message)"
            $entry | Out-File -FilePath $Event.MessageData.LogFile -Encoding UTF8 -Append
        }
		
}

# DECIDE WHICH EVENTS SHOULD BE WATCHED
Register-ObjectEvent $watcher "Created" -Action $action2 -MessageData @{LogFile=$LogFile}
# Register-ObjectEvent $watcher "Changed" -Action $action2
Register-ObjectEvent $watcher "Deleted" -Action $action -MessageData @{LogFile=$LogFile}
# Register-ObjectEvent $watcher "Renamed" -Action $action2

# Keep the script running to process events
Write-Log 'INFO' "Watcher started. Monitoring for events..."
while ($true) { 
    Start-Sleep -Seconds 5
}