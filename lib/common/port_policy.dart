part of 'port_routing.dart';

Map<String, dynamic> _compilePortPolicies({
  required List<PortBinding> bindings,
  required Map<int, Map<String, dynamic>> sources,
  Map<int, Map<String, String>> selectedMaps = const {},
  required String testUrl,
}) {
  final proxies = <Map<String, dynamic>>[];
  final groups = <Map<String, dynamic>>[];
  final subRules = <String, List<String>>{};
  final ruleProviders = <String, dynamic>{};
  for (final binding in bindings) {
    if (!binding.usesRules) continue;
    final source = binding.selection == PortSelection.aggregate
        ? _aggregateDocument(binding, sources, testUrl)
        : sources[binding.profileId];
    if (source == null) {
      throw const PortRoutingException(PortRoutingIssue.missingSubscription);
    }
    final prefix = binding.policyPrefix;
    final nodes = (source['proxies'] as List).cast<Map>();
    final sourceGroups = (source['proxy-groups'] as List? ?? []).cast<Map>();
    final names = <String, String>{
      for (final item in [...nodes, ...sourceGroups])
        item['name'] as String: '$prefix${item['name']}',
    };
    final globalName = '${prefix}GLOBAL';
    names.putIfAbsent('GLOBAL', () => globalName);
    String target(String name) => names[name] ?? name;
    final providers = (source['rule-providers'] as Map? ?? {})
        .cast<String, dynamic>();
    final providerNames = {
      for (final name in providers.keys) name: '$prefix$name',
    };
    final nested = (source['sub-rules'] as Map? ?? {}).cast<String, dynamic>();
    final ruleNames = {for (final name in nested.keys) name: '$prefix$name'};
    String rule(String raw) =>
        _renameRule(raw, names, providerNames, ruleNames);
    proxies.addAll([
      for (final node in nodes)
        {
          ...node.cast<String, dynamic>(),
          'name': target(node['name'] as String),
        },
    ]);
    groups.addAll([
      for (final group in sourceGroups)
        {
          ...group.cast<String, dynamic>(),
          'name': target(group['name'] as String),
          'proxies': [
            for (final name in _policyMembers(group, nodes)) target(name),
          ],
          'exclude-filter': '',
          if ((binding.policies.any((policy) => policy.group == group['name'])
                      ? null
                      : selectedMaps[binding.profileId]?[group['name']]) ??
                  group['default-selected']
              case final String selected)
            'default-selected': target(selected),
          if (group['empty-fallback'] case final String fallback)
            'empty-fallback': target(fallback),
          'include-all': false,
          'include-all-providers': false,
          'include-all-proxies': false,
        },
    ]);
    if (!sourceGroups.any((group) => group['name'] == 'GLOBAL')) {
      groups.add({
        'name': globalName,
        'type': 'select',
        'hidden': true,
        'proxies': [
          'DIRECT',
          ...sourceGroups.map((g) => target(g['name'] as String)),
          ...nodes.map((n) => target(n['name'] as String)),
        ],
        if (selectedMaps[binding.profileId]?['GLOBAL']
            case final String selected)
          'default-selected': target(selected),
      });
    }
    for (final entry in providers.entries) {
      ruleProviders[providerNames[entry.key]!] = entry.value;
    }
    for (final entry in nested.entries) {
      subRules[ruleNames[entry.key]!] = (entry.value as List)
          .cast<String>()
          .map(rule)
          .toList();
    }
    final rules = (source['rules'] as List? ?? [])
        .cast<String>()
        .map(rule)
        .toList();
    subRules[binding.ruleName] = switch (source['mode']) {
      'direct' => ['MATCH,DIRECT'],
      'global' => ['MATCH,$globalName'],
      _ => [...rules, 'MATCH,DIRECT'],
    };
  }
  return {
    if (proxies.isNotEmpty) 'proxies': proxies,
    if (groups.isNotEmpty) 'proxy-groups': groups,
    if (subRules.isNotEmpty) 'sub-rules': subRules,
    if (ruleProviders.isNotEmpty) 'rule-providers': ruleProviders,
  };
}

