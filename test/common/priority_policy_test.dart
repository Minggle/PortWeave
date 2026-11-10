import 'dart:convert';

import 'package:fl_clash/common/priority_policy.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> base() => {
  'proxies': [
    {'name': 'Taiwan A', 'type': 'socks5'},
    {'name': 'US A', 'type': 'socks5'},
  ],
  'proxy-groups': [
    {
      'name': 'Taiwan',
      'type': 'fallback',
      'proxies': ['Taiwan A'],
    },
    {
      'name': 'US',
      'type': 'fallback',
      'proxies': ['US A'],
    },
    {
      'name': 'Video',
      'type': 'select',
      'proxies': ['Taiwan', 'US'],
    },
  ],
  'rules': ['DOMAIN-SUFFIX,cn,DIRECT', 'DOMAIN,video.test,Video', 'MATCH,US'],
  'dns': {'enable': true},
};

const policy = PriorityPolicy(
  profileId: 10,
  group: 'Video',
  tiers: [
    PriorityTier(target: 'Taiwan'),
    PriorityTier(sourceIds: [11, 22], filter: 'US|美国', exclude: 'expired|到期'),
    PriorityTier(sourceIds: [33], filter: 'HK'),
  ],
);

void main() {
  test(
    'business rules keep their target and ordered tiers do not insert US or direct',
    () {
      final source = base();
      final snapshot = jsonEncode(source);
      final result = compilePriorityPolicies(
        base: source,
        policies: [policy],
        sourcePaths: {11: '/a', 22: '/b', 33: '/c'},
        testUrl: 'https://test.example',
      );
      expect(jsonEncode(source), snapshot);
      expect(result.config['rules'], source['rules']);
      expect(result.config['dns'], source['dns']);
      final groups = result.config['proxy-groups'] as List;
      final video = groups.firstWhere((g) => g['name'] == 'Video');
      expect(video['type'], 'fallback');
      expect(video['proxies'], ['Taiwan', 'Video · 2', 'Video · 3']);
      expect(video.containsKey('default-selected'), isFalse);
      expect(video['lazy'], isFalse);
      final tier = groups.firstWhere((g) => g['name'] == 'Video · 2');
      expect(tier['use'], [priorityProviderName(11), priorityProviderName(22)]);
      expect(tier['type'], 'url-test');
      expect(tier['empty-fallback'], 'REJECT');
      final regex = RegExp(
        (tier['filter'] as String).replaceFirst('(?i)', ''),
        caseSensitive: false,
      );
      expect(regex.hasMatch('${priorityNodePrefix(11)}US A'), isTrue);
      expect(regex.hasMatch('${priorityNodePrefix(22)}美国 B'), isTrue);
      expect(regex.hasMatch('${priorityNodePrefix(33)}US A'), isFalse);
    },
  );

  test('keywords refresh membership without storing node names', () {
    final tier = policy.tiers[1];
    expect(priorityMatches(tier, ['US Old', 'US expired', 'JP']), ['US Old']);
    expect(priorityMatches(tier, ['美国 New', 'JP']), ['美国 New']);
    expect(priorityMatches(tier, ['JP']), isEmpty);
    expect(priorityMatches(const PriorityTier(sourceIds: [11]), ['A', 'B']), [
      'A',
      'B',
    ]);
  });

  test(
    'changing tier order changes fallback order and allows explicit direct',
    () {
      final result = compilePriorityPolicies(
        base: base(),
        policies: [
          policy.copyWith(
            tiers: [
              policy.tiers[2],
              policy.tiers[0],
              const PriorityTier(target: 'DIRECT'),
            ],
          ),
        ],
        sourcePaths: {33: '/c'},
        testUrl: 'https://test.example',
      );
      final group = (result.config['proxy-groups'] as List).firstWhere(
        (g) => g['name'] == 'Video',
      );
      expect(group['proxies'], ['Video · 1', 'Taiwan', 'DIRECT']);
    },
  );

  test(
    'cycles and deleted source references cannot silently change routing',
    () {
      expect(
        () => compilePriorityPolicies(
          base: base(),
          policies: [
            policy.copyWith(tiers: [const PriorityTier(target: 'Video')]),
          ],
          sourcePaths: {},
          testUrl: '',
        ),
        throwsA(isA<PriorityPolicyException>()),
      );
      expect(
        () => compilePriorityPolicies(
          base: base(),
          policies: [policy],
          sourcePaths: {11: '/a'},
          testUrl: '',
        ),
        throwsA(isA<PriorityPolicyException>()),
      );
      expect(
        () => compilePriorityPolicies(
          base: base(),
          policies: [policy.copyWith(group: 'Missing')],
          sourcePaths: {11: '/a', 22: '/b', 33: '/c'},
          testUrl: '',
        ),
        throwsA(isA<PriorityPolicyException>()),
      );
    },
  );

  test('backup remaps every tier and drops a chain with a missing source', () {
    const settings = PriorityPolicies(policies: [policy]);
    expect(
      PriorityPolicies.fromJson(jsonDecode(jsonEncode(settings))),
      settings,
    );
    final remapped = settings.remapProfiles({
      10: 100,
      11: 110,
      22: 220,
      33: 330,
    });
    expect(remapped.policies.single.profileId, 100);
    expect(remapped.policies.single.tiers[1].sourceIds, [110, 220]);
    expect(settings.remapProfiles({10: 100, 11: 110}).policies, isEmpty);
    expect(settings.references(22), isTrue);
  });

  test('existing include-all groups cannot absorb injected sources', () {
    final source = base();
    (source['proxy-groups'] as List).add({
      'name': 'Existing',
      'type': 'select',
      'include-all': true,
    });
    final result = compilePriorityPolicies(
      base: source,
      policies: [policy],
      sourcePaths: {11: '/a', 22: '/b', 33: '/c'},
      testUrl: 'https://test.example',
    );
    final group = (result.config['proxy-groups'] as List).firstWhere(
      (g) => g['name'] == 'Existing',
    );
    expect(group['include-all-providers'], isFalse);
    expect(group['include-all-proxies'], isTrue);
    expect(group['use'], isEmpty);
  });
}
