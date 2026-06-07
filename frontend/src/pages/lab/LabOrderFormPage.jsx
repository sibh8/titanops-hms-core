import { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { labApi } from '../../api/labApi';
import { patientApi } from '../../api/patientApi';
import ErrorAlert from '../../components/ErrorAlert';
import Spinner from '../../components/Spinner';

const TESTS = ['CBC', 'BMP', 'LFT', 'RFT', 'Lipid Panel', 'HbA1c', 'TSH', 'Urinalysis', 'Blood Culture', 'Other'];

export default function LabOrderFormPage() {
  const navigate = useNavigate();
  const [form, setForm]       = useState({ patientId: '', testName: '', notes: '' });
  const [patients, setPatients] = useState([]);
  const [loading, setLoading]   = useState(true);
  const [saving,  setSaving]    = useState(false);
  const [error,   setError]     = useState('');

  useEffect(() => {
    patientApi.getAll()
      .then(r => setPatients(r.data))
      .catch(() => setError('Failed to load patients.'))
      .finally(() => setLoading(false));
  }, []);

  const handleChange = e => setForm(f => ({ ...f, [e.target.name]: e.target.value }));

  const handleSubmit = async e => {
    e.preventDefault(); setError('');
    if (!form.patientId || !form.testName) { setError('Patient and test name are required.'); return; }
    setSaving(true);
    try { await labApi.createOrder(form); navigate('/lab'); }
    catch (err) { setError(err.response?.data?.message || 'Failed to create lab order.'); }
    finally { setSaving(false); }
  };

  if (loading) return <Spinner />;

  return (
    <div>
      <div className="page-header">
        <h2>New Lab Order</h2>
        <Link to="/lab" className="btn btn-secondary">← Back</Link>
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
              <label>Test Name *</label>
              <select name="testName" className="form-control" value={form.testName} onChange={handleChange} required>
                <option value="">– select test –</option>
                {TESTS.map(t => <option key={t}>{t}</option>)}
              </select>
            </div>
          </div>
          <div className="form-group"><label>Notes</label><textarea name="notes" className="form-control" rows={2} value={form.notes} onChange={handleChange} /></div>
          <div className="btn-actions mt-3">
            <button type="submit" className="btn btn-primary" disabled={saving}>{saving ? 'Saving…' : 'Create Lab Order'}</button>
            <Link to="/lab" className="btn btn-secondary">Cancel</Link>
          </div>
        </form>
      </div></div>
    </div>
  );
}
