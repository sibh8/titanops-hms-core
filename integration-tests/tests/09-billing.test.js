/**
 * 09-billing.test.js — Billing Service
 *
 * Cross-service: patient-service + encounter-service → billing-service
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
const INVOICE_URL  = `${SERVICES.billing}/api/invoices`;

describe('Billing Service — cross-service (patient + encounter)', () => {
  let patientId, providerId, encounterId, invoiceId;

  before(async () => {
    const patient = await api.post(PATIENT_URL, {
      firstName: 'Bill', lastName: `Patient_${TS}`, dateOfBirth: '1970-04-01',
      gender: 'Male', phone: '555-0700', email: `bill_p_${TS}@medicore.test`,
    });
    patientId = patient.id;

    const provider = await api.post(PROVIDER_URL, {
      firstName: 'Dr. Bill', lastName: `Provider_${TS}`, speciality: 'General Medicine',
      phone: '555-0701', email: `bill_pr_${TS}@medicore.test`,
      licenseNumber: `BILL-${TS}`, active: true,
    });
    providerId = provider.id;

    const encounter = await api.post(ENC_URL, {
      patientId, providerId, encounterDate: '2026-04-01',
      chiefComplaint: 'Routine visit', diagnosis: 'Healthy',
      treatmentPlan: 'No treatment needed', notes: 'Billing test fixture',
    });
    encounterId = encounter.id;
  });

  after(async () => {
    if (invoiceId)   await api.delete(`${INVOICE_URL}/${invoiceId}`).catch(() => {});
    if (encounterId) await api.delete(`${ENC_URL}/${encounterId}`).catch(() => {});
    if (patientId)   await api.delete(`${PATIENT_URL}/${patientId}`).catch(() => {});
    if (providerId)  await api.delete(`${PROVIDER_URL}/${providerId}`).catch(() => {});
  });

  it('POST /api/invoices — creates an invoice', async () => {
    const body = await api.post(INVOICE_URL, {
      patientId,
      encounterId,
      totalAmount: 250.00,
      amountPaid:  0.00,
      status:      'Pending',
      notes:       'Integration test invoice',
    });
    assert.ok(body.id,                      'Response must include an id');
    assert.equal(body.patientId,  patientId,  'patientId must match');
    assert.equal(body.encounterId, encounterId, 'encounterId must match');
    assert.equal(body.status,     'Pending',    'status must be Pending');
    assert.equal(body.totalAmount, 250.00,      'totalAmount must match');
    invoiceId = body.id;
  });

  it('GET /api/invoices — lists all invoices', async () => {
    const list = await api.get(INVOICE_URL);
    assert.ok(Array.isArray(list), 'Response must be an array');
    assert.ok(list.some(i => i.id === invoiceId), 'Created invoice must appear in list');
  });

  it('GET /api/invoices/:id — retrieves by id', async () => {
    const body = await api.get(`${INVOICE_URL}/${invoiceId}`);
    assert.equal(body.id,          invoiceId, 'id must match');
    assert.equal(body.totalAmount, 250.00,    'totalAmount must match');
  });

  it('GET /api/invoices/patient/:patientId — filters by patient', async () => {
    const list = await api.get(`${INVOICE_URL}/patient/${patientId}`);
    assert.ok(Array.isArray(list), 'Response must be an array');
    assert.ok(list.some(i => i.id === invoiceId), 'Invoice must appear in patient invoices');
    list.forEach(i => assert.equal(i.patientId, patientId, 'All results must belong to the patient'));
  });

  it('PUT /api/invoices/:id — records partial payment', async () => {
    const body = await api.put(`${INVOICE_URL}/${invoiceId}`, {
      patientId, encounterId,
      totalAmount: 250.00,
      amountPaid:  100.00,
      status:      'Partially Paid',
      notes:       'Partial payment received',
    });
    assert.equal(body.amountPaid, 100.00,         'amountPaid must be updated');
    assert.equal(body.status,     'Partially Paid', 'status must be Partially Paid');
  });

  it('DELETE /api/invoices/:id — deletes the invoice', async () => {
    await api.delete(`${INVOICE_URL}/${invoiceId}`);
    invoiceId = null;
  });
});
