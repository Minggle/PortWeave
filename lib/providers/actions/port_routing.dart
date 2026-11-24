part of '../action.dart';

@Riverpod(keepAlive: true)
class PortRoutingAction extends _$PortRoutingAction {
  Timer? _timer;
  final _operations = SerialTaskScheduler();
  final _storage = SerialTaskScheduler();
  final _refreshes = <int, Future<void>>{};
  final _retryAt = <int, DateTime>{};
  final _failures = <int, int>{};
  bool _polling = false;
  int _revision = 0;
  int _checkRevision = 0;

  @visibleForTesting
  int? get coreProcessId => coreService?.processId;

  @visibleForTesting
  Future<Map<int, int>> readPortOwners() => desktopPortOwners();

  CoreController get _core => ref.read(coreHandlerProvider);
  PortRoutingConfig get _config => ref.read(portRoutingSettingProvider);
  bool get _active => ref.read(portRoutingActiveProvider);

  @override
  void build() {
    ref.listen(portRoutingActiveProvider, (_, _) => _invalidate());
    ref.listen(portRoutingSettingProvider, (_, _) => _invalidate());
    ref.listen(profilesProvider, (previous, next) {
      for (final id in _config.sourceIds) {
        final before = previous?.getProfile(id);
        final after = next.getProfile(id);
        if (before?.url != after?.url ||
            before?.ageSecretKey != after?.ageSecretKey ||
            before?.type != after?.type) {
          _invalidate();
          break;
        }
      }
    });
    ref.listen(coreStatusProvider, (_, _) => _invalidate());
    ref.listen(
      runTimeProvider.select((state) => state != null),
      (_, _) => _invalidate(),
    );
    ref.listen(appVisibleProvider, (_, visible) {
      if (visible) unawaited(tick());
    });
    ref.onDispose(() {
      _revision++;
      _timer?.cancel();
    });
  }

  void _invalidate() {
    _revision++;
    _retryAt.clear();
    ref.read(portRoutingActivityProvider.notifier).clearChecks();
  }

  void stopScheduler() {
    _timer?.cancel();
    _timer = null;
    _revision++;
  }

