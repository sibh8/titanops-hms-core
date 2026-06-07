import { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { prescriptionApi } from '../../api/prescriptionApi';
import { patientApi }      from '../../api/patientApi';
import { providerApi }     from '../../api/providerApi';
import ErrorAlert from '../../components/ErrorAlert';
import Spinner from '../../components/Spinner';

export default function PrescriptionFormPage() {
  const navigate = useNavigate();
  const [form, setForm]       = useState({ patientId: '', providerId: '', notes: '' });
  const [patients, setPatients]   = useState([]);
  const [providers, setProviders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving,  setSaving]  = useState(false);
  const [error,   setError]   = useState('');

  useEffect(() => {
    Promise.all([patientApi.getAll(), providerApi.getActive()])
      .then(([p, pr]) => { setPatients(p.data); setProviders(pr.data); })
      .catch(() => setError('Failed to load form data.'))
      .finally(() => setLoading(false));
  }, []);

  const handleChange = e => setForm(f => ({...f, [e.target.name]: e.target.value}));

  const handleSubmit = async e => {
    e.preventDefault(); setError('');
    if (!form.patientId || !form.providerId) { setError('Patient and provider are required.'); return; }
    setSaving(true);
    try { const r = await prescriptionApi.create(form); navigate(`/prescriptions/${r.data.id}`); }
    catch (err) { setError(err.response?.data?.message || 'Failed to create prescription.'); }
    finally { setSaving(false); }
  };

  if (loading) return <Spinner />;

  return (
    <div>
      <div className="page-header">
        <h2>New Prescription</h2>
        <Link to="/prescriptions" className="btn btn-secondary">← Back</Link>
      </div>
      <div className="card"><div className="card-body">
        <ErrorAlert message={error} onDismiss={() => setError('')} />
        <form onSubmit={handleSubmit}>
          <div className="form-row">
            <div className="form-group">
              <label>Patient *</label>
              <select name="patientId" className="form-control" value={form.patientId} onChange={handleChange} required>
                <option value="">– select patient –</option>
                {patients.map(p => <option key={p.id} value={p.id}>{p.firstName} {p.lastName}</option>)}
              </select>
            </div>
            <div className="form-group">
              <label>Provider *</label>
              <select name="providerId" className="form-control" value={form.providerId} onChange={handleChange} required>
                <option value="">– select provider –</option>
                {providers.map(p => <option key={p.id} value={p.id}>{p.firstName} {p.lastName} – {p.speciality}</option>)}
              </select>
            </div>
          </div>
          <div className="form-group"><label>Notes</label><textarea name="notes" className="form-control" rows={2} value={form.notes} onChange={handleChange} /></div>
          <div className="btn-actions mt-3">
            <button type="submit" className="btn btn-primary" disabled={saving}>{saving ? 'Creating…' : 'Create Prescription'}</button>
            <Link to="/prescriptions" className="btn btn-secondary">Cancel</Link>
          </div>
        </form>
      </div></div>
    </div>
  );
}
