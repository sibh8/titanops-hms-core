/**
 * 02-providers.test.js — Provider Service CRUD
 *
 * Tests: create → getAll → getActive → getById → update → delete
 */
import { describe, it, after } from 'node:test';
import assert from 'node:assert/strict';
import { SERVICES } from '../config.js';
import { api } from '../helpers/client.js';

const BASE = `${SERVICES.provider}/api/providers`;

const PAYLOAD = {
  firstName:   'Dr. Integration',
  lastName:    `Provider_${Date.now()}`,
  speciality:  'General Medicine',
  phone:       '555-0100',
  email:       `provider_${Date.now()}@medicore.test`,
  licenseNumber: `LIC-${Date.now()}`,
  active:      true,
};

describe('Provider Service — CRUD', () => {
  let createdId;

  after(async () => {
    if (createdId) await api.delete(`${BASE}/${createdId}`).catch(() => {});
  });

  it('POST /api/providers — creates a provider', async () => {
    const body = await api.post(BASE, PAYLOAD);
    assert.ok(body.id,                          'Response must include an id');
    assert.equal(body.lastName,  PAYLOAD.lastName,  'lastName must match');
    assert.equal(body.speciality, PAYLOAD.speciality, 'speciality must match');
    createdId = body.id;
  });

  it('GET /api/providers — lists all providers', async () => {
    const list = await api.get(BASE);
    assert.ok(Array.isArray(list), 'Response must be an array');
    assert.ok(list.some(p => p.id === createdId), 'Created provider must appear in list');
  });

  it('GET /api/providers/active — lists only active providers', async () => {
    const list = await api.get(`${BASE}/active`);
    assert.ok(Array.isArray(list), 'Response must be an array');
    assert.ok(list.some(p => p.id === createdId), 'Active provider must be in active list');
    list.forEach(p => assert.ok(p.active !== false, `Provider ${p.id} must be active`));
  });

  it('GET /api/providers/:id — retrieves by id', async () => {
    const body = await api.get(`${BASE}/${createdId}`);
    assert.equal(body.id,        createdId,         'id must match');
    assert.equal(body.firstName, PAYLOAD.firstName, 'firstName must match');
  });

  it('PUT /api/providers/:id — updates speciality', async () => {
    const updated = { ...PAYLOAD, speciality: 'Cardiology' };
    const body    = await api.put(`${BASE}/${createdId}`, updated);
    assert.equal(body.speciality, 'Cardiology', 'speciality must be updated');
  });

  it('DELETE /api/providers/:id — deletes the provider', async () => {
    await api.delete(`${BASE}/${createdId}`);
    createdId = null;
  });
});
