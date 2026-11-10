// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../priority_policy.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PriorityTier {

 String get target; List<int> get sourceIds; String get filter; String get exclude;
/// Create a copy of PriorityTier
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PriorityTierCopyWith<PriorityTier> get copyWith => _$PriorityTierCopyWithImpl<PriorityTier>(this as PriorityTier, _$identity);

  /// Serializes this PriorityTier to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PriorityTier;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PriorityTier&&(identical(other.target, _this.target) || other.target == _this.target)&&const DeepCollectionEquality().equals(other.sourceIds, _this.sourceIds)&&(identical(other.filter, _this.filter) || other.filter == _this.filter)&&(identical(other.exclude, _this.exclude) || other.exclude == _this.exclude));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PriorityTier;
  return Object.hash(runtimeType,_this.target,const DeepCollectionEquality().hash(_this.sourceIds),_this.filter,_this.exclude);
}

@override
String toString() {
  final _this = this as PriorityTier;
  return 'PriorityTier(target: ${_this.target}, sourceIds: ${_this.sourceIds}, filter: ${_this.filter}, exclude: ${_this.exclude})';
}


}

/// @nodoc
abstract mixin class $PriorityTierCopyWith<$Res>  {
  factory $PriorityTierCopyWith(PriorityTier value, $Res Function(PriorityTier) _then) = _$PriorityTierCopyWithImpl;
@useResult
$Res call({
 String target, List<int> sourceIds, String filter, String exclude
});




}
/// @nodoc
class _$PriorityTierCopyWithImpl<$Res>
    implements $PriorityTierCopyWith<$Res> {
  _$PriorityTierCopyWithImpl(this._self, this._then);

  final PriorityTier _self;
  final $Res Function(PriorityTier) _then;

/// Create a copy of PriorityTier
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? target = null,Object? sourceIds = null,Object? filter = null,Object? exclude = null,}) {
  return _then(PriorityTier(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,sourceIds: null == sourceIds ? _self.sourceIds : sourceIds // ignore: cast_nullable_to_non_nullable
as List<int>,filter: null == filter ? _self.filter : filter // ignore: cast_nullable_to_non_nullable
as String,exclude: null == exclude ? _self.exclude : exclude // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PriorityTier].
extension PriorityTierPatterns on PriorityTier {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PriorityTier value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PriorityTier() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PriorityTier value)  $default,){
final _that = this;
switch (_that) {
case _PriorityTier():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PriorityTier value)?  $default,){
final _that = this;
switch (_that) {
case _PriorityTier() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String target,  List<int> sourceIds,  String filter,  String exclude)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PriorityTier() when $default != null:
return $default(_that.target,_that.sourceIds,_that.filter,_that.exclude);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String target,  List<int> sourceIds,  String filter,  String exclude)  $default,) {final _that = this;
switch (_that) {
case _PriorityTier():
return $default(_that.target,_that.sourceIds,_that.filter,_that.exclude);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String target,  List<int> sourceIds,  String filter,  String exclude)?  $default,) {final _that = this;
switch (_that) {
case _PriorityTier() when $default != null:
return $default(_that.target,_that.sourceIds,_that.filter,_that.exclude);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PriorityTier extends PriorityTier {
  const _PriorityTier({this.target = '',  List<int> sourceIds = const [], this.filter = '', this.exclude = ''}): _sourceIds = sourceIds,super._();
  factory _PriorityTier.fromJson(Map<String, dynamic> json) => _$PriorityTierFromJson(json);

@override@JsonKey() final  String target;
 final  List<int> _sourceIds;
@override@JsonKey() List<int> get sourceIds {
  if (_sourceIds is EqualUnmodifiableListView) return _sourceIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sourceIds);
}

@override@JsonKey() final  String filter;
@override@JsonKey() final  String exclude;

/// Create a copy of PriorityTier
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PriorityTierCopyWith<_PriorityTier> get copyWith => __$PriorityTierCopyWithImpl<_PriorityTier>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PriorityTierToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PriorityTier&&(identical(other.target, target) || other.target == target)&&const DeepCollectionEquality().equals(other.sourceIds, _sourceIds)&&(identical(other.filter, filter) || other.filter == filter)&&(identical(other.exclude, exclude) || other.exclude == exclude));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,target,const DeepCollectionEquality().hash(_sourceIds),filter,exclude);
}

@override
String toString() {
    return 'PriorityTier(target: $target, sourceIds: $sourceIds, filter: $filter, exclude: $exclude)';
}


}

