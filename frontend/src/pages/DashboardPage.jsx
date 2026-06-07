import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { patientApi }     from '../api/patientApi';
import { appointmentApi } from '../api/appointmentApi';
import { labApi }         from '../api/labApi';
import { billingApi }     from '../api/billingApi';
import Spinner from '../components/Spinner';

export default function DashboardPage() {
  const [stats, setStats]   = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.allSettled([
      patientApi.getAll(),
      appointmentApi.getAll(),
      labApi.getPendingOrders(),
      billingApi.getAll(),
    ]).then(([patients, appts, pendingLab, invoices]) => {
      setStats({
        patients:    patients.status  === 'fulfilled' ? patients.value.data.length   : '–',
        appointments:appts.status     === 'fulfilled' ? appts.value.data.length      : '–',
        pendingLab:  pendingLab.status === 'fulfilled' ? pendingLab.value.data.length : '–',
        invoices:    invoices.status  === 'fulfilled' ? invoices.value.data.length   : '–',
      });
      setLoading(false);
    });
  }, []);

  if (loading) return <Spinner />;

  const today = new Date().toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });

  const QUICK = [
    { to: '/patients/new',     color: 'rgba(99,102,241,0.2)',  stroke: '#a5b4fc', title: 'Register patient',      sub: 'Add to the system',
      icon: <><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><line x1="19" y1="8" x2="19" y2="14"/><line x1="22" y1="11" x2="16" y2="11"/></> },
    { to: '/appointments/new', color: 'rgba(139,92,246,0.2)',  stroke: '#c4b5fd', title: 'Schedule appointment',  sub: 'Book with a provider',
      icon: <><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></> },
    { to: '/lab/new',          color: 'rgba(245,158,11,0.2)',  stroke: '#fcd34d', title: 'Create lab order',      sub: 'Request diagnostic tests',
      icon: <path d="M9 3H5a2 2 0 0 0-2 2v4m6-6h10a2 2 0 0 1 2 2v4M9 3v11l-4 5h14l-4-5V3"/> },
    { to: '/prescriptions/new',color: 'rgba(16,185,129,0.2)',  stroke: '#6ee7b7', title: 'New prescription',      sub: 'Issue medication order',
      icon: <><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></> },
    { to: '/billing/new',      color: 'rgba(6,182,212,0.2)',   stroke: '#67e8f9', title: 'Create invoice',        sub: 'Bill for services',
      icon: <><rect x="1" y="4" width="22" height="16" rx="2"/><line x1="1" y1="10" x2="23" y2="10"/></> },
    { to: '/status',           color: 'rgba(236,72,153,0.18)', stroke: '#f9a8d4', title: 'Service status',        sub: 'Check system health',
      icon: <polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/> },
  ];

  const chevron = (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="9 18 15 12 9 6"/></svg>
  );

  return (
    <div>
      {/* Page header */}
      <div className="page-header">
        <div>
          <h2>Dashboard</h2>
          <div className="page-header-sub">{today}</div>
        </div>
        <Link to="/patients/new" className="btn btn-primary">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
          New Patient
        </Link>
      </div>

      {/* Gradient Stat Cards */}
      <div className="stat-grid">
        <Link to="/patients" className="stat-card stat-card--blue">
          <div className="stat-top">
            <div><div className="stat-label">Total Patients</div><div className="stat-value">{stats.patients}</div></div>
            <div className="stat-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg></div>
          </div>
          <div className="stat-sub">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><polyline points="18 15 12 9 6 15"/></svg>
            Registered patients
          </div>
        </Link>

        <Link to="/appointments" className="stat-card stat-card--purple">
          <div className="stat-top">
            <div><div className="stat-label">Appointments</div><div className="stat-value">{stats.appointments}</div></div>
            <div className="stat-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg></div>
          </div>
          <div className="stat-sub">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><polyline points="18 15 12 9 6 15"/></svg>
            Total scheduled
          </div>
        </Link>

        <Link to="/lab" className="stat-card stat-card--orange">
          <div className="stat-top">
            <div><div className="stat-label">Pending Lab Orders</div><div className="stat-value">{stats.pendingLab}</div></div>
            <div className="stat-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M9 3H5a2 2 0 0 0-2 2v4m6-6h10a2 2 0 0 1 2 2v4M9 3v11l-4 5h14l-4-5V3"/></svg></div>
          </div>
          <div className="stat-sub">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><polyline points="18 9 12 15 6 9"/></svg>
            Awaiting results
          </div>
        </Link>

        <Link to="/billing" className="stat-card stat-card--green">
          <div className="stat-top">
            <div><div className="stat-label">Invoices</div><div className="stat-value">{stats.invoices}</div></div>
            <div className="stat-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="1" y="4" width="22" height="16" rx="2"/><line x1="1" y1="10" x2="23" y2="10"/></svg></div>
          </div>
          <div className="stat-sub">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><polyline points="18 15 12 9 6 15"/></svg>
            Total invoices
          </div>
        </Link>
      </div>

      {/* Quick Actions */}
      <div className="card">
        <div className="card-header"><h2>Quick Actions</h2></div>
        <div className="card-body">
          <div className="quick-actions">
            {QUICK.map(({ to, color, stroke, title, sub, icon }) => (
              <Link key={to} to={to} className="quick-action-btn">
                <div className="quick-action-icon" style={{ background: color }}>
                  <svg viewBox="0 0 24 24" fill="none" stroke={stroke} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">{icon}</svg>
                </div>
                <div className="quick-action-text">
                  <div className="quick-action-title">{title}</div>
                  <div className="quick-action-sub">{sub}</div>
                </div>
                <div className="quick-action-arrow">{chevron}</div>
              </Link>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
