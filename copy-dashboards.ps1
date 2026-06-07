$basePath = "d:\OneDrive - Mastek Limited\WorkArea\Git_Repositories\work\aws-transform\legacy\java-microservices"

# Copy dashboard files
Copy-Item "$basePath\grafana-dashboard-functional.json" "$basePath\grafana\dashboards\functional.json" -Force
Copy-Item "$basePath\grafana-dashboard-operational.json" "$basePath\grafana\dashboards\operational.json" -Force
Copy-Item "$basePath\grafana-dashboard-medicore-hms.json" "$basePath\grafana\dashboards\medicore-hms.json" -Force

Write-Host "✓ All 4 dashboards are now in grafana/dashboards/"
Get-ChildItem "$basePath\grafana\dashboards\*.json" | Format-Table Name, @{Label="Size (KB)";Expression={[math]::Round($_.Length/1KB,2)}}

# Restart Grafana
Write-Host "`nRestarting Grafana to load dashboards..."
Set-Location $basePath
docker-compose restart grafana

Write-Host "`n✓ Setup complete! Dashboards will auto-load after Grafana starts (~20 seconds)"
