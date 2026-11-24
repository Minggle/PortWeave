import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/port_display.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/layout.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/views/proxies/proxies.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/shapes/shapes.dart';

import 'card.dart';
import 'connections_table.dart';

const _stackedIcons = 4;

/// The inset of a block's corner, so the icon tile inside it is concentric.
const _blockInset = 10.0;

/// The proxies page stays mounted under the dashboard and filters by the same
/// query, so the sheet searches on its own and hands the page's query back.
Future<void> showProxiesSheet(
  BuildContext context, {
  String? groupName,
  int? portBindingId,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  if (groupName != null) {
    container
        .read(proxiesActionProvider.notifier)
        .updateCurrentGroupName(groupName);
  }
  final query = queryProvider(QueryTag.proxies);
  final pageQuery = container.read(query);
  container.read(query.notifier).value = '';
  await showNestedSheet<void>(
    context,
    builder: (_) => ProxiesView(picker: true, portBindingId: portBindingId),
  );
  container.read(query.notifier).value = pageQuery;
}

typedef _DashboardPortScope = ({
  List<Group> groups,
  PortBinding? viewedBinding,
  List<PortBinding> enabledBindings,
  PortBinding? defaultBinding,
  Map<int, PortBinding> bindingsById,
});

_DashboardPortScope _watchDashboardPortScope(WidgetRef ref) {
  final active = ref.watch(portRoutingActiveProvider);
  if (!active) {
    return (
      groups: ref.watch(visibleGroupsStateProvider).value,
      viewedBinding: null,
      enabledBindings: const [],
      defaultBinding: null,
      bindingsById: const {},
    );
  }
  final bindings = ref.watch(
    portRoutingSettingProvider.select((state) => state.bindings),
  );
  final enabledBindings = [
    for (final binding in bindings)
      if (binding.enabled) binding,
  ];
  final bindingsById = {for (final binding in bindings) binding.id: binding};
  final defaultBinding = ref.watch(portRoutingDefaultBindingProvider);
  final selectedId = ref.watch(dashboardPortBindingProvider);
  final viewedBinding =
      (selectedId != null
          ? enabledBindings.where((b) => b.id == selectedId).firstOrNull
          : null) ??
      defaultBinding ??
      enabledBindings.firstOrNull;
  final List<Group> groups;
  if (viewedBinding == null) {
    groups = ref.watch(visibleGroupsStateProvider).value;
  } else if (viewedBinding.usesRules) {
    groups = ref
        .watch(visibleGroupsStateProvider)
        .value
        .where((group) => group.name.startsWith(viewedBinding.policyPrefix))
        .toList();
  } else {
    final allGroups = ref.watch(groupsProvider);
    groups = [
      for (final group in allGroups)
        if (group.name == viewedBinding.groupName) group,
    ];
  }
  return (
    groups: groups,
    viewedBinding: viewedBinding,
    enabledBindings: enabledBindings,
    defaultBinding: defaultBinding,
    bindingsById: bindingsById,
  );
}

String _displayGroupName(
  Group group, {
  PortBinding? viewedBinding,
  Set<int> validBindingIds = const {},
  Set<int> validProfileIds = const {},
}) {
  if (viewedBinding != null && group.name == viewedBinding.groupName) {
    return viewedBinding.name;
  }
  return displayPortName(
    group.name,
    validBindingIds: validBindingIds,
    validProfileIds: validProfileIds,
  );
}

/// Drawn in the proportions of the proxies page's group header, always
/// filled: the icon style chosen there is that page's own, and the dashboard
/// would look bare without icons.
class _GroupIcon extends StatelessWidget {
  const _GroupIcon({
    required this.group,
    required this.displayName,
    required this.size,
    required this.radius,
    this.ring,
  });

  final Group group;
  final String displayName;
  final double size;
  final double radius;
  final Color? ring;

  static const _inset = 0.15;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final ring = this.ring;
    final inset = size * _inset;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(inset),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: DashboardColors.of(context).tone2,
        shape: AppShape.all(radius).copyWith(
          side: ring == null
              ? BorderSide.none
              : BorderSide(
                  color: ring,
                  width: 3,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
        ),
      ),
      child: Center(
        child: IconTheme.merge(
          data: IconThemeData(
            size: size - inset * 2,
            color: colorScheme.onSurfaceVariant,
          ),
          child: CommonTargetIcon(
            src: group.icon,
            fallback: GroupMonogram(displayName),
          ),
        ),
      ),
    );
  }
}

