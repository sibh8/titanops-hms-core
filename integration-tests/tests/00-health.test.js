/**
 * 00-health.test.js
 *
 * Checks that every microservice actuator health endpoint reports status UP.
 * This is the first gate — if any service is DOWN the remaining tests will fail.
 */
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { SERVICES } from '../config.js';
import { getHealth } from '../helpers/client.js';

describe('Health checks — all 9 microservices', () => {
  for (const [name, baseUrl] of Object.entries(SERVICES)) {
    it(`${name}-service (${baseUrl}) is UP`, async () => {
      const { ok, status, body } = await getHealth(baseUrl);
      assert.ok(ok, `Expected 2xx but got HTTP ${status}. Service may not be running.\nBody: ${JSON.stringify(body)}`);
      assert.equal(
        body.status,
        'UP',
        `Expected actuator status=UP but got "${body.status}". Check Docker logs for ${name}-service.`,
      );
    });
  }
});
