import { useState, useEffect } from 'react';
import { useNavigate, useParams, Link } from 'react-router-dom';
import { billingApi }   from '../../api/billingApi';
import { patientApi }   from '../../api/patientApi';
import { encounterApi } from '../../api/encounterApi';
import ErrorAlert from '../../components/ErrorAlert';
import Spinner from '../../components/Spinner';

const STATUS_OPTIONS = ['Draft', 'Pending', 'Paid', 'Partially Paid', 'Cancelled'];

export default function InvoiceFormPage() {
  const { id } = useParams();
  const isEdit  = Boolean(id);
  const navigate = useNavigate();

  const [form, setForm]           = useState({ patientId: '', encounterId: '', totalAmount: '', amountPaid: '', status: 'Draft', notes: '' });
  const [patients, setPatients]   = useState([]);
  const [encounters, setEncounters] = useState([]);
  const [loading, setLoading]     = useState(true);
  const [saving,  setSaving]      = useState(false);
  const [error,   setError]       = useState('');

  useEffect(() => {
    const fetches = [patientApi.getAll(), encounterApi.getAll()];
    if (isEdit) fetches.push(billingApi.getById(id));
    Promise.all(fetches).then(results => {
      setPatients(results[0].data);
      setEncounters(results[1].data);
      if (isEdit) {
        const inv = results[2].data;
        setForm({
          patientId:    String(inv.patientId   || ''),
          encounterId:  String(inv.encounterId || ''),
          totalAmount:  String(inv.totalAmount  || ''),
          amountPaid:   String(inv.amountPaid   || ''),
          status:       inv.status  || 'Draft',
          notes:        inv.notes   || '',
        });
      }
    }).catch(() => setError('Failed to load form data.'))
      .finally(() => setLoading(false));
  }, [id, isEdit]);

  const handleChange = e => setForm(f => ({...f, [e.target.name]: e.target.value}));

  const handleSubmit = async e => {
    e.preventDefault(); setError('');
    setSaving(true);
    try {
      const payload = {
        ...form,
        patientId:   Number(form.patientId)   || null,
        encounterId: Number(form.encounterId) || null,
        totalAmount: parseFloat(form.totalAmount) || 0,
        amountPaid:  parseFloat(form.amountPaid)  || 0,
      };
      if (isEdit) { await billingApi.update(id, payload); navigate(`/billing/${id}`); }
      else        { const r = await billingApi.create(payload); navigate(`/billing/${r.data.id}`); }
    } catch (err) { setError(err.response?.data?.message || 'Failed to save invoice.'); }
    finally { setSaving(false); }
  };

  if (loading) return <Spinner />;

  return (
    <div>
      <div className="page-header">
        <h2>{isEdit ? 'Edit Invoice' : 'New Invoice'}</h2>
        <Link to="/billing" className="btn btn-secondary">← Back</Link>
      </div>
      <div className="card"><div className="card-body">
        <ErrorAlert message={error} onDismiss={() => setError('')} />
        <form onSubmit={handleSubmit}>
          <div className="form-row">
            <div className="form-group">
              <label>Patient *</label>
              <select name="patientId" className="form-control" value={form.patientId} onChange={handleChange} required>
                <option value="">– select patient –</option>
                {patients.map(p => <option key={p.id} value={p.id}>{p.firstName} {p.lastName}</option>)}
              </select>
            </div>
            <div className="form-group">
              <label>Encounter</label>
              <select name="encounterId" className="form-control" value={form.encounterId} onChange={handleChange}>
                <option value="">– none –</option>
                {encounters.filter(e => !form.patientId || String(e.patientId) === form.patientId).map(e => <option key={e.id} value={e.id}>#{e.id} – {e.encounterDate}</option>)}
              </select>
            </div>
          </div>
          <div className="form-row">
            <div className="form-group">
              <label>Total Amount</label>
              <input type="number" step="0.01" min="0" name="totalAmount" className="form-control" value={form.totalAmount} onChange={handleChange} />
            </div>
            <div className="form-group">
              <label>Amount Paid</label>
              <input type="number" step="0.01" min="0" name="amountPaid" className="form-control" value={form.amountPaid} onChange={handleChange} />
            </div>
            <div className="form-group">
              <label>Status</label>
              <select name="status" className="form-control" value={form.status} onChange={handleChange}>
                {STATUS_OPTIONS.map(s => <option key={s}>{s}</option>)}
              </select>
            </div>
          </div>
          <div className="form-group"><label>Notes</label><textarea name="notes" className="form-control" rows={2} value={form.notes} onChange={handleChange} /></div>
          <div className="btn-actions mt-3">
            <button type="submit" className="btn btn-primary" disabled={saving}>{saving ? 'Saving…' : isEdit ? 'Update Invoice' : 'Create Invoice'}</button>
            <Link to="/billing" className="btn btn-secondary">Cancel</Link>
          </div>
        </form>
      </div></div>
    </div>
  );
}
