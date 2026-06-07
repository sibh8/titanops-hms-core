import { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { providerApi } from '../../api/providerApi';
import ErrorAlert from '../../components/ErrorAlert';
import Spinner from '../../components/Spinner';

const EMPTY = { firstName: '', lastName: '', speciality: '', licenseNumber: '', phone: '', email: '', active: true };

export default function ProviderFormPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const isEdit = Boolean(id);
  const [form, setForm]   = useState(EMPTY);
  const [loading, setLoading] = useState(isEdit);
  const [saving,  setSaving]  = useState(false);
  const [error,   setError]   = useState('');

  useEffect(() => {
    if (!isEdit) return;
    providerApi.getById(id)
      .then(r => setForm(r.data))
      .catch(() => setError('Failed to load provider.'))
      .finally(() => setLoading(false));
  }, [id, isEdit]);

  const handleChange = (e) => {
    const val = e.target.type === 'checkbox' ? e.target.checked : e.target.value;
    setForm(f => ({ ...f, [e.target.name]: val }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault(); setError('');
    if (!form.firstName || !form.lastName) { setError('First and last name are required.'); return; }
    setSaving(true);
    try {
      if (isEdit) await providerApi.update(id, form);
      else        await providerApi.create(form);
      navigate('/providers');
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to save provider.');
    } finally { setSaving(false); }
  };

  if (loading) return <Spinner />;

  return (
    <div>
      <div className="page-header">
        <h2>{isEdit ? 'Edit Provider' : 'New Provider'}</h2>
        <Link to="/providers" className="btn btn-secondary">← Back</Link>
      </div>
      <div className="card"><div className="card-body">
        <ErrorAlert message={error} onDismiss={() => setError('')} />
        <form onSubmit={handleSubmit}>
          <div className="form-row">
            <div className="form-group"><label>First Name *</label><input name="firstName" className="form-control" value={form.firstName} onChange={handleChange} required /></div>
            <div className="form-group"><label>Last Name *</label><input name="lastName" className="form-control" value={form.lastName} onChange={handleChange} required /></div>
          </div>
          <div className="form-row">
            <div className="form-group"><label>Speciality</label><input name="speciality" className="form-control" value={form.speciality || ''} onChange={handleChange} /></div>
            <div className="form-group"><label>License Number</label><input name="licenseNumber" className="form-control" value={form.licenseNumber || ''} onChange={handleChange} /></div>
          </div>
          <div className="form-row">
            <div className="form-group"><label>Phone</label><input name="phone" className="form-control" value={form.phone || ''} onChange={handleChange} /></div>
            <div className="form-group"><label>Email</label><input type="email" name="email" className="form-control" value={form.email || ''} onChange={handleChange} /></div>
          </div>
          <div className="form-group">
            <label><input type="checkbox" name="active" checked={form.active} onChange={handleChange} style={{marginRight:6}} />Active</label>
          </div>
          <div className="btn-actions mt-3">
            <button type="submit" className="btn btn-primary" disabled={saving}>{saving ? 'Saving…' : 'Save Provider'}</button>
            <Link to="/providers" className="btn btn-secondary">Cancel</Link>
          </div>
        </form>
      </div></div>
    </div>
  );
}
