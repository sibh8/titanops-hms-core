/**
 * apiClient.js
 *
 * Axios instance pre-configured with:
 *   - Base URL from VITE_API_BASE_URL build-time env var (set in .env or
 *     passed to `docker build --build-arg`). Falls back to same-origin
 *     so the Vite dev-server proxy and a plain reverse-proxy both work.
 *   - Auth token header from localStorage (set on login).
 *   - Global 401 handler that clears auth and redirects to /login.
 */
import axios from 'axios';

const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || '',
  headers: { 'Content-Type': 'application/json' },
  timeout: 15000,
});

// Request interceptor – attach bearer token if present
apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem('auth_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Response interceptor – handle 401 globally
apiClient.interceptors.response.use(
  (res) => res,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('auth_token');
      localStorage.removeItem('auth_user');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export default apiClient;
