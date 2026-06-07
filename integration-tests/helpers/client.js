/**
 * client.js — thin HTTP client wrapping fetch.
 *
 * Each method throws with status + body text if the response is not 2xx.
 * Returns the parsed JSON body on success.
 */
import { TIMEOUT_MS } from '../config.js';

const headers = { 'Content-Type': 'application/json', Accept: 'application/json' };

async function request(method, url, body) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), TIMEOUT_MS);
  let res;
  try {
    res = await fetch(url, {
      method,
      headers,
      body: body !== undefined ? JSON.stringify(body) : undefined,
      signal: ctrl.signal,
    });
  } finally {
    clearTimeout(timer);
  }

  const text = await res.text();
  let data;
  try { data = JSON.parse(text); } catch { data = text; }

  if (!res.ok) {
    const err = new Error(`HTTP ${res.status} ${res.statusText} — ${method} ${url}\n${text}`);
    err.status = res.status;
    err.body   = data;
    throw err;
  }
  return data;
}

export const api = {
  get:    (url)          => request('GET',    url),
  post:   (url, body)    => request('POST',   url, body),
  put:    (url, body)    => request('PUT',    url, body),
  patch:  (url, body)    => request('PATCH',  url, body),
  delete: (url)          => request('DELETE', url),
};

/** Convenience: GET /actuator/health and return parsed body (never throws on DOWN state). */
export async function getHealth(baseUrl) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), TIMEOUT_MS);
  try {
    const res = await fetch(`${baseUrl}/actuator/health`, { headers, signal: ctrl.signal });
    const body = await res.json().catch(() => ({}));
    return { ok: res.ok, status: res.status, body };
  } catch (e) {
    return { ok: false, status: 0, body: { error: e.message } };
  } finally {
    clearTimeout(timer);
  }
}
