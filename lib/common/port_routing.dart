import 'package:fl_clash/models/port_routing.dart';
import 'package:fl_clash/models/clash_config.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:yaml/yaml.dart';

part 'port_policy.dart';

enum PortRoutingIssue {
  invalidPort,
  duplicatePort,
  invalidBinding,
  invalidFilter,
  unsupportedSubscription,
  emptySubscription,
  duplicateNode,
  missingSubscription,
  portOccupied,
  coreUnavailable,
  staleUpdate,
  sourceInUse,
  updateFailed,
  invalidNodes,
}

class PortRoutingException implements Exception {
  final PortRoutingIssue issue;
  final List<String> nodes;

  const PortRoutingException(this.issue, {this.nodes = const []});

  @override
  String toString() => 'PortRoutingException(${issue.name})';
}

String portProviderName(int profileId) => 'flclash_ports_source_$profileId';

String portNodePrefix(int profileId) => '[ports:$profileId] ';

PatchClashConfig portRoutingPatch(PatchClashConfig saved) => saved.copyWith(
  mixedPort: 0,
  port: 0,
  socksPort: 0,
  redirPort: 0,
  tproxyPort: 0,
  allowLan: false,
  tun: saved.tun.copyWith(enable: false),
  externalController: ExternalControllerStatus.close,
  mode: Mode.rule,
);

List<Map<String, dynamic>> portSubscriptionNodes(String source) {
  return (portSubscriptionDocument(source)['proxies'] as List)
      .cast<Map<String, dynamic>>();
}

Map<String, dynamic> portSubscriptionDocument(String source) {
  final Object? document;
  try {
    document = loadYaml(source);
  } on YamlException {
    throw const PortRoutingException(PortRoutingIssue.unsupportedSubscription);
  }
  if (document is! Map ||
      document['proxy-providers'] is Map &&
          (document['proxy-providers'] as Map).isNotEmpty) {
    throw const PortRoutingException(PortRoutingIssue.unsupportedSubscription);
  }
  final nodes = document['proxies'];
  if (nodes is! List || nodes.isEmpty) {
    throw const PortRoutingException(PortRoutingIssue.emptySubscription);
  }
  final names = <String>{};
  return {
    'proxies': [for (final node in nodes) _portNode(node, names)],
    for (final key in [
      'proxy-groups',
      'rules',
      'sub-rules',
      'rule-providers',
      'mode',
    ])
      if (document[key] != null) key: _plainPortValue(document[key]),
  };
}

Object? _plainPortValue(Object? value, {bool shortId = false}) =>
    switch (value) {
      YamlMap() => {
        for (final entry in value.nodes.entries)
          (entry.key as YamlNode).value.toString(): _plainPortValue(
            entry.value,
            shortId: (entry.key as YamlNode).value == 'short-id',
          ),
      },
      YamlList() => [
        for (final node in value.nodes) _plainPortValue(node, shortId: shortId),
      ],
      YamlScalar()
          when shortId &&
              value.value is num &&
              RegExp(r'^[0-9a-fA-F]+$').hasMatch(value.span.text) =>
        value.span.text,
      YamlScalar() => value.value,
      Map() => value.map(
        (key, value) => MapEntry(key.toString(), _plainPortValue(value)),
      ),
      List() =>
        value.map((item) => _plainPortValue(item, shortId: shortId)).toList(),
      _ => value,
    };

Map<String, dynamic> _portNode(Object? value, Set<String> names) {
  if (value is! Map ||
      value['name'] is! String ||
      (value['name'] as String).isEmpty ||
      value['type'] is! String ||
      {
        'direct',
        'reject',
        'pass',
        'compatible',
        'dns',
        'rematch',
      }.contains((value['type'] as String).toLowerCase()) ||
      value['dialer-proxy'] != null && value['dialer-proxy'] != '') {
    throw const PortRoutingException(PortRoutingIssue.unsupportedSubscription);
  }
  if (!names.add(value['name'] as String)) {
    throw const PortRoutingException(PortRoutingIssue.duplicateNode);
  }
  return (_plainPortValue(value) as Map).cast<String, dynamic>();
}

