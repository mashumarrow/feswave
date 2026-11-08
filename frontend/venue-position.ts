export type Side = 'left' | 'right';
type Sample = { time: number; delta: number };

// Each five-second vote needs multiple fresh observations, so one packet or a
// backgrounded tab cannot stand in for a whole interval.
export function voteSide(samples: Sample[], start: number, bins: number, center: number) {
  const votes = { left: 0, right: 0, valid: 0 };
  for (let i = 0; i < bins; i++) {
    const from = start + i * 5000;
    const values = samples.filter(s => s.time >= from && s.time < from + 5000)
      .map(s => s.delta).sort((a, b) => a - b);
    if (values.length < 3) continue;
    const mid = Math.floor(values.length / 2);
    const delta = (values[mid] + values[Math.floor((values.length - 1) / 2)]) / 2 - center;
    votes.valid++;
    if (delta < -2) votes.left++;
    if (delta > 2) votes.right++;
  }
  const required = bins === 2 ? 2 : 5;
  const side: Side | null = votes.left >= required ? 'left' : votes.right >= required ? 'right' : null;
  return { side, usable: votes.valid >= required };
}

export async function trackVenuePosition(center: number, signal: AbortSignal,
  publish: (side: Side | null) => Promise<void>) {
  let samples: Sample[] = [];
  let last: Side | null = null;
  let start = performance.now();
  while (!signal.aborted) {
    const bins = last ? 6 : 2;
    try {
      const response = await fetch('http://192.168.4.1/api/me', {
        credentials: 'omit', cache: 'no-store', signal: AbortSignal.any([signal, AbortSignal.timeout(1800)])
      });
      if (response.ok) {
        const data = await response.json();
        if (data.online === true && Number.isFinite(data.left) && Number.isFinite(data.right))
          samples.push({ time: performance.now(), delta: data.right - data.left });
      }
    } catch { /* Missing observations leave holes in this window. */ }
    if (signal.aborted) return;
    const now = performance.now();
    if (now - start >= bins * 5000) {
      const vote = voteSide(samples, now - bins * 5000, bins, center);
      last = vote.usable ? vote.side ?? last : null;
      start = now;
      samples = [];
      try { await publish(last); } catch { /* The server expires unrefreshed positions. */ }
    }
    await new Promise(resolve => setTimeout(resolve, 650));
  }
}
