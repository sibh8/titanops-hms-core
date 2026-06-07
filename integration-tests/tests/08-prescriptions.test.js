/**
 * 08-prescriptions.test.js — Prescription Service
 *
 * Cross-service: patient-service + provider-service + medication-service → prescription-service
 *
 * Tests: create → getAll → getById → getByPatient → addItem → getItems →
 *        update → delete
 */
import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { SERVICES } from '../config.js';
import { api } from '../helpers/client.js';

const TS           = Date.now();
const PATIENT_URL  = `${SERVICES.patient}/api/patients`;
const PROVIDER_URL = `${SERVICES.provider}/api/providers`;
const MED_URL      = `${SERVICES.medication}/api/medications`;
const RX_URL       = `${SERVICES.prescription}/api/prescriptions`;

describe('Prescription Service — cross-service (patient + provider + medication)', () => {
  let patientId, providerId, medicationId, prescriptionId;

  before(async () => {
    const patient = await api.post(PATIENT_URL, {
      firstName: 'Rx', lastName: `Patient_${TS}`, dateOfBirth: '1995-11-25',
      gender: 'Female', phone: '555-0600', email: `rx_p_${TS}@medicore.test`,
    });
    patientId = patient.id;

    const provider = await api.post(PROVIDER_URL, {
      firstName: 'Dr. Rx', lastName: `Provider_${TS}`, speciality: 'Pharmacology',
      phone: '555-0601', email: `rx_pr_${TS}@medicore.test`,
      licenseNumber: `RX-${TS}`, active: true,
    });
    providerId = provider.id;

    const medication = await api.post(MED_URL, {
      name: `Amoxicillin_${TS}`, genericName: 'Amoxicillin', dosageForm: 'Capsule',
      strength: '500mg', manufacturer: 'Test Pharma', active: true,
    });
    medicationId = medication.id;
  });

  after(async () => {
    if (prescriptionId) await api.delete(`${RX_URL}/${prescriptionId}`).catch(() => {});
    if (medicationId)   await api.delete(`${MED_URL}/${medicationId}`).catch(() => {});
    if (patientId)      await api.delete(`${PATIENT_URL}/${patientId}`).catch(() => {});
    if (providerId)     await api.delete(`${PROVIDER_URL}/${providerId}`).catch(() => {});
  });

  it('POST /api/prescriptions — creates a prescription', async () => {
    const body = await api.post(RX_URL, {
      patientId,
      providerId,
      prescriptionDate: '2026-04-01',
      notes: 'Integration test prescription',
      status: 'Active',
    });
    assert.ok(body.id,                     'Response must include an id');
    assert.equal(body.patientId,  patientId,  'patientId must match');
    assert.equal(body.providerId, providerId, 'providerId must match');
    prescriptionId = body.id;
  });

  it('GET /api/prescriptions — lists all prescriptions', async () => {
    const list = await api.get(RX_URL);
    assert.ok(Array.isArray(list), 'Response must be an array');
    assert.ok(list.some(rx => rx.id === prescriptionId), 'Created prescription must appear in list');
  });

  it('GET /api/prescriptions/:id — retrieves by id', async () => {
    const body = await api.get(`${RX_URL}/${prescriptionId}`);
    assert.equal(body.id, prescriptionId, 'id must match');
  });

  it('GET /api/prescriptions/patient/:patientId — filters by patient', async () => {
    const list = await api.get(`${RX_URL}/patient/${patientId}`);
    assert.ok(Array.isArray(list), 'Response must be an array');
    assert.ok(list.some(rx => rx.id === prescriptionId), 'Prescription must appear in patient prescriptions');
    list.forEach(rx => assert.equal(rx.patientId, patientId, 'All results must belong to the patient'));
  });

  it('POST /api/prescriptions/:id/items — adds a medication item', async () => {
    const body = await api.post(`${RX_URL}/${prescriptionId}/items`, {
      medicationId,
      dosage:       '1 capsule',
      frequency:    'Three times daily',
      duration:     '7 days',
      instructions: 'Take with food',
    });
    assert.ok(body.id,                          'Item must have an id');
    assert.equal(body.medicationId, medicationId, 'medicationId must match');
    assert.equal(body.frequency, 'Three times daily', 'frequency must match');
  });

  it('GET /api/prescriptions/:id/items — lists prescription items', async () => {
    const list = await api.get(`${RX_URL}/${prescriptionId}/items`);
    assert.ok(Array.isArray(list), 'Response must be an array');
    assert.ok(list.length >= 1,    'Must have at least one item');
    assert.ok(list.some(i => i.medicationId === medicationId), 'Medication must appear in prescription items');
  });

  it('PUT /api/prescriptions/:id — updates notes', async () => {
    const body = await api.put(`${RX_URL}/${prescriptionId}`, {
      patientId, providerId,
      prescriptionDate: '2026-04-01',
      notes: 'Updated by integration test',
      status: 'Active',
    });
    assert.equal(body.notes, 'Updated by integration test', 'notes must be updated');
  });

  it('DELETE /api/prescriptions/:id — deletes the prescription', async () => {
    await api.delete(`${RX_URL}/${prescriptionId}`);
    prescriptionId = null;
  });
});
