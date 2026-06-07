import apiClient from './apiClient';

const BASE = '/api/prescriptions';

export const prescriptionApi = {
  getAll:         ()         => apiClient.get(BASE),
  getById:        (id)       => apiClient.get(`${BASE}/${id}`),
  getByPatient:   (pid)      => apiClient.get(`${BASE}/patient/${pid}`),
  create:         (data)     => apiClient.post(BASE, data),
  update:         (id, data) => apiClient.put(`${BASE}/${id}`, data),
  remove:         (id)       => apiClient.delete(`${BASE}/${id}`),
  addItem:        (id, item) => apiClient.post(`${BASE}/${id}/items`, item),
  getItems:       (id)       => apiClient.get(`${BASE}/${id}/items`),
};
