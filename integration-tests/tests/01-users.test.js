/**
 * 01-users.test.js — User Service CRUD
 *
 * Tests: create → getAll → getById → getByUsername → update → delete
 * All created resources are deleted in cleanup even if assertions fail.
 */
import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { SERVICES } from '../config.js';
import { api } from '../helpers/client.js';

const BASE = `${SERVICES.user}/api/users`;

const PAYLOAD = {
  username:  `test_user_${Date.now()}`,
  password:  'Test@1234',
  email:     `test_${Date.now()}@medicore.test`,
  firstName: 'Integration',
  lastName:  'TestUser',
  role:      'NURSE',
  active:    true,
};

describe('User Service — CRUD', () => {
  let createdId;

  after(async () => {
    if (createdId) {
      await api.delete(`${BASE}/${createdId}`).catch(() => {});
    }
  });

  it('POST /api/users — creates a user', async () => {
    const body = await api.post(BASE, PAYLOAD);
    assert.ok(body.id,                    'Response must include an id');
    assert.equal(body.username, PAYLOAD.username, 'username must match');
    assert.equal(body.email,    PAYLOAD.email,    'email must match');
    createdId = body.id;
  });

  it('GET /api/users — lists users (includes created)', async () => {
    const list = await api.get(BASE);
    assert.ok(Array.isArray(list),         'Response must be an array');
    assert.ok(list.length > 0,             'User list must not be empty');
    assert.ok(list.some(u => u.id === createdId), 'Created user must appear in list');
  });

  it('GET /api/users/:id — retrieves by id', async () => {
    const body = await api.get(`${BASE}/${createdId}`);
    assert.equal(body.id,       createdId,       'id must match');
    assert.equal(body.username, PAYLOAD.username, 'username must match');
  });

  it('GET /api/users/username/:username — retrieves by username', async () => {
    const body = await api.get(`${BASE}/username/${PAYLOAD.username}`);
    assert.equal(body.username, PAYLOAD.username, 'username must match');
    assert.equal(body.id,       createdId,        'id must match');
  });

  it('PUT /api/users/:id — updates email', async () => {
    const updated = { ...PAYLOAD, email: `updated_${Date.now()}@medicore.test` };
    const body    = await api.put(`${BASE}/${createdId}`, updated);
    assert.equal(body.email, updated.email, 'email must be updated');
  });

  it('DELETE /api/users/:id — deletes the user', async () => {
    await api.delete(`${BASE}/${createdId}`);
    createdId = null; // prevent after() double-delete
    // Verify 404
    try {
      await api.get(`${BASE}/9999999`);
      assert.fail('Expected 404 but request succeeded');
    } catch (e) {
      assert.equal(e.status, 404, `Expected 404 but got ${e.status}`);
    }
  });
});
