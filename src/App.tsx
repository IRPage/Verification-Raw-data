import { useEffect, useState } from 'react'
import './App.css'

type Verification = {
  id: number;
  certificate_no: string;
  verification_date: string;
  client_name?: string;
}

export default function App() {
  const [health, setHealth] = useState('checking...')
  const [verifications, setVerifications] = useState<Verification[]>([])

  useEffect(() => {
    fetch('/api/health').then(r => r.json()).then(d => setHealth(d.message)).catch(() => setHealth('offline'))
    fetch('/api/verifications').then(r => r.json()).then(d => setVerifications(d.verifications || [])).catch(() => setVerifications([]))
  }, [])

  return (
    <div className="card" style={{ maxWidth: 800, margin: '2rem auto', fontFamily: 'system-ui, sans-serif' }}>
      <h1>WOW Scales Verification</h1>
      <p>API status: {health}</p>
      <h2>Recent verifications</h2>
      <ul>
        {verifications.map(v => (
          <li key={v.id}>
            <strong>{v.certificate_no}</strong> — {v.client_name} — {v.verification_date}
          </li>
        ))}
        {verifications.length === 0 && <li>No data</li>}
      </ul>
    </div>
  )
}
