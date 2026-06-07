import apiClient from './apiClient';

const BASE = '/api/invoices';

export const billingApi = {
  getAll:        ()         => apiClient.get(BASE),
  getById:       (id)       => apiClient.get(`${BASE}/${id}`),
  getByPatient:  (pid)      => apiClient.get(`${BASE}/patient/${pid}`),
  create:        (data)     => apiClient.post(BASE, data),
  update:        (id, data) => apiClient.put(`${BASE}/${id}`, data),
  remove:        (id)       => apiClient.delete(`${BASE}/${id}`),
};
