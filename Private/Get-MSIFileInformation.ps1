function Get-MSIFileInformation {
    <#
    .SYNOPSIS
        Pulls information from MSI file that is required for the MSI data in the detection.xml file. 

    .DESCRIPTION
        Pulls information from MSI file that is required for the MSI data in the detection.xml file. 

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
    $msiOpenDatabaseModeReadOnly = 0
 
    $summaryInfoHashTable = @{
        1  = 'Codepage'
        2  = 'Title'
        3  = 'Subject'
        4  = 'Author'
        5  = 'Keywords'
        6  = 'Comment'
        7  = 'Template'
        8  = 'LastAuthor'
        9  = 'RevisionNumber'
        10 = 'EditTime'
        11 = 'LastPrinted'
        12 = 'CreationDate'
        13 = 'LastSaved'
        14 = 'PageCount'
        15 = 'WordCount'
        16 = 'CharacterCount'
        18 = 'ApplicationName'
        19 = 'Security'
    }
 
    $properties = @("ProductCode", "ProductVersion", "ProductName", "Manufacturer", "ProductLanguage", "FullVersion", "UpgradeCode", "MSIINSTALLPERUSER", "ALLUSERS", "REBOOT")
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
 
    # Read property from MSI database
    $windowsInstallerObject = New-Object -ComObject WindowsInstaller.Installer
 
    # open read only
    Write-Verbose -Message "Opening MSI database in read only."
    $msiDatabase = $windowsInstallerObject.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $windowsInstallerObject, @($file.FullName, $msiOpenDatabaseModeReadOnly))
 
    foreach ($property in $properties) {
        Write-Verbose -Message "Fetching MSI propery: $Property"
        $view = $null
        $query = "SELECT Value FROM Property WHERE Property = '$($property)'"
        $view = $msiDatabase.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $msiDatabase, ($query))
        $view.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $view, $null)
        $record = $view.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $view, $null)
 
        try {
            $value = $record.GetType().InvokeMember('StringData', 'GetProperty', $null, $record, 1)
        }
        catch {
            Write-Verbose "Unable to get '$property' $($_.Exception.Message)"
            $value = ''
        }
 
        $object | Add-Member -MemberType NoteProperty -Name $property -Value $value
    }
 
    Write-Verbose -Message "Fetching file properties from database"
    $summaryInfo = $msiDatabase.GetType().InvokeMember('SummaryInformation', 'GetProperty', $null, $msiDatabase, $null)
    $summaryInfoPropertiesCount = $summaryInfo.GetType().InvokeMember('PropertyCount', 'GetProperty', $null, $summaryInfo, $null)
 
        (1..$summaryInfoPropertiesCount) | ForEach-Object {
        Write-Verbose -Message "Fetching property $($summaryInfoHashTable[$_])"
        $value = $SummaryInfo.GetType().InvokeMember("Property", "GetProperty", $Null, $SummaryInfo, $_)
 
        if ($null -eq $value) {
            $object | Add-Member -MemberType NoteProperty -Name $summaryInfoHashTable[$_] -Value ''
        }
        else {
            $object | Add-Member -MemberType NoteProperty -Name $summaryInfoHashTable[$_] -Value $value
        }
    }
 
    #$msiDatabase.GetType().InvokeMember('Commit', 'InvokeMethod', $null, $msiDatabase, $null)
    
    Write-Verbose -Message "Closing MSI database file"
    $view.GetType().InvokeMember('Close', 'InvokeMethod', $null, $view, $null)
    # Run garbage collection and release ComObject
    $null = [System.Runtime.Interopservices.Marshal]::ReleaseComObject($windowsInstallerObject) 
    [System.GC]::Collect()
 
    return $object  
}