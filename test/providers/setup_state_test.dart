import 'dart:async';

import 'package:drift/drift.dart' show LazyDatabase;
import 'package:drift/native.dart';
import 'package:fl_clash/database/database.dart' as db;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_profiles.dart';

void main() {
  late db.Database testDatabase;

  setUp(() {
    testDatabase = db.Database(NativeDatabase.memory());
    db.database = testDatabase;
  });

  tearDown(() async {
    await testDatabase.close();
  });

  testWidgets(
    'a standard setup can finish after its unobserved ref is disposed',
    (tester) async {
      await testDatabase.close();
      final started = Completer<void>();
      final release = Completer<void>();
      testDatabase = db.Database(
        LazyDatabase(() async {
          started.complete();
          await release.future;
          return NativeDatabase.memory();
        }),
      );
      db.database = testDatabase;
      const profile = Profile(id: 1, autoUpdateDuration: Duration.zero);
      const policy = PriorityPolicy(
        profileId: 1,
        group: 'Video',
        tiers: [PriorityTier(target: 'Primary')],
      );
      final disposed = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([profile])),
          priorityPolicySettingProvider.overrideWithBuild(
            (_, _) => const PriorityPolicies(policies: [policy]),
          ),
          setupStateProvider.overrideWith((ref, id) {
            ref.onDispose(() {
              if (!disposed.isCompleted) disposed.complete();
            });
            return setupState(ref, id);
          }),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SizedBox.shrink(),
        ),
      );
      final pending = container.read(setupStateProvider(profile.id).future);
      await started.future;
      await tester.pump();
      expect(disposed.isCompleted, isTrue);
      release.complete();
      final state = await pending;
      expect(state.priorityPolicies, [policy]);
      expect(state.profileType, ProfileType.file);
    },
  );

  test(
    'priority edits during a pending query invalidate the old setup build',
    () async {
      await testDatabase.close();
      final started = Completer<void>();
      final release = Completer<void>();
      testDatabase = db.Database(
        LazyDatabase(() async {
          started.complete();
          await release.future;
          return NativeDatabase.memory();
        }),
      );
      db.database = testDatabase;
      const profile = Profile(id: 1, autoUpdateDuration: Duration.zero);
      const policy = PriorityPolicy(
        profileId: 1,
        group: 'Video',
        tiers: [PriorityTier(target: 'Primary')],
      );
      var builds = 0;
      var disposals = 0;
      final container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([profile])),
          setupStateProvider.overrideWith((ref, id) {
            builds++;
            ref.onDispose(() => disposals++);
            return setupState(ref, id);
          }),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      final observed = <SetupState>[];
      container.listen(setupStateProvider(profile.id), (_, next) {
        if (next case AsyncData(:final value)) observed.add(value);
      });
      final pending = container.read(setupStateProvider(profile.id).future);
      await started.future;
      container.read(priorityPolicySettingProvider.notifier).value =
          const PriorityPolicies(policies: [policy]);
      container.read(setupStateProvider(profile.id));
      expect(builds, 2);
      expect(disposals, 1);
      release.complete();
      final state = await pending;
      expect(state.priorityPolicies, [policy]);
      expect(observed, isNotEmpty);
      expect(
        observed,
        everyElement(
          isA<SetupState>().having(
            (state) => state.priorityPolicies,
            'latest priorities',
            [policy],
          ),
        ),
      );
      container.read(priorityPolicySettingProvider.notifier).value =
          const PriorityPolicies();
      final restored = await container.read(
        setupStateProvider(profile.id).future,
      );
      expect(restored.priorityPolicies, isEmpty);
    },
  );

  testWidgets('a custom setup disposed before its queries return resolves', (
    tester,
  ) async {
    const profile = Profile(
      id: 1,
      label: 'Home',
      type: ProfileType.custom,
      autoUpdateDuration: Duration.zero,
    );
    const subscription = Profile(
      id: 2,
      label: 'Sub',
      type: ProfileType.url,
      url: 'https://example.com/sub',
      autoUpdateDuration: Duration.zero,
    );
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(
          () => TestProfiles([profile, subscription]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SizedBox.shrink(),
      ),
    );

    final state = await container.read(setupStateProvider(profile.id).future);

    expect(state.profileType, ProfileType.custom);
    expect(state.profileProviders, {'Sub': subscription.id});
  });

  testWidgets('a custom setup leaves the extension out but keeps its exits', (
    tester,
  ) async {
    const profile = Profile(
      id: 1,
      type: ProfileType.custom,
      autoUpdateDuration: Duration.zero,
      scriptId: 5,
      exitTargets: {'PROXY': 'Proxy'},
    );
    await testDatabase.profilesDao.putAll([profile.toCompanion()]);
    await testDatabase.scripts.put(
      Script(
        id: 5,
        label: 'Script',
        lastUpdateTime: DateTime(2026),
      ).toCompanion(),
    );
    await testDatabase.rulesDao.putRule(
      Rule.parse('DOMAIN,global.com,DIRECT', id: 10),
    );
    await testDatabase.rulesDao.putRule(
      Rule.parse('DOMAIN,own.com,DIRECT', id: 11),
      profileId: profile.id,
    );
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([profile])),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SizedBox.shrink(),
      ),
    );

    final state = await container.read(setupStateProvider(profile.id).future);

    expect(state.script, isNull);
    expect(state.exitTargets, {'PROXY': 'Proxy'});
    expect(state.addedRules, isEmpty);
    expect(state.rules.map((rule) => rule.id), [11]);
  });

  testWidgets('a custom setup carries the dialers of its own profile', (
    tester,
  ) async {
    const profile = Profile(
      id: 1,
      label: 'Home',
      type: ProfileType.custom,
      autoUpdateDuration: Duration.zero,
    );
    const other = Profile(
      id: 2,
      type: ProfileType.custom,
      autoUpdateDuration: Duration.zero,
    );
    await testDatabase.profilesDao.putAll([
      profile.toCompanion(),
      other.toCompanion(),
    ]);
    await testDatabase.customProxies.put(
      const CustomProxy(id: 30, definition: {'name': 'Home'}).toCompanion(),
    );
    await testDatabase.proxyDialersDao.set(profile.id, 30, 'Relay');
    await testDatabase.proxyDialersDao.set(other.id, 30, 'Other');
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([profile, other])),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SizedBox.shrink(),
      ),
    );

    final state = await container.read(setupStateProvider(profile.id).future);

    expect(state.proxyDialers, {30: 'Relay'});
  });
}
