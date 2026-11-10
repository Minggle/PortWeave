import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/port_routing.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../helpers/app_paths.dart';
import '../helpers/test_profiles.dart';

class _Core extends Mock implements CoreHandlerInterface {}

class _ProbeAction extends PortRoutingAction {
  int? processId = 1234;
  Future<Map<int, int>> Function() owners = () async => {};

  @override
  int? get coreProcessId => processId;

  @override
  Future<Map<int, int>> readPortOwners() => owners();
}

class _Setup extends SetupAction {
  int applies = 0;
  bool? running;
  Future<bool> Function()? onApply;
  @override
  void build() {}
  @override
  Future<bool> applyProfile({
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) async {
    applies++;
    return onApply == null ? true : await onApply!();
  }

  @override
  Future<bool> setRunning(bool value, {bool initialize = false}) async {
    running = value;
    return true;
  }
}

const _old =
    'proxies: [{name: "US One", type: socks5, server: 127.0.0.1, port: 10001}]';
const _new =
    'proxies: [{name: "US Two", type: socks5, server: 127.0.0.1, port: 10002}]';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory home;
  late HttpServer server;
  late _Core core;
  late ProviderContainer container;
  late _ProbeAction action;
  late File original;
  late Profile source;
  late _Setup setup;
  var content = _new;
  var requests = 0;
  Completer<void>? responseGate;
  HttpOverrides? originalOverrides;

  setUpAll(() async {
    originalOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    await AppLocalizations.load(const Locale('en'));
    globalState.packageInfo = PackageInfo(
      appName: 'FlClash',
      packageName: 'test',
      version: '0.9.3',
      buildNumber: '1',
    );
    registerFallbackValue(
      const SetupParams(
        selectedMap: {},
        options: CoreOptions(testUrl: 'https://example.test'),
      ),
    );
    registerFallbackValue(
      const ChangeProxyParams(groupName: '', proxyName: ''),
    );
  });

  tearDownAll(() {
    HttpOverrides.global = originalOverrides;
  });

