# Grafana Configuration

This directory contains Grafana provisioning configuration for the MediCore HMS application.

## Directory Structure

```
grafana/
├── dashboards/              # Dashboard JSON files
│   ├── business-metrics.json
│   ├── functional.json
│   ├── operational.json
│   ├── medicore-hms.json
│   └── README.md
└── provisioning/
    ├── dashboards/          # Dashboard provisioning config
    │   └── dashboard.yml
    └── datasources/         # Datasource provisioning config
        └── datasource.yml
```

## What is Provisioning?

Grafana provisioning allows automatic configuration of:
- **Datasources**: Prometheus connection is auto-configured
- **Dashboards**: All three dashboards are automatically loaded on startup

## How It Works

1. **Datasource Provisioning** (`provisioning/datasources/datasource.yml`)
   - Automatically creates Prometheus datasource
   - Points to `http://prometheus:9090`
   - Sets as default datasource

2. **Dashboard Provisioning** (`provisioning/dashboards/dashboard.yml`)
   - Scans `dashboards/` directory for JSON files
   - Loads them into "MediCore HMS" folder
   - Updates every 10 seconds if files change
   - Allows UI editing with `allowUiUpdates: true`

## Docker Compose Integration

The `docker-compose.yml` mounts these directories:
```yaml
volumes:
  - ./grafana/provisioning:/etc/grafana/provisioning
  - ./grafana/dashboards:/etc/grafana/dashboards
```

## First-Time Setup

No manual configuration needed! Just run:
```bash
docker-compose up -d
```

Access Grafana at http://localhost:3001 (admin/admin) and all dashboards will be available.

## Adding New Dashboards

1. Export dashboard JSON from Grafana UI
2. Place JSON file in `dashboards/` directory
3. Grafana will auto-load it within 10 seconds
4. No restart required!

## Modifying Existing Dashboards

**Option 1: Edit in Grafana UI**
- Make changes in the web interface
- Changes are saved to the JSON files automatically

**Option 2: Edit JSON directly**
- Modify the JSON file in `dashboards/`
- Grafana reloads changes within 10 seconds

## Troubleshooting

**Dashboards not appearing?**
```bash
# Check if files are mounted correctly
docker exec java-microservices-grafana-1 ls /etc/grafana/dashboards/

# Check provisioning logs
docker logs java-microservices-grafana-1 | grep -i provision
```

**Datasource not working?**
```bash
# Verify Prometheus is accessible
docker exec java-microservices-grafana-1 wget -O- http://prometheus:9090/api/v1/status/config
```
