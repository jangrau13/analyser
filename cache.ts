export interface Origin {
  fetch(key: string): Promise<string>;
}

export class Cache {
  private entries = new Map<string, string>();

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
    if (hit !== undefined) {
      return hit;
    }

    const value = await this.origin.fetch(key);
    this.entries.set(key, value);
    return value;
  }
}
