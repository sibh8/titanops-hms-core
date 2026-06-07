/**
 * config.js — service base URLs, all configurable via env vars.
 * Defaults point to docker-compose port bindings on localhost.
 */
export const SERVICES = {
  patient:      process.env.PATIENT_URL      ?? 'http://localhost:8081',
  appointment:  process.env.APPOINTMENT_URL  ?? 'http://localhost:8082',
  user:         process.env.USER_URL         ?? 'http://localhost:8083',
  billing:      process.env.BILLING_URL      ?? 'http://localhost:8084',
  encounter:    process.env.ENCOUNTER_URL    ?? 'http://localhost:8085',
  lab:          process.env.LAB_URL          ?? 'http://localhost:8086',
  medication:   process.env.MEDICATION_URL   ?? 'http://localhost:8087',
  prescription: process.env.PRESCRIPTION_URL ?? 'http://localhost:8088',
  provider:     process.env.PROVIDER_URL     ?? 'http://localhost:8089',
};

/** Default request timeout in ms */
export const TIMEOUT_MS = Number(process.env.TEST_TIMEOUT_MS ?? 10_000);
