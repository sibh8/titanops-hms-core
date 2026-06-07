import { useState, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { encounterApi } from '../../api/encounterApi';
import Spinner from '../../components/Spinner';
import ErrorAlert from '../../components/ErrorAlert';

export default function EncounterListPage() {
  const [encounters, setEncounters] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error,   setError]   = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    try { const r = await encounterApi.getAll(); setEncounters(r.data); }
    catch { setError('Failed to load encounters.'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  return (
    <div>
      <div className="page-header"><h2>Encounters</h2></div>
      <ErrorAlert message={error} onDismiss={() => setError('')} />
      {loading ? <Spinner /> : (
        <div className="card">
          <div className="table-responsive">
            <table>
              <thead><tr><th>ID</th><th>Patient ID</th><th>Provider ID</th><th>Date</th><th>Status</th><th>Diagnosis</th><th>Actions</th></tr></thead>
              <tbody>
                {encounters.length === 0
                  ? <tr><td colSpan={7} className="text-muted" style={{textAlign:'center',padding:20}}>No encounters found.</td></tr>
                  : encounters.map(e => (
                    <tr key={e.id}>
                      <td>{e.id}</td>
                      <td><Link to={`/patients/${e.patientId}`}>#{e.patientId}</Link></td>
                      <td>{e.providerId}</td>
                      <td>{e.encounterDate}</td>
                      <td><span className="badge badge-secondary">{e.status}</span></td>
                      <td>{e.diagnosis}</td>
                      <td><Link to={`/encounters/${e.id}`} className="btn btn-outline btn-sm">View</Link></td>
                    </tr>))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
