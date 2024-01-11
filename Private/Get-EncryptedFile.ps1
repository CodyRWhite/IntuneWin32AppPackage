function Get-EncryptedFile {
    <#
    .SYNOPSIS
        Encrypts the intune source folder that has been compressed. This will return the file encrypted back in a PSObject including encryption data, keys, hash, and digest information. 

        This was dirrived from the following encryption tool used for LOB Apps. 
        https://github.com/microsoft/Intune-PowerShell-SDK/blob/67641ce51259bc8e94d1863086ec2801d4a3fea4/Samples/Apps/UploadLobApp.psm1#L1

    .DESCRIPTION
        Encrypts the intune source folder that has been compressed. This will return the file encrypted back in a PSObject including encryption data, keys, hash, and digest information. 

        This was dirrived from the following encryption tool used for LOB Apps. 
        https://github.com/microsoft/Intune-PowerShell-SDK/blob/67641ce51259bc8e94d1863086ec2801d4a3fea4/Samples/Apps/UploadLobApp.psm1#L1

    .PARAMETER sourceFile
        Input file path in string format.

    .PARAMETER Destination
        This is not implemented yet. I have a feeling larger packages 4GB and larger might run into issues due to RAM limiations. Encrypted data is stored in memory and passed through varaibles before exported to file. 

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
        [string]
        $sourceFile,
        [Parameter()]
        [string]
        $Destination
    )

    $bufferBlockSize = 1024 * 4
    $buffer = New-Object byte[] $bufferBlockSize
    $bytesRead = 0

    try {
        $aes = [System.Security.Cryptography.Aes]::Create()
        $initializationVector = $aes.IV

        $aesProvider = New-Object System.Security.Cryptography.AesCryptoServiceProvider
        $hmacSha256 = New-Object System.Security.Cryptography.HMACSHA256
        $aesProvider.GenerateKey()
        $hmacKey = $aesProvider.Key
        $hmacSha256.Key = $hmacKey
        $hmacLength = $hmacSha256.HashSize / 8

        # Create the stream that we will write to
        $targetStream = New-Object System.IO.MemoryStream

        # Add empty space for the hmac and initialization vector
        $targetStream.Write($buffer, 0, $hmacLength + $initializationVector.Length)

        # Create the Crypto stream
        $aesProvider.GenerateKey()
        $encryptionKey = $aesProvider.Key
        $encryptor = $aes.CreateEncryptor($encryptionKey, $initializationVector)
        $sourceStream = [System.IO.File]::Open($sourceFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        $cryptoStream = New-Object System.Security.Cryptography.CryptoStream -ArgumentList @($targetStream, $encryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)

        # Write encrypted file
        while (($bytesRead = $sourceStream.Read($buffer, 0, $bufferBlockSize)) -gt 0) {
            $cryptoStream.Write($buffer, 0, $bytesRead)
            $cryptoStream.Flush()
        }
        $cryptoStream.FlushFinalBlock()

        # Write initialization vector
        $targetStream.Seek($hmacLength, [System.IO.SeekOrigin]::Begin) | Out-Null
        $targetStream.Write($initializationVector, 0, $initializationVector.Length)
        $targetStream.Seek($hmacLength, [System.IO.SeekOrigin]::Begin) | Out-Null

        # Create HMAC
        $hmac = $hmacSha256.ComputeHash($targetStream)

        # Write HMAC
        $targetStream.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
        $targetStream.Write($hmac, 0, $hmac.Length)

        # Create file digest
        $fileDigestAlgorithm = 'SHA256'
        $fileDigest = (Get-FileHash $sourceFile -Algorithm $fileDigestAlgorithm).Hash
        [byte[]]$fileDigestBytes = New-Object byte[] ($fileDigest.Length / 2) # 2 hexadecimal characters represents 1 byte here
        for ($i = 0; $i -lt $fileDigest.Length; $i += 2) {
            $fileDigestBytes[$i / 2] = [System.Convert]::ToByte($fileDigest.Substring($i, 2), 16)
        }

        # Return encrypted file and encryption info that can be sent to Intune
        $fileBytes = $targetStream.ToArray()
        return @{
            'file' = $fileBytes
            'info' = @{
                #$DecodedText         = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($EncodedText))
                encryptionKey        = [Convert]::ToBase64String($encryptionKey)
                macKey               = [Convert]::ToBase64String($hmacKey)
                initializationVector = [Convert]::ToBase64String($initializationVector)
                mac                  = [Convert]::ToBase64String($hmac)
                profileIdentifier    = 'ProfileVersion1'
                fileDigest           = [Convert]::ToBase64String($fileDigestBytes)
                fileDigestAlgorithm  = $fileDigestAlgorithm
            }
        }
    }
    finally {
        if ($cryptoStream) { $cryptoStream.Dispose() }
        if ($sourceStream) { $sourceStream.Dispose() }
        if ($encryptor) { $encryptor.Dispose() }
        if ($targetStream) { $targetStream.Dispose() }
        if ($aes) { $aes.Dispose() }
    }
}