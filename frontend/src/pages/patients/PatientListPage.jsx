import { useState, useEffect, useCallback } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { patientApi } from '../../api/patientApi';
import Spinner from '../../components/Spinner';
import ErrorAlert from '../../components/ErrorAlert';

export default function PatientListPage() {
  const [patients, setPatients] = useState([]);
  const [query, setQuery]       = useState('');
  const [loading, setLoading]   = useState(true);
  const [error, setError]       = useState('');
  const navigate = useNavigate();

  const load = useCallback(async (q = '') => {
    setLoading(true); setError('');
    try {
      const res = q.trim()
        ? await patientApi.search(q.trim())
        : await patientApi.getAll();
      setPatients(res.data);
    } catch (e) {
      setError(e.response?.data?.message || 'Failed to load patients.');
    } finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  const handleDelete = async (id) => {
    if (!window.confirm('Delete this patient?')) return;
    try { await patientApi.remove(id); setPatients((p) => p.filter((x) => x.id !== id)); }
    catch (e) { setError('Failed to delete patient.'); }
  };

  return (
    <div>
      <div className="page-header">
        <h2>Patients</h2>
        <Link to="/patients/new" className="btn btn-success">+ New Patient</Link>
      </div>
      <ErrorAlert message={error} onDismiss={() => setError('')} />
      <div className="search-bar">
        <input className="form-control" placeholder="Search by name…"
          value={query} onChange={(e) => setQuery(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && load(query)} />
        <button className="btn btn-primary" onClick={() => load(query)}>Search</button>
        {query && <button className="btn btn-secondary" onClick={() => { setQuery(''); load(''); }}>Clear</button>}
      </div>
      {loading ? <Spinner /> : (
        <div className="card">
          <div className="table-responsive">
            <table>
              <thead>
                <tr>
                  <th>ID</th><th>First Name</th><th>Last Name</th>
                  <th>Date of Birth</th><th>Gender</th><th>Phone</th><th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {patients.length === 0
                  ? <tr><td colSpan={7} className="text-muted" style={{textAlign:'center', padding:'20px'}}>No patients found.</td></tr>
                  : patients.map((p) => (
                    <tr key={p.id}>
                      <td>{p.id}</td>
                      <td>{p.firstName}</td>
                      <td>{p.lastName}</td>
                      <td>{p.dateOfBirth}</td>
                      <td>{p.gender}</td>
                      <td>{p.phone}</td>
                      <td>
                        <div className="btn-actions">
                          <Link to={`/patients/${p.id}`}       className="btn btn-outline btn-sm">View</Link>
                          <Link to={`/patients/${p.id}/edit`}  className="btn btn-warning btn-sm">Edit</Link>
                          <button className="btn btn-danger btn-sm" onClick={() => handleDelete(p.id)}>Del</button>
                        </div>
                      </td>
                    </tr>
                  ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
