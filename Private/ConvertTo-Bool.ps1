function ConvertTo-Bool {
    <#
    .SYNOPSIS
        Converts strings to Bool

    .DESCRIPTION
        Converts strings to Bool

    .PARAMETER item
        Input string to validate.

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
        [Parameter()]
        [string]
        $item
    )
    switch ($item) { 
        { $_ -eq 1 -or $_ -eq "True" } { 
            return $True 
        } 
        default { 
            return $false
        }
    }
}