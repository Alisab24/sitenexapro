# Script pour optimiser le texte "Partenaire" - éviter répétitions
$content = Get-Content -Path "leadqualif.html" -Raw

# Remplacements pour éviter les répétitions
$content = $content -replace 'Devenir Partenaire', 'Rejoindre le Programme'
$content = $content -replace 'Partenaires', 'Réseau Partenarial'
$content = $content -replace 'Se Connecter', 'Accès Espace'
$content = $content -replace 'Devenir Partenaire', "Rejoindre l'Écosystème"

Set-Content -Path "leadqualif.html" -Value $content
Write-Host "Texte optimisé - Répétitions éliminées!"
