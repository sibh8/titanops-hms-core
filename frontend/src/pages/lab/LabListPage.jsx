import { useState, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { labApi } from '../../api/labApi';
import { patientApi } from '../../api/patientApi';
import Spinner from '../../components/Spinner';
import ErrorAlert from '../../components/ErrorAlert';

export default function LabListPage() {
  const [orders, setOrders]   = useState([]);
  const [patients, setPatients] = useState([]);
  const [showAll, setShowAll]   = useState(false);
  const [loading, setLoading]   = useState(true);
  const [error,   setError]     = useState('');

  const load = useCallback(async (all = false) => {
    setLoading(true); setError('');
    try {
      const [labRes, pRes] = await Promise.all([
        all ? labApi.getAllOrders() : labApi.getPendingOrders(),
        patientApi.getAll(),
      ]);
      setOrders(labRes.data);
      setPatients(pRes.data);
    } catch { setError('Failed to load lab orders.'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(showAll); }, [load, showAll]);

  const patientName = (id) => { const p = patients.find(x => String(x.id) === String(id)); return p ? `${p.firstName} ${p.lastName}` : `#${id}`; };

  const STATUS_BADGE = { Pending: 'warning', Completed: 'success', Cancelled: 'danger' };

  return (
    <div>
      <div className="page-header">
        <h2>Lab Orders {!showAll && <span className="badge badge-warning" style={{fontSize:'0.75rem',marginLeft:8}}>Pending only</span>}</h2>
        <div className="btn-actions">
          <button className="btn btn-outline btn-sm" onClick={() => setShowAll(s => !s)}>{showAll ? 'Show Pending Only' : 'Show All Orders'}</button>
          <Link to="/lab/new" className="btn btn-success">+ New Lab Order</Link>
        </div>
      </div>
      <ErrorAlert message={error} onDismiss={() => setError('')} />
      {loading ? <Spinner /> : (
        <div className="card">
          <div className="table-responsive">
            <table>
              <thead><tr><th>ID</th><th>Patient</th><th>Test Name</th><th>Order Date</th><th>Status</th><th>Actions</th></tr></thead>
              <tbody>
                {orders.length === 0
                  ? <tr><td colSpan={6} className="text-muted" style={{textAlign:'center',padding:20}}>No lab orders found.</td></tr>
                  : orders.map(o => (
                    <tr key={o.id}>
                      <td>{o.id}</td>
                      <td><Link to={`/patients/${o.patientId}`}>{patientName(o.patientId)}</Link></td>
                      <td>{o.testName}</td>
                      <td>{o.orderDate}</td>
                      <td><span className={`badge badge-${STATUS_BADGE[o.status] || 'secondary'}`}>{o.status}</span></td>
                      <td><Link to={`/lab/${o.id}`} className="btn btn-outline btn-sm">View</Link></td>
                    </tr>))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
