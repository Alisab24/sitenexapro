# Script pour supprimer le lien "Réseau Partenarial" du footer
$pages = @("leadqualif.html", "partner-program.html", "partner-application-form.html", "partner-dashboard.html")

foreach ($page in $pages) {
    if (Test-Path $page) {
        $content = Get-Content -Path $page -Raw
        
        # Supprimer le lien "Réseau Partenarial" du footer
        $pattern = '\s*<span class=""footer-sep"">·</span>\s*<a href="/partner-program.html">Réseau Partenarial</a>'
        $content = $content -replace $pattern, ''
        
        Set-Content -Path $page -Value $content
        Write-Host "Lien Réseau Partenarial supprimé de: $page"
    }
}

Write-Host "Lien Réseau Partenarial supprimé de tous les footers!"
