# Script pour corriger partner-program.html
(Get-Content partner-program.html) -replace 'Devenir Partenaire', 'Rejoindre le Programme' | Set-Content partner-program.html
Write-Host "partner-program.html corrigé!"
