export default function Spinner({ text = 'Loading…' }) {
  return (
    <div className="spinner-wrap">
      <div className="spinner" />
      {text && <span>{text}</span>}
    </div>
  );
}