/// @nodoc
abstract mixin class _$PriorityTierCopyWith<$Res> implements $PriorityTierCopyWith<$Res> {
  factory _$PriorityTierCopyWith(_PriorityTier value, $Res Function(_PriorityTier) _then) = __$PriorityTierCopyWithImpl;
@override @useResult
$Res call({
 String target, List<int> sourceIds, String filter, String exclude
});




}
/// @nodoc
class __$PriorityTierCopyWithImpl<$Res>
    implements _$PriorityTierCopyWith<$Res> {
  __$PriorityTierCopyWithImpl(this._self, this._then);

  final _PriorityTier _self;
  final $Res Function(_PriorityTier) _then;

/// Create a copy of PriorityTier
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? target = null,Object? sourceIds = null,Object? filter = null,Object? exclude = null,}) {
  return _then(_PriorityTier(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,sourceIds: null == sourceIds ? _self._sourceIds : sourceIds // ignore: cast_nullable_to_non_nullable
as List<int>,filter: null == filter ? _self.filter : filter // ignore: cast_nullable_to_non_nullable
as String,exclude: null == exclude ? _self.exclude : exclude // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$PriorityPolicy {

 int get profileId; String get group; List<PriorityTier> get tiers;
/// Create a copy of PriorityPolicy
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PriorityPolicyCopyWith<PriorityPolicy> get copyWith => _$PriorityPolicyCopyWithImpl<PriorityPolicy>(this as PriorityPolicy, _$identity);

  /// Serializes this PriorityPolicy to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PriorityPolicy;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PriorityPolicy&&(identical(other.profileId, _this.profileId) || other.profileId == _this.profileId)&&(identical(other.group, _this.group) || other.group == _this.group)&&const DeepCollectionEquality().equals(other.tiers, _this.tiers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PriorityPolicy;
  return Object.hash(runtimeType,_this.profileId,_this.group,const DeepCollectionEquality().hash(_this.tiers));
}

@override
String toString() {
  final _this = this as PriorityPolicy;
  return 'PriorityPolicy(profileId: ${_this.profileId}, group: ${_this.group}, tiers: ${_this.tiers})';
}


}

/// @nodoc
abstract mixin class $PriorityPolicyCopyWith<$Res>  {
  factory $PriorityPolicyCopyWith(PriorityPolicy value, $Res Function(PriorityPolicy) _then) = _$PriorityPolicyCopyWithImpl;
@useResult
$Res call({
 int profileId, String group, List<PriorityTier> tiers
});




}
/// @nodoc
class _$PriorityPolicyCopyWithImpl<$Res>
    implements $PriorityPolicyCopyWith<$Res> {
  _$PriorityPolicyCopyWithImpl(this._self, this._then);

  final PriorityPolicy _self;
  final $Res Function(PriorityPolicy) _then;

/// Create a copy of PriorityPolicy
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? profileId = null,Object? group = null,Object? tiers = null,}) {
  return _then(PriorityPolicy(
profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,group: null == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String,tiers: null == tiers ? _self.tiers : tiers // ignore: cast_nullable_to_non_nullable
as List<PriorityTier>,
  ));
}

}


/// Adds pattern-matching-related methods to [PriorityPolicy].
extension PriorityPolicyPatterns on PriorityPolicy {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PriorityPolicy value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PriorityPolicy() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PriorityPolicy value)  $default,){
final _that = this;
switch (_that) {
case _PriorityPolicy():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PriorityPolicy value)?  $default,){
final _that = this;
switch (_that) {
case _PriorityPolicy() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int profileId,  String group,  List<PriorityTier> tiers)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PriorityPolicy() when $default != null:
return $default(_that.profileId,_that.group,_that.tiers);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int profileId,  String group,  List<PriorityTier> tiers)  $default,) {final _that = this;
switch (_that) {
case _PriorityPolicy():
return $default(_that.profileId,_that.group,_that.tiers);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int profileId,  String group,  List<PriorityTier> tiers)?  $default,) {final _that = this;
switch (_that) {
case _PriorityPolicy() when $default != null:
return $default(_that.profileId,_that.group,_that.tiers);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PriorityPolicy extends PriorityPolicy {
  const _PriorityPolicy({required this.profileId, required this.group,  List<PriorityTier> tiers = const []}): _tiers = tiers,super._();
  factory _PriorityPolicy.fromJson(Map<String, dynamic> json) => _$PriorityPolicyFromJson(json);

@override final  int profileId;
@override final  String group;
 final  List<PriorityTier> _tiers;
@override@JsonKey() List<PriorityTier> get tiers {
  if (_tiers is EqualUnmodifiableListView) return _tiers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tiers);
}


/// Create a copy of PriorityPolicy
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PriorityPolicyCopyWith<_PriorityPolicy> get copyWith => __$PriorityPolicyCopyWithImpl<_PriorityPolicy>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PriorityPolicyToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PriorityPolicy&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.group, group) || other.group == group)&&const DeepCollectionEquality().equals(other.tiers, _tiers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,profileId,group,const DeepCollectionEquality().hash(_tiers));
}

@override
String toString() {
    return 'PriorityPolicy(profileId: $profileId, group: $group, tiers: $tiers)';
}


}

