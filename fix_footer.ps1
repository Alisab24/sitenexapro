# Script pour corriger le footer sur toutes les pages
$pages = @("leadqualif.html", "partner-program.html", "partner-application-form.html", "partner-dashboard.html")

foreach ($page in $pages) {
    if (Test-Path $page) {
        $content = Get-Content -Path $page -Raw
        
        # Ajouter le lien "Réseau Partenarial" juste avant la fermeture du footer
        $pattern = '(<div class="footer-links">.*?<a href="/rgpd.html">RGPD</a>.*?</div>)'
        $replacement = '$1' + "`n        <span class=""footer-sep"">·</span>`n        <a href=""/partner-program.html"">Réseau Partenarial</a>'
        $content = $content -replace $pattern, $replacement
        
        Set-Content -Path $page -Value $content
        Write-Host "Footer corrigé pour: $page"
    }
}

Write-Host "Footer corrigé pour toutes les pages!"
