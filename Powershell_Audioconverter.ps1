# SET FOLDER TO WATCH + FILES TO WATCH + SUBFOLDERS YES/NO
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = "C:\Users\Johannes Schnurrenbe\Desktop\Test_Links" # adjust as needed
$watcher.Filter = "*.*"
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true  

# Logging setup: write all messages to a log file with timestamps
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Get-Location }
$LogFile = Join-Path $ScriptDir "Powershell_Audioconverter.log"

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
        $infile = $Event.SourceEventArgs.FullPath
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        $path = $Event.SourceEventArgs.FullPath
        $changeType = $Event.SourceEventArgs.ChangeType
        
        $entry = "[$timestamp] [INFO] $changeType, $path"
        $entry | Out-File -FilePath $Event.MessageData.LogFile -Encoding UTF8 -Append
        Write-Host "$changeType, $path"

        if ($infile -match '\.(flac|ogg|m4a|aac|mp2|mp3|mp4)$') {
            $outfile = [System.IO.Path]::ChangeExtension($infile, ".wav")
            $entry = "[$timestamp] [INFO] Converting $infile to $outfile"
            $entry | Out-File -FilePath $Event.MessageData.LogFile -Encoding UTF8 -Append
            
            $ffmpegCommand = "ffmpeg -y -i `"$infile`" -acodec pcm_s16le -ar 48000 `"$outfile`""
            Invoke-Expression $ffmpegCommand
            
            $entry = "[$timestamp] [INFO] Erfolgreich konvertiert: $outfile"
            $entry | Out-File -FilePath $Event.MessageData.LogFile -Encoding UTF8 -Append
            Write-Host "Erfolgreich konvertiert: $outfile"
            sleep 2
            
            try {
                Remove-Item $infile -Force
                $entry = "[$timestamp] [INFO] Deleted original file: $infile"
                $entry | Out-File -FilePath $Event.MessageData.LogFile -Encoding UTF8 -Append
            } catch {
                $entry = "[$timestamp] [ERROR] Failed to delete $infile : $($_.Exception.Message)"
                $entry | Out-File -FilePath $Event.MessageData.LogFile -Encoding UTF8 -Append
            }

            # CSV-Datei mit gleichem Namen wie infile, aber .csv-Endung
            $csvFile = [System.IO.Path]::ChangeExtension($infile, ".csv")
            $filenameOnly = [System.IO.Path]::GetFileNameWithoutExtension($infile)
            $parts = $filenameOnly -split '-'
            # Schreibe alle Teile in eine Zeile, getrennt durch ";"
            $csvLine = $parts -join ';'
            try {
                Set-Content -Path $csvFile -Value $csvLine
                $entry = "[$timestamp] [INFO] Created CSV file: $csvFile"
                $entry | Out-File -FilePath $Event.MessageData.LogFile -Encoding UTF8 -Append
            } catch {
                $entry = "[$timestamp] [ERROR] Failed to create CSV $csvFile : $($_.Exception.Message)"
                $entry | Out-File -FilePath $Event.MessageData.LogFile -Encoding UTF8 -Append
            }
        }   

        if ($infile -match '\.(wav)$') {
            $outfile = [System.IO.Path]::ChangeExtension($infile, ".wav")
            $entry = "[$timestamp] [INFO] Processing WAV file: $infile"
            $entry | Out-File -FilePath $Event.MessageData.LogFile -Encoding UTF8 -Append
            
            $ffmpegCommand = "ffmpeg -y -i `"$infile`" -acodec pcm_s16le -ar 48000 `"$outfile`""
            Invoke-Expression $ffmpegCommand
            
            $entry = "[$timestamp] [INFO] Erfolgreich konvertiert: $outfile"
            $entry | Out-File -FilePath $Event.MessageData.LogFile -Encoding UTF8 -Append
            Write-Host "Erfolgreich konvertiert: $outfile"

            # CSV-Datei mit gleichem Namen wie infile, aber .csv-Endung
            $csvFile = [System.IO.Path]::ChangeExtension($infile, ".csv")
            $filenameOnly = [System.IO.Path]::GetFileNameWithoutExtension($infile)
            $parts = $filenameOnly -split '-'
            # Schreibe alle Teile in eine Zeile, getrennt durch ";"
            $csvLine = $parts -join ';'
            try {
                Set-Content -Path $csvFile -Value $csvLine
                $entry = "[$timestamp] [INFO] Created CSV file: $csvFile"
                $entry | Out-File -FilePath $Event.MessageData.LogFile -Encoding UTF8 -Append
            } catch {
                $entry = "[$timestamp] [ERROR] Failed to create CSV $csvFile : $($_.Exception.Message)"
                $entry | Out-File -FilePath $Event.MessageData.LogFile -Encoding UTF8 -Append
            }
        }   
}

# DECIDE WHICH EVENTS SHOULD BE WATCHED
Register-ObjectEvent $watcher "Created" -Action $action2 -MessageData @{LogFile=$LogFile}
# Register-ObjectEvent $watcher "Changed" -Action $action2
Register-ObjectEvent $watcher "Deleted" -Action $action -MessageData @{LogFile=$LogFile}
# Register-ObjectEvent $watcher "Renamed" -Action $action2

# Endlosschleife, damit das Skript weiterhin läuft
Write-Log 'INFO' "Audio Converter Watcher started. Monitoring for events..."
while ($true) { 
    sleep 5
} 

#TODO: Merge to Master and Rollout to Production