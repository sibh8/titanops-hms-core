import { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { medicationApi } from '../../api/medicationApi';
import ErrorAlert from '../../components/ErrorAlert';
import Spinner from '../../components/Spinner';

const FORMS = ['Tablet','Capsule','Syrup','Injection','Cream','Ointment','Drops','Inhaler','Patch','Other'];
const EMPTY = { name: '', genericName: '', dosageForm: 'Tablet', strength: '', manufacturer: '', description: '' };

export default function MedicationFormPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const isEdit = Boolean(id);
  const [form, setForm]     = useState(EMPTY);
  const [loading, setLoading] = useState(isEdit);
  const [saving,  setSaving]  = useState(false);
  const [error,   setError]   = useState('');

  useEffect(() => {
    if (!isEdit) return;
    medicationApi.getById(id)
      .then(r => setForm(r.data))
      .catch(() => setError('Failed to load medication.'))
      .finally(() => setLoading(false));
  }, [id, isEdit]);

  const handleChange = e => setForm(f => ({ ...f, [e.target.name]: e.target.value }));

  const handleSubmit = async e => {
    e.preventDefault(); setError('');
    if (!form.name) { setError('Name is required.'); return; }
    setSaving(true);
    try {
      if (isEdit) await medicationApi.update(id, form);
      else        await medicationApi.create(form);
      navigate('/medications');
    } catch (err) { setError(err.response?.data?.message || 'Failed to save medication.'); }
    finally { setSaving(false); }
  };

  if (loading) return <Spinner />;

  return (
    <div>
      <div className="page-header">
        <h2>{isEdit ? 'Edit Medication' : 'New Medication'}</h2>
        <Link to="/medications" className="btn btn-secondary">← Back</Link>
      </div>
      <div className="card"><div className="card-body">
        <ErrorAlert message={error} onDismiss={() => setError('')} />
        <form onSubmit={handleSubmit}>
          <div className="form-row">
            <div className="form-group"><label>Brand Name *</label><input name="name" className="form-control" value={form.name} onChange={handleChange} required /></div>
            <div className="form-group"><label>Generic Name</label><input name="genericName" className="form-control" value={form.genericName || ''} onChange={handleChange} /></div>
          </div>
          <div className="form-row">
            <div className="form-group">
              <label>Dosage Form</label>
              <select name="dosageForm" className="form-control" value={form.dosageForm || ''} onChange={handleChange}>
                {FORMS.map(f => <option key={f}>{f}</option>)}
              </select>
            </div>
            <div className="form-group"><label>Strength</label><input name="strength" className="form-control" placeholder="e.g. 500mg" value={form.strength || ''} onChange={handleChange} /></div>
            <div className="form-group"><label>Manufacturer</label><input name="manufacturer" className="form-control" value={form.manufacturer || ''} onChange={handleChange} /></div>
          </div>
          <div className="form-group"><label>Description</label><textarea name="description" className="form-control" rows={2} value={form.description || ''} onChange={handleChange} /></div>
          <div className="btn-actions mt-3">
            <button type="submit" className="btn btn-primary" disabled={saving}>{saving ? 'Saving…' : 'Save Medication'}</button>
            <Link to="/medications" className="btn btn-secondary">Cancel</Link>
          </div>
        </form>
      </div></div>
    </div>
  );
}
