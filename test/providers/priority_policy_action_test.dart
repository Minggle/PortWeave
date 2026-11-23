import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/priority_policy.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:yaml/yaml.dart';

import '../helpers/app_paths.dart';
import '../helpers/test_profiles.dart';

class _Core extends Mock implements CoreHandlerInterface {}

class _Setup extends SetupAction {
  int applies = 0;
  int scheduled = 0;
  bool fail = false;
  @override
  void build() {}
  @override
  Future<bool> applyProfile({
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) async {
    applies++;
    return !fail || applies > 1;
  }

  @override
  void applyProfileDebounce({bool silence = false, bool force = false}) {
    scheduled++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory home;
  late ProviderContainer container;
  late _Core core;
  late _Setup setup;
  late PriorityPolicyAction action;
  const policy = PriorityPolicy(
    profileId: 10,
    group: 'Video',
    tiers: [
      PriorityTier(target: 'Taiwan'),
      PriorityTier(sourceIds: [11], filter: 'US'),
    ],
  );
  final base = <String, dynamic>{
    'proxies': [
      {'name': 'Taiwan', 'type': 'socks5'},
    ],
    'proxy-groups': [
      {
        'name': 'Video',
        'type': 'select',
        'proxies': ['Taiwan'],
      },
    ],
    'rules': ['MATCH,Video'],
  };

  setUp(() async {
    loadAppLocalizations(const Locale('en'));
    home = await Directory.systemTemp.createTemp('priority-policy-');
    await useAppPaths(home);
    core = _Core();
    setup = _Setup();
    when(() => core.readConfig(any())).thenAnswer(
      (_) async =>
          {...base, 'rule': List<String>.from(base['rules'] as List)}
            ..remove('rules'),
    );
    when(() => core.validateProxies(any())).thenAnswer((_) async => {});
    container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        setupActionProvider.overrideWith(() => setup),
        profilesProvider.overrideWith(
          () => TestProfiles([
            Profile.normal(label: 'Base').copyWith(id: 10),
            Profile.normal(label: 'Subscription').copyWith(id: 11),
          ]),
        ),
        ...buildConfigOverrides(
          const Config(themeProps: defaultThemeProps, currentProfileId: 10),
        ),
      ],
    );
    globalState.container = container;
    globalState.packageInfo = PackageInfo(
      appName: 'Test',
      packageName: 'test',
      version: '1.0.0',
      buildNumber: '1',
    );
    action = container.read(priorityPolicyActionProvider.notifier);
    final file = File(await appPath.getProfilePath('11'));
    await file.parent.create(recursive: true);
    await file.writeAsString(
      'proxies: [{name: US Old, type: socks5, server: 127.0.0.1, port: 9999}]',
    );
  });
  tearDown(() async {
    container.dispose();
    await home.delete(recursive: true);
  });

  test('save applies only the selected base and persists settings', () async {
    await action.save(10, [policy]);
    expect(container.read(priorityPolicySettingProvider).policies, [policy]);
    expect(container.read(configProvider).priorityPolicies.policies, [policy]);
    expect(setup.applies, 1);
    container.read(currentProfileIdProvider.notifier).value = 11;
    await action.save(10, []);
    expect(setup.applies, 1);
  });

  test(
    'ordinary profile build includes prioritized groups without replacing its rules',
    () async {
      final result = await container
          .read(setupActionProvider.notifier)
          .getProfile(
            setupState: const SetupState(
              profileId: 10,
              profileLastUpdateDate: null,
              profileType: ProfileType.file,
              rules: [],
              proxyGroups: [],
              addedRules: [],
              script: null,
              overrides: ProfileOverrides(),
              priorityPolicies: [policy],
            ),
            patchConfig: const PatchClashConfig(),
          );
      final document = loadYaml(result.yaml) as Map;
      expect(document['rules'], ['MATCH,Video']);
      expect(document['mixed-port'], 7891);
      final group = (document['proxy-groups'] as List).firstWhere(
        (g) => g['name'] == 'Video',
      );
      expect(group['type'], 'fallback');
      expect(group['proxies'].first, 'Taiwan');
      expect(
        (document['proxy-providers'] as Map).containsKey(
          priorityProviderName(11),
        ),
        isTrue,
      );
      expect(result.base, isNull);
      verifyNever(() => core.getProfileBase(any()));
    },
  );

  test('failed apply restores the previous priorities', () async {
    setup.fail = true;
    await expectLater(
      action.save(10, [policy]),
      throwsA(isA<PriorityPolicyException>()),
    );
    expect(container.read(priorityPolicySettingProvider).policies, isEmpty);
    expect(setup.applies, 2);
  });

  test(
    'subscription updates refresh only current dependent profiles',
    () async {
      await action.save(10, [policy]);
      action.sourceUpdated(11);
      expect(setup.scheduled, 1);
      action.sourceUpdated(99);
      expect(setup.scheduled, 1);
      container.read(currentProfileIdProvider.notifier).value = 11;
      action.sourceUpdated(11);
      expect(setup.scheduled, 1);
    },
  );

  test(
    'provider cache follows source changes and cannot be selected by stale name',
    () async {
      final first = await action.prepare(base, [
        policy,
      ], 'https://test.example');
      final path = first.providers[priorityProviderName(11)]['path'] as String;
      expect(await File(path).readAsString(), contains('US Old'));
      await File(
        await appPath.getProfilePath('11'),
      ).writeAsString('proxies: [{name: US New, type: socks5}]');
      await action.prepare(base, [policy], 'https://test.example');
      expect(await File(path).readAsString(), contains('US New'));
      expect(await File(path).readAsString(), isNot(contains('US Old')));
    },
  );

  test(
    'a referenced source cannot be deleted or replaced with invalid nodes',
    () async {
      await action.save(10, [policy]);
      await expectLater(
        container.read(profilesActionProvider.notifier).deleteProfile(11),
        throwsA(isA<MessageException>()),
      );
      when(
        () => core.validateProxies(any()),
      ).thenAnswer((_) async => {0: 'invalid'});
      await expectLater(
        action.validateSource(11, await appPath.getProfilePath('11')),
        throwsA(isA<PriorityPolicyException>()),
      );
    },
  );

  test(
    'source changed during validation cannot commit stale priorities',
    () async {
      final gate = Completer<Map<int, String>>();
      final entered = Completer<void>();
      when(() => core.validateProxies(any())).thenAnswer((_) {
        entered.complete();
        return gate.future;
      });
      final saving = action.save(10, [policy]);
      final checked = expectLater(
        saving,
        throwsA(isA<PriorityPolicyException>()),
      );
      await entered.future;
      container
          .read(profilesProvider.notifier)
          .updateProfile(
            11,
            (p) => p.copyWith(url: 'https://replacement.test'),
          );
      gate.complete({});
      await checked;
      expect(container.read(priorityPolicySettingProvider).policies, isEmpty);
    },
  );
}
