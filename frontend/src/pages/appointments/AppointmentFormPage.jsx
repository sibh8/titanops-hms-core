import { useState, useEffect } from 'react';
import { useNavigate, useParams, useSearchParams, Link } from 'react-router-dom';
import { appointmentApi } from '../../api/appointmentApi';
import { patientApi }     from '../../api/patientApi';
import { providerApi }    from '../../api/providerApi';
import ErrorAlert from '../../components/ErrorAlert';
import Spinner from '../../components/Spinner';

const EMPTY = { patientId: '', providerId: '', appointmentDate: '', startTime: '', endTime: '', reason: '', status: 'Scheduled' };

export default function AppointmentFormPage() {
  const { id } = useParams();
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const isEdit = Boolean(id);
  const [form, setForm]       = useState({ ...EMPTY, patientId: searchParams.get('patientId') || '' });
  const [patients, setPatients]   = useState([]);
  const [providers, setProviders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving,  setSaving]  = useState(false);
  const [error,   setError]   = useState('');

  useEffect(() => {
    Promise.all([
      patientApi.getAll(),
      providerApi.getActive(),
      isEdit ? appointmentApi.getById(id) : Promise.resolve(null),
    ]).then(([p, pr, appt]) => {
      setPatients(p.data);
      setProviders(pr.data);
      if (appt) setForm(appt.data);
    }).catch(() => setError('Failed to load form data.'))
      .finally(() => setLoading(false));
  }, [id, isEdit]);

  const handleChange = (e) => setForm(f => ({ ...f, [e.target.name]: e.target.value }));

  const handleSubmit = async (e) => {
    e.preventDefault(); setError('');
    if (!form.patientId || !form.providerId || !form.appointmentDate) {
      setError('Patient, provider and date are required.'); return;
    }
    setSaving(true);
    try {
      if (isEdit) await appointmentApi.update(id, form);
      else        await appointmentApi.create(form);
      navigate('/appointments');
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to save appointment.');
    } finally { setSaving(false); }
  };

  if (loading) return <Spinner />;

  return (
    <div>
      <div className="page-header">
        <h2>{isEdit ? 'Edit Appointment' : 'Schedule New Appointment'}</h2>
        <Link to="/appointments" className="btn btn-secondary">← Back</Link>
      </div>
      <div className="card">
        <div className="card-body">
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
            <div className="form-row">
              <div className="form-group">
                <label>Date *</label>
                <input type="date" name="appointmentDate" className="form-control" value={form.appointmentDate || ''} onChange={handleChange} required />
              </div>
              <div className="form-group">
                <label>Start Time</label>
                <input type="time" name="startTime" className="form-control" value={form.startTime || ''} onChange={handleChange} />
              </div>
              <div className="form-group">
                <label>End Time</label>
                <input type="time" name="endTime" className="form-control" value={form.endTime || ''} onChange={handleChange} />
              </div>
            </div>
            <div className="form-group">
              <label>Reason for Visit</label>
              <textarea name="reason" className="form-control" rows={3} value={form.reason || ''} onChange={handleChange} />
            </div>
            {isEdit && (
              <div className="form-group">
                <label>Status</label>
                <select name="status" className="form-control" value={form.status} onChange={handleChange}>
                  <option>Scheduled</option><option>Completed</option><option>Cancelled</option>
                </select>
              </div>
            )}
            <div className="btn-actions mt-3">
              <button type="submit" className="btn btn-primary" disabled={saving}>{saving ? 'Saving…' : 'Save Appointment'}</button>
              <Link to="/appointments" className="btn btn-secondary">Cancel</Link>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}
