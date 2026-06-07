import apiClient from './apiClient';

const BASE = '/api/medications';

export const medicationApi = {
  getAll:   ()         => apiClient.get(BASE),
  getById:  (id)       => apiClient.get(`${BASE}/${id}`),
  search:   (q)        => apiClient.get(`${BASE}/search`, { params: { query: q } }),
  create:   (data)     => apiClient.post(BASE, data),
  update:   (id, data) => apiClient.put(`${BASE}/${id}`, data),
  remove:   (id)       => apiClient.delete(`${BASE}/${id}`),
};
