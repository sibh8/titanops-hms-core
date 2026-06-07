/**
 * 03-patients.test.js — Patient Service CRUD + search
 *
 * Tests: create → getAll → getById → search → update → delete
 */
import { describe, it, after } from 'node:test';
import assert from 'node:assert/strict';
import { SERVICES } from '../config.js';
import { api } from '../helpers/client.js';

const BASE = `${SERVICES.patient}/api/patients`;
const TS   = Date.now();

const PAYLOAD = {
  firstName:   'Integration',
  lastName:    `Patient_${TS}`,
  dateOfBirth: '1985-06-15',
  gender:      'Male',
  address:     '123 Test Street',
  phone:       '555-0200',
  email:       `patient_${TS}@medicore.test`,
  bloodGroup:  'A+',
};

describe('Patient Service — CRUD + search', () => {
  let createdId;

  after(async () => {
    if (createdId) await api.delete(`${BASE}/${createdId}`).catch(() => {});
  });

  it('POST /api/patients — creates a patient', async () => {
    const body = await api.post(BASE, PAYLOAD);
    assert.ok(body.id,                           'Response must include an id');
    assert.equal(body.firstName, PAYLOAD.firstName, 'firstName must match');
    assert.equal(body.lastName,  PAYLOAD.lastName,  'lastName must match');
    assert.equal(body.bloodGroup, PAYLOAD.bloodGroup, 'bloodGroup must match');
    createdId = body.id;
  });

  it('GET /api/patients — lists all patients', async () => {
    const list = await api.get(BASE);
    assert.ok(Array.isArray(list), 'Response must be an array');
    assert.ok(list.some(p => p.id === createdId), 'Created patient must appear in list');
  });

  it('GET /api/patients/:id — retrieves by id', async () => {
    const body = await api.get(`${BASE}/${createdId}`);
    assert.equal(body.id,          createdId,          'id must match');
    assert.equal(body.dateOfBirth, PAYLOAD.dateOfBirth, 'dateOfBirth must match');
    assert.equal(body.email,       PAYLOAD.email,       'email must match');
  });

  it('GET /api/patients/search?query= — finds created patient', async () => {
    const results = await api.get(`${BASE}/search?query=Patient_${TS}`);
    assert.ok(Array.isArray(results),                 'Search must return an array');
    assert.ok(results.some(p => p.id === createdId),  'Created patient must appear in search results');
  });

  it('PUT /api/patients/:id — updates phone and address', async () => {
    const updated = { ...PAYLOAD, phone: '555-9999', address: '456 Updated Ave' };
    const body    = await api.put(`${BASE}/${createdId}`, updated);
    assert.equal(body.phone,   '555-9999',       'phone must be updated');
    assert.equal(body.address, '456 Updated Ave', 'address must be updated');
  });

  it('DELETE /api/patients/:id — deletes the patient', async () => {
    await api.delete(`${BASE}/${createdId}`);
    createdId = null;
  });
});
