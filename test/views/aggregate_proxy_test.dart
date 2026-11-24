import 'package:fl_clash/common/port_routing.dart';
import 'package:fl_clash/manager/app_manager.dart';
import 'package:fl_clash/pages/home.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/proxies/proxies.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/common/app_ports.dart';
import 'package:fl_clash/views/navigation.dart';
import 'package:fl_clash/views/port_routing.dart';
import 'package:fl_clash/views/priority_policy.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

const _binding = PortBinding(
  id: 7,
  name: 'Combined',
  profileId: 11,
  port: 18084,
  selection: PortSelection.aggregate,
  policies: [
    PriorityPolicy(
      profileId: 11,
      group: 'Video',
      tiers: [PriorityTier(target: 'Self')],
    ),
  ],
);

class _Ports extends PortRoutingAction {
  bool fail = false;
  int saves = 0;

  @override
  void build() {}

  @override
  Future<Map<String, dynamic>> readBindingBase(int id) async => {
    'proxies': [
      {'name': 'Self', 'type': 'socks5'},
    ],
    'proxy-groups': [
      {
        'name': 'Video',
        'type': 'select',
        'proxies': ['Self'],
      },
    ],
  };

  @override
  Future<void> saveBinding(PortBinding binding) async {
    saves++;
    if (fail) throw const PortRoutingException(PortRoutingIssue.updateFailed);
    ref.read(portRoutingSettingProvider.notifier).value = ref
        .read(portRoutingSettingProvider)
        .copyWith(
          bindings: [
            for (final previous
                in ref.read(portRoutingSettingProvider).bindings)
              previous.id == binding.id ? binding : previous,
          ],
        );
  }
}