class _SelectedName extends ConsumerWidget {
  const _SelectedName({required this.group, required this.bindingsById});

  final Group group;
  final Map<int, PortBinding> bindingsById;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rawSelected = ref.watch(selectedProxyNameProvider(group.name)) ?? '';
    if (rawSelected.isEmpty) {
      return EmojiText(
        '—',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: DashboardText.label(context),
      );
    }
    final profileLabels = ref.watch(
      profilesProvider.select(
        (profiles) => {for (final p in profiles) p.id: p.realLabel},
      ),
    );
    final groupsByName = ref.watch(
      groupsProvider.select((groups) => {for (final g in groups) g.name: g}),
    );
    final resolved = resolveDisplaySelected(
      rawSelected,
      groupsByName: groupsByName,
      profileLabels: profileLabels,
      bindingsById: bindingsById,
    );
    final text = formatDisplayWithSource(resolved.name, resolved.source);
    return EmojiText(
      text.isEmpty ? '—' : text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: DashboardText.label(context),
    );
  }
}

class _TimeoutChip extends ConsumerWidget {
  const _TimeoutChip({required this.groups});

  final List<Group> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var timedOut = 0;
    for (final group in groups) {
      final delay = ref.watch(
        delayProvider(proxyName: group.name, testUrl: group.testUrl),
      );
      if (delay != null && delay < 0) {
        timedOut++;
      }
    }
    if (timedOut == 0) {
      return const SizedBox.shrink();
    }
    return DashboardChip(
      label: context.appLocalizations.groupTimeoutCount(timedOut),
      tone: DashboardChipTone.warn,
    );
  }
}

(String, String?) _emptyTextsOf(
  BuildContext context, {
  required bool connected,
}) {
  final appLocalizations = context.appLocalizations;
  return connected
      ? (appLocalizations.nullTip(appLocalizations.proxyGroup), null)
      : (
          appLocalizations.memoryCoreNotRunning,
          appLocalizations.proxyGroupsAfterStart,
        );
}

class _GroupsEmpty extends ConsumerWidget {
  const _GroupsEmpty({this.fit = false});

  /// Scales down into whatever height the card has left.
  final bool fit;

  static const _maxWidth = 260.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    final (title, subtitle) = _emptyTextsOf(
      context,
      connected: ref.watch(coreStatusProvider) == CoreStatus.connected,
    );
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          ShapeBadge(
            shape: MaterialShapes.cookie9Sided,
            color: DashboardColors.of(context).tone,
            size: 64,
            child: GlyphIcon(
              AppGlyphs.nodeGroup,
              size: 26,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyle.subheadline.of(context, emphasized: true),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: fit ? FittedBox(fit: BoxFit.scaleDown, child: content) : content,
      ),
    );
  }
}

