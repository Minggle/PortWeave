import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/port_routing.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String _portRoutingError(AppLocalizations l, Object error) {
  if (error is CoreMethodException) return l.portRoutingCoreUnavailable;
  if (error is! PortRoutingException) return l.portRoutingUpdateFailed;
  return switch (error.issue) {
    PortRoutingIssue.invalidNodes => l.portRoutingInvalidNodes(
      error.nodes.take(8).join(', '),
    ),
    PortRoutingIssue.invalidPort => l.portRoutingInvalidPort,
    PortRoutingIssue.duplicatePort ||
    PortRoutingIssue.portOccupied => l.portConflictTip,
    PortRoutingIssue.invalidBinding => l.portRoutingInvalidBinding,
    PortRoutingIssue.invalidFilter => l.portRoutingRegionHint,
    PortRoutingIssue.unsupportedSubscription => l.portRoutingUnsupported,
    PortRoutingIssue.emptySubscription => l.portRoutingEmptySource,
    PortRoutingIssue.duplicateNode => l.portRoutingDuplicateNode,
    PortRoutingIssue.missingSubscription => l.portRoutingMissingSource,
    PortRoutingIssue.coreUnavailable => l.portRoutingCoreUnavailable,
    PortRoutingIssue.staleUpdate => l.portRoutingStaleUpdate,
    PortRoutingIssue.sourceInUse => l.portRoutingSourceInUse,
    PortRoutingIssue.updateFailed => l.portRoutingUpdateFailed,
  };
}

class PortRoutingView extends ConsumerStatefulWidget {
  const PortRoutingView({super.key});

  @override
  ConsumerState<PortRoutingView> createState() => _PortRoutingViewState();
}