  void startScheduler() {
    _timer ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(tick()),
    );
    unawaited(tick());
  }

  bool owns(int profileId) => _active && _config.sourceIds.contains(profileId);

  bool references(int profileId) =>
      _config.bindings.any((binding) => binding.sourceIds.contains(profileId));

  Profile _source(int id) {
    final source = ref.read(profilesProvider).getProfile(id);
    if (source == null || source.type == ProfileType.custom) {
      throw const PortRoutingException(PortRoutingIssue.missingSubscription);
    }
    return source;
  }

  Future<File> _cache(int workspaceId, int sourceId) async => File(
    join(
      await appPath.profilesPath,
      providersDirectoryName,
      workspaceId.toString(),
      proxiesProviderDirectoryName,
      'ports-$sourceId.yaml',
    ),
  );

  Future<List<Map<String, dynamic>>> _readNodes(String path) async =>
      compute(portSubscriptionNodes, await File(path).readAsString());

  Future<void> discardCaches([PortRoutingConfig? restored]) =>
      _storage.run(() async {
        _invalidate();
        final config = restored ?? _config;
        final workspaceId = config.workspaceProfileId;
        if (workspaceId == null) return;
        for (final id
            in config.bindings.expand((binding) => binding.sourceIds).toSet()) {
          final cache = await _cache(workspaceId, id);
          await File('${cache.path}.good').safeDelete();
          await cache.safeDelete();
        }
      });

  Future<List<String>> nodeNames(int profileId) async {
    final nodes = await _readNodes(
      await appPath.getProfilePath(_source(profileId).id.toString()),
    );
    return [for (final node in nodes) node['name'] as String];
  }

  Future<Map<String, dynamic>> readBindingBase(int id) async {
    final binding = _config.bindings.where((item) => item.id == id).firstOrNull;
    if (binding == null) {
      throw const PortRoutingException(PortRoutingIssue.invalidBinding);
    }
    return _validatedDocument(
      await appPath.getProfilePath(_source(binding.profileId).id.toString()),
    );
  }

  Future<void> savePolicies(int id, List<PriorityPolicy> policies) async {
    final binding = _config.bindings.where((item) => item.id == id).firstOrNull;
    if (binding == null || binding.selection != PortSelection.aggregate) {
      throw const PortRoutingException(PortRoutingIssue.invalidBinding);
    }
    await saveBinding(binding.copyWith(policies: policies));
  }

  Future<Map<String, dynamic>> _validatedDocument(String path) async {
    final document = await compute(
      portSubscriptionDocument,
      await File(path).readAsString(),
    );
    final nodes = (document['proxies'] as List).cast<Map<String, dynamic>>();
    final issues = await _core.validateProxies(nodes);
    if (issues.isNotEmpty) {
      throw PortRoutingException(
        PortRoutingIssue.invalidNodes,
        nodes: [
          for (final index in issues.keys) nodes[index]['name'] as String,
        ],
      );
    }
    return document;
  }

  Future<PortRoutingFragment> prepare(PortRoutingConfig config) =>
      _storage.run(() async {
        validatePortBindings(config.bindings);
        final workspaceId = config.workspaceProfileId;
        if (workspaceId == null) {
          throw const PortRoutingException(PortRoutingIssue.invalidBinding);
        }
        final paths = <int, String>{};
        final documents = <int, Map<String, dynamic>>{};
        for (final id in config.sourceIds) {
          final source = _source(id);
          final cache = await _cache(workspaceId, id);
          final good = File('${cache.path}.good');
          String payload;
          try {
            final path = await appPath.getProfilePath(source.id.toString());
            payload = await encodeYamlTask(await _validatedDocument(path));
          } on Exception {
            if (!await good.exists()) rethrow;
            payload = await good.readAsString();
          }
          if (!await good.exists() || await good.readAsString() != payload) {
            await good.writeAsStringAtomically(payload);
          }
          if (!await cache.exists() || await cache.readAsString() != payload) {
            await cache.writeAsStringAtomically(payload);
          }
          paths[id] = cache.path;
          documents[id] = await compute(portSubscriptionDocument, payload);
        }
        return compute(
          (args) => compilePortRouting(
            bindings: args.$1,
            sourcePaths: args.$2,
            sourceDocuments: args.$3,
            selectedMaps: args.$4,
            testUrl: args.$5,
            takeoverSystem: args.$6,
            defaultBindingId: args.$7,
          ),
          (
            config.bindings,
            paths,
            documents,
            {for (final id in config.sourceIds) id: _source(id).selectedMap},
            ref.read(patchClashConfigProvider).testUrl,
            config.takeoverSystem,
            config.defaultBindingId,
          ),
        );
      });

  Future<void> activate() => _operations.run(() async {
    if (_active) return;
    final startedRevision = _revision;
    final previous = ref.read(currentProfileIdProvider);
    var config = _config;
    validatePortBindings(config.bindings);
    _validateHostPortConflicts(config);
    if (config.sourceIds.isEmpty) {
      throw const PortRoutingException(PortRoutingIssue.invalidBinding);
    }
    if (ref.read(coreStatusProvider) != CoreStatus.connected) {
      throw const PortRoutingException(PortRoutingIssue.coreUnavailable);
    }
    for (final binding in config.bindings.where((binding) => binding.enabled)) {
      await checkPortAvailable(binding.port);
    }
    final profiles = ref.read(profilesProvider);
    var workspace = profiles.getProfile(config.workspaceProfileId);
    if (workspace == null || workspace.type != ProfileType.custom) {
      workspace = Profile.custom(
        label: currentAppLocalizations.portRoutingTitle,
      );
      ref.read(profilesProvider.notifier).put(workspace);
    }
    config = config.copyWith(
      workspaceProfileId: workspace.id,
      previousProfileId: previous,
    );
    await prepare(config);
    if (!ref.mounted ||
        startedRevision != _revision ||
        previous != ref.read(currentProfileIdProvider)) {
      throw const PortRoutingException(PortRoutingIssue.staleUpdate);
    }
    ref.read(portRoutingSettingProvider.notifier).value = config;
    ref.read(currentProfileIdProvider.notifier).value = workspace.id;
    final activatedRevision = _revision;
    try {
      final applied = await ref
          .read(setupActionProvider.notifier)
          .applyProfile(force: true);
      if (!ref.mounted || activatedRevision != _revision || !_active) return;
      if (!applied ||
          !await ref.read(setupActionProvider.notifier).setRunning(true)) {
        throw const PortRoutingException(PortRoutingIssue.coreUnavailable);
      }
      await checkAll();
    } catch (_) {
      if (ref.mounted && activatedRevision == _revision && _active) {
        ref.read(currentProfileIdProvider.notifier).value = previous;
        await ref.read(setupActionProvider.notifier).applyProfile(force: true);
      }
      rethrow;
    }
  });

  Future<void> deactivate() => _operations.run(() async {
    if (!_active) return;
    final config = _config;
    final profiles = ref.read(profilesProvider);
    final previous =
        profiles.getProfile(config.previousProfileId) ??
        profiles
            .where((profile) => profile.id != config.workspaceProfileId)
            .firstOrNull;
    ref.read(currentProfileIdProvider.notifier).value = previous?.id;
    if (previous == null) {
      await ref.read(setupActionProvider.notifier).setRunning(false);
    } else {
      await ref.read(setupActionProvider.notifier).applyProfile(force: true);
    }
  });

  Future<void> saveBinding(PortBinding binding) => _operations.run(() async {
    final revision = _revision;
    final before = _config;
    final bindings = [
      for (final existing in before.bindings)
        if (existing.id != binding.id) existing,
      binding,
    ];
    validatePortBindings(bindings);
    if (_active) {
      _validateHostPortConflicts(before.copyWith(bindings: bindings));
    }
    for (final id in binding.sourceIds) {
      _source(id);
    }
    final old = before.bindings
        .where((item) => item.id == binding.id)
        .firstOrNull;
    if (binding.enabled &&
        (!(_active && old?.enabled == true && old?.port == binding.port))) {
      await checkPortAvailable(binding.port);
    }
    final validatePolicies =
        binding.selection == PortSelection.aggregate &&
        binding.policies.isNotEmpty;
    if (binding.enabled || validatePolicies) {
      final documents = <int, Map<String, dynamic>>{};
      for (final id in binding.sourceIds) {
        documents[id] = await _validatedDocument(
          await appPath.getProfilePath(id.toString()),
        );
      }
      if (binding.usesRules) {
        final candidate = binding.enabled
            ? binding
            : binding.copyWith(enabled: true);
        await compute(
          (args) => compilePortRouting(
            bindings: [args.$1],
            sourcePaths: {for (final id in args.$1.sourceIds) id: ''},
            sourceDocuments: args.$2,
            testUrl: args.$3,
          ),
          (candidate, documents, ref.read(patchClashConfigProvider).testUrl),
        );
      }
    }
    if (!ref.mounted || revision != _revision) {
      throw const PortRoutingException(PortRoutingIssue.staleUpdate);
    }
    await _saveConfig(
      before,
      before.copyWith(bindings: bindings),
      notifyFallback: true,
    );
  });

  Future<void> removeBinding(int id) => _operations.run(() {
    final before = _config;
    final next = before.copyWith(
      bindings: before.bindings.where((item) => item.id != id).toList(),
      defaultBindingId: before.defaultBindingId == id
          ? null
          : before.defaultBindingId,
    );
    return _saveConfig(before, next, notifyFallback: true);
  });

  Future<void> setDefaultBinding(int? bindingId) => _operations.run(() async {
    final before = _config;
    if (bindingId != null &&
        !before.bindings.any((b) => b.id == bindingId && b.enabled)) {
      throw const PortRoutingException(PortRoutingIssue.invalidBinding);
    }
    final next = before.copyWith(
      defaultBindingId: bindingId,
      takeoverSystem: bindingId != null ? true : before.takeoverSystem,
    );
    if (next == before) return;
    if (_active) _validateHostPortConflicts(next);
    await _saveConfig(before, next);
  });

  Future<void> setTakeoverSystem(bool takeover) => _operations.run(() async {
    final before = _config;
    final next = before.copyWith(takeoverSystem: takeover);
    if (next == before) return;
    if (_active) _validateHostPortConflicts(next);
    await _saveConfig(before, next);
  });

  Future<void> reorderBindings(List<int> orderedIds) => _operations.run(
    () async {
      final before = _config;
      final byId = {for (final b in before.bindings) b.id: b};
      final reorderedSubset = [
        for (final id in orderedIds)
          if (byId[id] case final binding?) binding,
      ];
      final subsetIds = {for (final b in reorderedSubset) b.id};
      var cursor = 0;
      final nextBindings = [
        for (final binding in before.bindings)
          if (subsetIds.contains(binding.id) && cursor < reorderedSubset.length)
            reorderedSubset[cursor++]
          else
            binding,
      ];
      ref.read(portRoutingSettingProvider.notifier).value = before.copyWith(
        bindings: nextBindings,
      );
    },
  );

  Set<int> _activeHostPorts() {
    final patch = ref.read(patchClashConfigProvider);
    final controllerPort =
        patch.externalController == ExternalControllerStatus.open &&
            patch.secret.isNotEmpty
        ? int.tryParse(patch.externalController.value.split(':').last)
        : null;
    return {
      for (final port in [
        patch.mixedPort,
        patch.port,
        patch.socksPort,
        patch.redirPort,
        patch.tproxyPort,
        ?controllerPort,
      ])
        if (port > 0) port,
    };
  }

  void _validateHostPortConflicts(PortRoutingConfig config) {
    if (config.resolveDefaultBinding() == null) return;
    final hostPorts = _activeHostPorts();
    for (final binding in config.bindings) {
      if (binding.enabled && hostPorts.contains(binding.port)) {
        throw const PortRoutingException(PortRoutingIssue.portOccupied);
      }
    }
  }

  Future<void> _saveConfig(
    PortRoutingConfig before,
    PortRoutingConfig next, {
    bool notifyFallback = false,
  }) async {
    final revision = _revision;
    if (_active) await prepare(next);
    if (!ref.mounted || revision != _revision) {
      throw const PortRoutingException(PortRoutingIssue.staleUpdate);
    }
    ref.read(portRoutingSettingProvider.notifier).value = next;
    if (!_active) return;
    try {
      if (!await ref
          .read(setupActionProvider.notifier)
          .applyProfile(force: true)) {
        throw const PortRoutingException(PortRoutingIssue.coreUnavailable);
      }
    } catch (_) {
      if (ref.mounted && _config == next) {
        ref.read(portRoutingSettingProvider.notifier).value = before;
        await ref.read(setupActionProvider.notifier).applyProfile(force: true);
      }
      rethrow;
    }
    if (notifyFallback) {
      final beforeDefault = before.resolveDefaultBinding();
      final afterDefault = next.resolveDefaultBinding();
      if (beforeDefault != null && beforeDefault.id != afterDefault?.id) {
        final message = afterDefault == null
            ? currentAppLocalizations.portRoutingEnteredIsolatedTip
            : currentAppLocalizations.portRoutingDefaultSwitched(
                afterDefault.name,
              );
        dialogs.showBanner(message, level: BannerLevel.info);
      }
    }
    await checkAll();
  }

  void setRefresh(PortSubscriptionRefresh setting) {
    if (setting.intervalMinutes < 1 || setting.intervalMinutes > 1440) {
      throw const PortRoutingException(PortRoutingIssue.invalidBinding);
    }
    ref.read(portRoutingSettingProvider.notifier).value = _config.copyWith(
      subscriptions: [
        for (final item in _config.subscriptions)
          if (item.profileId != setting.profileId) item,
        setting,
      ],
    );
  }

  Future<void> refresh(int profileId) {
    return _refreshes.putIfAbsent(
      profileId,
      () => _refresh(profileId).whenComplete(() {
        _refreshes.remove(profileId);
      }),
    );
  }

  Future<void> _refresh(int profileId) async {
    final activity = ref.read(portRoutingActivityProvider.notifier);
    activity.updating(profileId, true);
    PortRoutingIssue? issue;
    try {
      final profile = _source(profileId);
      if (profile.type == ProfileType.file) {
        await sourceUpdated(profileId);
      } else if (owns(profileId)) {
        await _refreshManaged(profile);
      } else {
        await ref.read(profilesActionProvider.notifier).updateProfile(profile);
      }
      _failures.remove(profileId);
      _retryAt.remove(profileId);
      if (!_polling && ref.mounted && ref.read(appVisibleProvider)) {
        await checkAll();
      }
    } catch (error) {
      issue = error is PortRoutingException
          ? error.issue
          : PortRoutingIssue.updateFailed;
      final attempt = (_failures[profileId] ?? 0) + 1;
      _failures[profileId] = attempt;
      _retryAt[profileId] = DateTime.now().add(
        Duration(minutes: 1 << attempt.clamp(0, 5)),
      );
      rethrow;
    } finally {
      if (ref.mounted) activity.updating(profileId, false, issue);
    }
  }

  Future<void> _refreshManaged(Profile profile) async {
    final revision = _revision;
    final workspaceId = _config.workspaceProfileId!;
    final staging = File(
      join(await appPath.profilesPath, '.ports-${profile.id}-$revision.tmp'),
    );
    try {
      final response = await request.getFileResponseForUrl(profile.url);
      await staging.writeAsBytes(
        decompressUnlabeled(response.data ?? Uint8List(0)),
        flush: true,
      );
      if (await _core.validateProfile(staging.path, profile.ageSecretKey) !=
          null) {
        throw const PortRoutingException(
          PortRoutingIssue.unsupportedSubscription,
        );
      }
      final payload = await encodeYamlTask(
        await _validatedDocument(staging.path),
      );
      await _commitSource(
        profile,
        revision,
        workspaceId,
        payload,
        sourceText: await staging.readAsString(),
        subscriptionInfo: SubscriptionInfo.formHString(
          response.headers.value('subscription-userinfo'),
        ),
      );
    } finally {
      await staging.safeDelete();
    }
  }

  Future<void> sourceUpdated(int profileId) async {
    if (!owns(profileId)) return;
    final revision = _revision;
    final workspaceId = _config.workspaceProfileId!;
    final source = _source(profileId);
    final path = await appPath.getProfilePath(profileId.toString());
    final payload = await encodeYamlTask(await _validatedDocument(path));
    await _commitSource(source, revision, workspaceId, payload);
  }

  bool _sourceIsCurrent(Profile source, int revision) {
    if (!ref.mounted || revision != _revision || !owns(source.id)) return false;
    final latest = ref.read(profilesProvider).getProfile(source.id);
    return latest?.url == source.url &&
        latest?.ageSecretKey == source.ageSecretKey;
  }

  Future<void> _commitSource(
    Profile source,
    int revision,
    int workspaceId,
    String payload, {
    String? sourceText,
    SubscriptionInfo? subscriptionInfo,
  }) {
    if (_config.bindings.any(
      (binding) =>
          binding.enabled &&
          binding.sourceIds.contains(source.id) &&
          binding.usesRules,
    )) {
      return _commitPolicySource(
        source,
        revision,
        workspaceId,
        payload,
        sourceText,
        subscriptionInfo,
      );
    }
    return _operations.run(
      () => _storage.run(() async {
        if (!_sourceIsCurrent(source, revision)) {
          throw const PortRoutingException(PortRoutingIssue.staleUpdate);
        }
        final cache = await _cache(workspaceId, source.id);
        final good = File('${cache.path}.good');
        final previous = await good.readAsString();
        final original = File(
          await appPath.getProfilePath(source.id.toString()),
        );
        final oldSource = sourceText == null
            ? null
            : await original.readAsString();
        try {
          await _core.sideLoadExternalProvider(
            providerName: portProviderName(source.id),
            data: payload,
          );
          await _resetAutoGroups(source.id);
          if (!_sourceIsCurrent(source, revision)) {
            throw const PortRoutingException(PortRoutingIssue.staleUpdate);
          }
          if (sourceText != null) {
            await original.writeAsStringAtomically(sourceText);
          }
          await good.writeAsStringAtomically(payload);
          if (!_sourceIsCurrent(source, revision)) {
            throw const PortRoutingException(PortRoutingIssue.staleUpdate);
          }
        } catch (_) {
          if (oldSource != null) {
            await original.writeAsStringAtomically(oldSource);
          }
          await good.writeAsStringAtomically(previous);
          await cache.writeAsStringAtomically(previous);
          if (_sourceIsCurrent(source, revision)) {
            await _core.sideLoadExternalProvider(
              providerName: portProviderName(source.id),
              data: previous,
            );
            await _resetAutoGroups(source.id);
          }
          rethrow;
        }
        if (!_sourceIsCurrent(source, revision)) return;
        final latest = _source(source.id);
        ref
            .read(profilesProvider.notifier)
            .put(
              latest.copyWith(
                subscriptionInfo: subscriptionInfo ?? latest.subscriptionInfo,
                lastUpdateDate: DateTime.now(),
              ),
            );
        await ref.read(proxiesActionProvider.notifier).updateGroups();
        await ref.read(providersProvider.notifier).syncProviders();
      }),
    );
  }

  Future<void> _commitPolicySource(
    Profile source,
    int revision,
    int workspaceId,
    String payload,
    String? sourceText,
    SubscriptionInfo? subscriptionInfo,
  ) => _operations.run(() async {
    if (!_sourceIsCurrent(source, revision)) {
      throw const PortRoutingException(PortRoutingIssue.staleUpdate);
    }
    final original = File(await appPath.getProfilePath(source.id.toString()));
    final cache = await _cache(workspaceId, source.id);
    final good = File('${cache.path}.good');
    final previous = await good.readAsString();
    final originalText = await original.readAsString();
    final oldSource = sourceText == null ? previous : originalText;
    final candidateSource = sourceText ?? originalText;
    if (!_sourceIsCurrent(source, revision)) {
      throw const PortRoutingException(PortRoutingIssue.staleUpdate);
    }
    try {
      if (sourceText != null) {
        await original.writeAsStringAtomically(sourceText);
      }
      if (!await ref
          .read(setupActionProvider.notifier)
          .applyProfile(force: true)) {
        throw const PortRoutingException(PortRoutingIssue.updateFailed);
      }
      if (!_sourceIsCurrent(source, revision)) {
        throw const PortRoutingException(PortRoutingIssue.staleUpdate);
      }
      await good.writeAsStringAtomically(payload);
      await cache.writeAsStringAtomically(payload);
    } catch (_) {
      if (await original.readAsString() == candidateSource) {
        await original.writeAsStringAtomically(oldSource);
      }
      if (await good.readAsString() == payload) {
        await good.writeAsStringAtomically(previous);
      }
      if (await cache.readAsString() == payload) {
        await cache.writeAsStringAtomically(previous);
      }
      if (_sourceIsCurrent(source, revision)) {
        await ref.read(setupActionProvider.notifier).applyProfile(force: true);
      }
      rethrow;
    }
    if (!_sourceIsCurrent(source, revision)) return;
    ref
        .read(profilesProvider.notifier)
        .put(
          _source(source.id).copyWith(
            subscriptionInfo:
                subscriptionInfo ?? _source(source.id).subscriptionInfo,
            lastUpdateDate: DateTime.now(),
          ),
        );
    await ref.read(proxiesActionProvider.notifier).updateGroups();
    await ref.read(providersProvider.notifier).syncProviders();
  });

  Future<void> _resetAutoGroups(int profileId) async {
    if (!ref.mounted || !owns(profileId)) return;
    for (final binding in _config.bindings) {
      if (binding.enabled &&
          binding.sourceIds.contains(profileId) &&
          binding.selection == PortSelection.region) {
        final result = await _core.changeProxy(
          ChangeProxyParams(groupName: binding.groupName, proxyName: ''),
        );
        if (result.message.isNotEmpty) {
          throw const PortRoutingException(PortRoutingIssue.updateFailed);
        }
      }
    }
  }

  Future<void> tick() async {
    if (_polling ||
        !_active ||
        ref.read(safeModeProvider) ||
        ref.read(coreStatusProvider) != CoreStatus.connected) {
      return;
    }
    _polling = true;
    try {
      for (final id in _config.sourceIds) {
        if (!ref.mounted || !owns(id)) break;
        final source = ref.read(profilesProvider).getProfile(id);
        final refreshSetting = _config.refreshFor(id);
        if (source?.type != ProfileType.url || !refreshSetting.enabled) {
          continue;
        }
        final now = DateTime.now();
        final retry = _retryAt[id];
        final due =
            retry ??
            source?.lastUpdateDate?.add(
              Duration(minutes: refreshSetting.intervalMinutes),
            );
        if (due != null && now.isBefore(due)) continue;
        try {
          await refresh(id);
        } on Exception {
          continue;
        }
      }
      if (ref.mounted && ref.read(appVisibleProvider)) await checkAll();
    } finally {
      _polling = false;
    }
  }

  Future<void> checkAll() async {
    final checkRevision = ++_checkRevision;
    if (!_active ||
        ref.read(safeModeProvider) ||
        !ref.read(isStartProvider) ||
        ref.read(coreStatusProvider) != CoreStatus.connected) {
      ref.read(portRoutingActivityProvider.notifier).clearChecks();
      return;
    }
    final revision = _revision;
    final activity = ref.read(portRoutingActivityProvider.notifier);
    final bindings = _config.bindings
        .where((binding) => binding.enabled)
        .toList();
    if (bindings.isEmpty) return;
    final owner = coreProcessId;
    bool isCurrent() =>
        ref.mounted &&
        _active &&
        ref.read(isStartProvider) &&
        ref.read(coreStatusProvider) == CoreStatus.connected &&
        revision == _revision &&
        checkRevision == _checkRevision &&
        owner == coreProcessId;
    for (final binding in bindings) {
      activity.check(
        binding.id,
        const PortBindingCheck(PortBindingPhase.checking),
      );
    }
    final Map<int, int> owners;
    final ProxiesData proxies;
    try {
      if (owner == null) {
        throw const PortRoutingException(PortRoutingIssue.coreUnavailable);
      }
      owners = await readPortOwners();
      if (!isCurrent()) return;
      proxies = await _core.getProxies();
    } catch (_) {
      if (!isCurrent()) return;
      for (final binding in bindings) {
        activity.check(
          binding.id,
          const PortBindingCheck(
            PortBindingPhase.failed,
            issue: PortRoutingIssue.coreUnavailable,
          ),
        );
      }
      return;
    }
    for (final binding in bindings) {
      if (!isCurrent()) return;
      try {
        if (!owners.containsKey(binding.port)) {
          throw const PortRoutingException(PortRoutingIssue.coreUnavailable);
        }
        if (owners[binding.port] != owner) {
          throw const PortRoutingException(PortRoutingIssue.portOccupied);
        }
        await checkSocksHandshake(binding.port);
        final group = proxies.proxies[binding.groupName];
        final node = group is Map ? group['now'] as String? : null;
        final blocked =
            !binding.usesRules && (node == null || node == 'REJECT');
        if (!isCurrent()) return;
        activity.check(
          binding.id,
          PortBindingCheck(
            blocked ? PortBindingPhase.blocked : PortBindingPhase.listening,
            node: node?.replaceFirst(RegExp(r'^\[ports:[0-9]+\] '), ''),
          ),
        );
      } catch (error) {
        if (!isCurrent()) return;
        activity.check(
          binding.id,
          PortBindingCheck(
            PortBindingPhase.failed,
            issue: error is PortRoutingException
                ? error.issue
                : PortRoutingIssue.coreUnavailable,
          ),
        );
      }
    }
  }
}
