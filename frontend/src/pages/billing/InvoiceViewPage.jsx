import { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { billingApi } from '../../api/billingApi';
import { patientApi } from '../../api/patientApi';
import Spinner from '../../components/Spinner';
import ErrorAlert from '../../components/ErrorAlert';

const STATUS_BADGE = { Draft: 'secondary', Finalized: 'info', Paid: 'success', Overdue: 'danger' };

export default function InvoiceViewPage() {
  const { id } = useParams();
  const [invoice, setInvoice] = useState(null);
  const [patient, setPatient] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error,   setError]   = useState('');

  useEffect(() => {
    billingApi.getById(id)
      .then(async r => {
        setInvoice(r.data);
        if (r.data.patientId) {
          try { const p = await patientApi.getById(r.data.patientId); setPatient(p.data); } catch {}
        }
      })
      .catch(() => setError('Invoice not found.'))
      .finally(() => setLoading(false));
  }, [id]);

  if (loading) return <Spinner />;
  if (!invoice) return <ErrorAlert message={error || 'Not found.'} />;

  return (
    <div>
      <div className="page-header">
        <h2>Invoice #{invoice.id}</h2>
        <div className="btn-actions">
          <Link to={`/billing/${id}/edit`} className="btn btn-warning">Edit</Link>
          <Link to="/billing" className="btn btn-secondary">← Back</Link>
        </div>
      </div>
      <ErrorAlert message={error} onDismiss={() => setError('')} />

      <div className="card">
        <div className="card-header"><h2>Invoice Details</h2></div>
        <div className="card-body">
          <div className="detail-grid">
            {[
              ['Invoice ID', invoice.id],
              ['Date', invoice.invoiceDate],
              ['Status', <span className={`badge badge-${STATUS_BADGE[invoice.status] || 'secondary'}`}>{invoice.status}</span>],
              ['Patient', patient ? <Link to={`/patients/${patient.id}`}>{patient.firstName} {patient.lastName}</Link> : `#${invoice.patientId}`],
              ['Encounter ID', invoice.encounterId || '–'],
              ['Total Amount', <strong>${invoice.totalAmount || '0.00'}</strong>],
            ].map(([l, v]) => (
              <div key={l} className="detail-item">
                <div className="detail-label">{l}</div>
                <div className="detail-value">{v}</div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {invoice.notes && (
        <div className="card">
          <div className="card-header"><h2>Notes</h2></div>
          <div className="card-body">{invoice.notes}</div>
        </div>
      )}
    </div>
  );
}
