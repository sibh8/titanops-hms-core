import { useState, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { appointmentApi } from '../../api/appointmentApi';
import Spinner from '../../components/Spinner';
import ErrorAlert from '../../components/ErrorAlert';

const STATUS_BADGE = { Scheduled: 'info', Completed: 'success', Cancelled: 'danger' };

export default function AppointmentListPage() {
  const [appointments, setAppointments] = useState([]);
  const [loading,  setLoading]  = useState(true);
  const [error,    setError]    = useState('');

  const load = useCallback(async () => {
    setLoading(true); setError('');
    try { const r = await appointmentApi.getAll(); setAppointments(r.data); }
    catch (e) { setError(e.response?.data?.message || 'Failed to load appointments.'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  const handleStatusUpdate = async (id, status) => {
    try { await appointmentApi.updateStatus(id, status); load(); }
    catch { setError('Failed to update status.'); }
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Delete this appointment?')) return;
    try { await appointmentApi.remove(id); setAppointments(a => a.filter(x => x.id !== id)); }
    catch { setError('Failed to delete appointment.'); }
  };

  return (
    <div>
      <div className="page-header">
        <h2>Appointments</h2>
        <Link to="/appointments/new" className="btn btn-success">+ Schedule Appointment</Link>
      </div>
      <ErrorAlert message={error} onDismiss={() => setError('')} />
      {loading ? <Spinner /> : (
        <div className="card">
          <div className="table-responsive">
            <table>
              <thead>
                <tr><th>ID</th><th>Patient ID</th><th>Provider ID</th><th>Date</th><th>Time</th><th>Reason</th><th>Status</th><th>Actions</th></tr>
              </thead>
              <tbody>
                {appointments.length === 0
                  ? <tr><td colSpan={8} className="text-muted" style={{textAlign:'center',padding:20}}>No appointments found.</td></tr>
                  : appointments.map(a => (
                    <tr key={a.id}>
                      <td>{a.id}</td>
                      <td><Link to={`/patients/${a.patientId}`}>{a.patientId}</Link></td>
                      <td>{a.providerId}</td>
                      <td>{a.appointmentDate}</td>
                      <td>{a.startTime} – {a.endTime}</td>
                      <td>{a.reason}</td>
                      <td><span className={`badge badge-${STATUS_BADGE[a.status] || 'secondary'}`}>{a.status}</span></td>
                      <td>
                        <div className="btn-actions">
                          <Link to={`/appointments/${a.id}`}      className="btn btn-outline btn-sm">View</Link>
                          <Link to={`/appointments/${a.id}/edit`} className="btn btn-warning btn-sm">Edit</Link>
                          {a.status === 'Scheduled' && (
                            <button className="btn btn-success btn-sm" onClick={() => handleStatusUpdate(a.id, 'Completed')}>✓</button>
                          )}
                          <button className="btn btn-danger btn-sm" onClick={() => handleDelete(a.id)}>Del</button>
                        </div>
                      </td>
                    </tr>))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