void main() {
  setUp(() {
    navigationPort = navigation;
    addTearDown(() => navigationPort = null);
  });
  Future<ProviderContainer> open(
    WidgetTester tester,
    Widget view,
    _Ports action, {
    bool sidebarPorts = true,
    List<PriorityPolicy> legacyPolicies = const [],
    List<PortBinding>? bindings,
    int? currentProfileId,
    List<Group> groups = const [],
    Size size = const Size(1400, 1000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        sidebarPortRoutingSupportedProvider.overrideWithValue(sidebarPorts),
        navigationItemsStateProvider.overrideWithValue(
          NavigationItemsState(
            value: [
              NavigationItem(
                glyph: AppGlyphs.dashboard,
                label: PageLabel.dashboard,
                builder: (_) => const SizedBox(),
              ),
              NavigationItem(
                glyph: AppGlyphs.proxies,
                label: PageLabel.proxies,
                builder: (_) => const ProxiesView(),
              ),
            ],
          ),
        ),
        profilesProvider.overrideWith(
          () => TestProfiles([Profile.normal(label: 'Base').copyWith(id: 11)]),
        ),
        portRoutingActionProvider.overrideWith(() => action),
        if (groups.isNotEmpty)
          groupsProvider.overrideWithBuild((_, _) => groups),
        ...buildConfigOverrides(
          Config(
            themeProps: defaultThemeProps,
            currentProfileId: currentProfileId,
            priorityPolicies: PriorityPolicies(policies: legacyPolicies),
            portRouting: PortRoutingConfig(
              workspaceProfileId: currentProfileId == 9 ? 9 : null,
              bindings:
                  bindings ??
                  [
                    _binding,
                    _binding.copyWith(
                      id: 8,
                      name: 'Provider A',
                      port: 18082,
                      selection: PortSelection.original,
                      policies: [],
                    ),
                  ],
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.listen(configProvider, (_, _) {});
    container.read(viewSizeProvider.notifier).value = size;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(locale: const Locale('en'), child: view),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('a port page exposes only its own configuration', (tester) async {
    final container = await open(
      tester,
      const PortRoutingView(bindingId: 7),
      _Ports(),
    );
    expect(find.text('Combined · 18084'), findsOneWidget);
    expect(find.textContaining('Provider A'), findsNothing);
    expect(find.text('Strategy groups and priorities'), findsOneWidget);
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    final bindings = container.read(portRoutingSettingProvider).bindings;
    expect(bindings.first.enabled, isFalse);
    expect(bindings.last.enabled, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'aggregate policies save on the port and keep failed edits open',
    (tester) async {
      final action = _Ports()..fail = true;
      final container = await open(
        tester,
        const PriorityPolicyView(bindingId: 7),
        action,
      );
      await tester.tap(find.text('Video'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(find.text('1. Self'), findsWidgets);
      expect(find.text('Save'), findsOneWidget);
      expect(find.textContaining('Could not save'), findsOneWidget);
      action.fail = false;
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(
        container.read(portRoutingSettingProvider).bindings.first.policies,
        _binding.policies,
      );
      expect(
        container.read(portRoutingSettingProvider).bindings.last.policies,
        isEmpty,
      );
      expect(container.read(priorityPolicySettingProvider).policies, isEmpty);
      expect(action.saves, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'desktop sidebar places ports below proxies and selects independently',
    (tester) async {
      final container = await open(
        tester,
        const AppSidebarContainer(child: SizedBox.expand()),
        _Ports(),
      );
      container
          .read(appSettingProvider.notifier)
          .update((s) => s.copyWith(sidebarExpanded: true));
      await tester.pumpAndSettle();
      final sidebar = tester.widget<NavigationSidebar>(
        find.byType(NavigationSidebar),
      );
      final labels = sidebar.destinations.map((item) => item.label).toList();
      final proxies = labels.indexOf('Proxies');
      expect(proxies, greaterThanOrEqualTo(0));
      expect(labels[proxies + 1].trim(), 'Combined · 18084');
      expect(labels[proxies + 2].trim(), 'Provider A · 18082');
      sidebar.onSelected(proxies + 1);
      await tester.pumpAndSettle();
      expect(container.read(currentPageLabelProvider), PageLabel.proxies);
      expect(container.read(selectedPortBindingProvider), 7);
      container.read(portRoutingSettingProvider.notifier).value =
          const PortRoutingConfig();
      await tester.pumpAndSettle();
      expect(container.read(selectedPortBindingProvider), isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('switching port pages closes the previous port group editor', (
    tester,
  ) async {
    final container = await open(tester, const HomePage(), _Ports());
    container.read(currentPageLabelProvider.notifier).toPage(PageLabel.proxies);
    container.read(selectedPortBindingProvider.notifier).select(7);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Strategy groups and priorities'));
    await tester.pumpAndSettle();
    expect(find.byType(PriorityPolicyView), findsOneWidget);
    final sidebar = tester.widget<NavigationSidebar>(
      find.byType(NavigationSidebar),
    );
    final index = sidebar.destinations.indexWhere(
      (item) => item.label.contains('Provider A'),
    );
    sidebar.onSelected(index);
    await tester.pumpAndSettle();
    expect(find.byType(PriorityPolicyView), findsNothing);
    expect(find.text('Provider A · 18082'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'copy priorities is hidden when base has none and confirms before overwrite',
    (tester) async {
      await open(tester, const PortRoutingView(bindingId: 7), _Ports());
      expect(find.text('Copy priorities from base profile'), findsNothing);

      const legacy = [
        PriorityPolicy(
          profileId: 11,
          group: 'LegacyGroup',
          tiers: [PriorityTier(target: 'Self')],
        ),
      ];
      final action = _Ports();
      final container = await open(
        tester,
        const PortRoutingView(bindingId: 7),
        action,
        legacyPolicies: legacy,
      );
      expect(find.text('Copy priorities from base profile'), findsOneWidget);
      await tester.tap(find.text('Copy priorities from base profile'));
      await tester.pumpAndSettle();
      expect(find.text('Replace'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(action.saves, 0);
      expect(
        container.read(portRoutingSettingProvider).bindings.first.policies,
        _binding.policies,
      );

      await tester.tap(find.text('Copy priorities from base profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      expect(action.saves, 1);
      expect(
        container.read(portRoutingSettingProvider).bindings.first.policies,
        legacy,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'port group choices strip priority prefixes and render in a sliver section',
    (tester) async {
      await open(
        tester,
        const PortRoutingView(bindingId: 7),
        _Ports(),
        currentProfileId: 9,
        groups: [
          Group(
            type: GroupType.Fallback,
            name: '${_binding.policyPrefix}Video',
            now: '${_binding.policyPrefix}[priority:11] JP Node',
            all: const [],
          ),
        ],
      );
      expect(find.text('Video'), findsOneWidget);
      expect(find.text('Base · JP Node'), findsOneWidget);
      expect(find.textContaining('[priority:'), findsNothing);
      expect(find.textContaining('[port:'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sidebar hides port items on unsupported platforms and guards out-of-range index',
    (tester) async {
      await open(
        tester,
        const AppSidebarContainer(child: SizedBox.expand()),
        _Ports(),
        sidebarPorts: false,
      );
      final sidebar = tester.widget<NavigationSidebar>(
        find.byType(NavigationSidebar),
      );
      final labels = sidebar.destinations.map((item) => item.label).toList();
      expect(labels, ['Dashboard', 'Proxies']);
      expect(tester.takeException(), isNull);

      final container = ProviderContainer(
        overrides: [
          sidebarPortRoutingSupportedProvider.overrideWithValue(true),
          navigationStateProvider.overrideWithValue(
            NavigationState(
              locale: 'en',
              pageLabel: PageLabel.dashboard,
              viewMode: ViewMode.laptop,
              currentIndex: 99,
              navigationItems: [
                NavigationItem(
                  glyph: AppGlyphs.dashboard,
                  label: PageLabel.dashboard,
                  builder: (_) => const SizedBox(),
                ),
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container.read(viewSizeProvider.notifier).value = const Size(1400, 1000);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(
            locale: Locale('en'),
            child: AppSidebarContainer(child: SizedBox.expand()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mobile view ignores selected port binding when dedicated mode is off',
    (tester) async {
      final container = await open(
        tester,
        const ProxiesView(),
        _Ports(),
        size: const Size(500, 900),
      );
      container.read(selectedPortBindingProvider.notifier).select(7);
      await tester.pumpAndSettle();
      expect(find.byType(PortRoutingView), findsNothing);
      expect(find.text('Proxies'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
