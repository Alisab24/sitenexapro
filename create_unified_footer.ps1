# Script pour créer un footer unifié pour toutes les pages
$footerContent = @'
      <div class="footer-links">
        <a href="/mentions-legales.html">Mentions légales</a>
        <span class="footer-sep">·</span>
        <a href="/politique-confidentialite.html">Confidentialité</a>
        <span class="footer-sep">·</span>
        <a href="/cgu.html">CGU</a>
        <span class="footer-sep">·</span>
        <a href="/cgv.html">CGV</a>
        <span class="footer-sep">·</span>
        <a href="/rgpd.html">RGPD</a>
        <span class="footer-sep">·</span>
        <a href="/partner-program.html">Réseau Partenarial</a>
      </div>
    </div>
</footer>
'

# Appliquer le footer unifié à toutes les pages principales
$pages = @("leadqualif.html", "partner-program.html", "partner-application-form.html", "partner-dashboard.html")

foreach ($page in $pages) {
    if (Test-Path $page) {
        $content = Get-Content -Path $page -Raw
        
        # Remplacer l'ancien footer par le nouveau
        $pattern = '(?s)<footer>.*?</footer>'
        $content = $content -replace $pattern, $footerContent
        
        Set-Content -Path $page -Value $content
        Write-Host "Footer unifié appliqué à: $page"
    }
}

Write-Host "Footer unifié créé pour toutes les pages!"
