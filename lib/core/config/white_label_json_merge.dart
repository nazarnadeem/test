/// Combines the main app's config with this white-label repo's config.
///
/// Values already set in [local] stay. Keys that exist only in [incoming]
/// are added, so a new field from the main app shows up without replacing
/// the gym ids or the app name.
Map<String, dynamic> mergeWhiteLabelJson({
  required Map<String, dynamic> local,
  required Map<String, dynamic> incoming,
}) {
  final merged = Map<String, dynamic>.from(local);
  for (final entry in incoming.entries) {
    if (!merged.containsKey(entry.key)) {
      merged[entry.key] = entry.value;
    }
  }
  return merged;
}
