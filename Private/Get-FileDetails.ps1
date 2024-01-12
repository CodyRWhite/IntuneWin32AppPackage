function Get-FileDetails {
    <#
    .SYNOPSIS
        Pulls information from non MSI file that is required for some data in the detection.xml file. 

    .DESCRIPTION
        Pulls information from non MSI file that is required for some data in the detection.xml file. 

    .PARAMETER FilePath
        Provide the file object for the app in question. This is the IO File object not a string. 

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
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo[]]$FilePath
    ) 
    # https://learn.microsoft.com/en-us/windows/win32/msi/installer-opendatabase
 
    $FilePath = "C:\DevOps\Intune\IntuneAppFactory\Templates\Framework\Source\Deploy-Application.exe"
    $IncludeEmptyFields = $false
   
    try {
        $file = Get-ChildItem $FilePath -ErrorAction Stop
    }
    catch {
        Write-Warning "Unable to get file $FilePath $($_.Exception.Message)"
        return
    }
 
    $object = [PSCustomObject][ordered]@{
        FileName     = $file.Name
        FilePath     = $file.FullName
        'Length(MB)' = $file.Length / 1MB
    }

    $objShell = New-Object -ComObject Shell.Application
    $objFolder = $objShell.Namespace($File.Directory.ToString())
    $objFile = $objFolder.ParseName($file.Name)

    if ($null -ne $FieldIDs) {
        $FieldIDs | Sort-Object | Get-Unique | ForEach-Object {
            $FieldValue = $objFolder.GetDetailsOf($objFile, $_) 
            $FieldName = $objFolder.GetDetailsOf($null, $_) -Replace '[^0-9A-Z]', ' '
            $FieldName = (Get-Culture).TextInfo.ToTitleCase($FieldName) -Replace ' '

            if ($FieldName -and $FieldValue) {
                $object | Add-Member -MemberType NoteProperty -Name $FieldName -Value $FieldValue -ErrorAction SilentlyContinue
            }
        }
    }
    else {
        foreach ($id in -1..320) {            
            $FieldValue = $objFolder.GetDetailsOf($objFile, $id)           
            $FieldName = $objFolder.GetDetailsOf($null, $id) -Replace '[^0-9A-Z]', ' '
            $FieldName = (Get-Culture).TextInfo.ToTitleCase($FieldName) -Replace ' '           
            if ($FieldName -and $FieldValue) {
                $object | Add-Member -MemberType NoteProperty -Name $FieldName -Value $FieldValue -ErrorAction SilentlyContinue
            }
        }
    }

    return $object
}