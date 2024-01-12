function New-IntuneWin32AppPackage {
    <#
    .SYNOPSIS
        Creates a intunwin encrypted file to be uploaded into intune. 

    .DESCRIPTION
        Creates a intunwin encrypted file to be uploaded into intune. 

    .PARAMETER SourceFolder
        Specifiy the folder where the application is located, everything in this folder will be zipped and included in your package.

    .PARAMETER SourceSetupFile
        Speciify the file name of the primary file you are packaging.

    .PARAMETER OutputFolder
        Specify the folder where you want the intunewin package to be saved, this will overwrite existing files.

    .PARAMETER CatalogFolder
        I created the parameter for this option from the original tool, however I have not used it and not sure what it does as of yet.
        Please post an issue if you would like this added and can help me understand what this does or provide example files. 

    .EXAMPLE
        Minimial output of this command 
        New-IntuneWin32AppPackage -SourceFolder "C:\TestFolder\TestApp" -SourceSetupFile "testapp.msi" -OutputFolder "C:\TestFolder"

        Verbose output of this command
        New-IntuneWin32AppPackage -SourceFolder "C:\TestFolder\TestApp" -SourceSetupFile "testapp.msi" -OutputFolder "C:\TestFolder" -Verbose

    .NOTES
        Author:      Cody White
        Contact:     @CodyRWhite
        Created:     2024-01-11
        Updated:     2024-01-11

        Version history:
        1.0.0 - (2024-01-11) Function created
    #>
    [CmdletBinding()]
    param (        
        [Parameter(Mandatory)]
        [Alias("c")]
        [String]
        $SourceFolder,        
        [Parameter(Mandatory)]
        [Alias("s")]
        [String]
        $SourceSetupFile,        
        [Parameter(Mandatory)]
        [Alias("o")]
        [String]
        $OutputFolder,        
        [Parameter()]
        [Alias("a")]
        [String]
        $CatalogFolder
    )

    Write-Verbose -Message "Validating requirements"
    $RequiredPaths = @{
        SourceFolder    = $SourceFolder
        SourceSetupFile = Join-Path -Path $SourceFolder -ChildPath $SourceSetupFile
        OutputFolder    = $OutputFolder 
    }

    ForEach ($Path in $RequiredPaths.Keys) {
        
        IF (Test-Path -Path $RequiredPaths.$Path) {
            Write-Verbose -Message "Validated $Path path: $($RequiredPaths.$Path)"
        }
        else {
            Write-Error -Message "Error: Invalid parameter $Path." -Category InvalidArgument
        }
    }     

    $RandomGuid = (New-Guid).Guid
    Write-Verbose -Message "Preparing working environment"
    $SourceFile = Get-Item -Path $(Join-Path -Path $SourceFolder -ChildPath $SourceSetupFile)
    $WorkingFolder = Join-Path -Path $env:TEMP -ChildPath $RandomGuid
    $BaseFolder = "$WorkingFolder\IntuneWinPackage"
    $ContentsFolder = "$WorkingFolder\IntuneWinPackage\Contents"
    $MetadataFolder = "$WorkingFolder\IntuneWinPackage\Metadata"

    New-Item -Path $WorkingFolder -ItemType Directory -Force | Out-Null
    New-Item -Path $BaseFolder -ItemType Directory -Force | Out-Null
    New-Item -Path $ContentsFolder -ItemType Directory -Force | Out-Null
    New-Item -Path $MetadataFolder -ItemType Directory -Force | Out-Null

    Write-Verbose -Message "Compressing source folder for encryption process"
    Compress-Archive -Path "$SourceFolder\*" -DestinationPath "$ContentsFolder\IntunePackage.zip" -CompressionLevel Optimal -Force
    # Compress-ArchiveCustom -Path $SourceFolder -DestinationPath "$ContentsFolder\IntunePackage.zip" -CompressionLevel Optimal
    Rename-Item -Path "$ContentsFolder\IntunePackage.zip" -NewName "IntunePackage.intunewin"
    $SourceArchive = Get-Item -Path "$ContentsFolder\IntunePackage.intunewin"

    $UnencryptedContentSize = (Get-Item -Path $SourceArchive | Measure-Object -Property Length -sum).sum

    # Encrypt the file
    Write-Verbose -Message "Encrypting package"
    Write-Host "Encrypting the file '$($SourceArchive.Name)'..." -ForegroundColor Yellow
    $encryptionResult = Get-EncryptedFile -sourceFile $SourceArchive

    Write-Verbose -Message "Writing encrypted package to file"
    [io.file]::WriteAllBytes("$ContentsFolder\IntunePackage.intunewin", $encryptionResult.file)

    Write-Verbose -Message "Generating 'Detection.xml' file"
    IF ($SourceFile.Extension -eq ".msi") {
        $FileData = Get-MSIFileInformation -FilePath $SourceFile.FullName
    }
    else {
        $FileData = Get-FileDetails -FilePath $SourceFile.FullName
    }

    Switch ($FileData.ALLUSERS) {
        "1" {
            $MsiExecutionContext = "System"
            $MsiIsMachineInstall = $true
        }
        "2" {
            $MsiExecutionContext = "Any"
            $MsiIsMachineInstall = $true
            $MsiIsUserInstall = $true 
        }
        Default {
            $MsiExecutionContext = "User"
            $MsiIsUserInstall = $true 
        }
    }

    $DetectionXML = [PSCustomObject]@{
        Name                   = $FileData.ProductName
        UnencryptedContentSize = $UnencryptedContentSize
        FileName               = "IntunePackage.intunewin"
        SetupFile              = $SourceFile.Name
        EncryptionInfo         = [PSCustomObject]@{
            EncryptionKey        = $encryptionResult.info.encryptionKey
            MacKey               = $encryptionResult.info.macKey
            InitializationVector = $encryptionResult.info.initializationVector
            Mac                  = $encryptionResult.info.mac
            ProfileIdentifier    = $encryptionResult.info.profileIdentifier
            FileDigest           = $encryptionResult.info.fileDigest
            FileDigestAlgorithm  = $encryptionResult.info.fileDigestAlgorithm
        }
        MsiInfo                = [PSCustomObject]@{
            MsiProductCode                = $FileData.ProductCode
            MsiProductVersion             = $FileData.ProductVersion
            MsiPackageCode                = $FileData.RevisionNumber
            MsiUpgradeCode                = $FileData.UpgradeCode
            MsiExecutionContext           = $MsiExecutionContext
            MsiRequiresLogon              = $null
            MsiRequiresReboot             = ConvertTo-Bool -item $FileData.REBOOT
            MsiIsMachineInstall           = ConvertTo-Bool -item $MsiIsMachineInstall
            MsiIsUserInstall              = ConvertTo-Bool -item $MsiIsUserInstall
            MsiIncludesServices           = $null
            MsiIncludesODBCDataSource     = $null
            MsiContainsSystemRegistryKeys = $null
            MsiContainsSystemFolders      = $null
            MsiPublisher                  = $FileData.Author
        }
    }

    Get-Manifest -SourceFile $SourceFile -MetadataObject $DetectionXML | Out-File -FilePath "$MetadataFolder\Detection.xml"

    Write-Verbose -Message "Compressing and moving intunewin file to output directory"
    Compress-Archive -Path $BaseFolder -DestinationPath "$OutputFolder\IntunePackage.intunewin.zip" -CompressionLevel NoCompression -Force

    $OutputFile = Join-Path -Path $OutputFolder -ChildPath "$($SourceFile.BaseName).intunewin"

    if (Test-Path -Path $OutputFile) {
        Remove-Item -Path $OutputFile -Force
    }

    Rename-Item "$OutputFolder\IntunePackage.intunewin.zip" -NewName "$($SourceFile.BaseName).intunewin" -Force

    Write-Verbose -Message "Cleaning up working directory"
    Remove-Item -Path $WorkingFolder -Recurse -Force

    return Get-Item -Path $OutputFile
}

Get-ItemProperty -Path C:\WinGet\Putty\putty-64bit-0.79-installer.msi | FL * 