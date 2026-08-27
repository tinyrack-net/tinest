// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

// @dart=3.12
part of 'rpc_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HelloParamsDto {

 String get clientId; String get clientKind; int get protocolMajor; Map<String, bool> get capabilities; int get protocolRevision; String get clientVersion;
/// Create a copy of HelloParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HelloParamsDtoCopyWith<HelloParamsDto> get copyWith => _$HelloParamsDtoCopyWithImpl<HelloParamsDto>(this as HelloParamsDto, _$identity);

  /// Serializes this HelloParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HelloParamsDto&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.clientKind, clientKind) || other.clientKind == clientKind)&&(identical(other.protocolMajor, protocolMajor) || other.protocolMajor == protocolMajor)&&const DeepCollectionEquality().equals(other.capabilities, capabilities)&&(identical(other.protocolRevision, protocolRevision) || other.protocolRevision == protocolRevision)&&(identical(other.clientVersion, clientVersion) || other.clientVersion == clientVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,clientId,clientKind,protocolMajor,const DeepCollectionEquality().hash(capabilities),protocolRevision,clientVersion);

@override
String toString() {
  return 'HelloParamsDto(clientId: $clientId, clientKind: $clientKind, protocolMajor: $protocolMajor, capabilities: $capabilities, protocolRevision: $protocolRevision, clientVersion: $clientVersion)';
}


}

/// @nodoc
abstract mixin class $HelloParamsDtoCopyWith<$Res>  {
  factory $HelloParamsDtoCopyWith(HelloParamsDto value, $Res Function(HelloParamsDto) _then) = _$HelloParamsDtoCopyWithImpl;
@useResult
$Res call({
 String clientId, String clientKind, int protocolMajor, Map<String, bool> capabilities, int protocolRevision, String clientVersion
});




}
/// @nodoc
class _$HelloParamsDtoCopyWithImpl<$Res>
    implements $HelloParamsDtoCopyWith<$Res> {
  _$HelloParamsDtoCopyWithImpl(this._self, this._then);

  final HelloParamsDto _self;
  final $Res Function(HelloParamsDto) _then;

/// Create a copy of HelloParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? clientId = null,Object? clientKind = null,Object? protocolMajor = null,Object? capabilities = null,Object? protocolRevision = null,Object? clientVersion = null,}) {
  return _then(HelloParamsDto(
clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,clientKind: null == clientKind ? _self.clientKind : clientKind // ignore: cast_nullable_to_non_nullable
as String,protocolMajor: null == protocolMajor ? _self.protocolMajor : protocolMajor // ignore: cast_nullable_to_non_nullable
as int,capabilities: null == capabilities ? _self.capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,protocolRevision: null == protocolRevision ? _self.protocolRevision : protocolRevision // ignore: cast_nullable_to_non_nullable
as int,clientVersion: null == clientVersion ? _self.clientVersion : clientVersion // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [HelloParamsDto].
extension HelloParamsDtoPatterns on HelloParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HelloParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HelloParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HelloParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _HelloParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HelloParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _HelloParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String clientId,  String clientKind,  int protocolMajor,  Map<String, bool> capabilities,  int protocolRevision,  String clientVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HelloParamsDto() when $default != null:
return $default(_that.clientId,_that.clientKind,_that.protocolMajor,_that.capabilities,_that.protocolRevision,_that.clientVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String clientId,  String clientKind,  int protocolMajor,  Map<String, bool> capabilities,  int protocolRevision,  String clientVersion)  $default,) {final _that = this;
switch (_that) {
case _HelloParamsDto():
return $default(_that.clientId,_that.clientKind,_that.protocolMajor,_that.capabilities,_that.protocolRevision,_that.clientVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String clientId,  String clientKind,  int protocolMajor,  Map<String, bool> capabilities,  int protocolRevision,  String clientVersion)?  $default,) {final _that = this;
switch (_that) {
case _HelloParamsDto() when $default != null:
return $default(_that.clientId,_that.clientKind,_that.protocolMajor,_that.capabilities,_that.protocolRevision,_that.clientVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HelloParamsDto implements HelloParamsDto {
  const _HelloParamsDto({required this.clientId, required this.clientKind, required this.protocolMajor, required  Map<String, bool> capabilities, this.protocolRevision = tinestProtocolRevision, this.clientVersion = 'unknown'}): _capabilities = capabilities;
  factory _HelloParamsDto.fromJson(Map<String, dynamic> json) => _$HelloParamsDtoFromJson(json);

@override final  String clientId;
@override final  String clientKind;
@override final  int protocolMajor;
 final  Map<String, bool> _capabilities;
@override Map<String, bool> get capabilities {
  if (_capabilities is EqualUnmodifiableMapView) return _capabilities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_capabilities);
}

@override@JsonKey() final  int protocolRevision;
@override@JsonKey() final  String clientVersion;

/// Create a copy of HelloParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HelloParamsDtoCopyWith<_HelloParamsDto> get copyWith => __$HelloParamsDtoCopyWithImpl<_HelloParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HelloParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HelloParamsDto&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.clientKind, clientKind) || other.clientKind == clientKind)&&(identical(other.protocolMajor, protocolMajor) || other.protocolMajor == protocolMajor)&&const DeepCollectionEquality().equals(other._capabilities, _capabilities)&&(identical(other.protocolRevision, protocolRevision) || other.protocolRevision == protocolRevision)&&(identical(other.clientVersion, clientVersion) || other.clientVersion == clientVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,clientId,clientKind,protocolMajor,const DeepCollectionEquality().hash(_capabilities),protocolRevision,clientVersion);

@override
String toString() {
  return 'HelloParamsDto(clientId: $clientId, clientKind: $clientKind, protocolMajor: $protocolMajor, capabilities: $capabilities, protocolRevision: $protocolRevision, clientVersion: $clientVersion)';
}


}

/// @nodoc
abstract mixin class _$HelloParamsDtoCopyWith<$Res> implements $HelloParamsDtoCopyWith<$Res> {
  factory _$HelloParamsDtoCopyWith(_HelloParamsDto value, $Res Function(_HelloParamsDto) _then) = __$HelloParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String clientId, String clientKind, int protocolMajor, Map<String, bool> capabilities, int protocolRevision, String clientVersion
});




}
/// @nodoc
class __$HelloParamsDtoCopyWithImpl<$Res>
    implements _$HelloParamsDtoCopyWith<$Res> {
  __$HelloParamsDtoCopyWithImpl(this._self, this._then);

  final _HelloParamsDto _self;
  final $Res Function(_HelloParamsDto) _then;

/// Create a copy of HelloParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? clientId = null,Object? clientKind = null,Object? protocolMajor = null,Object? capabilities = null,Object? protocolRevision = null,Object? clientVersion = null,}) {
  return _then(_HelloParamsDto(
clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,clientKind: null == clientKind ? _self.clientKind : clientKind // ignore: cast_nullable_to_non_nullable
as String,protocolMajor: null == protocolMajor ? _self.protocolMajor : protocolMajor // ignore: cast_nullable_to_non_nullable
as int,capabilities: null == capabilities ? _self._capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,protocolRevision: null == protocolRevision ? _self.protocolRevision : protocolRevision // ignore: cast_nullable_to_non_nullable
as int,clientVersion: null == clientVersion ? _self.clientVersion : clientVersion // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$WorkspaceRegisterParamsDto {

 String get workspaceId; String get checkoutId; String get rootPath; String get name;
/// Create a copy of WorkspaceRegisterParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceRegisterParamsDtoCopyWith<WorkspaceRegisterParamsDto> get copyWith => _$WorkspaceRegisterParamsDtoCopyWithImpl<WorkspaceRegisterParamsDto>(this as WorkspaceRegisterParamsDto, _$identity);

  /// Serializes this WorkspaceRegisterParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkspaceRegisterParamsDto&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.checkoutId, checkoutId) || other.checkoutId == checkoutId)&&(identical(other.rootPath, rootPath) || other.rootPath == rootPath)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,workspaceId,checkoutId,rootPath,name);

@override
String toString() {
  return 'WorkspaceRegisterParamsDto(workspaceId: $workspaceId, checkoutId: $checkoutId, rootPath: $rootPath, name: $name)';
}


}

/// @nodoc
abstract mixin class $WorkspaceRegisterParamsDtoCopyWith<$Res>  {
  factory $WorkspaceRegisterParamsDtoCopyWith(WorkspaceRegisterParamsDto value, $Res Function(WorkspaceRegisterParamsDto) _then) = _$WorkspaceRegisterParamsDtoCopyWithImpl;
@useResult
$Res call({
 String workspaceId, String checkoutId, String rootPath, String name
});




}
/// @nodoc
class _$WorkspaceRegisterParamsDtoCopyWithImpl<$Res>
    implements $WorkspaceRegisterParamsDtoCopyWith<$Res> {
  _$WorkspaceRegisterParamsDtoCopyWithImpl(this._self, this._then);

  final WorkspaceRegisterParamsDto _self;
  final $Res Function(WorkspaceRegisterParamsDto) _then;

/// Create a copy of WorkspaceRegisterParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? workspaceId = null,Object? checkoutId = null,Object? rootPath = null,Object? name = null,}) {
  return _then(WorkspaceRegisterParamsDto(
workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,checkoutId: null == checkoutId ? _self.checkoutId : checkoutId // ignore: cast_nullable_to_non_nullable
as String,rootPath: null == rootPath ? _self.rootPath : rootPath // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkspaceRegisterParamsDto].
extension WorkspaceRegisterParamsDtoPatterns on WorkspaceRegisterParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkspaceRegisterParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkspaceRegisterParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkspaceRegisterParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _WorkspaceRegisterParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkspaceRegisterParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _WorkspaceRegisterParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String workspaceId,  String checkoutId,  String rootPath,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkspaceRegisterParamsDto() when $default != null:
return $default(_that.workspaceId,_that.checkoutId,_that.rootPath,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String workspaceId,  String checkoutId,  String rootPath,  String name)  $default,) {final _that = this;
switch (_that) {
case _WorkspaceRegisterParamsDto():
return $default(_that.workspaceId,_that.checkoutId,_that.rootPath,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String workspaceId,  String checkoutId,  String rootPath,  String name)?  $default,) {final _that = this;
switch (_that) {
case _WorkspaceRegisterParamsDto() when $default != null:
return $default(_that.workspaceId,_that.checkoutId,_that.rootPath,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorkspaceRegisterParamsDto implements WorkspaceRegisterParamsDto {
  const _WorkspaceRegisterParamsDto({required this.workspaceId, required this.checkoutId, required this.rootPath, required this.name});
  factory _WorkspaceRegisterParamsDto.fromJson(Map<String, dynamic> json) => _$WorkspaceRegisterParamsDtoFromJson(json);

@override final  String workspaceId;
@override final  String checkoutId;
@override final  String rootPath;
@override final  String name;

/// Create a copy of WorkspaceRegisterParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceRegisterParamsDtoCopyWith<_WorkspaceRegisterParamsDto> get copyWith => __$WorkspaceRegisterParamsDtoCopyWithImpl<_WorkspaceRegisterParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkspaceRegisterParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkspaceRegisterParamsDto&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.checkoutId, checkoutId) || other.checkoutId == checkoutId)&&(identical(other.rootPath, rootPath) || other.rootPath == rootPath)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,workspaceId,checkoutId,rootPath,name);

@override
String toString() {
  return 'WorkspaceRegisterParamsDto(workspaceId: $workspaceId, checkoutId: $checkoutId, rootPath: $rootPath, name: $name)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceRegisterParamsDtoCopyWith<$Res> implements $WorkspaceRegisterParamsDtoCopyWith<$Res> {
  factory _$WorkspaceRegisterParamsDtoCopyWith(_WorkspaceRegisterParamsDto value, $Res Function(_WorkspaceRegisterParamsDto) _then) = __$WorkspaceRegisterParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String workspaceId, String checkoutId, String rootPath, String name
});




}
/// @nodoc
class __$WorkspaceRegisterParamsDtoCopyWithImpl<$Res>
    implements _$WorkspaceRegisterParamsDtoCopyWith<$Res> {
  __$WorkspaceRegisterParamsDtoCopyWithImpl(this._self, this._then);

  final _WorkspaceRegisterParamsDto _self;
  final $Res Function(_WorkspaceRegisterParamsDto) _then;

/// Create a copy of WorkspaceRegisterParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? workspaceId = null,Object? checkoutId = null,Object? rootPath = null,Object? name = null,}) {
  return _then(_WorkspaceRegisterParamsDto(
workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,checkoutId: null == checkoutId ? _self.checkoutId : checkoutId // ignore: cast_nullable_to_non_nullable
as String,rootPath: null == rootPath ? _self.rootPath : rootPath // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$WorkspaceIdParamsDto {

 String get workspaceId;
/// Create a copy of WorkspaceIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceIdParamsDtoCopyWith<WorkspaceIdParamsDto> get copyWith => _$WorkspaceIdParamsDtoCopyWithImpl<WorkspaceIdParamsDto>(this as WorkspaceIdParamsDto, _$identity);

  /// Serializes this WorkspaceIdParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkspaceIdParamsDto&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,workspaceId);

@override
String toString() {
  return 'WorkspaceIdParamsDto(workspaceId: $workspaceId)';
}


}

/// @nodoc
abstract mixin class $WorkspaceIdParamsDtoCopyWith<$Res>  {
  factory $WorkspaceIdParamsDtoCopyWith(WorkspaceIdParamsDto value, $Res Function(WorkspaceIdParamsDto) _then) = _$WorkspaceIdParamsDtoCopyWithImpl;
@useResult
$Res call({
 String workspaceId
});




}
/// @nodoc
class _$WorkspaceIdParamsDtoCopyWithImpl<$Res>
    implements $WorkspaceIdParamsDtoCopyWith<$Res> {
  _$WorkspaceIdParamsDtoCopyWithImpl(this._self, this._then);

  final WorkspaceIdParamsDto _self;
  final $Res Function(WorkspaceIdParamsDto) _then;

/// Create a copy of WorkspaceIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? workspaceId = null,}) {
  return _then(WorkspaceIdParamsDto(
workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkspaceIdParamsDto].
extension WorkspaceIdParamsDtoPatterns on WorkspaceIdParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkspaceIdParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkspaceIdParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkspaceIdParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _WorkspaceIdParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkspaceIdParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _WorkspaceIdParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String workspaceId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkspaceIdParamsDto() when $default != null:
return $default(_that.workspaceId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String workspaceId)  $default,) {final _that = this;
switch (_that) {
case _WorkspaceIdParamsDto():
return $default(_that.workspaceId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String workspaceId)?  $default,) {final _that = this;
switch (_that) {
case _WorkspaceIdParamsDto() when $default != null:
return $default(_that.workspaceId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorkspaceIdParamsDto implements WorkspaceIdParamsDto {
  const _WorkspaceIdParamsDto({required this.workspaceId});
  factory _WorkspaceIdParamsDto.fromJson(Map<String, dynamic> json) => _$WorkspaceIdParamsDtoFromJson(json);

@override final  String workspaceId;

/// Create a copy of WorkspaceIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceIdParamsDtoCopyWith<_WorkspaceIdParamsDto> get copyWith => __$WorkspaceIdParamsDtoCopyWithImpl<_WorkspaceIdParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkspaceIdParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkspaceIdParamsDto&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,workspaceId);

@override
String toString() {
  return 'WorkspaceIdParamsDto(workspaceId: $workspaceId)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceIdParamsDtoCopyWith<$Res> implements $WorkspaceIdParamsDtoCopyWith<$Res> {
  factory _$WorkspaceIdParamsDtoCopyWith(_WorkspaceIdParamsDto value, $Res Function(_WorkspaceIdParamsDto) _then) = __$WorkspaceIdParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String workspaceId
});




}
/// @nodoc
class __$WorkspaceIdParamsDtoCopyWithImpl<$Res>
    implements _$WorkspaceIdParamsDtoCopyWith<$Res> {
  __$WorkspaceIdParamsDtoCopyWithImpl(this._self, this._then);

  final _WorkspaceIdParamsDto _self;
  final $Res Function(_WorkspaceIdParamsDto) _then;

/// Create a copy of WorkspaceIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? workspaceId = null,}) {
  return _then(_WorkspaceIdParamsDto(
workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$DirectorySuggestParamsDto {

 String get query; int get limit;
/// Create a copy of DirectorySuggestParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DirectorySuggestParamsDtoCopyWith<DirectorySuggestParamsDto> get copyWith => _$DirectorySuggestParamsDtoCopyWithImpl<DirectorySuggestParamsDto>(this as DirectorySuggestParamsDto, _$identity);

  /// Serializes this DirectorySuggestParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DirectorySuggestParamsDto&&(identical(other.query, query) || other.query == query)&&(identical(other.limit, limit) || other.limit == limit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,query,limit);

@override
String toString() {
  return 'DirectorySuggestParamsDto(query: $query, limit: $limit)';
}


}

/// @nodoc
abstract mixin class $DirectorySuggestParamsDtoCopyWith<$Res>  {
  factory $DirectorySuggestParamsDtoCopyWith(DirectorySuggestParamsDto value, $Res Function(DirectorySuggestParamsDto) _then) = _$DirectorySuggestParamsDtoCopyWithImpl;
@useResult
$Res call({
 String query, int limit
});




}
/// @nodoc
class _$DirectorySuggestParamsDtoCopyWithImpl<$Res>
    implements $DirectorySuggestParamsDtoCopyWith<$Res> {
  _$DirectorySuggestParamsDtoCopyWithImpl(this._self, this._then);

  final DirectorySuggestParamsDto _self;
  final $Res Function(DirectorySuggestParamsDto) _then;

/// Create a copy of DirectorySuggestParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? query = null,Object? limit = null,}) {
  return _then(DirectorySuggestParamsDto(
query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [DirectorySuggestParamsDto].
extension DirectorySuggestParamsDtoPatterns on DirectorySuggestParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DirectorySuggestParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DirectorySuggestParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DirectorySuggestParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _DirectorySuggestParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DirectorySuggestParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _DirectorySuggestParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String query,  int limit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DirectorySuggestParamsDto() when $default != null:
return $default(_that.query,_that.limit);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String query,  int limit)  $default,) {final _that = this;
switch (_that) {
case _DirectorySuggestParamsDto():
return $default(_that.query,_that.limit);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String query,  int limit)?  $default,) {final _that = this;
switch (_that) {
case _DirectorySuggestParamsDto() when $default != null:
return $default(_that.query,_that.limit);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DirectorySuggestParamsDto implements DirectorySuggestParamsDto {
  const _DirectorySuggestParamsDto({required this.query, this.limit = 30});
  factory _DirectorySuggestParamsDto.fromJson(Map<String, dynamic> json) => _$DirectorySuggestParamsDtoFromJson(json);

@override final  String query;
@override@JsonKey() final  int limit;

/// Create a copy of DirectorySuggestParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DirectorySuggestParamsDtoCopyWith<_DirectorySuggestParamsDto> get copyWith => __$DirectorySuggestParamsDtoCopyWithImpl<_DirectorySuggestParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DirectorySuggestParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DirectorySuggestParamsDto&&(identical(other.query, query) || other.query == query)&&(identical(other.limit, limit) || other.limit == limit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,query,limit);

@override
String toString() {
  return 'DirectorySuggestParamsDto(query: $query, limit: $limit)';
}


}

/// @nodoc
abstract mixin class _$DirectorySuggestParamsDtoCopyWith<$Res> implements $DirectorySuggestParamsDtoCopyWith<$Res> {
  factory _$DirectorySuggestParamsDtoCopyWith(_DirectorySuggestParamsDto value, $Res Function(_DirectorySuggestParamsDto) _then) = __$DirectorySuggestParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String query, int limit
});




}
/// @nodoc
class __$DirectorySuggestParamsDtoCopyWithImpl<$Res>
    implements _$DirectorySuggestParamsDtoCopyWith<$Res> {
  __$DirectorySuggestParamsDtoCopyWithImpl(this._self, this._then);

  final _DirectorySuggestParamsDto _self;
  final $Res Function(_DirectorySuggestParamsDto) _then;

/// Create a copy of DirectorySuggestParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? query = null,Object? limit = null,}) {
  return _then(_DirectorySuggestParamsDto(
query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$FileSearchParamsDto {

 String get worktreeId; String get query; int get limit;
/// Create a copy of FileSearchParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FileSearchParamsDtoCopyWith<FileSearchParamsDto> get copyWith => _$FileSearchParamsDtoCopyWithImpl<FileSearchParamsDto>(this as FileSearchParamsDto, _$identity);

  /// Serializes this FileSearchParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileSearchParamsDto&&(identical(other.worktreeId, worktreeId) || other.worktreeId == worktreeId)&&(identical(other.query, query) || other.query == query)&&(identical(other.limit, limit) || other.limit == limit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,worktreeId,query,limit);

@override
String toString() {
  return 'FileSearchParamsDto(worktreeId: $worktreeId, query: $query, limit: $limit)';
}


}

/// @nodoc
abstract mixin class $FileSearchParamsDtoCopyWith<$Res>  {
  factory $FileSearchParamsDtoCopyWith(FileSearchParamsDto value, $Res Function(FileSearchParamsDto) _then) = _$FileSearchParamsDtoCopyWithImpl;
@useResult
$Res call({
 String worktreeId, String query, int limit
});




}
/// @nodoc
class _$FileSearchParamsDtoCopyWithImpl<$Res>
    implements $FileSearchParamsDtoCopyWith<$Res> {
  _$FileSearchParamsDtoCopyWithImpl(this._self, this._then);

  final FileSearchParamsDto _self;
  final $Res Function(FileSearchParamsDto) _then;

/// Create a copy of FileSearchParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? worktreeId = null,Object? query = null,Object? limit = null,}) {
  return _then(FileSearchParamsDto(
worktreeId: null == worktreeId ? _self.worktreeId : worktreeId // ignore: cast_nullable_to_non_nullable
as String,query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [FileSearchParamsDto].
extension FileSearchParamsDtoPatterns on FileSearchParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FileSearchParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FileSearchParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FileSearchParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _FileSearchParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FileSearchParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _FileSearchParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String worktreeId,  String query,  int limit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FileSearchParamsDto() when $default != null:
return $default(_that.worktreeId,_that.query,_that.limit);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String worktreeId,  String query,  int limit)  $default,) {final _that = this;
switch (_that) {
case _FileSearchParamsDto():
return $default(_that.worktreeId,_that.query,_that.limit);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String worktreeId,  String query,  int limit)?  $default,) {final _that = this;
switch (_that) {
case _FileSearchParamsDto() when $default != null:
return $default(_that.worktreeId,_that.query,_that.limit);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FileSearchParamsDto implements FileSearchParamsDto {
  const _FileSearchParamsDto({required this.worktreeId, required this.query, this.limit = 50});
  factory _FileSearchParamsDto.fromJson(Map<String, dynamic> json) => _$FileSearchParamsDtoFromJson(json);

@override final  String worktreeId;
@override final  String query;
@override@JsonKey() final  int limit;

/// Create a copy of FileSearchParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FileSearchParamsDtoCopyWith<_FileSearchParamsDto> get copyWith => __$FileSearchParamsDtoCopyWithImpl<_FileSearchParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FileSearchParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FileSearchParamsDto&&(identical(other.worktreeId, worktreeId) || other.worktreeId == worktreeId)&&(identical(other.query, query) || other.query == query)&&(identical(other.limit, limit) || other.limit == limit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,worktreeId,query,limit);

@override
String toString() {
  return 'FileSearchParamsDto(worktreeId: $worktreeId, query: $query, limit: $limit)';
}


}

/// @nodoc
abstract mixin class _$FileSearchParamsDtoCopyWith<$Res> implements $FileSearchParamsDtoCopyWith<$Res> {
  factory _$FileSearchParamsDtoCopyWith(_FileSearchParamsDto value, $Res Function(_FileSearchParamsDto) _then) = __$FileSearchParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String worktreeId, String query, int limit
});




}
/// @nodoc
class __$FileSearchParamsDtoCopyWithImpl<$Res>
    implements _$FileSearchParamsDtoCopyWith<$Res> {
  __$FileSearchParamsDtoCopyWithImpl(this._self, this._then);

  final _FileSearchParamsDto _self;
  final $Res Function(_FileSearchParamsDto) _then;

/// Create a copy of FileSearchParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? worktreeId = null,Object? query = null,Object? limit = null,}) {
  return _then(_FileSearchParamsDto(
worktreeId: null == worktreeId ? _self.worktreeId : worktreeId // ignore: cast_nullable_to_non_nullable
as String,query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$CommandListParamsDto {

 String? get workspaceId;
/// Create a copy of CommandListParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommandListParamsDtoCopyWith<CommandListParamsDto> get copyWith => _$CommandListParamsDtoCopyWithImpl<CommandListParamsDto>(this as CommandListParamsDto, _$identity);

  /// Serializes this CommandListParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommandListParamsDto&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,workspaceId);

@override
String toString() {
  return 'CommandListParamsDto(workspaceId: $workspaceId)';
}


}

/// @nodoc
abstract mixin class $CommandListParamsDtoCopyWith<$Res>  {
  factory $CommandListParamsDtoCopyWith(CommandListParamsDto value, $Res Function(CommandListParamsDto) _then) = _$CommandListParamsDtoCopyWithImpl;
@useResult
$Res call({
 String? workspaceId
});




}
/// @nodoc
class _$CommandListParamsDtoCopyWithImpl<$Res>
    implements $CommandListParamsDtoCopyWith<$Res> {
  _$CommandListParamsDtoCopyWithImpl(this._self, this._then);

  final CommandListParamsDto _self;
  final $Res Function(CommandListParamsDto) _then;

/// Create a copy of CommandListParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? workspaceId = freezed,}) {
  return _then(CommandListParamsDto(
workspaceId: freezed == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CommandListParamsDto].
extension CommandListParamsDtoPatterns on CommandListParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommandListParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommandListParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommandListParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _CommandListParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommandListParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _CommandListParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? workspaceId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommandListParamsDto() when $default != null:
return $default(_that.workspaceId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? workspaceId)  $default,) {final _that = this;
switch (_that) {
case _CommandListParamsDto():
return $default(_that.workspaceId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? workspaceId)?  $default,) {final _that = this;
switch (_that) {
case _CommandListParamsDto() when $default != null:
return $default(_that.workspaceId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CommandListParamsDto implements CommandListParamsDto {
  const _CommandListParamsDto({this.workspaceId});
  factory _CommandListParamsDto.fromJson(Map<String, dynamic> json) => _$CommandListParamsDtoFromJson(json);

@override final  String? workspaceId;

/// Create a copy of CommandListParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommandListParamsDtoCopyWith<_CommandListParamsDto> get copyWith => __$CommandListParamsDtoCopyWithImpl<_CommandListParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CommandListParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommandListParamsDto&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,workspaceId);

@override
String toString() {
  return 'CommandListParamsDto(workspaceId: $workspaceId)';
}


}

/// @nodoc
abstract mixin class _$CommandListParamsDtoCopyWith<$Res> implements $CommandListParamsDtoCopyWith<$Res> {
  factory _$CommandListParamsDtoCopyWith(_CommandListParamsDto value, $Res Function(_CommandListParamsDto) _then) = __$CommandListParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String? workspaceId
});




}
/// @nodoc
class __$CommandListParamsDtoCopyWithImpl<$Res>
    implements _$CommandListParamsDtoCopyWith<$Res> {
  __$CommandListParamsDtoCopyWithImpl(this._self, this._then);

  final _CommandListParamsDto _self;
  final $Res Function(_CommandListParamsDto) _then;

/// Create a copy of CommandListParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? workspaceId = freezed,}) {
  return _then(_CommandListParamsDto(
workspaceId: freezed == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$GitBranchesListParamsDto {

 String get workspaceId;
/// Create a copy of GitBranchesListParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GitBranchesListParamsDtoCopyWith<GitBranchesListParamsDto> get copyWith => _$GitBranchesListParamsDtoCopyWithImpl<GitBranchesListParamsDto>(this as GitBranchesListParamsDto, _$identity);

  /// Serializes this GitBranchesListParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GitBranchesListParamsDto&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,workspaceId);

@override
String toString() {
  return 'GitBranchesListParamsDto(workspaceId: $workspaceId)';
}


}

/// @nodoc
abstract mixin class $GitBranchesListParamsDtoCopyWith<$Res>  {
  factory $GitBranchesListParamsDtoCopyWith(GitBranchesListParamsDto value, $Res Function(GitBranchesListParamsDto) _then) = _$GitBranchesListParamsDtoCopyWithImpl;
@useResult
$Res call({
 String workspaceId
});




}
/// @nodoc
class _$GitBranchesListParamsDtoCopyWithImpl<$Res>
    implements $GitBranchesListParamsDtoCopyWith<$Res> {
  _$GitBranchesListParamsDtoCopyWithImpl(this._self, this._then);

  final GitBranchesListParamsDto _self;
  final $Res Function(GitBranchesListParamsDto) _then;

/// Create a copy of GitBranchesListParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? workspaceId = null,}) {
  return _then(GitBranchesListParamsDto(
workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [GitBranchesListParamsDto].
extension GitBranchesListParamsDtoPatterns on GitBranchesListParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GitBranchesListParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GitBranchesListParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GitBranchesListParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _GitBranchesListParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GitBranchesListParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _GitBranchesListParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String workspaceId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GitBranchesListParamsDto() when $default != null:
return $default(_that.workspaceId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String workspaceId)  $default,) {final _that = this;
switch (_that) {
case _GitBranchesListParamsDto():
return $default(_that.workspaceId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String workspaceId)?  $default,) {final _that = this;
switch (_that) {
case _GitBranchesListParamsDto() when $default != null:
return $default(_that.workspaceId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GitBranchesListParamsDto implements GitBranchesListParamsDto {
  const _GitBranchesListParamsDto({required this.workspaceId});
  factory _GitBranchesListParamsDto.fromJson(Map<String, dynamic> json) => _$GitBranchesListParamsDtoFromJson(json);

@override final  String workspaceId;

/// Create a copy of GitBranchesListParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GitBranchesListParamsDtoCopyWith<_GitBranchesListParamsDto> get copyWith => __$GitBranchesListParamsDtoCopyWithImpl<_GitBranchesListParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GitBranchesListParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GitBranchesListParamsDto&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,workspaceId);

@override
String toString() {
  return 'GitBranchesListParamsDto(workspaceId: $workspaceId)';
}


}

/// @nodoc
abstract mixin class _$GitBranchesListParamsDtoCopyWith<$Res> implements $GitBranchesListParamsDtoCopyWith<$Res> {
  factory _$GitBranchesListParamsDtoCopyWith(_GitBranchesListParamsDto value, $Res Function(_GitBranchesListParamsDto) _then) = __$GitBranchesListParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String workspaceId
});




}
/// @nodoc
class __$GitBranchesListParamsDtoCopyWithImpl<$Res>
    implements _$GitBranchesListParamsDtoCopyWith<$Res> {
  __$GitBranchesListParamsDtoCopyWithImpl(this._self, this._then);

  final _GitBranchesListParamsDto _self;
  final $Res Function(_GitBranchesListParamsDto) _then;

/// Create a copy of GitBranchesListParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? workspaceId = null,}) {
  return _then(_GitBranchesListParamsDto(
workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$WorktreeCreateParamsDto {

 String get id; String get workspaceId; WorktreeCreateMode get mode; String get branchName; String? get baseBranch; WorktreeBranchNaming get branchNaming;
/// Create a copy of WorktreeCreateParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorktreeCreateParamsDtoCopyWith<WorktreeCreateParamsDto> get copyWith => _$WorktreeCreateParamsDtoCopyWithImpl<WorktreeCreateParamsDto>(this as WorktreeCreateParamsDto, _$identity);

  /// Serializes this WorktreeCreateParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorktreeCreateParamsDto&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.branchName, branchName) || other.branchName == branchName)&&(identical(other.baseBranch, baseBranch) || other.baseBranch == baseBranch)&&(identical(other.branchNaming, branchNaming) || other.branchNaming == branchNaming));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,mode,branchName,baseBranch,branchNaming);

@override
String toString() {
  return 'WorktreeCreateParamsDto(id: $id, workspaceId: $workspaceId, mode: $mode, branchName: $branchName, baseBranch: $baseBranch, branchNaming: $branchNaming)';
}


}

/// @nodoc
abstract mixin class $WorktreeCreateParamsDtoCopyWith<$Res>  {
  factory $WorktreeCreateParamsDtoCopyWith(WorktreeCreateParamsDto value, $Res Function(WorktreeCreateParamsDto) _then) = _$WorktreeCreateParamsDtoCopyWithImpl;
@useResult
$Res call({
 String id, String workspaceId, WorktreeCreateMode mode, String branchName, String? baseBranch, WorktreeBranchNaming branchNaming
});




}
/// @nodoc
class _$WorktreeCreateParamsDtoCopyWithImpl<$Res>
    implements $WorktreeCreateParamsDtoCopyWith<$Res> {
  _$WorktreeCreateParamsDtoCopyWithImpl(this._self, this._then);

  final WorktreeCreateParamsDto _self;
  final $Res Function(WorktreeCreateParamsDto) _then;

/// Create a copy of WorktreeCreateParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workspaceId = null,Object? mode = null,Object? branchName = null,Object? baseBranch = freezed,Object? branchNaming = null,}) {
  return _then(WorktreeCreateParamsDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as WorktreeCreateMode,branchName: null == branchName ? _self.branchName : branchName // ignore: cast_nullable_to_non_nullable
as String,baseBranch: freezed == baseBranch ? _self.baseBranch : baseBranch // ignore: cast_nullable_to_non_nullable
as String?,branchNaming: null == branchNaming ? _self.branchNaming : branchNaming // ignore: cast_nullable_to_non_nullable
as WorktreeBranchNaming,
  ));
}

}


/// Adds pattern-matching-related methods to [WorktreeCreateParamsDto].
extension WorktreeCreateParamsDtoPatterns on WorktreeCreateParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorktreeCreateParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorktreeCreateParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorktreeCreateParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _WorktreeCreateParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorktreeCreateParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _WorktreeCreateParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workspaceId,  WorktreeCreateMode mode,  String branchName,  String? baseBranch,  WorktreeBranchNaming branchNaming)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorktreeCreateParamsDto() when $default != null:
return $default(_that.id,_that.workspaceId,_that.mode,_that.branchName,_that.baseBranch,_that.branchNaming);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workspaceId,  WorktreeCreateMode mode,  String branchName,  String? baseBranch,  WorktreeBranchNaming branchNaming)  $default,) {final _that = this;
switch (_that) {
case _WorktreeCreateParamsDto():
return $default(_that.id,_that.workspaceId,_that.mode,_that.branchName,_that.baseBranch,_that.branchNaming);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workspaceId,  WorktreeCreateMode mode,  String branchName,  String? baseBranch,  WorktreeBranchNaming branchNaming)?  $default,) {final _that = this;
switch (_that) {
case _WorktreeCreateParamsDto() when $default != null:
return $default(_that.id,_that.workspaceId,_that.mode,_that.branchName,_that.baseBranch,_that.branchNaming);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorktreeCreateParamsDto implements WorktreeCreateParamsDto {
  const _WorktreeCreateParamsDto({required this.id, required this.workspaceId, required this.mode, required this.branchName, this.baseBranch, this.branchNaming = WorktreeBranchNaming.exact});
  factory _WorktreeCreateParamsDto.fromJson(Map<String, dynamic> json) => _$WorktreeCreateParamsDtoFromJson(json);

@override final  String id;
@override final  String workspaceId;
@override final  WorktreeCreateMode mode;
@override final  String branchName;
@override final  String? baseBranch;
@override@JsonKey() final  WorktreeBranchNaming branchNaming;

/// Create a copy of WorktreeCreateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorktreeCreateParamsDtoCopyWith<_WorktreeCreateParamsDto> get copyWith => __$WorktreeCreateParamsDtoCopyWithImpl<_WorktreeCreateParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorktreeCreateParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorktreeCreateParamsDto&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.branchName, branchName) || other.branchName == branchName)&&(identical(other.baseBranch, baseBranch) || other.baseBranch == baseBranch)&&(identical(other.branchNaming, branchNaming) || other.branchNaming == branchNaming));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,mode,branchName,baseBranch,branchNaming);

@override
String toString() {
  return 'WorktreeCreateParamsDto(id: $id, workspaceId: $workspaceId, mode: $mode, branchName: $branchName, baseBranch: $baseBranch, branchNaming: $branchNaming)';
}


}

/// @nodoc
abstract mixin class _$WorktreeCreateParamsDtoCopyWith<$Res> implements $WorktreeCreateParamsDtoCopyWith<$Res> {
  factory _$WorktreeCreateParamsDtoCopyWith(_WorktreeCreateParamsDto value, $Res Function(_WorktreeCreateParamsDto) _then) = __$WorktreeCreateParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String workspaceId, WorktreeCreateMode mode, String branchName, String? baseBranch, WorktreeBranchNaming branchNaming
});




}
/// @nodoc
class __$WorktreeCreateParamsDtoCopyWithImpl<$Res>
    implements _$WorktreeCreateParamsDtoCopyWith<$Res> {
  __$WorktreeCreateParamsDtoCopyWithImpl(this._self, this._then);

  final _WorktreeCreateParamsDto _self;
  final $Res Function(_WorktreeCreateParamsDto) _then;

/// Create a copy of WorktreeCreateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workspaceId = null,Object? mode = null,Object? branchName = null,Object? baseBranch = freezed,Object? branchNaming = null,}) {
  return _then(_WorktreeCreateParamsDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as WorktreeCreateMode,branchName: null == branchName ? _self.branchName : branchName // ignore: cast_nullable_to_non_nullable
as String,baseBranch: freezed == baseBranch ? _self.baseBranch : baseBranch // ignore: cast_nullable_to_non_nullable
as String?,branchNaming: null == branchNaming ? _self.branchNaming : branchNaming // ignore: cast_nullable_to_non_nullable
as WorktreeBranchNaming,
  ));
}


}


/// @nodoc
mixin _$WorktreeIdParamsDto {

 String get worktreeId;
/// Create a copy of WorktreeIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorktreeIdParamsDtoCopyWith<WorktreeIdParamsDto> get copyWith => _$WorktreeIdParamsDtoCopyWithImpl<WorktreeIdParamsDto>(this as WorktreeIdParamsDto, _$identity);

  /// Serializes this WorktreeIdParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorktreeIdParamsDto&&(identical(other.worktreeId, worktreeId) || other.worktreeId == worktreeId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,worktreeId);

@override
String toString() {
  return 'WorktreeIdParamsDto(worktreeId: $worktreeId)';
}


}

/// @nodoc
abstract mixin class $WorktreeIdParamsDtoCopyWith<$Res>  {
  factory $WorktreeIdParamsDtoCopyWith(WorktreeIdParamsDto value, $Res Function(WorktreeIdParamsDto) _then) = _$WorktreeIdParamsDtoCopyWithImpl;
@useResult
$Res call({
 String worktreeId
});




}
/// @nodoc
class _$WorktreeIdParamsDtoCopyWithImpl<$Res>
    implements $WorktreeIdParamsDtoCopyWith<$Res> {
  _$WorktreeIdParamsDtoCopyWithImpl(this._self, this._then);

  final WorktreeIdParamsDto _self;
  final $Res Function(WorktreeIdParamsDto) _then;

/// Create a copy of WorktreeIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? worktreeId = null,}) {
  return _then(WorktreeIdParamsDto(
worktreeId: null == worktreeId ? _self.worktreeId : worktreeId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [WorktreeIdParamsDto].
extension WorktreeIdParamsDtoPatterns on WorktreeIdParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorktreeIdParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorktreeIdParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorktreeIdParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _WorktreeIdParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorktreeIdParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _WorktreeIdParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String worktreeId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorktreeIdParamsDto() when $default != null:
return $default(_that.worktreeId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String worktreeId)  $default,) {final _that = this;
switch (_that) {
case _WorktreeIdParamsDto():
return $default(_that.worktreeId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String worktreeId)?  $default,) {final _that = this;
switch (_that) {
case _WorktreeIdParamsDto() when $default != null:
return $default(_that.worktreeId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorktreeIdParamsDto implements WorktreeIdParamsDto {
  const _WorktreeIdParamsDto({required this.worktreeId});
  factory _WorktreeIdParamsDto.fromJson(Map<String, dynamic> json) => _$WorktreeIdParamsDtoFromJson(json);

@override final  String worktreeId;

/// Create a copy of WorktreeIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorktreeIdParamsDtoCopyWith<_WorktreeIdParamsDto> get copyWith => __$WorktreeIdParamsDtoCopyWithImpl<_WorktreeIdParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorktreeIdParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorktreeIdParamsDto&&(identical(other.worktreeId, worktreeId) || other.worktreeId == worktreeId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,worktreeId);

@override
String toString() {
  return 'WorktreeIdParamsDto(worktreeId: $worktreeId)';
}


}

/// @nodoc
abstract mixin class _$WorktreeIdParamsDtoCopyWith<$Res> implements $WorktreeIdParamsDtoCopyWith<$Res> {
  factory _$WorktreeIdParamsDtoCopyWith(_WorktreeIdParamsDto value, $Res Function(_WorktreeIdParamsDto) _then) = __$WorktreeIdParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String worktreeId
});




}
/// @nodoc
class __$WorktreeIdParamsDtoCopyWithImpl<$Res>
    implements _$WorktreeIdParamsDtoCopyWith<$Res> {
  __$WorktreeIdParamsDtoCopyWithImpl(this._self, this._then);

  final _WorktreeIdParamsDto _self;
  final $Res Function(_WorktreeIdParamsDto) _then;

/// Create a copy of WorktreeIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? worktreeId = null,}) {
  return _then(_WorktreeIdParamsDto(
worktreeId: null == worktreeId ? _self.worktreeId : worktreeId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$WorktreeArchiveParamsDto {

 String get worktreeId; bool get force;
/// Create a copy of WorktreeArchiveParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorktreeArchiveParamsDtoCopyWith<WorktreeArchiveParamsDto> get copyWith => _$WorktreeArchiveParamsDtoCopyWithImpl<WorktreeArchiveParamsDto>(this as WorktreeArchiveParamsDto, _$identity);

  /// Serializes this WorktreeArchiveParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorktreeArchiveParamsDto&&(identical(other.worktreeId, worktreeId) || other.worktreeId == worktreeId)&&(identical(other.force, force) || other.force == force));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,worktreeId,force);

@override
String toString() {
  return 'WorktreeArchiveParamsDto(worktreeId: $worktreeId, force: $force)';
}


}

/// @nodoc
abstract mixin class $WorktreeArchiveParamsDtoCopyWith<$Res>  {
  factory $WorktreeArchiveParamsDtoCopyWith(WorktreeArchiveParamsDto value, $Res Function(WorktreeArchiveParamsDto) _then) = _$WorktreeArchiveParamsDtoCopyWithImpl;
@useResult
$Res call({
 String worktreeId, bool force
});




}
/// @nodoc
class _$WorktreeArchiveParamsDtoCopyWithImpl<$Res>
    implements $WorktreeArchiveParamsDtoCopyWith<$Res> {
  _$WorktreeArchiveParamsDtoCopyWithImpl(this._self, this._then);

  final WorktreeArchiveParamsDto _self;
  final $Res Function(WorktreeArchiveParamsDto) _then;

/// Create a copy of WorktreeArchiveParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? worktreeId = null,Object? force = null,}) {
  return _then(WorktreeArchiveParamsDto(
worktreeId: null == worktreeId ? _self.worktreeId : worktreeId // ignore: cast_nullable_to_non_nullable
as String,force: null == force ? _self.force : force // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [WorktreeArchiveParamsDto].
extension WorktreeArchiveParamsDtoPatterns on WorktreeArchiveParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorktreeArchiveParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorktreeArchiveParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorktreeArchiveParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _WorktreeArchiveParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorktreeArchiveParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _WorktreeArchiveParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String worktreeId,  bool force)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorktreeArchiveParamsDto() when $default != null:
return $default(_that.worktreeId,_that.force);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String worktreeId,  bool force)  $default,) {final _that = this;
switch (_that) {
case _WorktreeArchiveParamsDto():
return $default(_that.worktreeId,_that.force);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String worktreeId,  bool force)?  $default,) {final _that = this;
switch (_that) {
case _WorktreeArchiveParamsDto() when $default != null:
return $default(_that.worktreeId,_that.force);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorktreeArchiveParamsDto implements WorktreeArchiveParamsDto {
  const _WorktreeArchiveParamsDto({required this.worktreeId, required this.force});
  factory _WorktreeArchiveParamsDto.fromJson(Map<String, dynamic> json) => _$WorktreeArchiveParamsDtoFromJson(json);

@override final  String worktreeId;
@override final  bool force;

/// Create a copy of WorktreeArchiveParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorktreeArchiveParamsDtoCopyWith<_WorktreeArchiveParamsDto> get copyWith => __$WorktreeArchiveParamsDtoCopyWithImpl<_WorktreeArchiveParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorktreeArchiveParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorktreeArchiveParamsDto&&(identical(other.worktreeId, worktreeId) || other.worktreeId == worktreeId)&&(identical(other.force, force) || other.force == force));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,worktreeId,force);

@override
String toString() {
  return 'WorktreeArchiveParamsDto(worktreeId: $worktreeId, force: $force)';
}


}

/// @nodoc
abstract mixin class _$WorktreeArchiveParamsDtoCopyWith<$Res> implements $WorktreeArchiveParamsDtoCopyWith<$Res> {
  factory _$WorktreeArchiveParamsDtoCopyWith(_WorktreeArchiveParamsDto value, $Res Function(_WorktreeArchiveParamsDto) _then) = __$WorktreeArchiveParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String worktreeId, bool force
});




}
/// @nodoc
class __$WorktreeArchiveParamsDtoCopyWithImpl<$Res>
    implements _$WorktreeArchiveParamsDtoCopyWith<$Res> {
  __$WorktreeArchiveParamsDtoCopyWithImpl(this._self, this._then);

  final _WorktreeArchiveParamsDto _self;
  final $Res Function(_WorktreeArchiveParamsDto) _then;

/// Create a copy of WorktreeArchiveParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? worktreeId = null,Object? force = null,}) {
  return _then(_WorktreeArchiveParamsDto(
worktreeId: null == worktreeId ? _self.worktreeId : worktreeId // ignore: cast_nullable_to_non_nullable
as String,force: null == force ? _self.force : force // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$SessionListParamsDto {

 String? get worktreeId;
/// Create a copy of SessionListParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionListParamsDtoCopyWith<SessionListParamsDto> get copyWith => _$SessionListParamsDtoCopyWithImpl<SessionListParamsDto>(this as SessionListParamsDto, _$identity);

  /// Serializes this SessionListParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionListParamsDto&&(identical(other.worktreeId, worktreeId) || other.worktreeId == worktreeId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,worktreeId);

@override
String toString() {
  return 'SessionListParamsDto(worktreeId: $worktreeId)';
}


}

/// @nodoc
abstract mixin class $SessionListParamsDtoCopyWith<$Res>  {
  factory $SessionListParamsDtoCopyWith(SessionListParamsDto value, $Res Function(SessionListParamsDto) _then) = _$SessionListParamsDtoCopyWithImpl;
@useResult
$Res call({
 String? worktreeId
});




}
/// @nodoc
class _$SessionListParamsDtoCopyWithImpl<$Res>
    implements $SessionListParamsDtoCopyWith<$Res> {
  _$SessionListParamsDtoCopyWithImpl(this._self, this._then);

  final SessionListParamsDto _self;
  final $Res Function(SessionListParamsDto) _then;

/// Create a copy of SessionListParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? worktreeId = freezed,}) {
  return _then(SessionListParamsDto(
worktreeId: freezed == worktreeId ? _self.worktreeId : worktreeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionListParamsDto].
extension SessionListParamsDtoPatterns on SessionListParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionListParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionListParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionListParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _SessionListParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionListParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _SessionListParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? worktreeId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionListParamsDto() when $default != null:
return $default(_that.worktreeId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? worktreeId)  $default,) {final _that = this;
switch (_that) {
case _SessionListParamsDto():
return $default(_that.worktreeId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? worktreeId)?  $default,) {final _that = this;
switch (_that) {
case _SessionListParamsDto() when $default != null:
return $default(_that.worktreeId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SessionListParamsDto implements SessionListParamsDto {
  const _SessionListParamsDto({this.worktreeId});
  factory _SessionListParamsDto.fromJson(Map<String, dynamic> json) => _$SessionListParamsDtoFromJson(json);

@override final  String? worktreeId;

/// Create a copy of SessionListParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionListParamsDtoCopyWith<_SessionListParamsDto> get copyWith => __$SessionListParamsDtoCopyWithImpl<_SessionListParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionListParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionListParamsDto&&(identical(other.worktreeId, worktreeId) || other.worktreeId == worktreeId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,worktreeId);

@override
String toString() {
  return 'SessionListParamsDto(worktreeId: $worktreeId)';
}


}

/// @nodoc
abstract mixin class _$SessionListParamsDtoCopyWith<$Res> implements $SessionListParamsDtoCopyWith<$Res> {
  factory _$SessionListParamsDtoCopyWith(_SessionListParamsDto value, $Res Function(_SessionListParamsDto) _then) = __$SessionListParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String? worktreeId
});




}
/// @nodoc
class __$SessionListParamsDtoCopyWithImpl<$Res>
    implements _$SessionListParamsDtoCopyWith<$Res> {
  __$SessionListParamsDtoCopyWithImpl(this._self, this._then);

  final _SessionListParamsDto _self;
  final $Res Function(_SessionListParamsDto) _then;

/// Create a copy of SessionListParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? worktreeId = freezed,}) {
  return _then(_SessionListParamsDto(
worktreeId: freezed == worktreeId ? _self.worktreeId : worktreeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$SessionSubagentListParamsDto {

 String get sessionId;
/// Create a copy of SessionSubagentListParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionSubagentListParamsDtoCopyWith<SessionSubagentListParamsDto> get copyWith => _$SessionSubagentListParamsDtoCopyWithImpl<SessionSubagentListParamsDto>(this as SessionSubagentListParamsDto, _$identity);

  /// Serializes this SessionSubagentListParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionSubagentListParamsDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId);

@override
String toString() {
  return 'SessionSubagentListParamsDto(sessionId: $sessionId)';
}


}

/// @nodoc
abstract mixin class $SessionSubagentListParamsDtoCopyWith<$Res>  {
  factory $SessionSubagentListParamsDtoCopyWith(SessionSubagentListParamsDto value, $Res Function(SessionSubagentListParamsDto) _then) = _$SessionSubagentListParamsDtoCopyWithImpl;
@useResult
$Res call({
 String sessionId
});




}
/// @nodoc
class _$SessionSubagentListParamsDtoCopyWithImpl<$Res>
    implements $SessionSubagentListParamsDtoCopyWith<$Res> {
  _$SessionSubagentListParamsDtoCopyWithImpl(this._self, this._then);

  final SessionSubagentListParamsDto _self;
  final $Res Function(SessionSubagentListParamsDto) _then;

/// Create a copy of SessionSubagentListParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,}) {
  return _then(SessionSubagentListParamsDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionSubagentListParamsDto].
extension SessionSubagentListParamsDtoPatterns on SessionSubagentListParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionSubagentListParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionSubagentListParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionSubagentListParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _SessionSubagentListParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionSubagentListParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _SessionSubagentListParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sessionId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionSubagentListParamsDto() when $default != null:
return $default(_that.sessionId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sessionId)  $default,) {final _that = this;
switch (_that) {
case _SessionSubagentListParamsDto():
return $default(_that.sessionId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sessionId)?  $default,) {final _that = this;
switch (_that) {
case _SessionSubagentListParamsDto() when $default != null:
return $default(_that.sessionId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SessionSubagentListParamsDto implements SessionSubagentListParamsDto {
  const _SessionSubagentListParamsDto({required this.sessionId});
  factory _SessionSubagentListParamsDto.fromJson(Map<String, dynamic> json) => _$SessionSubagentListParamsDtoFromJson(json);

@override final  String sessionId;

/// Create a copy of SessionSubagentListParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionSubagentListParamsDtoCopyWith<_SessionSubagentListParamsDto> get copyWith => __$SessionSubagentListParamsDtoCopyWithImpl<_SessionSubagentListParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionSubagentListParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionSubagentListParamsDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId);

@override
String toString() {
  return 'SessionSubagentListParamsDto(sessionId: $sessionId)';
}


}

/// @nodoc
abstract mixin class _$SessionSubagentListParamsDtoCopyWith<$Res> implements $SessionSubagentListParamsDtoCopyWith<$Res> {
  factory _$SessionSubagentListParamsDtoCopyWith(_SessionSubagentListParamsDto value, $Res Function(_SessionSubagentListParamsDto) _then) = __$SessionSubagentListParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String sessionId
});




}
/// @nodoc
class __$SessionSubagentListParamsDtoCopyWithImpl<$Res>
    implements _$SessionSubagentListParamsDtoCopyWith<$Res> {
  __$SessionSubagentListParamsDtoCopyWithImpl(this._self, this._then);

  final _SessionSubagentListParamsDto _self;
  final $Res Function(_SessionSubagentListParamsDto) _then;

/// Create a copy of SessionSubagentListParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,}) {
  return _then(_SessionSubagentListParamsDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$SessionCreateParamsDto {

 String get id; String get worktreeId; String get title; String get agentDefinitionId; ModelSelectionDto? get model; Map<String, ModelControlValueDto> get modelControls;/// Permission mode to pin on the new session; null takes the daemon
/// default that is configured when the session is created.
 PermissionMode? get permissionMode;
/// Create a copy of SessionCreateParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionCreateParamsDtoCopyWith<SessionCreateParamsDto> get copyWith => _$SessionCreateParamsDtoCopyWithImpl<SessionCreateParamsDto>(this as SessionCreateParamsDto, _$identity);

  /// Serializes this SessionCreateParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionCreateParamsDto&&(identical(other.id, id) || other.id == id)&&(identical(other.worktreeId, worktreeId) || other.worktreeId == worktreeId)&&(identical(other.title, title) || other.title == title)&&(identical(other.agentDefinitionId, agentDefinitionId) || other.agentDefinitionId == agentDefinitionId)&&(identical(other.model, model) || other.model == model)&&const DeepCollectionEquality().equals(other.modelControls, modelControls)&&(identical(other.permissionMode, permissionMode) || other.permissionMode == permissionMode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,worktreeId,title,agentDefinitionId,model,const DeepCollectionEquality().hash(modelControls),permissionMode);

@override
String toString() {
  return 'SessionCreateParamsDto(id: $id, worktreeId: $worktreeId, title: $title, agentDefinitionId: $agentDefinitionId, model: $model, modelControls: $modelControls, permissionMode: $permissionMode)';
}


}

/// @nodoc
abstract mixin class $SessionCreateParamsDtoCopyWith<$Res>  {
  factory $SessionCreateParamsDtoCopyWith(SessionCreateParamsDto value, $Res Function(SessionCreateParamsDto) _then) = _$SessionCreateParamsDtoCopyWithImpl;
@useResult
$Res call({
 String id, String worktreeId, String title, String agentDefinitionId, ModelSelectionDto? model, Map<String, ModelControlValueDto> modelControls, PermissionMode? permissionMode
});


$ModelSelectionDtoCopyWith<$Res>? get model;

}
/// @nodoc
class _$SessionCreateParamsDtoCopyWithImpl<$Res>
    implements $SessionCreateParamsDtoCopyWith<$Res> {
  _$SessionCreateParamsDtoCopyWithImpl(this._self, this._then);

  final SessionCreateParamsDto _self;
  final $Res Function(SessionCreateParamsDto) _then;

/// Create a copy of SessionCreateParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? worktreeId = null,Object? title = null,Object? agentDefinitionId = null,Object? model = freezed,Object? modelControls = null,Object? permissionMode = freezed,}) {
  return _then(SessionCreateParamsDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,worktreeId: null == worktreeId ? _self.worktreeId : worktreeId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,agentDefinitionId: null == agentDefinitionId ? _self.agentDefinitionId : agentDefinitionId // ignore: cast_nullable_to_non_nullable
as String,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as ModelSelectionDto?,modelControls: null == modelControls ? _self.modelControls : modelControls // ignore: cast_nullable_to_non_nullable
as Map<String, ModelControlValueDto>,permissionMode: freezed == permissionMode ? _self.permissionMode : permissionMode // ignore: cast_nullable_to_non_nullable
as PermissionMode?,
  ));
}
/// Create a copy of SessionCreateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModelSelectionDtoCopyWith<$Res>? get model {
    if (_self.model == null) {
    return null;
  }

  return $ModelSelectionDtoCopyWith<$Res>(_self.model!, (value) {
    return _then(_self.copyWith(model: value));
  });
}
}


/// Adds pattern-matching-related methods to [SessionCreateParamsDto].
extension SessionCreateParamsDtoPatterns on SessionCreateParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionCreateParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionCreateParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionCreateParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _SessionCreateParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionCreateParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _SessionCreateParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String worktreeId,  String title,  String agentDefinitionId,  ModelSelectionDto? model,  Map<String, ModelControlValueDto> modelControls,  PermissionMode? permissionMode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionCreateParamsDto() when $default != null:
return $default(_that.id,_that.worktreeId,_that.title,_that.agentDefinitionId,_that.model,_that.modelControls,_that.permissionMode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String worktreeId,  String title,  String agentDefinitionId,  ModelSelectionDto? model,  Map<String, ModelControlValueDto> modelControls,  PermissionMode? permissionMode)  $default,) {final _that = this;
switch (_that) {
case _SessionCreateParamsDto():
return $default(_that.id,_that.worktreeId,_that.title,_that.agentDefinitionId,_that.model,_that.modelControls,_that.permissionMode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String worktreeId,  String title,  String agentDefinitionId,  ModelSelectionDto? model,  Map<String, ModelControlValueDto> modelControls,  PermissionMode? permissionMode)?  $default,) {final _that = this;
switch (_that) {
case _SessionCreateParamsDto() when $default != null:
return $default(_that.id,_that.worktreeId,_that.title,_that.agentDefinitionId,_that.model,_that.modelControls,_that.permissionMode);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SessionCreateParamsDto implements SessionCreateParamsDto {
  const _SessionCreateParamsDto({required this.id, required this.worktreeId, required this.title, required this.agentDefinitionId, this.model,  Map<String, ModelControlValueDto> modelControls = const <String, ModelControlValueDto>{}, this.permissionMode}): _modelControls = modelControls;
  factory _SessionCreateParamsDto.fromJson(Map<String, dynamic> json) => _$SessionCreateParamsDtoFromJson(json);

@override final  String id;
@override final  String worktreeId;
@override final  String title;
@override final  String agentDefinitionId;
@override final  ModelSelectionDto? model;
 final  Map<String, ModelControlValueDto> _modelControls;
@override@JsonKey() Map<String, ModelControlValueDto> get modelControls {
  if (_modelControls is EqualUnmodifiableMapView) return _modelControls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_modelControls);
}

/// Permission mode to pin on the new session; null takes the daemon
/// default that is configured when the session is created.
@override final  PermissionMode? permissionMode;

/// Create a copy of SessionCreateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionCreateParamsDtoCopyWith<_SessionCreateParamsDto> get copyWith => __$SessionCreateParamsDtoCopyWithImpl<_SessionCreateParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionCreateParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionCreateParamsDto&&(identical(other.id, id) || other.id == id)&&(identical(other.worktreeId, worktreeId) || other.worktreeId == worktreeId)&&(identical(other.title, title) || other.title == title)&&(identical(other.agentDefinitionId, agentDefinitionId) || other.agentDefinitionId == agentDefinitionId)&&(identical(other.model, model) || other.model == model)&&const DeepCollectionEquality().equals(other._modelControls, _modelControls)&&(identical(other.permissionMode, permissionMode) || other.permissionMode == permissionMode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,worktreeId,title,agentDefinitionId,model,const DeepCollectionEquality().hash(_modelControls),permissionMode);

@override
String toString() {
  return 'SessionCreateParamsDto(id: $id, worktreeId: $worktreeId, title: $title, agentDefinitionId: $agentDefinitionId, model: $model, modelControls: $modelControls, permissionMode: $permissionMode)';
}


}

/// @nodoc
abstract mixin class _$SessionCreateParamsDtoCopyWith<$Res> implements $SessionCreateParamsDtoCopyWith<$Res> {
  factory _$SessionCreateParamsDtoCopyWith(_SessionCreateParamsDto value, $Res Function(_SessionCreateParamsDto) _then) = __$SessionCreateParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String worktreeId, String title, String agentDefinitionId, ModelSelectionDto? model, Map<String, ModelControlValueDto> modelControls, PermissionMode? permissionMode
});


@override $ModelSelectionDtoCopyWith<$Res>? get model;

}
/// @nodoc
class __$SessionCreateParamsDtoCopyWithImpl<$Res>
    implements _$SessionCreateParamsDtoCopyWith<$Res> {
  __$SessionCreateParamsDtoCopyWithImpl(this._self, this._then);

  final _SessionCreateParamsDto _self;
  final $Res Function(_SessionCreateParamsDto) _then;

/// Create a copy of SessionCreateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? worktreeId = null,Object? title = null,Object? agentDefinitionId = null,Object? model = freezed,Object? modelControls = null,Object? permissionMode = freezed,}) {
  return _then(_SessionCreateParamsDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,worktreeId: null == worktreeId ? _self.worktreeId : worktreeId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,agentDefinitionId: null == agentDefinitionId ? _self.agentDefinitionId : agentDefinitionId // ignore: cast_nullable_to_non_nullable
as String,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as ModelSelectionDto?,modelControls: null == modelControls ? _self._modelControls : modelControls // ignore: cast_nullable_to_non_nullable
as Map<String, ModelControlValueDto>,permissionMode: freezed == permissionMode ? _self.permissionMode : permissionMode // ignore: cast_nullable_to_non_nullable
as PermissionMode?,
  ));
}

/// Create a copy of SessionCreateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModelSelectionDtoCopyWith<$Res>? get model {
    if (_self.model == null) {
    return null;
  }

  return $ModelSelectionDtoCopyWith<$Res>(_self.model!, (value) {
    return _then(_self.copyWith(model: value));
  });
}
}


/// @nodoc
mixin _$SessionSettingsPatchDto {

 bool get hasModel; ModelSelectionDto? get model; bool get hasModelControls; Map<String, ModelControlValueDto> get modelControls;/// New permission mode, or null to leave the current one in place. A
/// session always owns a concrete mode, so there is nothing to clear and
/// the field needs no has-flag of its own.
 PermissionMode? get permissionMode;
/// Create a copy of SessionSettingsPatchDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionSettingsPatchDtoCopyWith<SessionSettingsPatchDto> get copyWith => _$SessionSettingsPatchDtoCopyWithImpl<SessionSettingsPatchDto>(this as SessionSettingsPatchDto, _$identity);

  /// Serializes this SessionSettingsPatchDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionSettingsPatchDto&&(identical(other.hasModel, hasModel) || other.hasModel == hasModel)&&(identical(other.model, model) || other.model == model)&&(identical(other.hasModelControls, hasModelControls) || other.hasModelControls == hasModelControls)&&const DeepCollectionEquality().equals(other.modelControls, modelControls)&&(identical(other.permissionMode, permissionMode) || other.permissionMode == permissionMode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,hasModel,model,hasModelControls,const DeepCollectionEquality().hash(modelControls),permissionMode);

@override
String toString() {
  return 'SessionSettingsPatchDto(hasModel: $hasModel, model: $model, hasModelControls: $hasModelControls, modelControls: $modelControls, permissionMode: $permissionMode)';
}


}

/// @nodoc
abstract mixin class $SessionSettingsPatchDtoCopyWith<$Res>  {
  factory $SessionSettingsPatchDtoCopyWith(SessionSettingsPatchDto value, $Res Function(SessionSettingsPatchDto) _then) = _$SessionSettingsPatchDtoCopyWithImpl;
@useResult
$Res call({
 bool hasModel, ModelSelectionDto? model, bool hasModelControls, Map<String, ModelControlValueDto> modelControls, PermissionMode? permissionMode
});


$ModelSelectionDtoCopyWith<$Res>? get model;

}
/// @nodoc
class _$SessionSettingsPatchDtoCopyWithImpl<$Res>
    implements $SessionSettingsPatchDtoCopyWith<$Res> {
  _$SessionSettingsPatchDtoCopyWithImpl(this._self, this._then);

  final SessionSettingsPatchDto _self;
  final $Res Function(SessionSettingsPatchDto) _then;

/// Create a copy of SessionSettingsPatchDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hasModel = null,Object? model = freezed,Object? hasModelControls = null,Object? modelControls = null,Object? permissionMode = freezed,}) {
  return _then(SessionSettingsPatchDto(
hasModel: null == hasModel ? _self.hasModel : hasModel // ignore: cast_nullable_to_non_nullable
as bool,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as ModelSelectionDto?,hasModelControls: null == hasModelControls ? _self.hasModelControls : hasModelControls // ignore: cast_nullable_to_non_nullable
as bool,modelControls: null == modelControls ? _self.modelControls : modelControls // ignore: cast_nullable_to_non_nullable
as Map<String, ModelControlValueDto>,permissionMode: freezed == permissionMode ? _self.permissionMode : permissionMode // ignore: cast_nullable_to_non_nullable
as PermissionMode?,
  ));
}
/// Create a copy of SessionSettingsPatchDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModelSelectionDtoCopyWith<$Res>? get model {
    if (_self.model == null) {
    return null;
  }

  return $ModelSelectionDtoCopyWith<$Res>(_self.model!, (value) {
    return _then(_self.copyWith(model: value));
  });
}
}


/// Adds pattern-matching-related methods to [SessionSettingsPatchDto].
extension SessionSettingsPatchDtoPatterns on SessionSettingsPatchDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionSettingsPatchDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionSettingsPatchDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionSettingsPatchDto value)  $default,){
final _that = this;
switch (_that) {
case _SessionSettingsPatchDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionSettingsPatchDto value)?  $default,){
final _that = this;
switch (_that) {
case _SessionSettingsPatchDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool hasModel,  ModelSelectionDto? model,  bool hasModelControls,  Map<String, ModelControlValueDto> modelControls,  PermissionMode? permissionMode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionSettingsPatchDto() when $default != null:
return $default(_that.hasModel,_that.model,_that.hasModelControls,_that.modelControls,_that.permissionMode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool hasModel,  ModelSelectionDto? model,  bool hasModelControls,  Map<String, ModelControlValueDto> modelControls,  PermissionMode? permissionMode)  $default,) {final _that = this;
switch (_that) {
case _SessionSettingsPatchDto():
return $default(_that.hasModel,_that.model,_that.hasModelControls,_that.modelControls,_that.permissionMode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool hasModel,  ModelSelectionDto? model,  bool hasModelControls,  Map<String, ModelControlValueDto> modelControls,  PermissionMode? permissionMode)?  $default,) {final _that = this;
switch (_that) {
case _SessionSettingsPatchDto() when $default != null:
return $default(_that.hasModel,_that.model,_that.hasModelControls,_that.modelControls,_that.permissionMode);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SessionSettingsPatchDto implements SessionSettingsPatchDto {
  const _SessionSettingsPatchDto({this.hasModel = false, this.model, this.hasModelControls = false,  Map<String, ModelControlValueDto> modelControls = const <String, ModelControlValueDto>{}, this.permissionMode}): _modelControls = modelControls;
  factory _SessionSettingsPatchDto.fromJson(Map<String, dynamic> json) => _$SessionSettingsPatchDtoFromJson(json);

@override@JsonKey() final  bool hasModel;
@override final  ModelSelectionDto? model;
@override@JsonKey() final  bool hasModelControls;
 final  Map<String, ModelControlValueDto> _modelControls;
@override@JsonKey() Map<String, ModelControlValueDto> get modelControls {
  if (_modelControls is EqualUnmodifiableMapView) return _modelControls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_modelControls);
}

/// New permission mode, or null to leave the current one in place. A
/// session always owns a concrete mode, so there is nothing to clear and
/// the field needs no has-flag of its own.
@override final  PermissionMode? permissionMode;

/// Create a copy of SessionSettingsPatchDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionSettingsPatchDtoCopyWith<_SessionSettingsPatchDto> get copyWith => __$SessionSettingsPatchDtoCopyWithImpl<_SessionSettingsPatchDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionSettingsPatchDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionSettingsPatchDto&&(identical(other.hasModel, hasModel) || other.hasModel == hasModel)&&(identical(other.model, model) || other.model == model)&&(identical(other.hasModelControls, hasModelControls) || other.hasModelControls == hasModelControls)&&const DeepCollectionEquality().equals(other._modelControls, _modelControls)&&(identical(other.permissionMode, permissionMode) || other.permissionMode == permissionMode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,hasModel,model,hasModelControls,const DeepCollectionEquality().hash(_modelControls),permissionMode);

@override
String toString() {
  return 'SessionSettingsPatchDto(hasModel: $hasModel, model: $model, hasModelControls: $hasModelControls, modelControls: $modelControls, permissionMode: $permissionMode)';
}


}

/// @nodoc
abstract mixin class _$SessionSettingsPatchDtoCopyWith<$Res> implements $SessionSettingsPatchDtoCopyWith<$Res> {
  factory _$SessionSettingsPatchDtoCopyWith(_SessionSettingsPatchDto value, $Res Function(_SessionSettingsPatchDto) _then) = __$SessionSettingsPatchDtoCopyWithImpl;
@override @useResult
$Res call({
 bool hasModel, ModelSelectionDto? model, bool hasModelControls, Map<String, ModelControlValueDto> modelControls, PermissionMode? permissionMode
});


@override $ModelSelectionDtoCopyWith<$Res>? get model;

}
/// @nodoc
class __$SessionSettingsPatchDtoCopyWithImpl<$Res>
    implements _$SessionSettingsPatchDtoCopyWith<$Res> {
  __$SessionSettingsPatchDtoCopyWithImpl(this._self, this._then);

  final _SessionSettingsPatchDto _self;
  final $Res Function(_SessionSettingsPatchDto) _then;

/// Create a copy of SessionSettingsPatchDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hasModel = null,Object? model = freezed,Object? hasModelControls = null,Object? modelControls = null,Object? permissionMode = freezed,}) {
  return _then(_SessionSettingsPatchDto(
hasModel: null == hasModel ? _self.hasModel : hasModel // ignore: cast_nullable_to_non_nullable
as bool,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as ModelSelectionDto?,hasModelControls: null == hasModelControls ? _self.hasModelControls : hasModelControls // ignore: cast_nullable_to_non_nullable
as bool,modelControls: null == modelControls ? _self._modelControls : modelControls // ignore: cast_nullable_to_non_nullable
as Map<String, ModelControlValueDto>,permissionMode: freezed == permissionMode ? _self.permissionMode : permissionMode // ignore: cast_nullable_to_non_nullable
as PermissionMode?,
  ));
}

/// Create a copy of SessionSettingsPatchDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModelSelectionDtoCopyWith<$Res>? get model {
    if (_self.model == null) {
    return null;
  }

  return $ModelSelectionDtoCopyWith<$Res>(_self.model!, (value) {
    return _then(_self.copyWith(model: value));
  });
}
}


/// @nodoc
mixin _$SessionSettingsUpdateParamsDto {

 String get sessionId; SessionSettingsPatchDto get patch;
/// Create a copy of SessionSettingsUpdateParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionSettingsUpdateParamsDtoCopyWith<SessionSettingsUpdateParamsDto> get copyWith => _$SessionSettingsUpdateParamsDtoCopyWithImpl<SessionSettingsUpdateParamsDto>(this as SessionSettingsUpdateParamsDto, _$identity);

  /// Serializes this SessionSettingsUpdateParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionSettingsUpdateParamsDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.patch, patch) || other.patch == patch));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,patch);

@override
String toString() {
  return 'SessionSettingsUpdateParamsDto(sessionId: $sessionId, patch: $patch)';
}


}

/// @nodoc
abstract mixin class $SessionSettingsUpdateParamsDtoCopyWith<$Res>  {
  factory $SessionSettingsUpdateParamsDtoCopyWith(SessionSettingsUpdateParamsDto value, $Res Function(SessionSettingsUpdateParamsDto) _then) = _$SessionSettingsUpdateParamsDtoCopyWithImpl;
@useResult
$Res call({
 String sessionId, SessionSettingsPatchDto patch
});


$SessionSettingsPatchDtoCopyWith<$Res> get patch;

}
/// @nodoc
class _$SessionSettingsUpdateParamsDtoCopyWithImpl<$Res>
    implements $SessionSettingsUpdateParamsDtoCopyWith<$Res> {
  _$SessionSettingsUpdateParamsDtoCopyWithImpl(this._self, this._then);

  final SessionSettingsUpdateParamsDto _self;
  final $Res Function(SessionSettingsUpdateParamsDto) _then;

/// Create a copy of SessionSettingsUpdateParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? patch = null,}) {
  return _then(SessionSettingsUpdateParamsDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,patch: null == patch ? _self.patch : patch // ignore: cast_nullable_to_non_nullable
as SessionSettingsPatchDto,
  ));
}
/// Create a copy of SessionSettingsUpdateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionSettingsPatchDtoCopyWith<$Res> get patch {

  return $SessionSettingsPatchDtoCopyWith<$Res>(_self.patch, (value) {
    return _then(_self.copyWith(patch: value));
  });
}
}


/// Adds pattern-matching-related methods to [SessionSettingsUpdateParamsDto].
extension SessionSettingsUpdateParamsDtoPatterns on SessionSettingsUpdateParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionSettingsUpdateParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionSettingsUpdateParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionSettingsUpdateParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _SessionSettingsUpdateParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionSettingsUpdateParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _SessionSettingsUpdateParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sessionId,  SessionSettingsPatchDto patch)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionSettingsUpdateParamsDto() when $default != null:
return $default(_that.sessionId,_that.patch);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sessionId,  SessionSettingsPatchDto patch)  $default,) {final _that = this;
switch (_that) {
case _SessionSettingsUpdateParamsDto():
return $default(_that.sessionId,_that.patch);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sessionId,  SessionSettingsPatchDto patch)?  $default,) {final _that = this;
switch (_that) {
case _SessionSettingsUpdateParamsDto() when $default != null:
return $default(_that.sessionId,_that.patch);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SessionSettingsUpdateParamsDto implements SessionSettingsUpdateParamsDto {
  const _SessionSettingsUpdateParamsDto({required this.sessionId, required this.patch});
  factory _SessionSettingsUpdateParamsDto.fromJson(Map<String, dynamic> json) => _$SessionSettingsUpdateParamsDtoFromJson(json);

@override final  String sessionId;
@override final  SessionSettingsPatchDto patch;

/// Create a copy of SessionSettingsUpdateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionSettingsUpdateParamsDtoCopyWith<_SessionSettingsUpdateParamsDto> get copyWith => __$SessionSettingsUpdateParamsDtoCopyWithImpl<_SessionSettingsUpdateParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionSettingsUpdateParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionSettingsUpdateParamsDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.patch, patch) || other.patch == patch));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,patch);

@override
String toString() {
  return 'SessionSettingsUpdateParamsDto(sessionId: $sessionId, patch: $patch)';
}


}

/// @nodoc
abstract mixin class _$SessionSettingsUpdateParamsDtoCopyWith<$Res> implements $SessionSettingsUpdateParamsDtoCopyWith<$Res> {
  factory _$SessionSettingsUpdateParamsDtoCopyWith(_SessionSettingsUpdateParamsDto value, $Res Function(_SessionSettingsUpdateParamsDto) _then) = __$SessionSettingsUpdateParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, SessionSettingsPatchDto patch
});


@override $SessionSettingsPatchDtoCopyWith<$Res> get patch;

}
/// @nodoc
class __$SessionSettingsUpdateParamsDtoCopyWithImpl<$Res>
    implements _$SessionSettingsUpdateParamsDtoCopyWith<$Res> {
  __$SessionSettingsUpdateParamsDtoCopyWithImpl(this._self, this._then);

  final _SessionSettingsUpdateParamsDto _self;
  final $Res Function(_SessionSettingsUpdateParamsDto) _then;

/// Create a copy of SessionSettingsUpdateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? patch = null,}) {
  return _then(_SessionSettingsUpdateParamsDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,patch: null == patch ? _self.patch : patch // ignore: cast_nullable_to_non_nullable
as SessionSettingsPatchDto,
  ));
}

/// Create a copy of SessionSettingsUpdateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionSettingsPatchDtoCopyWith<$Res> get patch {

  return $SessionSettingsPatchDtoCopyWith<$Res>(_self.patch, (value) {
    return _then(_self.copyWith(patch: value));
  });
}
}


/// @nodoc
mixin _$AgentDefinitionIdParamsDto {

 String get id;
/// Create a copy of AgentDefinitionIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentDefinitionIdParamsDtoCopyWith<AgentDefinitionIdParamsDto> get copyWith => _$AgentDefinitionIdParamsDtoCopyWithImpl<AgentDefinitionIdParamsDto>(this as AgentDefinitionIdParamsDto, _$identity);

  /// Serializes this AgentDefinitionIdParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentDefinitionIdParamsDto&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'AgentDefinitionIdParamsDto(id: $id)';
}


}

/// @nodoc
abstract mixin class $AgentDefinitionIdParamsDtoCopyWith<$Res>  {
  factory $AgentDefinitionIdParamsDtoCopyWith(AgentDefinitionIdParamsDto value, $Res Function(AgentDefinitionIdParamsDto) _then) = _$AgentDefinitionIdParamsDtoCopyWithImpl;
@useResult
$Res call({
 String id
});




}
/// @nodoc
class _$AgentDefinitionIdParamsDtoCopyWithImpl<$Res>
    implements $AgentDefinitionIdParamsDtoCopyWith<$Res> {
  _$AgentDefinitionIdParamsDtoCopyWithImpl(this._self, this._then);

  final AgentDefinitionIdParamsDto _self;
  final $Res Function(AgentDefinitionIdParamsDto) _then;

/// Create a copy of AgentDefinitionIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,}) {
  return _then(AgentDefinitionIdParamsDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentDefinitionIdParamsDto].
extension AgentDefinitionIdParamsDtoPatterns on AgentDefinitionIdParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentDefinitionIdParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentDefinitionIdParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentDefinitionIdParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _AgentDefinitionIdParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentDefinitionIdParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _AgentDefinitionIdParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentDefinitionIdParamsDto() when $default != null:
return $default(_that.id);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id)  $default,) {final _that = this;
switch (_that) {
case _AgentDefinitionIdParamsDto():
return $default(_that.id);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id)?  $default,) {final _that = this;
switch (_that) {
case _AgentDefinitionIdParamsDto() when $default != null:
return $default(_that.id);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentDefinitionIdParamsDto implements AgentDefinitionIdParamsDto {
  const _AgentDefinitionIdParamsDto({required this.id});
  factory _AgentDefinitionIdParamsDto.fromJson(Map<String, dynamic> json) => _$AgentDefinitionIdParamsDtoFromJson(json);

@override final  String id;

/// Create a copy of AgentDefinitionIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentDefinitionIdParamsDtoCopyWith<_AgentDefinitionIdParamsDto> get copyWith => __$AgentDefinitionIdParamsDtoCopyWithImpl<_AgentDefinitionIdParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentDefinitionIdParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentDefinitionIdParamsDto&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'AgentDefinitionIdParamsDto(id: $id)';
}


}

/// @nodoc
abstract mixin class _$AgentDefinitionIdParamsDtoCopyWith<$Res> implements $AgentDefinitionIdParamsDtoCopyWith<$Res> {
  factory _$AgentDefinitionIdParamsDtoCopyWith(_AgentDefinitionIdParamsDto value, $Res Function(_AgentDefinitionIdParamsDto) _then) = __$AgentDefinitionIdParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String id
});




}
/// @nodoc
class __$AgentDefinitionIdParamsDtoCopyWithImpl<$Res>
    implements _$AgentDefinitionIdParamsDtoCopyWith<$Res> {
  __$AgentDefinitionIdParamsDtoCopyWithImpl(this._self, this._then);

  final _AgentDefinitionIdParamsDto _self;
  final $Res Function(_AgentDefinitionIdParamsDto) _then;

/// Create a copy of AgentDefinitionIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,}) {
  return _then(_AgentDefinitionIdParamsDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$AgentDefinitionCreateParamsDto {

 String get id; AgentDefinitionDto get definition;
/// Create a copy of AgentDefinitionCreateParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentDefinitionCreateParamsDtoCopyWith<AgentDefinitionCreateParamsDto> get copyWith => _$AgentDefinitionCreateParamsDtoCopyWithImpl<AgentDefinitionCreateParamsDto>(this as AgentDefinitionCreateParamsDto, _$identity);

  /// Serializes this AgentDefinitionCreateParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentDefinitionCreateParamsDto&&(identical(other.id, id) || other.id == id)&&(identical(other.definition, definition) || other.definition == definition));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,definition);

@override
String toString() {
  return 'AgentDefinitionCreateParamsDto(id: $id, definition: $definition)';
}


}

/// @nodoc
abstract mixin class $AgentDefinitionCreateParamsDtoCopyWith<$Res>  {
  factory $AgentDefinitionCreateParamsDtoCopyWith(AgentDefinitionCreateParamsDto value, $Res Function(AgentDefinitionCreateParamsDto) _then) = _$AgentDefinitionCreateParamsDtoCopyWithImpl;
@useResult
$Res call({
 String id, AgentDefinitionDto definition
});


$AgentDefinitionDtoCopyWith<$Res> get definition;

}
/// @nodoc
class _$AgentDefinitionCreateParamsDtoCopyWithImpl<$Res>
    implements $AgentDefinitionCreateParamsDtoCopyWith<$Res> {
  _$AgentDefinitionCreateParamsDtoCopyWithImpl(this._self, this._then);

  final AgentDefinitionCreateParamsDto _self;
  final $Res Function(AgentDefinitionCreateParamsDto) _then;

/// Create a copy of AgentDefinitionCreateParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? definition = null,}) {
  return _then(AgentDefinitionCreateParamsDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,definition: null == definition ? _self.definition : definition // ignore: cast_nullable_to_non_nullable
as AgentDefinitionDto,
  ));
}
/// Create a copy of AgentDefinitionCreateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentDefinitionDtoCopyWith<$Res> get definition {

  return $AgentDefinitionDtoCopyWith<$Res>(_self.definition, (value) {
    return _then(_self.copyWith(definition: value));
  });
}
}


/// Adds pattern-matching-related methods to [AgentDefinitionCreateParamsDto].
extension AgentDefinitionCreateParamsDtoPatterns on AgentDefinitionCreateParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentDefinitionCreateParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentDefinitionCreateParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentDefinitionCreateParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _AgentDefinitionCreateParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentDefinitionCreateParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _AgentDefinitionCreateParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  AgentDefinitionDto definition)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentDefinitionCreateParamsDto() when $default != null:
return $default(_that.id,_that.definition);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  AgentDefinitionDto definition)  $default,) {final _that = this;
switch (_that) {
case _AgentDefinitionCreateParamsDto():
return $default(_that.id,_that.definition);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  AgentDefinitionDto definition)?  $default,) {final _that = this;
switch (_that) {
case _AgentDefinitionCreateParamsDto() when $default != null:
return $default(_that.id,_that.definition);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentDefinitionCreateParamsDto implements AgentDefinitionCreateParamsDto {
  const _AgentDefinitionCreateParamsDto({required this.id, required this.definition});
  factory _AgentDefinitionCreateParamsDto.fromJson(Map<String, dynamic> json) => _$AgentDefinitionCreateParamsDtoFromJson(json);

@override final  String id;
@override final  AgentDefinitionDto definition;

/// Create a copy of AgentDefinitionCreateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentDefinitionCreateParamsDtoCopyWith<_AgentDefinitionCreateParamsDto> get copyWith => __$AgentDefinitionCreateParamsDtoCopyWithImpl<_AgentDefinitionCreateParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentDefinitionCreateParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentDefinitionCreateParamsDto&&(identical(other.id, id) || other.id == id)&&(identical(other.definition, definition) || other.definition == definition));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,definition);

@override
String toString() {
  return 'AgentDefinitionCreateParamsDto(id: $id, definition: $definition)';
}


}

/// @nodoc
abstract mixin class _$AgentDefinitionCreateParamsDtoCopyWith<$Res> implements $AgentDefinitionCreateParamsDtoCopyWith<$Res> {
  factory _$AgentDefinitionCreateParamsDtoCopyWith(_AgentDefinitionCreateParamsDto value, $Res Function(_AgentDefinitionCreateParamsDto) _then) = __$AgentDefinitionCreateParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, AgentDefinitionDto definition
});


@override $AgentDefinitionDtoCopyWith<$Res> get definition;

}
/// @nodoc
class __$AgentDefinitionCreateParamsDtoCopyWithImpl<$Res>
    implements _$AgentDefinitionCreateParamsDtoCopyWith<$Res> {
  __$AgentDefinitionCreateParamsDtoCopyWithImpl(this._self, this._then);

  final _AgentDefinitionCreateParamsDto _self;
  final $Res Function(_AgentDefinitionCreateParamsDto) _then;

/// Create a copy of AgentDefinitionCreateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? definition = null,}) {
  return _then(_AgentDefinitionCreateParamsDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,definition: null == definition ? _self.definition : definition // ignore: cast_nullable_to_non_nullable
as AgentDefinitionDto,
  ));
}

/// Create a copy of AgentDefinitionCreateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentDefinitionDtoCopyWith<$Res> get definition {

  return $AgentDefinitionDtoCopyWith<$Res>(_self.definition, (value) {
    return _then(_self.copyWith(definition: value));
  });
}
}


/// @nodoc
mixin _$AgentDefinitionUpdateParamsDto {

 AgentDefinitionDto get definition; String get expectedContentHash; bool get force;
/// Create a copy of AgentDefinitionUpdateParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentDefinitionUpdateParamsDtoCopyWith<AgentDefinitionUpdateParamsDto> get copyWith => _$AgentDefinitionUpdateParamsDtoCopyWithImpl<AgentDefinitionUpdateParamsDto>(this as AgentDefinitionUpdateParamsDto, _$identity);

  /// Serializes this AgentDefinitionUpdateParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentDefinitionUpdateParamsDto&&(identical(other.definition, definition) || other.definition == definition)&&(identical(other.expectedContentHash, expectedContentHash) || other.expectedContentHash == expectedContentHash)&&(identical(other.force, force) || other.force == force));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,definition,expectedContentHash,force);

@override
String toString() {
  return 'AgentDefinitionUpdateParamsDto(definition: $definition, expectedContentHash: $expectedContentHash, force: $force)';
}


}

/// @nodoc
abstract mixin class $AgentDefinitionUpdateParamsDtoCopyWith<$Res>  {
  factory $AgentDefinitionUpdateParamsDtoCopyWith(AgentDefinitionUpdateParamsDto value, $Res Function(AgentDefinitionUpdateParamsDto) _then) = _$AgentDefinitionUpdateParamsDtoCopyWithImpl;
@useResult
$Res call({
 AgentDefinitionDto definition, String expectedContentHash, bool force
});


$AgentDefinitionDtoCopyWith<$Res> get definition;

}
/// @nodoc
class _$AgentDefinitionUpdateParamsDtoCopyWithImpl<$Res>
    implements $AgentDefinitionUpdateParamsDtoCopyWith<$Res> {
  _$AgentDefinitionUpdateParamsDtoCopyWithImpl(this._self, this._then);

  final AgentDefinitionUpdateParamsDto _self;
  final $Res Function(AgentDefinitionUpdateParamsDto) _then;

/// Create a copy of AgentDefinitionUpdateParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? definition = null,Object? expectedContentHash = null,Object? force = null,}) {
  return _then(AgentDefinitionUpdateParamsDto(
definition: null == definition ? _self.definition : definition // ignore: cast_nullable_to_non_nullable
as AgentDefinitionDto,expectedContentHash: null == expectedContentHash ? _self.expectedContentHash : expectedContentHash // ignore: cast_nullable_to_non_nullable
as String,force: null == force ? _self.force : force // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of AgentDefinitionUpdateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentDefinitionDtoCopyWith<$Res> get definition {

  return $AgentDefinitionDtoCopyWith<$Res>(_self.definition, (value) {
    return _then(_self.copyWith(definition: value));
  });
}
}


/// Adds pattern-matching-related methods to [AgentDefinitionUpdateParamsDto].
extension AgentDefinitionUpdateParamsDtoPatterns on AgentDefinitionUpdateParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentDefinitionUpdateParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentDefinitionUpdateParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentDefinitionUpdateParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _AgentDefinitionUpdateParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentDefinitionUpdateParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _AgentDefinitionUpdateParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AgentDefinitionDto definition,  String expectedContentHash,  bool force)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentDefinitionUpdateParamsDto() when $default != null:
return $default(_that.definition,_that.expectedContentHash,_that.force);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AgentDefinitionDto definition,  String expectedContentHash,  bool force)  $default,) {final _that = this;
switch (_that) {
case _AgentDefinitionUpdateParamsDto():
return $default(_that.definition,_that.expectedContentHash,_that.force);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AgentDefinitionDto definition,  String expectedContentHash,  bool force)?  $default,) {final _that = this;
switch (_that) {
case _AgentDefinitionUpdateParamsDto() when $default != null:
return $default(_that.definition,_that.expectedContentHash,_that.force);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentDefinitionUpdateParamsDto implements AgentDefinitionUpdateParamsDto {
  const _AgentDefinitionUpdateParamsDto({required this.definition, required this.expectedContentHash, this.force = false});
  factory _AgentDefinitionUpdateParamsDto.fromJson(Map<String, dynamic> json) => _$AgentDefinitionUpdateParamsDtoFromJson(json);

@override final  AgentDefinitionDto definition;
@override final  String expectedContentHash;
@override@JsonKey() final  bool force;

/// Create a copy of AgentDefinitionUpdateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentDefinitionUpdateParamsDtoCopyWith<_AgentDefinitionUpdateParamsDto> get copyWith => __$AgentDefinitionUpdateParamsDtoCopyWithImpl<_AgentDefinitionUpdateParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentDefinitionUpdateParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentDefinitionUpdateParamsDto&&(identical(other.definition, definition) || other.definition == definition)&&(identical(other.expectedContentHash, expectedContentHash) || other.expectedContentHash == expectedContentHash)&&(identical(other.force, force) || other.force == force));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,definition,expectedContentHash,force);

@override
String toString() {
  return 'AgentDefinitionUpdateParamsDto(definition: $definition, expectedContentHash: $expectedContentHash, force: $force)';
}


}

/// @nodoc
abstract mixin class _$AgentDefinitionUpdateParamsDtoCopyWith<$Res> implements $AgentDefinitionUpdateParamsDtoCopyWith<$Res> {
  factory _$AgentDefinitionUpdateParamsDtoCopyWith(_AgentDefinitionUpdateParamsDto value, $Res Function(_AgentDefinitionUpdateParamsDto) _then) = __$AgentDefinitionUpdateParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 AgentDefinitionDto definition, String expectedContentHash, bool force
});


@override $AgentDefinitionDtoCopyWith<$Res> get definition;

}
/// @nodoc
class __$AgentDefinitionUpdateParamsDtoCopyWithImpl<$Res>
    implements _$AgentDefinitionUpdateParamsDtoCopyWith<$Res> {
  __$AgentDefinitionUpdateParamsDtoCopyWithImpl(this._self, this._then);

  final _AgentDefinitionUpdateParamsDto _self;
  final $Res Function(_AgentDefinitionUpdateParamsDto) _then;

/// Create a copy of AgentDefinitionUpdateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? definition = null,Object? expectedContentHash = null,Object? force = null,}) {
  return _then(_AgentDefinitionUpdateParamsDto(
definition: null == definition ? _self.definition : definition // ignore: cast_nullable_to_non_nullable
as AgentDefinitionDto,expectedContentHash: null == expectedContentHash ? _self.expectedContentHash : expectedContentHash // ignore: cast_nullable_to_non_nullable
as String,force: null == force ? _self.force : force // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of AgentDefinitionUpdateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentDefinitionDtoCopyWith<$Res> get definition {

  return $AgentDefinitionDtoCopyWith<$Res>(_self.definition, (value) {
    return _then(_self.copyWith(definition: value));
  });
}
}


/// @nodoc
mixin _$AgentDefinitionValidateParamsDto {

 String get id; String get markdown;
/// Create a copy of AgentDefinitionValidateParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentDefinitionValidateParamsDtoCopyWith<AgentDefinitionValidateParamsDto> get copyWith => _$AgentDefinitionValidateParamsDtoCopyWithImpl<AgentDefinitionValidateParamsDto>(this as AgentDefinitionValidateParamsDto, _$identity);

  /// Serializes this AgentDefinitionValidateParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentDefinitionValidateParamsDto&&(identical(other.id, id) || other.id == id)&&(identical(other.markdown, markdown) || other.markdown == markdown));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,markdown);

@override
String toString() {
  return 'AgentDefinitionValidateParamsDto(id: $id, markdown: $markdown)';
}


}

/// @nodoc
abstract mixin class $AgentDefinitionValidateParamsDtoCopyWith<$Res>  {
  factory $AgentDefinitionValidateParamsDtoCopyWith(AgentDefinitionValidateParamsDto value, $Res Function(AgentDefinitionValidateParamsDto) _then) = _$AgentDefinitionValidateParamsDtoCopyWithImpl;
@useResult
$Res call({
 String id, String markdown
});




}
/// @nodoc
class _$AgentDefinitionValidateParamsDtoCopyWithImpl<$Res>
    implements $AgentDefinitionValidateParamsDtoCopyWith<$Res> {
  _$AgentDefinitionValidateParamsDtoCopyWithImpl(this._self, this._then);

  final AgentDefinitionValidateParamsDto _self;
  final $Res Function(AgentDefinitionValidateParamsDto) _then;

/// Create a copy of AgentDefinitionValidateParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? markdown = null,}) {
  return _then(AgentDefinitionValidateParamsDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,markdown: null == markdown ? _self.markdown : markdown // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentDefinitionValidateParamsDto].
extension AgentDefinitionValidateParamsDtoPatterns on AgentDefinitionValidateParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentDefinitionValidateParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentDefinitionValidateParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentDefinitionValidateParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _AgentDefinitionValidateParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentDefinitionValidateParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _AgentDefinitionValidateParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String markdown)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentDefinitionValidateParamsDto() when $default != null:
return $default(_that.id,_that.markdown);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String markdown)  $default,) {final _that = this;
switch (_that) {
case _AgentDefinitionValidateParamsDto():
return $default(_that.id,_that.markdown);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String markdown)?  $default,) {final _that = this;
switch (_that) {
case _AgentDefinitionValidateParamsDto() when $default != null:
return $default(_that.id,_that.markdown);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentDefinitionValidateParamsDto implements AgentDefinitionValidateParamsDto {
  const _AgentDefinitionValidateParamsDto({required this.id, required this.markdown});
  factory _AgentDefinitionValidateParamsDto.fromJson(Map<String, dynamic> json) => _$AgentDefinitionValidateParamsDtoFromJson(json);

@override final  String id;
@override final  String markdown;

/// Create a copy of AgentDefinitionValidateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentDefinitionValidateParamsDtoCopyWith<_AgentDefinitionValidateParamsDto> get copyWith => __$AgentDefinitionValidateParamsDtoCopyWithImpl<_AgentDefinitionValidateParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentDefinitionValidateParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentDefinitionValidateParamsDto&&(identical(other.id, id) || other.id == id)&&(identical(other.markdown, markdown) || other.markdown == markdown));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,markdown);

@override
String toString() {
  return 'AgentDefinitionValidateParamsDto(id: $id, markdown: $markdown)';
}


}

/// @nodoc
abstract mixin class _$AgentDefinitionValidateParamsDtoCopyWith<$Res> implements $AgentDefinitionValidateParamsDtoCopyWith<$Res> {
  factory _$AgentDefinitionValidateParamsDtoCopyWith(_AgentDefinitionValidateParamsDto value, $Res Function(_AgentDefinitionValidateParamsDto) _then) = __$AgentDefinitionValidateParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String markdown
});




}
/// @nodoc
class __$AgentDefinitionValidateParamsDtoCopyWithImpl<$Res>
    implements _$AgentDefinitionValidateParamsDtoCopyWith<$Res> {
  __$AgentDefinitionValidateParamsDtoCopyWithImpl(this._self, this._then);

  final _AgentDefinitionValidateParamsDto _self;
  final $Res Function(_AgentDefinitionValidateParamsDto) _then;

/// Create a copy of AgentDefinitionValidateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? markdown = null,}) {
  return _then(_AgentDefinitionValidateParamsDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,markdown: null == markdown ? _self.markdown : markdown // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$PluginIdParamsDto {

 String get id;
/// Create a copy of PluginIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginIdParamsDtoCopyWith<PluginIdParamsDto> get copyWith => _$PluginIdParamsDtoCopyWithImpl<PluginIdParamsDto>(this as PluginIdParamsDto, _$identity);

  /// Serializes this PluginIdParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginIdParamsDto&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'PluginIdParamsDto(id: $id)';
}


}

/// @nodoc
abstract mixin class $PluginIdParamsDtoCopyWith<$Res>  {
  factory $PluginIdParamsDtoCopyWith(PluginIdParamsDto value, $Res Function(PluginIdParamsDto) _then) = _$PluginIdParamsDtoCopyWithImpl;
@useResult
$Res call({
 String id
});




}
/// @nodoc
class _$PluginIdParamsDtoCopyWithImpl<$Res>
    implements $PluginIdParamsDtoCopyWith<$Res> {
  _$PluginIdParamsDtoCopyWithImpl(this._self, this._then);

  final PluginIdParamsDto _self;
  final $Res Function(PluginIdParamsDto) _then;

/// Create a copy of PluginIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,}) {
  return _then(PluginIdParamsDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PluginIdParamsDto].
extension PluginIdParamsDtoPatterns on PluginIdParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginIdParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginIdParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginIdParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _PluginIdParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginIdParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _PluginIdParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginIdParamsDto() when $default != null:
return $default(_that.id);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id)  $default,) {final _that = this;
switch (_that) {
case _PluginIdParamsDto():
return $default(_that.id);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id)?  $default,) {final _that = this;
switch (_that) {
case _PluginIdParamsDto() when $default != null:
return $default(_that.id);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PluginIdParamsDto implements PluginIdParamsDto {
  const _PluginIdParamsDto({required this.id});
  factory _PluginIdParamsDto.fromJson(Map<String, dynamic> json) => _$PluginIdParamsDtoFromJson(json);

@override final  String id;

/// Create a copy of PluginIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginIdParamsDtoCopyWith<_PluginIdParamsDto> get copyWith => __$PluginIdParamsDtoCopyWithImpl<_PluginIdParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginIdParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginIdParamsDto&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'PluginIdParamsDto(id: $id)';
}


}

/// @nodoc
abstract mixin class _$PluginIdParamsDtoCopyWith<$Res> implements $PluginIdParamsDtoCopyWith<$Res> {
  factory _$PluginIdParamsDtoCopyWith(_PluginIdParamsDto value, $Res Function(_PluginIdParamsDto) _then) = __$PluginIdParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String id
});




}
/// @nodoc
class __$PluginIdParamsDtoCopyWithImpl<$Res>
    implements _$PluginIdParamsDtoCopyWith<$Res> {
  __$PluginIdParamsDtoCopyWithImpl(this._self, this._then);

  final _PluginIdParamsDto _self;
  final $Res Function(_PluginIdParamsDto) _then;

/// Create a copy of PluginIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,}) {
  return _then(_PluginIdParamsDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$PluginReloadParamsDto {

 String get id; String get agentId;
/// Create a copy of PluginReloadParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginReloadParamsDtoCopyWith<PluginReloadParamsDto> get copyWith => _$PluginReloadParamsDtoCopyWithImpl<PluginReloadParamsDto>(this as PluginReloadParamsDto, _$identity);

  /// Serializes this PluginReloadParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginReloadParamsDto&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId);

@override
String toString() {
  return 'PluginReloadParamsDto(id: $id, agentId: $agentId)';
}


}

/// @nodoc
abstract mixin class $PluginReloadParamsDtoCopyWith<$Res>  {
  factory $PluginReloadParamsDtoCopyWith(PluginReloadParamsDto value, $Res Function(PluginReloadParamsDto) _then) = _$PluginReloadParamsDtoCopyWithImpl;
@useResult
$Res call({
 String id, String agentId
});




}
/// @nodoc
class _$PluginReloadParamsDtoCopyWithImpl<$Res>
    implements $PluginReloadParamsDtoCopyWith<$Res> {
  _$PluginReloadParamsDtoCopyWithImpl(this._self, this._then);

  final PluginReloadParamsDto _self;
  final $Res Function(PluginReloadParamsDto) _then;

/// Create a copy of PluginReloadParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? agentId = null,}) {
  return _then(PluginReloadParamsDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PluginReloadParamsDto].
extension PluginReloadParamsDtoPatterns on PluginReloadParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginReloadParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginReloadParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginReloadParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _PluginReloadParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginReloadParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _PluginReloadParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String agentId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginReloadParamsDto() when $default != null:
return $default(_that.id,_that.agentId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String agentId)  $default,) {final _that = this;
switch (_that) {
case _PluginReloadParamsDto():
return $default(_that.id,_that.agentId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String agentId)?  $default,) {final _that = this;
switch (_that) {
case _PluginReloadParamsDto() when $default != null:
return $default(_that.id,_that.agentId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PluginReloadParamsDto implements PluginReloadParamsDto {
  const _PluginReloadParamsDto({required this.id, required this.agentId});
  factory _PluginReloadParamsDto.fromJson(Map<String, dynamic> json) => _$PluginReloadParamsDtoFromJson(json);

@override final  String id;
@override final  String agentId;

/// Create a copy of PluginReloadParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginReloadParamsDtoCopyWith<_PluginReloadParamsDto> get copyWith => __$PluginReloadParamsDtoCopyWithImpl<_PluginReloadParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginReloadParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginReloadParamsDto&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId);

@override
String toString() {
  return 'PluginReloadParamsDto(id: $id, agentId: $agentId)';
}


}

/// @nodoc
abstract mixin class _$PluginReloadParamsDtoCopyWith<$Res> implements $PluginReloadParamsDtoCopyWith<$Res> {
  factory _$PluginReloadParamsDtoCopyWith(_PluginReloadParamsDto value, $Res Function(_PluginReloadParamsDto) _then) = __$PluginReloadParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId
});




}
/// @nodoc
class __$PluginReloadParamsDtoCopyWithImpl<$Res>
    implements _$PluginReloadParamsDtoCopyWith<$Res> {
  __$PluginReloadParamsDtoCopyWithImpl(this._self, this._then);

  final _PluginReloadParamsDto _self;
  final $Res Function(_PluginReloadParamsDto) _then;

/// Create a copy of PluginReloadParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,}) {
  return _then(_PluginReloadParamsDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$PluginScaffoldParamsDto {

 String get id; String get name;
/// Create a copy of PluginScaffoldParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginScaffoldParamsDtoCopyWith<PluginScaffoldParamsDto> get copyWith => _$PluginScaffoldParamsDtoCopyWithImpl<PluginScaffoldParamsDto>(this as PluginScaffoldParamsDto, _$identity);

  /// Serializes this PluginScaffoldParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginScaffoldParamsDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name);

@override
String toString() {
  return 'PluginScaffoldParamsDto(id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class $PluginScaffoldParamsDtoCopyWith<$Res>  {
  factory $PluginScaffoldParamsDtoCopyWith(PluginScaffoldParamsDto value, $Res Function(PluginScaffoldParamsDto) _then) = _$PluginScaffoldParamsDtoCopyWithImpl;
@useResult
$Res call({
 String id, String name
});




}
/// @nodoc
class _$PluginScaffoldParamsDtoCopyWithImpl<$Res>
    implements $PluginScaffoldParamsDtoCopyWith<$Res> {
  _$PluginScaffoldParamsDtoCopyWithImpl(this._self, this._then);

  final PluginScaffoldParamsDto _self;
  final $Res Function(PluginScaffoldParamsDto) _then;

/// Create a copy of PluginScaffoldParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,}) {
  return _then(PluginScaffoldParamsDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PluginScaffoldParamsDto].
extension PluginScaffoldParamsDtoPatterns on PluginScaffoldParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginScaffoldParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginScaffoldParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginScaffoldParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _PluginScaffoldParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginScaffoldParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _PluginScaffoldParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginScaffoldParamsDto() when $default != null:
return $default(_that.id,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name)  $default,) {final _that = this;
switch (_that) {
case _PluginScaffoldParamsDto():
return $default(_that.id,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name)?  $default,) {final _that = this;
switch (_that) {
case _PluginScaffoldParamsDto() when $default != null:
return $default(_that.id,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PluginScaffoldParamsDto implements PluginScaffoldParamsDto {
  const _PluginScaffoldParamsDto({required this.id, required this.name});
  factory _PluginScaffoldParamsDto.fromJson(Map<String, dynamic> json) => _$PluginScaffoldParamsDtoFromJson(json);

@override final  String id;
@override final  String name;

/// Create a copy of PluginScaffoldParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginScaffoldParamsDtoCopyWith<_PluginScaffoldParamsDto> get copyWith => __$PluginScaffoldParamsDtoCopyWithImpl<_PluginScaffoldParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginScaffoldParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginScaffoldParamsDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name);

@override
String toString() {
  return 'PluginScaffoldParamsDto(id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class _$PluginScaffoldParamsDtoCopyWith<$Res> implements $PluginScaffoldParamsDtoCopyWith<$Res> {
  factory _$PluginScaffoldParamsDtoCopyWith(_PluginScaffoldParamsDto value, $Res Function(_PluginScaffoldParamsDto) _then) = __$PluginScaffoldParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String name
});




}
/// @nodoc
class __$PluginScaffoldParamsDtoCopyWithImpl<$Res>
    implements _$PluginScaffoldParamsDtoCopyWith<$Res> {
  __$PluginScaffoldParamsDtoCopyWithImpl(this._self, this._then);

  final _PluginScaffoldParamsDto _self;
  final $Res Function(_PluginScaffoldParamsDto) _then;

/// Create a copy of PluginScaffoldParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,}) {
  return _then(_PluginScaffoldParamsDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$PluginForkParamsDto {

 String get sourceId; String get id; String get name;
/// Create a copy of PluginForkParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginForkParamsDtoCopyWith<PluginForkParamsDto> get copyWith => _$PluginForkParamsDtoCopyWithImpl<PluginForkParamsDto>(this as PluginForkParamsDto, _$identity);

  /// Serializes this PluginForkParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginForkParamsDto&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sourceId,id,name);

@override
String toString() {
  return 'PluginForkParamsDto(sourceId: $sourceId, id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class $PluginForkParamsDtoCopyWith<$Res>  {
  factory $PluginForkParamsDtoCopyWith(PluginForkParamsDto value, $Res Function(PluginForkParamsDto) _then) = _$PluginForkParamsDtoCopyWithImpl;
@useResult
$Res call({
 String sourceId, String id, String name
});




}
/// @nodoc
class _$PluginForkParamsDtoCopyWithImpl<$Res>
    implements $PluginForkParamsDtoCopyWith<$Res> {
  _$PluginForkParamsDtoCopyWithImpl(this._self, this._then);

  final PluginForkParamsDto _self;
  final $Res Function(PluginForkParamsDto) _then;

/// Create a copy of PluginForkParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sourceId = null,Object? id = null,Object? name = null,}) {
  return _then(PluginForkParamsDto(
sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PluginForkParamsDto].
extension PluginForkParamsDtoPatterns on PluginForkParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginForkParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginForkParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginForkParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _PluginForkParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginForkParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _PluginForkParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sourceId,  String id,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginForkParamsDto() when $default != null:
return $default(_that.sourceId,_that.id,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sourceId,  String id,  String name)  $default,) {final _that = this;
switch (_that) {
case _PluginForkParamsDto():
return $default(_that.sourceId,_that.id,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sourceId,  String id,  String name)?  $default,) {final _that = this;
switch (_that) {
case _PluginForkParamsDto() when $default != null:
return $default(_that.sourceId,_that.id,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PluginForkParamsDto implements PluginForkParamsDto {
  const _PluginForkParamsDto({required this.sourceId, required this.id, required this.name});
  factory _PluginForkParamsDto.fromJson(Map<String, dynamic> json) => _$PluginForkParamsDtoFromJson(json);

@override final  String sourceId;
@override final  String id;
@override final  String name;

/// Create a copy of PluginForkParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginForkParamsDtoCopyWith<_PluginForkParamsDto> get copyWith => __$PluginForkParamsDtoCopyWithImpl<_PluginForkParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginForkParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginForkParamsDto&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sourceId,id,name);

@override
String toString() {
  return 'PluginForkParamsDto(sourceId: $sourceId, id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class _$PluginForkParamsDtoCopyWith<$Res> implements $PluginForkParamsDtoCopyWith<$Res> {
  factory _$PluginForkParamsDtoCopyWith(_PluginForkParamsDto value, $Res Function(_PluginForkParamsDto) _then) = __$PluginForkParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String sourceId, String id, String name
});




}
/// @nodoc
class __$PluginForkParamsDtoCopyWithImpl<$Res>
    implements _$PluginForkParamsDtoCopyWith<$Res> {
  __$PluginForkParamsDtoCopyWithImpl(this._self, this._then);

  final _PluginForkParamsDto _self;
  final $Res Function(_PluginForkParamsDto) _then;

/// Create a copy of PluginForkParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sourceId = null,Object? id = null,Object? name = null,}) {
  return _then(_PluginForkParamsDto(
sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$AgentPluginGrantsParamsDto {

 String get agentId;
/// Create a copy of AgentPluginGrantsParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentPluginGrantsParamsDtoCopyWith<AgentPluginGrantsParamsDto> get copyWith => _$AgentPluginGrantsParamsDtoCopyWithImpl<AgentPluginGrantsParamsDto>(this as AgentPluginGrantsParamsDto, _$identity);

  /// Serializes this AgentPluginGrantsParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentPluginGrantsParamsDto&&(identical(other.agentId, agentId) || other.agentId == agentId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,agentId);

@override
String toString() {
  return 'AgentPluginGrantsParamsDto(agentId: $agentId)';
}


}

/// @nodoc
abstract mixin class $AgentPluginGrantsParamsDtoCopyWith<$Res>  {
  factory $AgentPluginGrantsParamsDtoCopyWith(AgentPluginGrantsParamsDto value, $Res Function(AgentPluginGrantsParamsDto) _then) = _$AgentPluginGrantsParamsDtoCopyWithImpl;
@useResult
$Res call({
 String agentId
});




}
/// @nodoc
class _$AgentPluginGrantsParamsDtoCopyWithImpl<$Res>
    implements $AgentPluginGrantsParamsDtoCopyWith<$Res> {
  _$AgentPluginGrantsParamsDtoCopyWithImpl(this._self, this._then);

  final AgentPluginGrantsParamsDto _self;
  final $Res Function(AgentPluginGrantsParamsDto) _then;

/// Create a copy of AgentPluginGrantsParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? agentId = null,}) {
  return _then(AgentPluginGrantsParamsDto(
agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentPluginGrantsParamsDto].
extension AgentPluginGrantsParamsDtoPatterns on AgentPluginGrantsParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentPluginGrantsParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentPluginGrantsParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentPluginGrantsParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _AgentPluginGrantsParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentPluginGrantsParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _AgentPluginGrantsParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String agentId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentPluginGrantsParamsDto() when $default != null:
return $default(_that.agentId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String agentId)  $default,) {final _that = this;
switch (_that) {
case _AgentPluginGrantsParamsDto():
return $default(_that.agentId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String agentId)?  $default,) {final _that = this;
switch (_that) {
case _AgentPluginGrantsParamsDto() when $default != null:
return $default(_that.agentId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentPluginGrantsParamsDto implements AgentPluginGrantsParamsDto {
  const _AgentPluginGrantsParamsDto({required this.agentId});
  factory _AgentPluginGrantsParamsDto.fromJson(Map<String, dynamic> json) => _$AgentPluginGrantsParamsDtoFromJson(json);

@override final  String agentId;

/// Create a copy of AgentPluginGrantsParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentPluginGrantsParamsDtoCopyWith<_AgentPluginGrantsParamsDto> get copyWith => __$AgentPluginGrantsParamsDtoCopyWithImpl<_AgentPluginGrantsParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentPluginGrantsParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentPluginGrantsParamsDto&&(identical(other.agentId, agentId) || other.agentId == agentId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,agentId);

@override
String toString() {
  return 'AgentPluginGrantsParamsDto(agentId: $agentId)';
}


}

/// @nodoc
abstract mixin class _$AgentPluginGrantsParamsDtoCopyWith<$Res> implements $AgentPluginGrantsParamsDtoCopyWith<$Res> {
  factory _$AgentPluginGrantsParamsDtoCopyWith(_AgentPluginGrantsParamsDto value, $Res Function(_AgentPluginGrantsParamsDto) _then) = __$AgentPluginGrantsParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String agentId
});




}
/// @nodoc
class __$AgentPluginGrantsParamsDtoCopyWithImpl<$Res>
    implements _$AgentPluginGrantsParamsDtoCopyWith<$Res> {
  __$AgentPluginGrantsParamsDtoCopyWithImpl(this._self, this._then);

  final _AgentPluginGrantsParamsDto _self;
  final $Res Function(_AgentPluginGrantsParamsDto) _then;

/// Create a copy of AgentPluginGrantsParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? agentId = null,}) {
  return _then(_AgentPluginGrantsParamsDto(
agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$PluginGrantParamsDto {

 AgentPluginGrantDto get grant;
/// Create a copy of PluginGrantParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginGrantParamsDtoCopyWith<PluginGrantParamsDto> get copyWith => _$PluginGrantParamsDtoCopyWithImpl<PluginGrantParamsDto>(this as PluginGrantParamsDto, _$identity);

  /// Serializes this PluginGrantParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginGrantParamsDto&&(identical(other.grant, grant) || other.grant == grant));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,grant);

@override
String toString() {
  return 'PluginGrantParamsDto(grant: $grant)';
}


}

/// @nodoc
abstract mixin class $PluginGrantParamsDtoCopyWith<$Res>  {
  factory $PluginGrantParamsDtoCopyWith(PluginGrantParamsDto value, $Res Function(PluginGrantParamsDto) _then) = _$PluginGrantParamsDtoCopyWithImpl;
@useResult
$Res call({
 AgentPluginGrantDto grant
});


$AgentPluginGrantDtoCopyWith<$Res> get grant;

}
/// @nodoc
class _$PluginGrantParamsDtoCopyWithImpl<$Res>
    implements $PluginGrantParamsDtoCopyWith<$Res> {
  _$PluginGrantParamsDtoCopyWithImpl(this._self, this._then);

  final PluginGrantParamsDto _self;
  final $Res Function(PluginGrantParamsDto) _then;

/// Create a copy of PluginGrantParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? grant = null,}) {
  return _then(PluginGrantParamsDto(
grant: null == grant ? _self.grant : grant // ignore: cast_nullable_to_non_nullable
as AgentPluginGrantDto,
  ));
}
/// Create a copy of PluginGrantParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentPluginGrantDtoCopyWith<$Res> get grant {

  return $AgentPluginGrantDtoCopyWith<$Res>(_self.grant, (value) {
    return _then(_self.copyWith(grant: value));
  });
}
}


/// Adds pattern-matching-related methods to [PluginGrantParamsDto].
extension PluginGrantParamsDtoPatterns on PluginGrantParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginGrantParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginGrantParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginGrantParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _PluginGrantParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginGrantParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _PluginGrantParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AgentPluginGrantDto grant)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginGrantParamsDto() when $default != null:
return $default(_that.grant);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AgentPluginGrantDto grant)  $default,) {final _that = this;
switch (_that) {
case _PluginGrantParamsDto():
return $default(_that.grant);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AgentPluginGrantDto grant)?  $default,) {final _that = this;
switch (_that) {
case _PluginGrantParamsDto() when $default != null:
return $default(_that.grant);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PluginGrantParamsDto implements PluginGrantParamsDto {
  const _PluginGrantParamsDto({required this.grant});
  factory _PluginGrantParamsDto.fromJson(Map<String, dynamic> json) => _$PluginGrantParamsDtoFromJson(json);

@override final  AgentPluginGrantDto grant;

/// Create a copy of PluginGrantParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginGrantParamsDtoCopyWith<_PluginGrantParamsDto> get copyWith => __$PluginGrantParamsDtoCopyWithImpl<_PluginGrantParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginGrantParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginGrantParamsDto&&(identical(other.grant, grant) || other.grant == grant));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,grant);

@override
String toString() {
  return 'PluginGrantParamsDto(grant: $grant)';
}


}

/// @nodoc
abstract mixin class _$PluginGrantParamsDtoCopyWith<$Res> implements $PluginGrantParamsDtoCopyWith<$Res> {
  factory _$PluginGrantParamsDtoCopyWith(_PluginGrantParamsDto value, $Res Function(_PluginGrantParamsDto) _then) = __$PluginGrantParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 AgentPluginGrantDto grant
});


@override $AgentPluginGrantDtoCopyWith<$Res> get grant;

}
/// @nodoc
class __$PluginGrantParamsDtoCopyWithImpl<$Res>
    implements _$PluginGrantParamsDtoCopyWith<$Res> {
  __$PluginGrantParamsDtoCopyWithImpl(this._self, this._then);

  final _PluginGrantParamsDto _self;
  final $Res Function(_PluginGrantParamsDto) _then;

/// Create a copy of PluginGrantParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? grant = null,}) {
  return _then(_PluginGrantParamsDto(
grant: null == grant ? _self.grant : grant // ignore: cast_nullable_to_non_nullable
as AgentPluginGrantDto,
  ));
}

/// Create a copy of PluginGrantParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentPluginGrantDtoCopyWith<$Res> get grant {

  return $AgentPluginGrantDtoCopyWith<$Res>(_self.grant, (value) {
    return _then(_self.copyWith(grant: value));
  });
}
}


/// @nodoc
mixin _$PluginSecretSetParamsDto {

 String get agentId; String get pluginId; String get name; String get value;
/// Create a copy of PluginSecretSetParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginSecretSetParamsDtoCopyWith<PluginSecretSetParamsDto> get copyWith => _$PluginSecretSetParamsDtoCopyWithImpl<PluginSecretSetParamsDto>(this as PluginSecretSetParamsDto, _$identity);

  /// Serializes this PluginSecretSetParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginSecretSetParamsDto&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.name, name) || other.name == name)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,agentId,pluginId,name,value);

@override
String toString() {
  return 'PluginSecretSetParamsDto(agentId: $agentId, pluginId: $pluginId, name: $name, value: $value)';
}


}

/// @nodoc
abstract mixin class $PluginSecretSetParamsDtoCopyWith<$Res>  {
  factory $PluginSecretSetParamsDtoCopyWith(PluginSecretSetParamsDto value, $Res Function(PluginSecretSetParamsDto) _then) = _$PluginSecretSetParamsDtoCopyWithImpl;
@useResult
$Res call({
 String agentId, String pluginId, String name, String value
});




}
/// @nodoc
class _$PluginSecretSetParamsDtoCopyWithImpl<$Res>
    implements $PluginSecretSetParamsDtoCopyWith<$Res> {
  _$PluginSecretSetParamsDtoCopyWithImpl(this._self, this._then);

  final PluginSecretSetParamsDto _self;
  final $Res Function(PluginSecretSetParamsDto) _then;

/// Create a copy of PluginSecretSetParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? agentId = null,Object? pluginId = null,Object? name = null,Object? value = null,}) {
  return _then(PluginSecretSetParamsDto(
agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PluginSecretSetParamsDto].
extension PluginSecretSetParamsDtoPatterns on PluginSecretSetParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginSecretSetParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginSecretSetParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginSecretSetParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _PluginSecretSetParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginSecretSetParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _PluginSecretSetParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String agentId,  String pluginId,  String name,  String value)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginSecretSetParamsDto() when $default != null:
return $default(_that.agentId,_that.pluginId,_that.name,_that.value);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String agentId,  String pluginId,  String name,  String value)  $default,) {final _that = this;
switch (_that) {
case _PluginSecretSetParamsDto():
return $default(_that.agentId,_that.pluginId,_that.name,_that.value);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String agentId,  String pluginId,  String name,  String value)?  $default,) {final _that = this;
switch (_that) {
case _PluginSecretSetParamsDto() when $default != null:
return $default(_that.agentId,_that.pluginId,_that.name,_that.value);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PluginSecretSetParamsDto implements PluginSecretSetParamsDto {
  const _PluginSecretSetParamsDto({required this.agentId, required this.pluginId, required this.name, required this.value});
  factory _PluginSecretSetParamsDto.fromJson(Map<String, dynamic> json) => _$PluginSecretSetParamsDtoFromJson(json);

@override final  String agentId;
@override final  String pluginId;
@override final  String name;
@override final  String value;

/// Create a copy of PluginSecretSetParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginSecretSetParamsDtoCopyWith<_PluginSecretSetParamsDto> get copyWith => __$PluginSecretSetParamsDtoCopyWithImpl<_PluginSecretSetParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginSecretSetParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginSecretSetParamsDto&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.name, name) || other.name == name)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,agentId,pluginId,name,value);

@override
String toString() {
  return 'PluginSecretSetParamsDto(agentId: $agentId, pluginId: $pluginId, name: $name, value: $value)';
}


}

/// @nodoc
abstract mixin class _$PluginSecretSetParamsDtoCopyWith<$Res> implements $PluginSecretSetParamsDtoCopyWith<$Res> {
  factory _$PluginSecretSetParamsDtoCopyWith(_PluginSecretSetParamsDto value, $Res Function(_PluginSecretSetParamsDto) _then) = __$PluginSecretSetParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String agentId, String pluginId, String name, String value
});




}
/// @nodoc
class __$PluginSecretSetParamsDtoCopyWithImpl<$Res>
    implements _$PluginSecretSetParamsDtoCopyWith<$Res> {
  __$PluginSecretSetParamsDtoCopyWithImpl(this._self, this._then);

  final _PluginSecretSetParamsDto _self;
  final $Res Function(_PluginSecretSetParamsDto) _then;

/// Create a copy of PluginSecretSetParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? agentId = null,Object? pluginId = null,Object? name = null,Object? value = null,}) {
  return _then(_PluginSecretSetParamsDto(
agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$PluginSecretRemoveParamsDto {

 String get agentId; String get pluginId; String get name;
/// Create a copy of PluginSecretRemoveParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginSecretRemoveParamsDtoCopyWith<PluginSecretRemoveParamsDto> get copyWith => _$PluginSecretRemoveParamsDtoCopyWithImpl<PluginSecretRemoveParamsDto>(this as PluginSecretRemoveParamsDto, _$identity);

  /// Serializes this PluginSecretRemoveParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginSecretRemoveParamsDto&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,agentId,pluginId,name);

@override
String toString() {
  return 'PluginSecretRemoveParamsDto(agentId: $agentId, pluginId: $pluginId, name: $name)';
}


}

/// @nodoc
abstract mixin class $PluginSecretRemoveParamsDtoCopyWith<$Res>  {
  factory $PluginSecretRemoveParamsDtoCopyWith(PluginSecretRemoveParamsDto value, $Res Function(PluginSecretRemoveParamsDto) _then) = _$PluginSecretRemoveParamsDtoCopyWithImpl;
@useResult
$Res call({
 String agentId, String pluginId, String name
});




}
/// @nodoc
class _$PluginSecretRemoveParamsDtoCopyWithImpl<$Res>
    implements $PluginSecretRemoveParamsDtoCopyWith<$Res> {
  _$PluginSecretRemoveParamsDtoCopyWithImpl(this._self, this._then);

  final PluginSecretRemoveParamsDto _self;
  final $Res Function(PluginSecretRemoveParamsDto) _then;

/// Create a copy of PluginSecretRemoveParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? agentId = null,Object? pluginId = null,Object? name = null,}) {
  return _then(PluginSecretRemoveParamsDto(
agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PluginSecretRemoveParamsDto].
extension PluginSecretRemoveParamsDtoPatterns on PluginSecretRemoveParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginSecretRemoveParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginSecretRemoveParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginSecretRemoveParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _PluginSecretRemoveParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginSecretRemoveParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _PluginSecretRemoveParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String agentId,  String pluginId,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginSecretRemoveParamsDto() when $default != null:
return $default(_that.agentId,_that.pluginId,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String agentId,  String pluginId,  String name)  $default,) {final _that = this;
switch (_that) {
case _PluginSecretRemoveParamsDto():
return $default(_that.agentId,_that.pluginId,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String agentId,  String pluginId,  String name)?  $default,) {final _that = this;
switch (_that) {
case _PluginSecretRemoveParamsDto() when $default != null:
return $default(_that.agentId,_that.pluginId,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PluginSecretRemoveParamsDto implements PluginSecretRemoveParamsDto {
  const _PluginSecretRemoveParamsDto({required this.agentId, required this.pluginId, required this.name});
  factory _PluginSecretRemoveParamsDto.fromJson(Map<String, dynamic> json) => _$PluginSecretRemoveParamsDtoFromJson(json);

@override final  String agentId;
@override final  String pluginId;
@override final  String name;

/// Create a copy of PluginSecretRemoveParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginSecretRemoveParamsDtoCopyWith<_PluginSecretRemoveParamsDto> get copyWith => __$PluginSecretRemoveParamsDtoCopyWithImpl<_PluginSecretRemoveParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginSecretRemoveParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginSecretRemoveParamsDto&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,agentId,pluginId,name);

@override
String toString() {
  return 'PluginSecretRemoveParamsDto(agentId: $agentId, pluginId: $pluginId, name: $name)';
}


}

/// @nodoc
abstract mixin class _$PluginSecretRemoveParamsDtoCopyWith<$Res> implements $PluginSecretRemoveParamsDtoCopyWith<$Res> {
  factory _$PluginSecretRemoveParamsDtoCopyWith(_PluginSecretRemoveParamsDto value, $Res Function(_PluginSecretRemoveParamsDto) _then) = __$PluginSecretRemoveParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String agentId, String pluginId, String name
});




}
/// @nodoc
class __$PluginSecretRemoveParamsDtoCopyWithImpl<$Res>
    implements _$PluginSecretRemoveParamsDtoCopyWith<$Res> {
  __$PluginSecretRemoveParamsDtoCopyWithImpl(this._self, this._then);

  final _PluginSecretRemoveParamsDto _self;
  final $Res Function(_PluginSecretRemoveParamsDto) _then;

/// Create a copy of PluginSecretRemoveParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? agentId = null,Object? pluginId = null,Object? name = null,}) {
  return _then(_PluginSecretRemoveParamsDto(
agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$PluginSessionControlParamsDto {

 String get sessionId; String get pluginId; String get contributionId;
/// Create a copy of PluginSessionControlParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginSessionControlParamsDtoCopyWith<PluginSessionControlParamsDto> get copyWith => _$PluginSessionControlParamsDtoCopyWithImpl<PluginSessionControlParamsDto>(this as PluginSessionControlParamsDto, _$identity);

  /// Serializes this PluginSessionControlParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginSessionControlParamsDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.contributionId, contributionId) || other.contributionId == contributionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,pluginId,contributionId);

@override
String toString() {
  return 'PluginSessionControlParamsDto(sessionId: $sessionId, pluginId: $pluginId, contributionId: $contributionId)';
}


}

/// @nodoc
abstract mixin class $PluginSessionControlParamsDtoCopyWith<$Res>  {
  factory $PluginSessionControlParamsDtoCopyWith(PluginSessionControlParamsDto value, $Res Function(PluginSessionControlParamsDto) _then) = _$PluginSessionControlParamsDtoCopyWithImpl;
@useResult
$Res call({
 String sessionId, String pluginId, String contributionId
});




}
/// @nodoc
class _$PluginSessionControlParamsDtoCopyWithImpl<$Res>
    implements $PluginSessionControlParamsDtoCopyWith<$Res> {
  _$PluginSessionControlParamsDtoCopyWithImpl(this._self, this._then);

  final PluginSessionControlParamsDto _self;
  final $Res Function(PluginSessionControlParamsDto) _then;

/// Create a copy of PluginSessionControlParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? pluginId = null,Object? contributionId = null,}) {
  return _then(PluginSessionControlParamsDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,contributionId: null == contributionId ? _self.contributionId : contributionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PluginSessionControlParamsDto].
extension PluginSessionControlParamsDtoPatterns on PluginSessionControlParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginSessionControlParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginSessionControlParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginSessionControlParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _PluginSessionControlParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginSessionControlParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _PluginSessionControlParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sessionId,  String pluginId,  String contributionId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginSessionControlParamsDto() when $default != null:
return $default(_that.sessionId,_that.pluginId,_that.contributionId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sessionId,  String pluginId,  String contributionId)  $default,) {final _that = this;
switch (_that) {
case _PluginSessionControlParamsDto():
return $default(_that.sessionId,_that.pluginId,_that.contributionId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sessionId,  String pluginId,  String contributionId)?  $default,) {final _that = this;
switch (_that) {
case _PluginSessionControlParamsDto() when $default != null:
return $default(_that.sessionId,_that.pluginId,_that.contributionId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PluginSessionControlParamsDto implements PluginSessionControlParamsDto {
  const _PluginSessionControlParamsDto({required this.sessionId, required this.pluginId, required this.contributionId});
  factory _PluginSessionControlParamsDto.fromJson(Map<String, dynamic> json) => _$PluginSessionControlParamsDtoFromJson(json);

@override final  String sessionId;
@override final  String pluginId;
@override final  String contributionId;

/// Create a copy of PluginSessionControlParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginSessionControlParamsDtoCopyWith<_PluginSessionControlParamsDto> get copyWith => __$PluginSessionControlParamsDtoCopyWithImpl<_PluginSessionControlParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginSessionControlParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginSessionControlParamsDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.contributionId, contributionId) || other.contributionId == contributionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,pluginId,contributionId);

@override
String toString() {
  return 'PluginSessionControlParamsDto(sessionId: $sessionId, pluginId: $pluginId, contributionId: $contributionId)';
}


}

/// @nodoc
abstract mixin class _$PluginSessionControlParamsDtoCopyWith<$Res> implements $PluginSessionControlParamsDtoCopyWith<$Res> {
  factory _$PluginSessionControlParamsDtoCopyWith(_PluginSessionControlParamsDto value, $Res Function(_PluginSessionControlParamsDto) _then) = __$PluginSessionControlParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, String pluginId, String contributionId
});




}
/// @nodoc
class __$PluginSessionControlParamsDtoCopyWithImpl<$Res>
    implements _$PluginSessionControlParamsDtoCopyWith<$Res> {
  __$PluginSessionControlParamsDtoCopyWithImpl(this._self, this._then);

  final _PluginSessionControlParamsDto _self;
  final $Res Function(_PluginSessionControlParamsDto) _then;

/// Create a copy of PluginSessionControlParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? pluginId = null,Object? contributionId = null,}) {
  return _then(_PluginSessionControlParamsDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,contributionId: null == contributionId ? _self.contributionId : contributionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$PluginSessionControlSetParamsDto {

 String get sessionId; String get pluginId; String get contributionId; Object? get value;
/// Create a copy of PluginSessionControlSetParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginSessionControlSetParamsDtoCopyWith<PluginSessionControlSetParamsDto> get copyWith => _$PluginSessionControlSetParamsDtoCopyWithImpl<PluginSessionControlSetParamsDto>(this as PluginSessionControlSetParamsDto, _$identity);

  /// Serializes this PluginSessionControlSetParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginSessionControlSetParamsDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.contributionId, contributionId) || other.contributionId == contributionId)&&const DeepCollectionEquality().equals(other.value, value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,pluginId,contributionId,const DeepCollectionEquality().hash(value));

@override
String toString() {
  return 'PluginSessionControlSetParamsDto(sessionId: $sessionId, pluginId: $pluginId, contributionId: $contributionId, value: $value)';
}


}

/// @nodoc
abstract mixin class $PluginSessionControlSetParamsDtoCopyWith<$Res>  {
  factory $PluginSessionControlSetParamsDtoCopyWith(PluginSessionControlSetParamsDto value, $Res Function(PluginSessionControlSetParamsDto) _then) = _$PluginSessionControlSetParamsDtoCopyWithImpl;
@useResult
$Res call({
 String sessionId, String pluginId, String contributionId, Object? value
});




}
/// @nodoc
class _$PluginSessionControlSetParamsDtoCopyWithImpl<$Res>
    implements $PluginSessionControlSetParamsDtoCopyWith<$Res> {
  _$PluginSessionControlSetParamsDtoCopyWithImpl(this._self, this._then);

  final PluginSessionControlSetParamsDto _self;
  final $Res Function(PluginSessionControlSetParamsDto) _then;

/// Create a copy of PluginSessionControlSetParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? pluginId = null,Object? contributionId = null,Object? value = freezed,}) {
  return _then(PluginSessionControlSetParamsDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,contributionId: null == contributionId ? _self.contributionId : contributionId // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value ,
  ));
}

}


/// Adds pattern-matching-related methods to [PluginSessionControlSetParamsDto].
extension PluginSessionControlSetParamsDtoPatterns on PluginSessionControlSetParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginSessionControlSetParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginSessionControlSetParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginSessionControlSetParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _PluginSessionControlSetParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginSessionControlSetParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _PluginSessionControlSetParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sessionId,  String pluginId,  String contributionId,  Object? value)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginSessionControlSetParamsDto() when $default != null:
return $default(_that.sessionId,_that.pluginId,_that.contributionId,_that.value);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sessionId,  String pluginId,  String contributionId,  Object? value)  $default,) {final _that = this;
switch (_that) {
case _PluginSessionControlSetParamsDto():
return $default(_that.sessionId,_that.pluginId,_that.contributionId,_that.value);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sessionId,  String pluginId,  String contributionId,  Object? value)?  $default,) {final _that = this;
switch (_that) {
case _PluginSessionControlSetParamsDto() when $default != null:
return $default(_that.sessionId,_that.pluginId,_that.contributionId,_that.value);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PluginSessionControlSetParamsDto implements PluginSessionControlSetParamsDto {
  const _PluginSessionControlSetParamsDto({required this.sessionId, required this.pluginId, required this.contributionId, required this.value});
  factory _PluginSessionControlSetParamsDto.fromJson(Map<String, dynamic> json) => _$PluginSessionControlSetParamsDtoFromJson(json);

@override final  String sessionId;
@override final  String pluginId;
@override final  String contributionId;
@override final  Object? value;

/// Create a copy of PluginSessionControlSetParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginSessionControlSetParamsDtoCopyWith<_PluginSessionControlSetParamsDto> get copyWith => __$PluginSessionControlSetParamsDtoCopyWithImpl<_PluginSessionControlSetParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginSessionControlSetParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginSessionControlSetParamsDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.contributionId, contributionId) || other.contributionId == contributionId)&&const DeepCollectionEquality().equals(other.value, value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,pluginId,contributionId,const DeepCollectionEquality().hash(value));

@override
String toString() {
  return 'PluginSessionControlSetParamsDto(sessionId: $sessionId, pluginId: $pluginId, contributionId: $contributionId, value: $value)';
}


}

/// @nodoc
abstract mixin class _$PluginSessionControlSetParamsDtoCopyWith<$Res> implements $PluginSessionControlSetParamsDtoCopyWith<$Res> {
  factory _$PluginSessionControlSetParamsDtoCopyWith(_PluginSessionControlSetParamsDto value, $Res Function(_PluginSessionControlSetParamsDto) _then) = __$PluginSessionControlSetParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, String pluginId, String contributionId, Object? value
});




}
/// @nodoc
class __$PluginSessionControlSetParamsDtoCopyWithImpl<$Res>
    implements _$PluginSessionControlSetParamsDtoCopyWith<$Res> {
  __$PluginSessionControlSetParamsDtoCopyWithImpl(this._self, this._then);

  final _PluginSessionControlSetParamsDto _self;
  final $Res Function(_PluginSessionControlSetParamsDto) _then;

/// Create a copy of PluginSessionControlSetParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? pluginId = null,Object? contributionId = null,Object? value = freezed,}) {
  return _then(_PluginSessionControlSetParamsDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,contributionId: null == contributionId ? _self.contributionId : contributionId // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value ,
  ));
}


}


/// @nodoc
mixin _$PluginUiRenderParamsDto {

 String get agentId; String get pluginId; String get contributionId; PluginUiSlot get slot; Object? get input; Map<String, dynamic> get context;
/// Create a copy of PluginUiRenderParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginUiRenderParamsDtoCopyWith<PluginUiRenderParamsDto> get copyWith => _$PluginUiRenderParamsDtoCopyWithImpl<PluginUiRenderParamsDto>(this as PluginUiRenderParamsDto, _$identity);

  /// Serializes this PluginUiRenderParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginUiRenderParamsDto&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.contributionId, contributionId) || other.contributionId == contributionId)&&(identical(other.slot, slot) || other.slot == slot)&&const DeepCollectionEquality().equals(other.input, input)&&const DeepCollectionEquality().equals(other.context, context));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,agentId,pluginId,contributionId,slot,const DeepCollectionEquality().hash(input),const DeepCollectionEquality().hash(context));

@override
String toString() {
  return 'PluginUiRenderParamsDto(agentId: $agentId, pluginId: $pluginId, contributionId: $contributionId, slot: $slot, input: $input, context: $context)';
}


}

/// @nodoc
abstract mixin class $PluginUiRenderParamsDtoCopyWith<$Res>  {
  factory $PluginUiRenderParamsDtoCopyWith(PluginUiRenderParamsDto value, $Res Function(PluginUiRenderParamsDto) _then) = _$PluginUiRenderParamsDtoCopyWithImpl;
@useResult
$Res call({
 String agentId, String pluginId, String contributionId, PluginUiSlot slot, Object? input, Map<String, dynamic> context
});




}
/// @nodoc
class _$PluginUiRenderParamsDtoCopyWithImpl<$Res>
    implements $PluginUiRenderParamsDtoCopyWith<$Res> {
  _$PluginUiRenderParamsDtoCopyWithImpl(this._self, this._then);

  final PluginUiRenderParamsDto _self;
  final $Res Function(PluginUiRenderParamsDto) _then;

/// Create a copy of PluginUiRenderParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? agentId = null,Object? pluginId = null,Object? contributionId = null,Object? slot = null,Object? input = freezed,Object? context = null,}) {
  return _then(PluginUiRenderParamsDto(
agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,contributionId: null == contributionId ? _self.contributionId : contributionId // ignore: cast_nullable_to_non_nullable
as String,slot: null == slot ? _self.slot : slot // ignore: cast_nullable_to_non_nullable
as PluginUiSlot,input: freezed == input ? _self.input : input ,context: null == context ? _self.context : context // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [PluginUiRenderParamsDto].
extension PluginUiRenderParamsDtoPatterns on PluginUiRenderParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginUiRenderParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginUiRenderParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginUiRenderParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _PluginUiRenderParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginUiRenderParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _PluginUiRenderParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String agentId,  String pluginId,  String contributionId,  PluginUiSlot slot,  Object? input,  Map<String, dynamic> context)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginUiRenderParamsDto() when $default != null:
return $default(_that.agentId,_that.pluginId,_that.contributionId,_that.slot,_that.input,_that.context);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String agentId,  String pluginId,  String contributionId,  PluginUiSlot slot,  Object? input,  Map<String, dynamic> context)  $default,) {final _that = this;
switch (_that) {
case _PluginUiRenderParamsDto():
return $default(_that.agentId,_that.pluginId,_that.contributionId,_that.slot,_that.input,_that.context);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String agentId,  String pluginId,  String contributionId,  PluginUiSlot slot,  Object? input,  Map<String, dynamic> context)?  $default,) {final _that = this;
switch (_that) {
case _PluginUiRenderParamsDto() when $default != null:
return $default(_that.agentId,_that.pluginId,_that.contributionId,_that.slot,_that.input,_that.context);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PluginUiRenderParamsDto implements PluginUiRenderParamsDto {
  const _PluginUiRenderParamsDto({required this.agentId, required this.pluginId, required this.contributionId, required this.slot, this.input,  Map<String, dynamic> context = const <String, dynamic>{}}): _context = context;
  factory _PluginUiRenderParamsDto.fromJson(Map<String, dynamic> json) => _$PluginUiRenderParamsDtoFromJson(json);

@override final  String agentId;
@override final  String pluginId;
@override final  String contributionId;
@override final  PluginUiSlot slot;
@override final  Object? input;
 final  Map<String, dynamic> _context;
@override@JsonKey() Map<String, dynamic> get context {
  if (_context is EqualUnmodifiableMapView) return _context;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_context);
}


/// Create a copy of PluginUiRenderParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginUiRenderParamsDtoCopyWith<_PluginUiRenderParamsDto> get copyWith => __$PluginUiRenderParamsDtoCopyWithImpl<_PluginUiRenderParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginUiRenderParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginUiRenderParamsDto&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.contributionId, contributionId) || other.contributionId == contributionId)&&(identical(other.slot, slot) || other.slot == slot)&&const DeepCollectionEquality().equals(other.input, input)&&const DeepCollectionEquality().equals(other._context, _context));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,agentId,pluginId,contributionId,slot,const DeepCollectionEquality().hash(input),const DeepCollectionEquality().hash(_context));

@override
String toString() {
  return 'PluginUiRenderParamsDto(agentId: $agentId, pluginId: $pluginId, contributionId: $contributionId, slot: $slot, input: $input, context: $context)';
}


}

/// @nodoc
abstract mixin class _$PluginUiRenderParamsDtoCopyWith<$Res> implements $PluginUiRenderParamsDtoCopyWith<$Res> {
  factory _$PluginUiRenderParamsDtoCopyWith(_PluginUiRenderParamsDto value, $Res Function(_PluginUiRenderParamsDto) _then) = __$PluginUiRenderParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String agentId, String pluginId, String contributionId, PluginUiSlot slot, Object? input, Map<String, dynamic> context
});




}
/// @nodoc
class __$PluginUiRenderParamsDtoCopyWithImpl<$Res>
    implements _$PluginUiRenderParamsDtoCopyWith<$Res> {
  __$PluginUiRenderParamsDtoCopyWithImpl(this._self, this._then);

  final _PluginUiRenderParamsDto _self;
  final $Res Function(_PluginUiRenderParamsDto) _then;

/// Create a copy of PluginUiRenderParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? agentId = null,Object? pluginId = null,Object? contributionId = null,Object? slot = null,Object? input = freezed,Object? context = null,}) {
  return _then(_PluginUiRenderParamsDto(
agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,contributionId: null == contributionId ? _self.contributionId : contributionId // ignore: cast_nullable_to_non_nullable
as String,slot: null == slot ? _self.slot : slot // ignore: cast_nullable_to_non_nullable
as PluginUiSlot,input: freezed == input ? _self.input : input ,context: null == context ? _self._context : context // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}


/// @nodoc
mixin _$PluginUiActionParamsDto {

 String get agentId; String get pluginId; PluginUiActionDto get action;
/// Create a copy of PluginUiActionParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginUiActionParamsDtoCopyWith<PluginUiActionParamsDto> get copyWith => _$PluginUiActionParamsDtoCopyWithImpl<PluginUiActionParamsDto>(this as PluginUiActionParamsDto, _$identity);

  /// Serializes this PluginUiActionParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginUiActionParamsDto&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.action, action) || other.action == action));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,agentId,pluginId,action);

@override
String toString() {
  return 'PluginUiActionParamsDto(agentId: $agentId, pluginId: $pluginId, action: $action)';
}


}

/// @nodoc
abstract mixin class $PluginUiActionParamsDtoCopyWith<$Res>  {
  factory $PluginUiActionParamsDtoCopyWith(PluginUiActionParamsDto value, $Res Function(PluginUiActionParamsDto) _then) = _$PluginUiActionParamsDtoCopyWithImpl;
@useResult
$Res call({
 String agentId, String pluginId, PluginUiActionDto action
});


$PluginUiActionDtoCopyWith<$Res> get action;

}
/// @nodoc
class _$PluginUiActionParamsDtoCopyWithImpl<$Res>
    implements $PluginUiActionParamsDtoCopyWith<$Res> {
  _$PluginUiActionParamsDtoCopyWithImpl(this._self, this._then);

  final PluginUiActionParamsDto _self;
  final $Res Function(PluginUiActionParamsDto) _then;

/// Create a copy of PluginUiActionParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? agentId = null,Object? pluginId = null,Object? action = null,}) {
  return _then(PluginUiActionParamsDto(
agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as PluginUiActionDto,
  ));
}
/// Create a copy of PluginUiActionParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginUiActionDtoCopyWith<$Res> get action {

  return $PluginUiActionDtoCopyWith<$Res>(_self.action, (value) {
    return _then(_self.copyWith(action: value));
  });
}
}


/// Adds pattern-matching-related methods to [PluginUiActionParamsDto].
extension PluginUiActionParamsDtoPatterns on PluginUiActionParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginUiActionParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginUiActionParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginUiActionParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _PluginUiActionParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginUiActionParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _PluginUiActionParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String agentId,  String pluginId,  PluginUiActionDto action)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginUiActionParamsDto() when $default != null:
return $default(_that.agentId,_that.pluginId,_that.action);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String agentId,  String pluginId,  PluginUiActionDto action)  $default,) {final _that = this;
switch (_that) {
case _PluginUiActionParamsDto():
return $default(_that.agentId,_that.pluginId,_that.action);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String agentId,  String pluginId,  PluginUiActionDto action)?  $default,) {final _that = this;
switch (_that) {
case _PluginUiActionParamsDto() when $default != null:
return $default(_that.agentId,_that.pluginId,_that.action);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PluginUiActionParamsDto implements PluginUiActionParamsDto {
  const _PluginUiActionParamsDto({required this.agentId, required this.pluginId, required this.action});
  factory _PluginUiActionParamsDto.fromJson(Map<String, dynamic> json) => _$PluginUiActionParamsDtoFromJson(json);

@override final  String agentId;
@override final  String pluginId;
@override final  PluginUiActionDto action;

/// Create a copy of PluginUiActionParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginUiActionParamsDtoCopyWith<_PluginUiActionParamsDto> get copyWith => __$PluginUiActionParamsDtoCopyWithImpl<_PluginUiActionParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginUiActionParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginUiActionParamsDto&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.action, action) || other.action == action));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,agentId,pluginId,action);

@override
String toString() {
  return 'PluginUiActionParamsDto(agentId: $agentId, pluginId: $pluginId, action: $action)';
}


}

/// @nodoc
abstract mixin class _$PluginUiActionParamsDtoCopyWith<$Res> implements $PluginUiActionParamsDtoCopyWith<$Res> {
  factory _$PluginUiActionParamsDtoCopyWith(_PluginUiActionParamsDto value, $Res Function(_PluginUiActionParamsDto) _then) = __$PluginUiActionParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String agentId, String pluginId, PluginUiActionDto action
});


@override $PluginUiActionDtoCopyWith<$Res> get action;

}
/// @nodoc
class __$PluginUiActionParamsDtoCopyWithImpl<$Res>
    implements _$PluginUiActionParamsDtoCopyWith<$Res> {
  __$PluginUiActionParamsDtoCopyWithImpl(this._self, this._then);

  final _PluginUiActionParamsDto _self;
  final $Res Function(_PluginUiActionParamsDto) _then;

/// Create a copy of PluginUiActionParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? agentId = null,Object? pluginId = null,Object? action = null,}) {
  return _then(_PluginUiActionParamsDto(
agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as PluginUiActionDto,
  ));
}

/// Create a copy of PluginUiActionParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginUiActionDtoCopyWith<$Res> get action {

  return $PluginUiActionDtoCopyWith<$Res>(_self.action, (value) {
    return _then(_self.copyWith(action: value));
  });
}
}


/// @nodoc
mixin _$SkillListParamsDto {

 SkillListView get view; String? get workspaceId;
/// Create a copy of SkillListParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SkillListParamsDtoCopyWith<SkillListParamsDto> get copyWith => _$SkillListParamsDtoCopyWithImpl<SkillListParamsDto>(this as SkillListParamsDto, _$identity);

  /// Serializes this SkillListParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SkillListParamsDto&&(identical(other.view, view) || other.view == view)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,view,workspaceId);

@override
String toString() {
  return 'SkillListParamsDto(view: $view, workspaceId: $workspaceId)';
}


}

/// @nodoc
abstract mixin class $SkillListParamsDtoCopyWith<$Res>  {
  factory $SkillListParamsDtoCopyWith(SkillListParamsDto value, $Res Function(SkillListParamsDto) _then) = _$SkillListParamsDtoCopyWithImpl;
@useResult
$Res call({
 SkillListView view, String? workspaceId
});




}
/// @nodoc
class _$SkillListParamsDtoCopyWithImpl<$Res>
    implements $SkillListParamsDtoCopyWith<$Res> {
  _$SkillListParamsDtoCopyWithImpl(this._self, this._then);

  final SkillListParamsDto _self;
  final $Res Function(SkillListParamsDto) _then;

/// Create a copy of SkillListParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? view = null,Object? workspaceId = freezed,}) {
  return _then(SkillListParamsDto(
view: null == view ? _self.view : view // ignore: cast_nullable_to_non_nullable
as SkillListView,workspaceId: freezed == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SkillListParamsDto].
extension SkillListParamsDtoPatterns on SkillListParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SkillListParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SkillListParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SkillListParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _SkillListParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SkillListParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _SkillListParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SkillListView view,  String? workspaceId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SkillListParamsDto() when $default != null:
return $default(_that.view,_that.workspaceId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SkillListView view,  String? workspaceId)  $default,) {final _that = this;
switch (_that) {
case _SkillListParamsDto():
return $default(_that.view,_that.workspaceId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SkillListView view,  String? workspaceId)?  $default,) {final _that = this;
switch (_that) {
case _SkillListParamsDto() when $default != null:
return $default(_that.view,_that.workspaceId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SkillListParamsDto implements SkillListParamsDto {
  const _SkillListParamsDto({required this.view, this.workspaceId});
  factory _SkillListParamsDto.fromJson(Map<String, dynamic> json) => _$SkillListParamsDtoFromJson(json);

@override final  SkillListView view;
@override final  String? workspaceId;

/// Create a copy of SkillListParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SkillListParamsDtoCopyWith<_SkillListParamsDto> get copyWith => __$SkillListParamsDtoCopyWithImpl<_SkillListParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SkillListParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SkillListParamsDto&&(identical(other.view, view) || other.view == view)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,view,workspaceId);

@override
String toString() {
  return 'SkillListParamsDto(view: $view, workspaceId: $workspaceId)';
}


}

/// @nodoc
abstract mixin class _$SkillListParamsDtoCopyWith<$Res> implements $SkillListParamsDtoCopyWith<$Res> {
  factory _$SkillListParamsDtoCopyWith(_SkillListParamsDto value, $Res Function(_SkillListParamsDto) _then) = __$SkillListParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 SkillListView view, String? workspaceId
});




}
/// @nodoc
class __$SkillListParamsDtoCopyWithImpl<$Res>
    implements _$SkillListParamsDtoCopyWith<$Res> {
  __$SkillListParamsDtoCopyWithImpl(this._self, this._then);

  final _SkillListParamsDto _self;
  final $Res Function(_SkillListParamsDto) _then;

/// Create a copy of SkillListParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? view = null,Object? workspaceId = freezed,}) {
  return _then(_SkillListParamsDto(
view: null == view ? _self.view : view // ignore: cast_nullable_to_non_nullable
as SkillListView,workspaceId: freezed == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ProviderConnectApiKeyParamsDto {

 String get definitionId; String get apiKey; String? get connectionId; String? get modelPrefix;
/// Create a copy of ProviderConnectApiKeyParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderConnectApiKeyParamsDtoCopyWith<ProviderConnectApiKeyParamsDto> get copyWith => _$ProviderConnectApiKeyParamsDtoCopyWithImpl<ProviderConnectApiKeyParamsDto>(this as ProviderConnectApiKeyParamsDto, _$identity);

  /// Serializes this ProviderConnectApiKeyParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderConnectApiKeyParamsDto&&(identical(other.definitionId, definitionId) || other.definitionId == definitionId)&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey)&&(identical(other.connectionId, connectionId) || other.connectionId == connectionId)&&(identical(other.modelPrefix, modelPrefix) || other.modelPrefix == modelPrefix));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,definitionId,apiKey,connectionId,modelPrefix);

@override
String toString() {
  return 'ProviderConnectApiKeyParamsDto(definitionId: $definitionId, apiKey: $apiKey, connectionId: $connectionId, modelPrefix: $modelPrefix)';
}


}

/// @nodoc
abstract mixin class $ProviderConnectApiKeyParamsDtoCopyWith<$Res>  {
  factory $ProviderConnectApiKeyParamsDtoCopyWith(ProviderConnectApiKeyParamsDto value, $Res Function(ProviderConnectApiKeyParamsDto) _then) = _$ProviderConnectApiKeyParamsDtoCopyWithImpl;
@useResult
$Res call({
 String definitionId, String apiKey, String? connectionId, String? modelPrefix
});




}
/// @nodoc
class _$ProviderConnectApiKeyParamsDtoCopyWithImpl<$Res>
    implements $ProviderConnectApiKeyParamsDtoCopyWith<$Res> {
  _$ProviderConnectApiKeyParamsDtoCopyWithImpl(this._self, this._then);

  final ProviderConnectApiKeyParamsDto _self;
  final $Res Function(ProviderConnectApiKeyParamsDto) _then;

/// Create a copy of ProviderConnectApiKeyParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? definitionId = null,Object? apiKey = null,Object? connectionId = freezed,Object? modelPrefix = freezed,}) {
  return _then(ProviderConnectApiKeyParamsDto(
definitionId: null == definitionId ? _self.definitionId : definitionId // ignore: cast_nullable_to_non_nullable
as String,apiKey: null == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String,connectionId: freezed == connectionId ? _self.connectionId : connectionId // ignore: cast_nullable_to_non_nullable
as String?,modelPrefix: freezed == modelPrefix ? _self.modelPrefix : modelPrefix // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProviderConnectApiKeyParamsDto].
extension ProviderConnectApiKeyParamsDtoPatterns on ProviderConnectApiKeyParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderConnectApiKeyParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderConnectApiKeyParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderConnectApiKeyParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _ProviderConnectApiKeyParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderConnectApiKeyParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderConnectApiKeyParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String definitionId,  String apiKey,  String? connectionId,  String? modelPrefix)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderConnectApiKeyParamsDto() when $default != null:
return $default(_that.definitionId,_that.apiKey,_that.connectionId,_that.modelPrefix);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String definitionId,  String apiKey,  String? connectionId,  String? modelPrefix)  $default,) {final _that = this;
switch (_that) {
case _ProviderConnectApiKeyParamsDto():
return $default(_that.definitionId,_that.apiKey,_that.connectionId,_that.modelPrefix);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String definitionId,  String apiKey,  String? connectionId,  String? modelPrefix)?  $default,) {final _that = this;
switch (_that) {
case _ProviderConnectApiKeyParamsDto() when $default != null:
return $default(_that.definitionId,_that.apiKey,_that.connectionId,_that.modelPrefix);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProviderConnectApiKeyParamsDto implements ProviderConnectApiKeyParamsDto {
  const _ProviderConnectApiKeyParamsDto({required this.definitionId, required this.apiKey, this.connectionId, this.modelPrefix});
  factory _ProviderConnectApiKeyParamsDto.fromJson(Map<String, dynamic> json) => _$ProviderConnectApiKeyParamsDtoFromJson(json);

@override final  String definitionId;
@override final  String apiKey;
@override final  String? connectionId;
@override final  String? modelPrefix;

/// Create a copy of ProviderConnectApiKeyParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderConnectApiKeyParamsDtoCopyWith<_ProviderConnectApiKeyParamsDto> get copyWith => __$ProviderConnectApiKeyParamsDtoCopyWithImpl<_ProviderConnectApiKeyParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderConnectApiKeyParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderConnectApiKeyParamsDto&&(identical(other.definitionId, definitionId) || other.definitionId == definitionId)&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey)&&(identical(other.connectionId, connectionId) || other.connectionId == connectionId)&&(identical(other.modelPrefix, modelPrefix) || other.modelPrefix == modelPrefix));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,definitionId,apiKey,connectionId,modelPrefix);

@override
String toString() {
  return 'ProviderConnectApiKeyParamsDto(definitionId: $definitionId, apiKey: $apiKey, connectionId: $connectionId, modelPrefix: $modelPrefix)';
}


}

/// @nodoc
abstract mixin class _$ProviderConnectApiKeyParamsDtoCopyWith<$Res> implements $ProviderConnectApiKeyParamsDtoCopyWith<$Res> {
  factory _$ProviderConnectApiKeyParamsDtoCopyWith(_ProviderConnectApiKeyParamsDto value, $Res Function(_ProviderConnectApiKeyParamsDto) _then) = __$ProviderConnectApiKeyParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String definitionId, String apiKey, String? connectionId, String? modelPrefix
});




}
/// @nodoc
class __$ProviderConnectApiKeyParamsDtoCopyWithImpl<$Res>
    implements _$ProviderConnectApiKeyParamsDtoCopyWith<$Res> {
  __$ProviderConnectApiKeyParamsDtoCopyWithImpl(this._self, this._then);

  final _ProviderConnectApiKeyParamsDto _self;
  final $Res Function(_ProviderConnectApiKeyParamsDto) _then;

/// Create a copy of ProviderConnectApiKeyParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? definitionId = null,Object? apiKey = null,Object? connectionId = freezed,Object? modelPrefix = freezed,}) {
  return _then(_ProviderConnectApiKeyParamsDto(
definitionId: null == definitionId ? _self.definitionId : definitionId // ignore: cast_nullable_to_non_nullable
as String,apiKey: null == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String,connectionId: freezed == connectionId ? _self.connectionId : connectionId // ignore: cast_nullable_to_non_nullable
as String?,modelPrefix: freezed == modelPrefix ? _self.modelPrefix : modelPrefix // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ProviderConnectNoneParamsDto {

 String get definitionId; String? get connectionId; String? get modelPrefix;
/// Create a copy of ProviderConnectNoneParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderConnectNoneParamsDtoCopyWith<ProviderConnectNoneParamsDto> get copyWith => _$ProviderConnectNoneParamsDtoCopyWithImpl<ProviderConnectNoneParamsDto>(this as ProviderConnectNoneParamsDto, _$identity);

  /// Serializes this ProviderConnectNoneParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderConnectNoneParamsDto&&(identical(other.definitionId, definitionId) || other.definitionId == definitionId)&&(identical(other.connectionId, connectionId) || other.connectionId == connectionId)&&(identical(other.modelPrefix, modelPrefix) || other.modelPrefix == modelPrefix));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,definitionId,connectionId,modelPrefix);

@override
String toString() {
  return 'ProviderConnectNoneParamsDto(definitionId: $definitionId, connectionId: $connectionId, modelPrefix: $modelPrefix)';
}


}

/// @nodoc
abstract mixin class $ProviderConnectNoneParamsDtoCopyWith<$Res>  {
  factory $ProviderConnectNoneParamsDtoCopyWith(ProviderConnectNoneParamsDto value, $Res Function(ProviderConnectNoneParamsDto) _then) = _$ProviderConnectNoneParamsDtoCopyWithImpl;
@useResult
$Res call({
 String definitionId, String? connectionId, String? modelPrefix
});




}
/// @nodoc
class _$ProviderConnectNoneParamsDtoCopyWithImpl<$Res>
    implements $ProviderConnectNoneParamsDtoCopyWith<$Res> {
  _$ProviderConnectNoneParamsDtoCopyWithImpl(this._self, this._then);

  final ProviderConnectNoneParamsDto _self;
  final $Res Function(ProviderConnectNoneParamsDto) _then;

/// Create a copy of ProviderConnectNoneParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? definitionId = null,Object? connectionId = freezed,Object? modelPrefix = freezed,}) {
  return _then(ProviderConnectNoneParamsDto(
definitionId: null == definitionId ? _self.definitionId : definitionId // ignore: cast_nullable_to_non_nullable
as String,connectionId: freezed == connectionId ? _self.connectionId : connectionId // ignore: cast_nullable_to_non_nullable
as String?,modelPrefix: freezed == modelPrefix ? _self.modelPrefix : modelPrefix // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProviderConnectNoneParamsDto].
extension ProviderConnectNoneParamsDtoPatterns on ProviderConnectNoneParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderConnectNoneParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderConnectNoneParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderConnectNoneParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _ProviderConnectNoneParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderConnectNoneParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderConnectNoneParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String definitionId,  String? connectionId,  String? modelPrefix)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderConnectNoneParamsDto() when $default != null:
return $default(_that.definitionId,_that.connectionId,_that.modelPrefix);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String definitionId,  String? connectionId,  String? modelPrefix)  $default,) {final _that = this;
switch (_that) {
case _ProviderConnectNoneParamsDto():
return $default(_that.definitionId,_that.connectionId,_that.modelPrefix);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String definitionId,  String? connectionId,  String? modelPrefix)?  $default,) {final _that = this;
switch (_that) {
case _ProviderConnectNoneParamsDto() when $default != null:
return $default(_that.definitionId,_that.connectionId,_that.modelPrefix);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProviderConnectNoneParamsDto implements ProviderConnectNoneParamsDto {
  const _ProviderConnectNoneParamsDto({required this.definitionId, this.connectionId, this.modelPrefix});
  factory _ProviderConnectNoneParamsDto.fromJson(Map<String, dynamic> json) => _$ProviderConnectNoneParamsDtoFromJson(json);

@override final  String definitionId;
@override final  String? connectionId;
@override final  String? modelPrefix;

/// Create a copy of ProviderConnectNoneParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderConnectNoneParamsDtoCopyWith<_ProviderConnectNoneParamsDto> get copyWith => __$ProviderConnectNoneParamsDtoCopyWithImpl<_ProviderConnectNoneParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderConnectNoneParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderConnectNoneParamsDto&&(identical(other.definitionId, definitionId) || other.definitionId == definitionId)&&(identical(other.connectionId, connectionId) || other.connectionId == connectionId)&&(identical(other.modelPrefix, modelPrefix) || other.modelPrefix == modelPrefix));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,definitionId,connectionId,modelPrefix);

@override
String toString() {
  return 'ProviderConnectNoneParamsDto(definitionId: $definitionId, connectionId: $connectionId, modelPrefix: $modelPrefix)';
}


}

/// @nodoc
abstract mixin class _$ProviderConnectNoneParamsDtoCopyWith<$Res> implements $ProviderConnectNoneParamsDtoCopyWith<$Res> {
  factory _$ProviderConnectNoneParamsDtoCopyWith(_ProviderConnectNoneParamsDto value, $Res Function(_ProviderConnectNoneParamsDto) _then) = __$ProviderConnectNoneParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String definitionId, String? connectionId, String? modelPrefix
});




}
/// @nodoc
class __$ProviderConnectNoneParamsDtoCopyWithImpl<$Res>
    implements _$ProviderConnectNoneParamsDtoCopyWith<$Res> {
  __$ProviderConnectNoneParamsDtoCopyWithImpl(this._self, this._then);

  final _ProviderConnectNoneParamsDto _self;
  final $Res Function(_ProviderConnectNoneParamsDto) _then;

/// Create a copy of ProviderConnectNoneParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? definitionId = null,Object? connectionId = freezed,Object? modelPrefix = freezed,}) {
  return _then(_ProviderConnectNoneParamsDto(
definitionId: null == definitionId ? _self.definitionId : definitionId // ignore: cast_nullable_to_non_nullable
as String,connectionId: freezed == connectionId ? _self.connectionId : connectionId // ignore: cast_nullable_to_non_nullable
as String?,modelPrefix: freezed == modelPrefix ? _self.modelPrefix : modelPrefix // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ProviderConnectionIdParamsDto {

 String get connectionId;
/// Create a copy of ProviderConnectionIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderConnectionIdParamsDtoCopyWith<ProviderConnectionIdParamsDto> get copyWith => _$ProviderConnectionIdParamsDtoCopyWithImpl<ProviderConnectionIdParamsDto>(this as ProviderConnectionIdParamsDto, _$identity);

  /// Serializes this ProviderConnectionIdParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderConnectionIdParamsDto&&(identical(other.connectionId, connectionId) || other.connectionId == connectionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,connectionId);

@override
String toString() {
  return 'ProviderConnectionIdParamsDto(connectionId: $connectionId)';
}


}

/// @nodoc
abstract mixin class $ProviderConnectionIdParamsDtoCopyWith<$Res>  {
  factory $ProviderConnectionIdParamsDtoCopyWith(ProviderConnectionIdParamsDto value, $Res Function(ProviderConnectionIdParamsDto) _then) = _$ProviderConnectionIdParamsDtoCopyWithImpl;
@useResult
$Res call({
 String connectionId
});




}
/// @nodoc
class _$ProviderConnectionIdParamsDtoCopyWithImpl<$Res>
    implements $ProviderConnectionIdParamsDtoCopyWith<$Res> {
  _$ProviderConnectionIdParamsDtoCopyWithImpl(this._self, this._then);

  final ProviderConnectionIdParamsDto _self;
  final $Res Function(ProviderConnectionIdParamsDto) _then;

/// Create a copy of ProviderConnectionIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? connectionId = null,}) {
  return _then(ProviderConnectionIdParamsDto(
connectionId: null == connectionId ? _self.connectionId : connectionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ProviderConnectionIdParamsDto].
extension ProviderConnectionIdParamsDtoPatterns on ProviderConnectionIdParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderConnectionIdParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderConnectionIdParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderConnectionIdParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _ProviderConnectionIdParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderConnectionIdParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderConnectionIdParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String connectionId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderConnectionIdParamsDto() when $default != null:
return $default(_that.connectionId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String connectionId)  $default,) {final _that = this;
switch (_that) {
case _ProviderConnectionIdParamsDto():
return $default(_that.connectionId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String connectionId)?  $default,) {final _that = this;
switch (_that) {
case _ProviderConnectionIdParamsDto() when $default != null:
return $default(_that.connectionId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProviderConnectionIdParamsDto implements ProviderConnectionIdParamsDto {
  const _ProviderConnectionIdParamsDto({required this.connectionId});
  factory _ProviderConnectionIdParamsDto.fromJson(Map<String, dynamic> json) => _$ProviderConnectionIdParamsDtoFromJson(json);

@override final  String connectionId;

/// Create a copy of ProviderConnectionIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderConnectionIdParamsDtoCopyWith<_ProviderConnectionIdParamsDto> get copyWith => __$ProviderConnectionIdParamsDtoCopyWithImpl<_ProviderConnectionIdParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderConnectionIdParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderConnectionIdParamsDto&&(identical(other.connectionId, connectionId) || other.connectionId == connectionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,connectionId);

@override
String toString() {
  return 'ProviderConnectionIdParamsDto(connectionId: $connectionId)';
}


}

/// @nodoc
abstract mixin class _$ProviderConnectionIdParamsDtoCopyWith<$Res> implements $ProviderConnectionIdParamsDtoCopyWith<$Res> {
  factory _$ProviderConnectionIdParamsDtoCopyWith(_ProviderConnectionIdParamsDto value, $Res Function(_ProviderConnectionIdParamsDto) _then) = __$ProviderConnectionIdParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String connectionId
});




}
/// @nodoc
class __$ProviderConnectionIdParamsDtoCopyWithImpl<$Res>
    implements _$ProviderConnectionIdParamsDtoCopyWith<$Res> {
  __$ProviderConnectionIdParamsDtoCopyWithImpl(this._self, this._then);

  final _ProviderConnectionIdParamsDto _self;
  final $Res Function(_ProviderConnectionIdParamsDto) _then;

/// Create a copy of ProviderConnectionIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? connectionId = null,}) {
  return _then(_ProviderConnectionIdParamsDto(
connectionId: null == connectionId ? _self.connectionId : connectionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ProviderModelParamsDto {

 String get connectionId; String get modelId;
/// Create a copy of ProviderModelParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderModelParamsDtoCopyWith<ProviderModelParamsDto> get copyWith => _$ProviderModelParamsDtoCopyWithImpl<ProviderModelParamsDto>(this as ProviderModelParamsDto, _$identity);

  /// Serializes this ProviderModelParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderModelParamsDto&&(identical(other.connectionId, connectionId) || other.connectionId == connectionId)&&(identical(other.modelId, modelId) || other.modelId == modelId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,connectionId,modelId);

@override
String toString() {
  return 'ProviderModelParamsDto(connectionId: $connectionId, modelId: $modelId)';
}


}

/// @nodoc
abstract mixin class $ProviderModelParamsDtoCopyWith<$Res>  {
  factory $ProviderModelParamsDtoCopyWith(ProviderModelParamsDto value, $Res Function(ProviderModelParamsDto) _then) = _$ProviderModelParamsDtoCopyWithImpl;
@useResult
$Res call({
 String connectionId, String modelId
});




}
/// @nodoc
class _$ProviderModelParamsDtoCopyWithImpl<$Res>
    implements $ProviderModelParamsDtoCopyWith<$Res> {
  _$ProviderModelParamsDtoCopyWithImpl(this._self, this._then);

  final ProviderModelParamsDto _self;
  final $Res Function(ProviderModelParamsDto) _then;

/// Create a copy of ProviderModelParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? connectionId = null,Object? modelId = null,}) {
  return _then(ProviderModelParamsDto(
connectionId: null == connectionId ? _self.connectionId : connectionId // ignore: cast_nullable_to_non_nullable
as String,modelId: null == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ProviderModelParamsDto].
extension ProviderModelParamsDtoPatterns on ProviderModelParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderModelParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderModelParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderModelParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _ProviderModelParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderModelParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderModelParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String connectionId,  String modelId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderModelParamsDto() when $default != null:
return $default(_that.connectionId,_that.modelId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String connectionId,  String modelId)  $default,) {final _that = this;
switch (_that) {
case _ProviderModelParamsDto():
return $default(_that.connectionId,_that.modelId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String connectionId,  String modelId)?  $default,) {final _that = this;
switch (_that) {
case _ProviderModelParamsDto() when $default != null:
return $default(_that.connectionId,_that.modelId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProviderModelParamsDto implements ProviderModelParamsDto {
  const _ProviderModelParamsDto({required this.connectionId, required this.modelId});
  factory _ProviderModelParamsDto.fromJson(Map<String, dynamic> json) => _$ProviderModelParamsDtoFromJson(json);

@override final  String connectionId;
@override final  String modelId;

/// Create a copy of ProviderModelParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderModelParamsDtoCopyWith<_ProviderModelParamsDto> get copyWith => __$ProviderModelParamsDtoCopyWithImpl<_ProviderModelParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderModelParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderModelParamsDto&&(identical(other.connectionId, connectionId) || other.connectionId == connectionId)&&(identical(other.modelId, modelId) || other.modelId == modelId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,connectionId,modelId);

@override
String toString() {
  return 'ProviderModelParamsDto(connectionId: $connectionId, modelId: $modelId)';
}


}

/// @nodoc
abstract mixin class _$ProviderModelParamsDtoCopyWith<$Res> implements $ProviderModelParamsDtoCopyWith<$Res> {
  factory _$ProviderModelParamsDtoCopyWith(_ProviderModelParamsDto value, $Res Function(_ProviderModelParamsDto) _then) = __$ProviderModelParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String connectionId, String modelId
});




}
/// @nodoc
class __$ProviderModelParamsDtoCopyWithImpl<$Res>
    implements _$ProviderModelParamsDtoCopyWith<$Res> {
  __$ProviderModelParamsDtoCopyWithImpl(this._self, this._then);

  final _ProviderModelParamsDto _self;
  final $Res Function(_ProviderModelParamsDto) _then;

/// Create a copy of ProviderModelParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? connectionId = null,Object? modelId = null,}) {
  return _then(_ProviderModelParamsDto(
connectionId: null == connectionId ? _self.connectionId : connectionId // ignore: cast_nullable_to_non_nullable
as String,modelId: null == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ProviderAuthStartParamsDto {

 String get definitionId; String get methodId; String? get connectionId; String? get modelPrefix;
/// Create a copy of ProviderAuthStartParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderAuthStartParamsDtoCopyWith<ProviderAuthStartParamsDto> get copyWith => _$ProviderAuthStartParamsDtoCopyWithImpl<ProviderAuthStartParamsDto>(this as ProviderAuthStartParamsDto, _$identity);

  /// Serializes this ProviderAuthStartParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderAuthStartParamsDto&&(identical(other.definitionId, definitionId) || other.definitionId == definitionId)&&(identical(other.methodId, methodId) || other.methodId == methodId)&&(identical(other.connectionId, connectionId) || other.connectionId == connectionId)&&(identical(other.modelPrefix, modelPrefix) || other.modelPrefix == modelPrefix));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,definitionId,methodId,connectionId,modelPrefix);

@override
String toString() {
  return 'ProviderAuthStartParamsDto(definitionId: $definitionId, methodId: $methodId, connectionId: $connectionId, modelPrefix: $modelPrefix)';
}


}

/// @nodoc
abstract mixin class $ProviderAuthStartParamsDtoCopyWith<$Res>  {
  factory $ProviderAuthStartParamsDtoCopyWith(ProviderAuthStartParamsDto value, $Res Function(ProviderAuthStartParamsDto) _then) = _$ProviderAuthStartParamsDtoCopyWithImpl;
@useResult
$Res call({
 String definitionId, String methodId, String? connectionId, String? modelPrefix
});




}
/// @nodoc
class _$ProviderAuthStartParamsDtoCopyWithImpl<$Res>
    implements $ProviderAuthStartParamsDtoCopyWith<$Res> {
  _$ProviderAuthStartParamsDtoCopyWithImpl(this._self, this._then);

  final ProviderAuthStartParamsDto _self;
  final $Res Function(ProviderAuthStartParamsDto) _then;

/// Create a copy of ProviderAuthStartParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? definitionId = null,Object? methodId = null,Object? connectionId = freezed,Object? modelPrefix = freezed,}) {
  return _then(ProviderAuthStartParamsDto(
definitionId: null == definitionId ? _self.definitionId : definitionId // ignore: cast_nullable_to_non_nullable
as String,methodId: null == methodId ? _self.methodId : methodId // ignore: cast_nullable_to_non_nullable
as String,connectionId: freezed == connectionId ? _self.connectionId : connectionId // ignore: cast_nullable_to_non_nullable
as String?,modelPrefix: freezed == modelPrefix ? _self.modelPrefix : modelPrefix // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProviderAuthStartParamsDto].
extension ProviderAuthStartParamsDtoPatterns on ProviderAuthStartParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderAuthStartParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderAuthStartParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderAuthStartParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _ProviderAuthStartParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderAuthStartParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderAuthStartParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String definitionId,  String methodId,  String? connectionId,  String? modelPrefix)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderAuthStartParamsDto() when $default != null:
return $default(_that.definitionId,_that.methodId,_that.connectionId,_that.modelPrefix);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String definitionId,  String methodId,  String? connectionId,  String? modelPrefix)  $default,) {final _that = this;
switch (_that) {
case _ProviderAuthStartParamsDto():
return $default(_that.definitionId,_that.methodId,_that.connectionId,_that.modelPrefix);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String definitionId,  String methodId,  String? connectionId,  String? modelPrefix)?  $default,) {final _that = this;
switch (_that) {
case _ProviderAuthStartParamsDto() when $default != null:
return $default(_that.definitionId,_that.methodId,_that.connectionId,_that.modelPrefix);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProviderAuthStartParamsDto implements ProviderAuthStartParamsDto {
  const _ProviderAuthStartParamsDto({required this.definitionId, required this.methodId, this.connectionId, this.modelPrefix});
  factory _ProviderAuthStartParamsDto.fromJson(Map<String, dynamic> json) => _$ProviderAuthStartParamsDtoFromJson(json);

@override final  String definitionId;
@override final  String methodId;
@override final  String? connectionId;
@override final  String? modelPrefix;

/// Create a copy of ProviderAuthStartParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderAuthStartParamsDtoCopyWith<_ProviderAuthStartParamsDto> get copyWith => __$ProviderAuthStartParamsDtoCopyWithImpl<_ProviderAuthStartParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderAuthStartParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderAuthStartParamsDto&&(identical(other.definitionId, definitionId) || other.definitionId == definitionId)&&(identical(other.methodId, methodId) || other.methodId == methodId)&&(identical(other.connectionId, connectionId) || other.connectionId == connectionId)&&(identical(other.modelPrefix, modelPrefix) || other.modelPrefix == modelPrefix));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,definitionId,methodId,connectionId,modelPrefix);

@override
String toString() {
  return 'ProviderAuthStartParamsDto(definitionId: $definitionId, methodId: $methodId, connectionId: $connectionId, modelPrefix: $modelPrefix)';
}


}

/// @nodoc
abstract mixin class _$ProviderAuthStartParamsDtoCopyWith<$Res> implements $ProviderAuthStartParamsDtoCopyWith<$Res> {
  factory _$ProviderAuthStartParamsDtoCopyWith(_ProviderAuthStartParamsDto value, $Res Function(_ProviderAuthStartParamsDto) _then) = __$ProviderAuthStartParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String definitionId, String methodId, String? connectionId, String? modelPrefix
});




}
/// @nodoc
class __$ProviderAuthStartParamsDtoCopyWithImpl<$Res>
    implements _$ProviderAuthStartParamsDtoCopyWith<$Res> {
  __$ProviderAuthStartParamsDtoCopyWithImpl(this._self, this._then);

  final _ProviderAuthStartParamsDto _self;
  final $Res Function(_ProviderAuthStartParamsDto) _then;

/// Create a copy of ProviderAuthStartParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? definitionId = null,Object? methodId = null,Object? connectionId = freezed,Object? modelPrefix = freezed,}) {
  return _then(_ProviderAuthStartParamsDto(
definitionId: null == definitionId ? _self.definitionId : definitionId // ignore: cast_nullable_to_non_nullable
as String,methodId: null == methodId ? _self.methodId : methodId // ignore: cast_nullable_to_non_nullable
as String,connectionId: freezed == connectionId ? _self.connectionId : connectionId // ignore: cast_nullable_to_non_nullable
as String?,modelPrefix: freezed == modelPrefix ? _self.modelPrefix : modelPrefix // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ProviderPrefixUpdateParamsDto {

 String get connectionId; String get modelPrefix;
/// Create a copy of ProviderPrefixUpdateParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderPrefixUpdateParamsDtoCopyWith<ProviderPrefixUpdateParamsDto> get copyWith => _$ProviderPrefixUpdateParamsDtoCopyWithImpl<ProviderPrefixUpdateParamsDto>(this as ProviderPrefixUpdateParamsDto, _$identity);

  /// Serializes this ProviderPrefixUpdateParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderPrefixUpdateParamsDto&&(identical(other.connectionId, connectionId) || other.connectionId == connectionId)&&(identical(other.modelPrefix, modelPrefix) || other.modelPrefix == modelPrefix));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,connectionId,modelPrefix);

@override
String toString() {
  return 'ProviderPrefixUpdateParamsDto(connectionId: $connectionId, modelPrefix: $modelPrefix)';
}


}

/// @nodoc
abstract mixin class $ProviderPrefixUpdateParamsDtoCopyWith<$Res>  {
  factory $ProviderPrefixUpdateParamsDtoCopyWith(ProviderPrefixUpdateParamsDto value, $Res Function(ProviderPrefixUpdateParamsDto) _then) = _$ProviderPrefixUpdateParamsDtoCopyWithImpl;
@useResult
$Res call({
 String connectionId, String modelPrefix
});




}
/// @nodoc
class _$ProviderPrefixUpdateParamsDtoCopyWithImpl<$Res>
    implements $ProviderPrefixUpdateParamsDtoCopyWith<$Res> {
  _$ProviderPrefixUpdateParamsDtoCopyWithImpl(this._self, this._then);

  final ProviderPrefixUpdateParamsDto _self;
  final $Res Function(ProviderPrefixUpdateParamsDto) _then;

/// Create a copy of ProviderPrefixUpdateParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? connectionId = null,Object? modelPrefix = null,}) {
  return _then(ProviderPrefixUpdateParamsDto(
connectionId: null == connectionId ? _self.connectionId : connectionId // ignore: cast_nullable_to_non_nullable
as String,modelPrefix: null == modelPrefix ? _self.modelPrefix : modelPrefix // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ProviderPrefixUpdateParamsDto].
extension ProviderPrefixUpdateParamsDtoPatterns on ProviderPrefixUpdateParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderPrefixUpdateParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderPrefixUpdateParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderPrefixUpdateParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _ProviderPrefixUpdateParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderPrefixUpdateParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderPrefixUpdateParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String connectionId,  String modelPrefix)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderPrefixUpdateParamsDto() when $default != null:
return $default(_that.connectionId,_that.modelPrefix);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String connectionId,  String modelPrefix)  $default,) {final _that = this;
switch (_that) {
case _ProviderPrefixUpdateParamsDto():
return $default(_that.connectionId,_that.modelPrefix);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String connectionId,  String modelPrefix)?  $default,) {final _that = this;
switch (_that) {
case _ProviderPrefixUpdateParamsDto() when $default != null:
return $default(_that.connectionId,_that.modelPrefix);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProviderPrefixUpdateParamsDto implements ProviderPrefixUpdateParamsDto {
  const _ProviderPrefixUpdateParamsDto({required this.connectionId, required this.modelPrefix});
  factory _ProviderPrefixUpdateParamsDto.fromJson(Map<String, dynamic> json) => _$ProviderPrefixUpdateParamsDtoFromJson(json);

@override final  String connectionId;
@override final  String modelPrefix;

/// Create a copy of ProviderPrefixUpdateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderPrefixUpdateParamsDtoCopyWith<_ProviderPrefixUpdateParamsDto> get copyWith => __$ProviderPrefixUpdateParamsDtoCopyWithImpl<_ProviderPrefixUpdateParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderPrefixUpdateParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderPrefixUpdateParamsDto&&(identical(other.connectionId, connectionId) || other.connectionId == connectionId)&&(identical(other.modelPrefix, modelPrefix) || other.modelPrefix == modelPrefix));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,connectionId,modelPrefix);

@override
String toString() {
  return 'ProviderPrefixUpdateParamsDto(connectionId: $connectionId, modelPrefix: $modelPrefix)';
}


}

/// @nodoc
abstract mixin class _$ProviderPrefixUpdateParamsDtoCopyWith<$Res> implements $ProviderPrefixUpdateParamsDtoCopyWith<$Res> {
  factory _$ProviderPrefixUpdateParamsDtoCopyWith(_ProviderPrefixUpdateParamsDto value, $Res Function(_ProviderPrefixUpdateParamsDto) _then) = __$ProviderPrefixUpdateParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String connectionId, String modelPrefix
});




}
/// @nodoc
class __$ProviderPrefixUpdateParamsDtoCopyWithImpl<$Res>
    implements _$ProviderPrefixUpdateParamsDtoCopyWith<$Res> {
  __$ProviderPrefixUpdateParamsDtoCopyWithImpl(this._self, this._then);

  final _ProviderPrefixUpdateParamsDto _self;
  final $Res Function(_ProviderPrefixUpdateParamsDto) _then;

/// Create a copy of ProviderPrefixUpdateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? connectionId = null,Object? modelPrefix = null,}) {
  return _then(_ProviderPrefixUpdateParamsDto(
connectionId: null == connectionId ? _self.connectionId : connectionId // ignore: cast_nullable_to_non_nullable
as String,modelPrefix: null == modelPrefix ? _self.modelPrefix : modelPrefix // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ProviderAuthAttemptParamsDto {

 String get attemptId;
/// Create a copy of ProviderAuthAttemptParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderAuthAttemptParamsDtoCopyWith<ProviderAuthAttemptParamsDto> get copyWith => _$ProviderAuthAttemptParamsDtoCopyWithImpl<ProviderAuthAttemptParamsDto>(this as ProviderAuthAttemptParamsDto, _$identity);

  /// Serializes this ProviderAuthAttemptParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderAuthAttemptParamsDto&&(identical(other.attemptId, attemptId) || other.attemptId == attemptId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,attemptId);

@override
String toString() {
  return 'ProviderAuthAttemptParamsDto(attemptId: $attemptId)';
}


}

/// @nodoc
abstract mixin class $ProviderAuthAttemptParamsDtoCopyWith<$Res>  {
  factory $ProviderAuthAttemptParamsDtoCopyWith(ProviderAuthAttemptParamsDto value, $Res Function(ProviderAuthAttemptParamsDto) _then) = _$ProviderAuthAttemptParamsDtoCopyWithImpl;
@useResult
$Res call({
 String attemptId
});




}
/// @nodoc
class _$ProviderAuthAttemptParamsDtoCopyWithImpl<$Res>
    implements $ProviderAuthAttemptParamsDtoCopyWith<$Res> {
  _$ProviderAuthAttemptParamsDtoCopyWithImpl(this._self, this._then);

  final ProviderAuthAttemptParamsDto _self;
  final $Res Function(ProviderAuthAttemptParamsDto) _then;

/// Create a copy of ProviderAuthAttemptParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? attemptId = null,}) {
  return _then(ProviderAuthAttemptParamsDto(
attemptId: null == attemptId ? _self.attemptId : attemptId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ProviderAuthAttemptParamsDto].
extension ProviderAuthAttemptParamsDtoPatterns on ProviderAuthAttemptParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderAuthAttemptParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderAuthAttemptParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderAuthAttemptParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _ProviderAuthAttemptParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderAuthAttemptParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderAuthAttemptParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String attemptId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderAuthAttemptParamsDto() when $default != null:
return $default(_that.attemptId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String attemptId)  $default,) {final _that = this;
switch (_that) {
case _ProviderAuthAttemptParamsDto():
return $default(_that.attemptId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String attemptId)?  $default,) {final _that = this;
switch (_that) {
case _ProviderAuthAttemptParamsDto() when $default != null:
return $default(_that.attemptId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProviderAuthAttemptParamsDto implements ProviderAuthAttemptParamsDto {
  const _ProviderAuthAttemptParamsDto({required this.attemptId});
  factory _ProviderAuthAttemptParamsDto.fromJson(Map<String, dynamic> json) => _$ProviderAuthAttemptParamsDtoFromJson(json);

@override final  String attemptId;

/// Create a copy of ProviderAuthAttemptParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderAuthAttemptParamsDtoCopyWith<_ProviderAuthAttemptParamsDto> get copyWith => __$ProviderAuthAttemptParamsDtoCopyWithImpl<_ProviderAuthAttemptParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderAuthAttemptParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderAuthAttemptParamsDto&&(identical(other.attemptId, attemptId) || other.attemptId == attemptId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,attemptId);

@override
String toString() {
  return 'ProviderAuthAttemptParamsDto(attemptId: $attemptId)';
}


}

/// @nodoc
abstract mixin class _$ProviderAuthAttemptParamsDtoCopyWith<$Res> implements $ProviderAuthAttemptParamsDtoCopyWith<$Res> {
  factory _$ProviderAuthAttemptParamsDtoCopyWith(_ProviderAuthAttemptParamsDto value, $Res Function(_ProviderAuthAttemptParamsDto) _then) = __$ProviderAuthAttemptParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String attemptId
});




}
/// @nodoc
class __$ProviderAuthAttemptParamsDtoCopyWithImpl<$Res>
    implements _$ProviderAuthAttemptParamsDtoCopyWith<$Res> {
  __$ProviderAuthAttemptParamsDtoCopyWithImpl(this._self, this._then);

  final _ProviderAuthAttemptParamsDto _self;
  final $Res Function(_ProviderAuthAttemptParamsDto) _then;

/// Create a copy of ProviderAuthAttemptParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? attemptId = null,}) {
  return _then(_ProviderAuthAttemptParamsDto(
attemptId: null == attemptId ? _self.attemptId : attemptId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ProviderCustomCreateParamsDto {

 String get id; CustomProviderConfigDto get config; String? get apiKey; String? get modelPrefix;
/// Create a copy of ProviderCustomCreateParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderCustomCreateParamsDtoCopyWith<ProviderCustomCreateParamsDto> get copyWith => _$ProviderCustomCreateParamsDtoCopyWithImpl<ProviderCustomCreateParamsDto>(this as ProviderCustomCreateParamsDto, _$identity);

  /// Serializes this ProviderCustomCreateParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderCustomCreateParamsDto&&(identical(other.id, id) || other.id == id)&&(identical(other.config, config) || other.config == config)&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey)&&(identical(other.modelPrefix, modelPrefix) || other.modelPrefix == modelPrefix));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,config,apiKey,modelPrefix);

@override
String toString() {
  return 'ProviderCustomCreateParamsDto(id: $id, config: $config, apiKey: $apiKey, modelPrefix: $modelPrefix)';
}


}

/// @nodoc
abstract mixin class $ProviderCustomCreateParamsDtoCopyWith<$Res>  {
  factory $ProviderCustomCreateParamsDtoCopyWith(ProviderCustomCreateParamsDto value, $Res Function(ProviderCustomCreateParamsDto) _then) = _$ProviderCustomCreateParamsDtoCopyWithImpl;
@useResult
$Res call({
 String id, CustomProviderConfigDto config, String? apiKey, String? modelPrefix
});


$CustomProviderConfigDtoCopyWith<$Res> get config;

}
/// @nodoc
class _$ProviderCustomCreateParamsDtoCopyWithImpl<$Res>
    implements $ProviderCustomCreateParamsDtoCopyWith<$Res> {
  _$ProviderCustomCreateParamsDtoCopyWithImpl(this._self, this._then);

  final ProviderCustomCreateParamsDto _self;
  final $Res Function(ProviderCustomCreateParamsDto) _then;

/// Create a copy of ProviderCustomCreateParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? config = null,Object? apiKey = freezed,Object? modelPrefix = freezed,}) {
  return _then(ProviderCustomCreateParamsDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as CustomProviderConfigDto,apiKey: freezed == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String?,modelPrefix: freezed == modelPrefix ? _self.modelPrefix : modelPrefix // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of ProviderCustomCreateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CustomProviderConfigDtoCopyWith<$Res> get config {

  return $CustomProviderConfigDtoCopyWith<$Res>(_self.config, (value) {
    return _then(_self.copyWith(config: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProviderCustomCreateParamsDto].
extension ProviderCustomCreateParamsDtoPatterns on ProviderCustomCreateParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderCustomCreateParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderCustomCreateParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderCustomCreateParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _ProviderCustomCreateParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderCustomCreateParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderCustomCreateParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  CustomProviderConfigDto config,  String? apiKey,  String? modelPrefix)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderCustomCreateParamsDto() when $default != null:
return $default(_that.id,_that.config,_that.apiKey,_that.modelPrefix);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  CustomProviderConfigDto config,  String? apiKey,  String? modelPrefix)  $default,) {final _that = this;
switch (_that) {
case _ProviderCustomCreateParamsDto():
return $default(_that.id,_that.config,_that.apiKey,_that.modelPrefix);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  CustomProviderConfigDto config,  String? apiKey,  String? modelPrefix)?  $default,) {final _that = this;
switch (_that) {
case _ProviderCustomCreateParamsDto() when $default != null:
return $default(_that.id,_that.config,_that.apiKey,_that.modelPrefix);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProviderCustomCreateParamsDto implements ProviderCustomCreateParamsDto {
  const _ProviderCustomCreateParamsDto({required this.id, required this.config, this.apiKey, this.modelPrefix});
  factory _ProviderCustomCreateParamsDto.fromJson(Map<String, dynamic> json) => _$ProviderCustomCreateParamsDtoFromJson(json);

@override final  String id;
@override final  CustomProviderConfigDto config;
@override final  String? apiKey;
@override final  String? modelPrefix;

/// Create a copy of ProviderCustomCreateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderCustomCreateParamsDtoCopyWith<_ProviderCustomCreateParamsDto> get copyWith => __$ProviderCustomCreateParamsDtoCopyWithImpl<_ProviderCustomCreateParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderCustomCreateParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderCustomCreateParamsDto&&(identical(other.id, id) || other.id == id)&&(identical(other.config, config) || other.config == config)&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey)&&(identical(other.modelPrefix, modelPrefix) || other.modelPrefix == modelPrefix));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,config,apiKey,modelPrefix);

@override
String toString() {
  return 'ProviderCustomCreateParamsDto(id: $id, config: $config, apiKey: $apiKey, modelPrefix: $modelPrefix)';
}


}

/// @nodoc
abstract mixin class _$ProviderCustomCreateParamsDtoCopyWith<$Res> implements $ProviderCustomCreateParamsDtoCopyWith<$Res> {
  factory _$ProviderCustomCreateParamsDtoCopyWith(_ProviderCustomCreateParamsDto value, $Res Function(_ProviderCustomCreateParamsDto) _then) = __$ProviderCustomCreateParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, CustomProviderConfigDto config, String? apiKey, String? modelPrefix
});


@override $CustomProviderConfigDtoCopyWith<$Res> get config;

}
/// @nodoc
class __$ProviderCustomCreateParamsDtoCopyWithImpl<$Res>
    implements _$ProviderCustomCreateParamsDtoCopyWith<$Res> {
  __$ProviderCustomCreateParamsDtoCopyWithImpl(this._self, this._then);

  final _ProviderCustomCreateParamsDto _self;
  final $Res Function(_ProviderCustomCreateParamsDto) _then;

/// Create a copy of ProviderCustomCreateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? config = null,Object? apiKey = freezed,Object? modelPrefix = freezed,}) {
  return _then(_ProviderCustomCreateParamsDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as CustomProviderConfigDto,apiKey: freezed == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String?,modelPrefix: freezed == modelPrefix ? _self.modelPrefix : modelPrefix // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of ProviderCustomCreateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CustomProviderConfigDtoCopyWith<$Res> get config {

  return $CustomProviderConfigDtoCopyWith<$Res>(_self.config, (value) {
    return _then(_self.copyWith(config: value));
  });
}
}


/// @nodoc
mixin _$ProviderCustomUpdateParamsDto {

 String get connectionId; CustomProviderConfigDto get config; String? get apiKey;
/// Create a copy of ProviderCustomUpdateParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderCustomUpdateParamsDtoCopyWith<ProviderCustomUpdateParamsDto> get copyWith => _$ProviderCustomUpdateParamsDtoCopyWithImpl<ProviderCustomUpdateParamsDto>(this as ProviderCustomUpdateParamsDto, _$identity);

  /// Serializes this ProviderCustomUpdateParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderCustomUpdateParamsDto&&(identical(other.connectionId, connectionId) || other.connectionId == connectionId)&&(identical(other.config, config) || other.config == config)&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,connectionId,config,apiKey);

@override
String toString() {
  return 'ProviderCustomUpdateParamsDto(connectionId: $connectionId, config: $config, apiKey: $apiKey)';
}


}

/// @nodoc
abstract mixin class $ProviderCustomUpdateParamsDtoCopyWith<$Res>  {
  factory $ProviderCustomUpdateParamsDtoCopyWith(ProviderCustomUpdateParamsDto value, $Res Function(ProviderCustomUpdateParamsDto) _then) = _$ProviderCustomUpdateParamsDtoCopyWithImpl;
@useResult
$Res call({
 String connectionId, CustomProviderConfigDto config, String? apiKey
});


$CustomProviderConfigDtoCopyWith<$Res> get config;

}
/// @nodoc
class _$ProviderCustomUpdateParamsDtoCopyWithImpl<$Res>
    implements $ProviderCustomUpdateParamsDtoCopyWith<$Res> {
  _$ProviderCustomUpdateParamsDtoCopyWithImpl(this._self, this._then);

  final ProviderCustomUpdateParamsDto _self;
  final $Res Function(ProviderCustomUpdateParamsDto) _then;

/// Create a copy of ProviderCustomUpdateParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? connectionId = null,Object? config = null,Object? apiKey = freezed,}) {
  return _then(ProviderCustomUpdateParamsDto(
connectionId: null == connectionId ? _self.connectionId : connectionId // ignore: cast_nullable_to_non_nullable
as String,config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as CustomProviderConfigDto,apiKey: freezed == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of ProviderCustomUpdateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CustomProviderConfigDtoCopyWith<$Res> get config {

  return $CustomProviderConfigDtoCopyWith<$Res>(_self.config, (value) {
    return _then(_self.copyWith(config: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProviderCustomUpdateParamsDto].
extension ProviderCustomUpdateParamsDtoPatterns on ProviderCustomUpdateParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderCustomUpdateParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderCustomUpdateParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderCustomUpdateParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _ProviderCustomUpdateParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderCustomUpdateParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderCustomUpdateParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String connectionId,  CustomProviderConfigDto config,  String? apiKey)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderCustomUpdateParamsDto() when $default != null:
return $default(_that.connectionId,_that.config,_that.apiKey);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String connectionId,  CustomProviderConfigDto config,  String? apiKey)  $default,) {final _that = this;
switch (_that) {
case _ProviderCustomUpdateParamsDto():
return $default(_that.connectionId,_that.config,_that.apiKey);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String connectionId,  CustomProviderConfigDto config,  String? apiKey)?  $default,) {final _that = this;
switch (_that) {
case _ProviderCustomUpdateParamsDto() when $default != null:
return $default(_that.connectionId,_that.config,_that.apiKey);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProviderCustomUpdateParamsDto implements ProviderCustomUpdateParamsDto {
  const _ProviderCustomUpdateParamsDto({required this.connectionId, required this.config, this.apiKey});
  factory _ProviderCustomUpdateParamsDto.fromJson(Map<String, dynamic> json) => _$ProviderCustomUpdateParamsDtoFromJson(json);

@override final  String connectionId;
@override final  CustomProviderConfigDto config;
@override final  String? apiKey;

/// Create a copy of ProviderCustomUpdateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderCustomUpdateParamsDtoCopyWith<_ProviderCustomUpdateParamsDto> get copyWith => __$ProviderCustomUpdateParamsDtoCopyWithImpl<_ProviderCustomUpdateParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderCustomUpdateParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderCustomUpdateParamsDto&&(identical(other.connectionId, connectionId) || other.connectionId == connectionId)&&(identical(other.config, config) || other.config == config)&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,connectionId,config,apiKey);

@override
String toString() {
  return 'ProviderCustomUpdateParamsDto(connectionId: $connectionId, config: $config, apiKey: $apiKey)';
}


}

/// @nodoc
abstract mixin class _$ProviderCustomUpdateParamsDtoCopyWith<$Res> implements $ProviderCustomUpdateParamsDtoCopyWith<$Res> {
  factory _$ProviderCustomUpdateParamsDtoCopyWith(_ProviderCustomUpdateParamsDto value, $Res Function(_ProviderCustomUpdateParamsDto) _then) = __$ProviderCustomUpdateParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String connectionId, CustomProviderConfigDto config, String? apiKey
});


@override $CustomProviderConfigDtoCopyWith<$Res> get config;

}
/// @nodoc
class __$ProviderCustomUpdateParamsDtoCopyWithImpl<$Res>
    implements _$ProviderCustomUpdateParamsDtoCopyWith<$Res> {
  __$ProviderCustomUpdateParamsDtoCopyWithImpl(this._self, this._then);

  final _ProviderCustomUpdateParamsDto _self;
  final $Res Function(_ProviderCustomUpdateParamsDto) _then;

/// Create a copy of ProviderCustomUpdateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? connectionId = null,Object? config = null,Object? apiKey = freezed,}) {
  return _then(_ProviderCustomUpdateParamsDto(
connectionId: null == connectionId ? _self.connectionId : connectionId // ignore: cast_nullable_to_non_nullable
as String,config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as CustomProviderConfigDto,apiKey: freezed == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of ProviderCustomUpdateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CustomProviderConfigDtoCopyWith<$Res> get config {

  return $CustomProviderConfigDtoCopyWith<$Res>(_self.config, (value) {
    return _then(_self.copyWith(config: value));
  });
}
}


/// @nodoc
mixin _$TurnStartParamsDto {

 String get sessionId; String get turnId; String get prompt; List<String> get attachmentIds;
/// Create a copy of TurnStartParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TurnStartParamsDtoCopyWith<TurnStartParamsDto> get copyWith => _$TurnStartParamsDtoCopyWithImpl<TurnStartParamsDto>(this as TurnStartParamsDto, _$identity);

  /// Serializes this TurnStartParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TurnStartParamsDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.turnId, turnId) || other.turnId == turnId)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&const DeepCollectionEquality().equals(other.attachmentIds, attachmentIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,turnId,prompt,const DeepCollectionEquality().hash(attachmentIds));

@override
String toString() {
  return 'TurnStartParamsDto(sessionId: $sessionId, turnId: $turnId, prompt: $prompt, attachmentIds: $attachmentIds)';
}


}

/// @nodoc
abstract mixin class $TurnStartParamsDtoCopyWith<$Res>  {
  factory $TurnStartParamsDtoCopyWith(TurnStartParamsDto value, $Res Function(TurnStartParamsDto) _then) = _$TurnStartParamsDtoCopyWithImpl;
@useResult
$Res call({
 String sessionId, String turnId, String prompt, List<String> attachmentIds
});




}
/// @nodoc
class _$TurnStartParamsDtoCopyWithImpl<$Res>
    implements $TurnStartParamsDtoCopyWith<$Res> {
  _$TurnStartParamsDtoCopyWithImpl(this._self, this._then);

  final TurnStartParamsDto _self;
  final $Res Function(TurnStartParamsDto) _then;

/// Create a copy of TurnStartParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? turnId = null,Object? prompt = null,Object? attachmentIds = null,}) {
  return _then(TurnStartParamsDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,turnId: null == turnId ? _self.turnId : turnId // ignore: cast_nullable_to_non_nullable
as String,prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,attachmentIds: null == attachmentIds ? _self.attachmentIds : attachmentIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [TurnStartParamsDto].
extension TurnStartParamsDtoPatterns on TurnStartParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TurnStartParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TurnStartParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TurnStartParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _TurnStartParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TurnStartParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _TurnStartParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sessionId,  String turnId,  String prompt,  List<String> attachmentIds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TurnStartParamsDto() when $default != null:
return $default(_that.sessionId,_that.turnId,_that.prompt,_that.attachmentIds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sessionId,  String turnId,  String prompt,  List<String> attachmentIds)  $default,) {final _that = this;
switch (_that) {
case _TurnStartParamsDto():
return $default(_that.sessionId,_that.turnId,_that.prompt,_that.attachmentIds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sessionId,  String turnId,  String prompt,  List<String> attachmentIds)?  $default,) {final _that = this;
switch (_that) {
case _TurnStartParamsDto() when $default != null:
return $default(_that.sessionId,_that.turnId,_that.prompt,_that.attachmentIds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TurnStartParamsDto implements TurnStartParamsDto {
  const _TurnStartParamsDto({required this.sessionId, required this.turnId, required this.prompt,  List<String> attachmentIds = const <String>[]}): _attachmentIds = attachmentIds;
  factory _TurnStartParamsDto.fromJson(Map<String, dynamic> json) => _$TurnStartParamsDtoFromJson(json);

@override final  String sessionId;
@override final  String turnId;
@override final  String prompt;
 final  List<String> _attachmentIds;
@override@JsonKey() List<String> get attachmentIds {
  if (_attachmentIds is EqualUnmodifiableListView) return _attachmentIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attachmentIds);
}


/// Create a copy of TurnStartParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TurnStartParamsDtoCopyWith<_TurnStartParamsDto> get copyWith => __$TurnStartParamsDtoCopyWithImpl<_TurnStartParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TurnStartParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TurnStartParamsDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.turnId, turnId) || other.turnId == turnId)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&const DeepCollectionEquality().equals(other._attachmentIds, _attachmentIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,turnId,prompt,const DeepCollectionEquality().hash(_attachmentIds));

@override
String toString() {
  return 'TurnStartParamsDto(sessionId: $sessionId, turnId: $turnId, prompt: $prompt, attachmentIds: $attachmentIds)';
}


}

/// @nodoc
abstract mixin class _$TurnStartParamsDtoCopyWith<$Res> implements $TurnStartParamsDtoCopyWith<$Res> {
  factory _$TurnStartParamsDtoCopyWith(_TurnStartParamsDto value, $Res Function(_TurnStartParamsDto) _then) = __$TurnStartParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, String turnId, String prompt, List<String> attachmentIds
});




}
/// @nodoc
class __$TurnStartParamsDtoCopyWithImpl<$Res>
    implements _$TurnStartParamsDtoCopyWith<$Res> {
  __$TurnStartParamsDtoCopyWithImpl(this._self, this._then);

  final _TurnStartParamsDto _self;
  final $Res Function(_TurnStartParamsDto) _then;

/// Create a copy of TurnStartParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? turnId = null,Object? prompt = null,Object? attachmentIds = null,}) {
  return _then(_TurnStartParamsDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,turnId: null == turnId ? _self.turnId : turnId // ignore: cast_nullable_to_non_nullable
as String,prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,attachmentIds: null == attachmentIds ? _self._attachmentIds : attachmentIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$SessionIdParamsDto {

 String get sessionId;
/// Create a copy of SessionIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionIdParamsDtoCopyWith<SessionIdParamsDto> get copyWith => _$SessionIdParamsDtoCopyWithImpl<SessionIdParamsDto>(this as SessionIdParamsDto, _$identity);

  /// Serializes this SessionIdParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionIdParamsDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId);

@override
String toString() {
  return 'SessionIdParamsDto(sessionId: $sessionId)';
}


}

/// @nodoc
abstract mixin class $SessionIdParamsDtoCopyWith<$Res>  {
  factory $SessionIdParamsDtoCopyWith(SessionIdParamsDto value, $Res Function(SessionIdParamsDto) _then) = _$SessionIdParamsDtoCopyWithImpl;
@useResult
$Res call({
 String sessionId
});




}
/// @nodoc
class _$SessionIdParamsDtoCopyWithImpl<$Res>
    implements $SessionIdParamsDtoCopyWith<$Res> {
  _$SessionIdParamsDtoCopyWithImpl(this._self, this._then);

  final SessionIdParamsDto _self;
  final $Res Function(SessionIdParamsDto) _then;

/// Create a copy of SessionIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,}) {
  return _then(SessionIdParamsDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionIdParamsDto].
extension SessionIdParamsDtoPatterns on SessionIdParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionIdParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionIdParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionIdParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _SessionIdParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionIdParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _SessionIdParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sessionId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionIdParamsDto() when $default != null:
return $default(_that.sessionId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sessionId)  $default,) {final _that = this;
switch (_that) {
case _SessionIdParamsDto():
return $default(_that.sessionId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sessionId)?  $default,) {final _that = this;
switch (_that) {
case _SessionIdParamsDto() when $default != null:
return $default(_that.sessionId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SessionIdParamsDto implements SessionIdParamsDto {
  const _SessionIdParamsDto({required this.sessionId});
  factory _SessionIdParamsDto.fromJson(Map<String, dynamic> json) => _$SessionIdParamsDtoFromJson(json);

@override final  String sessionId;

/// Create a copy of SessionIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionIdParamsDtoCopyWith<_SessionIdParamsDto> get copyWith => __$SessionIdParamsDtoCopyWithImpl<_SessionIdParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionIdParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionIdParamsDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId);

@override
String toString() {
  return 'SessionIdParamsDto(sessionId: $sessionId)';
}


}

/// @nodoc
abstract mixin class _$SessionIdParamsDtoCopyWith<$Res> implements $SessionIdParamsDtoCopyWith<$Res> {
  factory _$SessionIdParamsDtoCopyWith(_SessionIdParamsDto value, $Res Function(_SessionIdParamsDto) _then) = __$SessionIdParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String sessionId
});




}
/// @nodoc
class __$SessionIdParamsDtoCopyWithImpl<$Res>
    implements _$SessionIdParamsDtoCopyWith<$Res> {
  __$SessionIdParamsDtoCopyWithImpl(this._self, this._then);

  final _SessionIdParamsDto _self;
  final $Res Function(_SessionIdParamsDto) _then;

/// Create a copy of SessionIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,}) {
  return _then(_SessionIdParamsDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ApprovalResolveParamsDto {

 String get approvalId; bool get approved;
/// Create a copy of ApprovalResolveParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApprovalResolveParamsDtoCopyWith<ApprovalResolveParamsDto> get copyWith => _$ApprovalResolveParamsDtoCopyWithImpl<ApprovalResolveParamsDto>(this as ApprovalResolveParamsDto, _$identity);

  /// Serializes this ApprovalResolveParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApprovalResolveParamsDto&&(identical(other.approvalId, approvalId) || other.approvalId == approvalId)&&(identical(other.approved, approved) || other.approved == approved));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,approvalId,approved);

@override
String toString() {
  return 'ApprovalResolveParamsDto(approvalId: $approvalId, approved: $approved)';
}


}

/// @nodoc
abstract mixin class $ApprovalResolveParamsDtoCopyWith<$Res>  {
  factory $ApprovalResolveParamsDtoCopyWith(ApprovalResolveParamsDto value, $Res Function(ApprovalResolveParamsDto) _then) = _$ApprovalResolveParamsDtoCopyWithImpl;
@useResult
$Res call({
 String approvalId, bool approved
});




}
/// @nodoc
class _$ApprovalResolveParamsDtoCopyWithImpl<$Res>
    implements $ApprovalResolveParamsDtoCopyWith<$Res> {
  _$ApprovalResolveParamsDtoCopyWithImpl(this._self, this._then);

  final ApprovalResolveParamsDto _self;
  final $Res Function(ApprovalResolveParamsDto) _then;

/// Create a copy of ApprovalResolveParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? approvalId = null,Object? approved = null,}) {
  return _then(ApprovalResolveParamsDto(
approvalId: null == approvalId ? _self.approvalId : approvalId // ignore: cast_nullable_to_non_nullable
as String,approved: null == approved ? _self.approved : approved // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ApprovalResolveParamsDto].
extension ApprovalResolveParamsDtoPatterns on ApprovalResolveParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ApprovalResolveParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ApprovalResolveParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ApprovalResolveParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _ApprovalResolveParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ApprovalResolveParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _ApprovalResolveParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String approvalId,  bool approved)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ApprovalResolveParamsDto() when $default != null:
return $default(_that.approvalId,_that.approved);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String approvalId,  bool approved)  $default,) {final _that = this;
switch (_that) {
case _ApprovalResolveParamsDto():
return $default(_that.approvalId,_that.approved);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String approvalId,  bool approved)?  $default,) {final _that = this;
switch (_that) {
case _ApprovalResolveParamsDto() when $default != null:
return $default(_that.approvalId,_that.approved);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ApprovalResolveParamsDto implements ApprovalResolveParamsDto {
  const _ApprovalResolveParamsDto({required this.approvalId, required this.approved});
  factory _ApprovalResolveParamsDto.fromJson(Map<String, dynamic> json) => _$ApprovalResolveParamsDtoFromJson(json);

@override final  String approvalId;
@override final  bool approved;

/// Create a copy of ApprovalResolveParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ApprovalResolveParamsDtoCopyWith<_ApprovalResolveParamsDto> get copyWith => __$ApprovalResolveParamsDtoCopyWithImpl<_ApprovalResolveParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ApprovalResolveParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ApprovalResolveParamsDto&&(identical(other.approvalId, approvalId) || other.approvalId == approvalId)&&(identical(other.approved, approved) || other.approved == approved));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,approvalId,approved);

@override
String toString() {
  return 'ApprovalResolveParamsDto(approvalId: $approvalId, approved: $approved)';
}


}

/// @nodoc
abstract mixin class _$ApprovalResolveParamsDtoCopyWith<$Res> implements $ApprovalResolveParamsDtoCopyWith<$Res> {
  factory _$ApprovalResolveParamsDtoCopyWith(_ApprovalResolveParamsDto value, $Res Function(_ApprovalResolveParamsDto) _then) = __$ApprovalResolveParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String approvalId, bool approved
});




}
/// @nodoc
class __$ApprovalResolveParamsDtoCopyWithImpl<$Res>
    implements _$ApprovalResolveParamsDtoCopyWith<$Res> {
  __$ApprovalResolveParamsDtoCopyWithImpl(this._self, this._then);

  final _ApprovalResolveParamsDto _self;
  final $Res Function(_ApprovalResolveParamsDto) _then;

/// Create a copy of ApprovalResolveParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? approvalId = null,Object? approved = null,}) {
  return _then(_ApprovalResolveParamsDto(
approvalId: null == approvalId ? _self.approvalId : approvalId // ignore: cast_nullable_to_non_nullable
as String,approved: null == approved ? _self.approved : approved // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$SessionPendingInputParamsDto {

 String get sessionId;
/// Create a copy of SessionPendingInputParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionPendingInputParamsDtoCopyWith<SessionPendingInputParamsDto> get copyWith => _$SessionPendingInputParamsDtoCopyWithImpl<SessionPendingInputParamsDto>(this as SessionPendingInputParamsDto, _$identity);

  /// Serializes this SessionPendingInputParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionPendingInputParamsDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId);

@override
String toString() {
  return 'SessionPendingInputParamsDto(sessionId: $sessionId)';
}


}

/// @nodoc
abstract mixin class $SessionPendingInputParamsDtoCopyWith<$Res>  {
  factory $SessionPendingInputParamsDtoCopyWith(SessionPendingInputParamsDto value, $Res Function(SessionPendingInputParamsDto) _then) = _$SessionPendingInputParamsDtoCopyWithImpl;
@useResult
$Res call({
 String sessionId
});




}
/// @nodoc
class _$SessionPendingInputParamsDtoCopyWithImpl<$Res>
    implements $SessionPendingInputParamsDtoCopyWith<$Res> {
  _$SessionPendingInputParamsDtoCopyWithImpl(this._self, this._then);

  final SessionPendingInputParamsDto _self;
  final $Res Function(SessionPendingInputParamsDto) _then;

/// Create a copy of SessionPendingInputParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,}) {
  return _then(SessionPendingInputParamsDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionPendingInputParamsDto].
extension SessionPendingInputParamsDtoPatterns on SessionPendingInputParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionPendingInputParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionPendingInputParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionPendingInputParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _SessionPendingInputParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionPendingInputParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _SessionPendingInputParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sessionId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionPendingInputParamsDto() when $default != null:
return $default(_that.sessionId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sessionId)  $default,) {final _that = this;
switch (_that) {
case _SessionPendingInputParamsDto():
return $default(_that.sessionId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sessionId)?  $default,) {final _that = this;
switch (_that) {
case _SessionPendingInputParamsDto() when $default != null:
return $default(_that.sessionId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SessionPendingInputParamsDto implements SessionPendingInputParamsDto {
  const _SessionPendingInputParamsDto({required this.sessionId});
  factory _SessionPendingInputParamsDto.fromJson(Map<String, dynamic> json) => _$SessionPendingInputParamsDtoFromJson(json);

@override final  String sessionId;

/// Create a copy of SessionPendingInputParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionPendingInputParamsDtoCopyWith<_SessionPendingInputParamsDto> get copyWith => __$SessionPendingInputParamsDtoCopyWithImpl<_SessionPendingInputParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionPendingInputParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionPendingInputParamsDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId);

@override
String toString() {
  return 'SessionPendingInputParamsDto(sessionId: $sessionId)';
}


}

/// @nodoc
abstract mixin class _$SessionPendingInputParamsDtoCopyWith<$Res> implements $SessionPendingInputParamsDtoCopyWith<$Res> {
  factory _$SessionPendingInputParamsDtoCopyWith(_SessionPendingInputParamsDto value, $Res Function(_SessionPendingInputParamsDto) _then) = __$SessionPendingInputParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String sessionId
});




}
/// @nodoc
class __$SessionPendingInputParamsDtoCopyWithImpl<$Res>
    implements _$SessionPendingInputParamsDtoCopyWith<$Res> {
  __$SessionPendingInputParamsDtoCopyWithImpl(this._self, this._then);

  final _SessionPendingInputParamsDto _self;
  final $Res Function(_SessionPendingInputParamsDto) _then;

/// Create a copy of SessionPendingInputParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,}) {
  return _then(_SessionPendingInputParamsDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$UserQuestionAnswerParamsDto {

 String get requestId; List<UserQuestionAnswerDto> get answers;
/// Create a copy of UserQuestionAnswerParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserQuestionAnswerParamsDtoCopyWith<UserQuestionAnswerParamsDto> get copyWith => _$UserQuestionAnswerParamsDtoCopyWithImpl<UserQuestionAnswerParamsDto>(this as UserQuestionAnswerParamsDto, _$identity);

  /// Serializes this UserQuestionAnswerParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserQuestionAnswerParamsDto&&(identical(other.requestId, requestId) || other.requestId == requestId)&&const DeepCollectionEquality().equals(other.answers, answers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,requestId,const DeepCollectionEquality().hash(answers));

@override
String toString() {
  return 'UserQuestionAnswerParamsDto(requestId: $requestId, answers: $answers)';
}


}

/// @nodoc
abstract mixin class $UserQuestionAnswerParamsDtoCopyWith<$Res>  {
  factory $UserQuestionAnswerParamsDtoCopyWith(UserQuestionAnswerParamsDto value, $Res Function(UserQuestionAnswerParamsDto) _then) = _$UserQuestionAnswerParamsDtoCopyWithImpl;
@useResult
$Res call({
 String requestId, List<UserQuestionAnswerDto> answers
});




}
/// @nodoc
class _$UserQuestionAnswerParamsDtoCopyWithImpl<$Res>
    implements $UserQuestionAnswerParamsDtoCopyWith<$Res> {
  _$UserQuestionAnswerParamsDtoCopyWithImpl(this._self, this._then);

  final UserQuestionAnswerParamsDto _self;
  final $Res Function(UserQuestionAnswerParamsDto) _then;

/// Create a copy of UserQuestionAnswerParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? requestId = null,Object? answers = null,}) {
  return _then(UserQuestionAnswerParamsDto(
requestId: null == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String,answers: null == answers ? _self.answers : answers // ignore: cast_nullable_to_non_nullable
as List<UserQuestionAnswerDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [UserQuestionAnswerParamsDto].
extension UserQuestionAnswerParamsDtoPatterns on UserQuestionAnswerParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserQuestionAnswerParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserQuestionAnswerParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserQuestionAnswerParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _UserQuestionAnswerParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserQuestionAnswerParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _UserQuestionAnswerParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String requestId,  List<UserQuestionAnswerDto> answers)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserQuestionAnswerParamsDto() when $default != null:
return $default(_that.requestId,_that.answers);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String requestId,  List<UserQuestionAnswerDto> answers)  $default,) {final _that = this;
switch (_that) {
case _UserQuestionAnswerParamsDto():
return $default(_that.requestId,_that.answers);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String requestId,  List<UserQuestionAnswerDto> answers)?  $default,) {final _that = this;
switch (_that) {
case _UserQuestionAnswerParamsDto() when $default != null:
return $default(_that.requestId,_that.answers);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserQuestionAnswerParamsDto implements UserQuestionAnswerParamsDto {
  const _UserQuestionAnswerParamsDto({required this.requestId, required  List<UserQuestionAnswerDto> answers}): _answers = answers;
  factory _UserQuestionAnswerParamsDto.fromJson(Map<String, dynamic> json) => _$UserQuestionAnswerParamsDtoFromJson(json);

@override final  String requestId;
 final  List<UserQuestionAnswerDto> _answers;
@override List<UserQuestionAnswerDto> get answers {
  if (_answers is EqualUnmodifiableListView) return _answers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_answers);
}


/// Create a copy of UserQuestionAnswerParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserQuestionAnswerParamsDtoCopyWith<_UserQuestionAnswerParamsDto> get copyWith => __$UserQuestionAnswerParamsDtoCopyWithImpl<_UserQuestionAnswerParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserQuestionAnswerParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserQuestionAnswerParamsDto&&(identical(other.requestId, requestId) || other.requestId == requestId)&&const DeepCollectionEquality().equals(other._answers, _answers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,requestId,const DeepCollectionEquality().hash(_answers));

@override
String toString() {
  return 'UserQuestionAnswerParamsDto(requestId: $requestId, answers: $answers)';
}


}

/// @nodoc
abstract mixin class _$UserQuestionAnswerParamsDtoCopyWith<$Res> implements $UserQuestionAnswerParamsDtoCopyWith<$Res> {
  factory _$UserQuestionAnswerParamsDtoCopyWith(_UserQuestionAnswerParamsDto value, $Res Function(_UserQuestionAnswerParamsDto) _then) = __$UserQuestionAnswerParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String requestId, List<UserQuestionAnswerDto> answers
});




}
/// @nodoc
class __$UserQuestionAnswerParamsDtoCopyWithImpl<$Res>
    implements _$UserQuestionAnswerParamsDtoCopyWith<$Res> {
  __$UserQuestionAnswerParamsDtoCopyWithImpl(this._self, this._then);

  final _UserQuestionAnswerParamsDto _self;
  final $Res Function(_UserQuestionAnswerParamsDto) _then;

/// Create a copy of UserQuestionAnswerParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? requestId = null,Object? answers = null,}) {
  return _then(_UserQuestionAnswerParamsDto(
requestId: null == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String,answers: null == answers ? _self._answers : answers // ignore: cast_nullable_to_non_nullable
as List<UserQuestionAnswerDto>,
  ));
}


}


/// @nodoc
mixin _$TimelineSubscribeParamsDto {

 String get sessionId; int get afterSequence; int? get tailLimit;
/// Create a copy of TimelineSubscribeParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TimelineSubscribeParamsDtoCopyWith<TimelineSubscribeParamsDto> get copyWith => _$TimelineSubscribeParamsDtoCopyWithImpl<TimelineSubscribeParamsDto>(this as TimelineSubscribeParamsDto, _$identity);

  /// Serializes this TimelineSubscribeParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TimelineSubscribeParamsDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.afterSequence, afterSequence) || other.afterSequence == afterSequence)&&(identical(other.tailLimit, tailLimit) || other.tailLimit == tailLimit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,afterSequence,tailLimit);

@override
String toString() {
  return 'TimelineSubscribeParamsDto(sessionId: $sessionId, afterSequence: $afterSequence, tailLimit: $tailLimit)';
}


}

/// @nodoc
abstract mixin class $TimelineSubscribeParamsDtoCopyWith<$Res>  {
  factory $TimelineSubscribeParamsDtoCopyWith(TimelineSubscribeParamsDto value, $Res Function(TimelineSubscribeParamsDto) _then) = _$TimelineSubscribeParamsDtoCopyWithImpl;
@useResult
$Res call({
 String sessionId, int afterSequence, int? tailLimit
});




}
/// @nodoc
class _$TimelineSubscribeParamsDtoCopyWithImpl<$Res>
    implements $TimelineSubscribeParamsDtoCopyWith<$Res> {
  _$TimelineSubscribeParamsDtoCopyWithImpl(this._self, this._then);

  final TimelineSubscribeParamsDto _self;
  final $Res Function(TimelineSubscribeParamsDto) _then;

/// Create a copy of TimelineSubscribeParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? afterSequence = null,Object? tailLimit = freezed,}) {
  return _then(TimelineSubscribeParamsDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,afterSequence: null == afterSequence ? _self.afterSequence : afterSequence // ignore: cast_nullable_to_non_nullable
as int,tailLimit: freezed == tailLimit ? _self.tailLimit : tailLimit // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [TimelineSubscribeParamsDto].
extension TimelineSubscribeParamsDtoPatterns on TimelineSubscribeParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TimelineSubscribeParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TimelineSubscribeParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TimelineSubscribeParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _TimelineSubscribeParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TimelineSubscribeParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _TimelineSubscribeParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sessionId,  int afterSequence,  int? tailLimit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TimelineSubscribeParamsDto() when $default != null:
return $default(_that.sessionId,_that.afterSequence,_that.tailLimit);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sessionId,  int afterSequence,  int? tailLimit)  $default,) {final _that = this;
switch (_that) {
case _TimelineSubscribeParamsDto():
return $default(_that.sessionId,_that.afterSequence,_that.tailLimit);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sessionId,  int afterSequence,  int? tailLimit)?  $default,) {final _that = this;
switch (_that) {
case _TimelineSubscribeParamsDto() when $default != null:
return $default(_that.sessionId,_that.afterSequence,_that.tailLimit);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TimelineSubscribeParamsDto implements TimelineSubscribeParamsDto {
  const _TimelineSubscribeParamsDto({required this.sessionId, required this.afterSequence, this.tailLimit});
  factory _TimelineSubscribeParamsDto.fromJson(Map<String, dynamic> json) => _$TimelineSubscribeParamsDtoFromJson(json);

@override final  String sessionId;
@override final  int afterSequence;
@override final  int? tailLimit;

/// Create a copy of TimelineSubscribeParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TimelineSubscribeParamsDtoCopyWith<_TimelineSubscribeParamsDto> get copyWith => __$TimelineSubscribeParamsDtoCopyWithImpl<_TimelineSubscribeParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TimelineSubscribeParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TimelineSubscribeParamsDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.afterSequence, afterSequence) || other.afterSequence == afterSequence)&&(identical(other.tailLimit, tailLimit) || other.tailLimit == tailLimit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,afterSequence,tailLimit);

@override
String toString() {
  return 'TimelineSubscribeParamsDto(sessionId: $sessionId, afterSequence: $afterSequence, tailLimit: $tailLimit)';
}


}

/// @nodoc
abstract mixin class _$TimelineSubscribeParamsDtoCopyWith<$Res> implements $TimelineSubscribeParamsDtoCopyWith<$Res> {
  factory _$TimelineSubscribeParamsDtoCopyWith(_TimelineSubscribeParamsDto value, $Res Function(_TimelineSubscribeParamsDto) _then) = __$TimelineSubscribeParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, int afterSequence, int? tailLimit
});




}
/// @nodoc
class __$TimelineSubscribeParamsDtoCopyWithImpl<$Res>
    implements _$TimelineSubscribeParamsDtoCopyWith<$Res> {
  __$TimelineSubscribeParamsDtoCopyWithImpl(this._self, this._then);

  final _TimelineSubscribeParamsDto _self;
  final $Res Function(_TimelineSubscribeParamsDto) _then;

/// Create a copy of TimelineSubscribeParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? afterSequence = null,Object? tailLimit = freezed,}) {
  return _then(_TimelineSubscribeParamsDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,afterSequence: null == afterSequence ? _self.afterSequence : afterSequence // ignore: cast_nullable_to_non_nullable
as int,tailLimit: freezed == tailLimit ? _self.tailLimit : tailLimit // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$TimelineHistoryParamsDto {

 String get sessionId; int get beforeSequence; int get limit;
/// Create a copy of TimelineHistoryParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TimelineHistoryParamsDtoCopyWith<TimelineHistoryParamsDto> get copyWith => _$TimelineHistoryParamsDtoCopyWithImpl<TimelineHistoryParamsDto>(this as TimelineHistoryParamsDto, _$identity);

  /// Serializes this TimelineHistoryParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TimelineHistoryParamsDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.beforeSequence, beforeSequence) || other.beforeSequence == beforeSequence)&&(identical(other.limit, limit) || other.limit == limit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,beforeSequence,limit);

@override
String toString() {
  return 'TimelineHistoryParamsDto(sessionId: $sessionId, beforeSequence: $beforeSequence, limit: $limit)';
}


}

/// @nodoc
abstract mixin class $TimelineHistoryParamsDtoCopyWith<$Res>  {
  factory $TimelineHistoryParamsDtoCopyWith(TimelineHistoryParamsDto value, $Res Function(TimelineHistoryParamsDto) _then) = _$TimelineHistoryParamsDtoCopyWithImpl;
@useResult
$Res call({
 String sessionId, int beforeSequence, int limit
});




}
/// @nodoc
class _$TimelineHistoryParamsDtoCopyWithImpl<$Res>
    implements $TimelineHistoryParamsDtoCopyWith<$Res> {
  _$TimelineHistoryParamsDtoCopyWithImpl(this._self, this._then);

  final TimelineHistoryParamsDto _self;
  final $Res Function(TimelineHistoryParamsDto) _then;

/// Create a copy of TimelineHistoryParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? beforeSequence = null,Object? limit = null,}) {
  return _then(TimelineHistoryParamsDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,beforeSequence: null == beforeSequence ? _self.beforeSequence : beforeSequence // ignore: cast_nullable_to_non_nullable
as int,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TimelineHistoryParamsDto].
extension TimelineHistoryParamsDtoPatterns on TimelineHistoryParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TimelineHistoryParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TimelineHistoryParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TimelineHistoryParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _TimelineHistoryParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TimelineHistoryParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _TimelineHistoryParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sessionId,  int beforeSequence,  int limit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TimelineHistoryParamsDto() when $default != null:
return $default(_that.sessionId,_that.beforeSequence,_that.limit);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sessionId,  int beforeSequence,  int limit)  $default,) {final _that = this;
switch (_that) {
case _TimelineHistoryParamsDto():
return $default(_that.sessionId,_that.beforeSequence,_that.limit);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sessionId,  int beforeSequence,  int limit)?  $default,) {final _that = this;
switch (_that) {
case _TimelineHistoryParamsDto() when $default != null:
return $default(_that.sessionId,_that.beforeSequence,_that.limit);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TimelineHistoryParamsDto implements TimelineHistoryParamsDto {
  const _TimelineHistoryParamsDto({required this.sessionId, required this.beforeSequence, required this.limit});
  factory _TimelineHistoryParamsDto.fromJson(Map<String, dynamic> json) => _$TimelineHistoryParamsDtoFromJson(json);

@override final  String sessionId;
@override final  int beforeSequence;
@override final  int limit;

/// Create a copy of TimelineHistoryParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TimelineHistoryParamsDtoCopyWith<_TimelineHistoryParamsDto> get copyWith => __$TimelineHistoryParamsDtoCopyWithImpl<_TimelineHistoryParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TimelineHistoryParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TimelineHistoryParamsDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.beforeSequence, beforeSequence) || other.beforeSequence == beforeSequence)&&(identical(other.limit, limit) || other.limit == limit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,beforeSequence,limit);

@override
String toString() {
  return 'TimelineHistoryParamsDto(sessionId: $sessionId, beforeSequence: $beforeSequence, limit: $limit)';
}


}

/// @nodoc
abstract mixin class _$TimelineHistoryParamsDtoCopyWith<$Res> implements $TimelineHistoryParamsDtoCopyWith<$Res> {
  factory _$TimelineHistoryParamsDtoCopyWith(_TimelineHistoryParamsDto value, $Res Function(_TimelineHistoryParamsDto) _then) = __$TimelineHistoryParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, int beforeSequence, int limit
});




}
/// @nodoc
class __$TimelineHistoryParamsDtoCopyWithImpl<$Res>
    implements _$TimelineHistoryParamsDtoCopyWith<$Res> {
  __$TimelineHistoryParamsDtoCopyWithImpl(this._self, this._then);

  final _TimelineHistoryParamsDto _self;
  final $Res Function(_TimelineHistoryParamsDto) _then;

/// Create a copy of TimelineHistoryParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? beforeSequence = null,Object? limit = null,}) {
  return _then(_TimelineHistoryParamsDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,beforeSequence: null == beforeSequence ? _self.beforeSequence : beforeSequence // ignore: cast_nullable_to_non_nullable
as int,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$WorkspaceCatalogResultDto {

 WorkspaceCatalogDto get catalog;
/// Create a copy of WorkspaceCatalogResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceCatalogResultDtoCopyWith<WorkspaceCatalogResultDto> get copyWith => _$WorkspaceCatalogResultDtoCopyWithImpl<WorkspaceCatalogResultDto>(this as WorkspaceCatalogResultDto, _$identity);

  /// Serializes this WorkspaceCatalogResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkspaceCatalogResultDto&&(identical(other.catalog, catalog) || other.catalog == catalog));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,catalog);

@override
String toString() {
  return 'WorkspaceCatalogResultDto(catalog: $catalog)';
}


}

/// @nodoc
abstract mixin class $WorkspaceCatalogResultDtoCopyWith<$Res>  {
  factory $WorkspaceCatalogResultDtoCopyWith(WorkspaceCatalogResultDto value, $Res Function(WorkspaceCatalogResultDto) _then) = _$WorkspaceCatalogResultDtoCopyWithImpl;
@useResult
$Res call({
 WorkspaceCatalogDto catalog
});


$WorkspaceCatalogDtoCopyWith<$Res> get catalog;

}
/// @nodoc
class _$WorkspaceCatalogResultDtoCopyWithImpl<$Res>
    implements $WorkspaceCatalogResultDtoCopyWith<$Res> {
  _$WorkspaceCatalogResultDtoCopyWithImpl(this._self, this._then);

  final WorkspaceCatalogResultDto _self;
  final $Res Function(WorkspaceCatalogResultDto) _then;

/// Create a copy of WorkspaceCatalogResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? catalog = null,}) {
  return _then(WorkspaceCatalogResultDto(
catalog: null == catalog ? _self.catalog : catalog // ignore: cast_nullable_to_non_nullable
as WorkspaceCatalogDto,
  ));
}
/// Create a copy of WorkspaceCatalogResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkspaceCatalogDtoCopyWith<$Res> get catalog {

  return $WorkspaceCatalogDtoCopyWith<$Res>(_self.catalog, (value) {
    return _then(_self.copyWith(catalog: value));
  });
}
}


/// Adds pattern-matching-related methods to [WorkspaceCatalogResultDto].
extension WorkspaceCatalogResultDtoPatterns on WorkspaceCatalogResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkspaceCatalogResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkspaceCatalogResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkspaceCatalogResultDto value)  $default,){
final _that = this;
switch (_that) {
case _WorkspaceCatalogResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkspaceCatalogResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _WorkspaceCatalogResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( WorkspaceCatalogDto catalog)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkspaceCatalogResultDto() when $default != null:
return $default(_that.catalog);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( WorkspaceCatalogDto catalog)  $default,) {final _that = this;
switch (_that) {
case _WorkspaceCatalogResultDto():
return $default(_that.catalog);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( WorkspaceCatalogDto catalog)?  $default,) {final _that = this;
switch (_that) {
case _WorkspaceCatalogResultDto() when $default != null:
return $default(_that.catalog);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorkspaceCatalogResultDto implements WorkspaceCatalogResultDto {
  const _WorkspaceCatalogResultDto({required this.catalog});
  factory _WorkspaceCatalogResultDto.fromJson(Map<String, dynamic> json) => _$WorkspaceCatalogResultDtoFromJson(json);

@override final  WorkspaceCatalogDto catalog;

/// Create a copy of WorkspaceCatalogResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceCatalogResultDtoCopyWith<_WorkspaceCatalogResultDto> get copyWith => __$WorkspaceCatalogResultDtoCopyWithImpl<_WorkspaceCatalogResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkspaceCatalogResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkspaceCatalogResultDto&&(identical(other.catalog, catalog) || other.catalog == catalog));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,catalog);

@override
String toString() {
  return 'WorkspaceCatalogResultDto(catalog: $catalog)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceCatalogResultDtoCopyWith<$Res> implements $WorkspaceCatalogResultDtoCopyWith<$Res> {
  factory _$WorkspaceCatalogResultDtoCopyWith(_WorkspaceCatalogResultDto value, $Res Function(_WorkspaceCatalogResultDto) _then) = __$WorkspaceCatalogResultDtoCopyWithImpl;
@override @useResult
$Res call({
 WorkspaceCatalogDto catalog
});


@override $WorkspaceCatalogDtoCopyWith<$Res> get catalog;

}
/// @nodoc
class __$WorkspaceCatalogResultDtoCopyWithImpl<$Res>
    implements _$WorkspaceCatalogResultDtoCopyWith<$Res> {
  __$WorkspaceCatalogResultDtoCopyWithImpl(this._self, this._then);

  final _WorkspaceCatalogResultDto _self;
  final $Res Function(_WorkspaceCatalogResultDto) _then;

/// Create a copy of WorkspaceCatalogResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? catalog = null,}) {
  return _then(_WorkspaceCatalogResultDto(
catalog: null == catalog ? _self.catalog : catalog // ignore: cast_nullable_to_non_nullable
as WorkspaceCatalogDto,
  ));
}

/// Create a copy of WorkspaceCatalogResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkspaceCatalogDtoCopyWith<$Res> get catalog {

  return $WorkspaceCatalogDtoCopyWith<$Res>(_self.catalog, (value) {
    return _then(_self.copyWith(catalog: value));
  });
}
}


/// @nodoc
mixin _$WorkspaceRegisterResultDto {

 WorkspaceDto get workspace; List<WorktreeDto> get worktrees;
/// Create a copy of WorkspaceRegisterResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceRegisterResultDtoCopyWith<WorkspaceRegisterResultDto> get copyWith => _$WorkspaceRegisterResultDtoCopyWithImpl<WorkspaceRegisterResultDto>(this as WorkspaceRegisterResultDto, _$identity);

  /// Serializes this WorkspaceRegisterResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkspaceRegisterResultDto&&(identical(other.workspace, workspace) || other.workspace == workspace)&&const DeepCollectionEquality().equals(other.worktrees, worktrees));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,workspace,const DeepCollectionEquality().hash(worktrees));

@override
String toString() {
  return 'WorkspaceRegisterResultDto(workspace: $workspace, worktrees: $worktrees)';
}


}

/// @nodoc
abstract mixin class $WorkspaceRegisterResultDtoCopyWith<$Res>  {
  factory $WorkspaceRegisterResultDtoCopyWith(WorkspaceRegisterResultDto value, $Res Function(WorkspaceRegisterResultDto) _then) = _$WorkspaceRegisterResultDtoCopyWithImpl;
@useResult
$Res call({
 WorkspaceDto workspace, List<WorktreeDto> worktrees
});


$WorkspaceDtoCopyWith<$Res> get workspace;

}
/// @nodoc
class _$WorkspaceRegisterResultDtoCopyWithImpl<$Res>
    implements $WorkspaceRegisterResultDtoCopyWith<$Res> {
  _$WorkspaceRegisterResultDtoCopyWithImpl(this._self, this._then);

  final WorkspaceRegisterResultDto _self;
  final $Res Function(WorkspaceRegisterResultDto) _then;

/// Create a copy of WorkspaceRegisterResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? workspace = null,Object? worktrees = null,}) {
  return _then(WorkspaceRegisterResultDto(
workspace: null == workspace ? _self.workspace : workspace // ignore: cast_nullable_to_non_nullable
as WorkspaceDto,worktrees: null == worktrees ? _self.worktrees : worktrees // ignore: cast_nullable_to_non_nullable
as List<WorktreeDto>,
  ));
}
/// Create a copy of WorkspaceRegisterResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkspaceDtoCopyWith<$Res> get workspace {

  return $WorkspaceDtoCopyWith<$Res>(_self.workspace, (value) {
    return _then(_self.copyWith(workspace: value));
  });
}
}


/// Adds pattern-matching-related methods to [WorkspaceRegisterResultDto].
extension WorkspaceRegisterResultDtoPatterns on WorkspaceRegisterResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkspaceRegisterResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkspaceRegisterResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkspaceRegisterResultDto value)  $default,){
final _that = this;
switch (_that) {
case _WorkspaceRegisterResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkspaceRegisterResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _WorkspaceRegisterResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( WorkspaceDto workspace,  List<WorktreeDto> worktrees)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkspaceRegisterResultDto() when $default != null:
return $default(_that.workspace,_that.worktrees);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( WorkspaceDto workspace,  List<WorktreeDto> worktrees)  $default,) {final _that = this;
switch (_that) {
case _WorkspaceRegisterResultDto():
return $default(_that.workspace,_that.worktrees);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( WorkspaceDto workspace,  List<WorktreeDto> worktrees)?  $default,) {final _that = this;
switch (_that) {
case _WorkspaceRegisterResultDto() when $default != null:
return $default(_that.workspace,_that.worktrees);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorkspaceRegisterResultDto implements WorkspaceRegisterResultDto {
  const _WorkspaceRegisterResultDto({required this.workspace, required  List<WorktreeDto> worktrees}): _worktrees = worktrees;
  factory _WorkspaceRegisterResultDto.fromJson(Map<String, dynamic> json) => _$WorkspaceRegisterResultDtoFromJson(json);

@override final  WorkspaceDto workspace;
 final  List<WorktreeDto> _worktrees;
@override List<WorktreeDto> get worktrees {
  if (_worktrees is EqualUnmodifiableListView) return _worktrees;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_worktrees);
}


/// Create a copy of WorkspaceRegisterResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceRegisterResultDtoCopyWith<_WorkspaceRegisterResultDto> get copyWith => __$WorkspaceRegisterResultDtoCopyWithImpl<_WorkspaceRegisterResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkspaceRegisterResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkspaceRegisterResultDto&&(identical(other.workspace, workspace) || other.workspace == workspace)&&const DeepCollectionEquality().equals(other._worktrees, _worktrees));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,workspace,const DeepCollectionEquality().hash(_worktrees));

@override
String toString() {
  return 'WorkspaceRegisterResultDto(workspace: $workspace, worktrees: $worktrees)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceRegisterResultDtoCopyWith<$Res> implements $WorkspaceRegisterResultDtoCopyWith<$Res> {
  factory _$WorkspaceRegisterResultDtoCopyWith(_WorkspaceRegisterResultDto value, $Res Function(_WorkspaceRegisterResultDto) _then) = __$WorkspaceRegisterResultDtoCopyWithImpl;
@override @useResult
$Res call({
 WorkspaceDto workspace, List<WorktreeDto> worktrees
});


@override $WorkspaceDtoCopyWith<$Res> get workspace;

}
/// @nodoc
class __$WorkspaceRegisterResultDtoCopyWithImpl<$Res>
    implements _$WorkspaceRegisterResultDtoCopyWith<$Res> {
  __$WorkspaceRegisterResultDtoCopyWithImpl(this._self, this._then);

  final _WorkspaceRegisterResultDto _self;
  final $Res Function(_WorkspaceRegisterResultDto) _then;

/// Create a copy of WorkspaceRegisterResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? workspace = null,Object? worktrees = null,}) {
  return _then(_WorkspaceRegisterResultDto(
workspace: null == workspace ? _self.workspace : workspace // ignore: cast_nullable_to_non_nullable
as WorkspaceDto,worktrees: null == worktrees ? _self._worktrees : worktrees // ignore: cast_nullable_to_non_nullable
as List<WorktreeDto>,
  ));
}

/// Create a copy of WorkspaceRegisterResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkspaceDtoCopyWith<$Res> get workspace {

  return $WorkspaceDtoCopyWith<$Res>(_self.workspace, (value) {
    return _then(_self.copyWith(workspace: value));
  });
}
}


/// @nodoc
mixin _$WorkspaceUnregisterResultDto {

 bool get unregistered;
/// Create a copy of WorkspaceUnregisterResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceUnregisterResultDtoCopyWith<WorkspaceUnregisterResultDto> get copyWith => _$WorkspaceUnregisterResultDtoCopyWithImpl<WorkspaceUnregisterResultDto>(this as WorkspaceUnregisterResultDto, _$identity);

  /// Serializes this WorkspaceUnregisterResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkspaceUnregisterResultDto&&(identical(other.unregistered, unregistered) || other.unregistered == unregistered));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,unregistered);

@override
String toString() {
  return 'WorkspaceUnregisterResultDto(unregistered: $unregistered)';
}


}

/// @nodoc
abstract mixin class $WorkspaceUnregisterResultDtoCopyWith<$Res>  {
  factory $WorkspaceUnregisterResultDtoCopyWith(WorkspaceUnregisterResultDto value, $Res Function(WorkspaceUnregisterResultDto) _then) = _$WorkspaceUnregisterResultDtoCopyWithImpl;
@useResult
$Res call({
 bool unregistered
});




}
/// @nodoc
class _$WorkspaceUnregisterResultDtoCopyWithImpl<$Res>
    implements $WorkspaceUnregisterResultDtoCopyWith<$Res> {
  _$WorkspaceUnregisterResultDtoCopyWithImpl(this._self, this._then);

  final WorkspaceUnregisterResultDto _self;
  final $Res Function(WorkspaceUnregisterResultDto) _then;

/// Create a copy of WorkspaceUnregisterResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? unregistered = null,}) {
  return _then(WorkspaceUnregisterResultDto(
unregistered: null == unregistered ? _self.unregistered : unregistered // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkspaceUnregisterResultDto].
extension WorkspaceUnregisterResultDtoPatterns on WorkspaceUnregisterResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkspaceUnregisterResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkspaceUnregisterResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkspaceUnregisterResultDto value)  $default,){
final _that = this;
switch (_that) {
case _WorkspaceUnregisterResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkspaceUnregisterResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _WorkspaceUnregisterResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool unregistered)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkspaceUnregisterResultDto() when $default != null:
return $default(_that.unregistered);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool unregistered)  $default,) {final _that = this;
switch (_that) {
case _WorkspaceUnregisterResultDto():
return $default(_that.unregistered);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool unregistered)?  $default,) {final _that = this;
switch (_that) {
case _WorkspaceUnregisterResultDto() when $default != null:
return $default(_that.unregistered);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorkspaceUnregisterResultDto implements WorkspaceUnregisterResultDto {
  const _WorkspaceUnregisterResultDto({required this.unregistered});
  factory _WorkspaceUnregisterResultDto.fromJson(Map<String, dynamic> json) => _$WorkspaceUnregisterResultDtoFromJson(json);

@override final  bool unregistered;

/// Create a copy of WorkspaceUnregisterResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceUnregisterResultDtoCopyWith<_WorkspaceUnregisterResultDto> get copyWith => __$WorkspaceUnregisterResultDtoCopyWithImpl<_WorkspaceUnregisterResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkspaceUnregisterResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkspaceUnregisterResultDto&&(identical(other.unregistered, unregistered) || other.unregistered == unregistered));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,unregistered);

@override
String toString() {
  return 'WorkspaceUnregisterResultDto(unregistered: $unregistered)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceUnregisterResultDtoCopyWith<$Res> implements $WorkspaceUnregisterResultDtoCopyWith<$Res> {
  factory _$WorkspaceUnregisterResultDtoCopyWith(_WorkspaceUnregisterResultDto value, $Res Function(_WorkspaceUnregisterResultDto) _then) = __$WorkspaceUnregisterResultDtoCopyWithImpl;
@override @useResult
$Res call({
 bool unregistered
});




}
/// @nodoc
class __$WorkspaceUnregisterResultDtoCopyWithImpl<$Res>
    implements _$WorkspaceUnregisterResultDtoCopyWith<$Res> {
  __$WorkspaceUnregisterResultDtoCopyWithImpl(this._self, this._then);

  final _WorkspaceUnregisterResultDto _self;
  final $Res Function(_WorkspaceUnregisterResultDto) _then;

/// Create a copy of WorkspaceUnregisterResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? unregistered = null,}) {
  return _then(_WorkspaceUnregisterResultDto(
unregistered: null == unregistered ? _self.unregistered : unregistered // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$DirectorySuggestResultDto {

 List<DirectorySuggestionDto> get suggestions;
/// Create a copy of DirectorySuggestResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DirectorySuggestResultDtoCopyWith<DirectorySuggestResultDto> get copyWith => _$DirectorySuggestResultDtoCopyWithImpl<DirectorySuggestResultDto>(this as DirectorySuggestResultDto, _$identity);

  /// Serializes this DirectorySuggestResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DirectorySuggestResultDto&&const DeepCollectionEquality().equals(other.suggestions, suggestions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(suggestions));

@override
String toString() {
  return 'DirectorySuggestResultDto(suggestions: $suggestions)';
}


}

/// @nodoc
abstract mixin class $DirectorySuggestResultDtoCopyWith<$Res>  {
  factory $DirectorySuggestResultDtoCopyWith(DirectorySuggestResultDto value, $Res Function(DirectorySuggestResultDto) _then) = _$DirectorySuggestResultDtoCopyWithImpl;
@useResult
$Res call({
 List<DirectorySuggestionDto> suggestions
});




}
/// @nodoc
class _$DirectorySuggestResultDtoCopyWithImpl<$Res>
    implements $DirectorySuggestResultDtoCopyWith<$Res> {
  _$DirectorySuggestResultDtoCopyWithImpl(this._self, this._then);

  final DirectorySuggestResultDto _self;
  final $Res Function(DirectorySuggestResultDto) _then;

/// Create a copy of DirectorySuggestResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? suggestions = null,}) {
  return _then(DirectorySuggestResultDto(
suggestions: null == suggestions ? _self.suggestions : suggestions // ignore: cast_nullable_to_non_nullable
as List<DirectorySuggestionDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [DirectorySuggestResultDto].
extension DirectorySuggestResultDtoPatterns on DirectorySuggestResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DirectorySuggestResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DirectorySuggestResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DirectorySuggestResultDto value)  $default,){
final _that = this;
switch (_that) {
case _DirectorySuggestResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DirectorySuggestResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _DirectorySuggestResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<DirectorySuggestionDto> suggestions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DirectorySuggestResultDto() when $default != null:
return $default(_that.suggestions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<DirectorySuggestionDto> suggestions)  $default,) {final _that = this;
switch (_that) {
case _DirectorySuggestResultDto():
return $default(_that.suggestions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<DirectorySuggestionDto> suggestions)?  $default,) {final _that = this;
switch (_that) {
case _DirectorySuggestResultDto() when $default != null:
return $default(_that.suggestions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DirectorySuggestResultDto implements DirectorySuggestResultDto {
  const _DirectorySuggestResultDto({required  List<DirectorySuggestionDto> suggestions}): _suggestions = suggestions;
  factory _DirectorySuggestResultDto.fromJson(Map<String, dynamic> json) => _$DirectorySuggestResultDtoFromJson(json);

 final  List<DirectorySuggestionDto> _suggestions;
@override List<DirectorySuggestionDto> get suggestions {
  if (_suggestions is EqualUnmodifiableListView) return _suggestions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_suggestions);
}


/// Create a copy of DirectorySuggestResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DirectorySuggestResultDtoCopyWith<_DirectorySuggestResultDto> get copyWith => __$DirectorySuggestResultDtoCopyWithImpl<_DirectorySuggestResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DirectorySuggestResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DirectorySuggestResultDto&&const DeepCollectionEquality().equals(other._suggestions, _suggestions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_suggestions));

@override
String toString() {
  return 'DirectorySuggestResultDto(suggestions: $suggestions)';
}


}

/// @nodoc
abstract mixin class _$DirectorySuggestResultDtoCopyWith<$Res> implements $DirectorySuggestResultDtoCopyWith<$Res> {
  factory _$DirectorySuggestResultDtoCopyWith(_DirectorySuggestResultDto value, $Res Function(_DirectorySuggestResultDto) _then) = __$DirectorySuggestResultDtoCopyWithImpl;
@override @useResult
$Res call({
 List<DirectorySuggestionDto> suggestions
});




}
/// @nodoc
class __$DirectorySuggestResultDtoCopyWithImpl<$Res>
    implements _$DirectorySuggestResultDtoCopyWith<$Res> {
  __$DirectorySuggestResultDtoCopyWithImpl(this._self, this._then);

  final _DirectorySuggestResultDto _self;
  final $Res Function(_DirectorySuggestResultDto) _then;

/// Create a copy of DirectorySuggestResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? suggestions = null,}) {
  return _then(_DirectorySuggestResultDto(
suggestions: null == suggestions ? _self._suggestions : suggestions // ignore: cast_nullable_to_non_nullable
as List<DirectorySuggestionDto>,
  ));
}


}


/// @nodoc
mixin _$FileSearchResultDto {

 List<FileMatchDto> get matches; bool get truncated;
/// Create a copy of FileSearchResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FileSearchResultDtoCopyWith<FileSearchResultDto> get copyWith => _$FileSearchResultDtoCopyWithImpl<FileSearchResultDto>(this as FileSearchResultDto, _$identity);

  /// Serializes this FileSearchResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileSearchResultDto&&const DeepCollectionEquality().equals(other.matches, matches)&&(identical(other.truncated, truncated) || other.truncated == truncated));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(matches),truncated);

@override
String toString() {
  return 'FileSearchResultDto(matches: $matches, truncated: $truncated)';
}


}

/// @nodoc
abstract mixin class $FileSearchResultDtoCopyWith<$Res>  {
  factory $FileSearchResultDtoCopyWith(FileSearchResultDto value, $Res Function(FileSearchResultDto) _then) = _$FileSearchResultDtoCopyWithImpl;
@useResult
$Res call({
 List<FileMatchDto> matches, bool truncated
});




}
/// @nodoc
class _$FileSearchResultDtoCopyWithImpl<$Res>
    implements $FileSearchResultDtoCopyWith<$Res> {
  _$FileSearchResultDtoCopyWithImpl(this._self, this._then);

  final FileSearchResultDto _self;
  final $Res Function(FileSearchResultDto) _then;

/// Create a copy of FileSearchResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? matches = null,Object? truncated = null,}) {
  return _then(FileSearchResultDto(
matches: null == matches ? _self.matches : matches // ignore: cast_nullable_to_non_nullable
as List<FileMatchDto>,truncated: null == truncated ? _self.truncated : truncated // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [FileSearchResultDto].
extension FileSearchResultDtoPatterns on FileSearchResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FileSearchResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FileSearchResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FileSearchResultDto value)  $default,){
final _that = this;
switch (_that) {
case _FileSearchResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FileSearchResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _FileSearchResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<FileMatchDto> matches,  bool truncated)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FileSearchResultDto() when $default != null:
return $default(_that.matches,_that.truncated);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<FileMatchDto> matches,  bool truncated)  $default,) {final _that = this;
switch (_that) {
case _FileSearchResultDto():
return $default(_that.matches,_that.truncated);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<FileMatchDto> matches,  bool truncated)?  $default,) {final _that = this;
switch (_that) {
case _FileSearchResultDto() when $default != null:
return $default(_that.matches,_that.truncated);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FileSearchResultDto implements FileSearchResultDto {
  const _FileSearchResultDto({required  List<FileMatchDto> matches, this.truncated = false}): _matches = matches;
  factory _FileSearchResultDto.fromJson(Map<String, dynamic> json) => _$FileSearchResultDtoFromJson(json);

 final  List<FileMatchDto> _matches;
@override List<FileMatchDto> get matches {
  if (_matches is EqualUnmodifiableListView) return _matches;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_matches);
}

@override@JsonKey() final  bool truncated;

/// Create a copy of FileSearchResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FileSearchResultDtoCopyWith<_FileSearchResultDto> get copyWith => __$FileSearchResultDtoCopyWithImpl<_FileSearchResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FileSearchResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FileSearchResultDto&&const DeepCollectionEquality().equals(other._matches, _matches)&&(identical(other.truncated, truncated) || other.truncated == truncated));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_matches),truncated);

@override
String toString() {
  return 'FileSearchResultDto(matches: $matches, truncated: $truncated)';
}


}

/// @nodoc
abstract mixin class _$FileSearchResultDtoCopyWith<$Res> implements $FileSearchResultDtoCopyWith<$Res> {
  factory _$FileSearchResultDtoCopyWith(_FileSearchResultDto value, $Res Function(_FileSearchResultDto) _then) = __$FileSearchResultDtoCopyWithImpl;
@override @useResult
$Res call({
 List<FileMatchDto> matches, bool truncated
});




}
/// @nodoc
class __$FileSearchResultDtoCopyWithImpl<$Res>
    implements _$FileSearchResultDtoCopyWith<$Res> {
  __$FileSearchResultDtoCopyWithImpl(this._self, this._then);

  final _FileSearchResultDto _self;
  final $Res Function(_FileSearchResultDto) _then;

/// Create a copy of FileSearchResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? matches = null,Object? truncated = null,}) {
  return _then(_FileSearchResultDto(
matches: null == matches ? _self._matches : matches // ignore: cast_nullable_to_non_nullable
as List<FileMatchDto>,truncated: null == truncated ? _self.truncated : truncated // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$GitBranchesListResultDto {

 List<GitBranchDto> get branches;
/// Create a copy of GitBranchesListResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GitBranchesListResultDtoCopyWith<GitBranchesListResultDto> get copyWith => _$GitBranchesListResultDtoCopyWithImpl<GitBranchesListResultDto>(this as GitBranchesListResultDto, _$identity);

  /// Serializes this GitBranchesListResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GitBranchesListResultDto&&const DeepCollectionEquality().equals(other.branches, branches));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(branches));

@override
String toString() {
  return 'GitBranchesListResultDto(branches: $branches)';
}


}

/// @nodoc
abstract mixin class $GitBranchesListResultDtoCopyWith<$Res>  {
  factory $GitBranchesListResultDtoCopyWith(GitBranchesListResultDto value, $Res Function(GitBranchesListResultDto) _then) = _$GitBranchesListResultDtoCopyWithImpl;
@useResult
$Res call({
 List<GitBranchDto> branches
});




}
/// @nodoc
class _$GitBranchesListResultDtoCopyWithImpl<$Res>
    implements $GitBranchesListResultDtoCopyWith<$Res> {
  _$GitBranchesListResultDtoCopyWithImpl(this._self, this._then);

  final GitBranchesListResultDto _self;
  final $Res Function(GitBranchesListResultDto) _then;

/// Create a copy of GitBranchesListResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? branches = null,}) {
  return _then(GitBranchesListResultDto(
branches: null == branches ? _self.branches : branches // ignore: cast_nullable_to_non_nullable
as List<GitBranchDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [GitBranchesListResultDto].
extension GitBranchesListResultDtoPatterns on GitBranchesListResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GitBranchesListResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GitBranchesListResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GitBranchesListResultDto value)  $default,){
final _that = this;
switch (_that) {
case _GitBranchesListResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GitBranchesListResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _GitBranchesListResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<GitBranchDto> branches)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GitBranchesListResultDto() when $default != null:
return $default(_that.branches);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<GitBranchDto> branches)  $default,) {final _that = this;
switch (_that) {
case _GitBranchesListResultDto():
return $default(_that.branches);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<GitBranchDto> branches)?  $default,) {final _that = this;
switch (_that) {
case _GitBranchesListResultDto() when $default != null:
return $default(_that.branches);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GitBranchesListResultDto implements GitBranchesListResultDto {
  const _GitBranchesListResultDto({required  List<GitBranchDto> branches}): _branches = branches;
  factory _GitBranchesListResultDto.fromJson(Map<String, dynamic> json) => _$GitBranchesListResultDtoFromJson(json);

 final  List<GitBranchDto> _branches;
@override List<GitBranchDto> get branches {
  if (_branches is EqualUnmodifiableListView) return _branches;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_branches);
}


/// Create a copy of GitBranchesListResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GitBranchesListResultDtoCopyWith<_GitBranchesListResultDto> get copyWith => __$GitBranchesListResultDtoCopyWithImpl<_GitBranchesListResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GitBranchesListResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GitBranchesListResultDto&&const DeepCollectionEquality().equals(other._branches, _branches));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_branches));

@override
String toString() {
  return 'GitBranchesListResultDto(branches: $branches)';
}


}

/// @nodoc
abstract mixin class _$GitBranchesListResultDtoCopyWith<$Res> implements $GitBranchesListResultDtoCopyWith<$Res> {
  factory _$GitBranchesListResultDtoCopyWith(_GitBranchesListResultDto value, $Res Function(_GitBranchesListResultDto) _then) = __$GitBranchesListResultDtoCopyWithImpl;
@override @useResult
$Res call({
 List<GitBranchDto> branches
});




}
/// @nodoc
class __$GitBranchesListResultDtoCopyWithImpl<$Res>
    implements _$GitBranchesListResultDtoCopyWith<$Res> {
  __$GitBranchesListResultDtoCopyWithImpl(this._self, this._then);

  final _GitBranchesListResultDto _self;
  final $Res Function(_GitBranchesListResultDto) _then;

/// Create a copy of GitBranchesListResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? branches = null,}) {
  return _then(_GitBranchesListResultDto(
branches: null == branches ? _self._branches : branches // ignore: cast_nullable_to_non_nullable
as List<GitBranchDto>,
  ));
}


}


/// @nodoc
mixin _$WorktreeResultDto {

 WorktreeDto get worktree; List<WorktreeHookRunDto> get hookRuns;
/// Create a copy of WorktreeResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorktreeResultDtoCopyWith<WorktreeResultDto> get copyWith => _$WorktreeResultDtoCopyWithImpl<WorktreeResultDto>(this as WorktreeResultDto, _$identity);

  /// Serializes this WorktreeResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorktreeResultDto&&(identical(other.worktree, worktree) || other.worktree == worktree)&&const DeepCollectionEquality().equals(other.hookRuns, hookRuns));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,worktree,const DeepCollectionEquality().hash(hookRuns));

@override
String toString() {
  return 'WorktreeResultDto(worktree: $worktree, hookRuns: $hookRuns)';
}


}

/// @nodoc
abstract mixin class $WorktreeResultDtoCopyWith<$Res>  {
  factory $WorktreeResultDtoCopyWith(WorktreeResultDto value, $Res Function(WorktreeResultDto) _then) = _$WorktreeResultDtoCopyWithImpl;
@useResult
$Res call({
 WorktreeDto worktree, List<WorktreeHookRunDto> hookRuns
});


$WorktreeDtoCopyWith<$Res> get worktree;

}
/// @nodoc
class _$WorktreeResultDtoCopyWithImpl<$Res>
    implements $WorktreeResultDtoCopyWith<$Res> {
  _$WorktreeResultDtoCopyWithImpl(this._self, this._then);

  final WorktreeResultDto _self;
  final $Res Function(WorktreeResultDto) _then;

/// Create a copy of WorktreeResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? worktree = null,Object? hookRuns = null,}) {
  return _then(WorktreeResultDto(
worktree: null == worktree ? _self.worktree : worktree // ignore: cast_nullable_to_non_nullable
as WorktreeDto,hookRuns: null == hookRuns ? _self.hookRuns : hookRuns // ignore: cast_nullable_to_non_nullable
as List<WorktreeHookRunDto>,
  ));
}
/// Create a copy of WorktreeResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorktreeDtoCopyWith<$Res> get worktree {

  return $WorktreeDtoCopyWith<$Res>(_self.worktree, (value) {
    return _then(_self.copyWith(worktree: value));
  });
}
}


/// Adds pattern-matching-related methods to [WorktreeResultDto].
extension WorktreeResultDtoPatterns on WorktreeResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorktreeResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorktreeResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorktreeResultDto value)  $default,){
final _that = this;
switch (_that) {
case _WorktreeResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorktreeResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _WorktreeResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( WorktreeDto worktree,  List<WorktreeHookRunDto> hookRuns)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorktreeResultDto() when $default != null:
return $default(_that.worktree,_that.hookRuns);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( WorktreeDto worktree,  List<WorktreeHookRunDto> hookRuns)  $default,) {final _that = this;
switch (_that) {
case _WorktreeResultDto():
return $default(_that.worktree,_that.hookRuns);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( WorktreeDto worktree,  List<WorktreeHookRunDto> hookRuns)?  $default,) {final _that = this;
switch (_that) {
case _WorktreeResultDto() when $default != null:
return $default(_that.worktree,_that.hookRuns);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorktreeResultDto implements WorktreeResultDto {
  const _WorktreeResultDto({required this.worktree,  List<WorktreeHookRunDto> hookRuns = const <WorktreeHookRunDto>[]}): _hookRuns = hookRuns;
  factory _WorktreeResultDto.fromJson(Map<String, dynamic> json) => _$WorktreeResultDtoFromJson(json);

@override final  WorktreeDto worktree;
 final  List<WorktreeHookRunDto> _hookRuns;
@override@JsonKey() List<WorktreeHookRunDto> get hookRuns {
  if (_hookRuns is EqualUnmodifiableListView) return _hookRuns;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_hookRuns);
}


/// Create a copy of WorktreeResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorktreeResultDtoCopyWith<_WorktreeResultDto> get copyWith => __$WorktreeResultDtoCopyWithImpl<_WorktreeResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorktreeResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorktreeResultDto&&(identical(other.worktree, worktree) || other.worktree == worktree)&&const DeepCollectionEquality().equals(other._hookRuns, _hookRuns));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,worktree,const DeepCollectionEquality().hash(_hookRuns));

@override
String toString() {
  return 'WorktreeResultDto(worktree: $worktree, hookRuns: $hookRuns)';
}


}

/// @nodoc
abstract mixin class _$WorktreeResultDtoCopyWith<$Res> implements $WorktreeResultDtoCopyWith<$Res> {
  factory _$WorktreeResultDtoCopyWith(_WorktreeResultDto value, $Res Function(_WorktreeResultDto) _then) = __$WorktreeResultDtoCopyWithImpl;
@override @useResult
$Res call({
 WorktreeDto worktree, List<WorktreeHookRunDto> hookRuns
});


@override $WorktreeDtoCopyWith<$Res> get worktree;

}
/// @nodoc
class __$WorktreeResultDtoCopyWithImpl<$Res>
    implements _$WorktreeResultDtoCopyWith<$Res> {
  __$WorktreeResultDtoCopyWithImpl(this._self, this._then);

  final _WorktreeResultDto _self;
  final $Res Function(_WorktreeResultDto) _then;

/// Create a copy of WorktreeResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? worktree = null,Object? hookRuns = null,}) {
  return _then(_WorktreeResultDto(
worktree: null == worktree ? _self.worktree : worktree // ignore: cast_nullable_to_non_nullable
as WorktreeDto,hookRuns: null == hookRuns ? _self._hookRuns : hookRuns // ignore: cast_nullable_to_non_nullable
as List<WorktreeHookRunDto>,
  ));
}

/// Create a copy of WorktreeResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorktreeDtoCopyWith<$Res> get worktree {

  return $WorktreeDtoCopyWith<$Res>(_self.worktree, (value) {
    return _then(_self.copyWith(worktree: value));
  });
}
}


/// @nodoc
mixin _$ProjectSettingsGetParamsDto {

 String get workspaceId;
/// Create a copy of ProjectSettingsGetParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectSettingsGetParamsDtoCopyWith<ProjectSettingsGetParamsDto> get copyWith => _$ProjectSettingsGetParamsDtoCopyWithImpl<ProjectSettingsGetParamsDto>(this as ProjectSettingsGetParamsDto, _$identity);

  /// Serializes this ProjectSettingsGetParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectSettingsGetParamsDto&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,workspaceId);

@override
String toString() {
  return 'ProjectSettingsGetParamsDto(workspaceId: $workspaceId)';
}


}

/// @nodoc
abstract mixin class $ProjectSettingsGetParamsDtoCopyWith<$Res>  {
  factory $ProjectSettingsGetParamsDtoCopyWith(ProjectSettingsGetParamsDto value, $Res Function(ProjectSettingsGetParamsDto) _then) = _$ProjectSettingsGetParamsDtoCopyWithImpl;
@useResult
$Res call({
 String workspaceId
});




}
/// @nodoc
class _$ProjectSettingsGetParamsDtoCopyWithImpl<$Res>
    implements $ProjectSettingsGetParamsDtoCopyWith<$Res> {
  _$ProjectSettingsGetParamsDtoCopyWithImpl(this._self, this._then);

  final ProjectSettingsGetParamsDto _self;
  final $Res Function(ProjectSettingsGetParamsDto) _then;

/// Create a copy of ProjectSettingsGetParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? workspaceId = null,}) {
  return _then(ProjectSettingsGetParamsDto(
workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ProjectSettingsGetParamsDto].
extension ProjectSettingsGetParamsDtoPatterns on ProjectSettingsGetParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProjectSettingsGetParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProjectSettingsGetParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProjectSettingsGetParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _ProjectSettingsGetParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProjectSettingsGetParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _ProjectSettingsGetParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String workspaceId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProjectSettingsGetParamsDto() when $default != null:
return $default(_that.workspaceId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String workspaceId)  $default,) {final _that = this;
switch (_that) {
case _ProjectSettingsGetParamsDto():
return $default(_that.workspaceId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String workspaceId)?  $default,) {final _that = this;
switch (_that) {
case _ProjectSettingsGetParamsDto() when $default != null:
return $default(_that.workspaceId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProjectSettingsGetParamsDto implements ProjectSettingsGetParamsDto {
  const _ProjectSettingsGetParamsDto({required this.workspaceId});
  factory _ProjectSettingsGetParamsDto.fromJson(Map<String, dynamic> json) => _$ProjectSettingsGetParamsDtoFromJson(json);

@override final  String workspaceId;

/// Create a copy of ProjectSettingsGetParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectSettingsGetParamsDtoCopyWith<_ProjectSettingsGetParamsDto> get copyWith => __$ProjectSettingsGetParamsDtoCopyWithImpl<_ProjectSettingsGetParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectSettingsGetParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectSettingsGetParamsDto&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,workspaceId);

@override
String toString() {
  return 'ProjectSettingsGetParamsDto(workspaceId: $workspaceId)';
}


}

/// @nodoc
abstract mixin class _$ProjectSettingsGetParamsDtoCopyWith<$Res> implements $ProjectSettingsGetParamsDtoCopyWith<$Res> {
  factory _$ProjectSettingsGetParamsDtoCopyWith(_ProjectSettingsGetParamsDto value, $Res Function(_ProjectSettingsGetParamsDto) _then) = __$ProjectSettingsGetParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String workspaceId
});




}
/// @nodoc
class __$ProjectSettingsGetParamsDtoCopyWithImpl<$Res>
    implements _$ProjectSettingsGetParamsDtoCopyWith<$Res> {
  __$ProjectSettingsGetParamsDtoCopyWithImpl(this._self, this._then);

  final _ProjectSettingsGetParamsDto _self;
  final $Res Function(_ProjectSettingsGetParamsDto) _then;

/// Create a copy of ProjectSettingsGetParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? workspaceId = null,}) {
  return _then(_ProjectSettingsGetParamsDto(
workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ProjectSettingsSaveParamsDto {

 String get workspaceId; ProjectSettingsDto get settings;
/// Create a copy of ProjectSettingsSaveParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectSettingsSaveParamsDtoCopyWith<ProjectSettingsSaveParamsDto> get copyWith => _$ProjectSettingsSaveParamsDtoCopyWithImpl<ProjectSettingsSaveParamsDto>(this as ProjectSettingsSaveParamsDto, _$identity);

  /// Serializes this ProjectSettingsSaveParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectSettingsSaveParamsDto&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.settings, settings) || other.settings == settings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,workspaceId,settings);

@override
String toString() {
  return 'ProjectSettingsSaveParamsDto(workspaceId: $workspaceId, settings: $settings)';
}


}

/// @nodoc
abstract mixin class $ProjectSettingsSaveParamsDtoCopyWith<$Res>  {
  factory $ProjectSettingsSaveParamsDtoCopyWith(ProjectSettingsSaveParamsDto value, $Res Function(ProjectSettingsSaveParamsDto) _then) = _$ProjectSettingsSaveParamsDtoCopyWithImpl;
@useResult
$Res call({
 String workspaceId, ProjectSettingsDto settings
});


$ProjectSettingsDtoCopyWith<$Res> get settings;

}
/// @nodoc
class _$ProjectSettingsSaveParamsDtoCopyWithImpl<$Res>
    implements $ProjectSettingsSaveParamsDtoCopyWith<$Res> {
  _$ProjectSettingsSaveParamsDtoCopyWithImpl(this._self, this._then);

  final ProjectSettingsSaveParamsDto _self;
  final $Res Function(ProjectSettingsSaveParamsDto) _then;

/// Create a copy of ProjectSettingsSaveParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? workspaceId = null,Object? settings = null,}) {
  return _then(ProjectSettingsSaveParamsDto(
workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as ProjectSettingsDto,
  ));
}
/// Create a copy of ProjectSettingsSaveParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectSettingsDtoCopyWith<$Res> get settings {

  return $ProjectSettingsDtoCopyWith<$Res>(_self.settings, (value) {
    return _then(_self.copyWith(settings: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProjectSettingsSaveParamsDto].
extension ProjectSettingsSaveParamsDtoPatterns on ProjectSettingsSaveParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProjectSettingsSaveParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProjectSettingsSaveParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProjectSettingsSaveParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _ProjectSettingsSaveParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProjectSettingsSaveParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _ProjectSettingsSaveParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String workspaceId,  ProjectSettingsDto settings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProjectSettingsSaveParamsDto() when $default != null:
return $default(_that.workspaceId,_that.settings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String workspaceId,  ProjectSettingsDto settings)  $default,) {final _that = this;
switch (_that) {
case _ProjectSettingsSaveParamsDto():
return $default(_that.workspaceId,_that.settings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String workspaceId,  ProjectSettingsDto settings)?  $default,) {final _that = this;
switch (_that) {
case _ProjectSettingsSaveParamsDto() when $default != null:
return $default(_that.workspaceId,_that.settings);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProjectSettingsSaveParamsDto implements ProjectSettingsSaveParamsDto {
  const _ProjectSettingsSaveParamsDto({required this.workspaceId, required this.settings});
  factory _ProjectSettingsSaveParamsDto.fromJson(Map<String, dynamic> json) => _$ProjectSettingsSaveParamsDtoFromJson(json);

@override final  String workspaceId;
@override final  ProjectSettingsDto settings;

/// Create a copy of ProjectSettingsSaveParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectSettingsSaveParamsDtoCopyWith<_ProjectSettingsSaveParamsDto> get copyWith => __$ProjectSettingsSaveParamsDtoCopyWithImpl<_ProjectSettingsSaveParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectSettingsSaveParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectSettingsSaveParamsDto&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.settings, settings) || other.settings == settings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,workspaceId,settings);

@override
String toString() {
  return 'ProjectSettingsSaveParamsDto(workspaceId: $workspaceId, settings: $settings)';
}


}

/// @nodoc
abstract mixin class _$ProjectSettingsSaveParamsDtoCopyWith<$Res> implements $ProjectSettingsSaveParamsDtoCopyWith<$Res> {
  factory _$ProjectSettingsSaveParamsDtoCopyWith(_ProjectSettingsSaveParamsDto value, $Res Function(_ProjectSettingsSaveParamsDto) _then) = __$ProjectSettingsSaveParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String workspaceId, ProjectSettingsDto settings
});


@override $ProjectSettingsDtoCopyWith<$Res> get settings;

}
/// @nodoc
class __$ProjectSettingsSaveParamsDtoCopyWithImpl<$Res>
    implements _$ProjectSettingsSaveParamsDtoCopyWith<$Res> {
  __$ProjectSettingsSaveParamsDtoCopyWithImpl(this._self, this._then);

  final _ProjectSettingsSaveParamsDto _self;
  final $Res Function(_ProjectSettingsSaveParamsDto) _then;

/// Create a copy of ProjectSettingsSaveParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? workspaceId = null,Object? settings = null,}) {
  return _then(_ProjectSettingsSaveParamsDto(
workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as ProjectSettingsDto,
  ));
}

/// Create a copy of ProjectSettingsSaveParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectSettingsDtoCopyWith<$Res> get settings {

  return $ProjectSettingsDtoCopyWith<$Res>(_self.settings, (value) {
    return _then(_self.copyWith(settings: value));
  });
}
}


/// @nodoc
mixin _$ProjectSettingsResultDto {

 ProjectSettingsDto get settings; String get sourcePath;
/// Create a copy of ProjectSettingsResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectSettingsResultDtoCopyWith<ProjectSettingsResultDto> get copyWith => _$ProjectSettingsResultDtoCopyWithImpl<ProjectSettingsResultDto>(this as ProjectSettingsResultDto, _$identity);

  /// Serializes this ProjectSettingsResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectSettingsResultDto&&(identical(other.settings, settings) || other.settings == settings)&&(identical(other.sourcePath, sourcePath) || other.sourcePath == sourcePath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,settings,sourcePath);

@override
String toString() {
  return 'ProjectSettingsResultDto(settings: $settings, sourcePath: $sourcePath)';
}


}

/// @nodoc
abstract mixin class $ProjectSettingsResultDtoCopyWith<$Res>  {
  factory $ProjectSettingsResultDtoCopyWith(ProjectSettingsResultDto value, $Res Function(ProjectSettingsResultDto) _then) = _$ProjectSettingsResultDtoCopyWithImpl;
@useResult
$Res call({
 ProjectSettingsDto settings, String sourcePath
});


$ProjectSettingsDtoCopyWith<$Res> get settings;

}
/// @nodoc
class _$ProjectSettingsResultDtoCopyWithImpl<$Res>
    implements $ProjectSettingsResultDtoCopyWith<$Res> {
  _$ProjectSettingsResultDtoCopyWithImpl(this._self, this._then);

  final ProjectSettingsResultDto _self;
  final $Res Function(ProjectSettingsResultDto) _then;

/// Create a copy of ProjectSettingsResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? settings = null,Object? sourcePath = null,}) {
  return _then(ProjectSettingsResultDto(
settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as ProjectSettingsDto,sourcePath: null == sourcePath ? _self.sourcePath : sourcePath // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of ProjectSettingsResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectSettingsDtoCopyWith<$Res> get settings {

  return $ProjectSettingsDtoCopyWith<$Res>(_self.settings, (value) {
    return _then(_self.copyWith(settings: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProjectSettingsResultDto].
extension ProjectSettingsResultDtoPatterns on ProjectSettingsResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProjectSettingsResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProjectSettingsResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProjectSettingsResultDto value)  $default,){
final _that = this;
switch (_that) {
case _ProjectSettingsResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProjectSettingsResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _ProjectSettingsResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ProjectSettingsDto settings,  String sourcePath)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProjectSettingsResultDto() when $default != null:
return $default(_that.settings,_that.sourcePath);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ProjectSettingsDto settings,  String sourcePath)  $default,) {final _that = this;
switch (_that) {
case _ProjectSettingsResultDto():
return $default(_that.settings,_that.sourcePath);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ProjectSettingsDto settings,  String sourcePath)?  $default,) {final _that = this;
switch (_that) {
case _ProjectSettingsResultDto() when $default != null:
return $default(_that.settings,_that.sourcePath);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProjectSettingsResultDto implements ProjectSettingsResultDto {
  const _ProjectSettingsResultDto({required this.settings, required this.sourcePath});
  factory _ProjectSettingsResultDto.fromJson(Map<String, dynamic> json) => _$ProjectSettingsResultDtoFromJson(json);

@override final  ProjectSettingsDto settings;
@override final  String sourcePath;

/// Create a copy of ProjectSettingsResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectSettingsResultDtoCopyWith<_ProjectSettingsResultDto> get copyWith => __$ProjectSettingsResultDtoCopyWithImpl<_ProjectSettingsResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectSettingsResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectSettingsResultDto&&(identical(other.settings, settings) || other.settings == settings)&&(identical(other.sourcePath, sourcePath) || other.sourcePath == sourcePath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,settings,sourcePath);

@override
String toString() {
  return 'ProjectSettingsResultDto(settings: $settings, sourcePath: $sourcePath)';
}


}

/// @nodoc
abstract mixin class _$ProjectSettingsResultDtoCopyWith<$Res> implements $ProjectSettingsResultDtoCopyWith<$Res> {
  factory _$ProjectSettingsResultDtoCopyWith(_ProjectSettingsResultDto value, $Res Function(_ProjectSettingsResultDto) _then) = __$ProjectSettingsResultDtoCopyWithImpl;
@override @useResult
$Res call({
 ProjectSettingsDto settings, String sourcePath
});


@override $ProjectSettingsDtoCopyWith<$Res> get settings;

}
/// @nodoc
class __$ProjectSettingsResultDtoCopyWithImpl<$Res>
    implements _$ProjectSettingsResultDtoCopyWith<$Res> {
  __$ProjectSettingsResultDtoCopyWithImpl(this._self, this._then);

  final _ProjectSettingsResultDto _self;
  final $Res Function(_ProjectSettingsResultDto) _then;

/// Create a copy of ProjectSettingsResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? settings = null,Object? sourcePath = null,}) {
  return _then(_ProjectSettingsResultDto(
settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as ProjectSettingsDto,sourcePath: null == sourcePath ? _self.sourcePath : sourcePath // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of ProjectSettingsResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectSettingsDtoCopyWith<$Res> get settings {

  return $ProjectSettingsDtoCopyWith<$Res>(_self.settings, (value) {
    return _then(_self.copyWith(settings: value));
  });
}
}


/// @nodoc
mixin _$WorktreeArchivePreviewResultDto {

 WorktreeArchivePreviewDto get preview;
/// Create a copy of WorktreeArchivePreviewResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorktreeArchivePreviewResultDtoCopyWith<WorktreeArchivePreviewResultDto> get copyWith => _$WorktreeArchivePreviewResultDtoCopyWithImpl<WorktreeArchivePreviewResultDto>(this as WorktreeArchivePreviewResultDto, _$identity);

  /// Serializes this WorktreeArchivePreviewResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorktreeArchivePreviewResultDto&&(identical(other.preview, preview) || other.preview == preview));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,preview);

@override
String toString() {
  return 'WorktreeArchivePreviewResultDto(preview: $preview)';
}


}

/// @nodoc
abstract mixin class $WorktreeArchivePreviewResultDtoCopyWith<$Res>  {
  factory $WorktreeArchivePreviewResultDtoCopyWith(WorktreeArchivePreviewResultDto value, $Res Function(WorktreeArchivePreviewResultDto) _then) = _$WorktreeArchivePreviewResultDtoCopyWithImpl;
@useResult
$Res call({
 WorktreeArchivePreviewDto preview
});


$WorktreeArchivePreviewDtoCopyWith<$Res> get preview;

}
/// @nodoc
class _$WorktreeArchivePreviewResultDtoCopyWithImpl<$Res>
    implements $WorktreeArchivePreviewResultDtoCopyWith<$Res> {
  _$WorktreeArchivePreviewResultDtoCopyWithImpl(this._self, this._then);

  final WorktreeArchivePreviewResultDto _self;
  final $Res Function(WorktreeArchivePreviewResultDto) _then;

/// Create a copy of WorktreeArchivePreviewResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? preview = null,}) {
  return _then(WorktreeArchivePreviewResultDto(
preview: null == preview ? _self.preview : preview // ignore: cast_nullable_to_non_nullable
as WorktreeArchivePreviewDto,
  ));
}
/// Create a copy of WorktreeArchivePreviewResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorktreeArchivePreviewDtoCopyWith<$Res> get preview {

  return $WorktreeArchivePreviewDtoCopyWith<$Res>(_self.preview, (value) {
    return _then(_self.copyWith(preview: value));
  });
}
}


/// Adds pattern-matching-related methods to [WorktreeArchivePreviewResultDto].
extension WorktreeArchivePreviewResultDtoPatterns on WorktreeArchivePreviewResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorktreeArchivePreviewResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorktreeArchivePreviewResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorktreeArchivePreviewResultDto value)  $default,){
final _that = this;
switch (_that) {
case _WorktreeArchivePreviewResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorktreeArchivePreviewResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _WorktreeArchivePreviewResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( WorktreeArchivePreviewDto preview)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorktreeArchivePreviewResultDto() when $default != null:
return $default(_that.preview);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( WorktreeArchivePreviewDto preview)  $default,) {final _that = this;
switch (_that) {
case _WorktreeArchivePreviewResultDto():
return $default(_that.preview);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( WorktreeArchivePreviewDto preview)?  $default,) {final _that = this;
switch (_that) {
case _WorktreeArchivePreviewResultDto() when $default != null:
return $default(_that.preview);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorktreeArchivePreviewResultDto implements WorktreeArchivePreviewResultDto {
  const _WorktreeArchivePreviewResultDto({required this.preview});
  factory _WorktreeArchivePreviewResultDto.fromJson(Map<String, dynamic> json) => _$WorktreeArchivePreviewResultDtoFromJson(json);

@override final  WorktreeArchivePreviewDto preview;

/// Create a copy of WorktreeArchivePreviewResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorktreeArchivePreviewResultDtoCopyWith<_WorktreeArchivePreviewResultDto> get copyWith => __$WorktreeArchivePreviewResultDtoCopyWithImpl<_WorktreeArchivePreviewResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorktreeArchivePreviewResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorktreeArchivePreviewResultDto&&(identical(other.preview, preview) || other.preview == preview));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,preview);

@override
String toString() {
  return 'WorktreeArchivePreviewResultDto(preview: $preview)';
}


}

/// @nodoc
abstract mixin class _$WorktreeArchivePreviewResultDtoCopyWith<$Res> implements $WorktreeArchivePreviewResultDtoCopyWith<$Res> {
  factory _$WorktreeArchivePreviewResultDtoCopyWith(_WorktreeArchivePreviewResultDto value, $Res Function(_WorktreeArchivePreviewResultDto) _then) = __$WorktreeArchivePreviewResultDtoCopyWithImpl;
@override @useResult
$Res call({
 WorktreeArchivePreviewDto preview
});


@override $WorktreeArchivePreviewDtoCopyWith<$Res> get preview;

}
/// @nodoc
class __$WorktreeArchivePreviewResultDtoCopyWithImpl<$Res>
    implements _$WorktreeArchivePreviewResultDtoCopyWith<$Res> {
  __$WorktreeArchivePreviewResultDtoCopyWithImpl(this._self, this._then);

  final _WorktreeArchivePreviewResultDto _self;
  final $Res Function(_WorktreeArchivePreviewResultDto) _then;

/// Create a copy of WorktreeArchivePreviewResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? preview = null,}) {
  return _then(_WorktreeArchivePreviewResultDto(
preview: null == preview ? _self.preview : preview // ignore: cast_nullable_to_non_nullable
as WorktreeArchivePreviewDto,
  ));
}

/// Create a copy of WorktreeArchivePreviewResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorktreeArchivePreviewDtoCopyWith<$Res> get preview {

  return $WorktreeArchivePreviewDtoCopyWith<$Res>(_self.preview, (value) {
    return _then(_self.copyWith(preview: value));
  });
}
}


/// @nodoc
mixin _$SessionListResultDto {

 List<SessionDto> get sessions;
/// Create a copy of SessionListResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionListResultDtoCopyWith<SessionListResultDto> get copyWith => _$SessionListResultDtoCopyWithImpl<SessionListResultDto>(this as SessionListResultDto, _$identity);

  /// Serializes this SessionListResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionListResultDto&&const DeepCollectionEquality().equals(other.sessions, sessions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(sessions));

@override
String toString() {
  return 'SessionListResultDto(sessions: $sessions)';
}


}

/// @nodoc
abstract mixin class $SessionListResultDtoCopyWith<$Res>  {
  factory $SessionListResultDtoCopyWith(SessionListResultDto value, $Res Function(SessionListResultDto) _then) = _$SessionListResultDtoCopyWithImpl;
@useResult
$Res call({
 List<SessionDto> sessions
});




}
/// @nodoc
class _$SessionListResultDtoCopyWithImpl<$Res>
    implements $SessionListResultDtoCopyWith<$Res> {
  _$SessionListResultDtoCopyWithImpl(this._self, this._then);

  final SessionListResultDto _self;
  final $Res Function(SessionListResultDto) _then;

/// Create a copy of SessionListResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessions = null,}) {
  return _then(SessionListResultDto(
sessions: null == sessions ? _self.sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<SessionDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionListResultDto].
extension SessionListResultDtoPatterns on SessionListResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionListResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionListResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionListResultDto value)  $default,){
final _that = this;
switch (_that) {
case _SessionListResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionListResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _SessionListResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<SessionDto> sessions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionListResultDto() when $default != null:
return $default(_that.sessions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<SessionDto> sessions)  $default,) {final _that = this;
switch (_that) {
case _SessionListResultDto():
return $default(_that.sessions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<SessionDto> sessions)?  $default,) {final _that = this;
switch (_that) {
case _SessionListResultDto() when $default != null:
return $default(_that.sessions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SessionListResultDto implements SessionListResultDto {
  const _SessionListResultDto({required  List<SessionDto> sessions}): _sessions = sessions;
  factory _SessionListResultDto.fromJson(Map<String, dynamic> json) => _$SessionListResultDtoFromJson(json);

 final  List<SessionDto> _sessions;
@override List<SessionDto> get sessions {
  if (_sessions is EqualUnmodifiableListView) return _sessions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sessions);
}


/// Create a copy of SessionListResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionListResultDtoCopyWith<_SessionListResultDto> get copyWith => __$SessionListResultDtoCopyWithImpl<_SessionListResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionListResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionListResultDto&&const DeepCollectionEquality().equals(other._sessions, _sessions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_sessions));

@override
String toString() {
  return 'SessionListResultDto(sessions: $sessions)';
}


}

/// @nodoc
abstract mixin class _$SessionListResultDtoCopyWith<$Res> implements $SessionListResultDtoCopyWith<$Res> {
  factory _$SessionListResultDtoCopyWith(_SessionListResultDto value, $Res Function(_SessionListResultDto) _then) = __$SessionListResultDtoCopyWithImpl;
@override @useResult
$Res call({
 List<SessionDto> sessions
});




}
/// @nodoc
class __$SessionListResultDtoCopyWithImpl<$Res>
    implements _$SessionListResultDtoCopyWith<$Res> {
  __$SessionListResultDtoCopyWithImpl(this._self, this._then);

  final _SessionListResultDto _self;
  final $Res Function(_SessionListResultDto) _then;

/// Create a copy of SessionListResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessions = null,}) {
  return _then(_SessionListResultDto(
sessions: null == sessions ? _self._sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<SessionDto>,
  ));
}


}


/// @nodoc
mixin _$SessionResultDto {

 SessionDto get session;
/// Create a copy of SessionResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionResultDtoCopyWith<SessionResultDto> get copyWith => _$SessionResultDtoCopyWithImpl<SessionResultDto>(this as SessionResultDto, _$identity);

  /// Serializes this SessionResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionResultDto&&(identical(other.session, session) || other.session == session));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,session);

@override
String toString() {
  return 'SessionResultDto(session: $session)';
}


}

/// @nodoc
abstract mixin class $SessionResultDtoCopyWith<$Res>  {
  factory $SessionResultDtoCopyWith(SessionResultDto value, $Res Function(SessionResultDto) _then) = _$SessionResultDtoCopyWithImpl;
@useResult
$Res call({
 SessionDto session
});


$SessionDtoCopyWith<$Res> get session;

}
/// @nodoc
class _$SessionResultDtoCopyWithImpl<$Res>
    implements $SessionResultDtoCopyWith<$Res> {
  _$SessionResultDtoCopyWithImpl(this._self, this._then);

  final SessionResultDto _self;
  final $Res Function(SessionResultDto) _then;

/// Create a copy of SessionResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? session = null,}) {
  return _then(SessionResultDto(
session: null == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as SessionDto,
  ));
}
/// Create a copy of SessionResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionDtoCopyWith<$Res> get session {

  return $SessionDtoCopyWith<$Res>(_self.session, (value) {
    return _then(_self.copyWith(session: value));
  });
}
}


/// Adds pattern-matching-related methods to [SessionResultDto].
extension SessionResultDtoPatterns on SessionResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionResultDto value)  $default,){
final _that = this;
switch (_that) {
case _SessionResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _SessionResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SessionDto session)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionResultDto() when $default != null:
return $default(_that.session);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SessionDto session)  $default,) {final _that = this;
switch (_that) {
case _SessionResultDto():
return $default(_that.session);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SessionDto session)?  $default,) {final _that = this;
switch (_that) {
case _SessionResultDto() when $default != null:
return $default(_that.session);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SessionResultDto implements SessionResultDto {
  const _SessionResultDto({required this.session});
  factory _SessionResultDto.fromJson(Map<String, dynamic> json) => _$SessionResultDtoFromJson(json);

@override final  SessionDto session;

/// Create a copy of SessionResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionResultDtoCopyWith<_SessionResultDto> get copyWith => __$SessionResultDtoCopyWithImpl<_SessionResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionResultDto&&(identical(other.session, session) || other.session == session));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,session);

@override
String toString() {
  return 'SessionResultDto(session: $session)';
}


}

/// @nodoc
abstract mixin class _$SessionResultDtoCopyWith<$Res> implements $SessionResultDtoCopyWith<$Res> {
  factory _$SessionResultDtoCopyWith(_SessionResultDto value, $Res Function(_SessionResultDto) _then) = __$SessionResultDtoCopyWithImpl;
@override @useResult
$Res call({
 SessionDto session
});


@override $SessionDtoCopyWith<$Res> get session;

}
/// @nodoc
class __$SessionResultDtoCopyWithImpl<$Res>
    implements _$SessionResultDtoCopyWith<$Res> {
  __$SessionResultDtoCopyWithImpl(this._self, this._then);

  final _SessionResultDto _self;
  final $Res Function(_SessionResultDto) _then;

/// Create a copy of SessionResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? session = null,}) {
  return _then(_SessionResultDto(
session: null == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as SessionDto,
  ));
}

/// Create a copy of SessionResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionDtoCopyWith<$Res> get session {

  return $SessionDtoCopyWith<$Res>(_self.session, (value) {
    return _then(_self.copyWith(session: value));
  });
}
}


/// @nodoc
mixin _$TerminalListParamsDto {

 String get worktreeId;
/// Create a copy of TerminalListParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TerminalListParamsDtoCopyWith<TerminalListParamsDto> get copyWith => _$TerminalListParamsDtoCopyWithImpl<TerminalListParamsDto>(this as TerminalListParamsDto, _$identity);

  /// Serializes this TerminalListParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TerminalListParamsDto&&(identical(other.worktreeId, worktreeId) || other.worktreeId == worktreeId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,worktreeId);

@override
String toString() {
  return 'TerminalListParamsDto(worktreeId: $worktreeId)';
}


}

/// @nodoc
abstract mixin class $TerminalListParamsDtoCopyWith<$Res>  {
  factory $TerminalListParamsDtoCopyWith(TerminalListParamsDto value, $Res Function(TerminalListParamsDto) _then) = _$TerminalListParamsDtoCopyWithImpl;
@useResult
$Res call({
 String worktreeId
});




}
/// @nodoc
class _$TerminalListParamsDtoCopyWithImpl<$Res>
    implements $TerminalListParamsDtoCopyWith<$Res> {
  _$TerminalListParamsDtoCopyWithImpl(this._self, this._then);

  final TerminalListParamsDto _self;
  final $Res Function(TerminalListParamsDto) _then;

/// Create a copy of TerminalListParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? worktreeId = null,}) {
  return _then(TerminalListParamsDto(
worktreeId: null == worktreeId ? _self.worktreeId : worktreeId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TerminalListParamsDto].
extension TerminalListParamsDtoPatterns on TerminalListParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TerminalListParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TerminalListParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TerminalListParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _TerminalListParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TerminalListParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _TerminalListParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String worktreeId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TerminalListParamsDto() when $default != null:
return $default(_that.worktreeId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String worktreeId)  $default,) {final _that = this;
switch (_that) {
case _TerminalListParamsDto():
return $default(_that.worktreeId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String worktreeId)?  $default,) {final _that = this;
switch (_that) {
case _TerminalListParamsDto() when $default != null:
return $default(_that.worktreeId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TerminalListParamsDto implements TerminalListParamsDto {
  const _TerminalListParamsDto({required this.worktreeId});
  factory _TerminalListParamsDto.fromJson(Map<String, dynamic> json) => _$TerminalListParamsDtoFromJson(json);

@override final  String worktreeId;

/// Create a copy of TerminalListParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TerminalListParamsDtoCopyWith<_TerminalListParamsDto> get copyWith => __$TerminalListParamsDtoCopyWithImpl<_TerminalListParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TerminalListParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TerminalListParamsDto&&(identical(other.worktreeId, worktreeId) || other.worktreeId == worktreeId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,worktreeId);

@override
String toString() {
  return 'TerminalListParamsDto(worktreeId: $worktreeId)';
}


}

/// @nodoc
abstract mixin class _$TerminalListParamsDtoCopyWith<$Res> implements $TerminalListParamsDtoCopyWith<$Res> {
  factory _$TerminalListParamsDtoCopyWith(_TerminalListParamsDto value, $Res Function(_TerminalListParamsDto) _then) = __$TerminalListParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String worktreeId
});




}
/// @nodoc
class __$TerminalListParamsDtoCopyWithImpl<$Res>
    implements _$TerminalListParamsDtoCopyWith<$Res> {
  __$TerminalListParamsDtoCopyWithImpl(this._self, this._then);

  final _TerminalListParamsDto _self;
  final $Res Function(_TerminalListParamsDto) _then;

/// Create a copy of TerminalListParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? worktreeId = null,}) {
  return _then(_TerminalListParamsDto(
worktreeId: null == worktreeId ? _self.worktreeId : worktreeId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$TerminalListResultDto {

 List<TerminalDto> get terminals;
/// Create a copy of TerminalListResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TerminalListResultDtoCopyWith<TerminalListResultDto> get copyWith => _$TerminalListResultDtoCopyWithImpl<TerminalListResultDto>(this as TerminalListResultDto, _$identity);

  /// Serializes this TerminalListResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TerminalListResultDto&&const DeepCollectionEquality().equals(other.terminals, terminals));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(terminals));

@override
String toString() {
  return 'TerminalListResultDto(terminals: $terminals)';
}


}

/// @nodoc
abstract mixin class $TerminalListResultDtoCopyWith<$Res>  {
  factory $TerminalListResultDtoCopyWith(TerminalListResultDto value, $Res Function(TerminalListResultDto) _then) = _$TerminalListResultDtoCopyWithImpl;
@useResult
$Res call({
 List<TerminalDto> terminals
});




}
/// @nodoc
class _$TerminalListResultDtoCopyWithImpl<$Res>
    implements $TerminalListResultDtoCopyWith<$Res> {
  _$TerminalListResultDtoCopyWithImpl(this._self, this._then);

  final TerminalListResultDto _self;
  final $Res Function(TerminalListResultDto) _then;

/// Create a copy of TerminalListResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? terminals = null,}) {
  return _then(TerminalListResultDto(
terminals: null == terminals ? _self.terminals : terminals // ignore: cast_nullable_to_non_nullable
as List<TerminalDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [TerminalListResultDto].
extension TerminalListResultDtoPatterns on TerminalListResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TerminalListResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TerminalListResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TerminalListResultDto value)  $default,){
final _that = this;
switch (_that) {
case _TerminalListResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TerminalListResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _TerminalListResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<TerminalDto> terminals)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TerminalListResultDto() when $default != null:
return $default(_that.terminals);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<TerminalDto> terminals)  $default,) {final _that = this;
switch (_that) {
case _TerminalListResultDto():
return $default(_that.terminals);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<TerminalDto> terminals)?  $default,) {final _that = this;
switch (_that) {
case _TerminalListResultDto() when $default != null:
return $default(_that.terminals);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TerminalListResultDto implements TerminalListResultDto {
  const _TerminalListResultDto({required  List<TerminalDto> terminals}): _terminals = terminals;
  factory _TerminalListResultDto.fromJson(Map<String, dynamic> json) => _$TerminalListResultDtoFromJson(json);

 final  List<TerminalDto> _terminals;
@override List<TerminalDto> get terminals {
  if (_terminals is EqualUnmodifiableListView) return _terminals;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_terminals);
}


/// Create a copy of TerminalListResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TerminalListResultDtoCopyWith<_TerminalListResultDto> get copyWith => __$TerminalListResultDtoCopyWithImpl<_TerminalListResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TerminalListResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TerminalListResultDto&&const DeepCollectionEquality().equals(other._terminals, _terminals));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_terminals));

@override
String toString() {
  return 'TerminalListResultDto(terminals: $terminals)';
}


}

/// @nodoc
abstract mixin class _$TerminalListResultDtoCopyWith<$Res> implements $TerminalListResultDtoCopyWith<$Res> {
  factory _$TerminalListResultDtoCopyWith(_TerminalListResultDto value, $Res Function(_TerminalListResultDto) _then) = __$TerminalListResultDtoCopyWithImpl;
@override @useResult
$Res call({
 List<TerminalDto> terminals
});




}
/// @nodoc
class __$TerminalListResultDtoCopyWithImpl<$Res>
    implements _$TerminalListResultDtoCopyWith<$Res> {
  __$TerminalListResultDtoCopyWithImpl(this._self, this._then);

  final _TerminalListResultDto _self;
  final $Res Function(_TerminalListResultDto) _then;

/// Create a copy of TerminalListResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? terminals = null,}) {
  return _then(_TerminalListResultDto(
terminals: null == terminals ? _self._terminals : terminals // ignore: cast_nullable_to_non_nullable
as List<TerminalDto>,
  ));
}


}


/// @nodoc
mixin _$TerminalCreateParamsDto {

 String get id; String get worktreeId; String get title; int get columns; int get rows;
/// Create a copy of TerminalCreateParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TerminalCreateParamsDtoCopyWith<TerminalCreateParamsDto> get copyWith => _$TerminalCreateParamsDtoCopyWithImpl<TerminalCreateParamsDto>(this as TerminalCreateParamsDto, _$identity);

  /// Serializes this TerminalCreateParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TerminalCreateParamsDto&&(identical(other.id, id) || other.id == id)&&(identical(other.worktreeId, worktreeId) || other.worktreeId == worktreeId)&&(identical(other.title, title) || other.title == title)&&(identical(other.columns, columns) || other.columns == columns)&&(identical(other.rows, rows) || other.rows == rows));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,worktreeId,title,columns,rows);

@override
String toString() {
  return 'TerminalCreateParamsDto(id: $id, worktreeId: $worktreeId, title: $title, columns: $columns, rows: $rows)';
}


}

/// @nodoc
abstract mixin class $TerminalCreateParamsDtoCopyWith<$Res>  {
  factory $TerminalCreateParamsDtoCopyWith(TerminalCreateParamsDto value, $Res Function(TerminalCreateParamsDto) _then) = _$TerminalCreateParamsDtoCopyWithImpl;
@useResult
$Res call({
 String id, String worktreeId, String title, int columns, int rows
});




}
/// @nodoc
class _$TerminalCreateParamsDtoCopyWithImpl<$Res>
    implements $TerminalCreateParamsDtoCopyWith<$Res> {
  _$TerminalCreateParamsDtoCopyWithImpl(this._self, this._then);

  final TerminalCreateParamsDto _self;
  final $Res Function(TerminalCreateParamsDto) _then;

/// Create a copy of TerminalCreateParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? worktreeId = null,Object? title = null,Object? columns = null,Object? rows = null,}) {
  return _then(TerminalCreateParamsDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,worktreeId: null == worktreeId ? _self.worktreeId : worktreeId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,columns: null == columns ? _self.columns : columns // ignore: cast_nullable_to_non_nullable
as int,rows: null == rows ? _self.rows : rows // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TerminalCreateParamsDto].
extension TerminalCreateParamsDtoPatterns on TerminalCreateParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TerminalCreateParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TerminalCreateParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TerminalCreateParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _TerminalCreateParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TerminalCreateParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _TerminalCreateParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String worktreeId,  String title,  int columns,  int rows)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TerminalCreateParamsDto() when $default != null:
return $default(_that.id,_that.worktreeId,_that.title,_that.columns,_that.rows);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String worktreeId,  String title,  int columns,  int rows)  $default,) {final _that = this;
switch (_that) {
case _TerminalCreateParamsDto():
return $default(_that.id,_that.worktreeId,_that.title,_that.columns,_that.rows);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String worktreeId,  String title,  int columns,  int rows)?  $default,) {final _that = this;
switch (_that) {
case _TerminalCreateParamsDto() when $default != null:
return $default(_that.id,_that.worktreeId,_that.title,_that.columns,_that.rows);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TerminalCreateParamsDto implements TerminalCreateParamsDto {
  const _TerminalCreateParamsDto({required this.id, required this.worktreeId, required this.title, required this.columns, required this.rows});
  factory _TerminalCreateParamsDto.fromJson(Map<String, dynamic> json) => _$TerminalCreateParamsDtoFromJson(json);

@override final  String id;
@override final  String worktreeId;
@override final  String title;
@override final  int columns;
@override final  int rows;

/// Create a copy of TerminalCreateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TerminalCreateParamsDtoCopyWith<_TerminalCreateParamsDto> get copyWith => __$TerminalCreateParamsDtoCopyWithImpl<_TerminalCreateParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TerminalCreateParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TerminalCreateParamsDto&&(identical(other.id, id) || other.id == id)&&(identical(other.worktreeId, worktreeId) || other.worktreeId == worktreeId)&&(identical(other.title, title) || other.title == title)&&(identical(other.columns, columns) || other.columns == columns)&&(identical(other.rows, rows) || other.rows == rows));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,worktreeId,title,columns,rows);

@override
String toString() {
  return 'TerminalCreateParamsDto(id: $id, worktreeId: $worktreeId, title: $title, columns: $columns, rows: $rows)';
}


}

/// @nodoc
abstract mixin class _$TerminalCreateParamsDtoCopyWith<$Res> implements $TerminalCreateParamsDtoCopyWith<$Res> {
  factory _$TerminalCreateParamsDtoCopyWith(_TerminalCreateParamsDto value, $Res Function(_TerminalCreateParamsDto) _then) = __$TerminalCreateParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String worktreeId, String title, int columns, int rows
});




}
/// @nodoc
class __$TerminalCreateParamsDtoCopyWithImpl<$Res>
    implements _$TerminalCreateParamsDtoCopyWith<$Res> {
  __$TerminalCreateParamsDtoCopyWithImpl(this._self, this._then);

  final _TerminalCreateParamsDto _self;
  final $Res Function(_TerminalCreateParamsDto) _then;

/// Create a copy of TerminalCreateParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? worktreeId = null,Object? title = null,Object? columns = null,Object? rows = null,}) {
  return _then(_TerminalCreateParamsDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,worktreeId: null == worktreeId ? _self.worktreeId : worktreeId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,columns: null == columns ? _self.columns : columns // ignore: cast_nullable_to_non_nullable
as int,rows: null == rows ? _self.rows : rows // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$TerminalIdParamsDto {

 String get terminalId;
/// Create a copy of TerminalIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TerminalIdParamsDtoCopyWith<TerminalIdParamsDto> get copyWith => _$TerminalIdParamsDtoCopyWithImpl<TerminalIdParamsDto>(this as TerminalIdParamsDto, _$identity);

  /// Serializes this TerminalIdParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TerminalIdParamsDto&&(identical(other.terminalId, terminalId) || other.terminalId == terminalId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,terminalId);

@override
String toString() {
  return 'TerminalIdParamsDto(terminalId: $terminalId)';
}


}

/// @nodoc
abstract mixin class $TerminalIdParamsDtoCopyWith<$Res>  {
  factory $TerminalIdParamsDtoCopyWith(TerminalIdParamsDto value, $Res Function(TerminalIdParamsDto) _then) = _$TerminalIdParamsDtoCopyWithImpl;
@useResult
$Res call({
 String terminalId
});




}
/// @nodoc
class _$TerminalIdParamsDtoCopyWithImpl<$Res>
    implements $TerminalIdParamsDtoCopyWith<$Res> {
  _$TerminalIdParamsDtoCopyWithImpl(this._self, this._then);

  final TerminalIdParamsDto _self;
  final $Res Function(TerminalIdParamsDto) _then;

/// Create a copy of TerminalIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? terminalId = null,}) {
  return _then(TerminalIdParamsDto(
terminalId: null == terminalId ? _self.terminalId : terminalId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TerminalIdParamsDto].
extension TerminalIdParamsDtoPatterns on TerminalIdParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TerminalIdParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TerminalIdParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TerminalIdParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _TerminalIdParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TerminalIdParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _TerminalIdParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String terminalId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TerminalIdParamsDto() when $default != null:
return $default(_that.terminalId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String terminalId)  $default,) {final _that = this;
switch (_that) {
case _TerminalIdParamsDto():
return $default(_that.terminalId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String terminalId)?  $default,) {final _that = this;
switch (_that) {
case _TerminalIdParamsDto() when $default != null:
return $default(_that.terminalId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TerminalIdParamsDto implements TerminalIdParamsDto {
  const _TerminalIdParamsDto({required this.terminalId});
  factory _TerminalIdParamsDto.fromJson(Map<String, dynamic> json) => _$TerminalIdParamsDtoFromJson(json);

@override final  String terminalId;

/// Create a copy of TerminalIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TerminalIdParamsDtoCopyWith<_TerminalIdParamsDto> get copyWith => __$TerminalIdParamsDtoCopyWithImpl<_TerminalIdParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TerminalIdParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TerminalIdParamsDto&&(identical(other.terminalId, terminalId) || other.terminalId == terminalId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,terminalId);

@override
String toString() {
  return 'TerminalIdParamsDto(terminalId: $terminalId)';
}


}

/// @nodoc
abstract mixin class _$TerminalIdParamsDtoCopyWith<$Res> implements $TerminalIdParamsDtoCopyWith<$Res> {
  factory _$TerminalIdParamsDtoCopyWith(_TerminalIdParamsDto value, $Res Function(_TerminalIdParamsDto) _then) = __$TerminalIdParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String terminalId
});




}
/// @nodoc
class __$TerminalIdParamsDtoCopyWithImpl<$Res>
    implements _$TerminalIdParamsDtoCopyWith<$Res> {
  __$TerminalIdParamsDtoCopyWithImpl(this._self, this._then);

  final _TerminalIdParamsDto _self;
  final $Res Function(_TerminalIdParamsDto) _then;

/// Create a copy of TerminalIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? terminalId = null,}) {
  return _then(_TerminalIdParamsDto(
terminalId: null == terminalId ? _self.terminalId : terminalId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$TerminalViewportDto {

 int get columns; int get rows;
/// Create a copy of TerminalViewportDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TerminalViewportDtoCopyWith<TerminalViewportDto> get copyWith => _$TerminalViewportDtoCopyWithImpl<TerminalViewportDto>(this as TerminalViewportDto, _$identity);

  /// Serializes this TerminalViewportDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TerminalViewportDto&&(identical(other.columns, columns) || other.columns == columns)&&(identical(other.rows, rows) || other.rows == rows));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,columns,rows);

@override
String toString() {
  return 'TerminalViewportDto(columns: $columns, rows: $rows)';
}


}

/// @nodoc
abstract mixin class $TerminalViewportDtoCopyWith<$Res>  {
  factory $TerminalViewportDtoCopyWith(TerminalViewportDto value, $Res Function(TerminalViewportDto) _then) = _$TerminalViewportDtoCopyWithImpl;
@useResult
$Res call({
 int columns, int rows
});




}
/// @nodoc
class _$TerminalViewportDtoCopyWithImpl<$Res>
    implements $TerminalViewportDtoCopyWith<$Res> {
  _$TerminalViewportDtoCopyWithImpl(this._self, this._then);

  final TerminalViewportDto _self;
  final $Res Function(TerminalViewportDto) _then;

/// Create a copy of TerminalViewportDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? columns = null,Object? rows = null,}) {
  return _then(TerminalViewportDto(
columns: null == columns ? _self.columns : columns // ignore: cast_nullable_to_non_nullable
as int,rows: null == rows ? _self.rows : rows // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TerminalViewportDto].
extension TerminalViewportDtoPatterns on TerminalViewportDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TerminalViewportDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TerminalViewportDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TerminalViewportDto value)  $default,){
final _that = this;
switch (_that) {
case _TerminalViewportDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TerminalViewportDto value)?  $default,){
final _that = this;
switch (_that) {
case _TerminalViewportDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int columns,  int rows)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TerminalViewportDto() when $default != null:
return $default(_that.columns,_that.rows);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int columns,  int rows)  $default,) {final _that = this;
switch (_that) {
case _TerminalViewportDto():
return $default(_that.columns,_that.rows);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int columns,  int rows)?  $default,) {final _that = this;
switch (_that) {
case _TerminalViewportDto() when $default != null:
return $default(_that.columns,_that.rows);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TerminalViewportDto implements TerminalViewportDto {
  const _TerminalViewportDto({required this.columns, required this.rows});
  factory _TerminalViewportDto.fromJson(Map<String, dynamic> json) => _$TerminalViewportDtoFromJson(json);

@override final  int columns;
@override final  int rows;

/// Create a copy of TerminalViewportDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TerminalViewportDtoCopyWith<_TerminalViewportDto> get copyWith => __$TerminalViewportDtoCopyWithImpl<_TerminalViewportDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TerminalViewportDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TerminalViewportDto&&(identical(other.columns, columns) || other.columns == columns)&&(identical(other.rows, rows) || other.rows == rows));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,columns,rows);

@override
String toString() {
  return 'TerminalViewportDto(columns: $columns, rows: $rows)';
}


}

/// @nodoc
abstract mixin class _$TerminalViewportDtoCopyWith<$Res> implements $TerminalViewportDtoCopyWith<$Res> {
  factory _$TerminalViewportDtoCopyWith(_TerminalViewportDto value, $Res Function(_TerminalViewportDto) _then) = __$TerminalViewportDtoCopyWithImpl;
@override @useResult
$Res call({
 int columns, int rows
});




}
/// @nodoc
class __$TerminalViewportDtoCopyWithImpl<$Res>
    implements _$TerminalViewportDtoCopyWith<$Res> {
  __$TerminalViewportDtoCopyWithImpl(this._self, this._then);

  final _TerminalViewportDto _self;
  final $Res Function(_TerminalViewportDto) _then;

/// Create a copy of TerminalViewportDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? columns = null,Object? rows = null,}) {
  return _then(_TerminalViewportDto(
columns: null == columns ? _self.columns : columns // ignore: cast_nullable_to_non_nullable
as int,rows: null == rows ? _self.rows : rows // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$TerminalAttachParamsDto {

 String get terminalId; TerminalRestoreMode get mode; int get afterSequence; int get scrollbackLines;/// Null for a passive attach, which must not claim the terminal's size.
///
/// Only a viewport the user genuinely changed or focused claims the size.
/// Attaching, restoring visibility, and a renderer settling are not that,
/// and a claim from one would fight every other attached client.
 TerminalViewportDto? get viewport;
/// Create a copy of TerminalAttachParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TerminalAttachParamsDtoCopyWith<TerminalAttachParamsDto> get copyWith => _$TerminalAttachParamsDtoCopyWithImpl<TerminalAttachParamsDto>(this as TerminalAttachParamsDto, _$identity);

  /// Serializes this TerminalAttachParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TerminalAttachParamsDto&&(identical(other.terminalId, terminalId) || other.terminalId == terminalId)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.afterSequence, afterSequence) || other.afterSequence == afterSequence)&&(identical(other.scrollbackLines, scrollbackLines) || other.scrollbackLines == scrollbackLines)&&(identical(other.viewport, viewport) || other.viewport == viewport));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,terminalId,mode,afterSequence,scrollbackLines,viewport);

@override
String toString() {
  return 'TerminalAttachParamsDto(terminalId: $terminalId, mode: $mode, afterSequence: $afterSequence, scrollbackLines: $scrollbackLines, viewport: $viewport)';
}


}

/// @nodoc
abstract mixin class $TerminalAttachParamsDtoCopyWith<$Res>  {
  factory $TerminalAttachParamsDtoCopyWith(TerminalAttachParamsDto value, $Res Function(TerminalAttachParamsDto) _then) = _$TerminalAttachParamsDtoCopyWithImpl;
@useResult
$Res call({
 String terminalId, TerminalRestoreMode mode, int afterSequence, int scrollbackLines, TerminalViewportDto? viewport
});


$TerminalViewportDtoCopyWith<$Res>? get viewport;

}
/// @nodoc
class _$TerminalAttachParamsDtoCopyWithImpl<$Res>
    implements $TerminalAttachParamsDtoCopyWith<$Res> {
  _$TerminalAttachParamsDtoCopyWithImpl(this._self, this._then);

  final TerminalAttachParamsDto _self;
  final $Res Function(TerminalAttachParamsDto) _then;

/// Create a copy of TerminalAttachParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? terminalId = null,Object? mode = null,Object? afterSequence = null,Object? scrollbackLines = null,Object? viewport = freezed,}) {
  return _then(TerminalAttachParamsDto(
terminalId: null == terminalId ? _self.terminalId : terminalId // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as TerminalRestoreMode,afterSequence: null == afterSequence ? _self.afterSequence : afterSequence // ignore: cast_nullable_to_non_nullable
as int,scrollbackLines: null == scrollbackLines ? _self.scrollbackLines : scrollbackLines // ignore: cast_nullable_to_non_nullable
as int,viewport: freezed == viewport ? _self.viewport : viewport // ignore: cast_nullable_to_non_nullable
as TerminalViewportDto?,
  ));
}
/// Create a copy of TerminalAttachParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TerminalViewportDtoCopyWith<$Res>? get viewport {
    if (_self.viewport == null) {
    return null;
  }

  return $TerminalViewportDtoCopyWith<$Res>(_self.viewport!, (value) {
    return _then(_self.copyWith(viewport: value));
  });
}
}


/// Adds pattern-matching-related methods to [TerminalAttachParamsDto].
extension TerminalAttachParamsDtoPatterns on TerminalAttachParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TerminalAttachParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TerminalAttachParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TerminalAttachParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _TerminalAttachParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TerminalAttachParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _TerminalAttachParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String terminalId,  TerminalRestoreMode mode,  int afterSequence,  int scrollbackLines,  TerminalViewportDto? viewport)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TerminalAttachParamsDto() when $default != null:
return $default(_that.terminalId,_that.mode,_that.afterSequence,_that.scrollbackLines,_that.viewport);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String terminalId,  TerminalRestoreMode mode,  int afterSequence,  int scrollbackLines,  TerminalViewportDto? viewport)  $default,) {final _that = this;
switch (_that) {
case _TerminalAttachParamsDto():
return $default(_that.terminalId,_that.mode,_that.afterSequence,_that.scrollbackLines,_that.viewport);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String terminalId,  TerminalRestoreMode mode,  int afterSequence,  int scrollbackLines,  TerminalViewportDto? viewport)?  $default,) {final _that = this;
switch (_that) {
case _TerminalAttachParamsDto() when $default != null:
return $default(_that.terminalId,_that.mode,_that.afterSequence,_that.scrollbackLines,_that.viewport);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TerminalAttachParamsDto implements TerminalAttachParamsDto {
  const _TerminalAttachParamsDto({required this.terminalId, required this.mode, this.afterSequence = 0, this.scrollbackLines = terminalRestoreScrollbackLines, this.viewport});
  factory _TerminalAttachParamsDto.fromJson(Map<String, dynamic> json) => _$TerminalAttachParamsDtoFromJson(json);

@override final  String terminalId;
@override final  TerminalRestoreMode mode;
@override@JsonKey() final  int afterSequence;
@override@JsonKey() final  int scrollbackLines;
/// Null for a passive attach, which must not claim the terminal's size.
///
/// Only a viewport the user genuinely changed or focused claims the size.
/// Attaching, restoring visibility, and a renderer settling are not that,
/// and a claim from one would fight every other attached client.
@override final  TerminalViewportDto? viewport;

/// Create a copy of TerminalAttachParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TerminalAttachParamsDtoCopyWith<_TerminalAttachParamsDto> get copyWith => __$TerminalAttachParamsDtoCopyWithImpl<_TerminalAttachParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TerminalAttachParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TerminalAttachParamsDto&&(identical(other.terminalId, terminalId) || other.terminalId == terminalId)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.afterSequence, afterSequence) || other.afterSequence == afterSequence)&&(identical(other.scrollbackLines, scrollbackLines) || other.scrollbackLines == scrollbackLines)&&(identical(other.viewport, viewport) || other.viewport == viewport));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,terminalId,mode,afterSequence,scrollbackLines,viewport);

@override
String toString() {
  return 'TerminalAttachParamsDto(terminalId: $terminalId, mode: $mode, afterSequence: $afterSequence, scrollbackLines: $scrollbackLines, viewport: $viewport)';
}


}

/// @nodoc
abstract mixin class _$TerminalAttachParamsDtoCopyWith<$Res> implements $TerminalAttachParamsDtoCopyWith<$Res> {
  factory _$TerminalAttachParamsDtoCopyWith(_TerminalAttachParamsDto value, $Res Function(_TerminalAttachParamsDto) _then) = __$TerminalAttachParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String terminalId, TerminalRestoreMode mode, int afterSequence, int scrollbackLines, TerminalViewportDto? viewport
});


@override $TerminalViewportDtoCopyWith<$Res>? get viewport;

}
/// @nodoc
class __$TerminalAttachParamsDtoCopyWithImpl<$Res>
    implements _$TerminalAttachParamsDtoCopyWith<$Res> {
  __$TerminalAttachParamsDtoCopyWithImpl(this._self, this._then);

  final _TerminalAttachParamsDto _self;
  final $Res Function(_TerminalAttachParamsDto) _then;

/// Create a copy of TerminalAttachParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? terminalId = null,Object? mode = null,Object? afterSequence = null,Object? scrollbackLines = null,Object? viewport = freezed,}) {
  return _then(_TerminalAttachParamsDto(
terminalId: null == terminalId ? _self.terminalId : terminalId // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as TerminalRestoreMode,afterSequence: null == afterSequence ? _self.afterSequence : afterSequence // ignore: cast_nullable_to_non_nullable
as int,scrollbackLines: null == scrollbackLines ? _self.scrollbackLines : scrollbackLines // ignore: cast_nullable_to_non_nullable
as int,viewport: freezed == viewport ? _self.viewport : viewport // ignore: cast_nullable_to_non_nullable
as TerminalViewportDto?,
  ));
}

/// Create a copy of TerminalAttachParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TerminalViewportDtoCopyWith<$Res>? get viewport {
    if (_self.viewport == null) {
    return null;
  }

  return $TerminalViewportDtoCopyWith<$Res>(_self.viewport!, (value) {
    return _then(_self.copyWith(viewport: value));
  });
}
}

TerminalRestoreDto _$TerminalRestoreDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'delta':
          return TerminalDeltaRestoreDto.fromJson(
            json
          );
                case 'snapshot':
          return TerminalSnapshotRestoreDto.fromJson(
            json
          );

          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'TerminalRestoreDto',
  'Invalid union type "${json['type']}"!'
);
        }

}

/// @nodoc
mixin _$TerminalRestoreDto {



  /// Serializes this TerminalRestoreDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TerminalRestoreDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TerminalRestoreDto()';
}


}

/// @nodoc
class $TerminalRestoreDtoCopyWith<$Res>  {
$TerminalRestoreDtoCopyWith(TerminalRestoreDto _, $Res Function(TerminalRestoreDto) __);
}


/// Adds pattern-matching-related methods to [TerminalRestoreDto].
extension TerminalRestoreDtoPatterns on TerminalRestoreDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TerminalDeltaRestoreDto value)?  delta,TResult Function( TerminalSnapshotRestoreDto value)?  snapshot,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TerminalDeltaRestoreDto() when delta != null:
return delta(_that);case TerminalSnapshotRestoreDto() when snapshot != null:
return snapshot(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TerminalDeltaRestoreDto value)  delta,required TResult Function( TerminalSnapshotRestoreDto value)  snapshot,}){
final _that = this;
switch (_that) {
case TerminalDeltaRestoreDto():
return delta(_that);case TerminalSnapshotRestoreDto():
return snapshot(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TerminalDeltaRestoreDto value)?  delta,TResult? Function( TerminalSnapshotRestoreDto value)?  snapshot,}){
final _that = this;
switch (_that) {
case TerminalDeltaRestoreDto() when delta != null:
return delta(_that);case TerminalSnapshotRestoreDto() when snapshot != null:
return snapshot(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int afterSequence,  List<TerminalOutputDto> chunks)?  delta,TResult Function( int throughSequence,  String ansi)?  snapshot,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TerminalDeltaRestoreDto() when delta != null:
return delta(_that.afterSequence,_that.chunks);case TerminalSnapshotRestoreDto() when snapshot != null:
return snapshot(_that.throughSequence,_that.ansi);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int afterSequence,  List<TerminalOutputDto> chunks)  delta,required TResult Function( int throughSequence,  String ansi)  snapshot,}) {final _that = this;
switch (_that) {
case TerminalDeltaRestoreDto():
return delta(_that.afterSequence,_that.chunks);case TerminalSnapshotRestoreDto():
return snapshot(_that.throughSequence,_that.ansi);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int afterSequence,  List<TerminalOutputDto> chunks)?  delta,TResult? Function( int throughSequence,  String ansi)?  snapshot,}) {final _that = this;
switch (_that) {
case TerminalDeltaRestoreDto() when delta != null:
return delta(_that.afterSequence,_that.chunks);case TerminalSnapshotRestoreDto() when snapshot != null:
return snapshot(_that.throughSequence,_that.ansi);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class TerminalDeltaRestoreDto implements TerminalRestoreDto {
  const TerminalDeltaRestoreDto({required this.afterSequence, required  List<TerminalOutputDto> chunks,  String? $type}): _chunks = chunks,$type = $type ?? 'delta';
  factory TerminalDeltaRestoreDto.fromJson(Map<String, dynamic> json) => _$TerminalDeltaRestoreDtoFromJson(json);

 final  int afterSequence;
 final  List<TerminalOutputDto> _chunks;
 List<TerminalOutputDto> get chunks {
  if (_chunks is EqualUnmodifiableListView) return _chunks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_chunks);
}


@JsonKey(name: 'type')
final String $type;


/// Create a copy of TerminalRestoreDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TerminalDeltaRestoreDtoCopyWith<TerminalDeltaRestoreDto> get copyWith => _$TerminalDeltaRestoreDtoCopyWithImpl<TerminalDeltaRestoreDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TerminalDeltaRestoreDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TerminalDeltaRestoreDto&&(identical(other.afterSequence, afterSequence) || other.afterSequence == afterSequence)&&const DeepCollectionEquality().equals(other._chunks, _chunks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,afterSequence,const DeepCollectionEquality().hash(_chunks));

@override
String toString() {
  return 'TerminalRestoreDto.delta(afterSequence: $afterSequence, chunks: $chunks)';
}


}

/// @nodoc
abstract mixin class $TerminalDeltaRestoreDtoCopyWith<$Res> implements $TerminalRestoreDtoCopyWith<$Res> {
  factory $TerminalDeltaRestoreDtoCopyWith(TerminalDeltaRestoreDto value, $Res Function(TerminalDeltaRestoreDto) _then) = _$TerminalDeltaRestoreDtoCopyWithImpl;
@useResult
$Res call({
 int afterSequence, List<TerminalOutputDto> chunks
});




}
/// @nodoc
class _$TerminalDeltaRestoreDtoCopyWithImpl<$Res>
    implements $TerminalDeltaRestoreDtoCopyWith<$Res> {
  _$TerminalDeltaRestoreDtoCopyWithImpl(this._self, this._then);

  final TerminalDeltaRestoreDto _self;
  final $Res Function(TerminalDeltaRestoreDto) _then;

/// Create a copy of TerminalRestoreDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? afterSequence = null,Object? chunks = null,}) {
  return _then(TerminalDeltaRestoreDto(
afterSequence: null == afterSequence ? _self.afterSequence : afterSequence // ignore: cast_nullable_to_non_nullable
as int,chunks: null == chunks ? _self._chunks : chunks // ignore: cast_nullable_to_non_nullable
as List<TerminalOutputDto>,
  ));
}


}

/// @nodoc
@JsonSerializable()

class TerminalSnapshotRestoreDto implements TerminalRestoreDto {
  const TerminalSnapshotRestoreDto({required this.throughSequence, required this.ansi,  String? $type}): $type = $type ?? 'snapshot';
  factory TerminalSnapshotRestoreDto.fromJson(Map<String, dynamic> json) => _$TerminalSnapshotRestoreDtoFromJson(json);

 final  int throughSequence;
 final  String ansi;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of TerminalRestoreDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TerminalSnapshotRestoreDtoCopyWith<TerminalSnapshotRestoreDto> get copyWith => _$TerminalSnapshotRestoreDtoCopyWithImpl<TerminalSnapshotRestoreDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TerminalSnapshotRestoreDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TerminalSnapshotRestoreDto&&(identical(other.throughSequence, throughSequence) || other.throughSequence == throughSequence)&&(identical(other.ansi, ansi) || other.ansi == ansi));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,throughSequence,ansi);

@override
String toString() {
  return 'TerminalRestoreDto.snapshot(throughSequence: $throughSequence, ansi: $ansi)';
}


}

/// @nodoc
abstract mixin class $TerminalSnapshotRestoreDtoCopyWith<$Res> implements $TerminalRestoreDtoCopyWith<$Res> {
  factory $TerminalSnapshotRestoreDtoCopyWith(TerminalSnapshotRestoreDto value, $Res Function(TerminalSnapshotRestoreDto) _then) = _$TerminalSnapshotRestoreDtoCopyWithImpl;
@useResult
$Res call({
 int throughSequence, String ansi
});




}
/// @nodoc
class _$TerminalSnapshotRestoreDtoCopyWithImpl<$Res>
    implements $TerminalSnapshotRestoreDtoCopyWith<$Res> {
  _$TerminalSnapshotRestoreDtoCopyWithImpl(this._self, this._then);

  final TerminalSnapshotRestoreDto _self;
  final $Res Function(TerminalSnapshotRestoreDto) _then;

/// Create a copy of TerminalRestoreDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? throughSequence = null,Object? ansi = null,}) {
  return _then(TerminalSnapshotRestoreDto(
throughSequence: null == throughSequence ? _self.throughSequence : throughSequence // ignore: cast_nullable_to_non_nullable
as int,ansi: null == ansi ? _self.ansi : ansi // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$TerminalAttachResultDto {

 TerminalDto get terminal; TerminalRestoreDto get restore;
/// Create a copy of TerminalAttachResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TerminalAttachResultDtoCopyWith<TerminalAttachResultDto> get copyWith => _$TerminalAttachResultDtoCopyWithImpl<TerminalAttachResultDto>(this as TerminalAttachResultDto, _$identity);

  /// Serializes this TerminalAttachResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TerminalAttachResultDto&&(identical(other.terminal, terminal) || other.terminal == terminal)&&(identical(other.restore, restore) || other.restore == restore));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,terminal,restore);

@override
String toString() {
  return 'TerminalAttachResultDto(terminal: $terminal, restore: $restore)';
}


}

/// @nodoc
abstract mixin class $TerminalAttachResultDtoCopyWith<$Res>  {
  factory $TerminalAttachResultDtoCopyWith(TerminalAttachResultDto value, $Res Function(TerminalAttachResultDto) _then) = _$TerminalAttachResultDtoCopyWithImpl;
@useResult
$Res call({
 TerminalDto terminal, TerminalRestoreDto restore
});


$TerminalDtoCopyWith<$Res> get terminal;$TerminalRestoreDtoCopyWith<$Res> get restore;

}
/// @nodoc
class _$TerminalAttachResultDtoCopyWithImpl<$Res>
    implements $TerminalAttachResultDtoCopyWith<$Res> {
  _$TerminalAttachResultDtoCopyWithImpl(this._self, this._then);

  final TerminalAttachResultDto _self;
  final $Res Function(TerminalAttachResultDto) _then;

/// Create a copy of TerminalAttachResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? terminal = null,Object? restore = null,}) {
  return _then(TerminalAttachResultDto(
terminal: null == terminal ? _self.terminal : terminal // ignore: cast_nullable_to_non_nullable
as TerminalDto,restore: null == restore ? _self.restore : restore // ignore: cast_nullable_to_non_nullable
as TerminalRestoreDto,
  ));
}
/// Create a copy of TerminalAttachResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TerminalDtoCopyWith<$Res> get terminal {

  return $TerminalDtoCopyWith<$Res>(_self.terminal, (value) {
    return _then(_self.copyWith(terminal: value));
  });
}/// Create a copy of TerminalAttachResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TerminalRestoreDtoCopyWith<$Res> get restore {

  return $TerminalRestoreDtoCopyWith<$Res>(_self.restore, (value) {
    return _then(_self.copyWith(restore: value));
  });
}
}


/// Adds pattern-matching-related methods to [TerminalAttachResultDto].
extension TerminalAttachResultDtoPatterns on TerminalAttachResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TerminalAttachResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TerminalAttachResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TerminalAttachResultDto value)  $default,){
final _that = this;
switch (_that) {
case _TerminalAttachResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TerminalAttachResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _TerminalAttachResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TerminalDto terminal,  TerminalRestoreDto restore)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TerminalAttachResultDto() when $default != null:
return $default(_that.terminal,_that.restore);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TerminalDto terminal,  TerminalRestoreDto restore)  $default,) {final _that = this;
switch (_that) {
case _TerminalAttachResultDto():
return $default(_that.terminal,_that.restore);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TerminalDto terminal,  TerminalRestoreDto restore)?  $default,) {final _that = this;
switch (_that) {
case _TerminalAttachResultDto() when $default != null:
return $default(_that.terminal,_that.restore);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TerminalAttachResultDto implements TerminalAttachResultDto {
  const _TerminalAttachResultDto({required this.terminal, required this.restore});
  factory _TerminalAttachResultDto.fromJson(Map<String, dynamic> json) => _$TerminalAttachResultDtoFromJson(json);

@override final  TerminalDto terminal;
@override final  TerminalRestoreDto restore;

/// Create a copy of TerminalAttachResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TerminalAttachResultDtoCopyWith<_TerminalAttachResultDto> get copyWith => __$TerminalAttachResultDtoCopyWithImpl<_TerminalAttachResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TerminalAttachResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TerminalAttachResultDto&&(identical(other.terminal, terminal) || other.terminal == terminal)&&(identical(other.restore, restore) || other.restore == restore));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,terminal,restore);

@override
String toString() {
  return 'TerminalAttachResultDto(terminal: $terminal, restore: $restore)';
}


}

/// @nodoc
abstract mixin class _$TerminalAttachResultDtoCopyWith<$Res> implements $TerminalAttachResultDtoCopyWith<$Res> {
  factory _$TerminalAttachResultDtoCopyWith(_TerminalAttachResultDto value, $Res Function(_TerminalAttachResultDto) _then) = __$TerminalAttachResultDtoCopyWithImpl;
@override @useResult
$Res call({
 TerminalDto terminal, TerminalRestoreDto restore
});


@override $TerminalDtoCopyWith<$Res> get terminal;@override $TerminalRestoreDtoCopyWith<$Res> get restore;

}
/// @nodoc
class __$TerminalAttachResultDtoCopyWithImpl<$Res>
    implements _$TerminalAttachResultDtoCopyWith<$Res> {
  __$TerminalAttachResultDtoCopyWithImpl(this._self, this._then);

  final _TerminalAttachResultDto _self;
  final $Res Function(_TerminalAttachResultDto) _then;

/// Create a copy of TerminalAttachResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? terminal = null,Object? restore = null,}) {
  return _then(_TerminalAttachResultDto(
terminal: null == terminal ? _self.terminal : terminal // ignore: cast_nullable_to_non_nullable
as TerminalDto,restore: null == restore ? _self.restore : restore // ignore: cast_nullable_to_non_nullable
as TerminalRestoreDto,
  ));
}

/// Create a copy of TerminalAttachResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TerminalDtoCopyWith<$Res> get terminal {

  return $TerminalDtoCopyWith<$Res>(_self.terminal, (value) {
    return _then(_self.copyWith(terminal: value));
  });
}/// Create a copy of TerminalAttachResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TerminalRestoreDtoCopyWith<$Res> get restore {

  return $TerminalRestoreDtoCopyWith<$Res>(_self.restore, (value) {
    return _then(_self.copyWith(restore: value));
  });
}
}


/// @nodoc
mixin _$TerminalResultDto {

 TerminalDto get terminal;
/// Create a copy of TerminalResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TerminalResultDtoCopyWith<TerminalResultDto> get copyWith => _$TerminalResultDtoCopyWithImpl<TerminalResultDto>(this as TerminalResultDto, _$identity);

  /// Serializes this TerminalResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TerminalResultDto&&(identical(other.terminal, terminal) || other.terminal == terminal));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,terminal);

@override
String toString() {
  return 'TerminalResultDto(terminal: $terminal)';
}


}

/// @nodoc
abstract mixin class $TerminalResultDtoCopyWith<$Res>  {
  factory $TerminalResultDtoCopyWith(TerminalResultDto value, $Res Function(TerminalResultDto) _then) = _$TerminalResultDtoCopyWithImpl;
@useResult
$Res call({
 TerminalDto terminal
});


$TerminalDtoCopyWith<$Res> get terminal;

}
/// @nodoc
class _$TerminalResultDtoCopyWithImpl<$Res>
    implements $TerminalResultDtoCopyWith<$Res> {
  _$TerminalResultDtoCopyWithImpl(this._self, this._then);

  final TerminalResultDto _self;
  final $Res Function(TerminalResultDto) _then;

/// Create a copy of TerminalResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? terminal = null,}) {
  return _then(TerminalResultDto(
terminal: null == terminal ? _self.terminal : terminal // ignore: cast_nullable_to_non_nullable
as TerminalDto,
  ));
}
/// Create a copy of TerminalResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TerminalDtoCopyWith<$Res> get terminal {

  return $TerminalDtoCopyWith<$Res>(_self.terminal, (value) {
    return _then(_self.copyWith(terminal: value));
  });
}
}


/// Adds pattern-matching-related methods to [TerminalResultDto].
extension TerminalResultDtoPatterns on TerminalResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TerminalResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TerminalResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TerminalResultDto value)  $default,){
final _that = this;
switch (_that) {
case _TerminalResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TerminalResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _TerminalResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TerminalDto terminal)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TerminalResultDto() when $default != null:
return $default(_that.terminal);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TerminalDto terminal)  $default,) {final _that = this;
switch (_that) {
case _TerminalResultDto():
return $default(_that.terminal);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TerminalDto terminal)?  $default,) {final _that = this;
switch (_that) {
case _TerminalResultDto() when $default != null:
return $default(_that.terminal);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TerminalResultDto implements TerminalResultDto {
  const _TerminalResultDto({required this.terminal});
  factory _TerminalResultDto.fromJson(Map<String, dynamic> json) => _$TerminalResultDtoFromJson(json);

@override final  TerminalDto terminal;

/// Create a copy of TerminalResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TerminalResultDtoCopyWith<_TerminalResultDto> get copyWith => __$TerminalResultDtoCopyWithImpl<_TerminalResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TerminalResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TerminalResultDto&&(identical(other.terminal, terminal) || other.terminal == terminal));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,terminal);

@override
String toString() {
  return 'TerminalResultDto(terminal: $terminal)';
}


}

/// @nodoc
abstract mixin class _$TerminalResultDtoCopyWith<$Res> implements $TerminalResultDtoCopyWith<$Res> {
  factory _$TerminalResultDtoCopyWith(_TerminalResultDto value, $Res Function(_TerminalResultDto) _then) = __$TerminalResultDtoCopyWithImpl;
@override @useResult
$Res call({
 TerminalDto terminal
});


@override $TerminalDtoCopyWith<$Res> get terminal;

}
/// @nodoc
class __$TerminalResultDtoCopyWithImpl<$Res>
    implements _$TerminalResultDtoCopyWith<$Res> {
  __$TerminalResultDtoCopyWithImpl(this._self, this._then);

  final _TerminalResultDto _self;
  final $Res Function(_TerminalResultDto) _then;

/// Create a copy of TerminalResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? terminal = null,}) {
  return _then(_TerminalResultDto(
terminal: null == terminal ? _self.terminal : terminal // ignore: cast_nullable_to_non_nullable
as TerminalDto,
  ));
}

/// Create a copy of TerminalResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TerminalDtoCopyWith<$Res> get terminal {

  return $TerminalDtoCopyWith<$Res>(_self.terminal, (value) {
    return _then(_self.copyWith(terminal: value));
  });
}
}


/// @nodoc
mixin _$TerminalWriteParamsDto {

 String get terminalId; String get data;
/// Create a copy of TerminalWriteParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TerminalWriteParamsDtoCopyWith<TerminalWriteParamsDto> get copyWith => _$TerminalWriteParamsDtoCopyWithImpl<TerminalWriteParamsDto>(this as TerminalWriteParamsDto, _$identity);

  /// Serializes this TerminalWriteParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TerminalWriteParamsDto&&(identical(other.terminalId, terminalId) || other.terminalId == terminalId)&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,terminalId,data);

@override
String toString() {
  return 'TerminalWriteParamsDto(terminalId: $terminalId, data: $data)';
}


}

/// @nodoc
abstract mixin class $TerminalWriteParamsDtoCopyWith<$Res>  {
  factory $TerminalWriteParamsDtoCopyWith(TerminalWriteParamsDto value, $Res Function(TerminalWriteParamsDto) _then) = _$TerminalWriteParamsDtoCopyWithImpl;
@useResult
$Res call({
 String terminalId, String data
});




}
/// @nodoc
class _$TerminalWriteParamsDtoCopyWithImpl<$Res>
    implements $TerminalWriteParamsDtoCopyWith<$Res> {
  _$TerminalWriteParamsDtoCopyWithImpl(this._self, this._then);

  final TerminalWriteParamsDto _self;
  final $Res Function(TerminalWriteParamsDto) _then;

/// Create a copy of TerminalWriteParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? terminalId = null,Object? data = null,}) {
  return _then(TerminalWriteParamsDto(
terminalId: null == terminalId ? _self.terminalId : terminalId // ignore: cast_nullable_to_non_nullable
as String,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TerminalWriteParamsDto].
extension TerminalWriteParamsDtoPatterns on TerminalWriteParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TerminalWriteParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TerminalWriteParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TerminalWriteParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _TerminalWriteParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TerminalWriteParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _TerminalWriteParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String terminalId,  String data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TerminalWriteParamsDto() when $default != null:
return $default(_that.terminalId,_that.data);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String terminalId,  String data)  $default,) {final _that = this;
switch (_that) {
case _TerminalWriteParamsDto():
return $default(_that.terminalId,_that.data);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String terminalId,  String data)?  $default,) {final _that = this;
switch (_that) {
case _TerminalWriteParamsDto() when $default != null:
return $default(_that.terminalId,_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TerminalWriteParamsDto implements TerminalWriteParamsDto {
  const _TerminalWriteParamsDto({required this.terminalId, required this.data});
  factory _TerminalWriteParamsDto.fromJson(Map<String, dynamic> json) => _$TerminalWriteParamsDtoFromJson(json);

@override final  String terminalId;
@override final  String data;

/// Create a copy of TerminalWriteParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TerminalWriteParamsDtoCopyWith<_TerminalWriteParamsDto> get copyWith => __$TerminalWriteParamsDtoCopyWithImpl<_TerminalWriteParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TerminalWriteParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TerminalWriteParamsDto&&(identical(other.terminalId, terminalId) || other.terminalId == terminalId)&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,terminalId,data);

@override
String toString() {
  return 'TerminalWriteParamsDto(terminalId: $terminalId, data: $data)';
}


}

/// @nodoc
abstract mixin class _$TerminalWriteParamsDtoCopyWith<$Res> implements $TerminalWriteParamsDtoCopyWith<$Res> {
  factory _$TerminalWriteParamsDtoCopyWith(_TerminalWriteParamsDto value, $Res Function(_TerminalWriteParamsDto) _then) = __$TerminalWriteParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String terminalId, String data
});




}
/// @nodoc
class __$TerminalWriteParamsDtoCopyWithImpl<$Res>
    implements _$TerminalWriteParamsDtoCopyWith<$Res> {
  __$TerminalWriteParamsDtoCopyWithImpl(this._self, this._then);

  final _TerminalWriteParamsDto _self;
  final $Res Function(_TerminalWriteParamsDto) _then;

/// Create a copy of TerminalWriteParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? terminalId = null,Object? data = null,}) {
  return _then(_TerminalWriteParamsDto(
terminalId: null == terminalId ? _self.terminalId : terminalId // ignore: cast_nullable_to_non_nullable
as String,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$TerminalResizeParamsDto {

 String get terminalId; int get columns; int get rows;
/// Create a copy of TerminalResizeParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TerminalResizeParamsDtoCopyWith<TerminalResizeParamsDto> get copyWith => _$TerminalResizeParamsDtoCopyWithImpl<TerminalResizeParamsDto>(this as TerminalResizeParamsDto, _$identity);

  /// Serializes this TerminalResizeParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TerminalResizeParamsDto&&(identical(other.terminalId, terminalId) || other.terminalId == terminalId)&&(identical(other.columns, columns) || other.columns == columns)&&(identical(other.rows, rows) || other.rows == rows));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,terminalId,columns,rows);

@override
String toString() {
  return 'TerminalResizeParamsDto(terminalId: $terminalId, columns: $columns, rows: $rows)';
}


}

/// @nodoc
abstract mixin class $TerminalResizeParamsDtoCopyWith<$Res>  {
  factory $TerminalResizeParamsDtoCopyWith(TerminalResizeParamsDto value, $Res Function(TerminalResizeParamsDto) _then) = _$TerminalResizeParamsDtoCopyWithImpl;
@useResult
$Res call({
 String terminalId, int columns, int rows
});




}
/// @nodoc
class _$TerminalResizeParamsDtoCopyWithImpl<$Res>
    implements $TerminalResizeParamsDtoCopyWith<$Res> {
  _$TerminalResizeParamsDtoCopyWithImpl(this._self, this._then);

  final TerminalResizeParamsDto _self;
  final $Res Function(TerminalResizeParamsDto) _then;

/// Create a copy of TerminalResizeParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? terminalId = null,Object? columns = null,Object? rows = null,}) {
  return _then(TerminalResizeParamsDto(
terminalId: null == terminalId ? _self.terminalId : terminalId // ignore: cast_nullable_to_non_nullable
as String,columns: null == columns ? _self.columns : columns // ignore: cast_nullable_to_non_nullable
as int,rows: null == rows ? _self.rows : rows // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TerminalResizeParamsDto].
extension TerminalResizeParamsDtoPatterns on TerminalResizeParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TerminalResizeParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TerminalResizeParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TerminalResizeParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _TerminalResizeParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TerminalResizeParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _TerminalResizeParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String terminalId,  int columns,  int rows)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TerminalResizeParamsDto() when $default != null:
return $default(_that.terminalId,_that.columns,_that.rows);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String terminalId,  int columns,  int rows)  $default,) {final _that = this;
switch (_that) {
case _TerminalResizeParamsDto():
return $default(_that.terminalId,_that.columns,_that.rows);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String terminalId,  int columns,  int rows)?  $default,) {final _that = this;
switch (_that) {
case _TerminalResizeParamsDto() when $default != null:
return $default(_that.terminalId,_that.columns,_that.rows);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TerminalResizeParamsDto implements TerminalResizeParamsDto {
  const _TerminalResizeParamsDto({required this.terminalId, required this.columns, required this.rows});
  factory _TerminalResizeParamsDto.fromJson(Map<String, dynamic> json) => _$TerminalResizeParamsDtoFromJson(json);

@override final  String terminalId;
@override final  int columns;
@override final  int rows;

/// Create a copy of TerminalResizeParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TerminalResizeParamsDtoCopyWith<_TerminalResizeParamsDto> get copyWith => __$TerminalResizeParamsDtoCopyWithImpl<_TerminalResizeParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TerminalResizeParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TerminalResizeParamsDto&&(identical(other.terminalId, terminalId) || other.terminalId == terminalId)&&(identical(other.columns, columns) || other.columns == columns)&&(identical(other.rows, rows) || other.rows == rows));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,terminalId,columns,rows);

@override
String toString() {
  return 'TerminalResizeParamsDto(terminalId: $terminalId, columns: $columns, rows: $rows)';
}


}

/// @nodoc
abstract mixin class _$TerminalResizeParamsDtoCopyWith<$Res> implements $TerminalResizeParamsDtoCopyWith<$Res> {
  factory _$TerminalResizeParamsDtoCopyWith(_TerminalResizeParamsDto value, $Res Function(_TerminalResizeParamsDto) _then) = __$TerminalResizeParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String terminalId, int columns, int rows
});




}
/// @nodoc
class __$TerminalResizeParamsDtoCopyWithImpl<$Res>
    implements _$TerminalResizeParamsDtoCopyWith<$Res> {
  __$TerminalResizeParamsDtoCopyWithImpl(this._self, this._then);

  final _TerminalResizeParamsDto _self;
  final $Res Function(_TerminalResizeParamsDto) _then;

/// Create a copy of TerminalResizeParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? terminalId = null,Object? columns = null,Object? rows = null,}) {
  return _then(_TerminalResizeParamsDto(
terminalId: null == terminalId ? _self.terminalId : terminalId // ignore: cast_nullable_to_non_nullable
as String,columns: null == columns ? _self.columns : columns // ignore: cast_nullable_to_non_nullable
as int,rows: null == rows ? _self.rows : rows // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$TerminalShellDto {

 ShellSpecDto? get shell;
/// Create a copy of TerminalShellDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TerminalShellDtoCopyWith<TerminalShellDto> get copyWith => _$TerminalShellDtoCopyWithImpl<TerminalShellDto>(this as TerminalShellDto, _$identity);

  /// Serializes this TerminalShellDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TerminalShellDto&&(identical(other.shell, shell) || other.shell == shell));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,shell);

@override
String toString() {
  return 'TerminalShellDto(shell: $shell)';
}


}

/// @nodoc
abstract mixin class $TerminalShellDtoCopyWith<$Res>  {
  factory $TerminalShellDtoCopyWith(TerminalShellDto value, $Res Function(TerminalShellDto) _then) = _$TerminalShellDtoCopyWithImpl;
@useResult
$Res call({
 ShellSpecDto? shell
});


$ShellSpecDtoCopyWith<$Res>? get shell;

}
/// @nodoc
class _$TerminalShellDtoCopyWithImpl<$Res>
    implements $TerminalShellDtoCopyWith<$Res> {
  _$TerminalShellDtoCopyWithImpl(this._self, this._then);

  final TerminalShellDto _self;
  final $Res Function(TerminalShellDto) _then;

/// Create a copy of TerminalShellDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? shell = freezed,}) {
  return _then(TerminalShellDto(
shell: freezed == shell ? _self.shell : shell // ignore: cast_nullable_to_non_nullable
as ShellSpecDto?,
  ));
}
/// Create a copy of TerminalShellDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ShellSpecDtoCopyWith<$Res>? get shell {
    if (_self.shell == null) {
    return null;
  }

  return $ShellSpecDtoCopyWith<$Res>(_self.shell!, (value) {
    return _then(_self.copyWith(shell: value));
  });
}
}


/// Adds pattern-matching-related methods to [TerminalShellDto].
extension TerminalShellDtoPatterns on TerminalShellDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TerminalShellDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TerminalShellDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TerminalShellDto value)  $default,){
final _that = this;
switch (_that) {
case _TerminalShellDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TerminalShellDto value)?  $default,){
final _that = this;
switch (_that) {
case _TerminalShellDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ShellSpecDto? shell)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TerminalShellDto() when $default != null:
return $default(_that.shell);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ShellSpecDto? shell)  $default,) {final _that = this;
switch (_that) {
case _TerminalShellDto():
return $default(_that.shell);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ShellSpecDto? shell)?  $default,) {final _that = this;
switch (_that) {
case _TerminalShellDto() when $default != null:
return $default(_that.shell);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TerminalShellDto implements TerminalShellDto {
  const _TerminalShellDto({this.shell});
  factory _TerminalShellDto.fromJson(Map<String, dynamic> json) => _$TerminalShellDtoFromJson(json);

@override final  ShellSpecDto? shell;

/// Create a copy of TerminalShellDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TerminalShellDtoCopyWith<_TerminalShellDto> get copyWith => __$TerminalShellDtoCopyWithImpl<_TerminalShellDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TerminalShellDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TerminalShellDto&&(identical(other.shell, shell) || other.shell == shell));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,shell);

@override
String toString() {
  return 'TerminalShellDto(shell: $shell)';
}


}

/// @nodoc
abstract mixin class _$TerminalShellDtoCopyWith<$Res> implements $TerminalShellDtoCopyWith<$Res> {
  factory _$TerminalShellDtoCopyWith(_TerminalShellDto value, $Res Function(_TerminalShellDto) _then) = __$TerminalShellDtoCopyWithImpl;
@override @useResult
$Res call({
 ShellSpecDto? shell
});


@override $ShellSpecDtoCopyWith<$Res>? get shell;

}
/// @nodoc
class __$TerminalShellDtoCopyWithImpl<$Res>
    implements _$TerminalShellDtoCopyWith<$Res> {
  __$TerminalShellDtoCopyWithImpl(this._self, this._then);

  final _TerminalShellDto _self;
  final $Res Function(_TerminalShellDto) _then;

/// Create a copy of TerminalShellDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? shell = freezed,}) {
  return _then(_TerminalShellDto(
shell: freezed == shell ? _self.shell : shell // ignore: cast_nullable_to_non_nullable
as ShellSpecDto?,
  ));
}

/// Create a copy of TerminalShellDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ShellSpecDtoCopyWith<$Res>? get shell {
    if (_self.shell == null) {
    return null;
  }

  return $ShellSpecDtoCopyWith<$Res>(_self.shell!, (value) {
    return _then(_self.copyWith(shell: value));
  });
}
}


/// @nodoc
mixin _$PermissionSettingsDto {

 PermissionMode get defaultMode;
/// Create a copy of PermissionSettingsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PermissionSettingsDtoCopyWith<PermissionSettingsDto> get copyWith => _$PermissionSettingsDtoCopyWithImpl<PermissionSettingsDto>(this as PermissionSettingsDto, _$identity);

  /// Serializes this PermissionSettingsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PermissionSettingsDto&&(identical(other.defaultMode, defaultMode) || other.defaultMode == defaultMode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,defaultMode);

@override
String toString() {
  return 'PermissionSettingsDto(defaultMode: $defaultMode)';
}


}

/// @nodoc
abstract mixin class $PermissionSettingsDtoCopyWith<$Res>  {
  factory $PermissionSettingsDtoCopyWith(PermissionSettingsDto value, $Res Function(PermissionSettingsDto) _then) = _$PermissionSettingsDtoCopyWithImpl;
@useResult
$Res call({
 PermissionMode defaultMode
});




}
/// @nodoc
class _$PermissionSettingsDtoCopyWithImpl<$Res>
    implements $PermissionSettingsDtoCopyWith<$Res> {
  _$PermissionSettingsDtoCopyWithImpl(this._self, this._then);

  final PermissionSettingsDto _self;
  final $Res Function(PermissionSettingsDto) _then;

/// Create a copy of PermissionSettingsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? defaultMode = null,}) {
  return _then(PermissionSettingsDto(
defaultMode: null == defaultMode ? _self.defaultMode : defaultMode // ignore: cast_nullable_to_non_nullable
as PermissionMode,
  ));
}

}


/// Adds pattern-matching-related methods to [PermissionSettingsDto].
extension PermissionSettingsDtoPatterns on PermissionSettingsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PermissionSettingsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PermissionSettingsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PermissionSettingsDto value)  $default,){
final _that = this;
switch (_that) {
case _PermissionSettingsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PermissionSettingsDto value)?  $default,){
final _that = this;
switch (_that) {
case _PermissionSettingsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PermissionMode defaultMode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PermissionSettingsDto() when $default != null:
return $default(_that.defaultMode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PermissionMode defaultMode)  $default,) {final _that = this;
switch (_that) {
case _PermissionSettingsDto():
return $default(_that.defaultMode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PermissionMode defaultMode)?  $default,) {final _that = this;
switch (_that) {
case _PermissionSettingsDto() when $default != null:
return $default(_that.defaultMode);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PermissionSettingsDto implements PermissionSettingsDto {
  const _PermissionSettingsDto({this.defaultMode = PermissionMode.ask});
  factory _PermissionSettingsDto.fromJson(Map<String, dynamic> json) => _$PermissionSettingsDtoFromJson(json);

@override@JsonKey() final  PermissionMode defaultMode;

/// Create a copy of PermissionSettingsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PermissionSettingsDtoCopyWith<_PermissionSettingsDto> get copyWith => __$PermissionSettingsDtoCopyWithImpl<_PermissionSettingsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PermissionSettingsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PermissionSettingsDto&&(identical(other.defaultMode, defaultMode) || other.defaultMode == defaultMode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,defaultMode);

@override
String toString() {
  return 'PermissionSettingsDto(defaultMode: $defaultMode)';
}


}

/// @nodoc
abstract mixin class _$PermissionSettingsDtoCopyWith<$Res> implements $PermissionSettingsDtoCopyWith<$Res> {
  factory _$PermissionSettingsDtoCopyWith(_PermissionSettingsDto value, $Res Function(_PermissionSettingsDto) _then) = __$PermissionSettingsDtoCopyWithImpl;
@override @useResult
$Res call({
 PermissionMode defaultMode
});




}
/// @nodoc
class __$PermissionSettingsDtoCopyWithImpl<$Res>
    implements _$PermissionSettingsDtoCopyWith<$Res> {
  __$PermissionSettingsDtoCopyWithImpl(this._self, this._then);

  final _PermissionSettingsDto _self;
  final $Res Function(_PermissionSettingsDto) _then;

/// Create a copy of PermissionSettingsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? defaultMode = null,}) {
  return _then(_PermissionSettingsDto(
defaultMode: null == defaultMode ? _self.defaultMode : defaultMode // ignore: cast_nullable_to_non_nullable
as PermissionMode,
  ));
}


}


/// @nodoc
mixin _$DaemonModelSettingsDto {

 ModelSelectionDto? get defaultModel;
/// Create a copy of DaemonModelSettingsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaemonModelSettingsDtoCopyWith<DaemonModelSettingsDto> get copyWith => _$DaemonModelSettingsDtoCopyWithImpl<DaemonModelSettingsDto>(this as DaemonModelSettingsDto, _$identity);

  /// Serializes this DaemonModelSettingsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaemonModelSettingsDto&&(identical(other.defaultModel, defaultModel) || other.defaultModel == defaultModel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,defaultModel);

@override
String toString() {
  return 'DaemonModelSettingsDto(defaultModel: $defaultModel)';
}


}

/// @nodoc
abstract mixin class $DaemonModelSettingsDtoCopyWith<$Res>  {
  factory $DaemonModelSettingsDtoCopyWith(DaemonModelSettingsDto value, $Res Function(DaemonModelSettingsDto) _then) = _$DaemonModelSettingsDtoCopyWithImpl;
@useResult
$Res call({
 ModelSelectionDto? defaultModel
});


$ModelSelectionDtoCopyWith<$Res>? get defaultModel;

}
/// @nodoc
class _$DaemonModelSettingsDtoCopyWithImpl<$Res>
    implements $DaemonModelSettingsDtoCopyWith<$Res> {
  _$DaemonModelSettingsDtoCopyWithImpl(this._self, this._then);

  final DaemonModelSettingsDto _self;
  final $Res Function(DaemonModelSettingsDto) _then;

/// Create a copy of DaemonModelSettingsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? defaultModel = freezed,}) {
  return _then(DaemonModelSettingsDto(
defaultModel: freezed == defaultModel ? _self.defaultModel : defaultModel // ignore: cast_nullable_to_non_nullable
as ModelSelectionDto?,
  ));
}
/// Create a copy of DaemonModelSettingsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModelSelectionDtoCopyWith<$Res>? get defaultModel {
    if (_self.defaultModel == null) {
    return null;
  }

  return $ModelSelectionDtoCopyWith<$Res>(_self.defaultModel!, (value) {
    return _then(_self.copyWith(defaultModel: value));
  });
}
}


/// Adds pattern-matching-related methods to [DaemonModelSettingsDto].
extension DaemonModelSettingsDtoPatterns on DaemonModelSettingsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DaemonModelSettingsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DaemonModelSettingsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DaemonModelSettingsDto value)  $default,){
final _that = this;
switch (_that) {
case _DaemonModelSettingsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DaemonModelSettingsDto value)?  $default,){
final _that = this;
switch (_that) {
case _DaemonModelSettingsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ModelSelectionDto? defaultModel)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DaemonModelSettingsDto() when $default != null:
return $default(_that.defaultModel);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ModelSelectionDto? defaultModel)  $default,) {final _that = this;
switch (_that) {
case _DaemonModelSettingsDto():
return $default(_that.defaultModel);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ModelSelectionDto? defaultModel)?  $default,) {final _that = this;
switch (_that) {
case _DaemonModelSettingsDto() when $default != null:
return $default(_that.defaultModel);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DaemonModelSettingsDto implements DaemonModelSettingsDto {
  const _DaemonModelSettingsDto({this.defaultModel});
  factory _DaemonModelSettingsDto.fromJson(Map<String, dynamic> json) => _$DaemonModelSettingsDtoFromJson(json);

@override final  ModelSelectionDto? defaultModel;

/// Create a copy of DaemonModelSettingsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DaemonModelSettingsDtoCopyWith<_DaemonModelSettingsDto> get copyWith => __$DaemonModelSettingsDtoCopyWithImpl<_DaemonModelSettingsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DaemonModelSettingsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DaemonModelSettingsDto&&(identical(other.defaultModel, defaultModel) || other.defaultModel == defaultModel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,defaultModel);

@override
String toString() {
  return 'DaemonModelSettingsDto(defaultModel: $defaultModel)';
}


}

/// @nodoc
abstract mixin class _$DaemonModelSettingsDtoCopyWith<$Res> implements $DaemonModelSettingsDtoCopyWith<$Res> {
  factory _$DaemonModelSettingsDtoCopyWith(_DaemonModelSettingsDto value, $Res Function(_DaemonModelSettingsDto) _then) = __$DaemonModelSettingsDtoCopyWithImpl;
@override @useResult
$Res call({
 ModelSelectionDto? defaultModel
});


@override $ModelSelectionDtoCopyWith<$Res>? get defaultModel;

}
/// @nodoc
class __$DaemonModelSettingsDtoCopyWithImpl<$Res>
    implements _$DaemonModelSettingsDtoCopyWith<$Res> {
  __$DaemonModelSettingsDtoCopyWithImpl(this._self, this._then);

  final _DaemonModelSettingsDto _self;
  final $Res Function(_DaemonModelSettingsDto) _then;

/// Create a copy of DaemonModelSettingsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? defaultModel = freezed,}) {
  return _then(_DaemonModelSettingsDto(
defaultModel: freezed == defaultModel ? _self.defaultModel : defaultModel // ignore: cast_nullable_to_non_nullable
as ModelSelectionDto?,
  ));
}

/// Create a copy of DaemonModelSettingsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModelSelectionDtoCopyWith<$Res>? get defaultModel {
    if (_self.defaultModel == null) {
    return null;
  }

  return $ModelSelectionDtoCopyWith<$Res>(_self.defaultModel!, (value) {
    return _then(_self.copyWith(defaultModel: value));
  });
}
}


/// @nodoc
mixin _$SetDaemonDefaultModelParamsDto {

 ModelSelectionDto get model;
/// Create a copy of SetDaemonDefaultModelParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SetDaemonDefaultModelParamsDtoCopyWith<SetDaemonDefaultModelParamsDto> get copyWith => _$SetDaemonDefaultModelParamsDtoCopyWithImpl<SetDaemonDefaultModelParamsDto>(this as SetDaemonDefaultModelParamsDto, _$identity);

  /// Serializes this SetDaemonDefaultModelParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SetDaemonDefaultModelParamsDto&&(identical(other.model, model) || other.model == model));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,model);

@override
String toString() {
  return 'SetDaemonDefaultModelParamsDto(model: $model)';
}


}

/// @nodoc
abstract mixin class $SetDaemonDefaultModelParamsDtoCopyWith<$Res>  {
  factory $SetDaemonDefaultModelParamsDtoCopyWith(SetDaemonDefaultModelParamsDto value, $Res Function(SetDaemonDefaultModelParamsDto) _then) = _$SetDaemonDefaultModelParamsDtoCopyWithImpl;
@useResult
$Res call({
 ModelSelectionDto model
});


$ModelSelectionDtoCopyWith<$Res> get model;

}
/// @nodoc
class _$SetDaemonDefaultModelParamsDtoCopyWithImpl<$Res>
    implements $SetDaemonDefaultModelParamsDtoCopyWith<$Res> {
  _$SetDaemonDefaultModelParamsDtoCopyWithImpl(this._self, this._then);

  final SetDaemonDefaultModelParamsDto _self;
  final $Res Function(SetDaemonDefaultModelParamsDto) _then;

/// Create a copy of SetDaemonDefaultModelParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? model = null,}) {
  return _then(SetDaemonDefaultModelParamsDto(
model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as ModelSelectionDto,
  ));
}
/// Create a copy of SetDaemonDefaultModelParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModelSelectionDtoCopyWith<$Res> get model {

  return $ModelSelectionDtoCopyWith<$Res>(_self.model, (value) {
    return _then(_self.copyWith(model: value));
  });
}
}


/// Adds pattern-matching-related methods to [SetDaemonDefaultModelParamsDto].
extension SetDaemonDefaultModelParamsDtoPatterns on SetDaemonDefaultModelParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SetDaemonDefaultModelParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SetDaemonDefaultModelParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SetDaemonDefaultModelParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _SetDaemonDefaultModelParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SetDaemonDefaultModelParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _SetDaemonDefaultModelParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ModelSelectionDto model)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SetDaemonDefaultModelParamsDto() when $default != null:
return $default(_that.model);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ModelSelectionDto model)  $default,) {final _that = this;
switch (_that) {
case _SetDaemonDefaultModelParamsDto():
return $default(_that.model);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ModelSelectionDto model)?  $default,) {final _that = this;
switch (_that) {
case _SetDaemonDefaultModelParamsDto() when $default != null:
return $default(_that.model);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SetDaemonDefaultModelParamsDto implements SetDaemonDefaultModelParamsDto {
  const _SetDaemonDefaultModelParamsDto({required this.model});
  factory _SetDaemonDefaultModelParamsDto.fromJson(Map<String, dynamic> json) => _$SetDaemonDefaultModelParamsDtoFromJson(json);

@override final  ModelSelectionDto model;

/// Create a copy of SetDaemonDefaultModelParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SetDaemonDefaultModelParamsDtoCopyWith<_SetDaemonDefaultModelParamsDto> get copyWith => __$SetDaemonDefaultModelParamsDtoCopyWithImpl<_SetDaemonDefaultModelParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SetDaemonDefaultModelParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SetDaemonDefaultModelParamsDto&&(identical(other.model, model) || other.model == model));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,model);

@override
String toString() {
  return 'SetDaemonDefaultModelParamsDto(model: $model)';
}


}

/// @nodoc
abstract mixin class _$SetDaemonDefaultModelParamsDtoCopyWith<$Res> implements $SetDaemonDefaultModelParamsDtoCopyWith<$Res> {
  factory _$SetDaemonDefaultModelParamsDtoCopyWith(_SetDaemonDefaultModelParamsDto value, $Res Function(_SetDaemonDefaultModelParamsDto) _then) = __$SetDaemonDefaultModelParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 ModelSelectionDto model
});


@override $ModelSelectionDtoCopyWith<$Res> get model;

}
/// @nodoc
class __$SetDaemonDefaultModelParamsDtoCopyWithImpl<$Res>
    implements _$SetDaemonDefaultModelParamsDtoCopyWith<$Res> {
  __$SetDaemonDefaultModelParamsDtoCopyWithImpl(this._self, this._then);

  final _SetDaemonDefaultModelParamsDto _self;
  final $Res Function(_SetDaemonDefaultModelParamsDto) _then;

/// Create a copy of SetDaemonDefaultModelParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? model = null,}) {
  return _then(_SetDaemonDefaultModelParamsDto(
model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as ModelSelectionDto,
  ));
}

/// Create a copy of SetDaemonDefaultModelParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModelSelectionDtoCopyWith<$Res> get model {

  return $ModelSelectionDtoCopyWith<$Res>(_self.model, (value) {
    return _then(_self.copyWith(model: value));
  });
}
}


/// @nodoc
mixin _$AgentDefinitionListResultDto {

 List<AgentDefinitionDto> get definitions;
/// Create a copy of AgentDefinitionListResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentDefinitionListResultDtoCopyWith<AgentDefinitionListResultDto> get copyWith => _$AgentDefinitionListResultDtoCopyWithImpl<AgentDefinitionListResultDto>(this as AgentDefinitionListResultDto, _$identity);

  /// Serializes this AgentDefinitionListResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentDefinitionListResultDto&&const DeepCollectionEquality().equals(other.definitions, definitions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(definitions));

@override
String toString() {
  return 'AgentDefinitionListResultDto(definitions: $definitions)';
}


}

/// @nodoc
abstract mixin class $AgentDefinitionListResultDtoCopyWith<$Res>  {
  factory $AgentDefinitionListResultDtoCopyWith(AgentDefinitionListResultDto value, $Res Function(AgentDefinitionListResultDto) _then) = _$AgentDefinitionListResultDtoCopyWithImpl;
@useResult
$Res call({
 List<AgentDefinitionDto> definitions
});




}
/// @nodoc
class _$AgentDefinitionListResultDtoCopyWithImpl<$Res>
    implements $AgentDefinitionListResultDtoCopyWith<$Res> {
  _$AgentDefinitionListResultDtoCopyWithImpl(this._self, this._then);

  final AgentDefinitionListResultDto _self;
  final $Res Function(AgentDefinitionListResultDto) _then;

/// Create a copy of AgentDefinitionListResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? definitions = null,}) {
  return _then(AgentDefinitionListResultDto(
definitions: null == definitions ? _self.definitions : definitions // ignore: cast_nullable_to_non_nullable
as List<AgentDefinitionDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentDefinitionListResultDto].
extension AgentDefinitionListResultDtoPatterns on AgentDefinitionListResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentDefinitionListResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentDefinitionListResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentDefinitionListResultDto value)  $default,){
final _that = this;
switch (_that) {
case _AgentDefinitionListResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentDefinitionListResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _AgentDefinitionListResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<AgentDefinitionDto> definitions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentDefinitionListResultDto() when $default != null:
return $default(_that.definitions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<AgentDefinitionDto> definitions)  $default,) {final _that = this;
switch (_that) {
case _AgentDefinitionListResultDto():
return $default(_that.definitions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<AgentDefinitionDto> definitions)?  $default,) {final _that = this;
switch (_that) {
case _AgentDefinitionListResultDto() when $default != null:
return $default(_that.definitions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentDefinitionListResultDto implements AgentDefinitionListResultDto {
  const _AgentDefinitionListResultDto({required  List<AgentDefinitionDto> definitions}): _definitions = definitions;
  factory _AgentDefinitionListResultDto.fromJson(Map<String, dynamic> json) => _$AgentDefinitionListResultDtoFromJson(json);

 final  List<AgentDefinitionDto> _definitions;
@override List<AgentDefinitionDto> get definitions {
  if (_definitions is EqualUnmodifiableListView) return _definitions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_definitions);
}


/// Create a copy of AgentDefinitionListResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentDefinitionListResultDtoCopyWith<_AgentDefinitionListResultDto> get copyWith => __$AgentDefinitionListResultDtoCopyWithImpl<_AgentDefinitionListResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentDefinitionListResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentDefinitionListResultDto&&const DeepCollectionEquality().equals(other._definitions, _definitions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_definitions));

@override
String toString() {
  return 'AgentDefinitionListResultDto(definitions: $definitions)';
}


}

/// @nodoc
abstract mixin class _$AgentDefinitionListResultDtoCopyWith<$Res> implements $AgentDefinitionListResultDtoCopyWith<$Res> {
  factory _$AgentDefinitionListResultDtoCopyWith(_AgentDefinitionListResultDto value, $Res Function(_AgentDefinitionListResultDto) _then) = __$AgentDefinitionListResultDtoCopyWithImpl;
@override @useResult
$Res call({
 List<AgentDefinitionDto> definitions
});




}
/// @nodoc
class __$AgentDefinitionListResultDtoCopyWithImpl<$Res>
    implements _$AgentDefinitionListResultDtoCopyWith<$Res> {
  __$AgentDefinitionListResultDtoCopyWithImpl(this._self, this._then);

  final _AgentDefinitionListResultDto _self;
  final $Res Function(_AgentDefinitionListResultDto) _then;

/// Create a copy of AgentDefinitionListResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? definitions = null,}) {
  return _then(_AgentDefinitionListResultDto(
definitions: null == definitions ? _self._definitions : definitions // ignore: cast_nullable_to_non_nullable
as List<AgentDefinitionDto>,
  ));
}


}


/// @nodoc
mixin _$AgentDefinitionResultDto {

 AgentDefinitionDto get definition;
/// Create a copy of AgentDefinitionResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentDefinitionResultDtoCopyWith<AgentDefinitionResultDto> get copyWith => _$AgentDefinitionResultDtoCopyWithImpl<AgentDefinitionResultDto>(this as AgentDefinitionResultDto, _$identity);

  /// Serializes this AgentDefinitionResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentDefinitionResultDto&&(identical(other.definition, definition) || other.definition == definition));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,definition);

@override
String toString() {
  return 'AgentDefinitionResultDto(definition: $definition)';
}


}

/// @nodoc
abstract mixin class $AgentDefinitionResultDtoCopyWith<$Res>  {
  factory $AgentDefinitionResultDtoCopyWith(AgentDefinitionResultDto value, $Res Function(AgentDefinitionResultDto) _then) = _$AgentDefinitionResultDtoCopyWithImpl;
@useResult
$Res call({
 AgentDefinitionDto definition
});


$AgentDefinitionDtoCopyWith<$Res> get definition;

}
/// @nodoc
class _$AgentDefinitionResultDtoCopyWithImpl<$Res>
    implements $AgentDefinitionResultDtoCopyWith<$Res> {
  _$AgentDefinitionResultDtoCopyWithImpl(this._self, this._then);

  final AgentDefinitionResultDto _self;
  final $Res Function(AgentDefinitionResultDto) _then;

/// Create a copy of AgentDefinitionResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? definition = null,}) {
  return _then(AgentDefinitionResultDto(
definition: null == definition ? _self.definition : definition // ignore: cast_nullable_to_non_nullable
as AgentDefinitionDto,
  ));
}
/// Create a copy of AgentDefinitionResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentDefinitionDtoCopyWith<$Res> get definition {

  return $AgentDefinitionDtoCopyWith<$Res>(_self.definition, (value) {
    return _then(_self.copyWith(definition: value));
  });
}
}


/// Adds pattern-matching-related methods to [AgentDefinitionResultDto].
extension AgentDefinitionResultDtoPatterns on AgentDefinitionResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentDefinitionResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentDefinitionResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentDefinitionResultDto value)  $default,){
final _that = this;
switch (_that) {
case _AgentDefinitionResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentDefinitionResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _AgentDefinitionResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AgentDefinitionDto definition)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentDefinitionResultDto() when $default != null:
return $default(_that.definition);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AgentDefinitionDto definition)  $default,) {final _that = this;
switch (_that) {
case _AgentDefinitionResultDto():
return $default(_that.definition);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AgentDefinitionDto definition)?  $default,) {final _that = this;
switch (_that) {
case _AgentDefinitionResultDto() when $default != null:
return $default(_that.definition);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentDefinitionResultDto implements AgentDefinitionResultDto {
  const _AgentDefinitionResultDto({required this.definition});
  factory _AgentDefinitionResultDto.fromJson(Map<String, dynamic> json) => _$AgentDefinitionResultDtoFromJson(json);

@override final  AgentDefinitionDto definition;

/// Create a copy of AgentDefinitionResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentDefinitionResultDtoCopyWith<_AgentDefinitionResultDto> get copyWith => __$AgentDefinitionResultDtoCopyWithImpl<_AgentDefinitionResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentDefinitionResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentDefinitionResultDto&&(identical(other.definition, definition) || other.definition == definition));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,definition);

@override
String toString() {
  return 'AgentDefinitionResultDto(definition: $definition)';
}


}

/// @nodoc
abstract mixin class _$AgentDefinitionResultDtoCopyWith<$Res> implements $AgentDefinitionResultDtoCopyWith<$Res> {
  factory _$AgentDefinitionResultDtoCopyWith(_AgentDefinitionResultDto value, $Res Function(_AgentDefinitionResultDto) _then) = __$AgentDefinitionResultDtoCopyWithImpl;
@override @useResult
$Res call({
 AgentDefinitionDto definition
});


@override $AgentDefinitionDtoCopyWith<$Res> get definition;

}
/// @nodoc
class __$AgentDefinitionResultDtoCopyWithImpl<$Res>
    implements _$AgentDefinitionResultDtoCopyWith<$Res> {
  __$AgentDefinitionResultDtoCopyWithImpl(this._self, this._then);

  final _AgentDefinitionResultDto _self;
  final $Res Function(_AgentDefinitionResultDto) _then;

/// Create a copy of AgentDefinitionResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? definition = null,}) {
  return _then(_AgentDefinitionResultDto(
definition: null == definition ? _self.definition : definition // ignore: cast_nullable_to_non_nullable
as AgentDefinitionDto,
  ));
}

/// Create a copy of AgentDefinitionResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentDefinitionDtoCopyWith<$Res> get definition {

  return $AgentDefinitionDtoCopyWith<$Res>(_self.definition, (value) {
    return _then(_self.copyWith(definition: value));
  });
}
}


/// @nodoc
mixin _$PluginListResultDto {

 List<PluginDescriptorDto> get plugins;
/// Create a copy of PluginListResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginListResultDtoCopyWith<PluginListResultDto> get copyWith => _$PluginListResultDtoCopyWithImpl<PluginListResultDto>(this as PluginListResultDto, _$identity);

  /// Serializes this PluginListResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginListResultDto&&const DeepCollectionEquality().equals(other.plugins, plugins));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(plugins));

@override
String toString() {
  return 'PluginListResultDto(plugins: $plugins)';
}


}

/// @nodoc
abstract mixin class $PluginListResultDtoCopyWith<$Res>  {
  factory $PluginListResultDtoCopyWith(PluginListResultDto value, $Res Function(PluginListResultDto) _then) = _$PluginListResultDtoCopyWithImpl;
@useResult
$Res call({
 List<PluginDescriptorDto> plugins
});




}
/// @nodoc
class _$PluginListResultDtoCopyWithImpl<$Res>
    implements $PluginListResultDtoCopyWith<$Res> {
  _$PluginListResultDtoCopyWithImpl(this._self, this._then);

  final PluginListResultDto _self;
  final $Res Function(PluginListResultDto) _then;

/// Create a copy of PluginListResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? plugins = null,}) {
  return _then(PluginListResultDto(
plugins: null == plugins ? _self.plugins : plugins // ignore: cast_nullable_to_non_nullable
as List<PluginDescriptorDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [PluginListResultDto].
extension PluginListResultDtoPatterns on PluginListResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginListResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginListResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginListResultDto value)  $default,){
final _that = this;
switch (_that) {
case _PluginListResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginListResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _PluginListResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<PluginDescriptorDto> plugins)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginListResultDto() when $default != null:
return $default(_that.plugins);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<PluginDescriptorDto> plugins)  $default,) {final _that = this;
switch (_that) {
case _PluginListResultDto():
return $default(_that.plugins);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<PluginDescriptorDto> plugins)?  $default,) {final _that = this;
switch (_that) {
case _PluginListResultDto() when $default != null:
return $default(_that.plugins);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PluginListResultDto implements PluginListResultDto {
  const _PluginListResultDto({required  List<PluginDescriptorDto> plugins}): _plugins = plugins;
  factory _PluginListResultDto.fromJson(Map<String, dynamic> json) => _$PluginListResultDtoFromJson(json);

 final  List<PluginDescriptorDto> _plugins;
@override List<PluginDescriptorDto> get plugins {
  if (_plugins is EqualUnmodifiableListView) return _plugins;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_plugins);
}


/// Create a copy of PluginListResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginListResultDtoCopyWith<_PluginListResultDto> get copyWith => __$PluginListResultDtoCopyWithImpl<_PluginListResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginListResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginListResultDto&&const DeepCollectionEquality().equals(other._plugins, _plugins));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_plugins));

@override
String toString() {
  return 'PluginListResultDto(plugins: $plugins)';
}


}

/// @nodoc
abstract mixin class _$PluginListResultDtoCopyWith<$Res> implements $PluginListResultDtoCopyWith<$Res> {
  factory _$PluginListResultDtoCopyWith(_PluginListResultDto value, $Res Function(_PluginListResultDto) _then) = __$PluginListResultDtoCopyWithImpl;
@override @useResult
$Res call({
 List<PluginDescriptorDto> plugins
});




}
/// @nodoc
class __$PluginListResultDtoCopyWithImpl<$Res>
    implements _$PluginListResultDtoCopyWith<$Res> {
  __$PluginListResultDtoCopyWithImpl(this._self, this._then);

  final _PluginListResultDto _self;
  final $Res Function(_PluginListResultDto) _then;

/// Create a copy of PluginListResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? plugins = null,}) {
  return _then(_PluginListResultDto(
plugins: null == plugins ? _self._plugins : plugins // ignore: cast_nullable_to_non_nullable
as List<PluginDescriptorDto>,
  ));
}


}


/// @nodoc
mixin _$PluginResultDto {

 PluginDescriptorDto get plugin;
/// Create a copy of PluginResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginResultDtoCopyWith<PluginResultDto> get copyWith => _$PluginResultDtoCopyWithImpl<PluginResultDto>(this as PluginResultDto, _$identity);

  /// Serializes this PluginResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginResultDto&&(identical(other.plugin, plugin) || other.plugin == plugin));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,plugin);

@override
String toString() {
  return 'PluginResultDto(plugin: $plugin)';
}


}

/// @nodoc
abstract mixin class $PluginResultDtoCopyWith<$Res>  {
  factory $PluginResultDtoCopyWith(PluginResultDto value, $Res Function(PluginResultDto) _then) = _$PluginResultDtoCopyWithImpl;
@useResult
$Res call({
 PluginDescriptorDto plugin
});


$PluginDescriptorDtoCopyWith<$Res> get plugin;

}
/// @nodoc
class _$PluginResultDtoCopyWithImpl<$Res>
    implements $PluginResultDtoCopyWith<$Res> {
  _$PluginResultDtoCopyWithImpl(this._self, this._then);

  final PluginResultDto _self;
  final $Res Function(PluginResultDto) _then;

/// Create a copy of PluginResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? plugin = null,}) {
  return _then(PluginResultDto(
plugin: null == plugin ? _self.plugin : plugin // ignore: cast_nullable_to_non_nullable
as PluginDescriptorDto,
  ));
}
/// Create a copy of PluginResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginDescriptorDtoCopyWith<$Res> get plugin {

  return $PluginDescriptorDtoCopyWith<$Res>(_self.plugin, (value) {
    return _then(_self.copyWith(plugin: value));
  });
}
}


/// Adds pattern-matching-related methods to [PluginResultDto].
extension PluginResultDtoPatterns on PluginResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginResultDto value)  $default,){
final _that = this;
switch (_that) {
case _PluginResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _PluginResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PluginDescriptorDto plugin)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginResultDto() when $default != null:
return $default(_that.plugin);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PluginDescriptorDto plugin)  $default,) {final _that = this;
switch (_that) {
case _PluginResultDto():
return $default(_that.plugin);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PluginDescriptorDto plugin)?  $default,) {final _that = this;
switch (_that) {
case _PluginResultDto() when $default != null:
return $default(_that.plugin);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PluginResultDto implements PluginResultDto {
  const _PluginResultDto({required this.plugin});
  factory _PluginResultDto.fromJson(Map<String, dynamic> json) => _$PluginResultDtoFromJson(json);

@override final  PluginDescriptorDto plugin;

/// Create a copy of PluginResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginResultDtoCopyWith<_PluginResultDto> get copyWith => __$PluginResultDtoCopyWithImpl<_PluginResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginResultDto&&(identical(other.plugin, plugin) || other.plugin == plugin));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,plugin);

@override
String toString() {
  return 'PluginResultDto(plugin: $plugin)';
}


}

/// @nodoc
abstract mixin class _$PluginResultDtoCopyWith<$Res> implements $PluginResultDtoCopyWith<$Res> {
  factory _$PluginResultDtoCopyWith(_PluginResultDto value, $Res Function(_PluginResultDto) _then) = __$PluginResultDtoCopyWithImpl;
@override @useResult
$Res call({
 PluginDescriptorDto plugin
});


@override $PluginDescriptorDtoCopyWith<$Res> get plugin;

}
/// @nodoc
class __$PluginResultDtoCopyWithImpl<$Res>
    implements _$PluginResultDtoCopyWith<$Res> {
  __$PluginResultDtoCopyWithImpl(this._self, this._then);

  final _PluginResultDto _self;
  final $Res Function(_PluginResultDto) _then;

/// Create a copy of PluginResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? plugin = null,}) {
  return _then(_PluginResultDto(
plugin: null == plugin ? _self.plugin : plugin // ignore: cast_nullable_to_non_nullable
as PluginDescriptorDto,
  ));
}

/// Create a copy of PluginResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginDescriptorDtoCopyWith<$Res> get plugin {

  return $PluginDescriptorDtoCopyWith<$Res>(_self.plugin, (value) {
    return _then(_self.copyWith(plugin: value));
  });
}
}


/// @nodoc
mixin _$PluginAuthoringEnvironmentResultDto {

 PluginAuthoringEnvironmentDto get environment;
/// Create a copy of PluginAuthoringEnvironmentResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginAuthoringEnvironmentResultDtoCopyWith<PluginAuthoringEnvironmentResultDto> get copyWith => _$PluginAuthoringEnvironmentResultDtoCopyWithImpl<PluginAuthoringEnvironmentResultDto>(this as PluginAuthoringEnvironmentResultDto, _$identity);

  /// Serializes this PluginAuthoringEnvironmentResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginAuthoringEnvironmentResultDto&&(identical(other.environment, environment) || other.environment == environment));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,environment);

@override
String toString() {
  return 'PluginAuthoringEnvironmentResultDto(environment: $environment)';
}


}

/// @nodoc
abstract mixin class $PluginAuthoringEnvironmentResultDtoCopyWith<$Res>  {
  factory $PluginAuthoringEnvironmentResultDtoCopyWith(PluginAuthoringEnvironmentResultDto value, $Res Function(PluginAuthoringEnvironmentResultDto) _then) = _$PluginAuthoringEnvironmentResultDtoCopyWithImpl;
@useResult
$Res call({
 PluginAuthoringEnvironmentDto environment
});


$PluginAuthoringEnvironmentDtoCopyWith<$Res> get environment;

}
/// @nodoc
class _$PluginAuthoringEnvironmentResultDtoCopyWithImpl<$Res>
    implements $PluginAuthoringEnvironmentResultDtoCopyWith<$Res> {
  _$PluginAuthoringEnvironmentResultDtoCopyWithImpl(this._self, this._then);

  final PluginAuthoringEnvironmentResultDto _self;
  final $Res Function(PluginAuthoringEnvironmentResultDto) _then;

/// Create a copy of PluginAuthoringEnvironmentResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? environment = null,}) {
  return _then(PluginAuthoringEnvironmentResultDto(
environment: null == environment ? _self.environment : environment // ignore: cast_nullable_to_non_nullable
as PluginAuthoringEnvironmentDto,
  ));
}
/// Create a copy of PluginAuthoringEnvironmentResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginAuthoringEnvironmentDtoCopyWith<$Res> get environment {

  return $PluginAuthoringEnvironmentDtoCopyWith<$Res>(_self.environment, (value) {
    return _then(_self.copyWith(environment: value));
  });
}
}


/// Adds pattern-matching-related methods to [PluginAuthoringEnvironmentResultDto].
extension PluginAuthoringEnvironmentResultDtoPatterns on PluginAuthoringEnvironmentResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginAuthoringEnvironmentResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginAuthoringEnvironmentResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginAuthoringEnvironmentResultDto value)  $default,){
final _that = this;
switch (_that) {
case _PluginAuthoringEnvironmentResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginAuthoringEnvironmentResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _PluginAuthoringEnvironmentResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PluginAuthoringEnvironmentDto environment)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginAuthoringEnvironmentResultDto() when $default != null:
return $default(_that.environment);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PluginAuthoringEnvironmentDto environment)  $default,) {final _that = this;
switch (_that) {
case _PluginAuthoringEnvironmentResultDto():
return $default(_that.environment);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PluginAuthoringEnvironmentDto environment)?  $default,) {final _that = this;
switch (_that) {
case _PluginAuthoringEnvironmentResultDto() when $default != null:
return $default(_that.environment);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PluginAuthoringEnvironmentResultDto implements PluginAuthoringEnvironmentResultDto {
  const _PluginAuthoringEnvironmentResultDto({required this.environment});
  factory _PluginAuthoringEnvironmentResultDto.fromJson(Map<String, dynamic> json) => _$PluginAuthoringEnvironmentResultDtoFromJson(json);

@override final  PluginAuthoringEnvironmentDto environment;

/// Create a copy of PluginAuthoringEnvironmentResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginAuthoringEnvironmentResultDtoCopyWith<_PluginAuthoringEnvironmentResultDto> get copyWith => __$PluginAuthoringEnvironmentResultDtoCopyWithImpl<_PluginAuthoringEnvironmentResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginAuthoringEnvironmentResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginAuthoringEnvironmentResultDto&&(identical(other.environment, environment) || other.environment == environment));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,environment);

@override
String toString() {
  return 'PluginAuthoringEnvironmentResultDto(environment: $environment)';
}


}

/// @nodoc
abstract mixin class _$PluginAuthoringEnvironmentResultDtoCopyWith<$Res> implements $PluginAuthoringEnvironmentResultDtoCopyWith<$Res> {
  factory _$PluginAuthoringEnvironmentResultDtoCopyWith(_PluginAuthoringEnvironmentResultDto value, $Res Function(_PluginAuthoringEnvironmentResultDto) _then) = __$PluginAuthoringEnvironmentResultDtoCopyWithImpl;
@override @useResult
$Res call({
 PluginAuthoringEnvironmentDto environment
});


@override $PluginAuthoringEnvironmentDtoCopyWith<$Res> get environment;

}
/// @nodoc
class __$PluginAuthoringEnvironmentResultDtoCopyWithImpl<$Res>
    implements _$PluginAuthoringEnvironmentResultDtoCopyWith<$Res> {
  __$PluginAuthoringEnvironmentResultDtoCopyWithImpl(this._self, this._then);

  final _PluginAuthoringEnvironmentResultDto _self;
  final $Res Function(_PluginAuthoringEnvironmentResultDto) _then;

/// Create a copy of PluginAuthoringEnvironmentResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? environment = null,}) {
  return _then(_PluginAuthoringEnvironmentResultDto(
environment: null == environment ? _self.environment : environment // ignore: cast_nullable_to_non_nullable
as PluginAuthoringEnvironmentDto,
  ));
}

/// Create a copy of PluginAuthoringEnvironmentResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginAuthoringEnvironmentDtoCopyWith<$Res> get environment {

  return $PluginAuthoringEnvironmentDtoCopyWith<$Res>(_self.environment, (value) {
    return _then(_self.copyWith(environment: value));
  });
}
}


/// @nodoc
mixin _$PluginGrantListResultDto {

 List<AgentPluginGrantDto> get grants;
/// Create a copy of PluginGrantListResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginGrantListResultDtoCopyWith<PluginGrantListResultDto> get copyWith => _$PluginGrantListResultDtoCopyWithImpl<PluginGrantListResultDto>(this as PluginGrantListResultDto, _$identity);

  /// Serializes this PluginGrantListResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginGrantListResultDto&&const DeepCollectionEquality().equals(other.grants, grants));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(grants));

@override
String toString() {
  return 'PluginGrantListResultDto(grants: $grants)';
}


}

/// @nodoc
abstract mixin class $PluginGrantListResultDtoCopyWith<$Res>  {
  factory $PluginGrantListResultDtoCopyWith(PluginGrantListResultDto value, $Res Function(PluginGrantListResultDto) _then) = _$PluginGrantListResultDtoCopyWithImpl;
@useResult
$Res call({
 List<AgentPluginGrantDto> grants
});




}
/// @nodoc
class _$PluginGrantListResultDtoCopyWithImpl<$Res>
    implements $PluginGrantListResultDtoCopyWith<$Res> {
  _$PluginGrantListResultDtoCopyWithImpl(this._self, this._then);

  final PluginGrantListResultDto _self;
  final $Res Function(PluginGrantListResultDto) _then;

/// Create a copy of PluginGrantListResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? grants = null,}) {
  return _then(PluginGrantListResultDto(
grants: null == grants ? _self.grants : grants // ignore: cast_nullable_to_non_nullable
as List<AgentPluginGrantDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [PluginGrantListResultDto].
extension PluginGrantListResultDtoPatterns on PluginGrantListResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginGrantListResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginGrantListResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginGrantListResultDto value)  $default,){
final _that = this;
switch (_that) {
case _PluginGrantListResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginGrantListResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _PluginGrantListResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<AgentPluginGrantDto> grants)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginGrantListResultDto() when $default != null:
return $default(_that.grants);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<AgentPluginGrantDto> grants)  $default,) {final _that = this;
switch (_that) {
case _PluginGrantListResultDto():
return $default(_that.grants);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<AgentPluginGrantDto> grants)?  $default,) {final _that = this;
switch (_that) {
case _PluginGrantListResultDto() when $default != null:
return $default(_that.grants);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PluginGrantListResultDto implements PluginGrantListResultDto {
  const _PluginGrantListResultDto({required  List<AgentPluginGrantDto> grants}): _grants = grants;
  factory _PluginGrantListResultDto.fromJson(Map<String, dynamic> json) => _$PluginGrantListResultDtoFromJson(json);

 final  List<AgentPluginGrantDto> _grants;
@override List<AgentPluginGrantDto> get grants {
  if (_grants is EqualUnmodifiableListView) return _grants;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_grants);
}


/// Create a copy of PluginGrantListResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginGrantListResultDtoCopyWith<_PluginGrantListResultDto> get copyWith => __$PluginGrantListResultDtoCopyWithImpl<_PluginGrantListResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginGrantListResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginGrantListResultDto&&const DeepCollectionEquality().equals(other._grants, _grants));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_grants));

@override
String toString() {
  return 'PluginGrantListResultDto(grants: $grants)';
}


}

/// @nodoc
abstract mixin class _$PluginGrantListResultDtoCopyWith<$Res> implements $PluginGrantListResultDtoCopyWith<$Res> {
  factory _$PluginGrantListResultDtoCopyWith(_PluginGrantListResultDto value, $Res Function(_PluginGrantListResultDto) _then) = __$PluginGrantListResultDtoCopyWithImpl;
@override @useResult
$Res call({
 List<AgentPluginGrantDto> grants
});




}
/// @nodoc
class __$PluginGrantListResultDtoCopyWithImpl<$Res>
    implements _$PluginGrantListResultDtoCopyWith<$Res> {
  __$PluginGrantListResultDtoCopyWithImpl(this._self, this._then);

  final _PluginGrantListResultDto _self;
  final $Res Function(_PluginGrantListResultDto) _then;

/// Create a copy of PluginGrantListResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? grants = null,}) {
  return _then(_PluginGrantListResultDto(
grants: null == grants ? _self._grants : grants // ignore: cast_nullable_to_non_nullable
as List<AgentPluginGrantDto>,
  ));
}


}


/// @nodoc
mixin _$PluginSessionControlResultDto {

 PluginSessionControlValueDto get control;
/// Create a copy of PluginSessionControlResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginSessionControlResultDtoCopyWith<PluginSessionControlResultDto> get copyWith => _$PluginSessionControlResultDtoCopyWithImpl<PluginSessionControlResultDto>(this as PluginSessionControlResultDto, _$identity);

  /// Serializes this PluginSessionControlResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginSessionControlResultDto&&(identical(other.control, control) || other.control == control));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,control);

@override
String toString() {
  return 'PluginSessionControlResultDto(control: $control)';
}


}

/// @nodoc
abstract mixin class $PluginSessionControlResultDtoCopyWith<$Res>  {
  factory $PluginSessionControlResultDtoCopyWith(PluginSessionControlResultDto value, $Res Function(PluginSessionControlResultDto) _then) = _$PluginSessionControlResultDtoCopyWithImpl;
@useResult
$Res call({
 PluginSessionControlValueDto control
});


$PluginSessionControlValueDtoCopyWith<$Res> get control;

}
/// @nodoc
class _$PluginSessionControlResultDtoCopyWithImpl<$Res>
    implements $PluginSessionControlResultDtoCopyWith<$Res> {
  _$PluginSessionControlResultDtoCopyWithImpl(this._self, this._then);

  final PluginSessionControlResultDto _self;
  final $Res Function(PluginSessionControlResultDto) _then;

/// Create a copy of PluginSessionControlResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? control = null,}) {
  return _then(PluginSessionControlResultDto(
control: null == control ? _self.control : control // ignore: cast_nullable_to_non_nullable
as PluginSessionControlValueDto,
  ));
}
/// Create a copy of PluginSessionControlResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginSessionControlValueDtoCopyWith<$Res> get control {

  return $PluginSessionControlValueDtoCopyWith<$Res>(_self.control, (value) {
    return _then(_self.copyWith(control: value));
  });
}
}


/// Adds pattern-matching-related methods to [PluginSessionControlResultDto].
extension PluginSessionControlResultDtoPatterns on PluginSessionControlResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginSessionControlResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginSessionControlResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginSessionControlResultDto value)  $default,){
final _that = this;
switch (_that) {
case _PluginSessionControlResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginSessionControlResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _PluginSessionControlResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PluginSessionControlValueDto control)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginSessionControlResultDto() when $default != null:
return $default(_that.control);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PluginSessionControlValueDto control)  $default,) {final _that = this;
switch (_that) {
case _PluginSessionControlResultDto():
return $default(_that.control);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PluginSessionControlValueDto control)?  $default,) {final _that = this;
switch (_that) {
case _PluginSessionControlResultDto() when $default != null:
return $default(_that.control);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PluginSessionControlResultDto implements PluginSessionControlResultDto {
  const _PluginSessionControlResultDto({required this.control});
  factory _PluginSessionControlResultDto.fromJson(Map<String, dynamic> json) => _$PluginSessionControlResultDtoFromJson(json);

@override final  PluginSessionControlValueDto control;

/// Create a copy of PluginSessionControlResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginSessionControlResultDtoCopyWith<_PluginSessionControlResultDto> get copyWith => __$PluginSessionControlResultDtoCopyWithImpl<_PluginSessionControlResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginSessionControlResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginSessionControlResultDto&&(identical(other.control, control) || other.control == control));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,control);

@override
String toString() {
  return 'PluginSessionControlResultDto(control: $control)';
}


}

/// @nodoc
abstract mixin class _$PluginSessionControlResultDtoCopyWith<$Res> implements $PluginSessionControlResultDtoCopyWith<$Res> {
  factory _$PluginSessionControlResultDtoCopyWith(_PluginSessionControlResultDto value, $Res Function(_PluginSessionControlResultDto) _then) = __$PluginSessionControlResultDtoCopyWithImpl;
@override @useResult
$Res call({
 PluginSessionControlValueDto control
});


@override $PluginSessionControlValueDtoCopyWith<$Res> get control;

}
/// @nodoc
class __$PluginSessionControlResultDtoCopyWithImpl<$Res>
    implements _$PluginSessionControlResultDtoCopyWith<$Res> {
  __$PluginSessionControlResultDtoCopyWithImpl(this._self, this._then);

  final _PluginSessionControlResultDto _self;
  final $Res Function(_PluginSessionControlResultDto) _then;

/// Create a copy of PluginSessionControlResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? control = null,}) {
  return _then(_PluginSessionControlResultDto(
control: null == control ? _self.control : control // ignore: cast_nullable_to_non_nullable
as PluginSessionControlValueDto,
  ));
}

/// Create a copy of PluginSessionControlResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginSessionControlValueDtoCopyWith<$Res> get control {

  return $PluginSessionControlValueDtoCopyWith<$Res>(_self.control, (value) {
    return _then(_self.copyWith(control: value));
  });
}
}


/// @nodoc
mixin _$PluginUiDocumentResultDto {

 PluginUiDocumentDto get document;
/// Create a copy of PluginUiDocumentResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginUiDocumentResultDtoCopyWith<PluginUiDocumentResultDto> get copyWith => _$PluginUiDocumentResultDtoCopyWithImpl<PluginUiDocumentResultDto>(this as PluginUiDocumentResultDto, _$identity);

  /// Serializes this PluginUiDocumentResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginUiDocumentResultDto&&(identical(other.document, document) || other.document == document));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,document);

@override
String toString() {
  return 'PluginUiDocumentResultDto(document: $document)';
}


}

/// @nodoc
abstract mixin class $PluginUiDocumentResultDtoCopyWith<$Res>  {
  factory $PluginUiDocumentResultDtoCopyWith(PluginUiDocumentResultDto value, $Res Function(PluginUiDocumentResultDto) _then) = _$PluginUiDocumentResultDtoCopyWithImpl;
@useResult
$Res call({
 PluginUiDocumentDto document
});


$PluginUiDocumentDtoCopyWith<$Res> get document;

}
/// @nodoc
class _$PluginUiDocumentResultDtoCopyWithImpl<$Res>
    implements $PluginUiDocumentResultDtoCopyWith<$Res> {
  _$PluginUiDocumentResultDtoCopyWithImpl(this._self, this._then);

  final PluginUiDocumentResultDto _self;
  final $Res Function(PluginUiDocumentResultDto) _then;

/// Create a copy of PluginUiDocumentResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? document = null,}) {
  return _then(PluginUiDocumentResultDto(
document: null == document ? _self.document : document // ignore: cast_nullable_to_non_nullable
as PluginUiDocumentDto,
  ));
}
/// Create a copy of PluginUiDocumentResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginUiDocumentDtoCopyWith<$Res> get document {

  return $PluginUiDocumentDtoCopyWith<$Res>(_self.document, (value) {
    return _then(_self.copyWith(document: value));
  });
}
}


/// Adds pattern-matching-related methods to [PluginUiDocumentResultDto].
extension PluginUiDocumentResultDtoPatterns on PluginUiDocumentResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginUiDocumentResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginUiDocumentResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginUiDocumentResultDto value)  $default,){
final _that = this;
switch (_that) {
case _PluginUiDocumentResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginUiDocumentResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _PluginUiDocumentResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PluginUiDocumentDto document)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginUiDocumentResultDto() when $default != null:
return $default(_that.document);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PluginUiDocumentDto document)  $default,) {final _that = this;
switch (_that) {
case _PluginUiDocumentResultDto():
return $default(_that.document);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PluginUiDocumentDto document)?  $default,) {final _that = this;
switch (_that) {
case _PluginUiDocumentResultDto() when $default != null:
return $default(_that.document);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PluginUiDocumentResultDto implements PluginUiDocumentResultDto {
  const _PluginUiDocumentResultDto({required this.document});
  factory _PluginUiDocumentResultDto.fromJson(Map<String, dynamic> json) => _$PluginUiDocumentResultDtoFromJson(json);

@override final  PluginUiDocumentDto document;

/// Create a copy of PluginUiDocumentResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginUiDocumentResultDtoCopyWith<_PluginUiDocumentResultDto> get copyWith => __$PluginUiDocumentResultDtoCopyWithImpl<_PluginUiDocumentResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginUiDocumentResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginUiDocumentResultDto&&(identical(other.document, document) || other.document == document));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,document);

@override
String toString() {
  return 'PluginUiDocumentResultDto(document: $document)';
}


}

/// @nodoc
abstract mixin class _$PluginUiDocumentResultDtoCopyWith<$Res> implements $PluginUiDocumentResultDtoCopyWith<$Res> {
  factory _$PluginUiDocumentResultDtoCopyWith(_PluginUiDocumentResultDto value, $Res Function(_PluginUiDocumentResultDto) _then) = __$PluginUiDocumentResultDtoCopyWithImpl;
@override @useResult
$Res call({
 PluginUiDocumentDto document
});


@override $PluginUiDocumentDtoCopyWith<$Res> get document;

}
/// @nodoc
class __$PluginUiDocumentResultDtoCopyWithImpl<$Res>
    implements _$PluginUiDocumentResultDtoCopyWith<$Res> {
  __$PluginUiDocumentResultDtoCopyWithImpl(this._self, this._then);

  final _PluginUiDocumentResultDto _self;
  final $Res Function(_PluginUiDocumentResultDto) _then;

/// Create a copy of PluginUiDocumentResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? document = null,}) {
  return _then(_PluginUiDocumentResultDto(
document: null == document ? _self.document : document // ignore: cast_nullable_to_non_nullable
as PluginUiDocumentDto,
  ));
}

/// Create a copy of PluginUiDocumentResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginUiDocumentDtoCopyWith<$Res> get document {

  return $PluginUiDocumentDtoCopyWith<$Res>(_self.document, (value) {
    return _then(_self.copyWith(document: value));
  });
}
}


/// @nodoc
mixin _$AgentToolCatalogParamsDto {

 String? get worktreeId;
/// Create a copy of AgentToolCatalogParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentToolCatalogParamsDtoCopyWith<AgentToolCatalogParamsDto> get copyWith => _$AgentToolCatalogParamsDtoCopyWithImpl<AgentToolCatalogParamsDto>(this as AgentToolCatalogParamsDto, _$identity);

  /// Serializes this AgentToolCatalogParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentToolCatalogParamsDto&&(identical(other.worktreeId, worktreeId) || other.worktreeId == worktreeId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,worktreeId);

@override
String toString() {
  return 'AgentToolCatalogParamsDto(worktreeId: $worktreeId)';
}


}

/// @nodoc
abstract mixin class $AgentToolCatalogParamsDtoCopyWith<$Res>  {
  factory $AgentToolCatalogParamsDtoCopyWith(AgentToolCatalogParamsDto value, $Res Function(AgentToolCatalogParamsDto) _then) = _$AgentToolCatalogParamsDtoCopyWithImpl;
@useResult
$Res call({
 String? worktreeId
});




}
/// @nodoc
class _$AgentToolCatalogParamsDtoCopyWithImpl<$Res>
    implements $AgentToolCatalogParamsDtoCopyWith<$Res> {
  _$AgentToolCatalogParamsDtoCopyWithImpl(this._self, this._then);

  final AgentToolCatalogParamsDto _self;
  final $Res Function(AgentToolCatalogParamsDto) _then;

/// Create a copy of AgentToolCatalogParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? worktreeId = freezed,}) {
  return _then(AgentToolCatalogParamsDto(
worktreeId: freezed == worktreeId ? _self.worktreeId : worktreeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentToolCatalogParamsDto].
extension AgentToolCatalogParamsDtoPatterns on AgentToolCatalogParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentToolCatalogParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentToolCatalogParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentToolCatalogParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _AgentToolCatalogParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentToolCatalogParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _AgentToolCatalogParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? worktreeId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentToolCatalogParamsDto() when $default != null:
return $default(_that.worktreeId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? worktreeId)  $default,) {final _that = this;
switch (_that) {
case _AgentToolCatalogParamsDto():
return $default(_that.worktreeId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? worktreeId)?  $default,) {final _that = this;
switch (_that) {
case _AgentToolCatalogParamsDto() when $default != null:
return $default(_that.worktreeId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentToolCatalogParamsDto implements AgentToolCatalogParamsDto {
  const _AgentToolCatalogParamsDto({this.worktreeId});
  factory _AgentToolCatalogParamsDto.fromJson(Map<String, dynamic> json) => _$AgentToolCatalogParamsDtoFromJson(json);

@override final  String? worktreeId;

/// Create a copy of AgentToolCatalogParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentToolCatalogParamsDtoCopyWith<_AgentToolCatalogParamsDto> get copyWith => __$AgentToolCatalogParamsDtoCopyWithImpl<_AgentToolCatalogParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentToolCatalogParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentToolCatalogParamsDto&&(identical(other.worktreeId, worktreeId) || other.worktreeId == worktreeId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,worktreeId);

@override
String toString() {
  return 'AgentToolCatalogParamsDto(worktreeId: $worktreeId)';
}


}

/// @nodoc
abstract mixin class _$AgentToolCatalogParamsDtoCopyWith<$Res> implements $AgentToolCatalogParamsDtoCopyWith<$Res> {
  factory _$AgentToolCatalogParamsDtoCopyWith(_AgentToolCatalogParamsDto value, $Res Function(_AgentToolCatalogParamsDto) _then) = __$AgentToolCatalogParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String? worktreeId
});




}
/// @nodoc
class __$AgentToolCatalogParamsDtoCopyWithImpl<$Res>
    implements _$AgentToolCatalogParamsDtoCopyWith<$Res> {
  __$AgentToolCatalogParamsDtoCopyWithImpl(this._self, this._then);

  final _AgentToolCatalogParamsDto _self;
  final $Res Function(_AgentToolCatalogParamsDto) _then;

/// Create a copy of AgentToolCatalogParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? worktreeId = freezed,}) {
  return _then(_AgentToolCatalogParamsDto(
worktreeId: freezed == worktreeId ? _self.worktreeId : worktreeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$McpServersParamsDto {

 String? get worktreeId;
/// Create a copy of McpServersParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$McpServersParamsDtoCopyWith<McpServersParamsDto> get copyWith => _$McpServersParamsDtoCopyWithImpl<McpServersParamsDto>(this as McpServersParamsDto, _$identity);

  /// Serializes this McpServersParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpServersParamsDto&&(identical(other.worktreeId, worktreeId) || other.worktreeId == worktreeId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,worktreeId);

@override
String toString() {
  return 'McpServersParamsDto(worktreeId: $worktreeId)';
}


}

/// @nodoc
abstract mixin class $McpServersParamsDtoCopyWith<$Res>  {
  factory $McpServersParamsDtoCopyWith(McpServersParamsDto value, $Res Function(McpServersParamsDto) _then) = _$McpServersParamsDtoCopyWithImpl;
@useResult
$Res call({
 String? worktreeId
});




}
/// @nodoc
class _$McpServersParamsDtoCopyWithImpl<$Res>
    implements $McpServersParamsDtoCopyWith<$Res> {
  _$McpServersParamsDtoCopyWithImpl(this._self, this._then);

  final McpServersParamsDto _self;
  final $Res Function(McpServersParamsDto) _then;

/// Create a copy of McpServersParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? worktreeId = freezed,}) {
  return _then(McpServersParamsDto(
worktreeId: freezed == worktreeId ? _self.worktreeId : worktreeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [McpServersParamsDto].
extension McpServersParamsDtoPatterns on McpServersParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _McpServersParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _McpServersParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _McpServersParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _McpServersParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _McpServersParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _McpServersParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? worktreeId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _McpServersParamsDto() when $default != null:
return $default(_that.worktreeId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? worktreeId)  $default,) {final _that = this;
switch (_that) {
case _McpServersParamsDto():
return $default(_that.worktreeId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? worktreeId)?  $default,) {final _that = this;
switch (_that) {
case _McpServersParamsDto() when $default != null:
return $default(_that.worktreeId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _McpServersParamsDto implements McpServersParamsDto {
  const _McpServersParamsDto({this.worktreeId});
  factory _McpServersParamsDto.fromJson(Map<String, dynamic> json) => _$McpServersParamsDtoFromJson(json);

@override final  String? worktreeId;

/// Create a copy of McpServersParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$McpServersParamsDtoCopyWith<_McpServersParamsDto> get copyWith => __$McpServersParamsDtoCopyWithImpl<_McpServersParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$McpServersParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpServersParamsDto&&(identical(other.worktreeId, worktreeId) || other.worktreeId == worktreeId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,worktreeId);

@override
String toString() {
  return 'McpServersParamsDto(worktreeId: $worktreeId)';
}


}

/// @nodoc
abstract mixin class _$McpServersParamsDtoCopyWith<$Res> implements $McpServersParamsDtoCopyWith<$Res> {
  factory _$McpServersParamsDtoCopyWith(_McpServersParamsDto value, $Res Function(_McpServersParamsDto) _then) = __$McpServersParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String? worktreeId
});




}
/// @nodoc
class __$McpServersParamsDtoCopyWithImpl<$Res>
    implements _$McpServersParamsDtoCopyWith<$Res> {
  __$McpServersParamsDtoCopyWithImpl(this._self, this._then);

  final _McpServersParamsDto _self;
  final $Res Function(_McpServersParamsDto) _then;

/// Create a copy of McpServersParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? worktreeId = freezed,}) {
  return _then(_McpServersParamsDto(
worktreeId: freezed == worktreeId ? _self.worktreeId : worktreeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$McpServersResultDto {

 List<McpServerStateDto> get servers;
/// Create a copy of McpServersResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$McpServersResultDtoCopyWith<McpServersResultDto> get copyWith => _$McpServersResultDtoCopyWithImpl<McpServersResultDto>(this as McpServersResultDto, _$identity);

  /// Serializes this McpServersResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpServersResultDto&&const DeepCollectionEquality().equals(other.servers, servers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(servers));

@override
String toString() {
  return 'McpServersResultDto(servers: $servers)';
}


}

/// @nodoc
abstract mixin class $McpServersResultDtoCopyWith<$Res>  {
  factory $McpServersResultDtoCopyWith(McpServersResultDto value, $Res Function(McpServersResultDto) _then) = _$McpServersResultDtoCopyWithImpl;
@useResult
$Res call({
 List<McpServerStateDto> servers
});




}
/// @nodoc
class _$McpServersResultDtoCopyWithImpl<$Res>
    implements $McpServersResultDtoCopyWith<$Res> {
  _$McpServersResultDtoCopyWithImpl(this._self, this._then);

  final McpServersResultDto _self;
  final $Res Function(McpServersResultDto) _then;

/// Create a copy of McpServersResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? servers = null,}) {
  return _then(McpServersResultDto(
servers: null == servers ? _self.servers : servers // ignore: cast_nullable_to_non_nullable
as List<McpServerStateDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [McpServersResultDto].
extension McpServersResultDtoPatterns on McpServersResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _McpServersResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _McpServersResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _McpServersResultDto value)  $default,){
final _that = this;
switch (_that) {
case _McpServersResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _McpServersResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _McpServersResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<McpServerStateDto> servers)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _McpServersResultDto() when $default != null:
return $default(_that.servers);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<McpServerStateDto> servers)  $default,) {final _that = this;
switch (_that) {
case _McpServersResultDto():
return $default(_that.servers);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<McpServerStateDto> servers)?  $default,) {final _that = this;
switch (_that) {
case _McpServersResultDto() when $default != null:
return $default(_that.servers);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _McpServersResultDto implements McpServersResultDto {
  const _McpServersResultDto({required  List<McpServerStateDto> servers}): _servers = servers;
  factory _McpServersResultDto.fromJson(Map<String, dynamic> json) => _$McpServersResultDtoFromJson(json);

 final  List<McpServerStateDto> _servers;
@override List<McpServerStateDto> get servers {
  if (_servers is EqualUnmodifiableListView) return _servers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_servers);
}


/// Create a copy of McpServersResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$McpServersResultDtoCopyWith<_McpServersResultDto> get copyWith => __$McpServersResultDtoCopyWithImpl<_McpServersResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$McpServersResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpServersResultDto&&const DeepCollectionEquality().equals(other._servers, _servers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_servers));

@override
String toString() {
  return 'McpServersResultDto(servers: $servers)';
}


}

/// @nodoc
abstract mixin class _$McpServersResultDtoCopyWith<$Res> implements $McpServersResultDtoCopyWith<$Res> {
  factory _$McpServersResultDtoCopyWith(_McpServersResultDto value, $Res Function(_McpServersResultDto) _then) = __$McpServersResultDtoCopyWithImpl;
@override @useResult
$Res call({
 List<McpServerStateDto> servers
});




}
/// @nodoc
class __$McpServersResultDtoCopyWithImpl<$Res>
    implements _$McpServersResultDtoCopyWith<$Res> {
  __$McpServersResultDtoCopyWithImpl(this._self, this._then);

  final _McpServersResultDto _self;
  final $Res Function(_McpServersResultDto) _then;

/// Create a copy of McpServersResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? servers = null,}) {
  return _then(_McpServersResultDto(
servers: null == servers ? _self._servers : servers // ignore: cast_nullable_to_non_nullable
as List<McpServerStateDto>,
  ));
}


}


/// @nodoc
mixin _$McpServerParamsDto {

 McpServerConfigDto get server;
/// Create a copy of McpServerParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$McpServerParamsDtoCopyWith<McpServerParamsDto> get copyWith => _$McpServerParamsDtoCopyWithImpl<McpServerParamsDto>(this as McpServerParamsDto, _$identity);

  /// Serializes this McpServerParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpServerParamsDto&&(identical(other.server, server) || other.server == server));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,server);

@override
String toString() {
  return 'McpServerParamsDto(server: $server)';
}


}

/// @nodoc
abstract mixin class $McpServerParamsDtoCopyWith<$Res>  {
  factory $McpServerParamsDtoCopyWith(McpServerParamsDto value, $Res Function(McpServerParamsDto) _then) = _$McpServerParamsDtoCopyWithImpl;
@useResult
$Res call({
 McpServerConfigDto server
});


$McpServerConfigDtoCopyWith<$Res> get server;

}
/// @nodoc
class _$McpServerParamsDtoCopyWithImpl<$Res>
    implements $McpServerParamsDtoCopyWith<$Res> {
  _$McpServerParamsDtoCopyWithImpl(this._self, this._then);

  final McpServerParamsDto _self;
  final $Res Function(McpServerParamsDto) _then;

/// Create a copy of McpServerParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? server = null,}) {
  return _then(McpServerParamsDto(
server: null == server ? _self.server : server // ignore: cast_nullable_to_non_nullable
as McpServerConfigDto,
  ));
}
/// Create a copy of McpServerParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$McpServerConfigDtoCopyWith<$Res> get server {

  return $McpServerConfigDtoCopyWith<$Res>(_self.server, (value) {
    return _then(_self.copyWith(server: value));
  });
}
}


/// Adds pattern-matching-related methods to [McpServerParamsDto].
extension McpServerParamsDtoPatterns on McpServerParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _McpServerParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _McpServerParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _McpServerParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _McpServerParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _McpServerParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _McpServerParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( McpServerConfigDto server)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _McpServerParamsDto() when $default != null:
return $default(_that.server);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( McpServerConfigDto server)  $default,) {final _that = this;
switch (_that) {
case _McpServerParamsDto():
return $default(_that.server);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( McpServerConfigDto server)?  $default,) {final _that = this;
switch (_that) {
case _McpServerParamsDto() when $default != null:
return $default(_that.server);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _McpServerParamsDto implements McpServerParamsDto {
  const _McpServerParamsDto({required this.server});
  factory _McpServerParamsDto.fromJson(Map<String, dynamic> json) => _$McpServerParamsDtoFromJson(json);

@override final  McpServerConfigDto server;

/// Create a copy of McpServerParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$McpServerParamsDtoCopyWith<_McpServerParamsDto> get copyWith => __$McpServerParamsDtoCopyWithImpl<_McpServerParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$McpServerParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpServerParamsDto&&(identical(other.server, server) || other.server == server));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,server);

@override
String toString() {
  return 'McpServerParamsDto(server: $server)';
}


}

/// @nodoc
abstract mixin class _$McpServerParamsDtoCopyWith<$Res> implements $McpServerParamsDtoCopyWith<$Res> {
  factory _$McpServerParamsDtoCopyWith(_McpServerParamsDto value, $Res Function(_McpServerParamsDto) _then) = __$McpServerParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 McpServerConfigDto server
});


@override $McpServerConfigDtoCopyWith<$Res> get server;

}
/// @nodoc
class __$McpServerParamsDtoCopyWithImpl<$Res>
    implements _$McpServerParamsDtoCopyWith<$Res> {
  __$McpServerParamsDtoCopyWithImpl(this._self, this._then);

  final _McpServerParamsDto _self;
  final $Res Function(_McpServerParamsDto) _then;

/// Create a copy of McpServerParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? server = null,}) {
  return _then(_McpServerParamsDto(
server: null == server ? _self.server : server // ignore: cast_nullable_to_non_nullable
as McpServerConfigDto,
  ));
}

/// Create a copy of McpServerParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$McpServerConfigDtoCopyWith<$Res> get server {

  return $McpServerConfigDtoCopyWith<$Res>(_self.server, (value) {
    return _then(_self.copyWith(server: value));
  });
}
}


/// @nodoc
mixin _$McpServerIdParamsDto {

 String get id;
/// Create a copy of McpServerIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$McpServerIdParamsDtoCopyWith<McpServerIdParamsDto> get copyWith => _$McpServerIdParamsDtoCopyWithImpl<McpServerIdParamsDto>(this as McpServerIdParamsDto, _$identity);

  /// Serializes this McpServerIdParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpServerIdParamsDto&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'McpServerIdParamsDto(id: $id)';
}


}

/// @nodoc
abstract mixin class $McpServerIdParamsDtoCopyWith<$Res>  {
  factory $McpServerIdParamsDtoCopyWith(McpServerIdParamsDto value, $Res Function(McpServerIdParamsDto) _then) = _$McpServerIdParamsDtoCopyWithImpl;
@useResult
$Res call({
 String id
});




}
/// @nodoc
class _$McpServerIdParamsDtoCopyWithImpl<$Res>
    implements $McpServerIdParamsDtoCopyWith<$Res> {
  _$McpServerIdParamsDtoCopyWithImpl(this._self, this._then);

  final McpServerIdParamsDto _self;
  final $Res Function(McpServerIdParamsDto) _then;

/// Create a copy of McpServerIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,}) {
  return _then(McpServerIdParamsDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [McpServerIdParamsDto].
extension McpServerIdParamsDtoPatterns on McpServerIdParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _McpServerIdParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _McpServerIdParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _McpServerIdParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _McpServerIdParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _McpServerIdParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _McpServerIdParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _McpServerIdParamsDto() when $default != null:
return $default(_that.id);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id)  $default,) {final _that = this;
switch (_that) {
case _McpServerIdParamsDto():
return $default(_that.id);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id)?  $default,) {final _that = this;
switch (_that) {
case _McpServerIdParamsDto() when $default != null:
return $default(_that.id);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _McpServerIdParamsDto implements McpServerIdParamsDto {
  const _McpServerIdParamsDto({required this.id});
  factory _McpServerIdParamsDto.fromJson(Map<String, dynamic> json) => _$McpServerIdParamsDtoFromJson(json);

@override final  String id;

/// Create a copy of McpServerIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$McpServerIdParamsDtoCopyWith<_McpServerIdParamsDto> get copyWith => __$McpServerIdParamsDtoCopyWithImpl<_McpServerIdParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$McpServerIdParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpServerIdParamsDto&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'McpServerIdParamsDto(id: $id)';
}


}

/// @nodoc
abstract mixin class _$McpServerIdParamsDtoCopyWith<$Res> implements $McpServerIdParamsDtoCopyWith<$Res> {
  factory _$McpServerIdParamsDtoCopyWith(_McpServerIdParamsDto value, $Res Function(_McpServerIdParamsDto) _then) = __$McpServerIdParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String id
});




}
/// @nodoc
class __$McpServerIdParamsDtoCopyWithImpl<$Res>
    implements _$McpServerIdParamsDtoCopyWith<$Res> {
  __$McpServerIdParamsDtoCopyWithImpl(this._self, this._then);

  final _McpServerIdParamsDto _self;
  final $Res Function(_McpServerIdParamsDto) _then;

/// Create a copy of McpServerIdParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,}) {
  return _then(_McpServerIdParamsDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$McpServerStateResultDto {

 McpServerStateDto get state;
/// Create a copy of McpServerStateResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$McpServerStateResultDtoCopyWith<McpServerStateResultDto> get copyWith => _$McpServerStateResultDtoCopyWithImpl<McpServerStateResultDto>(this as McpServerStateResultDto, _$identity);

  /// Serializes this McpServerStateResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpServerStateResultDto&&(identical(other.state, state) || other.state == state));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,state);

@override
String toString() {
  return 'McpServerStateResultDto(state: $state)';
}


}

/// @nodoc
abstract mixin class $McpServerStateResultDtoCopyWith<$Res>  {
  factory $McpServerStateResultDtoCopyWith(McpServerStateResultDto value, $Res Function(McpServerStateResultDto) _then) = _$McpServerStateResultDtoCopyWithImpl;
@useResult
$Res call({
 McpServerStateDto state
});


$McpServerStateDtoCopyWith<$Res> get state;

}
/// @nodoc
class _$McpServerStateResultDtoCopyWithImpl<$Res>
    implements $McpServerStateResultDtoCopyWith<$Res> {
  _$McpServerStateResultDtoCopyWithImpl(this._self, this._then);

  final McpServerStateResultDto _self;
  final $Res Function(McpServerStateResultDto) _then;

/// Create a copy of McpServerStateResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? state = null,}) {
  return _then(McpServerStateResultDto(
state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as McpServerStateDto,
  ));
}
/// Create a copy of McpServerStateResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$McpServerStateDtoCopyWith<$Res> get state {

  return $McpServerStateDtoCopyWith<$Res>(_self.state, (value) {
    return _then(_self.copyWith(state: value));
  });
}
}


/// Adds pattern-matching-related methods to [McpServerStateResultDto].
extension McpServerStateResultDtoPatterns on McpServerStateResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _McpServerStateResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _McpServerStateResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _McpServerStateResultDto value)  $default,){
final _that = this;
switch (_that) {
case _McpServerStateResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _McpServerStateResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _McpServerStateResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( McpServerStateDto state)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _McpServerStateResultDto() when $default != null:
return $default(_that.state);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( McpServerStateDto state)  $default,) {final _that = this;
switch (_that) {
case _McpServerStateResultDto():
return $default(_that.state);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( McpServerStateDto state)?  $default,) {final _that = this;
switch (_that) {
case _McpServerStateResultDto() when $default != null:
return $default(_that.state);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _McpServerStateResultDto implements McpServerStateResultDto {
  const _McpServerStateResultDto({required this.state});
  factory _McpServerStateResultDto.fromJson(Map<String, dynamic> json) => _$McpServerStateResultDtoFromJson(json);

@override final  McpServerStateDto state;

/// Create a copy of McpServerStateResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$McpServerStateResultDtoCopyWith<_McpServerStateResultDto> get copyWith => __$McpServerStateResultDtoCopyWithImpl<_McpServerStateResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$McpServerStateResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpServerStateResultDto&&(identical(other.state, state) || other.state == state));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,state);

@override
String toString() {
  return 'McpServerStateResultDto(state: $state)';
}


}

/// @nodoc
abstract mixin class _$McpServerStateResultDtoCopyWith<$Res> implements $McpServerStateResultDtoCopyWith<$Res> {
  factory _$McpServerStateResultDtoCopyWith(_McpServerStateResultDto value, $Res Function(_McpServerStateResultDto) _then) = __$McpServerStateResultDtoCopyWithImpl;
@override @useResult
$Res call({
 McpServerStateDto state
});


@override $McpServerStateDtoCopyWith<$Res> get state;

}
/// @nodoc
class __$McpServerStateResultDtoCopyWithImpl<$Res>
    implements _$McpServerStateResultDtoCopyWith<$Res> {
  __$McpServerStateResultDtoCopyWithImpl(this._self, this._then);

  final _McpServerStateResultDto _self;
  final $Res Function(_McpServerStateResultDto) _then;

/// Create a copy of McpServerStateResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? state = null,}) {
  return _then(_McpServerStateResultDto(
state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as McpServerStateDto,
  ));
}

/// Create a copy of McpServerStateResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$McpServerStateDtoCopyWith<$Res> get state {

  return $McpServerStateDtoCopyWith<$Res>(_self.state, (value) {
    return _then(_self.copyWith(state: value));
  });
}
}


/// @nodoc
mixin _$McpSecretParamsDto {

 String get key; String get value;
/// Create a copy of McpSecretParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$McpSecretParamsDtoCopyWith<McpSecretParamsDto> get copyWith => _$McpSecretParamsDtoCopyWithImpl<McpSecretParamsDto>(this as McpSecretParamsDto, _$identity);

  /// Serializes this McpSecretParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpSecretParamsDto&&(identical(other.key, key) || other.key == key)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,value);

@override
String toString() {
  return 'McpSecretParamsDto(key: $key, value: $value)';
}


}

/// @nodoc
abstract mixin class $McpSecretParamsDtoCopyWith<$Res>  {
  factory $McpSecretParamsDtoCopyWith(McpSecretParamsDto value, $Res Function(McpSecretParamsDto) _then) = _$McpSecretParamsDtoCopyWithImpl;
@useResult
$Res call({
 String key, String value
});




}
/// @nodoc
class _$McpSecretParamsDtoCopyWithImpl<$Res>
    implements $McpSecretParamsDtoCopyWith<$Res> {
  _$McpSecretParamsDtoCopyWithImpl(this._self, this._then);

  final McpSecretParamsDto _self;
  final $Res Function(McpSecretParamsDto) _then;

/// Create a copy of McpSecretParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? value = null,}) {
  return _then(McpSecretParamsDto(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [McpSecretParamsDto].
extension McpSecretParamsDtoPatterns on McpSecretParamsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _McpSecretParamsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _McpSecretParamsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _McpSecretParamsDto value)  $default,){
final _that = this;
switch (_that) {
case _McpSecretParamsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _McpSecretParamsDto value)?  $default,){
final _that = this;
switch (_that) {
case _McpSecretParamsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  String value)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _McpSecretParamsDto() when $default != null:
return $default(_that.key,_that.value);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  String value)  $default,) {final _that = this;
switch (_that) {
case _McpSecretParamsDto():
return $default(_that.key,_that.value);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  String value)?  $default,) {final _that = this;
switch (_that) {
case _McpSecretParamsDto() when $default != null:
return $default(_that.key,_that.value);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _McpSecretParamsDto implements McpSecretParamsDto {
  const _McpSecretParamsDto({required this.key, required this.value});
  factory _McpSecretParamsDto.fromJson(Map<String, dynamic> json) => _$McpSecretParamsDtoFromJson(json);

@override final  String key;
@override final  String value;

/// Create a copy of McpSecretParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$McpSecretParamsDtoCopyWith<_McpSecretParamsDto> get copyWith => __$McpSecretParamsDtoCopyWithImpl<_McpSecretParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$McpSecretParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpSecretParamsDto&&(identical(other.key, key) || other.key == key)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,value);

@override
String toString() {
  return 'McpSecretParamsDto(key: $key, value: $value)';
}


}

/// @nodoc
abstract mixin class _$McpSecretParamsDtoCopyWith<$Res> implements $McpSecretParamsDtoCopyWith<$Res> {
  factory _$McpSecretParamsDtoCopyWith(_McpSecretParamsDto value, $Res Function(_McpSecretParamsDto) _then) = __$McpSecretParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String key, String value
});




}
/// @nodoc
class __$McpSecretParamsDtoCopyWithImpl<$Res>
    implements _$McpSecretParamsDtoCopyWith<$Res> {
  __$McpSecretParamsDtoCopyWithImpl(this._self, this._then);

  final _McpSecretParamsDto _self;
  final $Res Function(_McpSecretParamsDto) _then;

/// Create a copy of McpSecretParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? value = null,}) {
  return _then(_McpSecretParamsDto(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$AgentToolCatalogResultDto {

 List<AgentToolDefinitionDto> get tools;
/// Create a copy of AgentToolCatalogResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentToolCatalogResultDtoCopyWith<AgentToolCatalogResultDto> get copyWith => _$AgentToolCatalogResultDtoCopyWithImpl<AgentToolCatalogResultDto>(this as AgentToolCatalogResultDto, _$identity);

  /// Serializes this AgentToolCatalogResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentToolCatalogResultDto&&const DeepCollectionEquality().equals(other.tools, tools));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(tools));

@override
String toString() {
  return 'AgentToolCatalogResultDto(tools: $tools)';
}


}

/// @nodoc
abstract mixin class $AgentToolCatalogResultDtoCopyWith<$Res>  {
  factory $AgentToolCatalogResultDtoCopyWith(AgentToolCatalogResultDto value, $Res Function(AgentToolCatalogResultDto) _then) = _$AgentToolCatalogResultDtoCopyWithImpl;
@useResult
$Res call({
 List<AgentToolDefinitionDto> tools
});




}
/// @nodoc
class _$AgentToolCatalogResultDtoCopyWithImpl<$Res>
    implements $AgentToolCatalogResultDtoCopyWith<$Res> {
  _$AgentToolCatalogResultDtoCopyWithImpl(this._self, this._then);

  final AgentToolCatalogResultDto _self;
  final $Res Function(AgentToolCatalogResultDto) _then;

/// Create a copy of AgentToolCatalogResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tools = null,}) {
  return _then(AgentToolCatalogResultDto(
tools: null == tools ? _self.tools : tools // ignore: cast_nullable_to_non_nullable
as List<AgentToolDefinitionDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentToolCatalogResultDto].
extension AgentToolCatalogResultDtoPatterns on AgentToolCatalogResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentToolCatalogResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentToolCatalogResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentToolCatalogResultDto value)  $default,){
final _that = this;
switch (_that) {
case _AgentToolCatalogResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentToolCatalogResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _AgentToolCatalogResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<AgentToolDefinitionDto> tools)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentToolCatalogResultDto() when $default != null:
return $default(_that.tools);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<AgentToolDefinitionDto> tools)  $default,) {final _that = this;
switch (_that) {
case _AgentToolCatalogResultDto():
return $default(_that.tools);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<AgentToolDefinitionDto> tools)?  $default,) {final _that = this;
switch (_that) {
case _AgentToolCatalogResultDto() when $default != null:
return $default(_that.tools);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentToolCatalogResultDto implements AgentToolCatalogResultDto {
  const _AgentToolCatalogResultDto({required  List<AgentToolDefinitionDto> tools}): _tools = tools;
  factory _AgentToolCatalogResultDto.fromJson(Map<String, dynamic> json) => _$AgentToolCatalogResultDtoFromJson(json);

 final  List<AgentToolDefinitionDto> _tools;
@override List<AgentToolDefinitionDto> get tools {
  if (_tools is EqualUnmodifiableListView) return _tools;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tools);
}


/// Create a copy of AgentToolCatalogResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentToolCatalogResultDtoCopyWith<_AgentToolCatalogResultDto> get copyWith => __$AgentToolCatalogResultDtoCopyWithImpl<_AgentToolCatalogResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentToolCatalogResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentToolCatalogResultDto&&const DeepCollectionEquality().equals(other._tools, _tools));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_tools));

@override
String toString() {
  return 'AgentToolCatalogResultDto(tools: $tools)';
}


}

/// @nodoc
abstract mixin class _$AgentToolCatalogResultDtoCopyWith<$Res> implements $AgentToolCatalogResultDtoCopyWith<$Res> {
  factory _$AgentToolCatalogResultDtoCopyWith(_AgentToolCatalogResultDto value, $Res Function(_AgentToolCatalogResultDto) _then) = __$AgentToolCatalogResultDtoCopyWithImpl;
@override @useResult
$Res call({
 List<AgentToolDefinitionDto> tools
});




}
/// @nodoc
class __$AgentToolCatalogResultDtoCopyWithImpl<$Res>
    implements _$AgentToolCatalogResultDtoCopyWith<$Res> {
  __$AgentToolCatalogResultDtoCopyWithImpl(this._self, this._then);

  final _AgentToolCatalogResultDto _self;
  final $Res Function(_AgentToolCatalogResultDto) _then;

/// Create a copy of AgentToolCatalogResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tools = null,}) {
  return _then(_AgentToolCatalogResultDto(
tools: null == tools ? _self._tools : tools // ignore: cast_nullable_to_non_nullable
as List<AgentToolDefinitionDto>,
  ));
}


}


/// @nodoc
mixin _$SkillListResultDto {

 List<SkillSummaryDto> get skills;
/// Create a copy of SkillListResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SkillListResultDtoCopyWith<SkillListResultDto> get copyWith => _$SkillListResultDtoCopyWithImpl<SkillListResultDto>(this as SkillListResultDto, _$identity);

  /// Serializes this SkillListResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SkillListResultDto&&const DeepCollectionEquality().equals(other.skills, skills));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(skills));

@override
String toString() {
  return 'SkillListResultDto(skills: $skills)';
}


}

/// @nodoc
abstract mixin class $SkillListResultDtoCopyWith<$Res>  {
  factory $SkillListResultDtoCopyWith(SkillListResultDto value, $Res Function(SkillListResultDto) _then) = _$SkillListResultDtoCopyWithImpl;
@useResult
$Res call({
 List<SkillSummaryDto> skills
});




}
/// @nodoc
class _$SkillListResultDtoCopyWithImpl<$Res>
    implements $SkillListResultDtoCopyWith<$Res> {
  _$SkillListResultDtoCopyWithImpl(this._self, this._then);

  final SkillListResultDto _self;
  final $Res Function(SkillListResultDto) _then;

/// Create a copy of SkillListResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? skills = null,}) {
  return _then(SkillListResultDto(
skills: null == skills ? _self.skills : skills // ignore: cast_nullable_to_non_nullable
as List<SkillSummaryDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [SkillListResultDto].
extension SkillListResultDtoPatterns on SkillListResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SkillListResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SkillListResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SkillListResultDto value)  $default,){
final _that = this;
switch (_that) {
case _SkillListResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SkillListResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _SkillListResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<SkillSummaryDto> skills)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SkillListResultDto() when $default != null:
return $default(_that.skills);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<SkillSummaryDto> skills)  $default,) {final _that = this;
switch (_that) {
case _SkillListResultDto():
return $default(_that.skills);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<SkillSummaryDto> skills)?  $default,) {final _that = this;
switch (_that) {
case _SkillListResultDto() when $default != null:
return $default(_that.skills);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SkillListResultDto implements SkillListResultDto {
  const _SkillListResultDto({required  List<SkillSummaryDto> skills}): _skills = skills;
  factory _SkillListResultDto.fromJson(Map<String, dynamic> json) => _$SkillListResultDtoFromJson(json);

 final  List<SkillSummaryDto> _skills;
@override List<SkillSummaryDto> get skills {
  if (_skills is EqualUnmodifiableListView) return _skills;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_skills);
}


/// Create a copy of SkillListResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SkillListResultDtoCopyWith<_SkillListResultDto> get copyWith => __$SkillListResultDtoCopyWithImpl<_SkillListResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SkillListResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SkillListResultDto&&const DeepCollectionEquality().equals(other._skills, _skills));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_skills));

@override
String toString() {
  return 'SkillListResultDto(skills: $skills)';
}


}

/// @nodoc
abstract mixin class _$SkillListResultDtoCopyWith<$Res> implements $SkillListResultDtoCopyWith<$Res> {
  factory _$SkillListResultDtoCopyWith(_SkillListResultDto value, $Res Function(_SkillListResultDto) _then) = __$SkillListResultDtoCopyWithImpl;
@override @useResult
$Res call({
 List<SkillSummaryDto> skills
});




}
/// @nodoc
class __$SkillListResultDtoCopyWithImpl<$Res>
    implements _$SkillListResultDtoCopyWith<$Res> {
  __$SkillListResultDtoCopyWithImpl(this._self, this._then);

  final _SkillListResultDto _self;
  final $Res Function(_SkillListResultDto) _then;

/// Create a copy of SkillListResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? skills = null,}) {
  return _then(_SkillListResultDto(
skills: null == skills ? _self._skills : skills // ignore: cast_nullable_to_non_nullable
as List<SkillSummaryDto>,
  ));
}


}


/// @nodoc
mixin _$CommandListResultDto {

 List<AgentCommandDto> get commands;
/// Create a copy of CommandListResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommandListResultDtoCopyWith<CommandListResultDto> get copyWith => _$CommandListResultDtoCopyWithImpl<CommandListResultDto>(this as CommandListResultDto, _$identity);

  /// Serializes this CommandListResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommandListResultDto&&const DeepCollectionEquality().equals(other.commands, commands));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(commands));

@override
String toString() {
  return 'CommandListResultDto(commands: $commands)';
}


}

/// @nodoc
abstract mixin class $CommandListResultDtoCopyWith<$Res>  {
  factory $CommandListResultDtoCopyWith(CommandListResultDto value, $Res Function(CommandListResultDto) _then) = _$CommandListResultDtoCopyWithImpl;
@useResult
$Res call({
 List<AgentCommandDto> commands
});




}
/// @nodoc
class _$CommandListResultDtoCopyWithImpl<$Res>
    implements $CommandListResultDtoCopyWith<$Res> {
  _$CommandListResultDtoCopyWithImpl(this._self, this._then);

  final CommandListResultDto _self;
  final $Res Function(CommandListResultDto) _then;

/// Create a copy of CommandListResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? commands = null,}) {
  return _then(CommandListResultDto(
commands: null == commands ? _self.commands : commands // ignore: cast_nullable_to_non_nullable
as List<AgentCommandDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [CommandListResultDto].
extension CommandListResultDtoPatterns on CommandListResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommandListResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommandListResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommandListResultDto value)  $default,){
final _that = this;
switch (_that) {
case _CommandListResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommandListResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _CommandListResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<AgentCommandDto> commands)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommandListResultDto() when $default != null:
return $default(_that.commands);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<AgentCommandDto> commands)  $default,) {final _that = this;
switch (_that) {
case _CommandListResultDto():
return $default(_that.commands);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<AgentCommandDto> commands)?  $default,) {final _that = this;
switch (_that) {
case _CommandListResultDto() when $default != null:
return $default(_that.commands);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CommandListResultDto implements CommandListResultDto {
  const _CommandListResultDto({required  List<AgentCommandDto> commands}): _commands = commands;
  factory _CommandListResultDto.fromJson(Map<String, dynamic> json) => _$CommandListResultDtoFromJson(json);

 final  List<AgentCommandDto> _commands;
@override List<AgentCommandDto> get commands {
  if (_commands is EqualUnmodifiableListView) return _commands;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_commands);
}


/// Create a copy of CommandListResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommandListResultDtoCopyWith<_CommandListResultDto> get copyWith => __$CommandListResultDtoCopyWithImpl<_CommandListResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CommandListResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommandListResultDto&&const DeepCollectionEquality().equals(other._commands, _commands));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_commands));

@override
String toString() {
  return 'CommandListResultDto(commands: $commands)';
}


}

/// @nodoc
abstract mixin class _$CommandListResultDtoCopyWith<$Res> implements $CommandListResultDtoCopyWith<$Res> {
  factory _$CommandListResultDtoCopyWith(_CommandListResultDto value, $Res Function(_CommandListResultDto) _then) = __$CommandListResultDtoCopyWithImpl;
@override @useResult
$Res call({
 List<AgentCommandDto> commands
});




}
/// @nodoc
class __$CommandListResultDtoCopyWithImpl<$Res>
    implements _$CommandListResultDtoCopyWith<$Res> {
  __$CommandListResultDtoCopyWithImpl(this._self, this._then);

  final _CommandListResultDto _self;
  final $Res Function(_CommandListResultDto) _then;

/// Create a copy of CommandListResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? commands = null,}) {
  return _then(_CommandListResultDto(
commands: null == commands ? _self._commands : commands // ignore: cast_nullable_to_non_nullable
as List<AgentCommandDto>,
  ));
}


}


/// @nodoc
mixin _$ProviderCatalogResultDto {

 ProviderCatalogDto get catalog;
/// Create a copy of ProviderCatalogResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderCatalogResultDtoCopyWith<ProviderCatalogResultDto> get copyWith => _$ProviderCatalogResultDtoCopyWithImpl<ProviderCatalogResultDto>(this as ProviderCatalogResultDto, _$identity);

  /// Serializes this ProviderCatalogResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderCatalogResultDto&&(identical(other.catalog, catalog) || other.catalog == catalog));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,catalog);

@override
String toString() {
  return 'ProviderCatalogResultDto(catalog: $catalog)';
}


}

/// @nodoc
abstract mixin class $ProviderCatalogResultDtoCopyWith<$Res>  {
  factory $ProviderCatalogResultDtoCopyWith(ProviderCatalogResultDto value, $Res Function(ProviderCatalogResultDto) _then) = _$ProviderCatalogResultDtoCopyWithImpl;
@useResult
$Res call({
 ProviderCatalogDto catalog
});


$ProviderCatalogDtoCopyWith<$Res> get catalog;

}
/// @nodoc
class _$ProviderCatalogResultDtoCopyWithImpl<$Res>
    implements $ProviderCatalogResultDtoCopyWith<$Res> {
  _$ProviderCatalogResultDtoCopyWithImpl(this._self, this._then);

  final ProviderCatalogResultDto _self;
  final $Res Function(ProviderCatalogResultDto) _then;

/// Create a copy of ProviderCatalogResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? catalog = null,}) {
  return _then(ProviderCatalogResultDto(
catalog: null == catalog ? _self.catalog : catalog // ignore: cast_nullable_to_non_nullable
as ProviderCatalogDto,
  ));
}
/// Create a copy of ProviderCatalogResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProviderCatalogDtoCopyWith<$Res> get catalog {

  return $ProviderCatalogDtoCopyWith<$Res>(_self.catalog, (value) {
    return _then(_self.copyWith(catalog: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProviderCatalogResultDto].
extension ProviderCatalogResultDtoPatterns on ProviderCatalogResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderCatalogResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderCatalogResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderCatalogResultDto value)  $default,){
final _that = this;
switch (_that) {
case _ProviderCatalogResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderCatalogResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderCatalogResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ProviderCatalogDto catalog)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderCatalogResultDto() when $default != null:
return $default(_that.catalog);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ProviderCatalogDto catalog)  $default,) {final _that = this;
switch (_that) {
case _ProviderCatalogResultDto():
return $default(_that.catalog);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ProviderCatalogDto catalog)?  $default,) {final _that = this;
switch (_that) {
case _ProviderCatalogResultDto() when $default != null:
return $default(_that.catalog);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProviderCatalogResultDto implements ProviderCatalogResultDto {
  const _ProviderCatalogResultDto({required this.catalog});
  factory _ProviderCatalogResultDto.fromJson(Map<String, dynamic> json) => _$ProviderCatalogResultDtoFromJson(json);

@override final  ProviderCatalogDto catalog;

/// Create a copy of ProviderCatalogResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderCatalogResultDtoCopyWith<_ProviderCatalogResultDto> get copyWith => __$ProviderCatalogResultDtoCopyWithImpl<_ProviderCatalogResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderCatalogResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderCatalogResultDto&&(identical(other.catalog, catalog) || other.catalog == catalog));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,catalog);

@override
String toString() {
  return 'ProviderCatalogResultDto(catalog: $catalog)';
}


}

/// @nodoc
abstract mixin class _$ProviderCatalogResultDtoCopyWith<$Res> implements $ProviderCatalogResultDtoCopyWith<$Res> {
  factory _$ProviderCatalogResultDtoCopyWith(_ProviderCatalogResultDto value, $Res Function(_ProviderCatalogResultDto) _then) = __$ProviderCatalogResultDtoCopyWithImpl;
@override @useResult
$Res call({
 ProviderCatalogDto catalog
});


@override $ProviderCatalogDtoCopyWith<$Res> get catalog;

}
/// @nodoc
class __$ProviderCatalogResultDtoCopyWithImpl<$Res>
    implements _$ProviderCatalogResultDtoCopyWith<$Res> {
  __$ProviderCatalogResultDtoCopyWithImpl(this._self, this._then);

  final _ProviderCatalogResultDto _self;
  final $Res Function(_ProviderCatalogResultDto) _then;

/// Create a copy of ProviderCatalogResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? catalog = null,}) {
  return _then(_ProviderCatalogResultDto(
catalog: null == catalog ? _self.catalog : catalog // ignore: cast_nullable_to_non_nullable
as ProviderCatalogDto,
  ));
}

/// Create a copy of ProviderCatalogResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProviderCatalogDtoCopyWith<$Res> get catalog {

  return $ProviderCatalogDtoCopyWith<$Res>(_self.catalog, (value) {
    return _then(_self.copyWith(catalog: value));
  });
}
}


/// @nodoc
mixin _$ProviderConnectionsResultDto {

 List<ProviderConnectionDto> get connections;
/// Create a copy of ProviderConnectionsResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderConnectionsResultDtoCopyWith<ProviderConnectionsResultDto> get copyWith => _$ProviderConnectionsResultDtoCopyWithImpl<ProviderConnectionsResultDto>(this as ProviderConnectionsResultDto, _$identity);

  /// Serializes this ProviderConnectionsResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderConnectionsResultDto&&const DeepCollectionEquality().equals(other.connections, connections));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(connections));

@override
String toString() {
  return 'ProviderConnectionsResultDto(connections: $connections)';
}


}

/// @nodoc
abstract mixin class $ProviderConnectionsResultDtoCopyWith<$Res>  {
  factory $ProviderConnectionsResultDtoCopyWith(ProviderConnectionsResultDto value, $Res Function(ProviderConnectionsResultDto) _then) = _$ProviderConnectionsResultDtoCopyWithImpl;
@useResult
$Res call({
 List<ProviderConnectionDto> connections
});




}
/// @nodoc
class _$ProviderConnectionsResultDtoCopyWithImpl<$Res>
    implements $ProviderConnectionsResultDtoCopyWith<$Res> {
  _$ProviderConnectionsResultDtoCopyWithImpl(this._self, this._then);

  final ProviderConnectionsResultDto _self;
  final $Res Function(ProviderConnectionsResultDto) _then;

/// Create a copy of ProviderConnectionsResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? connections = null,}) {
  return _then(ProviderConnectionsResultDto(
connections: null == connections ? _self.connections : connections // ignore: cast_nullable_to_non_nullable
as List<ProviderConnectionDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [ProviderConnectionsResultDto].
extension ProviderConnectionsResultDtoPatterns on ProviderConnectionsResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderConnectionsResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderConnectionsResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderConnectionsResultDto value)  $default,){
final _that = this;
switch (_that) {
case _ProviderConnectionsResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderConnectionsResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderConnectionsResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ProviderConnectionDto> connections)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderConnectionsResultDto() when $default != null:
return $default(_that.connections);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ProviderConnectionDto> connections)  $default,) {final _that = this;
switch (_that) {
case _ProviderConnectionsResultDto():
return $default(_that.connections);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ProviderConnectionDto> connections)?  $default,) {final _that = this;
switch (_that) {
case _ProviderConnectionsResultDto() when $default != null:
return $default(_that.connections);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProviderConnectionsResultDto implements ProviderConnectionsResultDto {
  const _ProviderConnectionsResultDto({required  List<ProviderConnectionDto> connections}): _connections = connections;
  factory _ProviderConnectionsResultDto.fromJson(Map<String, dynamic> json) => _$ProviderConnectionsResultDtoFromJson(json);

 final  List<ProviderConnectionDto> _connections;
@override List<ProviderConnectionDto> get connections {
  if (_connections is EqualUnmodifiableListView) return _connections;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_connections);
}


/// Create a copy of ProviderConnectionsResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderConnectionsResultDtoCopyWith<_ProviderConnectionsResultDto> get copyWith => __$ProviderConnectionsResultDtoCopyWithImpl<_ProviderConnectionsResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderConnectionsResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderConnectionsResultDto&&const DeepCollectionEquality().equals(other._connections, _connections));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_connections));

@override
String toString() {
  return 'ProviderConnectionsResultDto(connections: $connections)';
}


}

/// @nodoc
abstract mixin class _$ProviderConnectionsResultDtoCopyWith<$Res> implements $ProviderConnectionsResultDtoCopyWith<$Res> {
  factory _$ProviderConnectionsResultDtoCopyWith(_ProviderConnectionsResultDto value, $Res Function(_ProviderConnectionsResultDto) _then) = __$ProviderConnectionsResultDtoCopyWithImpl;
@override @useResult
$Res call({
 List<ProviderConnectionDto> connections
});




}
/// @nodoc
class __$ProviderConnectionsResultDtoCopyWithImpl<$Res>
    implements _$ProviderConnectionsResultDtoCopyWith<$Res> {
  __$ProviderConnectionsResultDtoCopyWithImpl(this._self, this._then);

  final _ProviderConnectionsResultDto _self;
  final $Res Function(_ProviderConnectionsResultDto) _then;

/// Create a copy of ProviderConnectionsResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? connections = null,}) {
  return _then(_ProviderConnectionsResultDto(
connections: null == connections ? _self._connections : connections // ignore: cast_nullable_to_non_nullable
as List<ProviderConnectionDto>,
  ));
}


}


/// @nodoc
mixin _$ProviderUsageResultDto {

 List<ProviderUsageDto> get usage;
/// Create a copy of ProviderUsageResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderUsageResultDtoCopyWith<ProviderUsageResultDto> get copyWith => _$ProviderUsageResultDtoCopyWithImpl<ProviderUsageResultDto>(this as ProviderUsageResultDto, _$identity);

  /// Serializes this ProviderUsageResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderUsageResultDto&&const DeepCollectionEquality().equals(other.usage, usage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(usage));

@override
String toString() {
  return 'ProviderUsageResultDto(usage: $usage)';
}


}

/// @nodoc
abstract mixin class $ProviderUsageResultDtoCopyWith<$Res>  {
  factory $ProviderUsageResultDtoCopyWith(ProviderUsageResultDto value, $Res Function(ProviderUsageResultDto) _then) = _$ProviderUsageResultDtoCopyWithImpl;
@useResult
$Res call({
 List<ProviderUsageDto> usage
});




}
/// @nodoc
class _$ProviderUsageResultDtoCopyWithImpl<$Res>
    implements $ProviderUsageResultDtoCopyWith<$Res> {
  _$ProviderUsageResultDtoCopyWithImpl(this._self, this._then);

  final ProviderUsageResultDto _self;
  final $Res Function(ProviderUsageResultDto) _then;

/// Create a copy of ProviderUsageResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? usage = null,}) {
  return _then(ProviderUsageResultDto(
usage: null == usage ? _self.usage : usage // ignore: cast_nullable_to_non_nullable
as List<ProviderUsageDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [ProviderUsageResultDto].
extension ProviderUsageResultDtoPatterns on ProviderUsageResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderUsageResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderUsageResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderUsageResultDto value)  $default,){
final _that = this;
switch (_that) {
case _ProviderUsageResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderUsageResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderUsageResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ProviderUsageDto> usage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderUsageResultDto() when $default != null:
return $default(_that.usage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ProviderUsageDto> usage)  $default,) {final _that = this;
switch (_that) {
case _ProviderUsageResultDto():
return $default(_that.usage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ProviderUsageDto> usage)?  $default,) {final _that = this;
switch (_that) {
case _ProviderUsageResultDto() when $default != null:
return $default(_that.usage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProviderUsageResultDto implements ProviderUsageResultDto {
  const _ProviderUsageResultDto({required  List<ProviderUsageDto> usage}): _usage = usage;
  factory _ProviderUsageResultDto.fromJson(Map<String, dynamic> json) => _$ProviderUsageResultDtoFromJson(json);

 final  List<ProviderUsageDto> _usage;
@override List<ProviderUsageDto> get usage {
  if (_usage is EqualUnmodifiableListView) return _usage;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_usage);
}


/// Create a copy of ProviderUsageResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderUsageResultDtoCopyWith<_ProviderUsageResultDto> get copyWith => __$ProviderUsageResultDtoCopyWithImpl<_ProviderUsageResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderUsageResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderUsageResultDto&&const DeepCollectionEquality().equals(other._usage, _usage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_usage));

@override
String toString() {
  return 'ProviderUsageResultDto(usage: $usage)';
}


}

/// @nodoc
abstract mixin class _$ProviderUsageResultDtoCopyWith<$Res> implements $ProviderUsageResultDtoCopyWith<$Res> {
  factory _$ProviderUsageResultDtoCopyWith(_ProviderUsageResultDto value, $Res Function(_ProviderUsageResultDto) _then) = __$ProviderUsageResultDtoCopyWithImpl;
@override @useResult
$Res call({
 List<ProviderUsageDto> usage
});




}
/// @nodoc
class __$ProviderUsageResultDtoCopyWithImpl<$Res>
    implements _$ProviderUsageResultDtoCopyWith<$Res> {
  __$ProviderUsageResultDtoCopyWithImpl(this._self, this._then);

  final _ProviderUsageResultDto _self;
  final $Res Function(_ProviderUsageResultDto) _then;

/// Create a copy of ProviderUsageResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? usage = null,}) {
  return _then(_ProviderUsageResultDto(
usage: null == usage ? _self._usage : usage // ignore: cast_nullable_to_non_nullable
as List<ProviderUsageDto>,
  ));
}


}


/// @nodoc
mixin _$ProviderConnectionResultDto {

 ProviderConnectionDto get connection;
/// Create a copy of ProviderConnectionResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderConnectionResultDtoCopyWith<ProviderConnectionResultDto> get copyWith => _$ProviderConnectionResultDtoCopyWithImpl<ProviderConnectionResultDto>(this as ProviderConnectionResultDto, _$identity);

  /// Serializes this ProviderConnectionResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderConnectionResultDto&&(identical(other.connection, connection) || other.connection == connection));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,connection);

@override
String toString() {
  return 'ProviderConnectionResultDto(connection: $connection)';
}


}

/// @nodoc
abstract mixin class $ProviderConnectionResultDtoCopyWith<$Res>  {
  factory $ProviderConnectionResultDtoCopyWith(ProviderConnectionResultDto value, $Res Function(ProviderConnectionResultDto) _then) = _$ProviderConnectionResultDtoCopyWithImpl;
@useResult
$Res call({
 ProviderConnectionDto connection
});


$ProviderConnectionDtoCopyWith<$Res> get connection;

}
/// @nodoc
class _$ProviderConnectionResultDtoCopyWithImpl<$Res>
    implements $ProviderConnectionResultDtoCopyWith<$Res> {
  _$ProviderConnectionResultDtoCopyWithImpl(this._self, this._then);

  final ProviderConnectionResultDto _self;
  final $Res Function(ProviderConnectionResultDto) _then;

/// Create a copy of ProviderConnectionResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? connection = null,}) {
  return _then(ProviderConnectionResultDto(
connection: null == connection ? _self.connection : connection // ignore: cast_nullable_to_non_nullable
as ProviderConnectionDto,
  ));
}
/// Create a copy of ProviderConnectionResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProviderConnectionDtoCopyWith<$Res> get connection {

  return $ProviderConnectionDtoCopyWith<$Res>(_self.connection, (value) {
    return _then(_self.copyWith(connection: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProviderConnectionResultDto].
extension ProviderConnectionResultDtoPatterns on ProviderConnectionResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderConnectionResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderConnectionResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderConnectionResultDto value)  $default,){
final _that = this;
switch (_that) {
case _ProviderConnectionResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderConnectionResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderConnectionResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ProviderConnectionDto connection)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderConnectionResultDto() when $default != null:
return $default(_that.connection);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ProviderConnectionDto connection)  $default,) {final _that = this;
switch (_that) {
case _ProviderConnectionResultDto():
return $default(_that.connection);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ProviderConnectionDto connection)?  $default,) {final _that = this;
switch (_that) {
case _ProviderConnectionResultDto() when $default != null:
return $default(_that.connection);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProviderConnectionResultDto implements ProviderConnectionResultDto {
  const _ProviderConnectionResultDto({required this.connection});
  factory _ProviderConnectionResultDto.fromJson(Map<String, dynamic> json) => _$ProviderConnectionResultDtoFromJson(json);

@override final  ProviderConnectionDto connection;

/// Create a copy of ProviderConnectionResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderConnectionResultDtoCopyWith<_ProviderConnectionResultDto> get copyWith => __$ProviderConnectionResultDtoCopyWithImpl<_ProviderConnectionResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderConnectionResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderConnectionResultDto&&(identical(other.connection, connection) || other.connection == connection));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,connection);

@override
String toString() {
  return 'ProviderConnectionResultDto(connection: $connection)';
}


}

/// @nodoc
abstract mixin class _$ProviderConnectionResultDtoCopyWith<$Res> implements $ProviderConnectionResultDtoCopyWith<$Res> {
  factory _$ProviderConnectionResultDtoCopyWith(_ProviderConnectionResultDto value, $Res Function(_ProviderConnectionResultDto) _then) = __$ProviderConnectionResultDtoCopyWithImpl;
@override @useResult
$Res call({
 ProviderConnectionDto connection
});


@override $ProviderConnectionDtoCopyWith<$Res> get connection;

}
/// @nodoc
class __$ProviderConnectionResultDtoCopyWithImpl<$Res>
    implements _$ProviderConnectionResultDtoCopyWith<$Res> {
  __$ProviderConnectionResultDtoCopyWithImpl(this._self, this._then);

  final _ProviderConnectionResultDto _self;
  final $Res Function(_ProviderConnectionResultDto) _then;

/// Create a copy of ProviderConnectionResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? connection = null,}) {
  return _then(_ProviderConnectionResultDto(
connection: null == connection ? _self.connection : connection // ignore: cast_nullable_to_non_nullable
as ProviderConnectionDto,
  ));
}

/// Create a copy of ProviderConnectionResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProviderConnectionDtoCopyWith<$Res> get connection {

  return $ProviderConnectionDtoCopyWith<$Res>(_self.connection, (value) {
    return _then(_self.copyWith(connection: value));
  });
}
}


/// @nodoc
mixin _$ProviderModelsResultDto {

 List<ProviderModelDto> get models;
/// Create a copy of ProviderModelsResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderModelsResultDtoCopyWith<ProviderModelsResultDto> get copyWith => _$ProviderModelsResultDtoCopyWithImpl<ProviderModelsResultDto>(this as ProviderModelsResultDto, _$identity);

  /// Serializes this ProviderModelsResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderModelsResultDto&&const DeepCollectionEquality().equals(other.models, models));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(models));

@override
String toString() {
  return 'ProviderModelsResultDto(models: $models)';
}


}

/// @nodoc
abstract mixin class $ProviderModelsResultDtoCopyWith<$Res>  {
  factory $ProviderModelsResultDtoCopyWith(ProviderModelsResultDto value, $Res Function(ProviderModelsResultDto) _then) = _$ProviderModelsResultDtoCopyWithImpl;
@useResult
$Res call({
 List<ProviderModelDto> models
});




}
/// @nodoc
class _$ProviderModelsResultDtoCopyWithImpl<$Res>
    implements $ProviderModelsResultDtoCopyWith<$Res> {
  _$ProviderModelsResultDtoCopyWithImpl(this._self, this._then);

  final ProviderModelsResultDto _self;
  final $Res Function(ProviderModelsResultDto) _then;

/// Create a copy of ProviderModelsResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? models = null,}) {
  return _then(ProviderModelsResultDto(
models: null == models ? _self.models : models // ignore: cast_nullable_to_non_nullable
as List<ProviderModelDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [ProviderModelsResultDto].
extension ProviderModelsResultDtoPatterns on ProviderModelsResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderModelsResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderModelsResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderModelsResultDto value)  $default,){
final _that = this;
switch (_that) {
case _ProviderModelsResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderModelsResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderModelsResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ProviderModelDto> models)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderModelsResultDto() when $default != null:
return $default(_that.models);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ProviderModelDto> models)  $default,) {final _that = this;
switch (_that) {
case _ProviderModelsResultDto():
return $default(_that.models);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ProviderModelDto> models)?  $default,) {final _that = this;
switch (_that) {
case _ProviderModelsResultDto() when $default != null:
return $default(_that.models);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProviderModelsResultDto implements ProviderModelsResultDto {
  const _ProviderModelsResultDto({required  List<ProviderModelDto> models}): _models = models;
  factory _ProviderModelsResultDto.fromJson(Map<String, dynamic> json) => _$ProviderModelsResultDtoFromJson(json);

 final  List<ProviderModelDto> _models;
@override List<ProviderModelDto> get models {
  if (_models is EqualUnmodifiableListView) return _models;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_models);
}


/// Create a copy of ProviderModelsResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderModelsResultDtoCopyWith<_ProviderModelsResultDto> get copyWith => __$ProviderModelsResultDtoCopyWithImpl<_ProviderModelsResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderModelsResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderModelsResultDto&&const DeepCollectionEquality().equals(other._models, _models));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_models));

@override
String toString() {
  return 'ProviderModelsResultDto(models: $models)';
}


}

/// @nodoc
abstract mixin class _$ProviderModelsResultDtoCopyWith<$Res> implements $ProviderModelsResultDtoCopyWith<$Res> {
  factory _$ProviderModelsResultDtoCopyWith(_ProviderModelsResultDto value, $Res Function(_ProviderModelsResultDto) _then) = __$ProviderModelsResultDtoCopyWithImpl;
@override @useResult
$Res call({
 List<ProviderModelDto> models
});




}
/// @nodoc
class __$ProviderModelsResultDtoCopyWithImpl<$Res>
    implements _$ProviderModelsResultDtoCopyWith<$Res> {
  __$ProviderModelsResultDtoCopyWithImpl(this._self, this._then);

  final _ProviderModelsResultDto _self;
  final $Res Function(_ProviderModelsResultDto) _then;

/// Create a copy of ProviderModelsResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? models = null,}) {
  return _then(_ProviderModelsResultDto(
models: null == models ? _self._models : models // ignore: cast_nullable_to_non_nullable
as List<ProviderModelDto>,
  ));
}


}


/// @nodoc
mixin _$ProviderAuthAttemptResultDto {

 ProviderAuthAttemptDto get attempt;
/// Create a copy of ProviderAuthAttemptResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderAuthAttemptResultDtoCopyWith<ProviderAuthAttemptResultDto> get copyWith => _$ProviderAuthAttemptResultDtoCopyWithImpl<ProviderAuthAttemptResultDto>(this as ProviderAuthAttemptResultDto, _$identity);

  /// Serializes this ProviderAuthAttemptResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderAuthAttemptResultDto&&(identical(other.attempt, attempt) || other.attempt == attempt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,attempt);

@override
String toString() {
  return 'ProviderAuthAttemptResultDto(attempt: $attempt)';
}


}

/// @nodoc
abstract mixin class $ProviderAuthAttemptResultDtoCopyWith<$Res>  {
  factory $ProviderAuthAttemptResultDtoCopyWith(ProviderAuthAttemptResultDto value, $Res Function(ProviderAuthAttemptResultDto) _then) = _$ProviderAuthAttemptResultDtoCopyWithImpl;
@useResult
$Res call({
 ProviderAuthAttemptDto attempt
});


$ProviderAuthAttemptDtoCopyWith<$Res> get attempt;

}
/// @nodoc
class _$ProviderAuthAttemptResultDtoCopyWithImpl<$Res>
    implements $ProviderAuthAttemptResultDtoCopyWith<$Res> {
  _$ProviderAuthAttemptResultDtoCopyWithImpl(this._self, this._then);

  final ProviderAuthAttemptResultDto _self;
  final $Res Function(ProviderAuthAttemptResultDto) _then;

/// Create a copy of ProviderAuthAttemptResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? attempt = null,}) {
  return _then(ProviderAuthAttemptResultDto(
attempt: null == attempt ? _self.attempt : attempt // ignore: cast_nullable_to_non_nullable
as ProviderAuthAttemptDto,
  ));
}
/// Create a copy of ProviderAuthAttemptResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProviderAuthAttemptDtoCopyWith<$Res> get attempt {

  return $ProviderAuthAttemptDtoCopyWith<$Res>(_self.attempt, (value) {
    return _then(_self.copyWith(attempt: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProviderAuthAttemptResultDto].
extension ProviderAuthAttemptResultDtoPatterns on ProviderAuthAttemptResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderAuthAttemptResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderAuthAttemptResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderAuthAttemptResultDto value)  $default,){
final _that = this;
switch (_that) {
case _ProviderAuthAttemptResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderAuthAttemptResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderAuthAttemptResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ProviderAuthAttemptDto attempt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderAuthAttemptResultDto() when $default != null:
return $default(_that.attempt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ProviderAuthAttemptDto attempt)  $default,) {final _that = this;
switch (_that) {
case _ProviderAuthAttemptResultDto():
return $default(_that.attempt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ProviderAuthAttemptDto attempt)?  $default,) {final _that = this;
switch (_that) {
case _ProviderAuthAttemptResultDto() when $default != null:
return $default(_that.attempt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProviderAuthAttemptResultDto implements ProviderAuthAttemptResultDto {
  const _ProviderAuthAttemptResultDto({required this.attempt});
  factory _ProviderAuthAttemptResultDto.fromJson(Map<String, dynamic> json) => _$ProviderAuthAttemptResultDtoFromJson(json);

@override final  ProviderAuthAttemptDto attempt;

/// Create a copy of ProviderAuthAttemptResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderAuthAttemptResultDtoCopyWith<_ProviderAuthAttemptResultDto> get copyWith => __$ProviderAuthAttemptResultDtoCopyWithImpl<_ProviderAuthAttemptResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderAuthAttemptResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderAuthAttemptResultDto&&(identical(other.attempt, attempt) || other.attempt == attempt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,attempt);

@override
String toString() {
  return 'ProviderAuthAttemptResultDto(attempt: $attempt)';
}


}

/// @nodoc
abstract mixin class _$ProviderAuthAttemptResultDtoCopyWith<$Res> implements $ProviderAuthAttemptResultDtoCopyWith<$Res> {
  factory _$ProviderAuthAttemptResultDtoCopyWith(_ProviderAuthAttemptResultDto value, $Res Function(_ProviderAuthAttemptResultDto) _then) = __$ProviderAuthAttemptResultDtoCopyWithImpl;
@override @useResult
$Res call({
 ProviderAuthAttemptDto attempt
});


@override $ProviderAuthAttemptDtoCopyWith<$Res> get attempt;

}
/// @nodoc
class __$ProviderAuthAttemptResultDtoCopyWithImpl<$Res>
    implements _$ProviderAuthAttemptResultDtoCopyWith<$Res> {
  __$ProviderAuthAttemptResultDtoCopyWithImpl(this._self, this._then);

  final _ProviderAuthAttemptResultDto _self;
  final $Res Function(_ProviderAuthAttemptResultDto) _then;

/// Create a copy of ProviderAuthAttemptResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? attempt = null,}) {
  return _then(_ProviderAuthAttemptResultDto(
attempt: null == attempt ? _self.attempt : attempt // ignore: cast_nullable_to_non_nullable
as ProviderAuthAttemptDto,
  ));
}

/// Create a copy of ProviderAuthAttemptResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProviderAuthAttemptDtoCopyWith<$Res> get attempt {

  return $ProviderAuthAttemptDtoCopyWith<$Res>(_self.attempt, (value) {
    return _then(_self.copyWith(attempt: value));
  });
}
}


/// @nodoc
mixin _$ProviderDiagnosticResultDto {

 ProviderDiagnosticDto get diagnostic;
/// Create a copy of ProviderDiagnosticResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderDiagnosticResultDtoCopyWith<ProviderDiagnosticResultDto> get copyWith => _$ProviderDiagnosticResultDtoCopyWithImpl<ProviderDiagnosticResultDto>(this as ProviderDiagnosticResultDto, _$identity);

  /// Serializes this ProviderDiagnosticResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderDiagnosticResultDto&&(identical(other.diagnostic, diagnostic) || other.diagnostic == diagnostic));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,diagnostic);

@override
String toString() {
  return 'ProviderDiagnosticResultDto(diagnostic: $diagnostic)';
}


}

/// @nodoc
abstract mixin class $ProviderDiagnosticResultDtoCopyWith<$Res>  {
  factory $ProviderDiagnosticResultDtoCopyWith(ProviderDiagnosticResultDto value, $Res Function(ProviderDiagnosticResultDto) _then) = _$ProviderDiagnosticResultDtoCopyWithImpl;
@useResult
$Res call({
 ProviderDiagnosticDto diagnostic
});


$ProviderDiagnosticDtoCopyWith<$Res> get diagnostic;

}
/// @nodoc
class _$ProviderDiagnosticResultDtoCopyWithImpl<$Res>
    implements $ProviderDiagnosticResultDtoCopyWith<$Res> {
  _$ProviderDiagnosticResultDtoCopyWithImpl(this._self, this._then);

  final ProviderDiagnosticResultDto _self;
  final $Res Function(ProviderDiagnosticResultDto) _then;

/// Create a copy of ProviderDiagnosticResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? diagnostic = null,}) {
  return _then(ProviderDiagnosticResultDto(
diagnostic: null == diagnostic ? _self.diagnostic : diagnostic // ignore: cast_nullable_to_non_nullable
as ProviderDiagnosticDto,
  ));
}
/// Create a copy of ProviderDiagnosticResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProviderDiagnosticDtoCopyWith<$Res> get diagnostic {

  return $ProviderDiagnosticDtoCopyWith<$Res>(_self.diagnostic, (value) {
    return _then(_self.copyWith(diagnostic: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProviderDiagnosticResultDto].
extension ProviderDiagnosticResultDtoPatterns on ProviderDiagnosticResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderDiagnosticResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderDiagnosticResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderDiagnosticResultDto value)  $default,){
final _that = this;
switch (_that) {
case _ProviderDiagnosticResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderDiagnosticResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderDiagnosticResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ProviderDiagnosticDto diagnostic)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderDiagnosticResultDto() when $default != null:
return $default(_that.diagnostic);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ProviderDiagnosticDto diagnostic)  $default,) {final _that = this;
switch (_that) {
case _ProviderDiagnosticResultDto():
return $default(_that.diagnostic);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ProviderDiagnosticDto diagnostic)?  $default,) {final _that = this;
switch (_that) {
case _ProviderDiagnosticResultDto() when $default != null:
return $default(_that.diagnostic);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProviderDiagnosticResultDto implements ProviderDiagnosticResultDto {
  const _ProviderDiagnosticResultDto({required this.diagnostic});
  factory _ProviderDiagnosticResultDto.fromJson(Map<String, dynamic> json) => _$ProviderDiagnosticResultDtoFromJson(json);

@override final  ProviderDiagnosticDto diagnostic;

/// Create a copy of ProviderDiagnosticResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderDiagnosticResultDtoCopyWith<_ProviderDiagnosticResultDto> get copyWith => __$ProviderDiagnosticResultDtoCopyWithImpl<_ProviderDiagnosticResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderDiagnosticResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderDiagnosticResultDto&&(identical(other.diagnostic, diagnostic) || other.diagnostic == diagnostic));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,diagnostic);

@override
String toString() {
  return 'ProviderDiagnosticResultDto(diagnostic: $diagnostic)';
}


}

/// @nodoc
abstract mixin class _$ProviderDiagnosticResultDtoCopyWith<$Res> implements $ProviderDiagnosticResultDtoCopyWith<$Res> {
  factory _$ProviderDiagnosticResultDtoCopyWith(_ProviderDiagnosticResultDto value, $Res Function(_ProviderDiagnosticResultDto) _then) = __$ProviderDiagnosticResultDtoCopyWithImpl;
@override @useResult
$Res call({
 ProviderDiagnosticDto diagnostic
});


@override $ProviderDiagnosticDtoCopyWith<$Res> get diagnostic;

}
/// @nodoc
class __$ProviderDiagnosticResultDtoCopyWithImpl<$Res>
    implements _$ProviderDiagnosticResultDtoCopyWith<$Res> {
  __$ProviderDiagnosticResultDtoCopyWithImpl(this._self, this._then);

  final _ProviderDiagnosticResultDto _self;
  final $Res Function(_ProviderDiagnosticResultDto) _then;

/// Create a copy of ProviderDiagnosticResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? diagnostic = null,}) {
  return _then(_ProviderDiagnosticResultDto(
diagnostic: null == diagnostic ? _self.diagnostic : diagnostic // ignore: cast_nullable_to_non_nullable
as ProviderDiagnosticDto,
  ));
}

/// Create a copy of ProviderDiagnosticResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProviderDiagnosticDtoCopyWith<$Res> get diagnostic {

  return $ProviderDiagnosticDtoCopyWith<$Res>(_self.diagnostic, (value) {
    return _then(_self.copyWith(diagnostic: value));
  });
}
}


/// @nodoc
mixin _$TurnStartResultDto {

 bool get created;
/// Create a copy of TurnStartResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TurnStartResultDtoCopyWith<TurnStartResultDto> get copyWith => _$TurnStartResultDtoCopyWithImpl<TurnStartResultDto>(this as TurnStartResultDto, _$identity);

  /// Serializes this TurnStartResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TurnStartResultDto&&(identical(other.created, created) || other.created == created));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,created);

@override
String toString() {
  return 'TurnStartResultDto(created: $created)';
}


}

/// @nodoc
abstract mixin class $TurnStartResultDtoCopyWith<$Res>  {
  factory $TurnStartResultDtoCopyWith(TurnStartResultDto value, $Res Function(TurnStartResultDto) _then) = _$TurnStartResultDtoCopyWithImpl;
@useResult
$Res call({
 bool created
});




}
/// @nodoc
class _$TurnStartResultDtoCopyWithImpl<$Res>
    implements $TurnStartResultDtoCopyWith<$Res> {
  _$TurnStartResultDtoCopyWithImpl(this._self, this._then);

  final TurnStartResultDto _self;
  final $Res Function(TurnStartResultDto) _then;

/// Create a copy of TurnStartResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? created = null,}) {
  return _then(TurnStartResultDto(
created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TurnStartResultDto].
extension TurnStartResultDtoPatterns on TurnStartResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TurnStartResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TurnStartResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TurnStartResultDto value)  $default,){
final _that = this;
switch (_that) {
case _TurnStartResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TurnStartResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _TurnStartResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool created)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TurnStartResultDto() when $default != null:
return $default(_that.created);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool created)  $default,) {final _that = this;
switch (_that) {
case _TurnStartResultDto():
return $default(_that.created);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool created)?  $default,) {final _that = this;
switch (_that) {
case _TurnStartResultDto() when $default != null:
return $default(_that.created);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TurnStartResultDto implements TurnStartResultDto {
  const _TurnStartResultDto({required this.created});
  factory _TurnStartResultDto.fromJson(Map<String, dynamic> json) => _$TurnStartResultDtoFromJson(json);

@override final  bool created;

/// Create a copy of TurnStartResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TurnStartResultDtoCopyWith<_TurnStartResultDto> get copyWith => __$TurnStartResultDtoCopyWithImpl<_TurnStartResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TurnStartResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TurnStartResultDto&&(identical(other.created, created) || other.created == created));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,created);

@override
String toString() {
  return 'TurnStartResultDto(created: $created)';
}


}

/// @nodoc
abstract mixin class _$TurnStartResultDtoCopyWith<$Res> implements $TurnStartResultDtoCopyWith<$Res> {
  factory _$TurnStartResultDtoCopyWith(_TurnStartResultDto value, $Res Function(_TurnStartResultDto) _then) = __$TurnStartResultDtoCopyWithImpl;
@override @useResult
$Res call({
 bool created
});




}
/// @nodoc
class __$TurnStartResultDtoCopyWithImpl<$Res>
    implements _$TurnStartResultDtoCopyWith<$Res> {
  __$TurnStartResultDtoCopyWithImpl(this._self, this._then);

  final _TurnStartResultDto _self;
  final $Res Function(_TurnStartResultDto) _then;

/// Create a copy of TurnStartResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? created = null,}) {
  return _then(_TurnStartResultDto(
created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$ApprovalResultDto {

 ApprovalRequestDto get approval;
/// Create a copy of ApprovalResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApprovalResultDtoCopyWith<ApprovalResultDto> get copyWith => _$ApprovalResultDtoCopyWithImpl<ApprovalResultDto>(this as ApprovalResultDto, _$identity);

  /// Serializes this ApprovalResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApprovalResultDto&&(identical(other.approval, approval) || other.approval == approval));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,approval);

@override
String toString() {
  return 'ApprovalResultDto(approval: $approval)';
}


}

/// @nodoc
abstract mixin class $ApprovalResultDtoCopyWith<$Res>  {
  factory $ApprovalResultDtoCopyWith(ApprovalResultDto value, $Res Function(ApprovalResultDto) _then) = _$ApprovalResultDtoCopyWithImpl;
@useResult
$Res call({
 ApprovalRequestDto approval
});


$ApprovalRequestDtoCopyWith<$Res> get approval;

}
/// @nodoc
class _$ApprovalResultDtoCopyWithImpl<$Res>
    implements $ApprovalResultDtoCopyWith<$Res> {
  _$ApprovalResultDtoCopyWithImpl(this._self, this._then);

  final ApprovalResultDto _self;
  final $Res Function(ApprovalResultDto) _then;

/// Create a copy of ApprovalResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? approval = null,}) {
  return _then(ApprovalResultDto(
approval: null == approval ? _self.approval : approval // ignore: cast_nullable_to_non_nullable
as ApprovalRequestDto,
  ));
}
/// Create a copy of ApprovalResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApprovalRequestDtoCopyWith<$Res> get approval {

  return $ApprovalRequestDtoCopyWith<$Res>(_self.approval, (value) {
    return _then(_self.copyWith(approval: value));
  });
}
}


/// Adds pattern-matching-related methods to [ApprovalResultDto].
extension ApprovalResultDtoPatterns on ApprovalResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ApprovalResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ApprovalResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ApprovalResultDto value)  $default,){
final _that = this;
switch (_that) {
case _ApprovalResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ApprovalResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _ApprovalResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ApprovalRequestDto approval)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ApprovalResultDto() when $default != null:
return $default(_that.approval);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ApprovalRequestDto approval)  $default,) {final _that = this;
switch (_that) {
case _ApprovalResultDto():
return $default(_that.approval);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ApprovalRequestDto approval)?  $default,) {final _that = this;
switch (_that) {
case _ApprovalResultDto() when $default != null:
return $default(_that.approval);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ApprovalResultDto implements ApprovalResultDto {
  const _ApprovalResultDto({required this.approval});
  factory _ApprovalResultDto.fromJson(Map<String, dynamic> json) => _$ApprovalResultDtoFromJson(json);

@override final  ApprovalRequestDto approval;

/// Create a copy of ApprovalResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ApprovalResultDtoCopyWith<_ApprovalResultDto> get copyWith => __$ApprovalResultDtoCopyWithImpl<_ApprovalResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ApprovalResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ApprovalResultDto&&(identical(other.approval, approval) || other.approval == approval));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,approval);

@override
String toString() {
  return 'ApprovalResultDto(approval: $approval)';
}


}

/// @nodoc
abstract mixin class _$ApprovalResultDtoCopyWith<$Res> implements $ApprovalResultDtoCopyWith<$Res> {
  factory _$ApprovalResultDtoCopyWith(_ApprovalResultDto value, $Res Function(_ApprovalResultDto) _then) = __$ApprovalResultDtoCopyWithImpl;
@override @useResult
$Res call({
 ApprovalRequestDto approval
});


@override $ApprovalRequestDtoCopyWith<$Res> get approval;

}
/// @nodoc
class __$ApprovalResultDtoCopyWithImpl<$Res>
    implements _$ApprovalResultDtoCopyWith<$Res> {
  __$ApprovalResultDtoCopyWithImpl(this._self, this._then);

  final _ApprovalResultDto _self;
  final $Res Function(_ApprovalResultDto) _then;

/// Create a copy of ApprovalResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? approval = null,}) {
  return _then(_ApprovalResultDto(
approval: null == approval ? _self.approval : approval // ignore: cast_nullable_to_non_nullable
as ApprovalRequestDto,
  ));
}

/// Create a copy of ApprovalResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApprovalRequestDtoCopyWith<$Res> get approval {

  return $ApprovalRequestDtoCopyWith<$Res>(_self.approval, (value) {
    return _then(_self.copyWith(approval: value));
  });
}
}


/// @nodoc
mixin _$UserQuestionResultDto {

 UserQuestionRequestDto get request;
/// Create a copy of UserQuestionResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserQuestionResultDtoCopyWith<UserQuestionResultDto> get copyWith => _$UserQuestionResultDtoCopyWithImpl<UserQuestionResultDto>(this as UserQuestionResultDto, _$identity);

  /// Serializes this UserQuestionResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserQuestionResultDto&&(identical(other.request, request) || other.request == request));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,request);

@override
String toString() {
  return 'UserQuestionResultDto(request: $request)';
}


}

/// @nodoc
abstract mixin class $UserQuestionResultDtoCopyWith<$Res>  {
  factory $UserQuestionResultDtoCopyWith(UserQuestionResultDto value, $Res Function(UserQuestionResultDto) _then) = _$UserQuestionResultDtoCopyWithImpl;
@useResult
$Res call({
 UserQuestionRequestDto request
});


$UserQuestionRequestDtoCopyWith<$Res> get request;

}
/// @nodoc
class _$UserQuestionResultDtoCopyWithImpl<$Res>
    implements $UserQuestionResultDtoCopyWith<$Res> {
  _$UserQuestionResultDtoCopyWithImpl(this._self, this._then);

  final UserQuestionResultDto _self;
  final $Res Function(UserQuestionResultDto) _then;

/// Create a copy of UserQuestionResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? request = null,}) {
  return _then(UserQuestionResultDto(
request: null == request ? _self.request : request // ignore: cast_nullable_to_non_nullable
as UserQuestionRequestDto,
  ));
}
/// Create a copy of UserQuestionResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserQuestionRequestDtoCopyWith<$Res> get request {

  return $UserQuestionRequestDtoCopyWith<$Res>(_self.request, (value) {
    return _then(_self.copyWith(request: value));
  });
}
}


/// Adds pattern-matching-related methods to [UserQuestionResultDto].
extension UserQuestionResultDtoPatterns on UserQuestionResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserQuestionResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserQuestionResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserQuestionResultDto value)  $default,){
final _that = this;
switch (_that) {
case _UserQuestionResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserQuestionResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _UserQuestionResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( UserQuestionRequestDto request)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserQuestionResultDto() when $default != null:
return $default(_that.request);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( UserQuestionRequestDto request)  $default,) {final _that = this;
switch (_that) {
case _UserQuestionResultDto():
return $default(_that.request);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( UserQuestionRequestDto request)?  $default,) {final _that = this;
switch (_that) {
case _UserQuestionResultDto() when $default != null:
return $default(_that.request);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserQuestionResultDto implements UserQuestionResultDto {
  const _UserQuestionResultDto({required this.request});
  factory _UserQuestionResultDto.fromJson(Map<String, dynamic> json) => _$UserQuestionResultDtoFromJson(json);

@override final  UserQuestionRequestDto request;

/// Create a copy of UserQuestionResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserQuestionResultDtoCopyWith<_UserQuestionResultDto> get copyWith => __$UserQuestionResultDtoCopyWithImpl<_UserQuestionResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserQuestionResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserQuestionResultDto&&(identical(other.request, request) || other.request == request));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,request);

@override
String toString() {
  return 'UserQuestionResultDto(request: $request)';
}


}

/// @nodoc
abstract mixin class _$UserQuestionResultDtoCopyWith<$Res> implements $UserQuestionResultDtoCopyWith<$Res> {
  factory _$UserQuestionResultDtoCopyWith(_UserQuestionResultDto value, $Res Function(_UserQuestionResultDto) _then) = __$UserQuestionResultDtoCopyWithImpl;
@override @useResult
$Res call({
 UserQuestionRequestDto request
});


@override $UserQuestionRequestDtoCopyWith<$Res> get request;

}
/// @nodoc
class __$UserQuestionResultDtoCopyWithImpl<$Res>
    implements _$UserQuestionResultDtoCopyWith<$Res> {
  __$UserQuestionResultDtoCopyWithImpl(this._self, this._then);

  final _UserQuestionResultDto _self;
  final $Res Function(_UserQuestionResultDto) _then;

/// Create a copy of UserQuestionResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? request = null,}) {
  return _then(_UserQuestionResultDto(
request: null == request ? _self.request : request // ignore: cast_nullable_to_non_nullable
as UserQuestionRequestDto,
  ));
}

/// Create a copy of UserQuestionResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserQuestionRequestDtoCopyWith<$Res> get request {

  return $UserQuestionRequestDtoCopyWith<$Res>(_self.request, (value) {
    return _then(_self.copyWith(request: value));
  });
}
}


/// @nodoc
mixin _$TimelineResultDto {

 List<TimelineEventDto> get events;
/// Create a copy of TimelineResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TimelineResultDtoCopyWith<TimelineResultDto> get copyWith => _$TimelineResultDtoCopyWithImpl<TimelineResultDto>(this as TimelineResultDto, _$identity);

  /// Serializes this TimelineResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TimelineResultDto&&const DeepCollectionEquality().equals(other.events, events));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(events));

@override
String toString() {
  return 'TimelineResultDto(events: $events)';
}


}

/// @nodoc
abstract mixin class $TimelineResultDtoCopyWith<$Res>  {
  factory $TimelineResultDtoCopyWith(TimelineResultDto value, $Res Function(TimelineResultDto) _then) = _$TimelineResultDtoCopyWithImpl;
@useResult
$Res call({
 List<TimelineEventDto> events
});




}
/// @nodoc
class _$TimelineResultDtoCopyWithImpl<$Res>
    implements $TimelineResultDtoCopyWith<$Res> {
  _$TimelineResultDtoCopyWithImpl(this._self, this._then);

  final TimelineResultDto _self;
  final $Res Function(TimelineResultDto) _then;

/// Create a copy of TimelineResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? events = null,}) {
  return _then(TimelineResultDto(
events: null == events ? _self.events : events // ignore: cast_nullable_to_non_nullable
as List<TimelineEventDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [TimelineResultDto].
extension TimelineResultDtoPatterns on TimelineResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TimelineResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TimelineResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TimelineResultDto value)  $default,){
final _that = this;
switch (_that) {
case _TimelineResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TimelineResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _TimelineResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<TimelineEventDto> events)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TimelineResultDto() when $default != null:
return $default(_that.events);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<TimelineEventDto> events)  $default,) {final _that = this;
switch (_that) {
case _TimelineResultDto():
return $default(_that.events);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<TimelineEventDto> events)?  $default,) {final _that = this;
switch (_that) {
case _TimelineResultDto() when $default != null:
return $default(_that.events);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TimelineResultDto implements TimelineResultDto {
  const _TimelineResultDto({required  List<TimelineEventDto> events}): _events = events;
  factory _TimelineResultDto.fromJson(Map<String, dynamic> json) => _$TimelineResultDtoFromJson(json);

 final  List<TimelineEventDto> _events;
@override List<TimelineEventDto> get events {
  if (_events is EqualUnmodifiableListView) return _events;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_events);
}


/// Create a copy of TimelineResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TimelineResultDtoCopyWith<_TimelineResultDto> get copyWith => __$TimelineResultDtoCopyWithImpl<_TimelineResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TimelineResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TimelineResultDto&&const DeepCollectionEquality().equals(other._events, _events));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_events));

@override
String toString() {
  return 'TimelineResultDto(events: $events)';
}


}

/// @nodoc
abstract mixin class _$TimelineResultDtoCopyWith<$Res> implements $TimelineResultDtoCopyWith<$Res> {
  factory _$TimelineResultDtoCopyWith(_TimelineResultDto value, $Res Function(_TimelineResultDto) _then) = __$TimelineResultDtoCopyWithImpl;
@override @useResult
$Res call({
 List<TimelineEventDto> events
});




}
/// @nodoc
class __$TimelineResultDtoCopyWithImpl<$Res>
    implements _$TimelineResultDtoCopyWith<$Res> {
  __$TimelineResultDtoCopyWithImpl(this._self, this._then);

  final _TimelineResultDto _self;
  final $Res Function(_TimelineResultDto) _then;

/// Create a copy of TimelineResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? events = null,}) {
  return _then(_TimelineResultDto(
events: null == events ? _self._events : events // ignore: cast_nullable_to_non_nullable
as List<TimelineEventDto>,
  ));
}


}

// dart format on
