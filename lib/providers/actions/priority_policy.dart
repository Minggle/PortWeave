part of '../action.dart';

@Riverpod(keepAlive: true)
class PriorityPolicyAction extends _$PriorityPolicyAction {
  final _operations = SerialTaskScheduler();
  final _preparations = SerialTaskScheduler();

  @override
  void build() {}

  CoreController get _core => ref.read(coreHandlerProvider);

  Future<Map<String, dynamic>> readBase(int profileId) async {
    final profile = ref.read(profilesProvider).getProfile(profileId);
    if (profile == null ||
        profile.type == ProfileType.custom ||
        profile.extendType == ExtendType.script) {
      throw const PriorityPolicyException(PriorityPolicyIssue.missingTarget);
    }
    return _core.readConfig(profileId);
  }

  Future<List<Map<String, dynamic>>> _readSource(String path) async {
    final nodes = await compute(
      portSubscriptionNodes,
      await File(path).readAsString(),
    );
    if ((await _core.validateProxies(nodes)).isNotEmpty) {
      throw const PriorityPolicyException(PriorityPolicyIssue.invalid);
    }
    return nodes;
  }

  Future<List<String>> nodeNames(int id) async => [
    for (final node in await _readSource(
      await appPath.getProfilePath(id.toString()),
    ))
      node['name'] as String,
  ];

  Future<void> validateSource(int id, String path) async {
    if (ref
        .read(priorityPolicySettingProvider)
        .policies
        .any((p) => p.sourceIds.contains(id))) {
      await _readSource(path);
    }
  }

  Future<({int count, List<(int, String)> sample})> preview(
    PriorityTier tier,
  ) async {
    final sources = <int, List<String>>{};
    for (final id in tier.sourceIds) {
      sources[id] = await nodeNames(id);
    }
    return compute(priorityPreview, (tier, sources));
  }

  void sourceUpdated(int id) {
    final current = ref.read(currentProfileIdProvider);
    if (id != current &&
        ref
            .read(priorityPolicySettingProvider)
            .forProfile(current)
            .any((policy) => policy.sourceIds.contains(id))) {
      ref
          .read(setupActionProvider.notifier)
          .applyProfileDebounce(silence: true, force: true);
    }
  }

  Future<({Map<String, dynamic> config, Map<String, dynamic> providers})>
  prepare(
    Map<String, dynamic> base,
    List<PriorityPolicy> policies,
    String testUrl,
  ) => _preparations.run(() async {
    validatePriorityPolicies(policies);
    final paths = <int, String>{};
    for (final id in policies.expand((policy) => policy.sourceIds).toSet()) {
      final profile = ref.read(profilesProvider).getProfile(id);
      if (profile == null || profile.type == ProfileType.custom) {
        throw const PriorityPolicyException(PriorityPolicyIssue.missingSource);
      }
      final nodes = await _readSource(
        await appPath.getProfilePath(id.toString()),
      );
      final payload = await encodeYamlTask({'proxies': nodes});
      final latest = ref.read(profilesProvider).getProfile(id);
      if (latest?.url != profile.url ||
          latest?.ageSecretKey != profile.ageSecretKey ||
          latest?.type != profile.type ||
          latest?.lastUpdateDate != profile.lastUpdateDate) {
        throw const PriorityPolicyException(PriorityPolicyIssue.missingSource);
      }
      final file = File(
        join(
          await appPath.getProviderDirPath(
            policies.first.profileId,
            proxiesProviderDirectoryName,
          ),
          'priority-$id.yaml',
        ),
      );
      await file.writeAsStringAtomically(payload);
      paths[id] = file.path;
    }
    return compute(
      (args) => compilePriorityPolicies(
        base: args.$1,
        policies: args.$2,
        sourcePaths: args.$3,
        testUrl: args.$4,
      ),
      (base, policies, paths, testUrl),
    );
  });

  Future<void> save(
    int profileId,
    List<PriorityPolicy> policies,
  ) => _operations.run(() async {
    final before = ref.read(priorityPolicySettingProvider);
    final profileBefore = ref.read(profilesProvider).getProfile(profileId);
    if (policies.any((policy) => policy.profileId != profileId)) {
      throw const PriorityPolicyException(PriorityPolicyIssue.invalid);
    }
    if (policies.isNotEmpty) {
      final base = await readBase(profileId);
      await prepare(base, policies, ref.read(patchClashConfigProvider).testUrl);
    }
    if (!ref.mounted ||
        before != ref.read(priorityPolicySettingProvider) ||
        profileBefore != ref.read(profilesProvider).getProfile(profileId)) {
      throw const PriorityPolicyException(PriorityPolicyIssue.invalid);
    }
    if (policies.isNotEmpty &&
        ref.read(profilesProvider).getProfile(profileId) == null) {
      throw const PriorityPolicyException(PriorityPolicyIssue.missingTarget);
    }
    final next = before.copyWith(
      policies: [
        for (final policy in before.policies)
          if (policy.profileId != profileId) policy,
        ...policies,
      ],
    );
    ref.read(priorityPolicySettingProvider.notifier).value = next;
    if (ref.read(currentProfileIdProvider) != profileId) return;
    try {
      if (!await ref
          .read(setupActionProvider.notifier)
          .applyProfile(force: true)) {
        throw const PriorityPolicyException(PriorityPolicyIssue.invalid);
      }
    } catch (_) {
      if (ref.mounted && ref.read(priorityPolicySettingProvider) == next) {
        ref.read(priorityPolicySettingProvider.notifier).value = before;
        if (ref.read(currentProfileIdProvider) == profileId) {
          await ref
              .read(setupActionProvider.notifier)
              .applyProfile(force: true);
        }
      }
      rethrow;
    }
  });
}
