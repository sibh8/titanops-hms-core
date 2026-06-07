import { useState, useEffect } from 'react';
import { useNavigate, useParams, Link } from 'react-router-dom';
import { patientApi } from '../../api/patientApi';
import ErrorAlert from '../../components/ErrorAlert';
import Spinner from '../../components/Spinner';

const EMPTY = { firstName: '', lastName: '', dateOfBirth: '', gender: 'Male', address: '', phone: '', email: '', bloodGroup: '' };

export default function PatientFormPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const isEdit = Boolean(id);
  const [form, setForm]     = useState(EMPTY);
  const [loading, setLoading] = useState(isEdit);
  const [saving, setSaving]   = useState(false);
  const [error, setError]     = useState('');

  useEffect(() => {
    if (!isEdit) return;
    patientApi.getById(id)
      .then((r) => setForm(r.data))
      .catch(() => setError('Failed to load patient.'))
      .finally(() => setLoading(false));
  }, [id, isEdit]);

  const handleChange = (e) => setForm((f) => ({ ...f, [e.target.name]: e.target.value }));

  const handleSubmit = async (e) => {
    e.preventDefault(); setError('');
    if (!form.firstName || !form.lastName) { setError('First name and last name are required.'); return; }
    setSaving(true);
    try {
      if (isEdit) await patientApi.update(id, form);
      else        await patientApi.create(form);
      navigate('/patients');
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to save patient.');
    } finally { setSaving(false); }
  };

  if (loading) return <Spinner />;

  return (
    <div>
      <div className="page-header">
        <h2>{isEdit ? 'Edit Patient' : 'New Patient'}</h2>
        <Link to="/patients" className="btn btn-secondary">← Back</Link>
      </div>
      <div className="card">
        <div className="card-body">
          <ErrorAlert message={error} onDismiss={() => setError('')} />
          <form onSubmit={handleSubmit}>
            <div className="form-row">
              <div className="form-group">
                <label>First Name *</label>
                <input name="firstName" className="form-control" value={form.firstName} onChange={handleChange} required />
              </div>
              <div className="form-group">
                <label>Last Name *</label>
                <input name="lastName" className="form-control" value={form.lastName} onChange={handleChange} required />
              </div>
            </div>
            <div className="form-row">
              <div className="form-group">
                <label>Date of Birth</label>
                <input type="date" name="dateOfBirth" className="form-control" value={form.dateOfBirth || ''} onChange={handleChange} />
              </div>
              <div className="form-group">
                <label>Gender</label>
                <select name="gender" className="form-control" value={form.gender} onChange={handleChange}>
                  <option>Male</option><option>Female</option><option>Other</option>
                </select>
              </div>
              <div className="form-group">
                <label>Blood Group</label>
                <select name="bloodGroup" className="form-control" value={form.bloodGroup || ''} onChange={handleChange}>
                  <option value="">– select –</option>
                  {['A+','A-','B+','B-','AB+','AB-','O+','O-'].map(g => <option key={g}>{g}</option>)}
                </select>
              </div>
            </div>
            <div className="form-group">
              <label>Address</label>
              <textarea name="address" className="form-control" rows={2} value={form.address || ''} onChange={handleChange} />
            </div>
            <div className="form-row">
              <div className="form-group">
                <label>Phone</label>
                <input name="phone" className="form-control" value={form.phone || ''} onChange={handleChange} />
              </div>
              <div className="form-group">
                <label>Email</label>
                <input type="email" name="email" className="form-control" value={form.email || ''} onChange={handleChange} />
              </div>
            </div>
            <div className="btn-actions mt-3">
              <button type="submit" className="btn btn-primary" disabled={saving}>{saving ? 'Saving…' : 'Save Patient'}</button>
              <Link to="/patients" className="btn btn-secondary">Cancel</Link>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}
