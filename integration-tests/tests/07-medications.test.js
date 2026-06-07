/**
 * 07-medications.test.js — Medication Service CRUD + search
 *
 * Tests: create → getAll → getById → search → update → delete
 */
import { describe, it, after } from 'node:test';
import assert from 'node:assert/strict';
import { SERVICES } from '../config.js';
import { api } from '../helpers/client.js';

const BASE = `${SERVICES.medication}/api/medications`;
const TS   = Date.now();

const PAYLOAD = {
  name:         `Ibuprofen_${TS}`,
  genericName:  'Ibuprofen',
  dosageForm:   'Tablet',
  strength:     '400mg',
  manufacturer: 'Integration Pharma',
  description:  'NSAID for pain relief',
  active:       true,
};

describe('Medication Service — CRUD + search', () => {
  let createdId;

  after(async () => {
    if (createdId) await api.delete(`${BASE}/${createdId}`).catch(() => {});
  });

  it('POST /api/medications — creates a medication', async () => {
    const body = await api.post(BASE, PAYLOAD);
    assert.ok(body.id,                           'Response must include an id');
    assert.equal(body.genericName, 'Ibuprofen',  'genericName must match');
    assert.equal(body.strength,    '400mg',       'strength must match');
    createdId = body.id;
  });

  it('GET /api/medications — lists all medications', async () => {
    const list = await api.get(BASE);
    assert.ok(Array.isArray(list), 'Response must be an array');
    assert.ok(list.some(m => m.id === createdId), 'Created medication must appear in list');
  });

  it('GET /api/medications/:id — retrieves by id', async () => {
    const body = await api.get(`${BASE}/${createdId}`);
    assert.equal(body.id,           createdId,          'id must match');
    assert.equal(body.manufacturer, PAYLOAD.manufacturer, 'manufacturer must match');
  });

  it('GET /api/medications/search?query= — finds by name', async () => {
    const results = await api.get(`${BASE}/search?query=Ibuprofen_${TS}`);
    assert.ok(Array.isArray(results), 'Search must return an array');
    assert.ok(results.some(m => m.id === createdId), 'Created medication must appear in search');
  });

  it('PUT /api/medications/:id — updates strength', async () => {
    const updated = { ...PAYLOAD, strength: '600mg' };
    const body    = await api.put(`${BASE}/${createdId}`, updated);
    assert.equal(body.strength, '600mg', 'strength must be updated');
  });

  it('DELETE /api/medications/:id — deletes the medication', async () => {
    await api.delete(`${BASE}/${createdId}`);
    createdId = null;
  });
});
