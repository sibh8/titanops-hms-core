import { useState, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { medicationApi } from '../../api/medicationApi';
import Spinner from '../../components/Spinner';
import ErrorAlert from '../../components/ErrorAlert';

export default function MedicationListPage() {
  const [medications, setMedications] = useState([]);
  const [query, setQuery]   = useState('');
  const [loading, setLoading] = useState(true);
  const [error,   setError]   = useState('');

  const load = useCallback(async (q = '') => {
    setLoading(true);
    try {
      const r = q.trim() ? await medicationApi.search(q) : await medicationApi.getAll();
      setMedications(r.data);
    } catch { setError('Failed to load medications.'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  const handleDelete = async (id) => {
    if (!window.confirm('Delete this medication?')) return;
    try { await medicationApi.remove(id); setMedications(m => m.filter(x => x.id !== id)); }
    catch { setError('Failed to delete medication.'); }
  };

  return (
    <div>
      <div className="page-header">
        <h2>Medications</h2>
        <Link to="/medications/new" className="btn btn-success">+ New Medication</Link>
      </div>
      <ErrorAlert message={error} onDismiss={() => setError('')} />
      <div className="search-bar">
        <input className="form-control" placeholder="Search by name or generic name…"
          value={query} onChange={e => setQuery(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && load(query)} />
        <button className="btn btn-primary" onClick={() => load(query)}>Search</button>
        {query && <button className="btn btn-secondary" onClick={() => { setQuery(''); load(''); }}>Clear</button>}
      </div>
      {loading ? <Spinner /> : (
        <div className="card">
          <div className="table-responsive">
            <table>
              <thead><tr><th>ID</th><th>Name</th><th>Generic Name</th><th>Dosage Form</th><th>Strength</th><th>Actions</th></tr></thead>
              <tbody>
                {medications.length === 0
                  ? <tr><td colSpan={6} className="text-muted" style={{textAlign:'center',padding:20}}>No medications found.</td></tr>
                  : medications.map(m => (
                    <tr key={m.id}>
                      <td>{m.id}</td><td><strong>{m.name}</strong></td><td>{m.genericName}</td>
                      <td>{m.dosageForm}</td><td>{m.strength}</td>
                      <td>
                        <div className="btn-actions">
                          <Link to={`/medications/${m.id}/edit`} className="btn btn-warning btn-sm">Edit</Link>
                          <button className="btn btn-danger btn-sm" onClick={() => handleDelete(m.id)}>Del</button>
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
