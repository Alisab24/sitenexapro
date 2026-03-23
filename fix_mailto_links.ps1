# Script pour corriger les liens mailto qui devraient être des liens normaux
$pages = @("leadqualif.html", "partner-program.html", "partner-application-form.html", "partner-dashboard.html")

foreach ($page in $pages) {
    if (Test-Path $page) {
        $content = Get-Content -Path $page -Raw
        
        # Remplacer les liens mailto vers partner-program.html par des liens normaux
        $content = $content -replace 'href="mailto:contact@nexapro.tech\?subject=Candidature%20Partenaire%20LeadQualif"', 'href="/partner-program.html"'
        
        # Remplacer le lien carrières aussi
        $content = $content -replace 'href="mailto:contact@nexapro.tech\?subject=Candidature%20NexaPro"', 'href="/partner-program.html"'
        
        Set-Content -Path $page -Value $content
        Write-Host "Liens corrigés dans: $page"
    }
}

Write-Host "Tous les liens mailto corrigés!"
