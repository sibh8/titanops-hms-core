import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

const initials = (s = '') => s.slice(0, 2).toUpperCase();

export default function Header() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const handleLogout = () => { logout(); navigate('/login'); };

  return (
    <header className="app-header">
      {/* Brand */}
      <div className="header-brand">
        <div className="header-brand-badge">
          <svg viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
            <path d="M22 12h-4l-3 9L9 3l-3 9H2"/>
          </svg>
        </div>
        <span className="header-brand-name">MediCore HMS</span>
        <span className="header-brand-tag">v2.0</span>
      </div>

      {/* Search */}
      <div className="header-search">
        <svg className="search-ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
        </svg>
        <input type="text" placeholder="Search patients, appointments…" />
      </div>

      {user && (
        <div className="header-right">
          <button className="header-icon-btn" title="Notifications">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/>
            </svg>
            <span className="header-badge-dot" />
          </button>
          <button className="header-icon-btn" title="Calendar">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>
            </svg>
          </button>
          <div className="header-divider" />
          <div className="header-user">
            <div className="avatar">{initials(user.username)}</div>
            <div>
              <div className="header-user-name">{user.username}</div>
              <div className="header-user-role">{user.role || 'Staff'}</div>
            </div>
          </div>
          <button className="header-logout-btn" onClick={handleLogout}>Sign out</button>
        </div>
      )}
    </header>
  );
}
