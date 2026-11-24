// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../port_routing.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PortBinding _$PortBindingFromJson(Map<String, dynamic> json) => _PortBinding(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  profileId: (json['profileId'] as num).toInt(),
  additionalProfileIds:
      (json['additionalProfileIds'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  port: (json['port'] as num).toInt(),
  enabled: json['enabled'] as bool? ?? true,
  selection:
      $enumDecodeNullable(_$PortSelectionEnumMap, json['selection']) ??
      PortSelection.fixed,
  node: json['node'] as String? ?? '',
  filter: json['filter'] as String? ?? '',
  policies:
      (json['policies'] as List<dynamic>?)
          ?.map((e) => PriorityPolicy.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$PortBindingToJson(_PortBinding instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'profileId': instance.profileId,
      'additionalProfileIds': instance.additionalProfileIds,
      'port': instance.port,
      'enabled': instance.enabled,
      'selection': _$PortSelectionEnumMap[instance.selection]!,
      'node': instance.node,
      'filter': instance.filter,
      'policies': instance.policies,
    };

const _$PortSelectionEnumMap = {
  PortSelection.original: 'original',
  PortSelection.fixed: 'fixed',
  PortSelection.region: 'region',
  PortSelection.aggregate: 'aggregate',
};

_PortSubscriptionRefresh _$PortSubscriptionRefreshFromJson(
  Map<String, dynamic> json,
) => _PortSubscriptionRefresh(
  profileId: (json['profileId'] as num).toInt(),
  enabled: json['enabled'] as bool? ?? true,
  intervalMinutes: (json['intervalMinutes'] as num?)?.toInt() ?? 5,
);

Map<String, dynamic> _$PortSubscriptionRefreshToJson(
  _PortSubscriptionRefresh instance,
) => <String, dynamic>{
  'profileId': instance.profileId,
  'enabled': instance.enabled,
  'intervalMinutes': instance.intervalMinutes,
};

_PortRoutingConfig _$PortRoutingConfigFromJson(Map<String, dynamic> json) =>
    _PortRoutingConfig(
      workspaceProfileId: (json['workspaceProfileId'] as num?)?.toInt(),
      previousProfileId: (json['previousProfileId'] as num?)?.toInt(),
      bindings:
          (json['bindings'] as List<dynamic>?)
              ?.map((e) => PortBinding.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      subscriptions:
          (json['subscriptions'] as List<dynamic>?)
              ?.map(
                (e) =>
                    PortSubscriptionRefresh.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      takeoverSystem: json['takeoverSystem'] as bool? ?? true,
      defaultBindingId: (json['defaultBindingId'] as num?)?.toInt(),
    );

Map<String, dynamic> _$PortRoutingConfigToJson(_PortRoutingConfig instance) =>
    <String, dynamic>{
      'workspaceProfileId': instance.workspaceProfileId,
      'previousProfileId': instance.previousProfileId,
      'bindings': instance.bindings,
      'subscriptions': instance.subscriptions,
      'takeoverSystem': instance.takeoverSystem,
      'defaultBindingId': instance.defaultBindingId,
    };
