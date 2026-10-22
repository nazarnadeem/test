import 'dart:convert';
import 'dart:io';

import 'package:gcrm_one/core/config/white_label_json_merge.dart';

/// Writes [output] from [localPath], keeping those values and adding any new
/// keys found in [incomingPath].
void main(List<String> args) {
  if (args.length != 3) {
    stderr.writeln(
      'Usage: dart run tool/merge_white_label_json.dart <local.json> <incoming.json> <output.json>',
    );
    exit(1);
  }

  final localText = File(args[0]).readAsStringSync();
  final incomingText = File(args[1]).readAsStringSync();
  final local = jsonDecode(localText);
  final incoming = jsonDecode(incomingText);
  if (local is! Map || incoming is! Map) {
    stderr.writeln('Both JSON files must be objects.');
    exit(1);
  }

  final localMap = Map<String, dynamic>.from(local);
  final merged = mergeWhiteLabelJson(
    local: localMap,
    incoming: Map<String, dynamic>.from(incoming),
  );

  final output = File(args[2]);
  if (_sameMap(merged, localMap)) {
    output.writeAsStringSync(localText.endsWith('\n') ? localText : '$localText\n');
    return;
  }

  const encoder = JsonEncoder.withIndent('  ');
  output.writeAsStringSync('${encoder.convert(merged)}\n');
}

bool _sameMap(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) return false;
  }
  return true;
}
