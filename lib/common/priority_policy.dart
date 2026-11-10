import 'package:fl_clash/models/priority_policy.dart';

enum PriorityPolicyIssue {
  invalid,
  missingSource,
  missingTarget,
  cycle,
  collision,
}

class PriorityPolicyException implements Exception {
  final PriorityPolicyIssue issue;

  const PriorityPolicyException(this.issue);

  @override
  String toString() => 'PriorityPolicyException(${issue.name})';
}

String priorityProviderName(int id) => 'portweave_priority_source_$id';
String priorityNodePrefix(int id) => '[priority:$id] ';

List<String> priorityKeywords(String value) => value
    .split('|')
    .map((word) => word.trim().toLowerCase())
    .where((word) => word.isNotEmpty)
    .toList();

List<String> priorityMatches(PriorityTier tier, Iterable<String> names) {
  final include = priorityKeywords(tier.filter);
  final exclude = priorityKeywords(tier.exclude);
  return names.where((name) {
    final lower = name.toLowerCase();
    return (include.isEmpty || include.any(lower.contains)) &&
        !exclude.any(lower.contains);
  }).toList();
}

({int count, List<(int, String)> sample}) priorityPreview(
  (PriorityTier, Map<int, List<String>>) input,
) {
  var count = 0;
  final sample = <(int, String)>[];
  for (final entry in input.$2.entries) {
    final matches = priorityMatches(input.$1, entry.value);
    count += matches.length;
    for (final name in matches.take(12 - sample.length)) {
      sample.add((entry.key, name));
    }
  }
  return (count: count, sample: sample);
}

void validatePriorityPolicies(List<PriorityPolicy> policies) {
  final groups = <String>{};
  for (final policy in policies) {
    if (policy.profileId <= 0 ||
        policy.group.isEmpty ||
        !groups.add(policy.group) ||
        policy.tiers.isEmpty) {
      throw const PriorityPolicyException(PriorityPolicyIssue.invalid);
    }
    for (final tier in policy.tiers) {
      if (tier.isLocal
          ? tier.sourceIds.isNotEmpty
          : tier.sourceIds.isEmpty ||
                tier.sourceIds.any((id) => id <= 0 || id == policy.profileId) ||
                tier.sourceIds.toSet().length != tier.sourceIds.length) {
        throw const PriorityPolicyException(PriorityPolicyIssue.invalid);
      }
    }
  }
}

String _literal(String value) => RegExp.escape(value).replaceAll('`', r'\x60');

({Map<String, dynamic> config, Map<String, dynamic> providers})
compilePriorityPolicies({
  required Map<String, dynamic> base,
  required List<PriorityPolicy> policies,
  required Map<int, String> sourcePaths,
  required String testUrl,
}) {
  validatePriorityPolicies(policies);
  final baseGroups = (base['proxy-groups'] as List? ?? []).cast<Map>();
  final names = <String>{
    'DIRECT',
    'REJECT',
    'REJECT-DROP',
    'PASS',
    'COMPATIBLE',
    'GLOBAL',
    for (final node in (base['proxies'] as List? ?? []).cast<Map>())
      node['name'] as String,
    for (final group in baseGroups) group['name'] as String,
  };
  final sourceIds = policies.expand((policy) => policy.sourceIds).toSet();
  if (!sourceIds.every(sourcePaths.containsKey)) {
    throw const PriorityPolicyException(PriorityPolicyIssue.missingSource);
  }
  final oldProviders = (base['proxy-providers'] as Map? ?? {}).keys.toSet();
  for (final id in sourceIds) {
    if (oldProviders.contains(priorityProviderName(id)) ||
        names.contains(priorityProviderName(id))) {
      throw const PriorityPolicyException(PriorityPolicyIssue.collision);
    }
  }
  final replacements = <String, Map<String, dynamic>>{};
  final generated = <Map<String, dynamic>>[];
  for (final policy in policies) {
    if (!baseGroups.any((group) => group['name'] == policy.group)) {
      throw const PriorityPolicyException(PriorityPolicyIssue.missingTarget);
    }
    final targets = <String>[];
    for (final (tierIndex, tier) in policy.tiers.indexed) {
      if (tier.isLocal) {
        if (!names.contains(tier.target) || tier.target == 'GLOBAL') {
          throw const PriorityPolicyException(
            PriorityPolicyIssue.missingTarget,
          );
        }
        targets.add(tier.target);
        continue;
      }
      final name = '${policy.group} · ${tierIndex + 1}';
      if (!names.add(name) || oldProviders.contains(name)) {
        throw const PriorityPolicyException(PriorityPolicyIssue.collision);
      }
      targets.add(name);
      final prefixes = tier.sourceIds
          .map((id) => _literal(priorityNodePrefix(id)))
          .join('|');
      final words = priorityKeywords(tier.filter);
      generated.add({
        'name': name,
        'type': 'url-test',
        'use': [for (final id in tier.sourceIds) priorityProviderName(id)],
        'filter':
            '(?i)^(?:$prefixes)${words.isEmpty ? ".*" : ".*(?:${words.map(_literal).join('|')}).*"}\$',
        if (priorityKeywords(tier.exclude).isNotEmpty)
          'exclude-filter':
              '(?i)^(?:$prefixes).*(?:${priorityKeywords(tier.exclude).map(_literal).join('|')}).*\$',
        'empty-fallback': 'REJECT',
        'url': testUrl,
        'interval': 60,
        'tolerance': 50,
        'lazy': false,
        'hidden': true,
      });
    }
    replacements[policy.group] = {
      'name': policy.group,
      'type': 'fallback',
      'proxies': targets,
      'url': testUrl,
      'interval': 60,
      'lazy': false,
      'empty-fallback': 'REJECT',
    };
  }
  final groups = <Map<String, dynamic>>[
    for (final group in baseGroups)
      replacements[group['name']] ??
          {
            ...group.cast<String, dynamic>(),
            if (group['include-all'] == true ||
                group['include-all-providers'] == true) ...{
              'include-all': false,
              'include-all-providers': false,
              'include-all-proxies':
                  group['include-all'] == true ||
                  group['include-all-proxies'] == true,
              'use': oldProviders.toList(),
            },
          },
    ...generated,
  ];
  final graph = {
    for (final node in (base['proxies'] as List? ?? []).cast<Map>())
      if (node['dialer-proxy'] case final String target when target.isNotEmpty)
        node['name'] as String: [target],
    for (final group in groups)
      group['name'] as String: (group['proxies'] as List? ?? []).cast<String>(),
  };
  final visiting = <String>{};
  final complete = <String>{};
  void visit(String name) {
    if (complete.contains(name) || !graph.containsKey(name)) return;
    if (!visiting.add(name)) {
      throw const PriorityPolicyException(PriorityPolicyIssue.cycle);
    }
    for (final next in graph[name]!) {
      visit(next);
    }
    visiting.remove(name);
    complete.add(name);
  }

  for (final name in graph.keys) {
    visit(name);
  }
  return (
    config: {...base, 'proxy-groups': groups},
    providers: {
      for (final id in sourceIds)
        priorityProviderName(id): {
          'type': 'file',
          'path': sourcePaths[id],
          'override': {'additional-prefix': priorityNodePrefix(id)},
          'health-check': {
            'enable': true,
            'url': testUrl,
            'interval': 60,
            'lazy': false,
          },
        },
    },
  );
}
