import { useState, useEffect } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import { appointmentApi } from '../../api/appointmentApi';
import Spinner from '../../components/Spinner';
import ErrorAlert from '../../components/ErrorAlert';

const STATUS_BADGE = { Scheduled: 'info', Completed: 'success', Cancelled: 'danger' };

export default function AppointmentViewPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [appt, setAppt]   = useState(null);
  const [loading, setLoading] = useState(true);
  const [error,   setError]   = useState('');

  useEffect(() => {
    appointmentApi.getById(id)
      .then(r => setAppt(r.data))
      .catch(() => setError('Appointment not found.'))
      .finally(() => setLoading(false));
  }, [id]);

  const handleStatus = async (status) => {
    try { await appointmentApi.updateStatus(id, status); setAppt(a => ({ ...a, status })); }
    catch { setError('Failed to update status.'); }
  };

  if (loading) return <Spinner />;
  if (!appt)   return <ErrorAlert message={error || 'Not found.'} />;

  return (
    <div>
      <div className="page-header">
        <h2>Appointment #{appt.id}</h2>
        <div className="btn-actions">
          <Link to={`/appointments/${id}/edit`} className="btn btn-warning">Edit</Link>
          <Link to="/appointments" className="btn btn-secondary">← Back</Link>
        </div>
      </div>
      <ErrorAlert message={error} onDismiss={() => setError('')} />
      <div className="card">
        <div className="card-body">
          <div className="detail-grid">
            {[
              ['Patient', <Link to={`/patients/${appt.patientId}`}>Patient #{appt.patientId}</Link>],
              ['Provider', `Provider #${appt.providerId}`],
              ['Date', appt.appointmentDate],
              ['Time', `${appt.startTime || '–'} – ${appt.endTime || '–'}`],
              ['Reason', appt.reason],
              ['Status', <span className={`badge badge-${STATUS_BADGE[appt.status] || 'secondary'}`}>{appt.status}</span>],
            ].map(([l, v]) => (
              <div key={l} className="detail-item">
                <div className="detail-label">{l}</div>
                <div className="detail-value">{v || '–'}</div>
              </div>
            ))}
          </div>
          {appt.status === 'Scheduled' && (
            <div className="btn-actions mt-4">
              <button className="btn btn-success" onClick={() => handleStatus('Completed')}>Mark Completed</button>
              <button className="btn btn-danger"  onClick={() => handleStatus('Cancelled')}>Cancel Appointment</button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