class _PortRoutingViewState extends ConsumerState<PortRoutingView> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await task();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = _portRoutingError(context.appLocalizations, error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([PortBinding? binding]) async {
    final profiles = ref
        .read(profilesProvider)
        .where((profile) => profile.type != ProfileType.custom)
        .toList();
    if (profiles.isEmpty) {
      setState(
        () => _error = context.appLocalizations.portRoutingMissingSource,
      );
      return;
    }
    await showFormSheet<void>(
      context: context,
      builder: (_) => _BindingForm(binding: binding, profiles: profiles),
    );
  }

  Future<void> _refreshOptions(int profileId) async {
    final setting = ref.read(portRoutingSettingProvider).refreshFor(profileId);
    final result = await showFormSheet<PortSubscriptionRefresh>(
      context: context,
      builder: (_) => _RefreshForm(setting: setting),
    );
    if (result != null && mounted) {
      ref.read(portRoutingActionProvider.notifier).setRefresh(result);
    }
  }

  Widget _binding(PortBinding binding, bool active) {
    return Consumer(
      builder: (context, ref, _) {
        final l = context.appLocalizations;
        final check = ref.watch(
          portRoutingActivityProvider.select(
            (state) => state.ports[binding.id],
          ),
        );
        final profiles = ref
            .watch(profilesProvider)
            .where((profile) => binding.sourceIds.contains(profile.id))
            .toList();
        final profile = profiles.firstOrNull;
        final phase = !active || !binding.enabled
            ? PortBindingPhase.stopped
            : check?.phase;
        final status = switch (phase) {
          PortBindingPhase.stopped => l.portRoutingStopped,
          PortBindingPhase.checking => l.portRoutingChecking,
          PortBindingPhase.listening => l.portRoutingListening,
          PortBindingPhase.blocked => l.portRoutingBlocked,
          PortBindingPhase.failed => _portRoutingError(
            l,
            PortRoutingException(
              check?.issue ?? PortRoutingIssue.coreUnavailable,
            ),
          ),
          null => l.portRoutingUnchecked,
        };
        return ContextMenuRegion(
          menuItems: [
            PopupMenuItem(
              label: 'HTTP',
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: binding.httpAddress)),
            ),
            PopupMenuItem(
              label: 'SOCKS5',
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: binding.socksAddress)),
            ),
            PopupMenuItem(label: l.edit, onPressed: () => _edit(binding)),
            for (final source in profiles) ...[
              PopupMenuItem(
                label: '${l.portRoutingRefreshSettings} · ${source.realLabel}',
                onPressed: () => _refreshOptions(source.id),
              ),
              if (source.type == ProfileType.url)
                PopupMenuItem(
                  label: '${l.update} · ${source.realLabel}',
                  onPressed: () => _run(
                    () => ref
                        .read(portRoutingActionProvider.notifier)
                        .refresh(source.id),
                  ),
                ),
            ],
            PopupMenuItem(
              label: l.delete,
              onPressed: () => _run(
                () => ref
                    .read(portRoutingActionProvider.notifier)
                    .removeBinding(binding.id),
              ),
            ),
          ],
          child: ListItem(
            title: Text('${binding.name} · 127.0.0.1:${binding.port}'),
            subtitle: Text(
              [
                profiles.isEmpty
                    ? l.portRoutingMissingSource
                    : profiles.map((p) => p.realLabel).join(' · '),
                switch (binding.selection) {
                  PortSelection.original => l.portRoutingOriginal,
                  PortSelection.fixed => binding.node,
                  PortSelection.region => binding.filter,
                },
                status,
                if (check?.node != null && active) check!.node!,
                if (profile?.lastUpdateDate != null)
                  '${l.update}: ${profile!.lastUpdateDate!.toLocal()}',
              ].join('\n'),
            ),
            onTap: () => _edit(binding),
            trailing: Switch(
              value: binding.enabled,
              onChanged: _busy
                  ? null
                  : (value) => _run(
                      () => ref
                          .read(portRoutingActionProvider.notifier)
                          .saveBinding(binding.copyWith(enabled: value)),
                    ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final config = ref.watch(portRoutingSettingProvider);
    final active = ref.watch(portRoutingActiveProvider);
    final runtime = ref.watch(portRoutingActivityProvider);
    final safe = ref.watch(safeModeProvider);
    return Scaffold(
      title: l.portRoutingTitle,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: l.add,
          onPressed: _busy ? null : _edit,
        ),
        IconButtonData(
          glyph: AppGlyphs.refresh,
          tooltip: l.portRoutingCheck,
          onPressed: _busy
              ? null
              : () => _run(
                  () => ref.read(portRoutingActionProvider.notifier).checkAll(),
                ),
        ),
      ],
      body: Builder(
        builder: (context) => PrismListView(
          padding: EdgeInsets.fromLTRB(
            16,
            context.sectionsTopPadding,
            16,
            20 + context.bottomInset,
          ),
          itemCount: config.bindings.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return generateSection(
                items: [
                  ListItem(
                    title: Text(l.portRoutingMode),
                    subtitle: Text(
                      safe ? l.portRoutingSafeMode : l.portRoutingDescription,
                    ),
                    trailing: Switch(
                      value: active,
                      onChanged: _busy
                          ? null
                          : (value) => _run(
                              () => value
                                  ? ref
                                        .read(
                                          portRoutingActionProvider.notifier,
                                        )
                                        .activate()
                                  : ref
                                        .read(
                                          portRoutingActionProvider.notifier,
                                        )
                                        .deactivate(),
                            ),
                    ),
                  ),
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_error!),
                    ),
                  for (final entry in runtime.errors.entries)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _portRoutingError(l, PortRoutingException(entry.value)),
                      ),
                    ),
                ],
              );
            }
            if (index == config.bindings.length + 1) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  config.bindings.isEmpty
                      ? l.portRoutingEmpty
                      : l.portRoutingCopyHint,
                ),
              );
            }
            return generateSection(
              items: [_binding(config.bindings[index - 1], active)],
            );
          },
        ),
      ),
    );
  }
}

class _BindingForm extends ConsumerStatefulWidget {
  final PortBinding? binding;
  final List<Profile> profiles;
  const _BindingForm({required this.binding, required this.profiles});

  @override
  ConsumerState<_BindingForm> createState() => _BindingFormState();
}

class _BindingFormState extends ConsumerState<_BindingForm> {
  late final int _id;
  late final TextEditingController _name;
  late final TextEditingController _port;
  late final TextEditingController _filter;
  late List<int> _profileIds;
  Map<int, List<String>> _sourceNodes = {};
  bool _saving = false;
  late PortSelection _selection;
  String _node = '';
  List<String>? _nodes;
  String? _error;
  int _load = 0;
  Timer? _previewTimer;
  int _previewRevision = 0;
  ({int count, List<String> sample}) _preview = (count: 0, sample: []);

  @override
  void initState() {
    super.initState();
    final binding = widget.binding;
    _id = binding?.id ?? snowflake.id;
    _name = TextEditingController(text: binding?.name);
    _port = TextEditingController(
      text: (binding?.port ?? _nextPort()).toString(),
    );
    _filter = TextEditingController(text: binding?.filter ?? 'HK|Hong Kong');
    _profileIds = binding?.sourceIds.toList() ?? [widget.profiles.first.id];
    _selection = binding?.selection ?? PortSelection.original;
    _node = binding?.node ?? '';
    unawaited(_loadNodes());
  }

