# Script simple pour corriger les pages
(Get-Content leadqualif.html) -replace 'Devenir Partenaire', 'Rejoindre le Programme' | Set-Content leadqualif.html
Write-Host "leadqualif.html corrigé!"
