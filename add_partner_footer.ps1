# Script pour ajouter le lien "Réseau Partenarial" dans tous les footers
$pages = @("leadqualif.html", "partner-program.html", "partner-application-form.html", "partner-dashboard.html")

foreach ($page in $pages) {
    $content = Get-Content -Path $page -Raw
    $pattern = '(<a href="/rgpd.html">RGPD</a>)'
    $replacement = '$1' + '<span class="footer-sep">·</span><a href="/partner-program.html">Réseau Partenarial</a>'
    $content = $content -replace $pattern, $replacement
    Set-Content -Path $page -Value $content
    Write-Host "Lien Réseau Partenarial ajouté à: $page"
}
Write-Host "Tous les footers mis à jour!"