class ProxyGroupsCard extends ConsumerWidget {
  const ProxyGroupsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final density = DashboardDensityScope.of(context);
    if (!density.isDesktop) {
      return const ProxyGroupsSummaryCard();
    }
    final compact = density.isCompact;
    final scale = DashboardDensityScope.scaleOf(context);
    final scope = _watchDashboardPortScope(ref);
    final groups = scope.groups;
    final profileIds = ref.watch(
      profilesProvider.select((profiles) => {for (final p in profiles) p.id}),
    );
    final padding = dashboardCardPadding(density);
    final tileHeight = (compact ? 52 : 60) * scale;
    final tileGap = compact ? 6.0 : 8.0;
    return DashboardCard(
      semanticLabel: context.appLocalizations.proxyGroup,
      padding: padding.copyWith(bottom: 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tiles = _GroupTiles(
            groups: groups,
            viewedBinding: scope.viewedBinding,
            bindingsById: scope.bindingsById,
            validProfileIds: profileIds,
            columns: _GroupTiles.columnsFor(
              constraints.maxWidth,
              scale: scale,
              gap: tileGap,
            ),
            height: tileHeight,
            gap: tileGap,
            iconSize: tileHeight - _blockInset * 2,
            bottom: padding.bottom,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GroupsHeader(
                groups: groups,
                count: true,
                viewedBinding: scope.viewedBinding,
                enabledBindings: scope.enabledBindings,
                defaultBindingId: scope.defaultBinding?.id,
              ),
              if (groups.isEmpty)
                const Expanded(child: _GroupsEmpty(fit: true))
              else ...[
                SizedBox(
                  height:
                      connectionsTableTop(density, scale) -
                      padding.top -
                      DashboardCardHeader.height * scale,
                ),
                Expanded(child: tiles),
              ],
            ],
          );
        },
      ),
    );
  }
}

typedef _FigureMetrics = ({AppTextStyle style, double icon});

_FigureMetrics _figureMetricsOf(DashboardDensity density) => density.isCompact
    ? (style: AppTextStyle.largeTitle, icon: 34)
    : (style: AppTextStyle.display, icon: 40);

class _PortSwitcherButton extends ConsumerWidget {
  const _PortSwitcherButton({
    required this.viewedBinding,
    required this.enabledBindings,
    required this.defaultBindingId,
  });

  final PortBinding viewedBinding;
  final List<PortBinding> enabledBindings;
  final int? defaultBindingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final colors = DashboardColors.of(context);
    final foreground = context.colorScheme.onSurfaceVariant;
    return PopupAnchor(
      targetBuilder: (open) => Tooltip(
        message: l.portRoutingSwitcherTooltip,
        child: PressSurface(
          fill: colors.tone,
          shape: AppShape.full,
          onPressed: open,
          child: SizedBox(
            height: 24,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 96),
                    child: EmojiText(
                      viewedBinding.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.caption1
                          .of(context, emphasized: true)
                          .copyWith(color: foreground),
                    ),
                  ),
                  GlyphIcon(AppGlyphs.chevronDown, size: 12, color: foreground),
                ],
              ),
            ),
          ),
        ),
      ),
      popupBuilder: (_) => PopupMenu(
        items: [
          for (final binding in enabledBindings)
            PopupMenuItem(
              label: '${binding.name} · :${binding.port}',
              subtitle: binding.id == defaultBindingId
                  ? l.portRoutingPrimaryTag
                  : null,
              checked: binding.id == viewedBinding.id,
              onPressed: () => ref
                  .read(dashboardPortBindingProvider.notifier)
                  .select(binding.id),
            ),
        ],
      ),
    );
  }
}

class _GroupsHeader extends StatelessWidget {
  const _GroupsHeader({
    required this.groups,
    this.count = false,
    this.viewedBinding,
    this.enabledBindings = const [],
    this.defaultBindingId,
  });

  final List<Group> groups;
  final bool count;
  final PortBinding? viewedBinding;
  final List<PortBinding> enabledBindings;
  final int? defaultBindingId;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final mobile = !DashboardDensityScope.of(context).isDesktop;
    final showSwitcher = viewedBinding != null && enabledBindings.isNotEmpty;
    return DashboardCardHeader(
      glyph: AppGlyphs.nodeGroup,
      title: appLocalizations.proxyGroup,
      chevron: mobile && groups.isNotEmpty,
      leading: [
        if (count && groups.isNotEmpty)
          Tooltip(
            message: appLocalizations.groupCount(groups.length),
            child: DashboardChip(label: '${groups.length}'),
          ),
        _TimeoutChip(groups: groups),
      ],
      trailing: [
        if (showSwitcher)
          _PortSwitcherButton(
            viewedBinding: viewedBinding!,
            enabledBindings: enabledBindings,
            defaultBindingId: defaultBindingId,
          ),
        if (!mobile)
          Transform.translate(
            offset: const Offset(8, 0),
            child: DashboardIconButton(
              glyph: AppGlyphs.chevronForward,
              tooltip: appLocalizations.proxyGroup,
              onPressed: groups.isEmpty
                  ? null
                  : () => showProxiesSheet(
                      context,
                      portBindingId: viewedBinding?.id,
                    ),
            ),
          ),
      ],
    );
  }
}

