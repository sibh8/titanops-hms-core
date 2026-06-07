import apiClient from './apiClient';

const BASE = '/api/appointments';

export const appointmentApi = {
  getAll:          ()               => apiClient.get(BASE),
  getById:         (id)             => apiClient.get(`${BASE}/${id}`),
  getByPatient:    (patientId)      => apiClient.get(`${BASE}/patient/${patientId}`),
  getByProvider:   (providerId)     => apiClient.get(`${BASE}/provider/${providerId}`),
  create:          (data)           => apiClient.post(BASE, data),
  update:          (id, data)       => apiClient.put(`${BASE}/${id}`, data),
  updateStatus:    (id, status)     => apiClient.put(`${BASE}/${id}/status`, null, { params: { status } }),
  remove:          (id)             => apiClient.delete(`${BASE}/${id}`),
};
