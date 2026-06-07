/**
 * healthApi.js
 *
 * Calls each microservice actuator health endpoint via the nginx
 * proxy paths exposed at /health/<service-name>.
 * Returns { status, responseTimeMs } per service.
 */

export const SERVICES = [
  { id: 'patient-service',      label: 'Patient Service',      port: 8081, apiPath: '/api/patients' },
  { id: 'appointment-service',  label: 'Appointment Service',  port: 8082, apiPath: '/api/appointments' },
  { id: 'user-service',         label: 'User Service',         port: 8083, apiPath: '/api/users' },
  { id: 'billing-service',      label: 'Billing Service',      port: 8084, apiPath: '/api/invoices' },
  { id: 'encounter-service',    label: 'Encounter Service',    port: 8085, apiPath: '/api/encounters' },
  { id: 'lab-service',          label: 'Lab Service',          port: 8086, apiPath: '/api/labs/orders' },
  { id: 'medication-service',   label: 'Medication Service',   port: 8087, apiPath: '/api/medications' },
  { id: 'prescription-service', label: 'Prescription Service', port: 8088, apiPath: '/api/prescriptions' },
  { id: 'provider-service',     label: 'Provider Service',     port: 8089, apiPath: '/api/providers' },
];

/**
 * Ping a single service via its actuator health proxy route.
 * Returns { id, status: 'UP'|'DOWN', responseTimeMs, details }.
 */
export async function pingService(service) {
  const start = performance.now();
  try {
    const res = await fetch(`/health/${service.id}`, {
      method: 'GET',
      signal: AbortSignal.timeout(5000),
    });
    const elapsed = Math.round(performance.now() - start);
    if (res.ok) {
      const body = await res.json().catch(() => ({}));
      return {
        id:            service.id,
        status:        body.status || 'UP',
        responseTimeMs: elapsed,
        details:       body.components || {},
      };
    }
    return { id: service.id, status: 'DOWN', responseTimeMs: Math.round(performance.now() - start), details: {} };
  } catch {
    return { id: service.id, status: 'DOWN', responseTimeMs: Math.round(performance.now() - start), details: {} };
  }
}

/** Ping all 9 services in parallel. */
export async function pingAllServices() {
  return Promise.all(SERVICES.map(pingService));
}
