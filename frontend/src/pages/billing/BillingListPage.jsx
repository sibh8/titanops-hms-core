import { useState, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { billingApi } from '../../api/billingApi';
import Spinner from '../../components/Spinner';
import ErrorAlert from '../../components/ErrorAlert';

const STATUS_BADGE = { Draft: 'secondary', Finalized: 'info', Paid: 'success', Overdue: 'danger', Cancelled: 'danger' };

export default function BillingListPage() {
  const [invoices, setInvoices] = useState([]);
  const [loading, setLoading]   = useState(true);
  const [error,   setError]     = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    try { const r = await billingApi.getAll(); setInvoices(r.data); }
    catch { setError('Failed to load invoices.'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  return (
    <div>
      <div className="page-header">
        <h2>Invoices</h2>
        <Link to="/billing/new" className="btn btn-success">+ New Invoice</Link>
      </div>
      <ErrorAlert message={error} onDismiss={() => setError('')} />
      {loading ? <Spinner /> : (
        <div className="card">
          <div className="table-responsive">
            <table>
              <thead><tr><th>ID</th><th>Patient ID</th><th>Date</th><th>Total Amount</th><th>Status</th><th>Actions</th></tr></thead>
              <tbody>
                {invoices.length === 0
                  ? <tr><td colSpan={6} className="text-muted" style={{textAlign:'center',padding:20}}>No invoices found.</td></tr>
                  : invoices.map(i => (
                    <tr key={i.id}>
                      <td>{i.id}</td>
                      <td><Link to={`/patients/${i.patientId}`}>#{i.patientId}</Link></td>
                      <td>{i.invoiceDate}</td>
                      <td><strong>${i.totalAmount || '0.00'}</strong></td>
                      <td><span className={`badge badge-${STATUS_BADGE[i.status] || 'secondary'}`}>{i.status}</span></td>
                      <td><Link to={`/billing/${i.id}`} className="btn btn-outline btn-sm">View</Link></td>
                    </tr>))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
