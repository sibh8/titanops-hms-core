/**
 * 05-encounters.test.js — Encounter Service
 *
 * Cross-service: patient-service + provider-service → encounter-service
 *
 * Tests: create → getAll → getById → getByPatient → update → delete
 */
import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { SERVICES } from '../config.js';
import { api } from '../helpers/client.js';

const TS           = Date.now();
const PATIENT_URL  = `${SERVICES.patient}/api/patients`;
const PROVIDER_URL = `${SERVICES.provider}/api/providers`;
const ENC_URL      = `${SERVICES.encounter}/api/encounters`;

describe('Encounter Service — cross-service (patient + provider)', () => {
  let patientId, providerId, encounterId;

  before(async () => {
    const patient = await api.post(PATIENT_URL, {
      firstName: 'Enc', lastName: `Patient_${TS}`, dateOfBirth: '1975-03-20',
      gender: 'Male', phone: '555-0400', email: `enc_p_${TS}@medicore.test`,
    });
    patientId = patient.id;

    const provider = await api.post(PROVIDER_URL, {
      firstName: 'Dr. Enc', lastName: `Provider_${TS}`, speciality: 'Internal Medicine',
      phone: '555-0401', email: `enc_pr_${TS}@medicore.test`,
      licenseNumber: `ENC-${TS}`, active: true,
    });
    providerId = provider.id;
  });

  after(async () => {
    if (encounterId) await api.delete(`${ENC_URL}/${encounterId}`).catch(() => {});
    if (patientId)   await api.delete(`${PATIENT_URL}/${patientId}`).catch(() => {});
    if (providerId)  await api.delete(`${PROVIDER_URL}/${providerId}`).catch(() => {});
  });

  it('POST /api/encounters — creates an encounter', async () => {
    const body = await api.post(ENC_URL, {
      patientId,
      providerId,
      encounterDate:    '2026-04-01',
      chiefComplaint:   'Headache and fatigue',
      diagnosis:        'Tension headache',
      treatmentPlan:    'Rest and ibuprofen',
      notes:            'Integration test encounter',
    });
    assert.ok(body.id,                     'Response must include an id');
    assert.equal(body.patientId,  patientId,  'patientId must match');
    assert.equal(body.providerId, providerId, 'providerId must match');
    assert.equal(body.diagnosis, 'Tension headache', 'diagnosis must match');
    encounterId = body.id;
  });

  it('GET /api/encounters — lists all encounters', async () => {
    const list = await api.get(ENC_URL);
    assert.ok(Array.isArray(list), 'Response must be an array');
    assert.ok(list.some(e => e.id === encounterId), 'Created encounter must appear in list');
  });

  it('GET /api/encounters/:id — retrieves by id', async () => {
    const body = await api.get(`${ENC_URL}/${encounterId}`);
    assert.equal(body.id,             encounterId,          'id must match');
    assert.equal(body.chiefComplaint, 'Headache and fatigue', 'chiefComplaint must match');
  });

  it('GET /api/encounters/patient/:patientId — filters by patient', async () => {
    const list = await api.get(`${ENC_URL}/patient/${patientId}`);
    assert.ok(Array.isArray(list), 'Response must be an array');
    assert.ok(list.some(e => e.id === encounterId), 'Encounter must appear in patient encounters');
    list.forEach(e => assert.equal(e.patientId, patientId, 'All results must belong to the patient'));
  });

  it('PUT /api/encounters/:id — updates diagnosis', async () => {
    const body = await api.put(`${ENC_URL}/${encounterId}`, {
      patientId, providerId,
      encounterDate:  '2026-04-01',
      chiefComplaint: 'Headache and fatigue',
      diagnosis:      'Migraine',
      treatmentPlan:  'Sumatriptan prescribed',
      notes:          'Updated by integration test',
    });
    assert.equal(body.diagnosis, 'Migraine', 'diagnosis must be updated');
  });

  it('DELETE /api/encounters/:id — deletes the encounter', async () => {
    await api.delete(`${ENC_URL}/${encounterId}`);
    encounterId = null;
  });
});
