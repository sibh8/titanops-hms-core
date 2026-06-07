import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { userApi } from '../api/userApi';
import ErrorAlert from '../components/ErrorAlert';

export default function RegisterPage() {
  const { login } = useAuth();
  const navigate = useNavigate();

  const [form, setForm] = useState({
    username: '',
    password: '',
    confirmPassword: '',
    role: 'STAFF',
  });
  const [error, setError]     = useState('');
  const [loading, setLoading] = useState(false);

  const handleChange = (e) =>
    setForm((f) => ({ ...f, [e.target.name]: e.target.value }));

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');

    if (!form.username || !form.password || !form.confirmPassword) {
      setError('All fields are required.');
      return;
    }
    if (form.username.length < 3) {
      setError('Username must be at least 3 characters.');
      return;
    }
    if (form.password.length < 6) {
      setError('Password must be at least 6 characters.');
      return;
    }
    if (form.password !== form.confirmPassword) {
      setError('Passwords do not match.');
      return;
    }

    setLoading(true);
    try {
      const res = await userApi.register({
        username: form.username,
        password: form.password,
        role: form.role,
      });
      // Auto-login after successful registration
      login(res.data, null);
      navigate('/');
    } catch (err) {
      if (err.response?.status === 409 || err.response?.status === 400) {
        setError('Username already taken. Please choose another.');
      } else {
        setError('Registration failed. Make sure user-service is running.');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      <div className="mesh-bg">
        <div className="orb1" />
        <div className="orb2" />
        <div className="orb3" />
        <div className="grain" />
      </div>

      <div className="login-glass-card">
        {/* Logo */}
        <div className="login-logo">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
            <path d="M22 12h-4l-3 9L9 3l-3 9H2"/>
          </svg>
        </div>

        <h2>MediCore HMS</h2>
        <p className="login-subtitle">Create your account</p>

        <ErrorAlert message={error} onDismiss={() => setError('')} />

        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label htmlFor="username">Username</label>
            <input
              id="username" name="username" className="form-control"
              placeholder="Choose a username"
              value={form.username} onChange={handleChange}
              autoComplete="username" autoFocus
            />
          </div>

          <div className="form-group">
            <label htmlFor="role">Role</label>
            <select
              id="role" name="role" className="form-control"
              value={form.role} onChange={handleChange}
            >
              <option value="STAFF">Staff</option>
              <option value="DOCTOR">Doctor</option>
              <option value="NURSE">Nurse</option>
              <option value="ADMIN">Admin</option>
            </select>
          </div>

          <div className="form-group">
            <label htmlFor="password">Password</label>
            <input
              id="password" name="password" type="password" className="form-control"
              placeholder="At least 6 characters"
              value={form.password} onChange={handleChange}
              autoComplete="new-password"
            />
          </div>

          <div className="form-group">
            <label htmlFor="confirmPassword">Confirm Password</label>
            <input
              id="confirmPassword" name="confirmPassword" type="password" className="form-control"
              placeholder="Repeat your password"
              value={form.confirmPassword} onChange={handleChange}
              autoComplete="new-password"
            />
          </div>

          <button
            type="submit"
            className="btn btn-primary"
            style={{ width: '100%', padding: '11px', fontSize: '0.9rem', marginTop: 4, justifyContent: 'center' }}
            disabled={loading}
          >
            {loading ? 'Creating account…' : 'Create Account →'}
          </button>
        </form>

        <p style={{ textAlign: 'center', marginTop: 20, fontSize: '0.82rem', color: 'var(--text-muted)' }}>
          Already have an account?{' '}
          <Link to="/login" style={{ color: 'var(--accent-cyan)', textDecoration: 'none', fontWeight: 600 }}>
            Sign in
          </Link>
        </p>

        <p style={{ textAlign: 'center', marginTop: 16, fontSize: '0.75rem', color: 'var(--text-muted)' }}>
          Hospital Management System · v2.0
        </p>
      </div>
    </div>
  );
}
