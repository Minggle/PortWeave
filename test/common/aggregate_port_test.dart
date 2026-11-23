import 'dart:convert';

import 'package:fl_clash/common/port_routing.dart';
import 'package:fl_clash/common/priority_policy.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

const _policy = PriorityPolicy(
  profileId: 11,
  group: 'Video',
  tiers: [
    PriorityTier(target: 'Self'),
    PriorityTier(sourceIds: [22, 33], filter: 'US', exclude: 'expired'),
  ],
);
const _binding = PortBinding(
  id: 7,
  name: 'Aggregate',
  profileId: 11,
  port: 18084,
  selection: PortSelection.aggregate,
  policies: [_policy],
);

Map<String, dynamic> _source(String name) => portSubscriptionDocument('''
proxies: [{name: '$name', type: socks5, server: 127.0.0.1, port: 1080}]
proxy-groups:
  - {name: Video, type: select, proxies: ['$name']}
  - {name: Everything, type: select, include-all: true}
rules: ['DOMAIN,video.test,Video', 'MATCH,REJECT']
''');

PortRoutingFragment _compile(
  List<PortBinding> bindings, {
  String first = 'US Same',
}) => compilePortRouting(
  bindings: bindings,
  sourcePaths: {11: '/base', 22: '/a', 33: '/b'},
  sourceDocuments: {
    11: _source('Self'),
    22: _source(first),
    33: _source('US Same'),
  },
  selectedMaps: {
    11: {'Video': 'Self'},
  },
  testUrl: 'http://probe.test/health',
);

void main() {
  test('aggregate and source ports have separate rules, groups and nodes', () {
    final ordinary = _binding.copyWith(
      id: 8,
      port: 18085,
      selection: PortSelection.original,
      policies: [],
    );
    final result = _compile([_binding, ordinary]);
    final groups = {
      for (final group in result.config['proxy-groups'] as List)
        group['name']: group,
    };
    expect(groups['[port:7] Video']['type'], 'fallback');
    expect(groups['[port:7] Video']['proxies'], [
      '[port:7] Self',
      '[port:7] Video · 2',
    ]);
    expect(groups['[port:7] Video'].containsKey('default-selected'), isFalse);
    expect(groups['[port:7] Video · 2']['proxies'], [
      '[port:7] [priority:22] US Same',
      '[port:7] [priority:33] US Same',
    ]);
    expect(groups['[port:7] Everything']['proxies'], ['[port:7] Self']);
    expect(groups['[port:8] Video']['type'], 'select');
    expect(groups['[port:8] Video']['proxies'], ['[port:8] Self']);
    final listeners = result.config['listeners'] as List;
    expect(listeners.map((listener) => listener['port']), [18084, 18085]);
    expect(listeners.map((listener) => listener['rule']).toSet(), hasLength(2));
    expect(
      result.config['sub-rules'][_binding.ruleName],
      contains('DOMAIN,video.test,[port:7] Video'),
    );
    expect(result.providers, isEmpty);
  });

  test('each aggregate port keeps its own priority order', () {
    final second = _binding.copyWith(
      id: 9,
      port: 18086,
      policies: [_policy.copyWith(tiers: _policy.tiers.reversed.toList())],
    );
    final result = _compile([_binding, second]);
    final groups = {
      for (final group in result.config['proxy-groups'] as List)
        group['name']: group,
    };
    expect(groups['[port:7] Video']['proxies'].first, '[port:7] Self');
    expect(groups['[port:9] Video']['proxies'].first, '[port:9] Video · 1');
  });

  test('source changes recalculate matches and empty tiers reject', () {
    final binding = _binding.copyWith(
      policies: [
        _policy.copyWith(
          tiers: [
            const PriorityTier(
              sourceIds: [22],
              filter: 'US',
              exclude: 'expired',
            ),
          ],
        ),
      ],
    );
    for (final name in ['JP', 'US expired']) {
      final result = _compile([binding], first: name);
      final tier = (result.config['proxy-groups'] as List).firstWhere(
        (group) => group['name'] == '[port:7] Video · 1',
      );
      expect(tier['proxies'], ['REJECT']);
    }
    final result = _compile([binding], first: 'US New');
    final tier = (result.config['proxy-groups'] as List).firstWhere(
      (group) => group['name'] == '[port:7] Video · 1',
    );
    expect(tier['proxies'], ['[port:7] [priority:22] US New']);
  });

  test('aggregate backup remaps every base and tier reference', () {
    const config = PortRoutingConfig(bindings: [_binding]);
    expect(PortRoutingConfig.fromJson(jsonDecode(jsonEncode(config))), config);
    final remapped = config
        .remapProfiles({11: 111, 22: 222, 33: 333})
        .bindings
        .single;
    expect(remapped.sourceIds, {111, 222, 333});
    expect(remapped.policies.single.profileId, 111);
    expect(remapped.policies.single.tiers.last.sourceIds, [222, 333]);
    expect(config.remapProfiles({11: 111, 22: 222}).bindings, isEmpty);
    final legacy = PortBinding.fromJson({
      'id': 1,
      'name': 'Old',
      'profileId': 11,
      'port': 18082,
      'node': 'Self',
    });
    expect(legacy.policies, isEmpty);
    expect(legacy.selection, PortSelection.fixed);
  });

  test('invalid base ownership and cyclic aggregate groups are rejected', () {
    expect(
      () => _compile([
        _binding.copyWith(policies: [_policy.copyWith(profileId: 22)]),
      ]),
      throwsA(isA<PortRoutingException>()),
    );
    expect(
      () => _compile([
        _binding.copyWith(
          policies: [
            _policy.copyWith(tiers: [const PriorityTier(target: 'Video')]),
          ],
        ),
      ]),
      throwsA(isA<PriorityPolicyException>()),
    );
  });
}
