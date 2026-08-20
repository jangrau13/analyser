#!/bin/sh
# Whether the submission is still something node can load.
#
# There is no tsc in this image — the Dockerfile keeps the toolchain out on
# purpose, because nothing can be fetched at exam time — so validity here is
# what node itself decides: the file parses, its types strip, it loads without
# throwing, and a Cache class comes out. Type stripping is the sharp end of
# that: node strips types, it does not transform them, so a constructor
# parameter property is a hard failure here rather than a style.
#
# It stops at the class. Whether `get` is on the prototype is not a question
# this can answer without refusing a legal submission — a method written as a
# class field is not on the prototype at all — and run.sh calls it anyway.
#
# Loading runs whatever the file does at import. So does every scenario, so a
# submission that cannot be loaded cannot be examined by any other route either.
set -eu
mkdir -p "${TMPDIR:-/build/tmp}"
[ -f /work/cache.ts ] || { echo "the submission has no cache.ts at its root"; exit 2; }

W=/build/viva-compile
rm -rf "$W"; mkdir -p "$W"

cat > "$W/check.ts" <<'TS'
const mod = await import('/work/cache.ts');
const Cache = (mod as any).Cache ?? (mod as any).default;
if (typeof Cache !== 'function') {
  console.log('cache.ts loads, but exports no Cache class');
  process.exit(1);
}
console.log('cache.ts parses, strips, loads, and exports a Cache class');
TS

node "$W/check.ts" 2>&1
