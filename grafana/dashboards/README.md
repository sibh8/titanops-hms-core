# Grafana Dashboards

This directory contains pre-configured Grafana dashboards for the MediCore HMS application that are automatically provisioned when Grafana starts.

## Dashboard Files

1. **business-metrics.json** - MediCore HMS Business Metrics Dashboard
   - Executive summary with KPIs
   - Clinical operations metrics
   - Financial performance tracking
   - Healthcare delivery metrics
   - User activity and security

2. **functional.json** - Functional Dashboard
   - Application performance metrics
   - Request rates and response times
   - Success rates and error tracking
   - HTTP latency percentiles (P50, P95, P99)

3. **operational.json** - Operational Dashboard
   - Infrastructure resource monitoring
   - CPU, memory, and thread usage per service
   - Garbage collection metrics
   - JVM memory pool tracking

4. **medicore-hms.json** - MediCore HMS Main Dashboard
   - Combined overview dashboard
   - Comprehensive microservices monitoring
   - System-wide health metrics

## Auto-Provisioning

These dashboards are automatically loaded into Grafana on startup through the provisioning system configured in:
- `../provisioning/dashboards/dashboard.yml`
- `../provisioning/datasources/datasource.yml`

## Accessing Dashboards

After starting the application with `docker-compose up -d`, access Grafana at:
- **URL**: http://localhost:3001
- **Username**: admin
- **Password**: admin

Navigate to **Dashboards → Browse** to find all three dashboards in the "MediCore HMS" folder.

## Updating Dashboards

To update a dashboard:
1. Edit the JSON file in this directory
2. Restart Grafana: `docker-compose restart grafana`
3. Changes will be reflected within 10 seconds

Alternatively, you can make changes in the Grafana UI since `allowUiUpdates: true` is enabled.
