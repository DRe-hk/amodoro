const buckets = new Map<string, number[]>();

export function checkRateLimit(
  key: string,
  maxAttempts: number,
  windowMs: number,
): { allowed: boolean; remaining: number; retryAfterSec: number } {
  const now = Date.now();
  const windowStart = now - windowMs;
  const timestamps = (buckets.get(key) ?? []).filter((ts) => ts > windowStart);

  if (timestamps.length >= maxAttempts) {
    buckets.set(key, timestamps);
    const oldest = timestamps[0] ?? now;
    const retryAfterSec = Math.max(1, Math.ceil((oldest + windowMs - now) / 1000));
    return {
      allowed: false,
      remaining: 0,
      retryAfterSec,
    };
  }

  timestamps.push(now);
  buckets.set(key, timestamps);
  return {
    allowed: true,
    remaining: Math.max(0, maxAttempts - timestamps.length),
    retryAfterSec: 0,
  };
}

export function resetRateLimit(key: string) {
  buckets.delete(key);
}

export function getClientIp(request: Request): string {
  const xff = request.headers.get("x-forwarded-for");
  if (xff) {
    const first = xff.split(",")[0]?.trim();
    if (first) return first;
  }
  const realIp = request.headers.get("x-real-ip")?.trim();
  if (realIp) return realIp;
  return "local";
}

export function logSecurityEvent(
  event: string,
  details?: Record<string, unknown>,
) {
  if (process.env.NODE_ENV === "test") return;
  try {
    console.info(
      JSON.stringify({
        ts: new Date().toISOString(),
        type: "SECURITY_AUDIT",
        event,
        ...details,
      }),
    );
  } catch {
    // ignore logging failure
  }
}
