import { useState, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { userApi } from '../../api/userApi';
import Spinner from '../../components/Spinner';
import ErrorAlert from '../../components/ErrorAlert';

export default function UserListPage() {
  const [users, setUsers]   = useState([]);
  const [loading, setLoading] = useState(true);
  const [error,   setError]   = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    try { const r = await userApi.getAll(); setUsers(r.data); }
    catch { setError('Failed to load users.'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  const handleDelete = async (id) => {
    if (!window.confirm('Delete this user?')) return;
    try { await userApi.remove(id); setUsers(u => u.filter(x => x.id !== id)); }
    catch { setError('Failed to delete user.'); }
  };

  return (
    <div>
      <div className="page-header">
        <h2>Users</h2>
        <Link to="/users/new" className="btn btn-success">+ New User</Link>
      </div>
      <ErrorAlert message={error} onDismiss={() => setError('')} />
      {loading ? <Spinner /> : (
        <div className="card">
          <div className="table-responsive">
            <table>
              <thead><tr><th>ID</th><th>Username</th><th>Email</th><th>Role</th><th>Active</th><th>Actions</th></tr></thead>
              <tbody>
                {users.length === 0
                  ? <tr><td colSpan={6} className="text-muted" style={{textAlign:'center',padding:20}}>No users found.</td></tr>
                  : users.map(u => (
                    <tr key={u.id}>
                      <td>{u.id}</td><td><strong>{u.username}</strong></td><td>{u.email}</td>
                      <td><span className="badge badge-info">{u.role}</span></td>
                      <td><span className={`badge badge-${u.active ? 'success' : 'secondary'}`}>{u.active ? 'Active' : 'Inactive'}</span></td>
                      <td>
                        <div className="btn-actions">
                          <Link to={`/users/${u.id}/edit`} className="btn btn-warning btn-sm">Edit</Link>
                          <button className="btn btn-danger btn-sm" onClick={() => handleDelete(u.id)}>Del</button>
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
