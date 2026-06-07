/**
 * 10-cross-service.test.js — Holistic Clinical Workflow
 *
 * Proves that ALL 9 microservices interact correctly through a single
 * end-to-end clinical journey:
 *
 *   1.  Create a Provider                      → provider-service
 *   2.  Create a Patient                       → patient-service
 *   3.  Schedule an Appointment                → appointment-service  (links patient + provider)
 *   4.  Complete the Appointment               → appointment-service  (status update)
 *   5.  Create an Encounter                    → encounter-service    (links patient + provider)
 *   6.  Order a Lab Test                       → lab-service          (links patient + encounter)
 *   7.  Record the Lab Result                  → lab-service
 *   8.  Complete the Lab Order                 → lab-service          (status update)
 *   9.  Create a Medication                    → medication-service
 *   10. Create a Prescription                  → prescription-service (links patient + provider)
 *   11. Add Medication to Prescription         → prescription-service (links medication)
 *   12. Create an Invoice                      → billing-service      (links patient + encounter)
 *   13. Mark Invoice as Paid                   → billing-service
 *   14. Create a User (clinical staff)         → user-service
 *   15. Assert cross-service data consistency  → GET each resource and verify foreign keys
 *
 *   Cleanup: deletes all created resources in reverse order.
 */
import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { SERVICES } from '../config.js';
import { api } from '../helpers/client.js';

const TS = Date.now();

const S = {
  patient:      `${SERVICES.patient}/api/patients`,
  provider:     `${SERVICES.provider}/api/providers`,
  appointment:  `${SERVICES.appointment}/api/appointments`,
  encounter:    `${SERVICES.encounter}/api/encounters`,
  lab_orders:   `${SERVICES.lab}/api/lab/orders`,
  lab_results:  `${SERVICES.lab}/api/lab/results`,
  medication:   `${SERVICES.medication}/api/medications`,
  prescription: `${SERVICES.prescription}/api/prescriptions`,
  invoice:      `${SERVICES.billing}/api/invoices`,
  user:         `${SERVICES.user}/api/users`,
};

// IDs accumulated during the workflow; cleaned up in after()
const ctx = {};

