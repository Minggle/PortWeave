import 'package:fl_clash/common/priority_policy.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/priority_policy.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';
import '../helpers/context_menu.dart';

class _Action extends PriorityPolicyAction {
  bool fail = false;
  int saves = 0;
  @override
  void build() {}
  @override
  Future<Map<String, dynamic>> readBase(int id) async => {
    'proxies': [
      {'name': 'Self Taiwan', 'type': 'socks5'},
    ],
    'proxy-groups': [
      {
        'name': 'Video',
        'type': 'select',
        'proxies': ['Taiwan'],
      },
      {
        'name': 'Taiwan',
        'type': 'fallback',
        'proxies': ['Self Taiwan'],
      },
    ],
    'rules': ['MATCH,Video'],
  };
  @override
  Future<List<String>> nodeNames(int id) async => [
    'US Fast',
    'US expired',
    'Japan',
  ];

  @override
  Future<({int count, List<(int, String)> sample})> preview(
    PriorityTier tier,
  ) async => priorityPreview((
    tier,
    {
      for (final id in tier.sourceIds) id: ['US Fast', 'US expired', 'Japan'],
    },
  ));
  @override
  Future<void> save(int id, List<PriorityPolicy> policies) async {
    saves++;
    if (fail) throw const PriorityPolicyException(PriorityPolicyIssue.invalid);
    ref.read(priorityPolicySettingProvider.notifier).value = PriorityPolicies(
      policies: policies,
    );
  }
}

void main() {
  Future<ProviderContainer> open(WidgetTester tester, _Action action) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(
          () => TestProfiles([
            Profile.normal(label: 'Base').copyWith(id: 10),
            Profile.normal(label: 'First subscription').copyWith(id: 11),
            Profile.normal(label: 'Second subscription').copyWith(id: 22),
          ]),
        ),
        priorityPolicyActionProvider.overrideWith(() => action),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(1200, 1200);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(locale: Locale('en'), child: PriorityPolicyView()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'adds a dynamic subscription tier after self-hosted group and retains input on failure',
    (tester) async {
      final action = _Action();
      final container = await open(tester, action);
      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();
      expect(find.text('1. Taiwan'), findsOneWidget);
      await tester.tap(find.text('Add priority'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('First subscription'));
      await tester.tap(find.text('Second subscription'));
      await tester.enterText(find.byType(TextFormField).first, 'US');
      await tester.enterText(find.byType(TextFormField).last, 'expired');
      await tester.tap(find.text('Preview matches'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('First subscription · US Fast'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Second subscription · US Fast'),
        findsOneWidget,
      );
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('2. First subscription'), findsOneWidget);
      action.fail = true;
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not save'), findsOneWidget);
      expect(find.text('1. Taiwan'), findsOneWidget);
      expect(container.read(priorityPolicySettingProvider).policies, isEmpty);
      action.fail = false;
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      final policy = container
          .read(priorityPolicySettingProvider)
          .policies
          .single;
      expect(policy.group, 'Video');
      expect(policy.tiers.first.target, 'Taiwan');
      expect(policy.tiers.last.sourceIds, [11, 22]);
      expect(policy.tiers.last.exclude, 'expired');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tiers can be reordered and removed without editing the base file',
    (tester) async {
      final action = _Action();
      final container = await open(tester, action);
      container
          .read(priorityPolicySettingProvider.notifier)
          .value = const PriorityPolicies(
        policies: [
          PriorityPolicy(
            profileId: 10,
            group: 'Video',
            tiers: [
              PriorityTier(target: 'Taiwan'),
              PriorityTier(sourceIds: [11], filter: 'US'),
            ],
          ),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Video'));
      await tester.pumpAndSettle();
      await rightClick(
        tester,
        find.textContaining('2. First subscription').last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move up'));
      await tester.pumpAndSettle();
      expect(find.text('1. First subscription / US'), findsOneWidget);
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(
        container
            .read(priorityPolicySettingProvider)
            .policies
            .single
            .tiers
            .first
            .sourceIds,
        [11],
      );
      await rightClick(tester, find.text('Video'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(container.read(priorityPolicySettingProvider).policies, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
