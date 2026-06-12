// Worst-case timing guard. These inputs are deliberately
// adversarial. A linear extractor finishes all of them in
// single-digit milliseconds.
//
// The budgets are generous (hundreds of ms for work that should take
// <10 ms) so a correct linear implementation won't go flaky on a slow
// CI box, while quadratic blowup still trips them by at least a
// factor of ten on a fast CPU.

import { test } from 'node:test';
import { strict as assert } from 'node:assert';
import {
  extractEmailAddresses,
  extractUrls,
  extractEntities,
} from '../src/index.js';

function elapsedMs(fn) {
    const t = process.hrtime.bigint();
    fn();
    return Number(process.hrtime.bigint() - t) / 1e6;
}

const BUDGET_MS = 750;

// A wall of '@' signs: every one is an email candidate, and the current
// code rebuilds the entire preceding prefix for each.
test('a wall of @ signs stays under budget', () => {
  const nasty = 'a@'.repeat(8000);
  const ms = elapsedMs(() => extractEmailAddresses(nasty));
  assert.ok(ms < BUDGET_MS, `took ${ms.toFixed(0)}ms (budget ${BUDGET_MS}ms)`);
});

// Thousands of tiny valid domains: every token is a real URL match, and
// each trigger slices from itself to the end of the string.
test('a swarm of short valid domains stays under budget', () => {
  const nasty = 'see a.co '.repeat(4000);
  const ms = elapsedMs(() => extractUrls(nasty));
  assert.ok(ms < BUDGET_MS, `took ${ms.toFixed(0)}ms (budget ${BUDGET_MS}ms)`);
});

// Mixed: addresses and domains interleaved, run through the combined path.
test('interleaved emails and domains stay under budget', () => {
  const nasty = 'x@a.co see b.co '.repeat(4000);
  const ms = elapsedMs(() => extractEntities(nasty));
  assert.ok(ms < BUDGET_MS, `took ${ms.toFixed(0)}ms (budget ${BUDGET_MS}ms)`);
});

// Machine-independent timing: doubling the input should roughly double
// the time (linear), not quadruple it (quadratic). A warm-up run primes the
// JIT so the ratio reflects steady-state behaviour, and the threshold is
// loose enough to tolerate timing noise while still catching n² growth.

// When I ran this about eleventy times, the correct implementation
// stayed around a factor of 2 and the old, buggy one was almost at 5,
// so the limit is 50% over what I saw and the bug 50% over the
// limit. Good enough.

test('runtime scales roughly linearly, not quadratically', () => {
  const build = (n) => 'see a.co '.repeat(n);
  extractUrls(build(1000)); // warm up

  const t1 = elapsedMs(() => extractUrls(build(3000)));
  const t2 = elapsedMs(() => extractUrls(build(6000)));
  const ratio = t2 / t1;
  assert.ok(
    ratio < 3,
    `doubling input multiplied time by ${ratio.toFixed(1)}x ` +
      `(${t1.toFixed(0)}ms → ${t2.toFixed(0)}ms); expected ~2x for linear`,
  );
});
