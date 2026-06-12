// The six module-level convenience functions, built over one shared
// Extractor. Factored out so each entry point (default/PSL, /iana, and a
// caller's own /core instance) gets the identical wrappers without copying
// them. Each wrapper drops overlapping candidates, keeping the
// earlier-starting one.

export function makeApi(shared) {
  const extractUrlsWithIndices = (text) =>
    shared.removeOverlappingEntities(shared.extractUrlsWithIndices(text));

  const extractUrls = (text) =>
    extractUrlsWithIndices(text).map((r) => r.url);

  const extractEmailAddressesWithIndices = (text) =>
    shared.removeOverlappingEntities(shared.extractEmailAddressesWithIndices(text));

  const extractEmailAddresses = (text) =>
    extractEmailAddressesWithIndices(text).map((r) => r.email);

  const extractEntitiesWithIndices = (text) =>
    shared.removeOverlappingEntities([
      ...shared.extractUrlsWithIndices(text),
      ...shared.extractEmailAddressesWithIndices(text),
    ]);

  const extractEntities = (text) =>
    extractEntitiesWithIndices(text).map((e) => e.url);

  return {
    extractUrlsWithIndices,
    extractUrls,
    extractEmailAddressesWithIndices,
    extractEmailAddresses,
    extractEntitiesWithIndices,
    extractEntities,
  };
}
