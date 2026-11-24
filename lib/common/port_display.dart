import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/models/port_routing.dart';

class PortDisplayName {
  final String name;
  final int? bindingId;
  final int? sourceProfileId;

  const PortDisplayName({
    required this.name,
    this.bindingId,
    this.sourceProfileId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PortDisplayName &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          bindingId == other.bindingId &&
          sourceProfileId == other.sourceProfileId;

  @override
  int get hashCode => Object.hash(name, bindingId, sourceProfileId);

  @override
  String toString() =>
      'PortDisplayName(name: $name, bindingId: $bindingId, sourceProfileId: $sourceProfileId)';
}

final _portPrefixPattern = RegExp(r'^\[port:(\d+)\] ');
final _sourcePrefixPattern = RegExp(r'^\[(?:priority|ports):(\d+)\] ');

PortDisplayName parsePortDisplayName(
  String raw, {
  Set<int>? validBindingIds,
  Set<int>? validProfileIds,
}) {
  var current = raw;
  int? bindingId;
  int? sourceProfileId;

  final portMatch = _portPrefixPattern.firstMatch(current);
  if (portMatch != null) {
    final id = int.tryParse(portMatch.group(1)!);
    if (id != null &&
        (validBindingIds == null || validBindingIds.contains(id))) {
      bindingId = id;
      current = current.substring(portMatch.end);
    }
  }

  final sourceMatch = _sourcePrefixPattern.firstMatch(current);
  if (sourceMatch != null) {
    final id = int.tryParse(sourceMatch.group(1)!);
    if (id != null &&
        (validProfileIds == null || validProfileIds.contains(id))) {
      sourceProfileId = id;
      current = current.substring(sourceMatch.end);
    }
  }

  return PortDisplayName(
    name: current,
    bindingId: bindingId,
    sourceProfileId: sourceProfileId,
  );
}

String displayPortName(
  String raw, {
  Set<int>? validBindingIds,
  Set<int>? validProfileIds,
}) {
  return parsePortDisplayName(
    raw,
    validBindingIds: validBindingIds,
    validProfileIds: validProfileIds,
  ).name;
}

String? _sourceLabelFromParsed(
  PortDisplayName parsed, {
  required Map<int, String> profileLabels,
  Map<int, PortBinding> bindingsById = const {},
}) {
  if (parsed.sourceProfileId case final sourceId?) {
    return profileLabels[sourceId];
  }
  if (parsed.bindingId case final bindingId?) {
    final binding = bindingsById[bindingId];
    if (binding != null && binding.selection == PortSelection.aggregate) {
      return profileLabels[binding.profileId];
    }
  }
  return null;
}

String? portSourceLabel(
  String raw, {
  required Map<int, String> profileLabels,
  Map<int, PortBinding> bindingsById = const {},
}) {
  final parsed = parsePortDisplayName(
    raw,
    validBindingIds: bindingsById.isEmpty ? null : bindingsById.keys.toSet(),
    validProfileIds: profileLabels.keys.toSet(),
  );
  return _sourceLabelFromParsed(
    parsed,
    profileLabels: profileLabels,
    bindingsById: bindingsById,
  );
}

({String name, String? source}) resolveDisplaySelected(
  String rawSelected, {
  required Map<String, Group> groupsByName,
  required Map<int, String> profileLabels,
  Map<int, PortBinding> bindingsById = const {},
  int maxDepth = 4,
}) {
  var current = rawSelected;
  final visited = <String>{};
  for (var depth = 0; depth < maxDepth; depth++) {
    if (!visited.add(current)) break;
    final group = groupsByName[current];
    final next = group?.now;
    if (group == null || group.hidden != true || next == null || next.isEmpty) {
      break;
    }
    current = next;
  }

  final parsed = parsePortDisplayName(
    current,
    validBindingIds: bindingsById.isEmpty ? null : bindingsById.keys.toSet(),
    validProfileIds: profileLabels.keys.toSet(),
  );
  final source = _sourceLabelFromParsed(
    parsed,
    profileLabels: profileLabels,
    bindingsById: bindingsById,
  );
  return (name: parsed.name, source: source);
}

String formatDisplayWithSource(String name, String? source) {
  return source == null || source.isEmpty ? name : '$source · $name';
}

String formatPortChainLabel(
  String raw, {
  Map<int, String> profileLabels = const {},
  Map<int, PortBinding> bindingsById = const {},
}) {
  final parsed = parsePortDisplayName(raw);
  final binding = parsed.bindingId != null
      ? bindingsById[parsed.bindingId]
      : null;
  final source =
      (parsed.sourceProfileId != null
          ? profileLabels[parsed.sourceProfileId]
          : null) ??
      (binding != null && binding.selection == PortSelection.aggregate
          ? profileLabels[binding.profileId]
          : null) ??
      binding?.name;
  return formatDisplayWithSource(parsed.name, source);
}
