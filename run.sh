#!/bin/sh
# The three decisions this brief is about, run against the candidate's cache.
#
# The analyser reads the file and says which of the usual pieces are named in
# it. These say what the pieces do: each target drives /work/cache.ts and
# prints the count the candidate's answer has to account for, which is the only
# thing that settles an argument about a stampede.
#
# These report what the cache did rather than marking it: a hundred origin
# calls for one key is a number to ask about, not a failure. A non-zero exit
# means the cache could not be run at all.
#
# The probe is written into /build: /work belongs to root so that a submission
# cannot rewrite itself while it is being run, and /tmp is noexec.
#
# Usage: run.sh --list | run.sh [stampede|eviction|expiry]
set -eu

if [ "${1:-}" = "--list" ]; then
  printf 'stampede\tA hundred callers ask for one hot key at the same instant, and the origin counts how often it was asked. A cache that does not collapse concurrent misses makes the stampede it exists to absorb.\n'
  printf 'eviction\tTen thousand distinct keys through a cache of capacity 100, then the newest key and the oldest one again. Says whether anything was evicted, and whether anything is held at all.\n'
  printf 'expiry\tTwo gets in a row, then the clock the cache was handed wound five TTLs forward and a third get. Says whether that clock decides anything.\n'
  exit 0
fi

TARGET="${1:-stampede}"
case "$TARGET" in
  stampede | eviction | expiry) ;;
  *) echo "no such target: $TARGET"; exit 2 ;;
esac

mkdir -p "${TMPDIR:-/build/tmp}"
[ -f /work/cache.ts ] || { echo "the submission has no cache.ts at its root"; exit 2; }

W=/build/viva-run
rm -rf "$W"; mkdir -p "$W"

# A .ts file whose first statement is a top-level await, which is what makes
# node read it as a module; the image's NODE_OPTIONS strips the types out of
# the file it imports.
cat > "$W/probe.ts" <<'TS'
const mod = await import('/work/cache.ts');
const Cache = (mod as any).Cache ?? (mod as any).default;
if (typeof Cache !== 'function') {
  console.log('the submission exports no Cache class');
  process.exit(2);
}

const target = process.argv[2];

/** An origin that counts, and whose value changes, so a refetch is visible. */
function counting(latencyMs = 0) {
  const origin = {
    calls: 0,
    async fetch(key: string) {
      origin.calls += 1;
      if (latencyMs) await new Promise((r) => setTimeout(r, latencyMs));
      return `value-for-${key}-#${origin.calls}`;
    },
  };
  return origin;
}

/** A get that says what went wrong rather than printing a stack over it. */
async function get(cache: any, key: string) {
  try {
    return await cache.get(key);
  } catch (err: any) {
    console.log(`get("${key}") threw: ${err?.message ?? err}`);
    process.exit(1);
  }
}

if (target === 'stampede') {
  const origin = counting(20);
  const cache = new Cache(origin, 100, 1000);
  const results = await Promise.all(Array.from({ length: 100 }, () => get(cache, 'hot')));

  console.log('100 concurrent callers, one key');
  console.log(`  origin was called: ${origin.calls} time(s)`);
  console.log(`  all agreed:        ${new Set(results).size === 1}`);
  if (origin.calls !== 1) {
    console.log(`STAMPEDE — ${origin.calls} origin calls for one key`);
  } else if (new Set(results).size !== 1) {
    console.log('one origin call, but the callers were not all given the same value');
  } else {
    console.log('the miss was collapsed onto one origin call');
  }
}

if (target === 'eviction') {
  const origin = counting();
  const cache = new Cache(origin, 100, 60_000);
  for (let i = 0; i < 10_000; i++) await get(cache, `key-${i}`);
  const filling = origin.calls;

  // The newest key is asked for first. Asking for the oldest one is itself a
  // write, and a cache that evicts to make room for it could evict the very
  // key the next line is about to ask about.
  const beforeNewest = origin.calls;
  await get(cache, 'key-9999');
  const newestRefetched = origin.calls > beforeNewest;

  const beforeOldest = origin.calls;
  await get(cache, 'key-0');
  const oldestRefetched = origin.calls > beforeOldest;

  console.log('capacity 100, 10000 distinct keys');
  console.log(`  origin calls while filling:               ${filling}`);
  console.log(`  the newest key came back from the origin: ${newestRefetched}`);
  console.log(`  the oldest key came back from the origin: ${oldestRefetched}`);
  if (newestRefetched) {
    console.log('NOTHING IS HELD — the key written a moment ago was fetched again');
  } else if (!oldestRefetched) {
    console.log('UNBOUNDED — key-0 survived 9999 later keys in a cache of capacity 100');
  } else {
    console.log('bounded: the oldest key was gone, the newest was still there');
  }
}

if (target === 'expiry') {
  let clock = 1_700_000_000_000;
  const origin = counting();
  const cache = new Cache(origin, 100, 1000, () => clock);

  const first = await get(cache, 'k');
  await get(cache, 'k');
  const warm = origin.calls;
  clock += 5000;
  const third = await get(cache, 'k');
  const moved = origin.calls;

  console.log('ttl 1000ms, one key, and a clock the cache was handed');
  console.log(`  origin calls for two gets in a row:    ${warm}`);
  console.log(`  origin calls after the clock moved 5s: ${moved}`);
  console.log(`  the value returned changed:            ${third !== first}`);
  if (warm !== 1) {
    console.log(`NOTHING IS CACHED — two gets in a row cost ${warm} origin calls`);
  } else if (moved === warm) {
    console.log('THE INJECTED CLOCK DECIDES NOTHING — the entry survived five TTLs');
  } else {
    console.log('the entry expired on the clock it was given');
  }
}
TS

node "$W/probe.ts" "$TARGET" 2>&1
