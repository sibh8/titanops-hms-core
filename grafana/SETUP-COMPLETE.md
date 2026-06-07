# Grafana Dashboard Auto-Loading Setup

## ✓ Setup Complete!

All 4 Grafana dashboards are now configured to automatically load when you start your local environment with `docker-compose up -d`.

## Dashboard Files

The following dashboards are located in `grafana/dashboards/`:

1. **business-metrics.json** (30 KB)
   - Executive Summary with key KPIs
   - Clinical Operations metrics (patient registrations, appointments)
   - Financial Performance (revenue, invoices, collections)
   - Healthcare Delivery (prescriptions, lab orders)
   - User Activity & Security (login analytics)

2. **functional.json** (22 KB)
   - HTTP & API Performance metrics
   - Request rates and response times
   - Error tracking (4xx, 5xx errors)
   - Database performance monitoring

3. **operational.json** (33 KB)  
   - System Overview (CPU, Memory, Threads)
   - Per-Service resource usage
   - JVM Garbage Collection metrics
   - Memory pool monitoring
   - Service Health Status

4. **medicore-hms.json** (31 KB)
   - Comprehensive microservices monitoring
   - Request rates and latency
   - Database query performance
   - JVM metrics by service

##  How It Works

### Auto-Provisioning Configuration

1. **Volume Mounts** (docker-compose.yml):
   ```yaml
   grafana:
     volumes:
       - ./grafana/provisioning:/etc/grafana/provisioning
       - ./grafana/dashboards:/etc/grafana/dashboards
   ```

2. **Provisioning Config** (grafana/provisioning/dashboards/dashboard.yml):
   ```yaml
   providers:
     - name: 'MediCore HMS Dashboards'
       type: file
       updateIntervalSeconds: 10
       options:
         path: /etc/grafana/dashboards
         folder: 'MediCore HMS'
   ```

3. **Datasource Config** (grafana/provisioning/datasources/datasource.yml):
   - Prometheus datasource (UID: ffgk2n76hlq0wf)
   - Auto-configured at http://prometheus:9090

## Usage Instructions

### Starting Your Local Environment

```powershell
# Clean start (recommended)
docker-compose down
docker-compose up -d
```

Wait approximately 20-30 seconds for Grafana to fully initialize and load the dashboards.

### Accessing Grafana

**URL**: http://localhost:3001

**Credentials**:
- Username: `admin`
- Password: `admin` (configured in `.sandbox.env` as `GRAFANA_ADMIN_PASSWORD`)

### Finding Your Dashboards

1. Open http://localhost:3001 in your browser
2. Login with admin/admin
3. Navigate to **Dashboards → Browse**
4. Look for the **"MediCore HMS"** folder
5. All 4 dashboards will be listed there

## Dashboard Details

### 1. Business Metrics Dashboard
- **Purpose**: Executive overview of healthcare operations
- **Key Panels**:
  - Total Patients, Active Appointments, Total Revenue
  - Patient Registration Trends
  - Appointment Activity (Bookings, Completions, Cancellations, No-Shows)
  - Lab Order Activity
  - Invoice Activity & Collection Rate
  - Prescription Volume
  - User Login Analytics
- **Refresh Rate**: 30 seconds
- **UID**: medicore-business

### 2. Functional Dashboard
- **Purpose**: Application performance monitoring
- **Key Panels**:
  - HTTP Request Rate by Service
  - Average Response Time
  - Response Time Percentiles (P50, P95, P99)
  - Overall Success Rate
  - 5xx and 4xx Error Rates
  - Database Activity
- **Refresh Rate**: 10 seconds
- **UID**: medicore-functional

### 3. Operational Dashboard
- **Purpose**: Infrastructure and resource monitoring
- **Key Panels**:
  - Total CPU Usage (Avg across all services)
  - Total Heap Memory Usage %
  - Total Active Threads
  - CPU Usage per Service
  - Heap Memory Usage per Service
  - Thread Count per Service
  - GC Duration and Frequency
  - Memory Pool Usage
  - Service Health Status
