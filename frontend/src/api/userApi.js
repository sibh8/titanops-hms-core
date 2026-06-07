import apiClient from './apiClient';

const BASE      = '/api/users';
const AUTH_BASE = '/api/auth';

export const userApi = {
  // User CRUD
  getAll:        ()         => apiClient.get(BASE),
  getById:       (id)       => apiClient.get(`${BASE}/${id}`),
  getByUsername: (username) => apiClient.get(`${BASE}/username/${username}`),
  create:        (data)     => apiClient.post(BASE, data),
  update:        (id, data) => apiClient.put(`${BASE}/${id}`, data),
  remove:        (id)       => apiClient.delete(`${BASE}/${id}`),

  // Auth
  register: (data)                       => apiClient.post(`${AUTH_BASE}/register`, data),
  login:    (username, password)         => apiClient.post(`${AUTH_BASE}/login`, { username, password }),
};
