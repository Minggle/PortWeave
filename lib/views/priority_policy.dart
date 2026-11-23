import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/priority_policy.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _isStandardBase(Profile profile) =>
    profile.type != ProfileType.custom && profile.scriptId == null;

String _priorityError(AppLocalizations l, Object error) => switch (error) {
  PriorityPolicyException(issue: PriorityPolicyIssue.cycle) => l.priorityCycle,
  PriorityPolicyException(issue: PriorityPolicyIssue.missingTarget) =>
    l.priorityMissingTarget,
  PriorityPolicyException(issue: PriorityPolicyIssue.missingSource) =>
    l.portRoutingMissingSource,
  _ => l.priorityInvalid,
};

String _tierLabel(
  PriorityTier tier,
  List<Profile> profiles,
  AppLocalizations l,
) => tier.isLocal
    ? tier.target
    : [
        profiles
            .where((p) => tier.sourceIds.contains(p.id))
            .map((p) => p.realLabel)
            .join(' · '),
        tier.filter.isEmpty ? l.priorityAll : tier.filter,
        if (tier.exclude.isNotEmpty) '${l.priorityExclude}: ${tier.exclude}',
      ].join(' / ');

class PriorityPolicyView extends ConsumerStatefulWidget {
  const PriorityPolicyView({super.key, this.bindingId});

  final int? bindingId;

  @override
  ConsumerState<PriorityPolicyView> createState() => _PriorityPolicyViewState();
}

