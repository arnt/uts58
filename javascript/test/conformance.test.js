// The official UTS58 conformance suite, LinkDetectionTest.txt, run against the
// /iana entry.
//
// Each non-comment line carries zero or more links wrapped in ⸠…⸡. We strip
// the markers, re-detect, re-wrap, and require the result to match the line.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { extractEntitiesWithIndices } from '../src/index-iana.js';

const OPEN = '⸠';
const CLOSE = '⸡';
const dataDir = new URL('../../', import.meta.url);

function readCases(name) {
  return readFileSync(new URL(name, dataDir), 'utf8')
    .split('\n')
    .filter((line) => line !== '' && !line.startsWith('#'));
}

// Detect links and wrap each in the markers. The entity indices are UTF-16
// offsets, so we slice `input` directly — no Array.from dance.
function detectAndMark(input) {
  const entities = extractEntitiesWithIndices(input)
    .slice()
    .sort((a, b) => a.indices[0] - b.indices[0]);
  let out = '';
  let cursor = 0;
  for (const { indices: [start, end] } of entities) {
    out += input.slice(cursor, start) + OPEN + input.slice(start, end) + CLOSE;
    cursor = end;
  }
  return out + input.slice(cursor);
}

const cases = readCases('LinkDetectionTest.txt');
const known = new Set(readCases('LinkDetectionKnownFailures.txt'));

test('LinkDetectionTest.txt conformance', () => {
  const regressed = [];
  const fixed = [];
  for (const expected of cases) {
    const input = expected.replaceAll(OPEN, '').replaceAll(CLOSE, '');
    const got = detectAndMark(input);
    if (got === expected) {
      if (known.has(input)) fixed.push(input);
    } else if (!known.has(input)) {
      regressed.push(`  in : ${input}\n  exp: ${expected}\n  got: ${got}`);
    }
  }
  assert.equal(regressed.length, 0,
    `newly failing conformance lines:\n${regressed.join('\n')}`);
  assert.equal(fixed.length, 0,
    `these now pass — delete them from LinkDetectionKnownFailures.txt:\n  ${fixed.join('\n  ')}`);
});