  int _nextPort() {
    final ports = ref
        .read(portRoutingSettingProvider)
        .bindings
        .map((item) => item.port)
        .toSet();
    var port = 18082;
    while (ports.contains(port)) {
      port++;
    }
    return port;
  }

  Future<void> _loadNodes() async {
    final load = ++_load;
    setState(() {
      _nodes = null;
      _sourceNodes = {};
      _previewTimer?.cancel();
      _previewRevision++;
      _preview = (count: 0, sample: []);
      _error = null;
    });
    try {
      final sources = <int, List<String>>{};
      for (final id in List<int>.of(_profileIds)) {
        sources[id] = await ref
            .read(portRoutingActionProvider.notifier)
            .nodeNames(id);
      }
      if (!mounted || load != _load) return;
      setState(() {
        _sourceNodes = sources;
        _nodes = sources.values.expand((nodes) => nodes).toList();
      });
      _schedulePreview();
    } catch (error) {
      if (mounted && load == _load) {
        setState(
          () => _error = _portRoutingError(context.appLocalizations, error),
        );
      }
    }
  }

  PortBinding _value() => PortBinding(
    id: _id,
    name: _name.text.trim(),
    profileId: _profileIds.first,
    additionalProfileIds: _profileIds.skip(1).toList(),
    port: int.tryParse(_port.text) ?? 0,
    enabled: widget.binding?.enabled ?? true,
    selection: _selection,
    node: _node,
    filter: _filter.text.trim(),
  );

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final value = _value();
      validatePortBindings([
        ...ref
            .read(portRoutingSettingProvider)
            .bindings
            .where((item) => item.id != value.id),
        value,
      ]);
      if (_nodes == null) {
        throw const PortRoutingException(PortRoutingIssue.missingSubscription);
      }
      await ref.read(portRoutingActionProvider.notifier).saveBinding(value);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      commonPrint.log(
        'port binding save failed: id=$_id strategy=${_selection.name} sources=${_profileIds.length} error=${error is PortRoutingException ? error.issue.name : error.runtimeType}',
        logLevel: LogLevel.warning,
      );
      if (mounted) {
        setState(
          () => _error = _portRoutingError(context.appLocalizations, error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseSources() async {
    final selected = _profileIds.toSet();
    final result = await showFormSheet<List<int>>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) => FormPage(
          title: context.appLocalizations.profiles,
          onSave: () {
            if (selected.isNotEmpty) {
              Navigator.of(sheetContext).pop(selected.toList());
            }
          },
          children: [
            generateSection(
              items: [
                for (final profile in widget.profiles)
                  ListItem(
                    title: Text(profile.realLabel),
                    trailing: Checkbox(
                      value: selected.contains(profile.id),
                      onChanged: (value) => update(() {
                        if (value == true) {
                          if (_selection != PortSelection.region) {
                            selected.clear();
                          }
                          selected.add(profile.id);
                        } else if (selected.length > 1) {
                          selected.remove(profile.id);
                        }
                      }),
                    ),
                    onTap: () => update(() {
                      if (_selection != PortSelection.region) selected.clear();
                      if (!selected.add(profile.id) && selected.length > 1) {
                        selected.remove(profile.id);
                      }
                    }),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _profileIds = result;
      _node = '';
    });
    unawaited(_loadNodes());
  }

  Future<void> _chooseNode() async {
    final result = await showFormSheet<String>(
      context: context,
      builder: (sheetContext) => SelectionSheet<String>(
        title: context.appLocalizations.portRoutingFixed,
        sections: [SelectionSection(items: _nodes ?? [])],
        labelBuilder: (node) => node,
        selectedOf: (_) => _node,
        onSelected: (node) => Navigator.of(sheetContext).pop(node),
      ),
    );
    if (result != null && mounted) {
      setState(() => _node = result);
      _schedulePreview();
    }
  }

  void _schedulePreview() {
    _previewTimer?.cancel();
    final revision = ++_previewRevision;
    _previewTimer = Timer(const Duration(milliseconds: 200), () async {
      final preview = await compute(_matchingPreview, (_value(), _sourceNodes));
      if (mounted && revision == _previewRevision) {
        setState(() => _preview = preview);
      }
    });
  }

  String _previewLabel(String sample) {
    for (final profile in widget.profiles) {
      if (sample.startsWith(portNodePrefix(profile.id))) {
        return '${profile.realLabel} · ${sample.substring(portNodePrefix(profile.id).length)}';
      }
    }
    return sample;
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _name.dispose();
    _port.dispose();
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    return PopScope(
      canPop: !_saving,
      child: AbsorbPointer(
        absorbing: _saving,
        child: FormPage(
          title: widget.binding == null ? l.add : l.edit,
          onSave: _save,
          error: _error,
          saving: _saving,
          children: [
            generateSection(
              items: [
                FormRow(
                  title: l.label,
                  trailing: FormRowTextField(
                    controller: _name,
                    hintText: l.required,
                  ),
                ),
                FormRow(
                  title: l.profiles,
                  trailing: Text(
                    widget.profiles
                        .where((p) => _profileIds.contains(p.id))
                        .map((p) => p.realLabel)
                        .join(' · '),
                    textAlign: TextAlign.end,
                  ),
                  onPressed: _saving ? null : _chooseSources,
                ),
                FormRow(
                  title: l.port,
                  trailing: FormRowTextField(
                    controller: _port,
                    keyboardType: TextInputType.number,
                    inputFormatters: TextInputLimits.digitsOnly(
                      TextInputLimits.port,
                    ),
                  ),
                ),
                ListItem<PortSelection>.options(
                  title: Text(l.portRoutingStrategy),
                  value: _selection,
                  options: PortSelection.values,
                  textBuilder: (value) => switch (value) {
                    PortSelection.original => l.portRoutingOriginal,
                    PortSelection.fixed => l.portRoutingFixed,
                    PortSelection.region => l.portRoutingRegion,
                  },
                  onChanged: (value) {
                    if (_saving) return;
                    setState(() {
                      _selection = value;
                      if (value != PortSelection.region) {
                        _profileIds = [_profileIds.first];
                      }
                    });
                    unawaited(_loadNodes());
                  },
                ),
                if (_selection == PortSelection.fixed)
                  FormRow(
                    title: l.portRoutingFixed,
                    trailing: Text(_node.isEmpty ? l.required : _node),
                    onPressed: _nodes == null ? null : _chooseNode,
                  )
                else if (_selection == PortSelection.region)
                  FormRow(
                    title: l.portRoutingRegion,
                    trailing: FormRowTextField(
                      controller: _filter,
                      autocorrect: false,
                      onChanged: (_) => _schedulePreview(),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _selection == PortSelection.original
                    ? l.portRoutingOriginalHint
                    : _selection == PortSelection.region
                    ? l.portRoutingAggregateHint
                    : l.portRoutingFixedHint,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _nodes == null
                    ? l.portRoutingChecking
                    : '${l.portRoutingMatches}: ${_preview.count}\n${_preview.sample.map(_previewLabel).join('\n')}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefreshForm extends StatefulWidget {
  final PortSubscriptionRefresh setting;
  const _RefreshForm({required this.setting});
  @override
  State<_RefreshForm> createState() => _RefreshFormState();
}

class _RefreshFormState extends State<_RefreshForm> {
  late bool _enabled;
  late final TextEditingController _minutes;
  String? _error;
  @override
  void initState() {
    super.initState();
    _enabled = widget.setting.enabled;
    _minutes = TextEditingController(
      text: widget.setting.intervalMinutes.toString(),
    );
  }

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    return FormPage(
      title: l.portRoutingRefreshSettings,
      error: _error,
      onSave: () {
        final minutes = int.tryParse(_minutes.text);
        if (minutes == null || minutes < 1 || minutes > 1440) {
          setState(() => _error = l.portRoutingRefreshRange);
          return;
        }
        Navigator.of(context).pop(
          widget.setting.copyWith(enabled: _enabled, intervalMinutes: minutes),
        );
      },
      children: [
        generateSection(
          items: [
            FormRow(
              title: l.autoUpdate,
              trailing: Switch(
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
            ),
            FormRow(
              title: l.portRoutingMinutes,
              trailing: FormRowTextField(
                controller: _minutes,
                keyboardType: TextInputType.number,
                inputFormatters: TextInputLimits.digitsOnly(
                  TextInputLimits.port,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

({int count, List<String> sample}) _matchingPreview(
  (PortBinding, Map<int, List<String>>) input,
) {
  final matches = [
    for (final entry in input.$2.entries)
      for (final name in matchingPortNodes(input.$1, entry.value))
        '${portNodePrefix(entry.key)}$name',
  ];
  return (count: matches.length, sample: matches.take(12).toList());
}
