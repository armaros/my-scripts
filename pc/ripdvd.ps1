param (
    [Parameter(Mandatory=$True)]
    [System.String]
    $DiscName,
    [Parameter(Mandatory=$True)]
    [System.Char]
    $Drive,
    [Parameter(Mandatory=$True)]
    [System.String]
    $TargetISODirectory,
    [Parameter(Mandatory=$True)]
    [System.String]
    $TargetMKVDirectory
)
$ErrorActionPreference = "Stop"
Import-Module C:\bin\DiscBackupTools.psm1

$targetISOPath = [System.IO.Path]::Join($TargetISODirectory, ("{0}.iso" -f $DiscName))
$isoProcess = Backup-Disc -SourceDriveLetter $Drive -TargetPath $targetISOPath
$isoProcess.WaitForExit()
If ($isoProcess.ExitCode -ne 0) {
    throw "An error occured when backing up the disc"
}
Send-Complete -Message ("Completed Backup of Disc {0}" -f $DiscName)
$TargetMKVDirectory = [System.IO.Path]::Join($TargetMKVDirectory, $DiscName)
# Start-Sleep -Seconds 120
New-Item $TargetMKVDirectory -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
$mkvProcess = Invoke-MakeMKVFromISO -SourceISO $targetISOPath -TargetDirectory $TargetMKVDirectory
$mkvProcess.WaitForExit()
Send-Complete -Message ("Completed writting MKVs for {0}" -f $DiscName)
