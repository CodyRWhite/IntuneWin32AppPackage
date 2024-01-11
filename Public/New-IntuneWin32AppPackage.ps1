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
        SourceSetupFile = "$SourceFolder\$SourceSetupFile"
        OutputFolder    = $OutputFolder 
    }

    ForEach ($Path in $RequiredPaths.Keys) {
        
        IF (Test-Path -Path $RequiredPaths.$Path) {
            Write-Verbose -Message "Validated $Path path: $($RequiredPaths.$Path)"
        }
        else {

        }
    }     

    $RandomGuid = (New-Guid).Guid
    Write-Verbose -Message "Preparing working environment"
    $SourceFile = Get-Item -Path "$SourceFolder\$SourceSetupFile"
    $WorkingFolder = "$env:TEMP\$RandomGuid"
    $BaseFolder = "$env:TEMP\$RandomGuid\IntuneWinPackage"
    $ContentsFolder = "$env:TEMP\$RandomGuid\IntuneWinPackage\Contents"
    $MetadataFolder = "$env:TEMP\$RandomGuid\IntuneWinPackage\Metadata"

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
    $MsiData = Get-MSIFileInformation -FilePath $SourceFile.FullName

    Switch ($MsiData.ALLUSERS) {
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
        Name                   = $MsiData.ProductName
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
            MsiProductCode                = $MsiData.ProductCode
            MsiProductVersion             = $MsiData.ProductVersion
            MsiPackageCode                = $MsiData.RevisionNumber
            MsiUpgradeCode                = $MsiData.UpgradeCode
            MsiExecutionContext           = $MsiExecutionContext
            MsiRequiresLogon              = $null
            MsiRequiresReboot             = ConvertTo-Bool -item $MsiData.REBOOT
            MsiIsMachineInstall           = ConvertTo-Bool -item $MsiIsMachineInstall
            MsiIsUserInstall              = ConvertTo-Bool -item $MsiIsUserInstall
            MsiIncludesServices           = $null
            MsiIncludesODBCDataSource     = $null
            MsiContainsSystemRegistryKeys = $null
            MsiContainsSystemFolders      = $null
            MsiPublisher                  = $MsiData.Author
        }
    }

    Get-Manifest -SourceFile $SourceFile -MetadataObject $DetectionXML | Out-File -FilePath "$MetadataFolder\Detection.xml"

    Write-Verbose -Message "Compressing and moving intunewin file to output directory"
    Compress-Archive -Path $BaseFolder -DestinationPath "$OutputFolder\IntunePackage.intunewin.zip" -CompressionLevel NoCompression -Force

    if (Test-Path -Path "$OutputFolder\$($SourceFile.BaseName).intunewin") {
        Remove-Item -Path "$OutputFolder\$($SourceFile.BaseName).intunewin" -Force
    }

    Rename-Item "$OutputFolder\IntunePackage.intunewin.zip" -NewName "$($SourceFile.BaseName).intunewin" -Force

    Write-Verbose -Message "Cleaning up working directory"
    Remove-Item -Path $WorkingFolder -Recurse -Force

    return Get-Item -Path "$OutputFolder\$($SourceFile.BaseName).intunewin"
}