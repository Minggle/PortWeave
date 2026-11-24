import 'package:fl_clash/common/port_routing.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/port_routing.dart';
import 'package:fl_clash/views/priority_policy.dart';
import 'package:fl_clash/views/tools.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../helpers/test_app.dart';
import '../helpers/test_database_providers.dart';
import '../helpers/test_profiles.dart';

class _Unavailable extends PortRoutingAction {
  int attempts = 0;

  @override
  void build() {}

  @override
  Future<void> activate() async {
    attempts++;
    throw const PortRoutingException(PortRoutingIssue.coreUnavailable);
  }
}

class _EditorAction extends PortRoutingAction {
  bool fail = false;
  int saves = 0;
  @override
  void build() {}
  @override
  Future<List<String>> nodeNames(int profileId) async => ['US One', 'JP One'];
  @override
  Future<void> saveBinding(PortBinding binding) async {
    saves++;
    if (fail) throw const PortRoutingException(PortRoutingIssue.portOccupied);
    final config = ref.read(portRoutingSettingProvider);
    ref.read(portRoutingSettingProvider.notifier).value = config.copyWith(
      bindings: [
        for (final existing in config.bindings)
          existing.id == binding.id ? binding : existing,
        if (!config.bindings.any((existing) => existing.id == binding.id))
          binding,
      ],
    );
  }
}

