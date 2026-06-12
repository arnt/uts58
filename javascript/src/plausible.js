// Host-plausibility check over a flat set of public suffixes. The
// question this answers is "could this be a link?", not "what is the
// exact registrable domain?". Therefore a flat membership test is
// enough, and the tabble can be much smaller than if we needed PSL's
// full wildcard/exception machinery.

// The tables are pre-folded for plausibility; see tools/maketlds.js).

import punycode from 'punycode/punycode.js';

// Build a `(host) => boolean` predicate. A host is plausible when
// some trailing run of its labels is a known suffix AND has at least
// one label before the suffix.
export function makeHostChecker(suffixes) {
  return (host) => {
    const folded = host.normalize('NFC').toLowerCase();
    let ascii;
    try {
      ascii = punycode.toASCII(folded);
    } catch {
      ascii = folded;
    }
    const labels = ascii.split('.');
    for (let i = labels.length - 1; i >= 1; i--) {
      if (suffixes.has(labels.slice(i).join('.'))) return true;
    }
    return false;
  };
}
