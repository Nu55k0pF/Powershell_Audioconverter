# SET FOLDER TO WATCH + FILES TO WATCH + SUBFOLDERS YES/NO
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = "C:\Users\Johannes Schnurrenbe\Desktop\Test_Links\"
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
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $ScriptDir) { $ScriptDir = Get-Location }
$LogFile = Join-Path $ScriptDir "Audio_Import.log"

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
    Write-Log 'INFO' "$changeType, $path"
}

$action2 = { 
		# DESTINATION FOR COPIED MP3 FILES (adjust as needed)
		$DestinationRoot = "C:\Users\Johannes Schnurrenbe\Desktop\Test_Rechts"
        $infile = $Event.SourceEventArgs.FullPath
        
        $path = $Event.SourceEventArgs.FullPath
        $changeType = $Event.SourceEventArgs.ChangeType
        Write-Log 'INFO' "$changeType, $path"
        $filenameOnly = [System.IO.Path]::GetFileName($infile)
		$nameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($filenameOnly)
        $destFile = Join-Path $DestinationRoot $filenameOnly
        Write-Log 'INFO' "Attempting copy to: $destFile"
	
        try {
            # force terminating error on failure so catch block runs
            Copy-Item -Path $infile -Destination $destFile -Force -ErrorAction Stop
            Write-Log 'INFO' "Copied MP3 to: $destFile"
        } catch {
            Write-Log 'ERROR' "Failed to copy $infile -> $destFile : $($_.Exception.Message)"
            return
        }
        # create .txt file next to copied file, content derived from filename
        $txtFile = [System.IO.Path]::ChangeExtension($destFile, ".txt")

        $dateStr = (Get-Date).ToString('dd.MM.yyyy')
        $timeStr = (Get-Date).ToString('HH:mm:ss')
		$Number = "-01"
		$filed1 = $nameWithoutExt + $Number
		$ID = $filed1 -replace '\s', ''    # removes all whitespace from filename
		Write-Log 'DEBUG' "$ID"
        $txtContent = "$ID;BLR;$nameWithoutExt;autoimport $dateStr $timeStr;13;-1;-1;-1"

        try {
            Set-Content -Path $txtFile -Value $txtContent -ErrorAction Stop
            Write-Log 'INFO' "Created txt: $txtFile"
        } catch {
            Write-Log 'ERROR' "Failed to write txt file $txtFile : $($_.Exception.Message)"
        }
		# cleanup: delete the original file after successful processing
        try {
            Remove-Item -Path $infile -Force -ErrorAction Stop
        } catch {
            Write-Log 'WARN' "Failed to delete original file $infile : $($_.Exception.Message)"
        }
		
}

# DECIDE WHICH EVENTS SHOULD BE WATCHED
Register-ObjectEvent $watcher "Created" -Action $action2
# Register-ObjectEvent $watcher "Changed" -Action $action2
Register-ObjectEvent $watcher "Deleted" -Action $action
# Register-ObjectEvent $watcher "Renamed" -Action $action2

# Endlosschleife, damit das Skript weiterhin läuft
while ($true) { 
    sleep 5
}

# TODO: Add funcionality to decet if in file is .wav and do nothing but create the csv file
# TODO: Add logging