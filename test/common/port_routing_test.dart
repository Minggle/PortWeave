import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/port_probe.dart';
import 'package:fl_clash/common/port_routing.dart';
import 'package:fl_clash/common/task.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const fixed = PortBinding(
  id: 1,
  name: 'Browser',
  profileId: 11,
  port: 18081,
  node: 'US [01]',
);
const regional = PortBinding(
  id: 2,
  name: 'Editor',
  profileId: 22,
  port: 18082,
  selection: PortSelection.region,
  filter: 'JP|日本',
);

void main() {
  test(
    'REALITY short ids preserve YAML scalar text before Core JSON validation',
    () {
      for (final id in ['0123', '00', '1e5', '1e999', '0189', '0a1b']) {
        final nodes = portSubscriptionNodes(
          'proxies: [{name: US, type: vless, reality-opts: {short-id: $id}}]',
        );
        final encoded = jsonDecode(jsonEncode(nodes)) as List;
        expect(encoded.single['reality-opts']['short-id'], id);
      }
    },
  );

  test(
    'keyword bindings aggregate sources while keeping duplicate names separate',
    () {
      final binding = regional.copyWith(
        profileId: 11,
        additionalProfileIds: [22],
        filter: 'US',
      );
      final result = compilePortRouting(
        bindings: [binding],
        sourcePaths: {11: '/a', 22: '/b'},
        testUrl: 'https://example.test',
      );
      final group = (result.config['proxy-groups'] as List).single;
      expect(group['use'], [portProviderName(11), portProviderName(22)]);
      final pattern = RegExp(
        (group['filter'] as String).replaceFirst('(?i)', ''),
        caseSensitive: false,
      );
      expect(pattern.hasMatch('${portNodePrefix(11)}US Same'), isTrue);
      expect(pattern.hasMatch('${portNodePrefix(22)}US Same'), isTrue);
      expect(pattern.hasMatch('${portNodePrefix(33)}US Same'), isFalse);
      expect(pattern.hasMatch('${portNodePrefix(22)}Japan'), isFalse);
      expect(group['empty-fallback'], 'REJECT');
      final config = PortRoutingConfig(bindings: [binding]);
      expect(config.sourceIds, {11, 22});
      final restored = PortRoutingConfig.fromJson(
        jsonDecode(jsonEncode(config)),
      );
      expect(restored, config);
      expect(
        config.remapProfiles({11: 111, 22: 222}).bindings.single.sourceIds,
        {111, 222},
      );
      expect(config.remapProfiles({11: 111}).bindings, isEmpty);
    },
  );

  test(
    'original policies preserve per-subscription rules and group selections',
    () {
      final binding = fixed.copyWith(
        selection: PortSelection.original,
        node: '',
      );
      final source = portSubscriptionDocument('''
proxies: [{name: US, type: socks5, server: localhost, port: 1234}]
proxy-groups:
  - {name: Select, type: select, proxies: [US, DIRECT]}
  - {name: Auto, type: url-test, proxies: [US], url: 'https://test.example', interval: 60}
rule-providers:
  ads: {type: inline, behavior: domain, payload: [ads.example]}
sub-rules:
  nested: ["RULE-SET,ads,REJECT", "MATCH,Select"]
rules:
  - DOMAIN,local.example,DIRECT
  - SUB-RULE,(NETWORK,TCP),nested
  - MATCH,Auto
''');
      final other = binding.copyWith(id: 2, profileId: 22, port: 18082);
      final result = compilePortRouting(
        bindings: [binding, other],
        sourcePaths: {11: '/a', 22: '/b'},
        sourceDocuments: {11: source, 22: source},
        selectedMaps: {
          11: {'Select': 'US'},
        },
        testUrl: '',
      );
      final listeners = result.config['listeners'] as List;
      expect(listeners[0]['rule'], binding.ruleName);
      expect(listeners[0].containsKey('proxy'), isFalse);
      final groups = result.config['proxy-groups'] as List;
      expect(groups.first['default-selected'], '[port:1] US');
      expect(groups.first['proxies'], ['[port:1] US', 'DIRECT']);
      expect(groups[1]['type'], 'url-test');
      expect(groups[1]['interval'], 60);
      expect(result.config['sub-rules'][binding.ruleName], [
        'DOMAIN,local.example,DIRECT',
        'SUB-RULE,(NETWORK,TCP),[port:1] nested',
        'MATCH,[port:1] Auto',
        'MATCH,DIRECT',
      ]);
      expect(result.config['sub-rules']['[port:2] nested'], [
        'RULE-SET,[port:2] ads,REJECT',
        'MATCH,[port:2] Select',
      ]);
      expect((result.config['rule-providers'] as Map).keys, [
        '[port:1] ads',
        '[port:2] ads',
      ]);
    },
  );

  test('include-all stays within its source and matches unprefixed names', () {
    final binding = fixed.copyWith(selection: PortSelection.original, node: '');
    final source = portSubscriptionDocument('''
proxies: [{name: US, type: socks5}, {name: JP, type: socks5}]
proxy-groups: [{name: Auto, type: url-test, include-all: true, filter: '^US', url: 'https://test.example'}]
rules: ['MATCH,Auto']
''');
    final result = compilePortRouting(
      bindings: [binding],
      sourcePaths: {11: '/a'},
      sourceDocuments: {11: source},
      testUrl: '',
    );
    final group = (result.config['proxy-groups'] as List).first;
    expect(group['proxies'], ['[port:1] US']);
    expect(group['include-all'], isFalse);
  });

  test('dedicated runtime settings leave the saved host settings intact', () {
    const saved = PatchClashConfig(
      mixedPort: 7897,
      port: 8080,
      socksPort: 1080,
      allowLan: true,
      mode: Mode.global,
      tun: Tun(enable: true),
      externalController: ExternalControllerStatus.open,
    );
    final effective = portRoutingPatch(saved);
    expect(effective.mixedPort, 0);
    expect(effective.port, 0);
    expect(effective.socksPort, 0);
    expect(effective.tun.enable, isFalse);
    expect(effective.externalController, ExternalControllerStatus.close);
    expect(effective.mode, Mode.rule);
    expect(saved.tun.enable, isTrue);
    expect(saved.mixedPort, 7897);
  });
  test('ports isolate sources, nodes and routing, with explicit rejection', () {
    final result = compilePortRouting(
      bindings: [
        fixed,
        regional,
        regional.copyWith(id: 3, port: 18083, profileId: 11),
      ],
      sourcePaths: {11: '/source/11.yaml', 22: '/source/22.yaml'},
      testUrl: 'https://example.test',
    );
    final groups = result.config['proxy-groups'] as List;
    final listeners = result.config['listeners'] as List;
    expect(result.providers.length, 2);
    expect(groups[0]['use'], [portProviderName(11)]);
    expect(groups[1]['use'], [portProviderName(22)]);
    expect(groups[2]['use'], [portProviderName(11)]);
    expect(groups.map((g) => g['empty-fallback']), everyElement('REJECT'));
    final exact = RegExp(groups[0]['filter'] as String);
    expect(exact.hasMatch('${portNodePrefix(11)}US [01]'), isTrue);
    expect(exact.hasMatch('${portNodePrefix(11)}US 01'), isFalse);
    expect(exact.hasMatch('${portNodePrefix(22)}US [01]'), isFalse);
    expect(listeners.map((l) => l['listen']), everyElement('127.0.0.1'));
    expect(listeners.map((l) => l['udp']), everyElement(false));
    expect(listeners[1]['proxy'], regional.groupName);
    expect(listeners[0]['users'], isEmpty);
    expect(result.config['rules'], ['MATCH,REJECT']);
  });

  test('fixed names escape provider separator and regex metacharacters', () {
    final result = compilePortRouting(
      bindings: [fixed.copyWith(node: 'a`b.*')],
      sourcePaths: {11: '/11'},
      testUrl: 'https://example.test',
    );
    final filter =
        (result.config['proxy-groups'] as List).single['filter'] as String;
    expect(filter, isNot(contains('`')));
    expect(RegExp(filter).hasMatch('${portNodePrefix(11)}a`b.*'), isTrue);
    expect(RegExp(filter).hasMatch('${portNodePrefix(11)}a`bXX'), isFalse);
  });

  test('region preview uses literal words rather than arbitrary regex', () {
    expect(
      matchingPortNodes(regional, ['US', 'jp fast', '日本 A', 'Hong Kong']),
      ['jp fast', '日本 A'],
    );
    expect(
      matchingPortNodes(regional.copyWith(filter: '[JP]'), ['JP', '[JP]']),
      ['[JP]'],
    );
    expect(matchingPortNodes(fixed, ['US [01]', 'US 01']), ['US [01]']);
  });

  test('invalid or colliding ports fail without changing their numbers', () {
    for (final port in [0, 80, 65536]) {
      expect(
        () => validatePortBindings([fixed.copyWith(port: port)]),
        throwsA(isA<PortRoutingException>()),
      );
    }
    expect(
      () => validatePortBindings([fixed, regional.copyWith(port: 18081)]),
      throwsA(isA<PortRoutingException>()),
    );
    expect(
      () => validatePortBindings([regional.copyWith(filter: ' | ')]),
      throwsA(isA<PortRoutingException>()),
    );
    expect(
      () => compilePortRouting(bindings: [fixed], sourcePaths: {}, testUrl: ''),
      throwsA(isA<PortRoutingException>()),
    );
  });

  test('source extraction rejects unsupported, empty and ambiguous content', () {
    for (final source in [
      'proxies: []',
      'not: a-subscription',
      '<html>login</html>',
      'proxies: [{name: A, type: direct}]',
      'proxies: [{name: A, type: ss, dialer-proxy: Group}]',
      'proxies: [{name: A, type: ss}, {name: A, type: ss}]',
      'proxies: [{name: A, type: ss}]\nproxy-providers: {nested: {type: http}}',
    ]) {
      expect(
        () => portSubscriptionNodes(source),
        throwsA(isA<PortRoutingException>()),
        reason: source,
      );
    }
    final nodes = portSubscriptionNodes(
      'proxies: [{name: A, type: ss, server: example.test}]\nrules: [MATCH,DIRECT]',
    );
    expect(nodes.single['name'], 'A');
  });

  test('old settings default off and bindings round-trip and remap', () {
    expect(Config.realFromJson({}).portRouting, const PortRoutingConfig());
    const config = PortRoutingConfig(
      workspaceProfileId: 9,
      previousProfileId: 11,
      bindings: [fixed, regional],
      subscriptions: [
        PortSubscriptionRefresh(
          profileId: 22,
          enabled: false,
          intervalMinutes: 17,
        ),
      ],
    );
    expect(PortRoutingConfig.fromJson(jsonDecode(jsonEncode(config))), config);
    final remapped = config.remapProfiles({9: 90, 11: 110, 22: 220});
    expect(remapped.workspaceProfileId, 90);
    expect(remapped.previousProfileId, 110);
    expect(remapped.bindings.map((b) => b.profileId), [110, 220]);
    expect(remapped.refreshFor(220).enabled, isFalse);
    expect(remapped.refreshFor(110).intervalMinutes, 5);
    expect(config.remapProfiles({11: 110}).workspaceProfileId, isNull);
  });

  test(
    'safe mode clears generated listeners after provider injection',
    () async {
      final fragment = compilePortRouting(
        bindings: [fixed],
        sourcePaths: {11: '/source.yaml'},
        testUrl: 'https://example.test',
      );
      final result = await makeRealProfileTask(
        MakeRealProfileState(
          profilesPath: '/profiles',
          profileId: 9,
          rawConfig: fragment.config,
          realPatchConfig: const PatchClashConfig(mixedPort: 0),
          appendSystemDns: false,
          proxyGroups: [],
          rules: [],
          addedRules: [],
          defaultUA: 'test',
          safeMode: true,
          injectedProxyProviders: fragment.providers,
        ),
      );
      final yaml = loadYaml(result.yaml) as Map;
      expect(yaml['listeners'], isEmpty);
      expect(yaml['mixed-port'], 0);
      expect(
        yaml['proxy-providers'][portProviderName(11)]['path'],
        '/source.yaml',
      );
    },
  );

  test('Windows listener ownership ignores established sockets', () {
    final owners = parseWindowsPortOwners('''
 TCP    127.0.0.1:18081  0.0.0.0:0  LISTENING  1234
 TCP    0.0.0.0:18082  0.0.0.0:0  LISTENING  5678
 TCP    127.0.0.1:18081  127.0.0.1:43000  ESTABLISHED  9999
''');
    expect(owners, {18081: 1234, 18082: 5678});
  });

  test('macOS listener fields preserve PID across file records', () {
    expect(
      parseMacOSPortOwners('''
p1234
f10
n127.0.0.1:18081
f11
n*:18082
p5678
f12
n0.0.0.0:18083
n192.168.1.2:18084
n[::1]:18085
n127.0.0.1:18081->127.0.0.1:43000
pinvalid
n127.0.0.1:18086
'''),
      {18081: 1234, 18082: 1234, 18083: 5678},
    );
  });

  test('macOS ambiguous ownership never reports a trusted listener', () {
    expect(
      parseMacOSPortOwners('''
p1234
n127.0.0.1:18081
n127.0.0.1:18082
n127.0.0.1:18082
n127.0.0.1:65536
p5678
n*:18081
'''),
      {18082: 1234},
    );
    expect(parseMacOSPortOwners(''), isEmpty);
  });

  test(
    'macOS reads actual loopback listener ownership without elevation',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      expect((await desktopPortOwners())[server.port], pid);
      await checkPortAvailable(server.port, existingOwner: pid);
      await expectLater(
        checkPortAvailable(server.port, existingOwner: pid + 1),
        throwsA(isA<PortRoutingException>()),
      );
    },
    skip: !Platform.isMacOS,
  );

  test('occupied ports are rejected and SOCKS response may be split', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    await expectLater(
      checkPortAvailable(server.port),
      throwsA(isA<PortRoutingException>()),
    );
    final listener = server.listen((socket) {
      socket.listen((_) async {
        socket.add([5]);
        await socket.flush();
        socket.add([0]);
        await socket.flush();
        socket.destroy();
      });
    });
    addTearDown(listener.cancel);
    await checkSocksHandshake(server.port);
  });
}
