import 'package:fl_clash/common/port_display.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/models/port_routing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parsePortDisplayName & displayPortName', () {
    test('strips single [port:<id>] prefix', () {
      final parsed = parsePortDisplayName('[port:1] 🇺🇸 美国 01');
      expect(parsed, const PortDisplayName(name: '🇺🇸 美国 01', bindingId: 1));
      expect(displayPortName('[port:1] 🇺🇸 美国 01'), '🇺🇸 美国 01');
    });

    test('strips single [priority:<id>] and [ports:<id>] prefixes', () {
      expect(
        parsePortDisplayName('[priority:3] 🇯🇵 日本 02'),
        const PortDisplayName(name: '🇯🇵 日本 02', sourceProfileId: 3),
      );
      expect(
        parsePortDisplayName('[ports:2] 🇸🇬 新加坡 01'),
        const PortDisplayName(name: '🇸🇬 新加坡 01', sourceProfileId: 2),
      );
    });

    test('strips double [port:<id>] [priority:<id>] prefix', () {
      final parsed = parsePortDisplayName('[port:1] [priority:3] 🇺🇸 美国 01');
      expect(
        parsed,
        const PortDisplayName(
          name: '🇺🇸 美国 01',
          bindingId: 1,
          sourceProfileId: 3,
        ),
      );
      expect(displayPortName('[port:1] [priority:3] 🇺🇸 美国 01'), '🇺🇸 美国 01');
    });

    test('does not strip unknown IDs when valid sets are supplied', () {
      final parsed = parsePortDisplayName(
        '[port:999] User Node',
        validBindingIds: {1, 2},
      );
      expect(parsed, const PortDisplayName(name: '[port:999] User Node'));

      final unknownSource = parsePortDisplayName(
        '[port:1] [priority:999] Node A',
        validBindingIds: {1},
        validProfileIds: {3},
      );
      expect(
        unknownSource,
        const PortDisplayName(name: '[priority:999] Node A', bindingId: 1),
      );

      final unknownPorts = parsePortDisplayName(
        '[ports:99] Node B',
        validProfileIds: {2},
      );
      expect(unknownPorts, const PortDisplayName(name: '[ports:99] Node B'));
    });

    test('leaves plain normal node names untouched', () {
      const plain = '🇭🇰 香港 01 [高速]';
      expect(
        parsePortDisplayName(plain, validBindingIds: {1}, validProfileIds: {2}),
        const PortDisplayName(name: plain),
      );
      expect(displayPortName(plain), plain);
    });
  });

  group('portSourceLabel', () {
    const profileLabels = {1: '机场 A', 3: '备用机场 B'};
    const aggregateBinding = PortBinding(
      id: 1,
      name: '聚合端口',
      profileId: 1,
      port: 10001,
      selection: PortSelection.aggregate,
    );
    const originalBinding = PortBinding(
      id: 2,
      name: '单订阅端口',
      profileId: 1,
      port: 10002,
      selection: PortSelection.original,
    );
    const bindingsById = {1: aggregateBinding, 2: originalBinding};

    test('returns backup subscription label for priority/ports prefix', () {
      expect(
        portSourceLabel(
          '[port:1] [priority:3] 🇺🇸 美国 01',
          profileLabels: profileLabels,
          bindingsById: bindingsById,
        ),
        '备用机场 B',
      );
      expect(
        portSourceLabel('[ports:3] 🇺🇸 美国 01', profileLabels: profileLabels),
        '备用机场 B',
      );
    });

    test('returns base profile label only for aggregate port bindings', () {
      expect(
        portSourceLabel(
          '[port:1] 🇺🇸 美国 01',
          profileLabels: profileLabels,
          bindingsById: bindingsById,
        ),
        '机场 A',
      );
      expect(
        portSourceLabel(
          '[port:2] 🇺🇸 美国 01',
          profileLabels: profileLabels,
          bindingsById: bindingsById,
        ),
        isNull,
      );
    });

    test('returns null for plain names or unknown IDs', () {
      expect(
        portSourceLabel(
          '[port:999] 🇺🇸 美国 01',
          profileLabels: profileLabels,
          bindingsById: bindingsById,
        ),
        isNull,
      );
      expect(
        portSourceLabel(
          'DIRECT',
          profileLabels: profileLabels,
          bindingsById: bindingsById,
        ),
        isNull,
      );
    });
  });

  group('resolveDisplaySelected & formatDisplayWithSource', () {
    const profileLabels = {1: '主订阅', 3: '备用订阅'};
    const bindingsById = {
      1: PortBinding(
        id: 1,
        name: '聚合端口',
        profileId: 1,
        port: 10001,
        selection: PortSelection.aggregate,
      ),
    };

    test('traverses hidden tier groups to final node and source', () {
      final groupsByName = {
        '[port:1] AI · 1': const Group(
          type: GroupType.URLTest,
          name: '[port:1] AI · 1',
          hidden: true,
          now: '[port:1] [priority:3] 🤖 OpenAI 01',
        ),
      };

      final resolved = resolveDisplaySelected(
        '[port:1] AI · 1',
        groupsByName: groupsByName,
        profileLabels: profileLabels,
        bindingsById: bindingsById,
      );
      expect(resolved.name, '🤖 OpenAI 01');
      expect(resolved.source, '备用订阅');
      expect(
        formatDisplayWithSource(resolved.name, resolved.source),
        '备用订阅 · 🤖 OpenAI 01',
      );
    });

    test('stops at visible (non-hidden) group', () {
      final groupsByName = {
        '[port:1] AI': const Group(
          type: GroupType.Fallback,
          name: '[port:1] AI',
          hidden: false,
          now: '[port:1] AI · 1',
        ),
        '[port:1] AI · 1': const Group(
          type: GroupType.URLTest,
          name: '[port:1] AI · 1',
          hidden: true,
          now: '[port:1] 🇺🇸 美国 01',
        ),
      };

      final resolved = resolveDisplaySelected(
        '[port:1] AI',
        groupsByName: groupsByName,
        profileLabels: profileLabels,
        bindingsById: bindingsById,
      );
      expect(resolved.name, 'AI');
      expect(resolved.source, '主订阅');
    });

    test('prevents infinite loops on cycles and respects maxDepth', () {
      final cyclicGroups = {
        'A': const Group(
          type: GroupType.URLTest,
          name: 'A',
          hidden: true,
          now: 'B',
        ),
        'B': const Group(
          type: GroupType.URLTest,
          name: 'B',
          hidden: true,
          now: 'A',
        ),
      };
      expect(
        resolveDisplaySelected(
          'A',
          groupsByName: cyclicGroups,
          profileLabels: profileLabels,
        ),
        (name: 'A', source: null),
      );

      final deepGroups = {
        'G0': const Group(
          type: GroupType.URLTest,
          name: 'G0',
          hidden: true,
          now: 'G1',
        ),
        'G1': const Group(
          type: GroupType.URLTest,
          name: 'G1',
          hidden: true,
          now: 'G2',
        ),
        'G2': const Group(
          type: GroupType.URLTest,
          name: 'G2',
          hidden: true,
          now: 'Leaf',
        ),
      };
      expect(
        resolveDisplaySelected(
          'G0',
          groupsByName: deepGroups,
          profileLabels: profileLabels,
          maxDepth: 2,
        ),
        (name: 'G2', source: null),
      );
    });

    test('formatDisplayWithSource omits empty or null source', () {
      expect(formatDisplayWithSource('🇺🇸 美国 01', null), '🇺🇸 美国 01');
      expect(formatDisplayWithSource('🇺🇸 美国 01', ''), '🇺🇸 美国 01');
      expect(formatDisplayWithSource('🇺🇸 美国 01', '主订阅'), '主订阅 · 🇺🇸 美国 01');
    });

    test(
      'formatPortChainLabel formats source-first and falls back to binding name',
      () {
        expect(
          formatPortChainLabel(
            '[port:1] [priority:3] TW-Fixed-01',
            profileLabels: profileLabels,
            bindingsById: bindingsById,
          ),
          '备用订阅 · TW-Fixed-01',
        );
        expect(
          formatPortChainLabel(
            '[port:1] TW-Fixed-01',
            profileLabels: profileLabels,
            bindingsById: bindingsById,
          ),
          '主订阅 · TW-Fixed-01',
        );
        const glados = PortBinding(
          id: 378340364773232640,
          name: 'Glados',
          profileId: 9,
          port: 18081,
        );
        expect(
          formatPortChainLabel(
            '[port:378340364773232640] TW-Fixed-01',
            bindingsById: {glados.id: glados},
          ),
          'Glados · TW-Fixed-01',
        );
        expect(
          formatPortChainLabel('[port:378340364773232640] TW-Fixed-01'),
          'TW-Fixed-01',
        );
      },
    );
  });
}