void main() {
  Future<ProviderContainer> openNew(
    WidgetTester tester,
    _EditorAction action,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(
          () => TestProfiles([
            Profile.normal(label: 'Subscription A').copyWith(id: 11),
            Profile.normal(label: 'Subscription B').copyWith(id: 22),
          ]),
        ),
        portRoutingActionProvider.overrideWith(() => action),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(1200, 1000);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(locale: Locale('en'), child: PortRoutingView()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'original policy saves without choosing a node and failed saves keep input',
    (tester) async {
      final action = _EditorAction()..fail = true;
      final container = await openNew(tester, action);
      expect(find.text('Use original policy'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).first,
        'Original browser',
      );
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(container.read(portRoutingSettingProvider).bindings, isEmpty);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'Original browser',
      );
      expect(find.text('Please enter a different port'), findsOneWidget);
      action.fail = false;
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(
        container.read(portRoutingSettingProvider).bindings.single.selection,
        PortSelection.original,
      );
      expect(action.saves, 2);
      expect(find.byType(TextFormField), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a keyword binding selects multiple subscription sources', (
    tester,
  ) async {
    final action = _EditorAction();
    final container = await openNew(tester, action);
    await tester.enterText(find.byType(TextFormField).first, 'Combined US');
    await tester.tap(find.text('Use original policy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Automatic by region').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subscription A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subscription B'));
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(2), 'US');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    final binding = container.read(portRoutingSettingProvider).bindings.single;
    expect(binding.sourceIds, {11, 22});
    expect(binding.filter, 'US');
    expect(binding.selection, PortSelection.region);
    expect(tester.takeException(), isNull);
  });

  for (final platform in ['macOS', 'Windows', 'Linux']) {
    testWidgets('tools exposes subscription ports on $platform as supported', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(TestProfiles.new),
          scriptsProvider.overrideWith(TestScripts.new),
          globalRulesProvider.overrideWith(TestGlobalRules.new),
          iconSetsProvider.overrideWith(TestIconSets.new),
          clashProvidersProvider.overrideWith(TestClashProviders.new),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container.read(viewSizeProvider.notifier).value = const Size(1400, 1000);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TestApp(
            locale: const Locale('en'),
            child: ToolsView(
              isWindows: platform == 'Windows',
              isMacOS: platform == 'macOS',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final entry = find.text('Subscription ports');
      final priorities = find.text('Policy priorities');
      if (platform == 'Linux') {
        expect(entry, findsNothing);
        expect(priorities, findsOneWidget);
        await tester.tap(priorities);
        await tester.pumpAndSettle();
        expect(find.byType(PriorityPolicyView), findsOneWidget);
      } else {
        expect(priorities, findsNothing);
        expect(entry, findsOneWidget);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(find.byType(PortRoutingView), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('editing validates port conflicts and saves the same binding', (
    tester,
  ) async {
    const first = PortBinding(
      id: 1,
      name: 'Browser',
      profileId: 11,
      port: 18081,
      node: 'US One',
    );
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(
          () => TestProfiles([
            Profile.normal(label: 'Subscription A').copyWith(id: 11),
          ]),
        ),
        portRoutingActionProvider.overrideWith(_EditorAction.new),
        portRoutingSettingProvider.overrideWithBuild(
          (_, _) => PortRoutingConfig(
            bindings: [
              first,
              first.copyWith(id: 2, name: 'Editor', port: 18082),
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(1200, 1000);
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(locale: Locale('en'), child: PortRoutingView()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Browser · 127.0.0.1:18081'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Browser US');
    await tester.enterText(find.byType(TextFormField).at(1), '18082');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    expect(container.read(portRoutingSettingProvider).bindings.first, first);
    await tester.enterText(find.byType(TextFormField).at(1), '18083');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    final updated = container.read(portRoutingSettingProvider).bindings.first;
    expect(updated.id, first.id);
    expect(updated.name, 'Browser US');
    expect(updated.port, 18083);
    globalState.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      '18084',
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('empty view offers import guidance and safe-mode status', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(TestProfiles.new),
        safeModeProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(1200, 1000);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(locale: Locale('en'), child: PortRoutingView()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Subscription ports'), findsOneWidget);
    expect(
      find.text('Import a subscription, then add a port binding.'),
      findsOneWidget,
    );
    expect(find.textContaining('Safe mode:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed activation surfaces an error and releases the control', (
    tester,
  ) async {
    final action = _Unavailable();
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(TestProfiles.new),
        portRoutingActionProvider.overrideWith(() => action),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(1200, 1000);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(locale: Locale('en'), child: PortRoutingView()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(
      find.text('The core or proxy listener is unavailable.'),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      container.read(portRoutingSettingProvider),
      const PortRoutingConfig(),
    );
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(action.attempts, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'new aggregate binding defaults to empty policies even with legacy policies',
    (tester) async {
      final action = _EditorAction();
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(
            () => TestProfiles([
              Profile.normal(label: 'Subscription A').copyWith(id: 11),
            ]),
          ),
          portRoutingActionProvider.overrideWith(() => action),
          priorityPolicySettingProvider.overrideWithBuild(
            (_, _) => const PriorityPolicies(
              policies: [
                PriorityPolicy(
                  profileId: 11,
                  group: 'StaleGroup',
                  tiers: [PriorityTier(target: 'MissingNode')],
                ),
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container.read(viewSizeProvider.notifier).value = const Size(1200, 1000);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(
            locale: Locale('en'),
            child: PortRoutingView(aggregateOnly: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Fresh Agg');
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      final binding = container
          .read(portRoutingSettingProvider)
          .bindings
          .single;
      expect(binding.selection, PortSelection.aggregate);
      expect(binding.policies, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'default outbound selector, primary badge, and drag-to-reorder work in overview',
    (tester) async {
      final reordered = <List<int>>[];
      int? defaultSet;
      bool? takeoverSet;
      final action = _ManageAction(
        onDefault: (id) => defaultSet = id,
        onTakeover: (value) => takeoverSet = value,
        onReorder: reordered.add,
      );
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(
            () => TestProfiles([
              Profile.normal(label: 'Sub A').copyWith(id: 11),
              Profile.normal(label: 'Sub B').copyWith(id: 22),
            ]),
          ),
          portRoutingActionProvider.overrideWith(() => action),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container.read(viewSizeProvider.notifier).value = const Size(1200, 1000);
      container
          .read(portRoutingSettingProvider.notifier)
          .value = const PortRoutingConfig(
        takeoverSystem: true,
        defaultBindingId: 1,
        bindings: [
          PortBinding(
            id: 1,
            name: 'Port One',
            profileId: 11,
            port: 18081,
            selection: PortSelection.original,
          ),
          PortBinding(
            id: 2,
            name: 'Port Two',
            profileId: 22,
            port: 18082,
            selection: PortSelection.fixed,
            node: 'JP 01',
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(locale: Locale('en'), child: PortRoutingView()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Default outbound'), findsOneWidget);
      expect(find.text('Primary'), findsOneWidget);
      expect(find.byType(SliverPrismReorderableList), findsOneWidget);
      expect(find.byType(ReorderDragStartListener), findsNWidgets(2));

      await tester.tap(find.text('Default outbound'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Port Two · :18082').last);
      await tester.pumpAndSettle();
      expect(defaultSet, 2);

      await tester.tap(find.text('Default outbound'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Isolated mode (no system takeover)').last);
      await tester.pumpAndSettle();
      expect(takeoverSet, isFalse);

      final reorderable = tester.widget<SliverPrismReorderableList>(
        find.byType(SliverPrismReorderableList),
      );
      reorderable.onReorderItem!(0, 2);
      await tester.pumpAndSettle();
      expect(reordered, [
        [2, 1],
      ]);
      expect(tester.takeException(), isNull);
    },
  );
}

class _ManageAction extends PortRoutingAction {
  _ManageAction({this.onDefault, this.onTakeover, this.onReorder});

  final void Function(int? id)? onDefault;
  final void Function(bool value)? onTakeover;
  final void Function(List<int> ids)? onReorder;

  @override
  void build() {}

  @override
  Future<void> setDefaultBinding(int? bindingId) async {
    onDefault?.call(bindingId);
    final config = ref.read(portRoutingSettingProvider);
    ref.read(portRoutingSettingProvider.notifier).value = config.copyWith(
      defaultBindingId: bindingId,
    );
  }

  @override
  Future<void> setTakeoverSystem(bool takeover) async {
    onTakeover?.call(takeover);
    final config = ref.read(portRoutingSettingProvider);
    ref.read(portRoutingSettingProvider.notifier).value = config.copyWith(
      takeoverSystem: takeover,
    );
  }

  @override
  Future<void> reorderBindings(List<int> orderedIds) async {
    onReorder?.call(orderedIds);
  }
}
