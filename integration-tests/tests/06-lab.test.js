/**
 * 06-lab.test.js — Lab Service
 *
 * Cross-service: patient-service + provider-service + encounter-service → lab-service
 *
 * Tests: createOrder → getAll → getPending → getById → getByPatient →
 *        updateOrderStatus → addResult → getResultsByOrder → deleteOrder
 */
import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { SERVICES } from '../config.js';
import { api } from '../helpers/client.js';

const TS           = Date.now();
const PATIENT_URL  = `${SERVICES.patient}/api/patients`;
const PROVIDER_URL = `${SERVICES.provider}/api/providers`;
const ENC_URL      = `${SERVICES.encounter}/api/encounters`;
const ORDERS_URL   = `${SERVICES.lab}/api/lab/orders`;
const RESULTS_URL  = `${SERVICES.lab}/api/lab/results`;

describe('Lab Service — cross-service (patient + provider + encounter)', () => {
  let patientId, providerId, encounterId, orderId;

  before(async () => {
    const patient = await api.post(PATIENT_URL, {
      firstName: 'Lab', lastName: `Patient_${TS}`, dateOfBirth: '1980-07-10',
      gender: 'Female', phone: '555-0500', email: `lab_p_${TS}@medicore.test`,
    });
    patientId = patient.id;

    const provider = await api.post(PROVIDER_URL, {
      firstName: 'Dr. Lab', lastName: `Provider_${TS}`, speciality: 'Pathology',
      phone: '555-0501', email: `lab_pr_${TS}@medicore.test`,
      licenseNumber: `LAB-${TS}`, active: true,
    });
    providerId = provider.id;

    const encounter = await api.post(ENC_URL, {
      patientId, providerId, encounterDate: '2026-04-01',
      chiefComplaint: 'Routine labs', diagnosis: 'Preventive care',
      treatmentPlan: 'Annual blood work', notes: 'Lab test fixture',
    });
    encounterId = encounter.id;
  });

  after(async () => {
    if (orderId)      await api.delete(`${ORDERS_URL}/${orderId}`).catch(() => {});
    if (encounterId)  await api.delete(`${ENC_URL}/${encounterId}`).catch(() => {});
    if (patientId)    await api.delete(`${PATIENT_URL}/${patientId}`).catch(() => {});
    if (providerId)   await api.delete(`${PROVIDER_URL}/${providerId}`).catch(() => {});
  });

  it('POST /api/lab/orders — creates a lab order', async () => {
    const body = await api.post(ORDERS_URL, {
      patientId,
      providerId,
      encounterId,
      testName:    'Complete Blood Count',
      testCode:    `CBC-${TS}`,
      priority:    'Routine',
      status:      'Pending',
      notes:       'Integration test lab order',
    });
    assert.ok(body.id,                    'Response must include an id');
    assert.equal(body.patientId, patientId, 'patientId must match');
    assert.equal(body.status,    'Pending',  'status must be Pending');
    orderId = body.id;
  });

  it('GET /api/lab/orders — lists all orders', async () => {
    const list = await api.get(ORDERS_URL);
    assert.ok(Array.isArray(list), 'Response must be an array');
    assert.ok(list.some(o => o.id === orderId), 'Created order must appear in list');
  });

  it('GET /api/lab/orders/pending — lists pending orders', async () => {
    const list = await api.get(`${ORDERS_URL}/pending`);
    assert.ok(Array.isArray(list), 'Response must be an array');
    assert.ok(list.some(o => o.id === orderId), 'Created order must be in pending list');
    list.forEach(o => assert.equal(o.status, 'Pending', 'All items must have status Pending'));
  });

  it('GET /api/lab/orders/:id — retrieves by id', async () => {
    const body = await api.get(`${ORDERS_URL}/${orderId}`);
    assert.equal(body.id,       orderId,              'id must match');
    assert.equal(body.testName, 'Complete Blood Count', 'testName must match');
  });

  it('GET /api/lab/orders/patient/:patientId — filters by patient', async () => {
    const list = await api.get(`${ORDERS_URL}/patient/${patientId}`);
    assert.ok(Array.isArray(list), 'Response must be an array');
    assert.ok(list.some(o => o.id === orderId), 'Order must appear in patient lab orders');
    list.forEach(o => assert.equal(o.patientId, patientId, 'All results must belong to the patient'));
  });

  it('PUT /api/lab/orders/:id/status — updates status to In Progress', async () => {
    const body = await api.put(`${ORDERS_URL}/${orderId}/status?status=In Progress`);
    assert.equal(body.status, 'In Progress', 'status must be updated to In Progress');
  });

  it('POST /api/lab/results — adds a result to the order', async () => {
    const body = await api.post(RESULTS_URL, {
      orderId,
      resultValue:  '13.5 g/dL',
      referenceRange: '12–16 g/dL',
      unit:         'g/dL',
      interpretation: 'Normal',
      notes:        'Integration test result',
    });
    assert.ok(body.id,                   'Result must have an id');
    assert.equal(body.orderId, orderId,  'orderId must match');
    assert.equal(body.interpretation, 'Normal', 'interpretation must match');
  });

  it('GET /api/lab/results/order/:orderId — retrieves results for the order', async () => {
    const list = await api.get(`${RESULTS_URL}/order/${orderId}`);
    assert.ok(Array.isArray(list),  'Response must be an array');
    assert.ok(list.length >= 1,     'Must have at least one result');
    list.forEach(r => assert.equal(r.orderId, orderId, 'All results must belong to the order'));
  });

  it('DELETE /api/lab/orders/:id — deletes the order', async () => {
    await api.delete(`${ORDERS_URL}/${orderId}`);
    orderId = null;
  });
});
