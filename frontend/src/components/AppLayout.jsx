import { Navigate, Outlet } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import Header from './Header';
import Sidebar from './Sidebar';

/** Wraps all authenticated pages: checks auth, renders header + sidebar + content. */
export default function AppLayout() {
  const { isAuthenticated } = useAuth();
  if (!isAuthenticated) return <Navigate to="/login" replace />;

  return (
    <>
      {/* Animated mesh background — sits behind everything */}
      <div className="mesh-bg">
        <div className="orb1" />
        <div className="orb2" />
        <div className="orb3" />
        <div className="grain" />
      </div>

      <div className="app-shell">
        <Header />
        <div className="main-wrapper">
          <Sidebar />
          <main className="page-content">
            <Outlet />
          </main>
        </div>
      </div>
    </>
  );
}
