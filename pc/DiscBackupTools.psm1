$script:pushoverURI = 'https://api.pushover.net/1/messages.json'
$script:anyToISOBin = 'C:\Program Files (x86)\AnyToISO\anytoiso.exe'
$script:makeMKVBin = 'C:\Program Files (x86)\MakeMKV\makemkvcon64.exe'
$script:defaultMKVProgressFile = 'C:\temp\mkvprogress.txt'
$script:defaultMKVMessagesFile = 'C:\temp\mkvmessages.txt'
$pushoverUserSecret = Get-AzKeyVaultSecret -VaultName the-plain-black-keys -Name Pushover-UserToken
$pushoverRipperSecret = Get-AzKeyVaultSecret -VaultName the-plain-black-keys -Name Pushover-RipperToken
$script:pushoverUserToken = ConvertFrom-SecureString -SecureString $pushoverUserSecret.SecretValue -AsPlainText
$script:pushoverRipperToken = ConvertFrom-SecureString -SecureString $pushoverRipperSecret.SecretValue -AsPlainText
Out-Host -InputObject $script:pushoverRipperToken
Out-Host -InputObject $script:pushoverUserToken

function Test-UsableFilePath {
    [CmdletBinding()]
    param (
        [System.String]
        $Path,
        [switch]
        $AllowOverwrite
    )
    process {
        $directory = [System.IO.Path]::GetDirectoryName($Path)
        if ($Null-eq $directory) {
            throw "Invalid path [$Path]"
        }
        If (-not (Test-Path $directory)) {
            throw "Directory [$directory] does not exist"
        }
        If (-not $AllowOverwrite -and (Test-Path $Path)) {
            throw "File [$Path] already exists"
        }
        If ($AllowOverwrite -and (Get-Item $Path) -isnot [System.IO.FileInfo]) {
            throw "This is not a file path [$Path]"
        }
        return $True
    }
}

function Get-MKVProgress {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False)]
        [System.String]
        $ProgressFile
    )
    process {
        $ProgressFile = $ProgressFile ?? $script:defaultMKVProgressFile
        $lastLine = Get-Content $ProgressFile | Select-Object -Last 1
        $lastLine -match 'Total progress - (?<progress>\d+)%'
        # Weirdly this actually has the desired behavior in that no match/no content will return 0
        # Match followed by no match will return the last valid match
        return [int]$Matches.progress
    }
}


function Backup-Disc {
   [CmdletBinding()]
   [OutputType([System.Diagnostics.Process])]
   param (
       [ValidateScript({ Get-Volume $_ })]
       [Parameter(Mandatory=$True)]
       [System.Char]$SourceDriveLetter,
       [ValidateScript({ Test-UsableFilePath $_ })]
       [Parameter(Mandatory=$True)]
       [System.String]$TargetPath
   )
   process {
       $volume = Get-Volume $SourceDriveLetter
       $driveParameter = $volume.DriveLetter + ':'
       $quotedTargetPath = "`"{0}`"" -f $targetPath
       return Start-Process -FilePath $script:anyToISOBin -ArgumentList '/fromcd',$driveParameter,$quotedTargetPath -PassThru
   }
}

function Send-Complete {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [System.String]$Message
    )
    $postParams = @{
        token = $script:pushoverRipperToken
        user = $script:pushoverUserToken
        message = $Message
    }
        
    $postParams | Invoke-RestMethod -Uri $script:pushoverURI -Method Post      
}

function Invoke-MakeMKVFromISO {
    [CmdletBinding()]
    [OutputType([System.Diagnostics.Process])]
    param (
        [ValidateScript({(Get-Item $_) -is [System.IO.FileInfo]})]
        [Parameter(Mandatory=$True)]
        [System.String]$SourceISO,
        [Parameter(Mandatory=$True)]
        [ValidateScript({(Get-Item $_) -is [System.IO.DirectoryInfo]})]
        [System.String]$TargetDirectory
    )
    
    process {
        $isoParameter = "iso:`"`{0}`"" -f $SourceISO
        $progressParameter = "" 
        # $progressParameter = "--progress=`"{0}`"" -f $script:defaultMKVProgressFile
        $messagesParameter = ""
        # $messagesParameter = "--messages=`"{0}`"" -f $script:defaultMKVMessagesFile
        $destinationParameter = "`"{0}`"" -f [System.IO.Path]::TrimEndingDirectorySeparator($TargetDirectory)
        return Start-Process -FilePath $script:makeMKVBin -ArgumentList "-r",$progressParameter,$messagesParameter,"--noscan","mkv",$isoParameter,"all",$destinationParameter -PassThru
    }
}
