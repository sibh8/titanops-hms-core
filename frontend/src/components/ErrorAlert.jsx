export default function ErrorAlert({ message, onDismiss }) {
  if (!message) return null;
  return (
    <div className="alert alert-error" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
      <span>{message}</span>
      {onDismiss && (
        <button onClick={onDismiss} style={{ background: 'none', border: 'none', cursor: 'pointer', fontSize: '1rem', lineHeight: 1, padding: '0 0 0 12px', color: 'inherit' }}>
          ✕
        </button>
      )}
    </div>
  );
}