- **Refresh Rate**: 10 seconds
- **UID**: medicore-operational

### 4. MediCore HMS Dashboard
- **Purpose**: Comprehensive microservices monitoring
- **Key Panels**:
  - HTTP Request Rate and Response Time
  - 5xx and 4xx Error Rates
  - JVM Heap Memory Usage
  - JVM Garbage Collection Duration
  - JVM Thread Count
  - JVM Classes Loaded
  - Database Query Duration and Operations Rate
  - Heap Memory Usage % Gauge
  - Service Health Status
  - Total Requests per Minute
  - P95 Response Time
- **Refresh Rate**: 5 seconds
- **UID**: medicore-hms-dashboard

## Custom Metrics Availability

Note: The custom business metrics (e.g., `medicore_patient_registrations_total`, `medicore_appointment_bookings_total`, etc.) will NOT show data until you:

1. **Rebuild the services** with Maven to include the Micrometer dependencies:
   ```powershell
   mvn clean package -DskipTests
   ```

2. **Rebuild Docker images** to use the updated JAR files:
   ```powershell
   docker-compose build
   ```

3. **Restart the full stack**:
   ```powershell
   docker-compose down
   docker-compose up -d
   ```

4. **Generate test data** by using the application (register patients, create appointments, etc.)

Until then, the Business Metrics Dashboard panels will show "No data" or empty charts. The Functional and Operational dashboards will show data from OpenTelemetry metrics which are already being collected.

## Troubleshooting

### Dashboards Not Appearing

1. **Check Grafana logs**:
   ```powershell
   docker logs java-microservices-grafana-1 --tail=100
   ```

2. **Verify files are mounted**:
   ```powershell
   docker exec java-microservices-grafana-1 ls -lh /etc/grafana/dashboards/
   ```
   Should show all 4 JSON files.

3. **Check provisioning config**:
   ```powershell
   docker exec java-microservices-grafana-1 cat /etc/grafana/provisioning/dashboards/dashboard.yml
   ```

4. **Recreate Grafana container**:
   ```powershell
   docker stop java-microservices-grafana-1
   docker rm java-microservices-grafana-1
   docker-compose up -d grafana
   ```

### Login Issues

- Default password is `admin` (configured in `.sandbox.env`)
- If you changed it and forgot, recreate the container
- Check `docker-compose.yml` for `GF_SECURITY_ADMIN_PASSWORD` environment variable

### Dashboards Show "No Data"

- **OpenTelemetry metrics** (JVM, HTTP, DB): Should work immediately
- **Custom business metrics** (medicore_*): Require service rebuild (see "Custom Metrics Availability" above)
- **Verify Prometheus is scraping**: http://localhost:9090/targets
- **Query metrics directly in Prometheus**: http://localhost:9090/graph

## File Structure

```
grafana/
├── provisioning/
│   ├── datasources/
│   │   └── datasource.yml          # Prometheus datasource config
│   └── dashboards/
│       └── dashboard.yml            # Dashboard auto-load config
├── dashboards/
│   ├── business-metrics.json        # Business KPIs dashboard
│   ├── functional.json              # Application performance
│   ├── operational.json             # Infrastructure resources
│   ├── medicore-hms.json           # Microservices overview
│   └── README.md                    # Dashboard documentation
└── README.md                        # This file
```

## Next Steps

1. ✅ Dashboards are configured (DONE)
2. ⏳ Rebuild services with Micrometer dependencies
3. ⏳ Rebuild Docker images
4. ⏳ Restart the full stack
5. ⏳ Generate test data to see metrics in action

---

**Last updated**: 2026-03-20
**Grafana version**: 12.4.1
**Dashboard count**: 4
**Auto-provisioning**: ✓ Enabled
