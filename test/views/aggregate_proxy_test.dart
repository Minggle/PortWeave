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
    _Ports action,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
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
        ...buildConfigOverrides(
          Config(
            themeProps: defaultThemeProps,
            portRouting: PortRoutingConfig(
              bindings: [
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
    container.read(viewSizeProvider.notifier).value = const Size(1400, 1000);
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
}