describe('Cross-service holistic clinical workflow — all 9 services', () => {

  after(async () => {
    // delete in reverse creation order to satisfy any FK constraints
    const del = (url, id) => id ? api.delete(`${url}/${id}`).catch(() => {}) : Promise.resolve();
    await del(S.user,         ctx.userId);
    await del(S.invoice,      ctx.invoiceId);
    await del(S.prescription, ctx.prescriptionId);
    await del(S.medication,   ctx.medicationId);
    await del(S.lab_orders,   ctx.orderId);
    await del(S.encounter,    ctx.encounterId);
    await del(S.appointment,  ctx.appointmentId);
    await del(S.patient,      ctx.patientId);
    await del(S.provider,     ctx.providerId);
  });

  // ── Step 1: Provider ──────────────────────────────────────────────────────
  it('Step 1 — provider-service: create provider', async () => {
    const body = await api.post(S.provider, {
      firstName: 'Dr. Holistic', lastName: `Provider_${TS}`,
      speciality: 'General Medicine', phone: '555-1000',
      email: `holistic_pr_${TS}@medicore.test`,
      licenseNumber: `HOL-${TS}`, active: true,
    });
    assert.ok(body.id, 'Provider must have an id');
    ctx.providerId = body.id;
  });

  // ── Step 2: Patient ───────────────────────────────────────────────────────
  it('Step 2 — patient-service: create patient', async () => {
    const body = await api.post(S.patient, {
      firstName: 'Holistic', lastName: `Patient_${TS}`, dateOfBirth: '1985-08-20',
      gender: 'Male', phone: '555-1001', email: `holistic_p_${TS}@medicore.test`,
      bloodGroup: 'O+', address: '1 Integration Way',
    });
    assert.ok(body.id, 'Patient must have an id');
    ctx.patientId = body.id;
  });

  // ── Step 3: Appointment ───────────────────────────────────────────────────
  it('Step 3 — appointment-service: schedule appointment (links patient + provider)', async () => {
    const body = await api.post(S.appointment, {
      patientId:       ctx.patientId,
      providerId:      ctx.providerId,
      appointmentDate: '2026-05-01',
      startTime:       '08:00',
      endTime:         '08:30',
      reason:          'Annual checkup',
      status:          'Scheduled',
    });
    assert.ok(body.id,                          'Appointment must have an id');
    assert.equal(body.patientId,  ctx.patientId,  'Appointment must reference correct patient');
    assert.equal(body.providerId, ctx.providerId, 'Appointment must reference correct provider');
    ctx.appointmentId = body.id;
  });

  // ── Step 4: Complete appointment ──────────────────────────────────────────
  it('Step 4 — appointment-service: mark appointment Completed', async () => {
    const body = await api.put(`${S.appointment}/${ctx.appointmentId}/status?status=Completed`);
    assert.equal(body.status, 'Completed', 'Appointment status must be Completed');
  });

  // ── Step 5: Encounter ─────────────────────────────────────────────────────
  it('Step 5 — encounter-service: create encounter (links patient + provider)', async () => {
    const body = await api.post(S.encounter, {
      patientId:      ctx.patientId,
      providerId:     ctx.providerId,
      encounterDate:  '2026-05-01',
      chiefComplaint: 'Annual checkup follow-up',
      diagnosis:      'Hypertension stage 1',
      treatmentPlan:  'Lifestyle changes + medication',
      notes:          'Holistic workflow test',
    });
    assert.ok(body.id, 'Encounter must have an id');
    assert.equal(body.patientId,  ctx.patientId,  'Encounter must reference correct patient');
    assert.equal(body.providerId, ctx.providerId, 'Encounter must reference correct provider');
    ctx.encounterId = body.id;
  });

  // ── Step 6: Lab order ─────────────────────────────────────────────────────
  it('Step 6 — lab-service: create lab order (links patient + encounter)', async () => {
    const body = await api.post(S.lab_orders, {
      patientId:   ctx.patientId,
      providerId:  ctx.providerId,
      encounterId: ctx.encounterId,
      testName:    'Basic Metabolic Panel',
      testCode:    `BMP-${TS}`,
      priority:    'Routine',
      status:      'Pending',
      notes:       'Holistic workflow lab order',
    });
    assert.ok(body.id, 'Lab order must have an id');
    assert.equal(body.patientId,   ctx.patientId,   'Lab order must reference correct patient');
    assert.equal(body.encounterId, ctx.encounterId, 'Lab order must reference correct encounter');
    ctx.orderId = body.id;
  });

  // ── Step 7: Lab result ────────────────────────────────────────────────────
  it('Step 7 — lab-service: record lab result', async () => {
    const body = await api.post(S.lab_results, {
      orderId:        ctx.orderId,
      resultValue:    'Sodium 138 mEq/L, Potassium 4.1 mEq/L',
      referenceRange: 'Na: 136–145, K: 3.5–5.0',
      unit:           'mEq/L',
      interpretation: 'Normal',
      notes:          'All values within range',
    });
    assert.ok(body.id, 'Lab result must have an id');
    assert.equal(body.orderId, ctx.orderId, 'Result must be linked to correct order');
    ctx.resultId = body.id;
  });

  // ── Step 8: Complete lab order ────────────────────────────────────────────
  it('Step 8 — lab-service: mark lab order Completed', async () => {
    const body = await api.put(`${S.lab_orders}/${ctx.orderId}/status?status=Completed`);
    assert.equal(body.status, 'Completed', 'Lab order status must be Completed');
  });

  // ── Step 9: Medication ────────────────────────────────────────────────────
  it('Step 9 — medication-service: create medication', async () => {
    const body = await api.post(S.medication, {
      name:         `Lisinopril_${TS}`,
      genericName:  'Lisinopril',
      dosageForm:   'Tablet',
      strength:     '10mg',
      manufacturer: 'Integration Pharma',
      active:       true,
    });
    assert.ok(body.id, 'Medication must have an id');
    assert.equal(body.genericName, 'Lisinopril', 'genericName must match');
    ctx.medicationId = body.id;
  });

  // ── Step 10: Prescription ─────────────────────────────────────────────────
  it('Step 10 — prescription-service: create prescription (links patient + provider)', async () => {
    const body = await api.post(S.prescription, {
      patientId:        ctx.patientId,
      providerId:       ctx.providerId,
      prescriptionDate: '2026-05-01',
      notes:            'For hypertension management',
      status:           'Active',
    });
    assert.ok(body.id, 'Prescription must have an id');
    assert.equal(body.patientId,  ctx.patientId,  'Prescription must reference correct patient');
    assert.equal(body.providerId, ctx.providerId, 'Prescription must reference correct provider');
    ctx.prescriptionId = body.id;
  });

  // ── Step 11: Prescription item ────────────────────────────────────────────
  it('Step 11 — prescription-service: add medication item (links medication)', async () => {
    const body = await api.post(`${S.prescription}/${ctx.prescriptionId}/items`, {
      medicationId: ctx.medicationId,
      dosage:       '1 tablet',
      frequency:    'Once daily',
      duration:     '90 days',
      instructions: 'Take in the morning with water',
    });
    assert.ok(body.id, 'Prescription item must have an id');
    assert.equal(body.medicationId, ctx.medicationId, 'Item must reference correct medication');
  });

  // ── Step 12: Invoice ──────────────────────────────────────────────────────
  it('Step 12 — billing-service: create invoice (links patient + encounter)', async () => {
    const body = await api.post(S.invoice, {
      patientId:   ctx.patientId,
      encounterId: ctx.encounterId,
      totalAmount: 400.00,
      amountPaid:  0.00,
      status:      'Pending',
      notes:       'Consultation + lab fee',
    });
    assert.ok(body.id, 'Invoice must have an id');
    assert.equal(body.patientId,   ctx.patientId,   'Invoice must reference correct patient');
    assert.equal(body.encounterId, ctx.encounterId, 'Invoice must reference correct encounter');
    assert.equal(body.status,      'Pending',        'Invoice status must be Pending');
    ctx.invoiceId = body.id;
  });

  // ── Step 13: Pay invoice ──────────────────────────────────────────────────
  it('Step 13 — billing-service: mark invoice Paid', async () => {
    const body = await api.put(`${S.invoice}/${ctx.invoiceId}`, {
      patientId: ctx.patientId, encounterId: ctx.encounterId,
      totalAmount: 400.00, amountPaid: 400.00,
      status: 'Paid', notes: 'Payment received in full',
    });
    assert.equal(body.status,     'Paid',   'Invoice status must be Paid');
    assert.equal(body.amountPaid, 400.00,   'amountPaid must be 400.00');
  });

  // ── Step 14: Create user ──────────────────────────────────────────────────
  it('Step 14 — user-service: create clinical staff user', async () => {
    const body = await api.post(S.user, {
      username:  `staff_${TS}`,
      password:  'Staff@1234',
      email:     `staff_${TS}@medicore.test`,
      firstName: 'Staff',
      lastName:  `User_${TS}`,
      role:      'DOCTOR',
      active:    true,
    });
    assert.ok(body.id, 'User must have an id');
    ctx.userId = body.id;
  });

  // ── Step 15: Cross-service consistency checks ─────────────────────────────
  it('Step 15 — data consistency: verify all cross-service foreign key references', async () => {
    // Patient exists and matches
    const patient = await api.get(`${S.patient}/${ctx.patientId}`);
    assert.equal(patient.id, ctx.patientId, 'Patient must be retrievable');

    // Appointment references correct patient and provider
    const appt = await api.get(`${S.appointment}/${ctx.appointmentId}`);
    assert.equal(appt.patientId,  ctx.patientId,  'Appointment.patientId must match');
    assert.equal(appt.providerId, ctx.providerId, 'Appointment.providerId must match');
    assert.equal(appt.status,     'Completed',     'Appointment must be Completed');

    // Encounter is linked to patient
    const encPatient = await api.get(`${S.encounter}/patient/${ctx.patientId}`);
    assert.ok(encPatient.some(e => e.id === ctx.encounterId), 'Encounter must be linked to patient');

    // Lab order is linked to encounter
    const labOrder = await api.get(`${S.lab_orders}/${ctx.orderId}`);
    assert.equal(labOrder.encounterId, ctx.encounterId, 'Lab order must reference the encounter');
    assert.equal(labOrder.status, 'Completed', 'Lab order must be Completed');

    // Lab result is linked to order
    const results = await api.get(`${S.lab_results}/order/${ctx.orderId}`);
    assert.ok(results.some(r => r.id === ctx.resultId), 'Lab result must be linked to order');

    // Prescription items contain the medication
    const items = await api.get(`${S.prescription}/${ctx.prescriptionId}/items`);
    assert.ok(items.some(i => i.medicationId === ctx.medicationId), 'Prescription item must reference medication');

    // Invoice references patient and encounter, and is Paid
    const invoice = await api.get(`${S.invoice}/${ctx.invoiceId}`);
    assert.equal(invoice.patientId,   ctx.patientId,   'Invoice.patientId must match');
    assert.equal(invoice.encounterId, ctx.encounterId, 'Invoice.encounterId must match');
    assert.equal(invoice.status,      'Paid',           'Invoice must be Paid');
  });
});
