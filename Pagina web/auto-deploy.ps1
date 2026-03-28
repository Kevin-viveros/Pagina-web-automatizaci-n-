# ================================================================
#  AutoVentas AI — Auto Deploy a Netlify
#  Corre este script una vez y se actualiza solo al guardar cambios
# ================================================================

# ─── CONFIGURACIÓN ───────────────────────────────────────────────
$NETLIFY_TOKEN  = "PEGA_TU_TOKEN_AQUI"   # <── pega tu token de Netlify
$SITE_ID        = "PEGA_TU_SITE_ID_AQUI" # <── pega tu Site ID de Netlify
$PROJECT_FOLDER = "c:\Users\kv\OneDrive\Antigravyti\Pagina web"
$ZIP_TEMP       = "$env:TEMP\autoventas-deploy.zip"
# ─────────────────────────────────────────────────────────────────

# Validar configuración
if ($NETLIFY_TOKEN -eq "PEGA_TU_TOKEN_AQUI" -or $SITE_ID -eq "PEGA_TU_SITE_ID_AQUI") {
    Write-Host ""
    Write-Host "  ⚠️  Debes configurar tu TOKEN y SITE_ID primero." -ForegroundColor Yellow
    Write-Host "  Abre auto-deploy.ps1 y rellena las 2 variables al inicio." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "  Presiona Enter para cerrar"
    exit
}

function Deploy-ToNetlify {
    Write-Host ""
    Write-Host "  🚀 Detectado cambio — subiendo a Netlify..." -ForegroundColor Cyan

    # Eliminar zip anterior si existe
    if (Test-Path $ZIP_TEMP) { Remove-Item $ZIP_TEMP -Force }

    # Comprimir la carpeta del proyecto (excluir el propio script y el zip)
    $files = Get-ChildItem -Path $PROJECT_FOLDER -Recurse |
             Where-Object { 
                 -not $_.PSIsContainer -and
                 $_.FullName -notlike "*.ps1" -and
                 $_.FullName -notlike "*.zip"
             }

    Compress-Archive -Path $files.FullName -DestinationPath $ZIP_TEMP -Force

    # Subir a Netlify via API
    try {
        $headers = @{
            "Authorization" = "Bearer $NETLIFY_TOKEN"
            "Content-Type"  = "application/zip"
        }

        $zipBytes = [System.IO.File]::ReadAllBytes($ZIP_TEMP)

        $response = Invoke-RestMethod `
            -Uri "https://api.netlify.com/api/v1/sites/$SITE_ID/deploys" `
            -Method POST `
            -Headers $headers `
            -Body $zipBytes `
            -ErrorAction Stop

        Write-Host "  ✅ Deploy exitoso!" -ForegroundColor Green
        Write-Host "  🌐 URL: https://$($response.subdomain).netlify.app" -ForegroundColor Green
        Write-Host "  🕐 $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor DarkGray
    }
    catch {
        Write-Host "  ❌ Error al subir: $_" -ForegroundColor Red
    }
}

# Deploy inicial al arrancar
Write-Host ""
Write-Host "  ================================================" -ForegroundColor DarkCyan
Write-Host "   AutoVentas AI — Auto Deploy activo 🤖" -ForegroundColor Cyan
Write-Host "  ================================================" -ForegroundColor DarkCyan
Write-Host "  📁 Vigilando: $PROJECT_FOLDER" -ForegroundColor Gray
Write-Host "  💡 Guarda cualquier archivo y se sube solo." -ForegroundColor Gray
Write-Host "  🛑 Presiona Ctrl+C para detener." -ForegroundColor Gray
Write-Host ""

Deploy-ToNetlify

# Configurar el FileSystemWatcher (detector de cambios)
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $PROJECT_FOLDER
$watcher.Filter = "*.*"
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

# Debounce: esperar 2 segundos tras el último cambio antes de deployar
$lastDeploy = [DateTime]::MinValue
$debounceSeconds = 2

$action = {
    $changedFile = $Event.SourceEventArgs.Name
    # Ignorar archivos del sistema y el propio script
    if ($changedFile -like "*.ps1" -or $changedFile -like "*.zip" -or $changedFile -like "*.tmp") { return }

    $now = [DateTime]::Now
    $secondsSinceLast = ($now - $script:lastDeploy).TotalSeconds

    if ($secondsSinceLast -gt $using:debounceSeconds) {
        $script:lastDeploy = $now
        Write-Host "  📝 Cambio en: $changedFile" -ForegroundColor DarkYellow
        Start-Sleep -Seconds $using:debounceSeconds
        Deploy-ToNetlify
    }
}

# Registrar eventos de cambio
Register-ObjectEvent $watcher "Changed" -Action $action | Out-Null
Register-ObjectEvent $watcher "Created" -Action $action | Out-Null
Register-ObjectEvent $watcher "Deleted" -Action $action | Out-Null

Write-Host "  ✅ Vigilando cambios... (guarda un archivo para probar)" -ForegroundColor Green
Write-Host ""

# Mantener el script activo
try {
    while ($true) { Start-Sleep -Seconds 1 }
}
finally {
    $watcher.EnableRaisingEvents = $false
    $watcher.Dispose()
    Write-Host ""
    Write-Host "  🛑 Auto Deploy detenido." -ForegroundColor Red
}
