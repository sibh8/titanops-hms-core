import { useState, useEffect, useCallback } from 'react';
import { SERVICES, pingAllServices, pingService } from '../api/healthApi';
import Spinner from '../components/Spinner';

const STATUS_COLOR = { UP: '#22c55e', DOWN: '#ef4444', CHECKING: '#f59e0b' };
const STATUS_BADGE = { UP: 'badge-success', DOWN: 'badge-danger', CHECKING: 'badge-warning' };

const TOOL_URLS = [
  { label: 'Jaeger UI',   url: 'http://localhost:16686', desc: 'Distributed tracing' },
  { label: 'Grafana',     url: 'http://localhost:3001',  desc: 'Metrics dashboards'  },
  { label: 'Prometheus',  url: 'http://localhost:9090',  desc: 'Metrics scraping'    },
];

function dot(status) {
  return (
    <span style={{
      display: 'inline-block', width: 10, height: 10, borderRadius: '50%',
      backgroundColor: STATUS_COLOR[status] || STATUS_COLOR.CHECKING,
      marginRight: 6,
    }} />
  );
}

export default function ServiceStatusPage() {
  const initial = SERVICES.map(s => ({ id: s.id, status: 'CHECKING', responseTimeMs: null, details: {} }));
  const [results, setResults] = useState(initial);
  const [loading, setLoading] = useState(true);
  const [lastRefresh, setLastRefresh] = useState(null);

  const refresh = useCallback(async () => {
    setLoading(true);
    setResults(SERVICES.map(s => ({ id: s.id, status: 'CHECKING', responseTimeMs: null, details: {} })));
    const data = await pingAllServices();
    setResults(data);
    setLastRefresh(new Date());
    setLoading(false);
  }, []);

  useEffect(() => { refresh(); }, [refresh]);

  const refreshOne = async (svc) => {
    setResults(prev => prev.map(r => r.id === svc.id ? { ...r, status: 'CHECKING' } : r));
    const data = await pingService(svc);
    setResults(prev => prev.map(r => r.id === svc.id ? data : r));
  };

  const upCount   = results.filter(r => r.status === 'UP').length;
  const downCount = results.filter(r => r.status === 'DOWN').length;

  return (
    <div>
      <div className="page-header">
        <h2>Service Status</h2>
        <button className="btn btn-primary" onClick={refresh} disabled={loading}>
          {loading ? 'Checking…' : '↻ Refresh All'}
        </button>
      </div>

      {/* Summary bar */}
      <div className="dashboard-stats" style={{ marginBottom: 24 }}>
        <div className="stat-card">
          <div className="stat-value" style={{ color: STATUS_COLOR.UP }}>{upCount}</div>
          <div className="stat-label">Services UP</div>
        </div>
        <div className="stat-card">
          <div className="stat-value" style={{ color: downCount > 0 ? STATUS_COLOR.DOWN : '#6b7280' }}>{downCount}</div>
          <div className="stat-label">Services DOWN</div>
        </div>
        <div className="stat-card">
          <div className="stat-value">{SERVICES.length}</div>
          <div className="stat-label">Total Services</div>
        </div>
        <div className="stat-card">
          <div className="stat-value" style={{ fontSize: '0.9rem' }}>
            {lastRefresh ? lastRefresh.toLocaleTimeString() : '–'}
          </div>
          <div className="stat-label">Last Checked</div>
        </div>
      </div>

      {/* Service cards */}
      <div className="card">
        <div className="card-header"><h2>Microservices</h2></div>
        <div className="table-responsive">
          <table>
            <thead>
              <tr>
                <th>Service</th>
                <th>Port</th>
                <th>Status</th>
                <th>Response Time</th>
                <th>DB</th>
                <th>Disk</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {SERVICES.map(svc => {
                const r = results.find(x => x.id === svc.id) || {};
                const dbStatus   = r.details?.db?.status;
                const diskStatus = r.details?.diskSpace?.status;
                return (
                  <tr key={svc.id}>
                    <td><strong>{svc.label}</strong></td>
                    <td><code>{svc.port}</code></td>
                    <td>
                      {dot(r.status || 'CHECKING')}
                      <span className={`badge ${STATUS_BADGE[r.status] || 'badge-warning'}`}>
                        {r.status || 'CHECKING'}
                      </span>
                    </td>
                    <td>
                      {r.responseTimeMs != null
                        ? <span style={{ color: r.responseTimeMs > 500 ? '#f59e0b' : 'inherit' }}>{r.responseTimeMs} ms</span>
                        : <span className="text-muted">–</span>}
                    </td>
                    <td>
                      {dbStatus
                        ? <span className={`badge ${dbStatus === 'UP' ? 'badge-success' : 'badge-danger'}`}>{dbStatus}</span>
                        : <span className="text-muted">–</span>}
                    </td>
                    <td>
                      {diskStatus
                        ? <span className={`badge ${diskStatus === 'UP' ? 'badge-success' : 'badge-danger'}`}>{diskStatus}</span>
                        : <span className="text-muted">–</span>}
                    </td>
                    <td>
                      <button
                        className="btn btn-outline btn-sm"
                        onClick={() => refreshOne(svc)}
                        disabled={r.status === 'CHECKING'}
                      >
                        Ping
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* API endpoint reference */}
      <div className="card" style={{ marginTop: 24 }}>
        <div className="card-header"><h2>API Endpoints</h2></div>
        <div className="table-responsive">
          <table>
            <thead><tr><th>Service</th><th>API Path</th><th>Actuator Health</th></tr></thead>
            <tbody>
              {SERVICES.map(svc => (
                <tr key={svc.id}>
                  <td>{svc.label}</td>
                  <td><code>{svc.apiPath}</code></td>
                  <td><code>/health/{svc.id}</code></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Observability tools */}
      <div className="card" style={{ marginTop: 24 }}>
        <div className="card-header"><h2>Observability Stack</h2></div>
        <div className="card-body">
          <div className="dashboard-stats">
            {TOOL_URLS.map(tool => (
              <div key={tool.label} className="stat-card" style={{ cursor: 'pointer' }}
                onClick={() => window.open(tool.url, '_blank')}>
                <div className="stat-value" style={{ fontSize: '1rem' }}>🔗</div>
                <div className="stat-label" style={{ fontWeight: 600 }}>{tool.label}</div>
                <div className="text-muted" style={{ fontSize: '0.75rem', marginTop: 4 }}>{tool.desc}</div>
                <div style={{ fontSize: '0.7rem', color: '#6b7280', marginTop: 2 }}>{tool.url}</div>
              </div>
            ))}
          </div>
          <p style={{ marginTop: 16, fontSize: '0.85rem', color: '#6b7280' }}>
            Browser traces from this UI are exported via OTLP/HTTP through the nginx proxy at
            <code> /otel/v1/traces</code> and <code>/otel/v1/metrics</code> to the OpenTelemetry
            Collector, then forwarded to Jaeger (traces) and Prometheus (metrics).
            Each API call carries a <code>traceparent</code> header that links frontend spans to
            backend microservice spans in Jaeger.
          </p>
        </div>
      </div>
    </div>
  );
}
