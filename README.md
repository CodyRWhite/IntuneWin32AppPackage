# Overview
This module was created to provide means to package your intune Win32Apps without the requirement of the IntuneWin32AppUtil and its buggyness in automation.

Currently the following functions are supported in the module:
- New-IntuneWin32AppPackage

## Installing the module from PSGallery
This is not currently in PSGallery and will need to investigate how to publish this if it becomes popular enough. 

## Module dependencies
None

## Usage
```PowerShell
# Package MSI as .intunewin file
New-IntuneWin32AppPackage -SourceFolder "C:\TestFolder\TestApp" -SourceSetupFile "testapp.msi" -OutputFolder "C:\TestFolder"

# Verbose ouput
New-IntuneWin32AppPackage -SourceFolder "C:\TestFolder\TestApp" -SourceSetupFile "testapp.msi" -OutputFolder "C:\TestFolder" -Verbose

# IntuneWinAppUtil parameters supported
New-IntuneWin32AppPackage -c "C:\TestFolder\TestApp" -s "testapp.msi" -o "C:\TestFolder"
```