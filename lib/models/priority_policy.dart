import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/priority_policy.freezed.dart';
part 'generated/priority_policy.g.dart';

@freezed
abstract class PriorityTier with _$PriorityTier {
  const PriorityTier._();

  const factory PriorityTier({
    @Default('') String target,
    @Default([]) List<int> sourceIds,
    @Default('') String filter,
    @Default('') String exclude,
  }) = _PriorityTier;

  factory PriorityTier.fromJson(Map<String, dynamic> json) =>
      _$PriorityTierFromJson(json);

  bool get isLocal => target.isNotEmpty;
}

@freezed
abstract class PriorityPolicy with _$PriorityPolicy {
  const PriorityPolicy._();

  const factory PriorityPolicy({
    required int profileId,
    required String group,
    @Default([]) List<PriorityTier> tiers,
  }) = _PriorityPolicy;

  factory PriorityPolicy.fromJson(Map<String, dynamic> json) =>
      _$PriorityPolicyFromJson(json);

  Set<int> get sourceIds => tiers.expand((tier) => tier.sourceIds).toSet();
}

@freezed
abstract class PriorityPolicies with _$PriorityPolicies {
  const PriorityPolicies._();

  const factory PriorityPolicies({@Default([]) List<PriorityPolicy> policies}) =
      _PriorityPolicies;

  factory PriorityPolicies.fromJson(Map<String, dynamic> json) =>
      _$PriorityPoliciesFromJson(json);

  List<PriorityPolicy> forProfile(int? id) =>
      policies.where((policy) => policy.profileId == id).toList();

  bool references(int id) => policies.any(
    (policy) => policy.profileId == id || policy.sourceIds.contains(id),
  );

  PriorityPolicies remapProfiles(Map<int, int> ids) => copyWith(
    policies: [
      for (final policy in policies)
        if (ids.containsKey(policy.profileId) &&
            policy.sourceIds.every(ids.containsKey))
          policy.copyWith(
            profileId: ids[policy.profileId]!,
            tiers: [
              for (final tier in policy.tiers)
                tier.copyWith(
                  sourceIds: [for (final id in tier.sourceIds) ids[id]!],
                ),
            ],
          ),
    ],
  );
}
