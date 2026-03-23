# Script pour optimiser les boutons et rediriger vers partner-program.html
$content = Get-Content -Path "partner-application-form.html" -Raw

# Remplacer les boutons de soumission par un seul bouton vers partner-program.html
$content = $content -replace '<!-- SUBMIT BUTTONS -->\s*<div style="display: flex; gap: 1rem; margin-top: 1rem;">.*?</div>', '<!-- SUBMIT BUTTON -->\n    <button type="button" class="form-submit" onclick="window.location.href=''https://nexapro.tech/partner-program.html''">\n      <span>🚀 Rejoindre le Programme</span>\n    </button>'

# Optimiser le texte
$content = $content -replace 'Candidater par Email', 'Postuler Maintenant'
$content = $content -replace 'Candidater en Ligne', 'Postuler en Ligne'
$content = $content -replace 'Nouvelle Demande d’Adhésion', 'Nouvelle Candidature'
$content = $content -replace 'Déjà membre', 'Déjà inscrit'
$content = $content -replace 'Espace Membre', 'Accès Partenaire'

Set-Content -Path "partner-application-form.html" -Value $content
Write-Host "Boutons optimisés - Redirection vers partner-program.html!"
