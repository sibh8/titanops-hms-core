import { useState, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { prescriptionApi } from '../../api/prescriptionApi';
import Spinner from '../../components/Spinner';
import ErrorAlert from '../../components/ErrorAlert';

export default function PrescriptionListPage() {
  const [prescriptions, setPrescriptions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error,   setError]   = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    try { const r = await prescriptionApi.getAll(); setPrescriptions(r.data); }
    catch { setError('Failed to load prescriptions.'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  return (
    <div>
      <div className="page-header">
        <h2>Prescriptions</h2>
        <Link to="/prescriptions/new" className="btn btn-success">+ New Prescription</Link>
      </div>
      <ErrorAlert message={error} onDismiss={() => setError('')} />
      {loading ? <Spinner /> : (
        <div className="card">
          <div className="table-responsive">
            <table>
              <thead><tr><th>ID</th><th>Patient ID</th><th>Provider ID</th><th>Date</th><th>Status</th><th>Actions</th></tr></thead>
              <tbody>
                {prescriptions.length === 0
                  ? <tr><td colSpan={6} className="text-muted" style={{textAlign:'center',padding:20}}>No prescriptions found.</td></tr>
                  : prescriptions.map(rx => (
                    <tr key={rx.id}>
                      <td>{rx.id}</td>
                      <td><Link to={`/patients/${rx.patientId}`}>#{rx.patientId}</Link></td>
                      <td>{rx.providerId}</td>
                      <td>{rx.prescriptionDate}</td>
                      <td><span className="badge badge-secondary">{rx.status || 'Active'}</span></td>
                      <td><Link to={`/prescriptions/${rx.id}`} className="btn btn-outline btn-sm">View</Link></td>
                    </tr>))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
