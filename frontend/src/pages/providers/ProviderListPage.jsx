import { useState, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { providerApi } from '../../api/providerApi';
import Spinner from '../../components/Spinner';
import ErrorAlert from '../../components/ErrorAlert';

export default function ProviderListPage() {
  const [providers, setProviders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error,   setError]   = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    try { const r = await providerApi.getAll(); setProviders(r.data); }
    catch { setError('Failed to load providers.'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  const handleDelete = async (id) => {
    if (!window.confirm('Delete this provider?')) return;
    try { await providerApi.remove(id); setProviders(p => p.filter(x => x.id !== id)); }
    catch { setError('Failed to delete provider.'); }
  };

  return (
    <div>
      <div className="page-header">
        <h2>Providers</h2>
        <Link to="/providers/new" className="btn btn-success">+ New Provider</Link>
      </div>
      <ErrorAlert message={error} onDismiss={() => setError('')} />
      {loading ? <Spinner /> : (
        <div className="card">
          <div className="table-responsive">
            <table>
              <thead><tr><th>ID</th><th>Name</th><th>Speciality</th><th>License No.</th><th>Phone</th><th>Active</th><th>Actions</th></tr></thead>
              <tbody>
                {providers.length === 0
                  ? <tr><td colSpan={7} className="text-muted" style={{textAlign:'center',padding:20}}>No providers found.</td></tr>
                  : providers.map(p => (
                    <tr key={p.id}>
                      <td>{p.id}</td>
                      <td>{p.firstName} {p.lastName}</td>
                      <td>{p.speciality}</td>
                      <td>{p.licenseNumber}</td>
                      <td>{p.phone}</td>
                      <td><span className={`badge badge-${p.active ? 'success' : 'secondary'}`}>{p.active ? 'Active' : 'Inactive'}</span></td>
                      <td>
                        <div className="btn-actions">
                          <Link to={`/providers/${p.id}/edit`} className="btn btn-warning btn-sm">Edit</Link>
                          <button className="btn btn-danger btn-sm" onClick={() => handleDelete(p.id)}>Del</button>
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
