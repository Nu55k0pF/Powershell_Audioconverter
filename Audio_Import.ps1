# SET FOLDER TO WATCH + FILES TO WATCH + SUBFOLDERS YES/NO
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = "G:\KI-Import\"
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

# DEFINE ACTIONS AFTER AN EVENT IS DETECTED
$action = { 
    $path = $Event.SourceEventArgs.FullPath
    $changeType = $Event.SourceEventArgs.ChangeType
    Write-Host "$changeType, $path"
}

$action2 = { 
		# DESTINATION FOR COPIED MP3 FILES (adjust as needed)
		$DestinationRoot = "C:\ProgramData\Zenon-Media\All in One\UniversalImport3\newsIn"
        $infile = $Event.SourceEventArgs.FullPath
        
        $path = $Event.SourceEventArgs.FullPath
        $changeType = $Event.SourceEventArgs.ChangeType
        Write-Host "$changeType, $path"
        $filenameOnly = [System.IO.Path]::GetFileName($infile)
		$nameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($filenameOnly)
        $destFile = Join-Path $DestinationRoot $filenameOnly
        Write-Host "Attempting copy to: $destFile"
	
        try {
            # force terminating error on failure so catch block runs
            Copy-Item -Path $infile -Destination $destFile -Force -ErrorAction Stop
            Write-Host "Copied MP3 to: $destFile"
        } catch {
            Write-Error "Failed to copy $infile -> $destFile : $_"
            return
        }
        # create .txt file next to copied file, content derived from filename
        $txtFile = [System.IO.Path]::ChangeExtension($destFile, ".txt")

        $dateStr = (Get-Date).ToString('dd.MM.yyyy')
        $timeStr = (Get-Date).ToString('HH:mm:ss')
		$Number = "-01"
		$filed1 = $nameWithoutExt + $Number
		$ID = $filed1 -replace '\s', ''    # removes all whitespace from filename
		Write-Host "$ID"
        $txtContent = "$ID;BLR;$nameWithoutExt;autoimport $dateStr $timeStr;13;-1;-1;-1"

        try {
            Set-Content -Path $txtFile -Value $txtContent -ErrorAction Stop
            Write-Host "Created txt: $txtFile"
        } catch {
            Write-Error "Failed to write txt file $txtFile : $_"
        }
		# cleanup: delete the original file after successful processing
        try {
            Remove-Item -Path $infile -Force -ErrorAction Stop
        } catch {
            Write-Warning "Failed to delete original file $infile : $_"
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