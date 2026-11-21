# Captures every phase-02 shell screen in light, dark and 200 % text into splitify-artifacts\phase-NN.
# Extend the screen list as later phases add screens. Usage:
#   powershell -File .claude\skills\ui-review\scripts\capture_shell.ps1 -Phase 02
param([string]$Phase = '02')
. "$PSScriptRoot\ui.ps1" -Phase $Phase

function Invoke-Pass([string]$suffix) {
  Start-App
  Save-Shot "welcome-$suffix"
  Invoke-TapLabel 'Get started'; Start-Sleep 2
  Save-Shot "groups-$suffix"
  Invoke-Scroll 1200; Save-Shot "groups-$suffix-2"
  Invoke-TapLabel 'Friends'; Save-Shot "friends-$suffix"
  Invoke-TapLabel 'Activity'; Save-Shot "activity-$suffix"
  Invoke-TapLabel 'Account'; Save-Shot "account-$suffix"
  Invoke-Scroll 1400; Save-Shot "account-$suffix-2"
  Invoke-Scroll -1400; Invoke-Scroll -1400
  Invoke-TapLabel 'Account settings'; Start-Sleep 1; Save-Shot "settings-$suffix"
  Invoke-TapLabel 'Appearance'; Start-Sleep 1; Save-Shot "appearance-$suffix"
}

Set-Dark $false; Set-FontScale 1.0; Invoke-Pass 'light'
Set-Dark $true; Invoke-Pass 'dark'
Set-Dark $false; Set-FontScale 2.0; Invoke-Pass 'text200'
Set-FontScale 1.0
"captured into $script:out"
