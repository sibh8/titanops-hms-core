import { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { labApi } from '../../api/labApi';
import Spinner from '../../components/Spinner';
import ErrorAlert from '../../components/ErrorAlert';

export default function LabOrderViewPage() {
  const { id } = useParams();
  const [order,   setOrder]   = useState(null);
  const [results, setResults] = useState([]);
  const [newResult, setNewResult] = useState({ resultValue: '', unit: '', referenceRange: '', notes: '' });
  const [loading, setLoading] = useState(true);
  const [saving,  setSaving]  = useState(false);
  const [error,   setError]   = useState('');
  const [success, setSuccess] = useState('');

  useEffect(() => {
    Promise.all([labApi.getOrderById(id), labApi.getResultsByOrder(id)])
      .then(([o, r]) => { setOrder(o.data); setResults(r.data); })
      .catch(() => setError('Failed to load lab order.'))
      .finally(() => setLoading(false));
  }, [id]);

  const handleAddResult = async (e) => {
    e.preventDefault(); setError(''); setSuccess('');
    if (!newResult.resultValue) { setError('Result value is required.'); return; }
    setSaving(true);
    try {
      const res = await labApi.addResult({ ...newResult, labOrderId: Number(id) });
      setResults(r => [...r, res.data]);
      setOrder(o => ({ ...o, status: 'Completed' }));
      setNewResult({ resultValue: '', unit: '', referenceRange: '', notes: '' });
      setSuccess('Result added successfully.');
    } catch (err) { setError('Failed to add result.'); }
    finally { setSaving(false); }
  };

  if (loading) return <Spinner />;
  if (!order)  return <ErrorAlert message={error || 'Not found.'} />;

  return (
    <div>
      <div className="page-header">
        <h2>Lab Order #{order.id} — {order.testName}</h2>
        <Link to="/lab" className="btn btn-secondary">← Back</Link>
      </div>
      <ErrorAlert message={error} onDismiss={() => setError('')} />
      {success && <div className="alert alert-success">{success}</div>}

      <div className="card">
        <div className="card-header"><h2>Order Details</h2></div>
        <div className="card-body">
          <div className="detail-grid">
            {[['Patient ID', order.patientId], ['Test Name', order.testName],
              ['Order Date', order.orderDate], ['Status', order.status],
              ['Notes', order.notes]].map(([l, v]) => (
              <div key={l} className="detail-item"><div className="detail-label">{l}</div><div className="detail-value">{v || '–'}</div></div>
            ))}
          </div>
        </div>
      </div>

      <div className="card">
        <div className="card-header"><h2>Results ({results.length})</h2></div>
        {results.length > 0 && (
          <div className="table-responsive">
            <table>
              <thead><tr><th>Value</th><th>Unit</th><th>Reference Range</th><th>Date</th><th>Notes</th></tr></thead>
              <tbody>
                {results.map(r => (
                  <tr key={r.id}>
                    <td><strong>{r.resultValue}</strong></td>
                    <td>{r.unit}</td>
                    <td>{r.referenceRange}</td>
                    <td>{r.resultDate}</td>
                    <td>{r.notes}</td>
                  </tr>))}
              </tbody>
            </table>
          </div>
        )}
        {order.status === 'Pending' && (
          <div className="card-body">
            <div className="section-title">Add Result</div>
            <form onSubmit={handleAddResult}>
              <div className="form-row">
                <div className="form-group"><label>Result Value *</label><input name="resultValue" className="form-control" value={newResult.resultValue} onChange={e => setNewResult(r => ({...r, resultValue: e.target.value}))} required /></div>
                <div className="form-group"><label>Unit</label><input name="unit" className="form-control" value={newResult.unit} onChange={e => setNewResult(r => ({...r, unit: e.target.value}))} /></div>
                <div className="form-group"><label>Reference Range</label><input name="referenceRange" className="form-control" value={newResult.referenceRange} onChange={e => setNewResult(r => ({...r, referenceRange: e.target.value}))} /></div>
              </div>
              <div className="form-group"><label>Notes</label><textarea className="form-control" rows={2} value={newResult.notes} onChange={e => setNewResult(r => ({...r, notes: e.target.value}))} /></div>
              <button type="submit" className="btn btn-primary" disabled={saving}>{saving ? 'Saving…' : 'Add Result'}</button>
            </form>
          </div>
        )}
      </div>
    </div>
  );
}