class _GroupsFigure extends StatelessWidget {
  const _GroupsFigure({
    required this.groups,
    required this.metrics,
    required this.viewedBinding,
    required this.validBindingIds,
    required this.validProfileIds,
  });

  final List<Group> groups;
  final _FigureMetrics metrics;
  final PortBinding? viewedBinding;
  final Set<int> validBindingIds;
  final Set<int> validProfileIds;

  @override
  Widget build(BuildContext context) {
    final count = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${groups.length}',
            style: DashboardText.figure(context, metrics.style),
          ),
          TextSpan(
            text: ' ${context.appLocalizations.groupCountUnit}',
            style: DashboardText.unit(context),
          ),
        ],
      ),
      maxLines: 1,
    );
    return DashboardCappedRow(
      start: count,
      end: _IconStack(
        groups: groups,
        viewedBinding: viewedBinding,
        validBindingIds: validBindingIds,
        validProfileIds: validProfileIds,
        size: metrics.icon,
        ring: DashboardColors.of(context).card,
      ),
    );
  }
}

class _IconStack extends StatelessWidget {
  const _IconStack({
    required this.groups,
    required this.viewedBinding,
    required this.validBindingIds,
    required this.validProfileIds,
    required this.size,
    required this.ring,
  });

  final List<Group> groups;
  final PortBinding? viewedBinding;
  final Set<int> validBindingIds;
  final Set<int> validProfileIds;
  final double size;
  final Color ring;

  static const _overlap = 8.0;

