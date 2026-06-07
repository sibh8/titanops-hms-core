/**
 * 04-appointments.test.js — Appointment Service
 *
 * Proves cross-service data flow:
 *   provider-service → patient-service → appointment-service
 *
 * Tests: create → getAll → getById → getByPatient → getByProvider →
 *        updateStatus → update → delete
 * All fixture data is cleaned up at the end.
 */
import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { SERVICES } from '../config.js';
import { api } from '../helpers/client.js';

const TS          = Date.now();
const PATIENT_URL = `${SERVICES.patient}/api/patients`;
const PROVIDER_URL= `${SERVICES.provider}/api/providers`;
const APPT_URL    = `${SERVICES.appointment}/api/appointments`;

describe('Appointment Service — cross-service (patient + provider)', () => {
  let patientId, providerId, appointmentId;

  before(async () => {
    // Create fixture patient
    const patient = await api.post(PATIENT_URL, {
      firstName: 'Appt', lastName: `Patient_${TS}`, dateOfBirth: '1990-01-01',
      gender: 'Female', phone: '555-0300', email: `appt_p_${TS}@medicore.test`,
    });
    patientId = patient.id;
    // Create fixture provider
    const provider = await api.post(PROVIDER_URL, {
      firstName: 'Dr. Appt', lastName: `Provider_${TS}`, speciality: 'General Medicine',
      phone: '555-0301', email: `appt_pr_${TS}@medicore.test`,
      licenseNumber: `APPT-${TS}`, active: true,
    });
    providerId = provider.id;
  });

  after(async () => {
    if (appointmentId) await api.delete(`${APPT_URL}/${appointmentId}`).catch(() => {});
    if (patientId)     await api.delete(`${PATIENT_URL}/${patientId}`).catch(() => {});
    if (providerId)    await api.delete(`${PROVIDER_URL}/${providerId}`).catch(() => {});
  });

  it('POST /api/appointments — creates an appointment', async () => {
    const body = await api.post(APPT_URL, {
      patientId,
      providerId,
      appointmentDate: '2026-04-01',
      startTime: '09:00',
      endTime:   '09:30',
      reason:    'Integration test checkup',
      status:    'Scheduled',
    });
    assert.ok(body.id,                         'Response must include an id');
    assert.equal(body.patientId,  patientId,  'patientId must match');
    assert.equal(body.providerId, providerId, 'providerId must match');
    assert.equal(body.status,     'Scheduled', 'status must be Scheduled');
    appointmentId = body.id;
  });

  it('GET /api/appointments — lists all appointments', async () => {
    const list = await api.get(APPT_URL);
    assert.ok(Array.isArray(list), 'Response must be an array');
    assert.ok(list.some(a => a.id === appointmentId), 'Created appointment must appear in list');
  });

  it('GET /api/appointments/:id — retrieves by id', async () => {
    const body = await api.get(`${APPT_URL}/${appointmentId}`);
    assert.equal(body.id,     appointmentId, 'id must match');
    assert.equal(body.reason, 'Integration test checkup', 'reason must match');
  });

  it('GET /api/appointments/patient/:patientId — filters by patient', async () => {
    const list = await api.get(`${APPT_URL}/patient/${patientId}`);
    assert.ok(Array.isArray(list), 'Response must be an array');
    assert.ok(list.some(a => a.id === appointmentId), 'Appointment must appear in patient appointments');
    list.forEach(a => assert.equal(a.patientId, patientId, 'All results must belong to the patient'));
  });

  it('GET /api/appointments/provider/:providerId — filters by provider', async () => {
    const list = await api.get(`${APPT_URL}/provider/${providerId}`);
    assert.ok(Array.isArray(list), 'Response must be an array');
    assert.ok(list.some(a => a.id === appointmentId), 'Appointment must appear in provider appointments');
    list.forEach(a => assert.equal(a.providerId, providerId, 'All results must belong to the provider'));
  });

  it('PUT /api/appointments/:id/status — updates status to Completed', async () => {
    const body = await api.put(`${APPT_URL}/${appointmentId}/status?status=Completed`);
    assert.equal(body.status, 'Completed', 'status must be updated to Completed');
  });

  it('PUT /api/appointments/:id — full update', async () => {
    const body = await api.put(`${APPT_URL}/${appointmentId}`, {
      patientId, providerId,
      appointmentDate: '2026-04-01',
      startTime: '10:00', endTime: '10:30',
      reason: 'Updated reason', status: 'Completed',
    });
    assert.equal(body.reason, 'Updated reason', 'reason must be updated');
  });

  it('DELETE /api/appointments/:id — deletes the appointment', async () => {
    await api.delete(`${APPT_URL}/${appointmentId}`);
    appointmentId = null;
  });
});