Map<String, dynamic> _aggregateDocument(
  PortBinding binding,
  Map<int, Map<String, dynamic>> sources,
  String testUrl,
) {
  final base = sources[binding.profileId];
  if (base == null || !binding.sourceIds.every(sources.containsKey)) {
    throw const PortRoutingException(PortRoutingIssue.missingSubscription);
  }
  final nodes = (base['proxies'] as List).cast<Map>();
  final baseGroups = (base['proxy-groups'] as List? ?? []).cast<Map>();
  final compiled = compilePriorityPolicies(
    base: {
      ...base,
      'proxy-groups': [
        for (final group in baseGroups)
          {
            ...group.cast<String, dynamic>(),
            'proxies': _policyMembers(group, nodes),
            'include-all': false,
            'include-all-proxies': false,
            'include-all-providers': false,
            'exclude-filter': '',
          },
      ],
    },
    policies: binding.policies,
    sourcePaths: {for (final id in binding.sourceIds) id: ''},
    testUrl: testUrl,
  );
  final imported = <String, Map<String, dynamic>>{};
  final members = <String, List<String>>{};
  final names = {
    for (final node in nodes) node['name'] as String,
    for (final group in compiled.config['proxy-groups'] as List)
      group['name'] as String,
  };
  for (final policy in binding.policies) {
    for (final (index, tier) in policy.tiers.indexed) {
      if (tier.isLocal) continue;
      final selected = <String>[];
      for (final id in tier.sourceIds) {
        final sourceNodes = (sources[id]!['proxies'] as List).cast<Map>();
        final matches = priorityMatches(
          tier,
          sourceNodes.map((node) => node['name'] as String),
        ).toSet();
        for (final node in sourceNodes) {
          if (!matches.contains(node['name'])) continue;
          final name = '${priorityNodePrefix(id)}${node['name']}';
          if (names.contains(name)) {
            throw const PriorityPolicyException(PriorityPolicyIssue.collision);
          }
          imported[name] = {...node.cast<String, dynamic>(), 'name': name};
          selected.add(name);
        }
      }
      members['${policy.group} · ${index + 1}'] = selected.isEmpty
          ? ['REJECT']
          : selected;
    }
  }
  return {
    ...compiled.config,
    'mode': 'rule',
    'proxies': [...nodes, ...imported.values],
    'proxy-groups': [
      for (final group in (compiled.config['proxy-groups'] as List).cast<Map>())
        if (members[group['name']] case final values?)
          {
            for (final entry in group.entries)
              if (!{'use', 'filter', 'exclude-filter'}.contains(entry.key))
                entry.key as String: entry.value,
            'proxies': values,
          }
        else
          group,
    ],
  };
}

List<String> _policyMembers(Map group, List<Map> nodes) {
  bool matches(String name, String pattern) {
    try {
      return pattern.split('`').any((part) {
        final insensitive = part.startsWith('(?i)');
        return RegExp(
          insensitive ? part.substring(4) : part,
          caseSensitive: !insensitive,
        ).hasMatch(name);
      });
    } on FormatException {
      throw const PortRoutingException(
        PortRoutingIssue.unsupportedSubscription,
      );
    }
  }

  final members = <String>{...(group['proxies'] as List? ?? []).cast<String>()};
  if (group['include-all'] == true || group['include-all-proxies'] == true) {
    final filter = group['filter'] as String? ?? '';
    members.addAll(
      nodes
          .map((node) => node['name'] as String)
          .where((name) => filter.isEmpty || matches(name, filter)),
    );
  }
  final exclude = group['exclude-filter'] as String? ?? '';
  if (exclude.isNotEmpty) members.removeWhere((name) => matches(name, exclude));
  return members.isEmpty
      ? [group['empty-fallback'] as String? ?? 'COMPATIBLE']
      : members.toList();
}

String _renameRule(
  String raw,
  Map<String, String> targets,
  Map<String, String> providers,
  Map<String, String> subRules,
) {
  final fields = raw.split(',').map((field) => field.trim()).toList();
  final type = fields.first.toUpperCase();
  final index = switch (type) {
    'MATCH' => 1,
    'AND' ||
    'OR' ||
    'NOT' ||
    'SUB-RULE' ||
    'DOMAIN-REGEX' ||
    'PROCESS-NAME-REGEX' ||
    'PROCESS-PATH-REGEX' => fields.length - 1,
    _ => 2,
  };
  if (index >= fields.length) {
    throw const PortRoutingException(PortRoutingIssue.unsupportedSubscription);
  }
  final mapping = type == 'SUB-RULE' ? subRules : targets;
  fields[index] = mapping[fields[index]] ?? fields[index];
  return fields
      .join(',')
      .replaceAllMapped(
        RegExp(r'(^|\()RULE-SET,([^,()]+)'),
        (match) => '${match[1]}RULE-SET,${providers[match[2]] ?? match[2]}',
      );
}
