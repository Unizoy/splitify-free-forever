# Dot-source in every PowerShell session:  . .\tool\env.ps1
# Fixes the empty PATH entries that break flutter.bat and sets JAVA_HOME.
$env:Path = ((([Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
    [Environment]::GetEnvironmentVariable('Path', 'User')) -split ';') |
    Where-Object { $_ -ne '' }) -join ';'

if (-not $env:JAVA_HOME) {
    $jbr = 'C:\Program Files\Android\Android Studio\jbr'
    if (Test-Path $jbr) { $env:JAVA_HOME = $jbr }
}
