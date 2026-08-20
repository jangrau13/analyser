/**
 * A cache in front of a slow origin.
 *
 * The plumbing is settled: what a key is, how the origin is called, and what
 * the caller does with a miss. `get` is the part with a decision in it.
 */

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

  /** The value for this key, from the cache if it is there and still good. */
  async get(_key: string): Promise<string> {
    throw new Error('not implemented');
  }
}
