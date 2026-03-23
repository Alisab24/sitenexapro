# Script pour corriger partner-application-form.html
(Get-Content partner-application-form.html) -replace 'Rejoindre le Programme', 'Postuler Maintenant' | Set-Content partner-application-form.html
Write-Host "partner-application-form.html corrigé!"
