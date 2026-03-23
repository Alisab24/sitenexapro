# Script pour corriger partner-dashboard.html
(Get-Content partner-dashboard.html) -replace 'Rejoindre le Programme', 'Accès Dashboard' | Set-Content partner-dashboard.html
Write-Host "partner-dashboard.html corrigé!"
