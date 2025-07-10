# SET FOLDER TO WATCH + FILES TO WATCH + SUBFOLDERS YES/NO
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = "G:\ZenonImport"
$watcher.Filter = "*.*"
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true  

# DEFINE ACTIONS AFTER AN EVENT IS DETECTED
$action = { 
    $path = $Event.SourceEventArgs.FullPath
    $changeType = $Event.SourceEventArgs.ChangeType
    Write-Host "$changeType, $path"
}

$action2 = { 
        $infile = $Event.SourceEventArgs.FullPath
        
        $path = $Event.SourceEventArgs.FullPath
        $changeType = $Event.SourceEventArgs.ChangeType
        Write-Host "$changeType, $path"

        if ($infile -match '\.(flac|ogg|m4a|aac|mp2|mp3|mp4)$') {
            $outfile = [System.IO.Path]::ChangeExtension($infile, ".wav")
            $ffmpegCommand = "ffmpeg -y -i `"$infile`" -acodec pcm_s16le -ar 48000 `"$outfile`""
            Invoke-Expression $ffmpegCommand
            Write-Host "Erfolgreich konvertiert: $outfile"
            sleep 2
            Remove-Item $infile -Force

            # CSV-Datei mit gleichem Namen wie infile, aber .csv-Endung
            $csvFile = [System.IO.Path]::ChangeExtension($infile, ".csv")
            $filenameOnly = [System.IO.Path]::GetFileNameWithoutExtension($infile)
            $parts = $filenameOnly -split '-'
            # Schreibe alle Teile in eine Zeile, getrennt durch ";"
            $csvLine = $parts -join ';'
            Set-Content -Path $csvFile -Value $csvLine
        }   

        if ($infile -match '\.(wav)$') {
            $outfile = [System.IO.Path]::ChangeExtension($infile, ".wav")
            $ffmpegCommand = "ffmpeg -y -i `"$infile`" -acodec pcm_s16le -ar 48000 `"$outfile`""
            Invoke-Expression $ffmpegCommand
            Write-Host "Erfolgreich konvertiert: $outfile"

            # CSV-Datei mit gleichem Namen wie infile, aber .csv-Endung
            $csvFile = [System.IO.Path]::ChangeExtension($infile, ".csv")
            $filenameOnly = [System.IO.Path]::GetFileNameWithoutExtension($infile)
            $parts = $filenameOnly -split '-'
            # Schreibe alle Teile in eine Zeile, getrennt durch ";"
            $csvLine = $parts -join ';'
            Set-Content -Path $csvFile -Value $csvLine
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

# TODO: Add logging 