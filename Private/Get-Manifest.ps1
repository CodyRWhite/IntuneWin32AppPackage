function Get-Manifest {
    <#
    .SYNOPSIS
        Converts the application data from PSObject to preformated XML.

    .DESCRIPTION
        Converts the application data from PSObject to preformated XML.

    .PARAMETER SourceFile
        Specify the source file of the app that is being packaged.

    .PARAMETER MetadataObject
        Specify the metadata object where the details about encryption and file information are stored.

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
        [PSCustomObject]
        $SourceFile, 
        [Parameter(Mandatory)]
        [PSCustomObject]
        $MetadataObject
    )
    Switch ($SourceFile.Extension) {
        ".msi" {
            $XML = @"
<ApplicationInfo xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ToolVersion="1.8.5.0">
    <Name>$($MetadataObject.Name)</Name>
    <UnencryptedContentSize>$($MetadataObject.UnencryptedContentSize)</UnencryptedContentSize>
    <FileName>$($MetadataObject.FileName)</FileName>
    <SetupFile>$($MetadataObject.SetupFile)</SetupFile>
    <EncryptionInfo>
        <EncryptionKey>$($MetadataObject.EncryptionInfo.EncryptionKey)</EncryptionKey>
        <MacKey>$($MetadataObject.EncryptionInfo.MacKey)</MacKey>
        <InitializationVector>$($MetadataObject.EncryptionInfo.InitializationVector)</InitializationVector>
        <Mac>$($MetadataObject.EncryptionInfo.Mac)</Mac>
        <ProfileIdentifier>$($MetadataObject.EncryptionInfo.ProfileIdentifier)</ProfileIdentifier>
        <FileDigest>$($MetadataObject.EncryptionInfo.FileDigest)</FileDigest>
        <FileDigestAlgorithm>$($MetadataObject.EncryptionInfo.FileDigestAlgorithm)</FileDigestAlgorithm>
    </EncryptionInfo>
    <MsiInfo>
        <MsiProductCode>$($MetadataObject.MsiInfo.MsiProductCode)</MsiProductCode>
        <MsiProductVersion>$($MetadataObject.MsiInfo.MsiProductVersion)</MsiProductVersion>
        <MsiPackageCode>$($MetadataObject.MsiInfo.MsiPackageCode)</MsiPackageCode>
        <MsiUpgradeCode>$($MetadataObject.MsiInfo.MsiUpgradeCode)</MsiUpgradeCode>
        <MsiExecutionContext>$($MetadataObject.MsiInfo.MsiExecutionContext)</MsiExecutionContext>
        <MsiRequiresLogon>$($MetadataObject.MsiInfo.MsiRequiresLogon)</MsiRequiresLogon>
        <MsiRequiresReboot>$($MetadataObject.MsiInfo.MsiRequiresReboot)</MsiRequiresReboot>
        <MsiIsMachineInstall>$($MetadataObject.MsiInfo.MsiIsMachineInstall)</MsiIsMachineInstall>
        <MsiIsUserInstall>$($MetadataObject.MsiInfo.MsiIsUserInstall)</MsiIsUserInstall>
        <MsiIncludesServices>$($MetadataObject.MsiInfo.MsiIncludesServices)</MsiIncludesServices>
        <MsiIncludesODBCDataSource>$($MetadataObject.MsiInfo.MsiIncludesODBCDataSource)</MsiIncludesODBCDataSource>
        <MsiContainsSystemRegistryKeys>$($MetadataObject.MsiInfo.MsiContainsSystemRegistryKeys)</MsiContainsSystemRegistryKeys>
        <MsiContainsSystemFolders>$($MetadataObject.MsiInfo.MsiContainsSystemFolders)</MsiContainsSystemFolders>
        <MsiPublisher>$($MetadataObject.MsiInfo.MsiPublisher)</MsiPublisher>
    </MsiInfo>
</ApplicationInfo>
"@
        }
        default {
            $XML = @"
<ApplicationInfo xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ToolVersion="1.8.5.0">
    <Name>$($MetadataObject.Name)</Name>
    <UnencryptedContentSize>$($MetadataObject.UnencryptedContentSize)</UnencryptedContentSize>
    <FileName>$($MetadataObject.FileName)</FileName>
    <SetupFile>$($MetadataObject.SetupFile)</SetupFile>
    <EncryptionInfo>
        <EncryptionKey>$($MetadataObject.EncryptionInfo.EncryptionKey)</EncryptionKey>
        <MacKey>$($MetadataObject.EncryptionInfo.MacKey)</MacKey>
        <InitializationVector>$($MetadataObject.EncryptionInfo.InitializationVector)</InitializationVector>
        <Mac>$($MetadataObject.EncryptionInfo.Mac)</Mac>
        <ProfileIdentifier>$($MetadataObject.EncryptionInfo.ProfileIdentifier)</ProfileIdentifier>
        <FileDigest>$($MetadataObject.EncryptionInfo.FileDigest)</FileDigest>
        <FileDigestAlgorithm>$($MetadataObject.EncryptionInfo.FileDigestAlgorithm)</FileDigestAlgorithm>
    </EncryptionInfo>
</ApplicationInfo>
"@
        }
    }
    return $XML
}