  setUp(() async {
    requests = 0;
    responseGate = null;
    content = _new;
    home = await Directory.systemTemp.createTemp('flclash-port-update-');
    await useAppPaths(home);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests++;
      if (responseGate != null) await responseGate!.future;
      request.response.headers.contentType = ContentType.text;
      request.response.add(utf8.encode(content));
      await request.response.close();
    });
    core = _Core();
    setup = _Setup();
    when(() => core.validateConfig(any())).thenAnswer((_) async => null);
    when(() => core.validateProxies(any())).thenAnswer((_) async => {});
    when(
      () => core.sideLoadExternalProvider(
        providerName: any(named: 'providerName'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((_) async {});
    when(() => core.getExternalProviders()).thenAnswer((_) async => []);
    when(
      () => core.changeProxy(any()),
    ).thenAnswer((_) async => const ChangeProxyResult());
    when(() => core.getProxies()).thenAnswer(
      (_) async => const ProxiesData(
        all: ['one'],
        proxies: {
          'one': {
            'name': 'one',
            'type': 'Selector',
            'all': ['REJECT'],
            'now': 'REJECT',
          },
          'REJECT': {'name': 'REJECT', 'type': 'Reject'},
        },
      ),
    );
    source = Profile.normal(
      url: 'http://127.0.0.1:${server.port}/subscription',
    ).copyWith(id: 11);
    final workspace = Profile.custom(label: 'Ports').copyWith(id: 9);
    action = _ProbeAction();
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([source, workspace])),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        setupActionProvider.overrideWith(() => setup),
        portRoutingActionProvider.overrideWith(() => action),
        ...buildConfigOverrides(
          const Config(
            themeProps: defaultThemeProps,
            currentProfileId: 9,
            portRouting: PortRoutingConfig(
              workspaceProfileId: 9,
              previousProfileId: 11,
              bindings: [
                PortBinding(
                  id: 1,
                  name: 'One',
                  profileId: 11,
                  port: 18081,
                  node: 'US One',
                ),
              ],
            ),
          ),
        ),
      ],
    );
    globalState.container = container;
    container.read(portRoutingActionProvider.notifier);
    original = File(await appPath.getProfilePath('11'));
    await original.parent.create(recursive: true);
    await original.writeAsString(_old);
    await action.prepare(container.read(portRoutingSettingProvider));
  });

  tearDown(() async {
    if (responseGate != null && !responseGate!.isCompleted) {
      responseGate!.complete();
    }
    container.dispose();
    await server.close(force: true);
    await home.delete(recursive: true);
  });

  Future<File> goodCache() async => File(
    '${(await action.prepare(container.read(portRoutingSettingProvider))).providers[portProviderName(11)]['path']}.good',
  );

  void startChecks() {
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    container.read(runTimeProvider.notifier).value =
        DateTime.now().millisecondsSinceEpoch;
  }

  test(
    'aggregate source ownership and refresh cover every selected subscription',
    () async {
      final second = source.copyWith(id: 22, label: 'Second');
      container.read(profilesProvider.notifier).put(second);
      final secondFile = File(await appPath.getProfilePath('22'));
      await secondFile.writeAsString(_old);
      final before = container.read(portRoutingSettingProvider);
      container.read(portRoutingSettingProvider.notifier).value = before
          .copyWith(
            bindings: [
              before.bindings.single.copyWith(
                additionalProfileIds: [22],
                selection: PortSelection.region,
                filter: 'US',
              ),
            ],
          );
      final fragment = await action.prepare(
        container.read(portRoutingSettingProvider),
      );
      expect(
        fragment.providers.keys,
        containsAll([portProviderName(11), portProviderName(22)]),
      );
      expect(action.owns(22), isTrue);
      expect(action.references(22), isTrue);
      await action.refresh(22);
      verify(
        () => core.sideLoadExternalProvider(
          providerName: portProviderName(22),
          data: any(named: 'data'),
        ),
      ).called(1);
      verify(
        () => core.changeProxy(
          const ChangeProxyParams(
            groupName: 'flclash_ports_group_1',
            proxyName: '',
          ),
        ),
      ).called(1);
      expect(setup.applies, 0);
    },
  );

  test(
    'original policy refresh reapplies rules without a storage deadlock',
    () async {
      final before = container.read(portRoutingSettingProvider);
      container
          .read(portRoutingSettingProvider.notifier)
          .value = before.copyWith(
        bindings: [
          before.bindings.single.copyWith(selection: PortSelection.original),
        ],
      );
      content =
          '$_new\nproxy-groups: [{name: Original, type: select, proxies: [US Two]}]\nrules: ["MATCH,Original"]';
      setup.onApply = () async {
        final fragment = await action.prepare(
          container.read(portRoutingSettingProvider),
        );
        expect(
          fragment.config['sub-rules']['flclash_ports_rules_11'],
          contains('MATCH,[policy:11] Original'),
        );
        return true;
      };
      await action.refresh(11).timeout(const Duration(seconds: 5));
      expect(setup.applies, 1);
      expect(await original.readAsString(), content);
      verifyNever(
        () => core.sideLoadExternalProvider(
          providerName: any(named: 'providerName'),
          data: any(named: 'data'),
        ),
      );
    },
  );

  test(
    'a failed original policy reload restores the previous source and cache',
    () async {
      final before = container.read(portRoutingSettingProvider);
      container
          .read(portRoutingSettingProvider.notifier)
          .value = before.copyWith(
        bindings: [
          before.bindings.single.copyWith(selection: PortSelection.original),
        ],
      );
      final cache = await goodCache();
      final previous = await cache.readAsString();
      setup.onApply = () async {
        await action.prepare(container.read(portRoutingSettingProvider));
        return setup.applies > 1;
      };
      await expectLater(
        action.refresh(11),
        throwsA(isA<PortRoutingException>()),
      );
      expect(await original.readAsString(), _old);
      expect(await cache.readAsString(), previous);
      expect(setup.applies, 2);
    },
  );

  test(
    'a thrown reload while editing restores the binding configuration',
    () async {
      final before = container.read(portRoutingSettingProvider);
      setup.onApply = () async {
        if (setup.applies == 1) throw StateError('load failed');
        return true;
      };
      await expectLater(
        action.saveBinding(before.bindings.single.copyWith(name: 'Changed')),
        throwsA(isA<StateError>()),
      );
      expect(container.read(portRoutingSettingProvider), before);
      expect(setup.applies, 2);
    },
  );

  test(
    'a late original-policy update cannot overwrite a replaced source',
    () async {
      final before = container.read(portRoutingSettingProvider);
      container
          .read(portRoutingSettingProvider.notifier)
          .value = before.copyWith(
        bindings: [
          before.bindings.single.copyWith(selection: PortSelection.original),
        ],
      );
      final entered = Completer<void>();
      final release = Completer<void>();
      setup.onApply = () async {
        entered.complete();
        await release.future;
        return true;
      };
      final updating = action.refresh(11);
      final checked = expectLater(
        updating,
        throwsA(isA<PortRoutingException>()),
      );
      await entered.future;
      await original.writeAsString('$_old\nrules: ["MATCH,DIRECT"]');
      container
          .read(profilesProvider.notifier)
          .put(source.copyWith(url: '${source.url}?replacement'));
      release.complete();
      await checked;
      expect(await original.readAsString(), '$_old\nrules: ["MATCH,DIRECT"]');
      expect(setup.applies, 1);
    },
  );

  test('ownership query failure replaces an earlier listening state', () async {
    startChecks();
    container
        .read(portRoutingActivityProvider.notifier)
        .check(1, const PortBindingCheck(PortBindingPhase.listening));
    action.owners = () async => throw const ProcessException('lsof', []);
    await action.checkAll();
    final check = container.read(portRoutingActivityProvider).ports[1]!;
    expect(check.phase, PortBindingPhase.failed);
    expect(check.issue, PortRoutingIssue.coreUnavailable);
  });

  test(
    'missing listener differs from a port held by another process',
    () async {
      startChecks();
      action.owners = () async => {18081: 5678};
      await action.checkAll();
      expect(
        container.read(portRoutingActivityProvider).ports[1]!.issue,
        PortRoutingIssue.portOccupied,
      );
      action.owners = () async => {};
      await action.checkAll();
      expect(
        container.read(portRoutingActivityProvider).ports[1]!.issue,
        PortRoutingIssue.coreUnavailable,
      );
    },
  );

  test('stopping while ownership is pending discards the check', () async {
    startChecks();
    final gate = Completer<Map<int, int>>();
    action.owners = () => gate.future;
    final pending = action.checkAll();
    expect(
      container.read(portRoutingActivityProvider).ports[1]!.phase,
      PortBindingPhase.checking,
    );
    container.read(runTimeProvider.notifier).value = null;
    gate.complete({18081: 5678});
    await pending;
    expect(container.read(portRoutingActivityProvider).ports, isEmpty);
  });

  test('an older check cannot overwrite a newer result', () async {
    startChecks();
    final gate = Completer<Map<int, int>>();
    action.owners = () => gate.future;
    final pending = action.checkAll();
    action.owners = () async => {};
    await action.checkAll();
    gate.complete({18081: 5678});
    await pending;
    expect(
      container.read(portRoutingActivityProvider).ports[1]!.issue,
      PortRoutingIssue.coreUnavailable,
    );
  });

  test('visible scheduler checks listeners even with refresh paused', () async {
    startChecks();
    action.setRefresh(
      const PortSubscriptionRefresh(profileId: 11, enabled: false),
    );
    var checks = 0;
    action.owners = () async {
      checks++;
      return {};
    };
    container.read(appVisibleProvider.notifier).value = false;
    await action.tick();
    expect(checks, 0);
    container.read(appVisibleProvider.notifier).value = true;
    await pumpEventQueue();
    expect(checks, 1);
    expect(requests, 0);
    expect(
      container.read(portRoutingActivityProvider).ports[1]!.issue,
      PortRoutingIssue.coreUnavailable,
    );
  });

  test('dedicated mode releases macOS DNS without changing saved TUN', () {
    container
        .read(networkSettingProvider.notifier)
        .update((value) => value.copyWith(autoSetSystemDns: true));
    container
        .read(patchClashConfigProvider.notifier)
        .update(
          (value) => value.copyWith(tun: value.tun.copyWith(enable: true)),
        );
    container.read(authorizedTunEnableProvider.notifier).value =
        TunAuthorizationState.authorized;
    startChecks();
    expect(container.read(shouldPatchSystemDnsProvider), isFalse);
    expect(container.read(patchClashConfigProvider).tun.enable, isTrue);
    expect(container.read(networkSettingProvider).autoSetSystemDns, isTrue);
    container.read(currentProfileIdProvider.notifier).value = 11;
    expect(container.read(shouldPatchSystemDnsProvider), isTrue);
  });

  test('owned SOCKS listener shows its selected node', () async {
    final listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(listener.close);
    final subscription = listener.listen((socket) {
      socket.listen((_) {
        socket.add([5, 0]);
        unawaited(socket.flush().then((_) => socket.destroy()));
      });
    });
    addTearDown(subscription.cancel);
    final config = container.read(portRoutingSettingProvider);
    container.read(portRoutingSettingProvider.notifier).value = config.copyWith(
      bindings: [config.bindings.single.copyWith(port: listener.port)],
    );
    startChecks();
    action.owners = () async => {listener.port: action.processId!};
    when(() => core.getProxies()).thenAnswer(
      (_) async => ProxiesData(
        all: [],
        proxies: {
          config.bindings.single.groupName: {
            'now': '${portNodePrefix(11)}US One',
          },
        },
      ),
    );
    await action.checkAll();
    final check = container.read(portRoutingActivityProvider).ports[1]!;
    expect(check.phase, PortBindingPhase.listening);
    expect(check.node, 'US One');
  });

  test(
    'refresh updates only the source provider and deduplicates requests',
    () async {
      responseGate = Completer();
      final first = action.refresh(11);
      final second = container
          .read(profilesActionProvider.notifier)
          .updateProfile(source);
      responseGate!.complete();
      await Future.wait([first, second]);
      expect(requests, 1);
      expect(await original.readAsString(), _new);
      expect(
        container.read(profilesProvider).getProfile(11)!.lastUpdateDate,
        isNotNull,
      );
      verify(
        () => core.sideLoadExternalProvider(
          providerName: portProviderName(11),
          data: any(named: 'data'),
        ),
      ).called(1);
      verifyNever(() => core.setupConfig(any()));
      verifyNever(() => core.closeConnections());
      expect(container.read(portRoutingActivityProvider).refreshing, isEmpty);
    },
  );

  test(
    'invalid subscription keeps disk and running provider unchanged',
    () async {
      content = 'proxies: []';
      await expectLater(
        action.refresh(11),
        throwsA(isA<PortRoutingException>()),
      );
      expect(await original.readAsString(), _old);
      verifyNever(
        () => core.sideLoadExternalProvider(
          providerName: any(named: 'providerName'),
          data: any(named: 'data'),
        ),
      );
      expect(
        container.read(portRoutingActivityProvider).errors[11],
        PortRoutingIssue.emptySubscription,
      );
    },
  );

  test('failed provider update restores the last working cache', () async {
    var attempts = 0;
    when(
      () => core.sideLoadExternalProvider(
        providerName: any(named: 'providerName'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((_) async {
      if (++attempts == 1) {
        throw const PortRoutingException(PortRoutingIssue.updateFailed);
      }
    });
    final cache = await goodCache();
    final previous = await cache.readAsString();
    await expectLater(action.refresh(11), throwsA(isA<PortRoutingException>()));
    expect(await original.readAsString(), _old);
    expect(await cache.readAsString(), previous);
    expect(attempts, 2);
  });

  test('switching profile during download discards the late result', () async {
    responseGate = Completer();
    final update = action.refresh(11);
    container.read(currentProfileIdProvider.notifier).value = 11;
    responseGate!.complete();
    await expectLater(update, throwsA(isA<PortRoutingException>()));
    expect(await original.readAsString(), _old);
    verifyNever(
      () => core.sideLoadExternalProvider(
        providerName: any(named: 'providerName'),
        data: any(named: 'data'),
      ),
    );
    expect(container.read(currentProfileIdProvider), 11);
  });

  test('editing source URL during download discards the late result', () async {
    responseGate = Completer();
    final update = action.refresh(11);
    container
        .read(profilesProvider.notifier)
        .put(source.copyWith(url: '${source.url}?changed=1'));
    responseGate!.complete();
    await expectLater(update, throwsA(isA<PortRoutingException>()));
    expect(await original.readAsString(), _old);
  });

  test(
    'managed source deletion is blocked while bindings refer to it',
    () async {
      await expectLater(
        container.read(profilesActionProvider.notifier).deleteProfile(11),
        throwsA(isA<MessageException>()),
      );
      expect(container.read(profilesProvider).getProfile(11), isNotNull);
    },
  );

  test('system settings remain saved while effective system proxy is off', () {
    container
        .read(networkSettingProvider.notifier)
        .update((value) => value.copyWith(systemProxy: true));
    container.read(runTimeProvider.notifier).value =
        DateTime.now().millisecondsSinceEpoch;
    expect(container.read(proxyStateProvider).systemProxy, isFalse);
    expect(container.read(networkSettingProvider).systemProxy, isTrue);
    expect(
      FlClashHttpOverrides.findProxyFor(
        container,
        Uri.parse('https://example.test'),
      ),
      'DIRECT',
    );
    container.read(currentProfileIdProvider.notifier).value = 11;
    expect(container.read(proxyStateProvider).systemProxy, isTrue);
  });

  test('activation and deactivation preserve the previous profile', () async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    final config = container.read(portRoutingSettingProvider);
    container.read(portRoutingSettingProvider.notifier).value = config.copyWith(
      bindings: [config.bindings.single.copyWith(port: port)],
    );
    container.read(currentProfileIdProvider.notifier).value = 11;
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    await action.activate();
    expect(container.read(currentProfileIdProvider), 9);
    expect(container.read(portRoutingSettingProvider).previousProfileId, 11);
    expect(setup.running, isTrue);
    await action.deactivate();
    expect(container.read(currentProfileIdProvider), 11);
    expect(setup.applies, 2);
  });

  test(
    'automatic group cache resets without closing other connections',
    () async {
      final config = container.read(portRoutingSettingProvider);
      container.read(portRoutingSettingProvider.notifier).value = config
          .copyWith(
            bindings: [
              config.bindings.single.copyWith(
                selection: PortSelection.region,
                filter: 'US',
              ),
            ],
          );
      await action.refresh(11);
      verify(
        () => core.changeProxy(
          const ChangeProxyParams(
            groupName: 'flclash_ports_group_1',
            proxyName: '',
          ),
        ),
      ).called(1);
      verifyNever(() => core.closeConnections());
    },
  );

  test('scheduler obeys per-source pause and update interval', () async {
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    action.setRefresh(
      const PortSubscriptionRefresh(profileId: 11, enabled: false),
    );
    await action.tick();
    expect(requests, 0);
    action.setRefresh(const PortSubscriptionRefresh(profileId: 11));
    await action.tick();
    expect(requests, 1);
    await action.tick();
    expect(requests, 1);
  });
}
