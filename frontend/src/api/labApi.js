import apiClient from './apiClient';

const ORDERS  = '/api/lab/orders';
const RESULTS = '/api/lab/results';

export const labApi = {
  getAllOrders:      ()           => apiClient.get(ORDERS),
  getPendingOrders: ()           => apiClient.get(`${ORDERS}/pending`),
  getOrderById:     (id)         => apiClient.get(`${ORDERS}/${id}`),
  getOrdersByPatient:(pid)       => apiClient.get(`${ORDERS}/patient/${pid}`),
  createOrder:      (data)       => apiClient.post(ORDERS, data),
  updateOrderStatus:(id, status) => apiClient.put(`${ORDERS}/${id}/status`, null, { params: { status } }),
  deleteOrder:      (id)         => apiClient.delete(`${ORDERS}/${id}`),

  addResult:        (data)       => apiClient.post(RESULTS, data),
  getResultsByOrder:(orderId)    => apiClient.get(`${RESULTS}/order/${orderId}`),
};