class _PriorityPolicyViewState extends ConsumerState<PriorityPolicyView> {
  int? _profileId;
  Map<String, dynamic>? _base;
  String? _error;
  int _load = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final profiles = _profiles;
    final current = ref.read(currentProfileIdProvider);
    _profileId = profiles.any((p) => p.id == current)
        ? current
        : profiles.firstOrNull?.id;
    if (widget.bindingId != null) {
      _profileId = _binding?.profileId;
    }
    unawaited(_loadBase());
  }

  List<Profile> get _profiles =>
      ref.read(profilesProvider).where(_isStandardBase).toList();

  PortBinding? get _binding => ref
      .read(portRoutingSettingProvider)
      .bindings
      .where((binding) => binding.id == widget.bindingId)
      .firstOrNull;

  List<PriorityPolicy> get _policies => widget.bindingId == null
      ? ref.read(priorityPolicySettingProvider).forProfile(_profileId)
      : _binding?.policies ?? const [];

  Future<void> _loadBase() async {
    final load = ++_load;
    setState(() {
      _base = null;
      _error = null;
    });
    final id = _profileId;
    if (id == null) return;
    try {
      final base = widget.bindingId == null
          ? await ref.read(priorityPolicyActionProvider.notifier).readBase(id)
          : await ref
                .read(portRoutingActionProvider.notifier)
                .readBindingBase(widget.bindingId!);
      if (mounted && load == _load) setState(() => _base = base);
    } catch (error) {
      if (mounted && load == _load) {
        setState(
          () => _error = _priorityError(context.appLocalizations, error),
        );
      }
    }
  }

  Future<void> _edit([PriorityPolicy? policy]) async {
    if (_base == null || _profileId == null) return;
    await showFormSheet<void>(
      context: context,
      builder: (_) => _PolicyForm(
        profileId: _profileId!,
        base: _base!,
        policy: policy,
        bindingId: widget.bindingId,
      ),
    );
  }

  Future<void> _remove(PriorityPolicy policy) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final next = _policies.where((p) => p.group != policy.group).toList();
      if (widget.bindingId case final id?) {
        await ref
            .read(portRoutingActionProvider.notifier)
            .savePolicies(id, next);
      } else {
        await ref
            .read(priorityPolicyActionProvider.notifier)
            .save(policy.profileId, next);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = _priorityError(context.appLocalizations, error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final profiles = ref.watch(profilesProvider);
    final eligible = profiles.where(_isStandardBase).toList();
    ref.watch(priorityPolicySettingProvider);
    ref.watch(portRoutingSettingProvider);
    final policies = _policies;
    final binding = _binding;
    return Scaffold(
      title: binding == null
          ? l.priorityTitle
          : '${binding.name} · ${binding.port}',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: l.add,
          onPressed: _base == null || _busy ? null : _edit,
        ),
        IconButtonData(
          glyph: AppGlyphs.refresh,
          tooltip: l.portRoutingCheck,
          onPressed: _busy ? null : _loadBase,
        ),
      ],
      body: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            context.sectionsTopPadding,
            16,
            20 + context.bottomInset,
          ),
          children: [
            Text(
              widget.bindingId == null
                  ? l.priorityDescription
                  : l.aggregateProxyDescription,
            ),
            const SizedBox(height: 16),
            if (widget.bindingId == null && eligible.isNotEmpty)
              generateSection(
                items: [
                  ListItem<int>.options(
                    title: Text(l.priorityBase),
                    value: _profileId ?? eligible.first.id,
                    options: eligible.map((p) => p.id).toList(),
                    textBuilder: (id) =>
                        profiles.getProfile(id)?.realLabel ??
                        l.portRoutingMissingSource,
                    onChanged: (id) {
                      if (_busy) return;
                      setState(() => _profileId = id);
                      unawaited(_loadBase());
                    },
                  ),
                ],
              ),
            if (_profileId != null && _base == null && _error == null)
              const LinearProgressIndicator(),
            ErrorBanner(message: _error),
            if (policies.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l.priorityEmpty),
              ),
            for (final policy in policies)
              generateSection(
                items: [
                  ContextMenuRegion(
                    menuItems: [
                      PopupMenuItem(
                        label: l.edit,
                        onPressed: () => _edit(policy),
                      ),
                      PopupMenuItem(
                        label: l.delete,
                        onPressed: () => _remove(policy),
                      ),
                    ],
                    child: ListItem(
                      title: Text(policy.group),
                      subtitle: Text(
                        [
                          for (final (index, tier) in policy.tiers.indexed)
                            '${index + 1}. ${_tierLabel(tier, profiles, l)}',
                        ].join('\n'),
                      ),
                      onTap: _busy ? null : () => _edit(policy),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PolicyForm extends ConsumerStatefulWidget {
  final int profileId;
  final Map<String, dynamic> base;
  final PriorityPolicy? policy;
  final int? bindingId;

  const _PolicyForm({
    required this.profileId,
    required this.base,
    this.policy,
    this.bindingId,
  });

  @override
  ConsumerState<_PolicyForm> createState() => _PolicyFormState();
}

class _PolicyFormState extends ConsumerState<_PolicyForm> {
  late String _group;
  late List<PriorityTier> _tiers;
  bool _saving = false;
  String? _error;

  List<Map> get _groups =>
      (widget.base['proxy-groups'] as List? ?? []).cast<Map>();

  @override
  void initState() {
    super.initState();
    _group =
        widget.policy?.group ?? _groups.firstOrNull?['name'] as String? ?? '';
    _tiers = widget.policy?.tiers.toList() ?? _initialTiers(_group);
  }

  List<PriorityTier> _initialTiers(String name) {
    final group = _groups.where((g) => g['name'] == name).firstOrNull;
    final first = (group?['proxies'] as List?)?.firstOrNull;
    return first is String ? [PriorityTier(target: first)] : [];
  }

  Future<void> _editTier([int? index]) async {
    final targets = [
      for (final group in _groups)
        if (group['name'] != _group) group['name'] as String,
      for (final node in (widget.base['proxies'] as List? ?? []).cast<Map>())
        node['name'] as String,
      'DIRECT',
      'REJECT',
    ];
    final result = await showFormSheet<PriorityTier>(
      context: context,
      builder: (_) => _TierForm(
        profileId: widget.profileId,
        targets: targets.toSet().toList(),
        tier: index == null ? null : _tiers[index],
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _tiers.add(result);
      } else {
        _tiers[index] = result;
      }
    });
  }

  void _move(int index, int delta) => setState(() {
    final item = _tiers.removeAt(index);
    _tiers.insert(index + delta, item);
  });

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final binding = ref
          .read(portRoutingSettingProvider)
          .bindings
          .where((item) => item.id == widget.bindingId)
          .firstOrNull;
      final policies = widget.bindingId == null
          ? ref.read(priorityPolicySettingProvider).forProfile(widget.profileId)
          : binding?.policies ?? const <PriorityPolicy>[];
      if (widget.bindingId != null &&
          (binding == null || binding.profileId != widget.profileId)) {
        throw const PriorityPolicyException(PriorityPolicyIssue.missingTarget);
      }
      if (widget.policy == null && policies.any((p) => p.group == _group)) {
        throw const PriorityPolicyException(PriorityPolicyIssue.invalid);
      }
      final next = [
        for (final policy in policies)
          if (policy.group != (widget.policy?.group ?? _group)) policy,
        PriorityPolicy(
          profileId: widget.profileId,
          group: _group,
          tiers: _tiers,
        ),
      ];
      if (widget.bindingId case final id?) {
        await ref
            .read(portRoutingActionProvider.notifier)
            .savePolicies(id, next);
      } else {
        await ref
            .read(priorityPolicyActionProvider.notifier)
            .save(widget.profileId, next);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = _priorityError(context.appLocalizations, error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final profiles = ref.watch(profilesProvider);
    return PopScope(
      canPop: !_saving,
      child: AbsorbPointer(
        absorbing: _saving,
        child: FormPage(
          title: l.priorityTitle,
          onSave: _save,
          saving: _saving,
          error: _error,
          children: [
            generateSection(
              items: [
                ListItem<String>.options(
                  title: Text(l.proxyGroup),
                  value: _group,
                  options: _groups.map((g) => g['name'] as String).toList(),
                  textBuilder: (value) => value,
                  onChanged: (value) => setState(() {
                    _group = value;
                    _tiers = _initialTiers(value);
                  }),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.priorityOrderHint),
            ),
            generateSection(
              items: [
                for (final (index, tier) in _tiers.indexed)
                  ContextMenuRegion(
                    menuItems: [
                      if (index > 0)
                        PopupMenuItem(
                          label: l.priorityMoveUp,
                          onPressed: () => _move(index, -1),
                        ),
                      if (index + 1 < _tiers.length)
                        PopupMenuItem(
                          label: l.priorityMoveDown,
                          onPressed: () => _move(index, 1),
                        ),
                      PopupMenuItem(
                        label: l.delete,
                        onPressed: () => setState(() => _tiers.removeAt(index)),
                      ),
                    ],
                    child: ListItem(
                      title: Text(
                        '${index + 1}. ${_tierLabel(tier, profiles, l)}',
                      ),
                      onTap: () => _editTier(index),
                    ),
                  ),
                ListItem(
                  title: Text(l.priorityAddTier),
                  leading: const GlyphIcon(AppGlyphs.add),
                  onTap: _editTier,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TierForm extends ConsumerStatefulWidget {
  final int profileId;
  final List<String> targets;
  final PriorityTier? tier;
  const _TierForm({required this.profileId, required this.targets, this.tier});

  @override
  ConsumerState<_TierForm> createState() => _TierFormState();
}

class _TierFormState extends ConsumerState<_TierForm> {
  late bool _local;
  late String _target;
  late Set<int> _sources;
  late final TextEditingController _filter;
  late final TextEditingController _exclude;
  String? _error;
  String? _preview;
  bool _loading = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _local = widget.tier?.isLocal ?? false;
    _target = widget.tier?.target ?? widget.targets.firstOrNull ?? '';
    _sources = widget.tier?.sourceIds.toSet() ?? {};
    _filter = TextEditingController(text: widget.tier?.filter ?? '');
    _exclude = TextEditingController(text: widget.tier?.exclude ?? '');
  }

  PriorityTier _value() => _local
      ? PriorityTier(target: _target)
      : PriorityTier(
          sourceIds: _sources.toList(),
          filter: _filter.text.trim(),
          exclude: _exclude.text.trim(),
        );

  Future<void> _inspect() async {
    final request = ++_request;
    final tier = _value();
    setState(() {
      _loading = true;
      _error = null;
      _preview = null;
    });
    try {
      final found = await ref
          .read(priorityPolicyActionProvider.notifier)
          .preview(tier);
      if (!mounted || request != _request) return;
      final profiles = ref.read(profilesProvider);
      final samples = [
        for (final (id, name) in found.sample)
          '${profiles.getProfile(id)?.realLabel ?? id} · $name',
      ];
      if (mounted && request == _request) {
        setState(
          () => _preview =
              '${context.appLocalizations.portRoutingMatches}: ${found.count}\n${samples.join('\n')}',
        );
      }
    } catch (error) {
      if (mounted && request == _request) {
        setState(
          () => _error = _priorityError(context.appLocalizations, error),
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  void _changed() => setState(() {
    _request++;
    _loading = false;
    _preview = null;
  });

  @override
  void dispose() {
    _request++;
    _filter.dispose();
    _exclude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final profiles = ref
        .watch(profilesProvider)
        .where((p) => p.id != widget.profileId && p.type != ProfileType.custom)
        .toList();
    return FormPage(
      title: l.priorityTier,
      error: _error,
      onSave: () {
        final value = _value();
        if (value.isLocal
            ? !widget.targets.contains(value.target)
            : value.sourceIds.isEmpty) {
          setState(() => _error = l.priorityInvalid);
          return;
        }
        Navigator.of(context).pop(value);
      },
      children: [
        generateSection(
          items: [
            ListItem<bool>.options(
              title: Text(l.priorityKind),
              value: _local,
              options: const [true, false],
              textBuilder: (local) =>
                  local ? l.priorityLocal : l.prioritySubscriptions,
              onChanged: (local) {
                _changed();
                setState(() {
                  _local = local;
                  if (_target.isEmpty) {
                    _target = widget.targets.firstOrNull ?? '';
                  }
                });
              },
            ),
            if (_local)
              ListItem<String>.options(
                title: Text(l.proxyGroup),
                value: _target,
                options: widget.targets,
                textBuilder: (value) => value,
                onChanged: (value) => setState(() => _target = value),
              ),
          ],
        ),
        if (!_local) ...[
          generateSection(
            items: [
              for (final profile in profiles)
                ListItem(
                  title: Text(profile.realLabel),
                  trailing: Checkbox(
                    value: _sources.contains(profile.id),
                    onChanged: (_) {
                      _changed();
                      setState(() {
                        _sources.addOrRemove(profile.id);
                      });
                    },
                  ),
                  onTap: () {
                    _changed();
                    setState(() {
                      _sources.addOrRemove(profile.id);
                    });
                  },
                ),
            ],
          ),
          generateSection(
            items: [
              FormRow(
                title: l.priorityInclude,
                trailing: FormRowTextField(
                  controller: _filter,
                  onChanged: (_) => _changed(),
                ),
              ),
              FormRow(
                title: l.priorityExclude,
                trailing: FormRowTextField(
                  controller: _exclude,
                  onChanged: (_) => _changed(),
                ),
              ),
              ListItem(
                title: Text(l.priorityPreview),
                onTap: _loading ? null : _inspect,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l.priorityFilterHint),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_preview != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(_preview!)),
        ],
      ],
    );
  }
}
