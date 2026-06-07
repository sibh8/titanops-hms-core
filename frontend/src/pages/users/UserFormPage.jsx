import { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { userApi } from '../../api/userApi';
import ErrorAlert from '../../components/ErrorAlert';
import Spinner from '../../components/Spinner';

const EMPTY = { username: '', password: '', email: '', role: 'STAFF', active: true };
const ROLES = ['ADMIN', 'DOCTOR', 'NURSE', 'RECEPTIONIST', 'STAFF'];

export default function UserFormPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const isEdit = Boolean(id);
  const [form, setForm]     = useState(EMPTY);
  const [loading, setLoading] = useState(isEdit);
  const [saving,  setSaving]  = useState(false);
  const [error,   setError]   = useState('');

  useEffect(() => {
    if (!isEdit) return;
    userApi.getById(id)
      .then(r => setForm({ ...r.data, password: '' }))
      .catch(() => setError('Failed to load user.'))
      .finally(() => setLoading(false));
  }, [id, isEdit]);

  const handleChange = e => {
    const val = e.target.type === 'checkbox' ? e.target.checked : e.target.value;
    setForm(f => ({ ...f, [e.target.name]: val }));
  };

  const handleSubmit = async e => {
    e.preventDefault(); setError('');
    if (!form.username) { setError('Username is required.'); return; }
    setSaving(true);
    try {
      const payload = { ...form };
      if (!payload.password) delete payload.password;
      if (isEdit) await userApi.update(id, payload);
      else        await userApi.create(payload);
      navigate('/users');
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to save user.');
    } finally { setSaving(false); }
  };

  if (loading) return <Spinner />;

  return (
    <div>
      <div className="page-header">
        <h2>{isEdit ? 'Edit User' : 'New User'}</h2>
        <Link to="/users" className="btn btn-secondary">← Back</Link>
      </div>
      <div className="card"><div className="card-body">
        <ErrorAlert message={error} onDismiss={() => setError('')} />
        <form onSubmit={handleSubmit}>
          <div className="form-row">
            <div className="form-group"><label>Username *</label><input name="username" className="form-control" value={form.username} onChange={handleChange} required /></div>
            <div className="form-group">
              <label>{isEdit ? 'New Password (leave blank to keep)' : 'Password *'}</label>
              <input type="password" name="password" className="form-control" value={form.password || ''} onChange={handleChange} {...(!isEdit && { required: true })} />
            </div>
          </div>
          <div className="form-row">
            <div className="form-group"><label>Email</label><input type="email" name="email" className="form-control" value={form.email || ''} onChange={handleChange} /></div>
            <div className="form-group">
              <label>Role</label>
              <select name="role" className="form-control" value={form.role} onChange={handleChange}>
                {ROLES.map(r => <option key={r}>{r}</option>)}
              </select>
            </div>
          </div>
          <div className="form-group">
            <label><input type="checkbox" name="active" checked={form.active} onChange={handleChange} style={{marginRight:6}} />Active</label>
          </div>
          <div className="btn-actions mt-3">
            <button type="submit" className="btn btn-primary" disabled={saving}>{saving ? 'Saving…' : 'Save User'}</button>
            <Link to="/users" className="btn btn-secondary">Cancel</Link>
          </div>
        </form>
      </div></div>
    </div>
  );
}