/// @nodoc
abstract mixin class _$PriorityPolicyCopyWith<$Res> implements $PriorityPolicyCopyWith<$Res> {
  factory _$PriorityPolicyCopyWith(_PriorityPolicy value, $Res Function(_PriorityPolicy) _then) = __$PriorityPolicyCopyWithImpl;
@override @useResult
$Res call({
 int profileId, String group, List<PriorityTier> tiers
});




}
/// @nodoc
class __$PriorityPolicyCopyWithImpl<$Res>
    implements _$PriorityPolicyCopyWith<$Res> {
  __$PriorityPolicyCopyWithImpl(this._self, this._then);

  final _PriorityPolicy _self;
  final $Res Function(_PriorityPolicy) _then;

/// Create a copy of PriorityPolicy
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? profileId = null,Object? group = null,Object? tiers = null,}) {
  return _then(_PriorityPolicy(
profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,group: null == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String,tiers: null == tiers ? _self._tiers : tiers // ignore: cast_nullable_to_non_nullable
as List<PriorityTier>,
  ));
}


}


/// @nodoc
mixin _$PriorityPolicies {

 List<PriorityPolicy> get policies;
/// Create a copy of PriorityPolicies
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PriorityPoliciesCopyWith<PriorityPolicies> get copyWith => _$PriorityPoliciesCopyWithImpl<PriorityPolicies>(this as PriorityPolicies, _$identity);

  /// Serializes this PriorityPolicies to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PriorityPolicies;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PriorityPolicies&&const DeepCollectionEquality().equals(other.policies, _this.policies));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PriorityPolicies;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.policies));
}

@override
String toString() {
  final _this = this as PriorityPolicies;
  return 'PriorityPolicies(policies: ${_this.policies})';
}


}

/// @nodoc
abstract mixin class $PriorityPoliciesCopyWith<$Res>  {
  factory $PriorityPoliciesCopyWith(PriorityPolicies value, $Res Function(PriorityPolicies) _then) = _$PriorityPoliciesCopyWithImpl;
@useResult
$Res call({
 List<PriorityPolicy> policies
});




}
/// @nodoc
class _$PriorityPoliciesCopyWithImpl<$Res>
    implements $PriorityPoliciesCopyWith<$Res> {
  _$PriorityPoliciesCopyWithImpl(this._self, this._then);

  final PriorityPolicies _self;
  final $Res Function(PriorityPolicies) _then;

/// Create a copy of PriorityPolicies
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? policies = null,}) {
  return _then(PriorityPolicies(
policies: null == policies ? _self.policies : policies // ignore: cast_nullable_to_non_nullable
as List<PriorityPolicy>,
  ));
}

}


/// Adds pattern-matching-related methods to [PriorityPolicies].
extension PriorityPoliciesPatterns on PriorityPolicies {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PriorityPolicies value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PriorityPolicies() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PriorityPolicies value)  $default,){
final _that = this;
switch (_that) {
case _PriorityPolicies():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PriorityPolicies value)?  $default,){
final _that = this;
switch (_that) {
case _PriorityPolicies() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<PriorityPolicy> policies)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PriorityPolicies() when $default != null:
return $default(_that.policies);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<PriorityPolicy> policies)  $default,) {final _that = this;
switch (_that) {
case _PriorityPolicies():
return $default(_that.policies);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<PriorityPolicy> policies)?  $default,) {final _that = this;
switch (_that) {
case _PriorityPolicies() when $default != null:
return $default(_that.policies);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PriorityPolicies extends PriorityPolicies {
  const _PriorityPolicies({ List<PriorityPolicy> policies = const []}): _policies = policies,super._();
  factory _PriorityPolicies.fromJson(Map<String, dynamic> json) => _$PriorityPoliciesFromJson(json);

 final  List<PriorityPolicy> _policies;
@override@JsonKey() List<PriorityPolicy> get policies {
  if (_policies is EqualUnmodifiableListView) return _policies;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_policies);
}


/// Create a copy of PriorityPolicies
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PriorityPoliciesCopyWith<_PriorityPolicies> get copyWith => __$PriorityPoliciesCopyWithImpl<_PriorityPolicies>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PriorityPoliciesToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PriorityPolicies&&const DeepCollectionEquality().equals(other.policies, _policies));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_policies));
}

@override
String toString() {
    return 'PriorityPolicies(policies: $policies)';
}


}

/// @nodoc
abstract mixin class _$PriorityPoliciesCopyWith<$Res> implements $PriorityPoliciesCopyWith<$Res> {
  factory _$PriorityPoliciesCopyWith(_PriorityPolicies value, $Res Function(_PriorityPolicies) _then) = __$PriorityPoliciesCopyWithImpl;
@override @useResult
$Res call({
 List<PriorityPolicy> policies
});




}
/// @nodoc
class __$PriorityPoliciesCopyWithImpl<$Res>
    implements _$PriorityPoliciesCopyWith<$Res> {
  __$PriorityPoliciesCopyWithImpl(this._self, this._then);

  final _PriorityPolicies _self;
  final $Res Function(_PriorityPolicies) _then;

/// Create a copy of PriorityPolicies
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? policies = null,}) {
  return _then(_PriorityPolicies(
policies: null == policies ? _self._policies : policies // ignore: cast_nullable_to_non_nullable
as List<PriorityPolicy>,
  ));
}


}

// dart format on
