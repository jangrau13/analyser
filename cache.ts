export interface Origin {
  fetch(key: string): Promise<string>;
}

type Entry = { value: string; expires: number };

export class Cache {
  private entries = new Map<string, Entry>();

  private origin: Origin;
  private capacity: number;
  private ttlMs: number;
  private now: () => number;

  // Fields declared and assigned rather than written as constructor parameter
  // properties: node strips types, it does not transform them, and a parameter
  // property is a transform — `ERR_UNSUPPORTED_TYPESCRIPT_SYNTAX`.
  constructor(origin: Origin, capacity: number, ttlMs: number, now: () => number = Date.now) {
    this.origin = origin;
    this.capacity = capacity;
    this.ttlMs = ttlMs;
    this.now = now;
  }

  async get(key: string): Promise<string> {
    const hit = this.entries.get(key);
    if (hit && hit.expires > this.now()) {
      return hit.value;
    }

    // Miss, or stale. Go to the origin and remember what it said.
    const value = await this.origin.fetch(key);
    this.entries.set(key, { value, expires: this.now() + this.ttlMs });
    return value;
  }
}