  @override
  Widget build(BuildContext context) {
    final shown = groups.take(_stackedIcons).toList();
    final rest = groups.length - shown.length;
    final count = shown.length + (rest > 0 ? 1 : 0);
    return SizedBox(
      width: count * size - (count - 1) * _overlap,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final (index, group) in shown.indexed)
            PositionedDirectional(
              start: index * (size - _overlap),
              child: _GroupIcon(
                group: group,
                displayName: _displayGroupName(
                  group,
                  viewedBinding: viewedBinding,
                  validBindingIds: validBindingIds,
                  validProfileIds: validProfileIds,
                ),
                size: size,
                radius: DashboardCorner.badge,
                ring: ring,
              ),
            ),
          if (rest > 0)
            PositionedDirectional(
              start: shown.length * (size - _overlap),
              child: Container(
                width: size,
                height: size,
                decoration: ShapeDecoration(
                  color: DashboardColors.of(context).tone,
                  shape: AppShape.all(DashboardCorner.badge).copyWith(
                    side: BorderSide(
                      color: ring,
                      width: 3,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    '+$rest',
                    style: AppTextStyle.caption1
                        .of(context, emphasized: true)
                        .toTabular
                        .copyWith(color: context.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupTiles extends StatelessWidget {
  const _GroupTiles({
    required this.groups,
    required this.viewedBinding,
    required this.bindingsById,
    required this.validProfileIds,
    required this.columns,
    required this.height,
    required this.gap,
    required this.iconSize,
    required this.bottom,
  });

  final List<Group> groups;
  final PortBinding? viewedBinding;
  final Map<int, PortBinding> bindingsById;
  final Set<int> validProfileIds;
  final int columns;
  final double height;
  final double gap;
  final double iconSize;
  final double bottom;

  static const _minTileWidth = 172.0;

  static int columnsFor(
    double width, {
    required double scale,
    required double gap,
  }) => width >= _minTileWidth * scale * 2 + gap ? 2 : 1;

  @override
  Widget build(BuildContext context) {
    final validBindingIds = bindingsById.keys.toSet();
    return LayoutBuilder(
      builder: (context, constraints) {
        final rows = (groups.length / columns).ceil();
        final overflows =
            rows * height + (rows - 1) * gap + bottom > constraints.maxHeight;
        final grid = GridView.builder(
          padding: EdgeInsets.only(bottom: bottom),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            mainAxisExtent: height,
          ),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            final displayName = _displayGroupName(
              group,
              viewedBinding: viewedBinding,
              validBindingIds: validBindingIds,
              validProfileIds: validProfileIds,
            );
            return _GroupTile(
              group: group,
              displayName: displayName,
              bindingsById: bindingsById,
              iconSize: iconSize,
              onTap: () => showProxiesSheet(
                context,
                groupName: group.name,
                portBindingId: viewedBinding?.id,
              ),
            );
          },
        );
        return overflows ? DashboardFadeOut(child: grid) : grid;
      },
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.group,
    required this.displayName,
    required this.bindingsById,
    required this.iconSize,
    required this.onTap,
  });

  final Group group;
  final String displayName;
  final Map<int, PortBinding> bindingsById;
  final double iconSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DashboardBlock(
      radius: DashboardCorner.block,
      padding: const EdgeInsetsDirectional.fromSTEB(_blockInset, 0, 14, 0),
      onTap: onTap,
      semanticLabel: displayName,
      child: Row(
        spacing: 12,
        children: [
          _GroupIcon(
            group: group,
            displayName: displayName,
            size: iconSize,
            radius: DashboardCorner.block - _blockInset,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EmojiText(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DashboardText.rowTitle(context),
                ),
                _SelectedName(group: group, bindingsById: bindingsById),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The group count, for the phone and a desktop page too short for tiles.
class ProxyGroupsSummaryCard extends ConsumerWidget {
  const ProxyGroupsSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final scope = _watchDashboardPortScope(ref);
    final groups = scope.groups;
    final profileIds = ref.watch(
      profilesProvider.select((profiles) => {for (final p in profiles) p.id}),
    );
    final density = DashboardDensityScope.of(context);
    final figure = _GroupsFigure(
      groups: groups,
      metrics: _figureMetricsOf(density),
      viewedBinding: scope.viewedBinding,
      validBindingIds: scope.bindingsById.keys.toSet(),
      validProfileIds: profileIds,
    );
    final header = _GroupsHeader(
      groups: groups,
      viewedBinding: scope.viewedBinding,
      enabledBindings: scope.enabledBindings,
      defaultBindingId: scope.defaultBinding?.id,
    );
    if (density.isDesktop) {
      return DashboardCard(
        semanticLabel: appLocalizations.proxyGroup,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const Spacer(),
            if (groups.isEmpty) const _GroupsEmptySummary() else figure,
            const Spacer(),
          ],
        ),
      );
    }
    return DashboardCard(
      semanticLabel: appLocalizations.proxyGroup,
      onTap: groups.isEmpty
          ? null
          : () => showProxiesSheet(
              context,
              portBindingId: scope.viewedBinding?.id,
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 12),
          if (groups.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: _GroupsEmpty(),
            )
          else
            figure,
        ],
      ),
    );
  }
}

/// The empty state of the desktop summary, whose fixed height leaves no room
/// for the illustration.
class _GroupsEmptySummary extends ConsumerWidget {
  const _GroupsEmptySummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (title, subtitle) = _emptyTextsOf(
      context,
      connected: ref.watch(coreStatusProvider) == CoreStatus.connected,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DashboardText.rowTitle(context),
        ),
        if (subtitle != null)
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DashboardText.label(context),
          ),
      ],
    );
  }
}
