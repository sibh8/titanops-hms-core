import { useState, useEffect } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import { patientApi }      from '../../api/patientApi';
import { appointmentApi }  from '../../api/appointmentApi';
import { encounterApi }    from '../../api/encounterApi';
import { billingApi }      from '../../api/billingApi';
import Spinner from '../../components/Spinner';
import ErrorAlert from '../../components/ErrorAlert';

export default function PatientViewPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [patient,      setPatient]      = useState(null);
  const [appointments, setAppointments] = useState([]);
  const [encounters,   setEncounters]   = useState([]);
  const [invoices,     setInvoices]     = useState([]);
  const [loading, setLoading] = useState(true);
  const [error,   setError]   = useState('');

  useEffect(() => {
    Promise.allSettled([
      patientApi.getById(id),
      appointmentApi.getByPatient(id),
      encounterApi.getByPatient(id),
      billingApi.getByPatient(id),
    ]).then(([p, a, e, b]) => {
      if (p.status === 'fulfilled') setPatient(p.value.data); else setError('Patient not found.');
      if (a.status === 'fulfilled') setAppointments(a.value.data);
      if (e.status === 'fulfilled') setEncounters(e.value.data);
      if (b.status === 'fulfilled') setInvoices(b.value.data);
    }).finally(() => setLoading(false));
  }, [id]);

  if (loading) return <Spinner />;
  if (!patient) return <ErrorAlert message={error || 'Patient not found.'} />;

  return (
    <div>
      <div className="page-header">
        <h2>{patient.firstName} {patient.lastName}</h2>
        <div className="btn-actions">
          <Link to={`/patients/${id}/edit`} className="btn btn-warning">Edit</Link>
          <Link to="/patients" className="btn btn-secondary">← Back</Link>
        </div>
      </div>
      <ErrorAlert message={error} onDismiss={() => setError('')} />

      {/* Demographics */}
      <div className="card">
        <div className="card-header"><h2>Demographics</h2></div>
        <div className="card-body">
          <div className="detail-grid">
            {[['ID', patient.id], ['Date of Birth', patient.dateOfBirth], ['Gender', patient.gender],
              ['Blood Group', patient.bloodGroup], ['Phone', patient.phone], ['Email', patient.email],
              ['Address', patient.address]].map(([l, v]) => (
              <div key={l} className="detail-item"><div className="detail-label">{l}</div><div className="detail-value">{v || '–'}</div></div>
            ))}
          </div>
        </div>
      </div>

      {/* Appointments */}
      <div className="card">
        <div className="card-header">
          <h2>Appointments ({appointments.length})</h2>
          <Link to={`/appointments/new?patientId=${id}`} className="btn btn-success btn-sm">+ Schedule</Link>
        </div>
        <div className="table-responsive">
          <table>
            <thead><tr><th>Date</th><th>Provider</th><th>Reason</th><th>Status</th><th></th></tr></thead>
            <tbody>
              {appointments.length === 0
                ? <tr><td colSpan={5} className="text-muted" style={{textAlign:'center',padding:12}}>No appointments.</td></tr>
                : appointments.map(a => (
                  <tr key={a.id}>
                    <td>{a.appointmentDate}</td>
                    <td>{a.providerId}</td>
                    <td>{a.reason}</td>
                    <td><span className={`badge badge-${a.status==='Completed'?'success':a.status==='Cancelled'?'danger':'info'}`}>{a.status}</span></td>
                    <td><Link to={`/appointments/${a.id}`} className="btn btn-outline btn-sm">View</Link></td>
                  </tr>))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Encounters */}
      <div className="card">
        <div className="card-header"><h2>Encounters ({encounters.length})</h2></div>
        <div className="table-responsive">
          <table>
            <thead><tr><th>ID</th><th>Date</th><th>Status</th><th></th></tr></thead>
            <tbody>
              {encounters.length === 0
                ? <tr><td colSpan={4} className="text-muted" style={{textAlign:'center',padding:12}}>No encounters.</td></tr>
                : encounters.map(e => (
                  <tr key={e.id}>
                    <td>{e.id}</td><td>{e.encounterDate}</td>
                    <td><span className="badge badge-secondary">{e.status}</span></td>
                    <td><Link to={`/encounters/${e.id}`} className="btn btn-outline btn-sm">View</Link></td>
                  </tr>))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Invoices */}
      <div className="card">
        <div className="card-header"><h2>Invoices ({invoices.length})</h2></div>
        <div className="table-responsive">
          <table>
            <thead><tr><th>ID</th><th>Date</th><th>Total</th><th>Status</th><th></th></tr></thead>
            <tbody>
              {invoices.length === 0
                ? <tr><td colSpan={5} className="text-muted" style={{textAlign:'center',padding:12}}>No invoices.</td></tr>
                : invoices.map(i => (
                  <tr key={i.id}>
                    <td>{i.id}</td><td>{i.invoiceDate}</td>
                    <td>${i.totalAmount}</td>
                    <td><span className={`badge badge-${i.status==='Paid'?'success':i.status==='Overdue'?'danger':'warning'}`}>{i.status}</span></td>
                    <td><Link to={`/billing/${i.id}`} className="btn btn-outline btn-sm">View</Link></td>
                  </tr>))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
