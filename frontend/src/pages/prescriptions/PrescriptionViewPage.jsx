import { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { prescriptionApi } from '../../api/prescriptionApi';
import { medicationApi }   from '../../api/medicationApi';
import Spinner from '../../components/Spinner';
import ErrorAlert from '../../components/ErrorAlert';

export default function PrescriptionViewPage() {
  const { id } = useParams();
  const [prescription, setPrescription] = useState(null);
  const [items, setItems]               = useState([]);
  const [medications, setMedications]   = useState([]);
  const [newItem, setNewItem]           = useState({ medicationId: '', dosage: '', frequency: '', duration: '', instructions: '' });
  const [loading, setLoading] = useState(true);
  const [saving,  setSaving]  = useState(false);
  const [error,   setError]   = useState('');

  useEffect(() => {
    Promise.all([
      prescriptionApi.getById(id),
      prescriptionApi.getItems(id),
      medicationApi.getAll(),
    ]).then(([rx, it, meds]) => {
      setPrescription(rx.data);
      setItems(it.data);
      setMedications(meds.data);
    }).catch(() => setError('Failed to load prescription.'))
      .finally(() => setLoading(false));
  }, [id]);

  const medName = (medId) => { const m = medications.find(x => String(x.id) === String(medId)); return m ? `${m.name} (${m.strength})` : `#${medId}`; };

  const handleAddItem = async (e) => {
    e.preventDefault(); setError('');
    if (!newItem.medicationId) { setError('Please select a medication.'); return; }
    setSaving(true);
    try {
      const r = await prescriptionApi.addItem(id, { ...newItem, medicationId: Number(newItem.medicationId) });
      setItems(prev => [...prev, r.data]);
      setNewItem({ medicationId: '', dosage: '', frequency: '', duration: '', instructions: '' });
    } catch { setError('Failed to add item.'); }
    finally { setSaving(false); }
  };

  if (loading) return <Spinner />;
  if (!prescription) return <ErrorAlert message={error || 'Not found.'} />;

  return (
    <div>
      <div className="page-header">
        <h2>Prescription #{prescription.id}</h2>
        <div className="btn-actions">
          <Link to={`/patients/${prescription.patientId}`} className="btn btn-outline">View Patient</Link>
          <Link to="/prescriptions" className="btn btn-secondary">← Back</Link>
        </div>
      </div>
      <ErrorAlert message={error} onDismiss={() => setError('')} />

      <div className="card">
        <div className="card-header"><h2>Prescription Details</h2></div>
        <div className="card-body">
          <div className="detail-grid">
            {[['ID', prescription.id], ['Date', prescription.prescriptionDate],
              ['Patient ID', prescription.patientId], ['Provider ID', prescription.providerId],
              ['Status', prescription.status || 'Active'], ['Notes', prescription.notes]].map(([l, v]) => (
              <div key={l} className="detail-item">
                <div className="detail-label">{l}</div>
                <div className="detail-value">{v || '–'}</div>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="card">
        <div className="card-header"><h2>Medications ({items.length})</h2></div>
        {items.length > 0 && (
          <div className="table-responsive">
            <table>
              <thead><tr><th>Medication</th><th>Dosage</th><th>Frequency</th><th>Duration</th><th>Instructions</th></tr></thead>
              <tbody>
                {items.map(item => (
                  <tr key={item.id}>
                    <td><strong>{medName(item.medicationId)}</strong></td>
                    <td>{item.dosage}</td>
                    <td>{item.frequency}</td>
                    <td>{item.duration}</td>
                    <td>{item.instructions}</td>
                  </tr>))}
              </tbody>
            </table>
          </div>
        )}
        <div className="card-body">
          <div className="section-title">Add Medication</div>
          <form onSubmit={handleAddItem}>
            <div className="form-row">
              <div className="form-group">
                <label>Medication *</label>
                <select className="form-control" value={newItem.medicationId} onChange={e => setNewItem(n => ({...n, medicationId: e.target.value}))} required>
                  <option value="">– select –</option>
                  {medications.map(m => <option key={m.id} value={m.id}>{m.name} – {m.strength}</option>)}
                </select>
              </div>
              <div className="form-group"><label>Dosage</label><input className="form-control" placeholder="e.g. 1 tablet" value={newItem.dosage} onChange={e => setNewItem(n => ({...n, dosage: e.target.value}))} /></div>
              <div className="form-group"><label>Frequency</label><input className="form-control" placeholder="e.g. Twice daily" value={newItem.frequency} onChange={e => setNewItem(n => ({...n, frequency: e.target.value}))} /></div>
              <div className="form-group"><label>Duration</label><input className="form-control" placeholder="e.g. 7 days" value={newItem.duration} onChange={e => setNewItem(n => ({...n, duration: e.target.value}))} /></div>
            </div>
            <div className="form-group"><label>Instructions</label><input className="form-control" value={newItem.instructions} onChange={e => setNewItem(n => ({...n, instructions: e.target.value}))} /></div>
            <button type="submit" className="btn btn-primary" disabled={saving}>{saving ? 'Adding…' : 'Add Medication'}</button>
          </form>
        </div>
      </div>
    </div>
  );
}
