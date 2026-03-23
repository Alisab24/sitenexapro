# PowerShell script pour ajouter le bouton "Devenir Partenaire"
$content = Get-Content -Path "leadqualif.html" -Raw
$content = $content -replace '<li><a href="#contact">Contact</a></li>', '<li><a href="#contact">Contact</a></li>
          <li><a href="/partner-application-form.html" style="color: var(--blue); font-weight: 600;">🤝 Devenir Partenaire</a></li>'
Set-Content -Path "leadqualif.html" -Value $content
Write-Host "Bouton 'Devenir Partenaire' ajouté avec succès!"
