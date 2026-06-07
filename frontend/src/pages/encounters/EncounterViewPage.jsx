import { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { encounterApi }    from '../../api/encounterApi';
import { labApi }          from '../../api/labApi';
import { prescriptionApi } from '../../api/prescriptionApi';
import Spinner from '../../components/Spinner';
import ErrorAlert from '../../components/ErrorAlert';

export default function EncounterViewPage() {
  const { id } = useParams();
  const [encounter,     setEncounter]     = useState(null);
  const [labOrders,     setLabOrders]     = useState([]);
  const [prescriptions, setPrescriptions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error,   setError]   = useState('');

  useEffect(() => {
    encounterApi.getById(id)
      .then(async r => {
        setEncounter(r.data);
        // Load related data keyed by patient if available
        if (r.data.patientId) {
          try { const lab = await labApi.getOrdersByPatient(r.data.patientId); setLabOrders(lab.data.slice(0, 5)); } catch {}
          try { const rx  = await prescriptionApi.getByPatient(r.data.patientId); setPrescriptions(rx.data.slice(0, 5)); } catch {}
        }
      })
      .catch(() => setError('Encounter not found.'))
      .finally(() => setLoading(false));
  }, [id]);

  if (loading) return <Spinner />;
  if (!encounter) return <ErrorAlert message={error || 'Not found.'} />;

  return (
    <div>
      <div className="page-header">
        <h2>Encounter #{encounter.id}</h2>
        <div className="btn-actions">
          <Link to={`/patients/${encounter.patientId}`} className="btn btn-outline">View Patient</Link>
          <Link to="/encounters" className="btn btn-secondary">← Back</Link>
        </div>
      </div>
      <ErrorAlert message={error} onDismiss={() => setError('')} />

      <div className="card">
        <div className="card-header"><h2>Encounter Details</h2></div>
        <div className="card-body">
          <div className="detail-grid">
            {[['Encounter ID', encounter.id], ['Date', encounter.encounterDate],
              ['Patient ID', encounter.patientId], ['Provider ID', encounter.providerId],
              ['Appointment ID', encounter.appointmentId], ['Status', encounter.status],
              ['Diagnosis', encounter.diagnosis], ['Chief Complaint', encounter.chiefComplaint],
              ['Notes', encounter.notes]].map(([l, v]) => (
              <div key={l} className="detail-item">
                <div className="detail-label">{l}</div>
                <div className="detail-value">{v || '–'}</div>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="card">
        <div className="card-header">
          <h2>Recent Lab Orders</h2>
          <Link to="/lab/new" className="btn btn-success btn-sm">+ New Lab Order</Link>
        </div>
        <div className="table-responsive">
          <table>
            <thead><tr><th>ID</th><th>Test</th><th>Date</th><th>Status</th><th></th></tr></thead>
            <tbody>
              {labOrders.length === 0
                ? <tr><td colSpan={5} className="text-muted" style={{textAlign:'center',padding:12}}>No lab orders.</td></tr>
                : labOrders.map(o => (
                  <tr key={o.id}>
                    <td>{o.id}</td><td>{o.testName}</td><td>{o.orderDate}</td>
                    <td>{o.status}</td>
                    <td><Link to={`/lab/${o.id}`} className="btn btn-outline btn-sm">View</Link></td>
                  </tr>))}
            </tbody>
          </table>
        </div>
      </div>

      <div className="card">
        <div className="card-header">
          <h2>Recent Prescriptions</h2>
          <Link to="/prescriptions/new" className="btn btn-success btn-sm">+ New Prescription</Link>
        </div>
        <div className="table-responsive">
          <table>
            <thead><tr><th>ID</th><th>Date</th><th>Status</th><th></th></tr></thead>
            <tbody>
              {prescriptions.length === 0
                ? <tr><td colSpan={4} className="text-muted" style={{textAlign:'center',padding:12}}>No prescriptions.</td></tr>
                : prescriptions.map(rx => (
                  <tr key={rx.id}>
                    <td>{rx.id}</td><td>{rx.prescriptionDate}</td><td>{rx.status}</td>
                    <td><Link to={`/prescriptions/${rx.id}`} className="btn btn-outline btn-sm">View</Link></td>
                  </tr>))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