void validatePortBindings(List<PortBinding> bindings) {
  final ports = <int>{};
  final ids = <int>{};
  for (final binding in bindings) {
    if (binding.port < 1024 || binding.port > 65535) {
      throw const PortRoutingException(PortRoutingIssue.invalidPort);
    }
    if (!ports.add(binding.port)) {
      throw const PortRoutingException(PortRoutingIssue.duplicatePort);
    }
    if (!ids.add(binding.id) ||
        binding.name.trim().isEmpty ||
        binding.id <= 0 ||
        binding.sourceIds.any((id) => id <= 0) ||
        binding.additionalProfileIds.length + 1 != binding.sourceIds.length ||
        binding.selection != PortSelection.region &&
            binding.sourceIds.length != 1 ||
        binding.selection == PortSelection.fixed && binding.node.isEmpty) {
      throw const PortRoutingException(PortRoutingIssue.invalidBinding);
    }
    if (binding.selection == PortSelection.region) {
      if (_regionWords(binding.filter).isEmpty) {
        throw const PortRoutingException(PortRoutingIssue.invalidFilter);
      }
    }
  }
}

List<String> matchingPortNodes(PortBinding binding, Iterable<String> names) {
  if (binding.selection == PortSelection.original) return names.toList();
  if (binding.selection == PortSelection.fixed) {
    return names.where((name) => name == binding.node).toList();
  }
  final words = _regionWords(binding.filter);
  return names.where((name) => words.any(name.toLowerCase().contains)).toList();
}

List<String> _regionWords(String filter) => filter
    .split('|')
    .map((word) => word.trim().toLowerCase())
    .where((word) => word.isNotEmpty)
    .toList();

String _portPattern(String value) =>
    RegExp.escape(value).replaceAll('`', r'\x60');

typedef PortRoutingFragment = ({
  Map<String, dynamic> config,
  Map<String, dynamic> providers,
});

PortRoutingFragment compilePortRouting({
  required List<PortBinding> bindings,
  required Map<int, String> sourcePaths,
  required String testUrl,
  Map<int, Map<String, dynamic>> sourceDocuments = const {},
  Map<int, Map<String, String>> selectedMaps = const {},
}) {
  validatePortBindings(bindings);
  final active = bindings.where((binding) => binding.enabled).toList();
  for (final binding in active) {
    if (!binding.sourceIds.every(sourcePaths.containsKey)) {
      throw const PortRoutingException(PortRoutingIssue.missingSubscription);
    }
  }
  final original = _compilePortPolicies(
    bindings: active,
    sources: sourceDocuments,
    selectedMaps: selectedMaps,
  );
  return (
    providers: {
      for (final id in active.expand((binding) => binding.sourceIds).toSet())
        portProviderName(id): {
          'type': 'file',
          'path': sourcePaths[id],
          'override': {'additional-prefix': portNodePrefix(id)},
          'health-check': {
            'enable': true,
            'url': testUrl,
            'interval': 300,
            'lazy': true,
          },
        },
    },
    config: {
      'rules': ['MATCH,REJECT'],
      ...original,
      'proxy-groups': [
        ...?original['proxy-groups'] as List?,
        for (final binding in active)
          if (binding.selection != PortSelection.original)
            {
              'name': binding.groupName,
              'type': binding.selection == PortSelection.fixed
                  ? 'select'
                  : 'url-test',
              'use': [for (final id in binding.sourceIds) portProviderName(id)],
              'filter': binding.selection == PortSelection.fixed
                  ? '^${_portPattern('${portNodePrefix(binding.profileId)}${binding.node}')}\$'
                  : '(?i)^(?:${binding.sourceIds.map((id) => _portPattern(portNodePrefix(id))).join('|')}).*(?:${_regionWords(binding.filter).map(_portPattern).join('|')}).*\$',
              'empty-fallback': 'REJECT',
              'hidden': true,
              if (binding.selection == PortSelection.region) ...{
                'url': testUrl,
                'interval': 300,
                'tolerance': 50,
                'lazy': true,
              },
            },
      ],
      'listeners': [
        for (final binding in active)
          {
            'name': binding.listenerName,
            'type': 'mixed',
            'listen': '127.0.0.1',
            'port': binding.port,
            'udp': false,
            'users': <Map<String, String>>[],
            if (binding.selection == PortSelection.original)
              'rule': binding.ruleName
            else
              'proxy': binding.groupName,
          },
      ],
    },
  );
}
