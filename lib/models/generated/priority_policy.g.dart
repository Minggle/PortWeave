// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../priority_policy.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PriorityTier _$PriorityTierFromJson(Map<String, dynamic> json) =>
    _PriorityTier(
      target: json['target'] as String? ?? '',
      sourceIds:
          (json['sourceIds'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      filter: json['filter'] as String? ?? '',
      exclude: json['exclude'] as String? ?? '',
    );

Map<String, dynamic> _$PriorityTierToJson(_PriorityTier instance) =>
    <String, dynamic>{
      'target': instance.target,
      'sourceIds': instance.sourceIds,
      'filter': instance.filter,
      'exclude': instance.exclude,
    };

_PriorityPolicy _$PriorityPolicyFromJson(Map<String, dynamic> json) =>
    _PriorityPolicy(
      profileId: (json['profileId'] as num).toInt(),
      group: json['group'] as String,
      tiers:
          (json['tiers'] as List<dynamic>?)
              ?.map((e) => PriorityTier.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$PriorityPolicyToJson(_PriorityPolicy instance) =>
    <String, dynamic>{
      'profileId': instance.profileId,
      'group': instance.group,
      'tiers': instance.tiers,
    };

_PriorityPolicies _$PriorityPoliciesFromJson(Map<String, dynamic> json) =>
    _PriorityPolicies(
      policies:
          (json['policies'] as List<dynamic>?)
              ?.map((e) => PriorityPolicy.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$PriorityPoliciesToJson(_PriorityPolicies instance) =>
    <String, dynamic>{'policies': instance.policies};
