// The six module-level convenience functions, built over one shared
// Extractor. Factored out so each entry point (default/PSL, /iana, and a
// caller's own /core instance) gets the identical wrappers without copying
// them. Each wrapper drops overlapping candidates, keeping the
// earlier-starting one.

export function makeApi(shared) {
  const extractUrlsWithIndices = (text, options = {}) =>
    shared.removeOverlappingEntities(
      shared.extractUrlsWithIndices(text, options));

  const extractUrls = (text, options = {}) =>
    extractUrlsWithIndices(text, options).map((r) => r.url);

  const extractEmailAddressesWithIndices = (text) =>
    shared.removeOverlappingEntities(shared.extractEmailAddressesWithIndices(text));

  const extractEmailAddresses = (text) =>
    extractEmailAddressesWithIndices(text).map((r) => r.email);

  const extractEntitiesWithIndices = (text, options = {}) =>
    shared.removeOverlappingEntities([
      ...shared.extractUrlsWithIndices(text, options),
      ...shared.extractEmailAddressesWithIndices(text),
    ]);

  const extractEntities = (text, options = {}) =>
    extractEntitiesWithIndices(text, options).map((e) => e.url);

  return {
    extractUrlsWithIndices,
    extractUrls,
    extractEmailAddressesWithIndices,
    extractEmailAddresses,
    extractEntitiesWithIndices,
    extractEntities,
  };
}
