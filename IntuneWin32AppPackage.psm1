$Private = @(Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -Recurse -ErrorAction SilentlyContinue)
$Public = @(Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -Recurse -ErrorAction SilentlyContinue)

foreach ($Import in @($Public + $Private)) {
    Try { . $Import.FullName }
    Catch { Write-Error -Message "Failed to import function $($Import.FullName): $_" }
}

#Export-ModuleMember -Function $Public.BaseName

#Alias
New-Alias -Name "New-IntuneWin32AppPackageAlt" -Value "New-IntuneWin32AppPackage" -Force -ErrorAction SilentlyContinue
#=================================================
#Export-ModuleMember
Export-ModuleMember -Function $Public.BaseName -Alias *