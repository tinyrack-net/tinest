// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $WorkspacesTable extends Workspaces
    with TableInfo<$WorkspacesTable, Workspace> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkspacesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rootPathMeta = const VerificationMeta(
    'rootPath',
  );
  @override
  late final GeneratedColumn<String> rootPath = GeneratedColumn<String>(
    'root_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, rootPath, kind, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workspaces';
  @override
  VerificationContext validateIntegrity(
    Insertable<Workspace> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('root_path')) {
      context.handle(
        _rootPathMeta,
        rootPath.isAcceptableOrUnknown(data['root_path']!, _rootPathMeta),
      );
    } else if (isInserting) {
      context.missing(_rootPathMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Workspace map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Workspace(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      rootPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_path'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WorkspacesTable createAlias(String alias) {
    return $WorkspacesTable(attachedDatabase, alias);
  }
}

class Workspace extends DataClass implements Insertable<Workspace> {
  /// The id public API member.
  final String id;

  /// The name public API member.
  final String name;

  /// The rootPath public API member.
  final String rootPath;

  /// Whether this workspace represents a Git repository or a directory.
  final String kind;

  /// The createdAt public API member.
  final DateTime createdAt;
  const Workspace({
    required this.id,
    required this.name,
    required this.rootPath,
    required this.kind,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['root_path'] = Variable<String>(rootPath);
    map['kind'] = Variable<String>(kind);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WorkspacesCompanion toCompanion(bool nullToAbsent) {
    return WorkspacesCompanion(
      id: Value(id),
      name: Value(name),
      rootPath: Value(rootPath),
      kind: Value(kind),
      createdAt: Value(createdAt),
    );
  }

  factory Workspace.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Workspace(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      rootPath: serializer.fromJson<String>(json['rootPath']),
      kind: serializer.fromJson<String>(json['kind']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'rootPath': serializer.toJson<String>(rootPath),
      'kind': serializer.toJson<String>(kind),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Workspace copyWith({
    String? id,
    String? name,
    String? rootPath,
    String? kind,
    DateTime? createdAt,
  }) => Workspace(
    id: id ?? this.id,
    name: name ?? this.name,
    rootPath: rootPath ?? this.rootPath,
    kind: kind ?? this.kind,
    createdAt: createdAt ?? this.createdAt,
  );
  Workspace copyWithCompanion(WorkspacesCompanion data) {
    return Workspace(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      rootPath: data.rootPath.present ? data.rootPath.value : this.rootPath,
      kind: data.kind.present ? data.kind.value : this.kind,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Workspace(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('rootPath: $rootPath, ')
          ..write('kind: $kind, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, rootPath, kind, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Workspace &&
          other.id == this.id &&
          other.name == this.name &&
          other.rootPath == this.rootPath &&
          other.kind == this.kind &&
          other.createdAt == this.createdAt);
}

class WorkspacesCompanion extends UpdateCompanion<Workspace> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> rootPath;
  final Value<String> kind;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const WorkspacesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.rootPath = const Value.absent(),
    this.kind = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkspacesCompanion.insert({
    required String id,
    required String name,
    required String rootPath,
    required String kind,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       rootPath = Value(rootPath),
       kind = Value(kind),
       createdAt = Value(createdAt);
  static Insertable<Workspace> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? rootPath,
    Expression<String>? kind,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (rootPath != null) 'root_path': rootPath,
      if (kind != null) 'kind': kind,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkspacesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? rootPath,
    Value<String>? kind,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return WorkspacesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      rootPath: rootPath ?? this.rootPath,
      kind: kind ?? this.kind,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rootPath.present) {
      map['root_path'] = Variable<String>(rootPath.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkspacesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('rootPath: $rootPath, ')
          ..write('kind: $kind, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorktreesTable extends Worktrees
    with TableInfo<$WorktreesTable, Worktree> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorktreesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workspaceIdMeta = const VerificationMeta(
    'workspaceId',
  );
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
    'workspace_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workspaces (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _branchMeta = const VerificationMeta('branch');
  @override
  late final GeneratedColumn<String> branch = GeneratedColumn<String>(
    'branch',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _headMeta = const VerificationMeta('head');
  @override
  late final GeneratedColumn<String> head = GeneratedColumn<String>(
    'head',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isTinestOwnedMeta = const VerificationMeta(
    'isTinestOwned',
  );
  @override
  late final GeneratedColumn<bool> isTinestOwned = GeneratedColumn<bool>(
    'is_tinest_owned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_tinest_owned" IN (0, 1))',
    ),
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    workspaceId,
    name,
    path,
    branch,
    head,
    kind,
    isTinestOwned,
    archivedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'worktrees';
  @override
  VerificationContext validateIntegrity(
    Insertable<Worktree> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
        _workspaceIdMeta,
        workspaceId.isAcceptableOrUnknown(
          data['workspace_id']!,
          _workspaceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('branch')) {
      context.handle(
        _branchMeta,
        branch.isAcceptableOrUnknown(data['branch']!, _branchMeta),
      );
    }
    if (data.containsKey('head')) {
      context.handle(
        _headMeta,
        head.isAcceptableOrUnknown(data['head']!, _headMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('is_tinest_owned')) {
      context.handle(
        _isTinestOwnedMeta,
        isTinestOwned.isAcceptableOrUnknown(
          data['is_tinest_owned']!,
          _isTinestOwnedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_isTinestOwnedMeta);
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Worktree map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Worktree(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      workspaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workspace_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      branch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch'],
      ),
      head: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}head'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      isTinestOwned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_tinest_owned'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WorktreesTable createAlias(String alias) {
    return $WorktreesTable(attachedDatabase, alias);
  }
}

class Worktree extends DataClass implements Insertable<Worktree> {
  /// Stable worktree identifier.
  final String id;

  /// Owning workspace identifier.
  final String workspaceId;

  /// Human-readable checkout name.
  final String name;

  /// Canonical checkout path.
  final String path;

  /// Checked-out branch, when this is a Git worktree.
  final String? branch;

  /// Current commit, when this is a Git worktree.
  final String? head;

  /// Worktree ownership and lifecycle kind.
  final String kind;

  /// Whether Tinest created and may remove the checkout directory.
  final bool isTinestOwned;

  /// Archive instant; null while visible in the workspace catalog.
  final DateTime? archivedAt;

  /// Creation instant.
  final DateTime createdAt;
  const Worktree({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.path,
    this.branch,
    this.head,
    required this.kind,
    required this.isTinestOwned,
    this.archivedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['name'] = Variable<String>(name);
    map['path'] = Variable<String>(path);
    if (!nullToAbsent || branch != null) {
      map['branch'] = Variable<String>(branch);
    }
    if (!nullToAbsent || head != null) {
      map['head'] = Variable<String>(head);
    }
    map['kind'] = Variable<String>(kind);
    map['is_tinest_owned'] = Variable<bool>(isTinestOwned);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WorktreesCompanion toCompanion(bool nullToAbsent) {
    return WorktreesCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      name: Value(name),
      path: Value(path),
      branch: branch == null && nullToAbsent
          ? const Value.absent()
          : Value(branch),
      head: head == null && nullToAbsent ? const Value.absent() : Value(head),
      kind: Value(kind),
      isTinestOwned: Value(isTinestOwned),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      createdAt: Value(createdAt),
    );
  }

  factory Worktree.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Worktree(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      name: serializer.fromJson<String>(json['name']),
      path: serializer.fromJson<String>(json['path']),
      branch: serializer.fromJson<String?>(json['branch']),
      head: serializer.fromJson<String?>(json['head']),
      kind: serializer.fromJson<String>(json['kind']),
      isTinestOwned: serializer.fromJson<bool>(json['isTinestOwned']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'name': serializer.toJson<String>(name),
      'path': serializer.toJson<String>(path),
      'branch': serializer.toJson<String?>(branch),
      'head': serializer.toJson<String?>(head),
      'kind': serializer.toJson<String>(kind),
      'isTinestOwned': serializer.toJson<bool>(isTinestOwned),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Worktree copyWith({
    String? id,
    String? workspaceId,
    String? name,
    String? path,
    Value<String?> branch = const Value.absent(),
    Value<String?> head = const Value.absent(),
    String? kind,
    bool? isTinestOwned,
    Value<DateTime?> archivedAt = const Value.absent(),
    DateTime? createdAt,
  }) => Worktree(
    id: id ?? this.id,
    workspaceId: workspaceId ?? this.workspaceId,
    name: name ?? this.name,
    path: path ?? this.path,
    branch: branch.present ? branch.value : this.branch,
    head: head.present ? head.value : this.head,
    kind: kind ?? this.kind,
    isTinestOwned: isTinestOwned ?? this.isTinestOwned,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  Worktree copyWithCompanion(WorktreesCompanion data) {
    return Worktree(
      id: data.id.present ? data.id.value : this.id,
      workspaceId: data.workspaceId.present
          ? data.workspaceId.value
          : this.workspaceId,
      name: data.name.present ? data.name.value : this.name,
      path: data.path.present ? data.path.value : this.path,
      branch: data.branch.present ? data.branch.value : this.branch,
      head: data.head.present ? data.head.value : this.head,
      kind: data.kind.present ? data.kind.value : this.kind,
      isTinestOwned: data.isTinestOwned.present
          ? data.isTinestOwned.value
          : this.isTinestOwned,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Worktree(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('name: $name, ')
          ..write('path: $path, ')
          ..write('branch: $branch, ')
          ..write('head: $head, ')
          ..write('kind: $kind, ')
          ..write('isTinestOwned: $isTinestOwned, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    workspaceId,
    name,
    path,
    branch,
    head,
    kind,
    isTinestOwned,
    archivedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Worktree &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.name == this.name &&
          other.path == this.path &&
          other.branch == this.branch &&
          other.head == this.head &&
          other.kind == this.kind &&
          other.isTinestOwned == this.isTinestOwned &&
          other.archivedAt == this.archivedAt &&
          other.createdAt == this.createdAt);
}

class WorktreesCompanion extends UpdateCompanion<Worktree> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> name;
  final Value<String> path;
  final Value<String?> branch;
  final Value<String?> head;
  final Value<String> kind;
  final Value<bool> isTinestOwned;
  final Value<DateTime?> archivedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const WorktreesCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.name = const Value.absent(),
    this.path = const Value.absent(),
    this.branch = const Value.absent(),
    this.head = const Value.absent(),
    this.kind = const Value.absent(),
    this.isTinestOwned = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorktreesCompanion.insert({
    required String id,
    required String workspaceId,
    required String name,
    required String path,
    this.branch = const Value.absent(),
    this.head = const Value.absent(),
    required String kind,
    required bool isTinestOwned,
    this.archivedAt = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       workspaceId = Value(workspaceId),
       name = Value(name),
       path = Value(path),
       kind = Value(kind),
       isTinestOwned = Value(isTinestOwned),
       createdAt = Value(createdAt);
  static Insertable<Worktree> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? name,
    Expression<String>? path,
    Expression<String>? branch,
    Expression<String>? head,
    Expression<String>? kind,
    Expression<bool>? isTinestOwned,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (name != null) 'name': name,
      if (path != null) 'path': path,
      if (branch != null) 'branch': branch,
      if (head != null) 'head': head,
      if (kind != null) 'kind': kind,
      if (isTinestOwned != null) 'is_tinest_owned': isTinestOwned,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorktreesCompanion copyWith({
    Value<String>? id,
    Value<String>? workspaceId,
    Value<String>? name,
    Value<String>? path,
    Value<String?>? branch,
    Value<String?>? head,
    Value<String>? kind,
    Value<bool>? isTinestOwned,
    Value<DateTime?>? archivedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return WorktreesCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      name: name ?? this.name,
      path: path ?? this.path,
      branch: branch ?? this.branch,
      head: head ?? this.head,
      kind: kind ?? this.kind,
      isTinestOwned: isTinestOwned ?? this.isTinestOwned,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (branch.present) {
      map['branch'] = Variable<String>(branch.value);
    }
    if (head.present) {
      map['head'] = Variable<String>(head.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (isTinestOwned.present) {
      map['is_tinest_owned'] = Variable<bool>(isTinestOwned.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorktreesCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('name: $name, ')
          ..write('path: $path, ')
          ..write('branch: $branch, ')
          ..write('head: $head, ')
          ..write('kind: $kind, ')
          ..write('isTinestOwned: $isTinestOwned, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _worktreeIdMeta = const VerificationMeta(
    'worktreeId',
  );
  @override
  late final GeneratedColumn<String> worktreeId = GeneratedColumn<String>(
    'worktree_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES worktrees (id)',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _agentDefinitionIdMeta = const VerificationMeta(
    'agentDefinitionId',
  );
  @override
  late final GeneratedColumn<String> agentDefinitionId =
      GeneratedColumn<String>(
        'agent_definition_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentSessionIdMeta = const VerificationMeta(
    'parentSessionId',
  );
  @override
  late final GeneratedColumn<String> parentSessionId = GeneratedColumn<String>(
    'parent_session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id)',
    ),
  );
  static const VerificationMeta _taskNameMeta = const VerificationMeta(
    'taskName',
  );
  @override
  late final GeneratedColumn<String> taskName = GeneratedColumn<String>(
    'task_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _agentPathMeta = const VerificationMeta(
    'agentPath',
  );
  @override
  late final GeneratedColumn<String> agentPath = GeneratedColumn<String>(
    'agent_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rootSessionIdMeta = const VerificationMeta(
    'rootSessionId',
  );
  @override
  late final GeneratedColumn<String> rootSessionId = GeneratedColumn<String>(
    'root_session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id)',
    ),
  );
  static const VerificationMeta _lifecycleMeta = const VerificationMeta(
    'lifecycle',
  );
  @override
  late final GeneratedColumn<String> lifecycle = GeneratedColumn<String>(
    'lifecycle',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeTurnIdMeta = const VerificationMeta(
    'activeTurnId',
  );
  @override
  late final GeneratedColumn<String> activeTurnId = GeneratedColumn<String>(
    'active_turn_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelControlsJsonMeta = const VerificationMeta(
    'modelControlsJson',
  );
  @override
  late final GeneratedColumn<String> modelControlsJson =
      GeneratedColumn<String>(
        'model_controls_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('{}'),
      );
  static const VerificationMeta _permissionModeMeta = const VerificationMeta(
    'permissionMode',
  );
  @override
  late final GeneratedColumn<String> permissionMode = GeneratedColumn<String>(
    'permission_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ask'),
  );
  static const VerificationMeta _currentContextEpochMeta =
      const VerificationMeta('currentContextEpoch');
  @override
  late final GeneratedColumn<int> currentContextEpoch = GeneratedColumn<int>(
    'current_context_epoch',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _contextTokensUsedMeta = const VerificationMeta(
    'contextTokensUsed',
  );
  @override
  late final GeneratedColumn<int> contextTokensUsed = GeneratedColumn<int>(
    'context_tokens_used',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _contextWindowTokensMeta =
      const VerificationMeta('contextWindowTokens');
  @override
  late final GeneratedColumn<int> contextWindowTokens = GeneratedColumn<int>(
    'context_window_tokens',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalCostUsdMeta = const VerificationMeta(
    'totalCostUsd',
  );
  @override
  late final GeneratedColumn<double> totalCostUsd = GeneratedColumn<double>(
    'total_cost_usd',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hasCompleteCostMeta = const VerificationMeta(
    'hasCompleteCost',
  );
  @override
  late final GeneratedColumn<bool> hasCompleteCost = GeneratedColumn<bool>(
    'has_complete_cost',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_complete_cost" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    worktreeId,
    title,
    agentDefinitionId,
    origin,
    parentSessionId,
    taskName,
    agentPath,
    rootSessionId,
    lifecycle,
    status,
    activeTurnId,
    lastError,
    modelId,
    modelControlsJson,
    permissionMode,
    currentContextEpoch,
    contextTokensUsed,
    contextWindowTokens,
    totalCostUsd,
    hasCompleteCost,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Session> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('worktree_id')) {
      context.handle(
        _worktreeIdMeta,
        worktreeId.isAcceptableOrUnknown(data['worktree_id']!, _worktreeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_worktreeIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('agent_definition_id')) {
      context.handle(
        _agentDefinitionIdMeta,
        agentDefinitionId.isAcceptableOrUnknown(
          data['agent_definition_id']!,
          _agentDefinitionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_agentDefinitionIdMeta);
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    } else if (isInserting) {
      context.missing(_originMeta);
    }
    if (data.containsKey('parent_session_id')) {
      context.handle(
        _parentSessionIdMeta,
        parentSessionId.isAcceptableOrUnknown(
          data['parent_session_id']!,
          _parentSessionIdMeta,
        ),
      );
    }
    if (data.containsKey('task_name')) {
      context.handle(
        _taskNameMeta,
        taskName.isAcceptableOrUnknown(data['task_name']!, _taskNameMeta),
      );
    }
    if (data.containsKey('agent_path')) {
      context.handle(
        _agentPathMeta,
        agentPath.isAcceptableOrUnknown(data['agent_path']!, _agentPathMeta),
      );
    }
    if (data.containsKey('root_session_id')) {
      context.handle(
        _rootSessionIdMeta,
        rootSessionId.isAcceptableOrUnknown(
          data['root_session_id']!,
          _rootSessionIdMeta,
        ),
      );
    }
    if (data.containsKey('lifecycle')) {
      context.handle(
        _lifecycleMeta,
        lifecycle.isAcceptableOrUnknown(data['lifecycle']!, _lifecycleMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('active_turn_id')) {
      context.handle(
        _activeTurnIdMeta,
        activeTurnId.isAcceptableOrUnknown(
          data['active_turn_id']!,
          _activeTurnIdMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    }
    if (data.containsKey('model_controls_json')) {
      context.handle(
        _modelControlsJsonMeta,
        modelControlsJson.isAcceptableOrUnknown(
          data['model_controls_json']!,
          _modelControlsJsonMeta,
        ),
      );
    }
    if (data.containsKey('permission_mode')) {
      context.handle(
        _permissionModeMeta,
        permissionMode.isAcceptableOrUnknown(
          data['permission_mode']!,
          _permissionModeMeta,
        ),
      );
    }
    if (data.containsKey('current_context_epoch')) {
      context.handle(
        _currentContextEpochMeta,
        currentContextEpoch.isAcceptableOrUnknown(
          data['current_context_epoch']!,
          _currentContextEpochMeta,
        ),
      );
    }
    if (data.containsKey('context_tokens_used')) {
      context.handle(
        _contextTokensUsedMeta,
        contextTokensUsed.isAcceptableOrUnknown(
          data['context_tokens_used']!,
          _contextTokensUsedMeta,
        ),
      );
    }
    if (data.containsKey('context_window_tokens')) {
      context.handle(
        _contextWindowTokensMeta,
        contextWindowTokens.isAcceptableOrUnknown(
          data['context_window_tokens']!,
          _contextWindowTokensMeta,
        ),
      );
    }
    if (data.containsKey('total_cost_usd')) {
      context.handle(
        _totalCostUsdMeta,
        totalCostUsd.isAcceptableOrUnknown(
          data['total_cost_usd']!,
          _totalCostUsdMeta,
        ),
      );
    }
    if (data.containsKey('has_complete_cost')) {
      context.handle(
        _hasCompleteCostMeta,
        hasCompleteCost.isAcceptableOrUnknown(
          data['has_complete_cost']!,
          _hasCompleteCostMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      worktreeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}worktree_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      agentDefinitionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_definition_id'],
      )!,
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      )!,
      parentSessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_session_id'],
      ),
      taskName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_name'],
      ),
      agentPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_path'],
      ),
      rootSessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_session_id'],
      ),
      lifecycle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lifecycle'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      activeTurnId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}active_turn_id'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      ),
      modelControlsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_controls_json'],
      )!,
      permissionMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}permission_mode'],
      )!,
      currentContextEpoch: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_context_epoch'],
      )!,
      contextTokensUsed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}context_tokens_used'],
      )!,
      contextWindowTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}context_window_tokens'],
      ),
      totalCostUsd: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_cost_usd'],
      )!,
      hasCompleteCost: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_complete_cost'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  /// The id public API member.
  final String id;

  /// The worktreeId public API member.
  final String worktreeId;

  /// The title public API member.
  final String title;

  /// Markdown agent definition resolved for each turn.
  final String agentDefinitionId;

  /// Whether this session was created directly or by delegation.
  final String origin;

  /// Parent session for delegated subagents.
  final String? parentSessionId;

  /// Leaf task name of a spawned subagent; null for root sessions.
  final String? taskName;

  /// Canonical collaboration path, e.g. `/root/task1/task_3`.
  final String? agentPath;

  /// Root session of the collaboration tree; null for root sessions.
  final String? rootSessionId;

  /// Collaboration lifecycle; null outside a collaboration tree.
  final String? lifecycle;

  /// The status public API member.
  final String status;

  /// The activeTurnId public API member.
  final String? activeTurnId;

  /// The lastError public API member.
  final String? lastError;

  /// Qualified model pinned for this session; null inherits the agent.
  final String? modelId;

  /// JSON-encoded typed model-control values for this session.
  final String modelControlsJson;

  /// Permission mode this session was pinned to when it was created.
  final String permissionMode;

  /// Live context window; `new_context` bumps it to hide older history.
  final int currentContextEpoch;

  /// Tokens the last response reported for the live window.
  final int contextTokensUsed;

  /// Context window of the model last resolved for this session.
  ///
  /// Cached on the row rather than looked up per read, so every session read
  /// path reports the same number as the turn that produced the usage.
  final int? contextWindowTokens;

  /// Exact accumulated USD cost while every usage event is priced.
  final double totalCostUsd;

  /// False permanently after a usage event cannot be priced exactly.
  final bool hasCompleteCost;

  /// The createdAt public API member.
  final DateTime createdAt;

  /// The updatedAt public API member.
  final DateTime updatedAt;
  const Session({
    required this.id,
    required this.worktreeId,
    required this.title,
    required this.agentDefinitionId,
    required this.origin,
    this.parentSessionId,
    this.taskName,
    this.agentPath,
    this.rootSessionId,
    this.lifecycle,
    required this.status,
    this.activeTurnId,
    this.lastError,
    this.modelId,
    required this.modelControlsJson,
    required this.permissionMode,
    required this.currentContextEpoch,
    required this.contextTokensUsed,
    this.contextWindowTokens,
    required this.totalCostUsd,
    required this.hasCompleteCost,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['worktree_id'] = Variable<String>(worktreeId);
    map['title'] = Variable<String>(title);
    map['agent_definition_id'] = Variable<String>(agentDefinitionId);
    map['origin'] = Variable<String>(origin);
    if (!nullToAbsent || parentSessionId != null) {
      map['parent_session_id'] = Variable<String>(parentSessionId);
    }
    if (!nullToAbsent || taskName != null) {
      map['task_name'] = Variable<String>(taskName);
    }
    if (!nullToAbsent || agentPath != null) {
      map['agent_path'] = Variable<String>(agentPath);
    }
    if (!nullToAbsent || rootSessionId != null) {
      map['root_session_id'] = Variable<String>(rootSessionId);
    }
    if (!nullToAbsent || lifecycle != null) {
      map['lifecycle'] = Variable<String>(lifecycle);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || activeTurnId != null) {
      map['active_turn_id'] = Variable<String>(activeTurnId);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || modelId != null) {
      map['model_id'] = Variable<String>(modelId);
    }
    map['model_controls_json'] = Variable<String>(modelControlsJson);
    map['permission_mode'] = Variable<String>(permissionMode);
    map['current_context_epoch'] = Variable<int>(currentContextEpoch);
    map['context_tokens_used'] = Variable<int>(contextTokensUsed);
    if (!nullToAbsent || contextWindowTokens != null) {
      map['context_window_tokens'] = Variable<int>(contextWindowTokens);
    }
    map['total_cost_usd'] = Variable<double>(totalCostUsd);
    map['has_complete_cost'] = Variable<bool>(hasCompleteCost);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      worktreeId: Value(worktreeId),
      title: Value(title),
      agentDefinitionId: Value(agentDefinitionId),
      origin: Value(origin),
      parentSessionId: parentSessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentSessionId),
      taskName: taskName == null && nullToAbsent
          ? const Value.absent()
          : Value(taskName),
      agentPath: agentPath == null && nullToAbsent
          ? const Value.absent()
          : Value(agentPath),
      rootSessionId: rootSessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(rootSessionId),
      lifecycle: lifecycle == null && nullToAbsent
          ? const Value.absent()
          : Value(lifecycle),
      status: Value(status),
      activeTurnId: activeTurnId == null && nullToAbsent
          ? const Value.absent()
          : Value(activeTurnId),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      modelId: modelId == null && nullToAbsent
          ? const Value.absent()
          : Value(modelId),
      modelControlsJson: Value(modelControlsJson),
      permissionMode: Value(permissionMode),
      currentContextEpoch: Value(currentContextEpoch),
      contextTokensUsed: Value(contextTokensUsed),
      contextWindowTokens: contextWindowTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(contextWindowTokens),
      totalCostUsd: Value(totalCostUsd),
      hasCompleteCost: Value(hasCompleteCost),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Session.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<String>(json['id']),
      worktreeId: serializer.fromJson<String>(json['worktreeId']),
      title: serializer.fromJson<String>(json['title']),
      agentDefinitionId: serializer.fromJson<String>(json['agentDefinitionId']),
      origin: serializer.fromJson<String>(json['origin']),
      parentSessionId: serializer.fromJson<String?>(json['parentSessionId']),
      taskName: serializer.fromJson<String?>(json['taskName']),
      agentPath: serializer.fromJson<String?>(json['agentPath']),
      rootSessionId: serializer.fromJson<String?>(json['rootSessionId']),
      lifecycle: serializer.fromJson<String?>(json['lifecycle']),
      status: serializer.fromJson<String>(json['status']),
      activeTurnId: serializer.fromJson<String?>(json['activeTurnId']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      modelId: serializer.fromJson<String?>(json['modelId']),
      modelControlsJson: serializer.fromJson<String>(json['modelControlsJson']),
      permissionMode: serializer.fromJson<String>(json['permissionMode']),
      currentContextEpoch: serializer.fromJson<int>(
        json['currentContextEpoch'],
      ),
      contextTokensUsed: serializer.fromJson<int>(json['contextTokensUsed']),
      contextWindowTokens: serializer.fromJson<int?>(
        json['contextWindowTokens'],
      ),
      totalCostUsd: serializer.fromJson<double>(json['totalCostUsd']),
      hasCompleteCost: serializer.fromJson<bool>(json['hasCompleteCost']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'worktreeId': serializer.toJson<String>(worktreeId),
      'title': serializer.toJson<String>(title),
      'agentDefinitionId': serializer.toJson<String>(agentDefinitionId),
      'origin': serializer.toJson<String>(origin),
      'parentSessionId': serializer.toJson<String?>(parentSessionId),
      'taskName': serializer.toJson<String?>(taskName),
      'agentPath': serializer.toJson<String?>(agentPath),
      'rootSessionId': serializer.toJson<String?>(rootSessionId),
      'lifecycle': serializer.toJson<String?>(lifecycle),
      'status': serializer.toJson<String>(status),
      'activeTurnId': serializer.toJson<String?>(activeTurnId),
      'lastError': serializer.toJson<String?>(lastError),
      'modelId': serializer.toJson<String?>(modelId),
      'modelControlsJson': serializer.toJson<String>(modelControlsJson),
      'permissionMode': serializer.toJson<String>(permissionMode),
      'currentContextEpoch': serializer.toJson<int>(currentContextEpoch),
      'contextTokensUsed': serializer.toJson<int>(contextTokensUsed),
      'contextWindowTokens': serializer.toJson<int?>(contextWindowTokens),
      'totalCostUsd': serializer.toJson<double>(totalCostUsd),
      'hasCompleteCost': serializer.toJson<bool>(hasCompleteCost),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Session copyWith({
    String? id,
    String? worktreeId,
    String? title,
    String? agentDefinitionId,
    String? origin,
    Value<String?> parentSessionId = const Value.absent(),
    Value<String?> taskName = const Value.absent(),
    Value<String?> agentPath = const Value.absent(),
    Value<String?> rootSessionId = const Value.absent(),
    Value<String?> lifecycle = const Value.absent(),
    String? status,
    Value<String?> activeTurnId = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    Value<String?> modelId = const Value.absent(),
    String? modelControlsJson,
    String? permissionMode,
    int? currentContextEpoch,
    int? contextTokensUsed,
    Value<int?> contextWindowTokens = const Value.absent(),
    double? totalCostUsd,
    bool? hasCompleteCost,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Session(
    id: id ?? this.id,
    worktreeId: worktreeId ?? this.worktreeId,
    title: title ?? this.title,
    agentDefinitionId: agentDefinitionId ?? this.agentDefinitionId,
    origin: origin ?? this.origin,
    parentSessionId: parentSessionId.present
        ? parentSessionId.value
        : this.parentSessionId,
    taskName: taskName.present ? taskName.value : this.taskName,
    agentPath: agentPath.present ? agentPath.value : this.agentPath,
    rootSessionId: rootSessionId.present
        ? rootSessionId.value
        : this.rootSessionId,
    lifecycle: lifecycle.present ? lifecycle.value : this.lifecycle,
    status: status ?? this.status,
    activeTurnId: activeTurnId.present ? activeTurnId.value : this.activeTurnId,
    lastError: lastError.present ? lastError.value : this.lastError,
    modelId: modelId.present ? modelId.value : this.modelId,
    modelControlsJson: modelControlsJson ?? this.modelControlsJson,
    permissionMode: permissionMode ?? this.permissionMode,
    currentContextEpoch: currentContextEpoch ?? this.currentContextEpoch,
    contextTokensUsed: contextTokensUsed ?? this.contextTokensUsed,
    contextWindowTokens: contextWindowTokens.present
        ? contextWindowTokens.value
        : this.contextWindowTokens,
    totalCostUsd: totalCostUsd ?? this.totalCostUsd,
    hasCompleteCost: hasCompleteCost ?? this.hasCompleteCost,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      worktreeId: data.worktreeId.present
          ? data.worktreeId.value
          : this.worktreeId,
      title: data.title.present ? data.title.value : this.title,
      agentDefinitionId: data.agentDefinitionId.present
          ? data.agentDefinitionId.value
          : this.agentDefinitionId,
      origin: data.origin.present ? data.origin.value : this.origin,
      parentSessionId: data.parentSessionId.present
          ? data.parentSessionId.value
          : this.parentSessionId,
      taskName: data.taskName.present ? data.taskName.value : this.taskName,
      agentPath: data.agentPath.present ? data.agentPath.value : this.agentPath,
      rootSessionId: data.rootSessionId.present
          ? data.rootSessionId.value
          : this.rootSessionId,
      lifecycle: data.lifecycle.present ? data.lifecycle.value : this.lifecycle,
      status: data.status.present ? data.status.value : this.status,
      activeTurnId: data.activeTurnId.present
          ? data.activeTurnId.value
          : this.activeTurnId,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      modelControlsJson: data.modelControlsJson.present
          ? data.modelControlsJson.value
          : this.modelControlsJson,
      permissionMode: data.permissionMode.present
          ? data.permissionMode.value
          : this.permissionMode,
      currentContextEpoch: data.currentContextEpoch.present
          ? data.currentContextEpoch.value
          : this.currentContextEpoch,
      contextTokensUsed: data.contextTokensUsed.present
          ? data.contextTokensUsed.value
          : this.contextTokensUsed,
      contextWindowTokens: data.contextWindowTokens.present
          ? data.contextWindowTokens.value
          : this.contextWindowTokens,
      totalCostUsd: data.totalCostUsd.present
          ? data.totalCostUsd.value
          : this.totalCostUsd,
      hasCompleteCost: data.hasCompleteCost.present
          ? data.hasCompleteCost.value
          : this.hasCompleteCost,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('worktreeId: $worktreeId, ')
          ..write('title: $title, ')
          ..write('agentDefinitionId: $agentDefinitionId, ')
          ..write('origin: $origin, ')
          ..write('parentSessionId: $parentSessionId, ')
          ..write('taskName: $taskName, ')
          ..write('agentPath: $agentPath, ')
          ..write('rootSessionId: $rootSessionId, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('status: $status, ')
          ..write('activeTurnId: $activeTurnId, ')
          ..write('lastError: $lastError, ')
          ..write('modelId: $modelId, ')
          ..write('modelControlsJson: $modelControlsJson, ')
          ..write('permissionMode: $permissionMode, ')
          ..write('currentContextEpoch: $currentContextEpoch, ')
          ..write('contextTokensUsed: $contextTokensUsed, ')
          ..write('contextWindowTokens: $contextWindowTokens, ')
          ..write('totalCostUsd: $totalCostUsd, ')
          ..write('hasCompleteCost: $hasCompleteCost, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    worktreeId,
    title,
    agentDefinitionId,
    origin,
    parentSessionId,
    taskName,
    agentPath,
    rootSessionId,
    lifecycle,
    status,
    activeTurnId,
    lastError,
    modelId,
    modelControlsJson,
    permissionMode,
    currentContextEpoch,
    contextTokensUsed,
    contextWindowTokens,
    totalCostUsd,
    hasCompleteCost,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.worktreeId == this.worktreeId &&
          other.title == this.title &&
          other.agentDefinitionId == this.agentDefinitionId &&
          other.origin == this.origin &&
          other.parentSessionId == this.parentSessionId &&
          other.taskName == this.taskName &&
          other.agentPath == this.agentPath &&
          other.rootSessionId == this.rootSessionId &&
          other.lifecycle == this.lifecycle &&
          other.status == this.status &&
          other.activeTurnId == this.activeTurnId &&
          other.lastError == this.lastError &&
          other.modelId == this.modelId &&
          other.modelControlsJson == this.modelControlsJson &&
          other.permissionMode == this.permissionMode &&
          other.currentContextEpoch == this.currentContextEpoch &&
          other.contextTokensUsed == this.contextTokensUsed &&
          other.contextWindowTokens == this.contextWindowTokens &&
          other.totalCostUsd == this.totalCostUsd &&
          other.hasCompleteCost == this.hasCompleteCost &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<String> id;
  final Value<String> worktreeId;
  final Value<String> title;
  final Value<String> agentDefinitionId;
  final Value<String> origin;
  final Value<String?> parentSessionId;
  final Value<String?> taskName;
  final Value<String?> agentPath;
  final Value<String?> rootSessionId;
  final Value<String?> lifecycle;
  final Value<String> status;
  final Value<String?> activeTurnId;
  final Value<String?> lastError;
  final Value<String?> modelId;
  final Value<String> modelControlsJson;
  final Value<String> permissionMode;
  final Value<int> currentContextEpoch;
  final Value<int> contextTokensUsed;
  final Value<int?> contextWindowTokens;
  final Value<double> totalCostUsd;
  final Value<bool> hasCompleteCost;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.worktreeId = const Value.absent(),
    this.title = const Value.absent(),
    this.agentDefinitionId = const Value.absent(),
    this.origin = const Value.absent(),
    this.parentSessionId = const Value.absent(),
    this.taskName = const Value.absent(),
    this.agentPath = const Value.absent(),
    this.rootSessionId = const Value.absent(),
    this.lifecycle = const Value.absent(),
    this.status = const Value.absent(),
    this.activeTurnId = const Value.absent(),
    this.lastError = const Value.absent(),
    this.modelId = const Value.absent(),
    this.modelControlsJson = const Value.absent(),
    this.permissionMode = const Value.absent(),
    this.currentContextEpoch = const Value.absent(),
    this.contextTokensUsed = const Value.absent(),
    this.contextWindowTokens = const Value.absent(),
    this.totalCostUsd = const Value.absent(),
    this.hasCompleteCost = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String id,
    required String worktreeId,
    required String title,
    required String agentDefinitionId,
    required String origin,
    this.parentSessionId = const Value.absent(),
    this.taskName = const Value.absent(),
    this.agentPath = const Value.absent(),
    this.rootSessionId = const Value.absent(),
    this.lifecycle = const Value.absent(),
    required String status,
    this.activeTurnId = const Value.absent(),
    this.lastError = const Value.absent(),
    this.modelId = const Value.absent(),
    this.modelControlsJson = const Value.absent(),
    this.permissionMode = const Value.absent(),
    this.currentContextEpoch = const Value.absent(),
    this.contextTokensUsed = const Value.absent(),
    this.contextWindowTokens = const Value.absent(),
    this.totalCostUsd = const Value.absent(),
    this.hasCompleteCost = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       worktreeId = Value(worktreeId),
       title = Value(title),
       agentDefinitionId = Value(agentDefinitionId),
       origin = Value(origin),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Session> custom({
    Expression<String>? id,
    Expression<String>? worktreeId,
    Expression<String>? title,
    Expression<String>? agentDefinitionId,
    Expression<String>? origin,
    Expression<String>? parentSessionId,
    Expression<String>? taskName,
    Expression<String>? agentPath,
    Expression<String>? rootSessionId,
    Expression<String>? lifecycle,
    Expression<String>? status,
    Expression<String>? activeTurnId,
    Expression<String>? lastError,
    Expression<String>? modelId,
    Expression<String>? modelControlsJson,
    Expression<String>? permissionMode,
    Expression<int>? currentContextEpoch,
    Expression<int>? contextTokensUsed,
    Expression<int>? contextWindowTokens,
    Expression<double>? totalCostUsd,
    Expression<bool>? hasCompleteCost,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (worktreeId != null) 'worktree_id': worktreeId,
      if (title != null) 'title': title,
      if (agentDefinitionId != null) 'agent_definition_id': agentDefinitionId,
      if (origin != null) 'origin': origin,
      if (parentSessionId != null) 'parent_session_id': parentSessionId,
      if (taskName != null) 'task_name': taskName,
      if (agentPath != null) 'agent_path': agentPath,
      if (rootSessionId != null) 'root_session_id': rootSessionId,
      if (lifecycle != null) 'lifecycle': lifecycle,
      if (status != null) 'status': status,
      if (activeTurnId != null) 'active_turn_id': activeTurnId,
      if (lastError != null) 'last_error': lastError,
      if (modelId != null) 'model_id': modelId,
      if (modelControlsJson != null) 'model_controls_json': modelControlsJson,
      if (permissionMode != null) 'permission_mode': permissionMode,
      if (currentContextEpoch != null)
        'current_context_epoch': currentContextEpoch,
      if (contextTokensUsed != null) 'context_tokens_used': contextTokensUsed,
      if (contextWindowTokens != null)
        'context_window_tokens': contextWindowTokens,
      if (totalCostUsd != null) 'total_cost_usd': totalCostUsd,
      if (hasCompleteCost != null) 'has_complete_cost': hasCompleteCost,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? worktreeId,
    Value<String>? title,
    Value<String>? agentDefinitionId,
    Value<String>? origin,
    Value<String?>? parentSessionId,
    Value<String?>? taskName,
    Value<String?>? agentPath,
    Value<String?>? rootSessionId,
    Value<String?>? lifecycle,
    Value<String>? status,
    Value<String?>? activeTurnId,
    Value<String?>? lastError,
    Value<String?>? modelId,
    Value<String>? modelControlsJson,
    Value<String>? permissionMode,
    Value<int>? currentContextEpoch,
    Value<int>? contextTokensUsed,
    Value<int?>? contextWindowTokens,
    Value<double>? totalCostUsd,
    Value<bool>? hasCompleteCost,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      worktreeId: worktreeId ?? this.worktreeId,
      title: title ?? this.title,
      agentDefinitionId: agentDefinitionId ?? this.agentDefinitionId,
      origin: origin ?? this.origin,
      parentSessionId: parentSessionId ?? this.parentSessionId,
      taskName: taskName ?? this.taskName,
      agentPath: agentPath ?? this.agentPath,
      rootSessionId: rootSessionId ?? this.rootSessionId,
      lifecycle: lifecycle ?? this.lifecycle,
      status: status ?? this.status,
      activeTurnId: activeTurnId ?? this.activeTurnId,
      lastError: lastError ?? this.lastError,
      modelId: modelId ?? this.modelId,
      modelControlsJson: modelControlsJson ?? this.modelControlsJson,
      permissionMode: permissionMode ?? this.permissionMode,
      currentContextEpoch: currentContextEpoch ?? this.currentContextEpoch,
      contextTokensUsed: contextTokensUsed ?? this.contextTokensUsed,
      contextWindowTokens: contextWindowTokens ?? this.contextWindowTokens,
      totalCostUsd: totalCostUsd ?? this.totalCostUsd,
      hasCompleteCost: hasCompleteCost ?? this.hasCompleteCost,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (worktreeId.present) {
      map['worktree_id'] = Variable<String>(worktreeId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (agentDefinitionId.present) {
      map['agent_definition_id'] = Variable<String>(agentDefinitionId.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (parentSessionId.present) {
      map['parent_session_id'] = Variable<String>(parentSessionId.value);
    }
    if (taskName.present) {
      map['task_name'] = Variable<String>(taskName.value);
    }
    if (agentPath.present) {
      map['agent_path'] = Variable<String>(agentPath.value);
    }
    if (rootSessionId.present) {
      map['root_session_id'] = Variable<String>(rootSessionId.value);
    }
    if (lifecycle.present) {
      map['lifecycle'] = Variable<String>(lifecycle.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (activeTurnId.present) {
      map['active_turn_id'] = Variable<String>(activeTurnId.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (modelControlsJson.present) {
      map['model_controls_json'] = Variable<String>(modelControlsJson.value);
    }
    if (permissionMode.present) {
      map['permission_mode'] = Variable<String>(permissionMode.value);
    }
    if (currentContextEpoch.present) {
      map['current_context_epoch'] = Variable<int>(currentContextEpoch.value);
    }
    if (contextTokensUsed.present) {
      map['context_tokens_used'] = Variable<int>(contextTokensUsed.value);
    }
    if (contextWindowTokens.present) {
      map['context_window_tokens'] = Variable<int>(contextWindowTokens.value);
    }
    if (totalCostUsd.present) {
      map['total_cost_usd'] = Variable<double>(totalCostUsd.value);
    }
    if (hasCompleteCost.present) {
      map['has_complete_cost'] = Variable<bool>(hasCompleteCost.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('worktreeId: $worktreeId, ')
          ..write('title: $title, ')
          ..write('agentDefinitionId: $agentDefinitionId, ')
          ..write('origin: $origin, ')
          ..write('parentSessionId: $parentSessionId, ')
          ..write('taskName: $taskName, ')
          ..write('agentPath: $agentPath, ')
          ..write('rootSessionId: $rootSessionId, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('status: $status, ')
          ..write('activeTurnId: $activeTurnId, ')
          ..write('lastError: $lastError, ')
          ..write('modelId: $modelId, ')
          ..write('modelControlsJson: $modelControlsJson, ')
          ..write('permissionMode: $permissionMode, ')
          ..write('currentContextEpoch: $currentContextEpoch, ')
          ..write('contextTokensUsed: $contextTokensUsed, ')
          ..write('contextWindowTokens: $contextWindowTokens, ')
          ..write('totalCostUsd: $totalCostUsd, ')
          ..write('hasCompleteCost: $hasCompleteCost, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TurnsTable extends Turns with TableInfo<$TurnsTable, Turn> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TurnsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id)',
    ),
  );
  static const VerificationMeta _promptMeta = const VerificationMeta('prompt');
  @override
  late final GeneratedColumn<String> prompt = GeneratedColumn<String>(
    'prompt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    prompt,
    status,
    error,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'turns';
  @override
  VerificationContext validateIntegrity(
    Insertable<Turn> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('prompt')) {
      context.handle(
        _promptMeta,
        prompt.isAcceptableOrUnknown(data['prompt']!, _promptMeta),
      );
    } else if (isInserting) {
      context.missing(_promptMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Turn map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Turn(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      prompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TurnsTable createAlias(String alias) {
    return $TurnsTable(attachedDatabase, alias);
  }
}

class Turn extends DataClass implements Insertable<Turn> {
  /// The id public API member.
  final String id;

  /// The sessionId public API member.
  final String sessionId;

  /// The prompt public API member.
  final String prompt;

  /// The status public API member.
  final String status;

  /// The error public API member.
  final String? error;

  /// The createdAt public API member.
  final DateTime createdAt;

  /// The updatedAt public API member.
  final DateTime updatedAt;
  const Turn({
    required this.id,
    required this.sessionId,
    required this.prompt,
    required this.status,
    this.error,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['prompt'] = Variable<String>(prompt);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TurnsCompanion toCompanion(bool nullToAbsent) {
    return TurnsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      prompt: Value(prompt),
      status: Value(status),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Turn.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Turn(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      prompt: serializer.fromJson<String>(json['prompt']),
      status: serializer.fromJson<String>(json['status']),
      error: serializer.fromJson<String?>(json['error']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'prompt': serializer.toJson<String>(prompt),
      'status': serializer.toJson<String>(status),
      'error': serializer.toJson<String?>(error),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Turn copyWith({
    String? id,
    String? sessionId,
    String? prompt,
    String? status,
    Value<String?> error = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Turn(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    prompt: prompt ?? this.prompt,
    status: status ?? this.status,
    error: error.present ? error.value : this.error,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Turn copyWithCompanion(TurnsCompanion data) {
    return Turn(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      prompt: data.prompt.present ? data.prompt.value : this.prompt,
      status: data.status.present ? data.status.value : this.status,
      error: data.error.present ? data.error.value : this.error,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Turn(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('prompt: $prompt, ')
          ..write('status: $status, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sessionId, prompt, status, error, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Turn &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.prompt == this.prompt &&
          other.status == this.status &&
          other.error == this.error &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TurnsCompanion extends UpdateCompanion<Turn> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> prompt;
  final Value<String> status;
  final Value<String?> error;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TurnsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.prompt = const Value.absent(),
    this.status = const Value.absent(),
    this.error = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TurnsCompanion.insert({
    required String id,
    required String sessionId,
    required String prompt,
    required String status,
    this.error = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       prompt = Value(prompt),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Turn> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? prompt,
    Expression<String>? status,
    Expression<String>? error,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (prompt != null) 'prompt': prompt,
      if (status != null) 'status': status,
      if (error != null) 'error': error,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TurnsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? prompt,
    Value<String>? status,
    Value<String?>? error,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TurnsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      prompt: prompt ?? this.prompt,
      status: status ?? this.status,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (prompt.present) {
      map['prompt'] = Variable<String>(prompt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TurnsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('prompt: $prompt, ')
          ..write('status: $status, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AgentMailboxMessagesTable extends AgentMailboxMessages
    with TableInfo<$AgentMailboxMessagesTable, AgentMailboxMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AgentMailboxMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id)',
    ),
  );
  static const VerificationMeta _senderSessionIdMeta = const VerificationMeta(
    'senderSessionId',
  );
  @override
  late final GeneratedColumn<String> senderSessionId = GeneratedColumn<String>(
    'sender_session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _senderPathMeta = const VerificationMeta(
    'senderPath',
  );
  @override
  late final GeneratedColumn<String> senderPath = GeneratedColumn<String>(
    'sender_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recipientPathMeta = const VerificationMeta(
    'recipientPath',
  );
  @override
  late final GeneratedColumn<String> recipientPath = GeneratedColumn<String>(
    'recipient_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageTypeMeta = const VerificationMeta(
    'messageType',
  );
  @override
  late final GeneratedColumn<String> messageType = GeneratedColumn<String>(
    'message_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _triggerTurnMeta = const VerificationMeta(
    'triggerTurn',
  );
  @override
  late final GeneratedColumn<bool> triggerTurn = GeneratedColumn<bool>(
    'trigger_turn',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("trigger_turn" IN (0, 1))',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deliveredAtMeta = const VerificationMeta(
    'deliveredAt',
  );
  @override
  late final GeneratedColumn<DateTime> deliveredAt = GeneratedColumn<DateTime>(
    'delivered_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    senderSessionId,
    senderPath,
    recipientPath,
    messageType,
    payload,
    triggerTurn,
    createdAt,
    deliveredAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agent_mailbox_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<AgentMailboxMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('sender_session_id')) {
      context.handle(
        _senderSessionIdMeta,
        senderSessionId.isAcceptableOrUnknown(
          data['sender_session_id']!,
          _senderSessionIdMeta,
        ),
      );
    }
    if (data.containsKey('sender_path')) {
      context.handle(
        _senderPathMeta,
        senderPath.isAcceptableOrUnknown(data['sender_path']!, _senderPathMeta),
      );
    } else if (isInserting) {
      context.missing(_senderPathMeta);
    }
    if (data.containsKey('recipient_path')) {
      context.handle(
        _recipientPathMeta,
        recipientPath.isAcceptableOrUnknown(
          data['recipient_path']!,
          _recipientPathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recipientPathMeta);
    }
    if (data.containsKey('message_type')) {
      context.handle(
        _messageTypeMeta,
        messageType.isAcceptableOrUnknown(
          data['message_type']!,
          _messageTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_messageTypeMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('trigger_turn')) {
      context.handle(
        _triggerTurnMeta,
        triggerTurn.isAcceptableOrUnknown(
          data['trigger_turn']!,
          _triggerTurnMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_triggerTurnMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('delivered_at')) {
      context.handle(
        _deliveredAtMeta,
        deliveredAt.isAcceptableOrUnknown(
          data['delivered_at']!,
          _deliveredAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AgentMailboxMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AgentMailboxMessage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      senderSessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_session_id'],
      ),
      senderPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_path'],
      )!,
      recipientPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipient_path'],
      )!,
      messageType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_type'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      triggerTurn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}trigger_turn'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      deliveredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}delivered_at'],
      ),
    );
  }

  @override
  $AgentMailboxMessagesTable createAlias(String alias) {
    return $AgentMailboxMessagesTable(attachedDatabase, alias);
  }
}

class AgentMailboxMessage extends DataClass
    implements Insertable<AgentMailboxMessage> {
  /// The id public API member.
  final String id;

  /// Recipient session.
  final String sessionId;

  /// Sender session; null when the daemon itself authored the message.
  final String? senderSessionId;

  /// Canonical path of the sender agent.
  final String senderPath;

  /// Canonical path of the recipient agent.
  final String recipientPath;

  /// Wire name of the protocol `InterAgentMessageType` enum value.
  final String messageType;

  /// Message body delivered inside the collaboration envelope.
  final String payload;

  /// Whether this message should start a turn on an idle recipient.
  final bool triggerTurn;

  /// The createdAt public API member.
  final DateTime createdAt;

  /// When the message was folded into a recipient turn; null while queued.
  final DateTime? deliveredAt;
  const AgentMailboxMessage({
    required this.id,
    required this.sessionId,
    this.senderSessionId,
    required this.senderPath,
    required this.recipientPath,
    required this.messageType,
    required this.payload,
    required this.triggerTurn,
    required this.createdAt,
    this.deliveredAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    if (!nullToAbsent || senderSessionId != null) {
      map['sender_session_id'] = Variable<String>(senderSessionId);
    }
    map['sender_path'] = Variable<String>(senderPath);
    map['recipient_path'] = Variable<String>(recipientPath);
    map['message_type'] = Variable<String>(messageType);
    map['payload'] = Variable<String>(payload);
    map['trigger_turn'] = Variable<bool>(triggerTurn);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || deliveredAt != null) {
      map['delivered_at'] = Variable<DateTime>(deliveredAt);
    }
    return map;
  }

  AgentMailboxMessagesCompanion toCompanion(bool nullToAbsent) {
    return AgentMailboxMessagesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      senderSessionId: senderSessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(senderSessionId),
      senderPath: Value(senderPath),
      recipientPath: Value(recipientPath),
      messageType: Value(messageType),
      payload: Value(payload),
      triggerTurn: Value(triggerTurn),
      createdAt: Value(createdAt),
      deliveredAt: deliveredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deliveredAt),
    );
  }

  factory AgentMailboxMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AgentMailboxMessage(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      senderSessionId: serializer.fromJson<String?>(json['senderSessionId']),
      senderPath: serializer.fromJson<String>(json['senderPath']),
      recipientPath: serializer.fromJson<String>(json['recipientPath']),
      messageType: serializer.fromJson<String>(json['messageType']),
      payload: serializer.fromJson<String>(json['payload']),
      triggerTurn: serializer.fromJson<bool>(json['triggerTurn']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deliveredAt: serializer.fromJson<DateTime?>(json['deliveredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'senderSessionId': serializer.toJson<String?>(senderSessionId),
      'senderPath': serializer.toJson<String>(senderPath),
      'recipientPath': serializer.toJson<String>(recipientPath),
      'messageType': serializer.toJson<String>(messageType),
      'payload': serializer.toJson<String>(payload),
      'triggerTurn': serializer.toJson<bool>(triggerTurn),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deliveredAt': serializer.toJson<DateTime?>(deliveredAt),
    };
  }

  AgentMailboxMessage copyWith({
    String? id,
    String? sessionId,
    Value<String?> senderSessionId = const Value.absent(),
    String? senderPath,
    String? recipientPath,
    String? messageType,
    String? payload,
    bool? triggerTurn,
    DateTime? createdAt,
    Value<DateTime?> deliveredAt = const Value.absent(),
  }) => AgentMailboxMessage(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    senderSessionId: senderSessionId.present
        ? senderSessionId.value
        : this.senderSessionId,
    senderPath: senderPath ?? this.senderPath,
    recipientPath: recipientPath ?? this.recipientPath,
    messageType: messageType ?? this.messageType,
    payload: payload ?? this.payload,
    triggerTurn: triggerTurn ?? this.triggerTurn,
    createdAt: createdAt ?? this.createdAt,
    deliveredAt: deliveredAt.present ? deliveredAt.value : this.deliveredAt,
  );
  AgentMailboxMessage copyWithCompanion(AgentMailboxMessagesCompanion data) {
    return AgentMailboxMessage(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      senderSessionId: data.senderSessionId.present
          ? data.senderSessionId.value
          : this.senderSessionId,
      senderPath: data.senderPath.present
          ? data.senderPath.value
          : this.senderPath,
      recipientPath: data.recipientPath.present
          ? data.recipientPath.value
          : this.recipientPath,
      messageType: data.messageType.present
          ? data.messageType.value
          : this.messageType,
      payload: data.payload.present ? data.payload.value : this.payload,
      triggerTurn: data.triggerTurn.present
          ? data.triggerTurn.value
          : this.triggerTurn,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deliveredAt: data.deliveredAt.present
          ? data.deliveredAt.value
          : this.deliveredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AgentMailboxMessage(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('senderSessionId: $senderSessionId, ')
          ..write('senderPath: $senderPath, ')
          ..write('recipientPath: $recipientPath, ')
          ..write('messageType: $messageType, ')
          ..write('payload: $payload, ')
          ..write('triggerTurn: $triggerTurn, ')
          ..write('createdAt: $createdAt, ')
          ..write('deliveredAt: $deliveredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    senderSessionId,
    senderPath,
    recipientPath,
    messageType,
    payload,
    triggerTurn,
    createdAt,
    deliveredAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentMailboxMessage &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.senderSessionId == this.senderSessionId &&
          other.senderPath == this.senderPath &&
          other.recipientPath == this.recipientPath &&
          other.messageType == this.messageType &&
          other.payload == this.payload &&
          other.triggerTurn == this.triggerTurn &&
          other.createdAt == this.createdAt &&
          other.deliveredAt == this.deliveredAt);
}

class AgentMailboxMessagesCompanion
    extends UpdateCompanion<AgentMailboxMessage> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String?> senderSessionId;
  final Value<String> senderPath;
  final Value<String> recipientPath;
  final Value<String> messageType;
  final Value<String> payload;
  final Value<bool> triggerTurn;
  final Value<DateTime> createdAt;
  final Value<DateTime?> deliveredAt;
  final Value<int> rowid;
  const AgentMailboxMessagesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.senderSessionId = const Value.absent(),
    this.senderPath = const Value.absent(),
    this.recipientPath = const Value.absent(),
    this.messageType = const Value.absent(),
    this.payload = const Value.absent(),
    this.triggerTurn = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deliveredAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AgentMailboxMessagesCompanion.insert({
    required String id,
    required String sessionId,
    this.senderSessionId = const Value.absent(),
    required String senderPath,
    required String recipientPath,
    required String messageType,
    required String payload,
    required bool triggerTurn,
    required DateTime createdAt,
    this.deliveredAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       senderPath = Value(senderPath),
       recipientPath = Value(recipientPath),
       messageType = Value(messageType),
       payload = Value(payload),
       triggerTurn = Value(triggerTurn),
       createdAt = Value(createdAt);
  static Insertable<AgentMailboxMessage> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? senderSessionId,
    Expression<String>? senderPath,
    Expression<String>? recipientPath,
    Expression<String>? messageType,
    Expression<String>? payload,
    Expression<bool>? triggerTurn,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deliveredAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (senderSessionId != null) 'sender_session_id': senderSessionId,
      if (senderPath != null) 'sender_path': senderPath,
      if (recipientPath != null) 'recipient_path': recipientPath,
      if (messageType != null) 'message_type': messageType,
      if (payload != null) 'payload': payload,
      if (triggerTurn != null) 'trigger_turn': triggerTurn,
      if (createdAt != null) 'created_at': createdAt,
      if (deliveredAt != null) 'delivered_at': deliveredAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AgentMailboxMessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String?>? senderSessionId,
    Value<String>? senderPath,
    Value<String>? recipientPath,
    Value<String>? messageType,
    Value<String>? payload,
    Value<bool>? triggerTurn,
    Value<DateTime>? createdAt,
    Value<DateTime?>? deliveredAt,
    Value<int>? rowid,
  }) {
    return AgentMailboxMessagesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      senderSessionId: senderSessionId ?? this.senderSessionId,
      senderPath: senderPath ?? this.senderPath,
      recipientPath: recipientPath ?? this.recipientPath,
      messageType: messageType ?? this.messageType,
      payload: payload ?? this.payload,
      triggerTurn: triggerTurn ?? this.triggerTurn,
      createdAt: createdAt ?? this.createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (senderSessionId.present) {
      map['sender_session_id'] = Variable<String>(senderSessionId.value);
    }
    if (senderPath.present) {
      map['sender_path'] = Variable<String>(senderPath.value);
    }
    if (recipientPath.present) {
      map['recipient_path'] = Variable<String>(recipientPath.value);
    }
    if (messageType.present) {
      map['message_type'] = Variable<String>(messageType.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (triggerTurn.present) {
      map['trigger_turn'] = Variable<bool>(triggerTurn.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deliveredAt.present) {
      map['delivered_at'] = Variable<DateTime>(deliveredAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AgentMailboxMessagesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('senderSessionId: $senderSessionId, ')
          ..write('senderPath: $senderPath, ')
          ..write('recipientPath: $recipientPath, ')
          ..write('messageType: $messageType, ')
          ..write('payload: $payload, ')
          ..write('triggerTurn: $triggerTurn, ')
          ..write('createdAt: $createdAt, ')
          ..write('deliveredAt: $deliveredAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttachmentsTable extends Attachments
    with TableInfo<$AttachmentsTable, Attachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byteSizeMeta = const VerificationMeta(
    'byteSize',
  );
  @override
  late final GeneratedColumn<int> byteSize = GeneratedColumn<int>(
    'byte_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fileName,
    mimeType,
    byteSize,
    kind,
    sha256,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<Attachment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('byte_size')) {
      context.handle(
        _byteSizeMeta,
        byteSize.isAcceptableOrUnknown(data['byte_size']!, _byteSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_byteSizeMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Attachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Attachment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      byteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_size'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AttachmentsTable createAlias(String alias) {
    return $AttachmentsTable(attachedDatabase, alias);
  }
}

class Attachment extends DataClass implements Insertable<Attachment> {
  /// Stable opaque identifier used as the storage key.
  final String id;

  /// Original display name, never used to construct a storage path.
  final String fileName;

  /// Validated media type.
  final String mimeType;

  /// Exact payload length.
  final int byteSize;

  /// Broad preview category.
  final String kind;

  /// Lower-case SHA-256 digest.
  final String sha256;

  /// Upload completion time.
  final DateTime createdAt;
  const Attachment({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
    required this.kind,
    required this.sha256,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['file_name'] = Variable<String>(fileName);
    map['mime_type'] = Variable<String>(mimeType);
    map['byte_size'] = Variable<int>(byteSize);
    map['kind'] = Variable<String>(kind);
    map['sha256'] = Variable<String>(sha256);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AttachmentsCompanion toCompanion(bool nullToAbsent) {
    return AttachmentsCompanion(
      id: Value(id),
      fileName: Value(fileName),
      mimeType: Value(mimeType),
      byteSize: Value(byteSize),
      kind: Value(kind),
      sha256: Value(sha256),
      createdAt: Value(createdAt),
    );
  }

  factory Attachment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Attachment(
      id: serializer.fromJson<String>(json['id']),
      fileName: serializer.fromJson<String>(json['fileName']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      byteSize: serializer.fromJson<int>(json['byteSize']),
      kind: serializer.fromJson<String>(json['kind']),
      sha256: serializer.fromJson<String>(json['sha256']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'fileName': serializer.toJson<String>(fileName),
      'mimeType': serializer.toJson<String>(mimeType),
      'byteSize': serializer.toJson<int>(byteSize),
      'kind': serializer.toJson<String>(kind),
      'sha256': serializer.toJson<String>(sha256),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Attachment copyWith({
    String? id,
    String? fileName,
    String? mimeType,
    int? byteSize,
    String? kind,
    String? sha256,
    DateTime? createdAt,
  }) => Attachment(
    id: id ?? this.id,
    fileName: fileName ?? this.fileName,
    mimeType: mimeType ?? this.mimeType,
    byteSize: byteSize ?? this.byteSize,
    kind: kind ?? this.kind,
    sha256: sha256 ?? this.sha256,
    createdAt: createdAt ?? this.createdAt,
  );
  Attachment copyWithCompanion(AttachmentsCompanion data) {
    return Attachment(
      id: data.id.present ? data.id.value : this.id,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      byteSize: data.byteSize.present ? data.byteSize.value : this.byteSize,
      kind: data.kind.present ? data.kind.value : this.kind,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Attachment(')
          ..write('id: $id, ')
          ..write('fileName: $fileName, ')
          ..write('mimeType: $mimeType, ')
          ..write('byteSize: $byteSize, ')
          ..write('kind: $kind, ')
          ..write('sha256: $sha256, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, fileName, mimeType, byteSize, kind, sha256, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Attachment &&
          other.id == this.id &&
          other.fileName == this.fileName &&
          other.mimeType == this.mimeType &&
          other.byteSize == this.byteSize &&
          other.kind == this.kind &&
          other.sha256 == this.sha256 &&
          other.createdAt == this.createdAt);
}

class AttachmentsCompanion extends UpdateCompanion<Attachment> {
  final Value<String> id;
  final Value<String> fileName;
  final Value<String> mimeType;
  final Value<int> byteSize;
  final Value<String> kind;
  final Value<String> sha256;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AttachmentsCompanion({
    this.id = const Value.absent(),
    this.fileName = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.kind = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttachmentsCompanion.insert({
    required String id,
    required String fileName,
    required String mimeType,
    required int byteSize,
    required String kind,
    required String sha256,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       fileName = Value(fileName),
       mimeType = Value(mimeType),
       byteSize = Value(byteSize),
       kind = Value(kind),
       sha256 = Value(sha256),
       createdAt = Value(createdAt);
  static Insertable<Attachment> custom({
    Expression<String>? id,
    Expression<String>? fileName,
    Expression<String>? mimeType,
    Expression<int>? byteSize,
    Expression<String>? kind,
    Expression<String>? sha256,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fileName != null) 'file_name': fileName,
      if (mimeType != null) 'mime_type': mimeType,
      if (byteSize != null) 'byte_size': byteSize,
      if (kind != null) 'kind': kind,
      if (sha256 != null) 'sha256': sha256,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttachmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? fileName,
    Value<String>? mimeType,
    Value<int>? byteSize,
    Value<String>? kind,
    Value<String>? sha256,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return AttachmentsCompanion(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      byteSize: byteSize ?? this.byteSize,
      kind: kind ?? this.kind,
      sha256: sha256 ?? this.sha256,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (byteSize.present) {
      map['byte_size'] = Variable<int>(byteSize.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('fileName: $fileName, ')
          ..write('mimeType: $mimeType, ')
          ..write('byteSize: $byteSize, ')
          ..write('kind: $kind, ')
          ..write('sha256: $sha256, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TurnAttachmentsTable extends TurnAttachments
    with TableInfo<$TurnAttachmentsTable, TurnAttachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TurnAttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _turnIdMeta = const VerificationMeta('turnId');
  @override
  late final GeneratedColumn<String> turnId = GeneratedColumn<String>(
    'turn_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES turns (id)',
    ),
  );
  static const VerificationMeta _attachmentIdMeta = const VerificationMeta(
    'attachmentId',
  );
  @override
  late final GeneratedColumn<String> attachmentId = GeneratedColumn<String>(
    'attachment_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES attachments (id)',
    ),
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    turnId,
    attachmentId,
    direction,
    ordinal,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'turn_attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<TurnAttachment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('turn_id')) {
      context.handle(
        _turnIdMeta,
        turnId.isAcceptableOrUnknown(data['turn_id']!, _turnIdMeta),
      );
    } else if (isInserting) {
      context.missing(_turnIdMeta);
    }
    if (data.containsKey('attachment_id')) {
      context.handle(
        _attachmentIdMeta,
        attachmentId.isAcceptableOrUnknown(
          data['attachment_id']!,
          _attachmentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attachmentIdMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {turnId, direction, ordinal};
  @override
  TurnAttachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TurnAttachment(
      turnId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}turn_id'],
      )!,
      attachmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_id'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
    );
  }

  @override
  $TurnAttachmentsTable createAlias(String alias) {
    return $TurnAttachmentsTable(attachedDatabase, alias);
  }
}

class TurnAttachment extends DataClass implements Insertable<TurnAttachment> {
  /// Owning turn.
  final String turnId;

  /// Attached immutable payload.
  final String attachmentId;

  /// `user` or `assistant`.
  final String direction;

  /// Stable order within the direction.
  final int ordinal;
  const TurnAttachment({
    required this.turnId,
    required this.attachmentId,
    required this.direction,
    required this.ordinal,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['turn_id'] = Variable<String>(turnId);
    map['attachment_id'] = Variable<String>(attachmentId);
    map['direction'] = Variable<String>(direction);
    map['ordinal'] = Variable<int>(ordinal);
    return map;
  }

  TurnAttachmentsCompanion toCompanion(bool nullToAbsent) {
    return TurnAttachmentsCompanion(
      turnId: Value(turnId),
      attachmentId: Value(attachmentId),
      direction: Value(direction),
      ordinal: Value(ordinal),
    );
  }

  factory TurnAttachment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TurnAttachment(
      turnId: serializer.fromJson<String>(json['turnId']),
      attachmentId: serializer.fromJson<String>(json['attachmentId']),
      direction: serializer.fromJson<String>(json['direction']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'turnId': serializer.toJson<String>(turnId),
      'attachmentId': serializer.toJson<String>(attachmentId),
      'direction': serializer.toJson<String>(direction),
      'ordinal': serializer.toJson<int>(ordinal),
    };
  }

  TurnAttachment copyWith({
    String? turnId,
    String? attachmentId,
    String? direction,
    int? ordinal,
  }) => TurnAttachment(
    turnId: turnId ?? this.turnId,
    attachmentId: attachmentId ?? this.attachmentId,
    direction: direction ?? this.direction,
    ordinal: ordinal ?? this.ordinal,
  );
  TurnAttachment copyWithCompanion(TurnAttachmentsCompanion data) {
    return TurnAttachment(
      turnId: data.turnId.present ? data.turnId.value : this.turnId,
      attachmentId: data.attachmentId.present
          ? data.attachmentId.value
          : this.attachmentId,
      direction: data.direction.present ? data.direction.value : this.direction,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TurnAttachment(')
          ..write('turnId: $turnId, ')
          ..write('attachmentId: $attachmentId, ')
          ..write('direction: $direction, ')
          ..write('ordinal: $ordinal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(turnId, attachmentId, direction, ordinal);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TurnAttachment &&
          other.turnId == this.turnId &&
          other.attachmentId == this.attachmentId &&
          other.direction == this.direction &&
          other.ordinal == this.ordinal);
}

class TurnAttachmentsCompanion extends UpdateCompanion<TurnAttachment> {
  final Value<String> turnId;
  final Value<String> attachmentId;
  final Value<String> direction;
  final Value<int> ordinal;
  final Value<int> rowid;
  const TurnAttachmentsCompanion({
    this.turnId = const Value.absent(),
    this.attachmentId = const Value.absent(),
    this.direction = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TurnAttachmentsCompanion.insert({
    required String turnId,
    required String attachmentId,
    required String direction,
    required int ordinal,
    this.rowid = const Value.absent(),
  }) : turnId = Value(turnId),
       attachmentId = Value(attachmentId),
       direction = Value(direction),
       ordinal = Value(ordinal);
  static Insertable<TurnAttachment> custom({
    Expression<String>? turnId,
    Expression<String>? attachmentId,
    Expression<String>? direction,
    Expression<int>? ordinal,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (turnId != null) 'turn_id': turnId,
      if (attachmentId != null) 'attachment_id': attachmentId,
      if (direction != null) 'direction': direction,
      if (ordinal != null) 'ordinal': ordinal,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TurnAttachmentsCompanion copyWith({
    Value<String>? turnId,
    Value<String>? attachmentId,
    Value<String>? direction,
    Value<int>? ordinal,
    Value<int>? rowid,
  }) {
    return TurnAttachmentsCompanion(
      turnId: turnId ?? this.turnId,
      attachmentId: attachmentId ?? this.attachmentId,
      direction: direction ?? this.direction,
      ordinal: ordinal ?? this.ordinal,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (turnId.present) {
      map['turn_id'] = Variable<String>(turnId.value);
    }
    if (attachmentId.present) {
      map['attachment_id'] = Variable<String>(attachmentId.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TurnAttachmentsCompanion(')
          ..write('turnId: $turnId, ')
          ..write('attachmentId: $attachmentId, ')
          ..write('direction: $direction, ')
          ..write('ordinal: $ordinal, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TimelineEventsTable extends TimelineEvents
    with TableInfo<$TimelineEventsTable, TimelineEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TimelineEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id)',
    ),
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _turnIdMeta = const VerificationMeta('turnId');
  @override
  late final GeneratedColumn<String> turnId = GeneratedColumn<String>(
    'turn_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    sequence,
    turnId,
    type,
    dataJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'timeline_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<TimelineEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('turn_id')) {
      context.handle(
        _turnIdMeta,
        turnId.isAcceptableOrUnknown(data['turn_id']!, _turnIdMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_dataJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId, sequence};
  @override
  TimelineEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TimelineEvent(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      turnId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}turn_id'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TimelineEventsTable createAlias(String alias) {
    return $TimelineEventsTable(attachedDatabase, alias);
  }
}

class TimelineEvent extends DataClass implements Insertable<TimelineEvent> {
  /// The sessionId public API member.
  final String sessionId;

  /// The sequence public API member.
  final int sequence;

  /// The turnId public API member.
  final String? turnId;

  /// The type public API member.
  final String type;

  /// The dataJson public API member.
  final String dataJson;

  /// The createdAt public API member.
  final DateTime createdAt;
  const TimelineEvent({
    required this.sessionId,
    required this.sequence,
    this.turnId,
    required this.type,
    required this.dataJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['sequence'] = Variable<int>(sequence);
    if (!nullToAbsent || turnId != null) {
      map['turn_id'] = Variable<String>(turnId);
    }
    map['type'] = Variable<String>(type);
    map['data_json'] = Variable<String>(dataJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TimelineEventsCompanion toCompanion(bool nullToAbsent) {
    return TimelineEventsCompanion(
      sessionId: Value(sessionId),
      sequence: Value(sequence),
      turnId: turnId == null && nullToAbsent
          ? const Value.absent()
          : Value(turnId),
      type: Value(type),
      dataJson: Value(dataJson),
      createdAt: Value(createdAt),
    );
  }

  factory TimelineEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TimelineEvent(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      sequence: serializer.fromJson<int>(json['sequence']),
      turnId: serializer.fromJson<String?>(json['turnId']),
      type: serializer.fromJson<String>(json['type']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'sequence': serializer.toJson<int>(sequence),
      'turnId': serializer.toJson<String?>(turnId),
      'type': serializer.toJson<String>(type),
      'dataJson': serializer.toJson<String>(dataJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TimelineEvent copyWith({
    String? sessionId,
    int? sequence,
    Value<String?> turnId = const Value.absent(),
    String? type,
    String? dataJson,
    DateTime? createdAt,
  }) => TimelineEvent(
    sessionId: sessionId ?? this.sessionId,
    sequence: sequence ?? this.sequence,
    turnId: turnId.present ? turnId.value : this.turnId,
    type: type ?? this.type,
    dataJson: dataJson ?? this.dataJson,
    createdAt: createdAt ?? this.createdAt,
  );
  TimelineEvent copyWithCompanion(TimelineEventsCompanion data) {
    return TimelineEvent(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      turnId: data.turnId.present ? data.turnId.value : this.turnId,
      type: data.type.present ? data.type.value : this.type,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TimelineEvent(')
          ..write('sessionId: $sessionId, ')
          ..write('sequence: $sequence, ')
          ..write('turnId: $turnId, ')
          ..write('type: $type, ')
          ..write('dataJson: $dataJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(sessionId, sequence, turnId, type, dataJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TimelineEvent &&
          other.sessionId == this.sessionId &&
          other.sequence == this.sequence &&
          other.turnId == this.turnId &&
          other.type == this.type &&
          other.dataJson == this.dataJson &&
          other.createdAt == this.createdAt);
}

class TimelineEventsCompanion extends UpdateCompanion<TimelineEvent> {
  final Value<String> sessionId;
  final Value<int> sequence;
  final Value<String?> turnId;
  final Value<String> type;
  final Value<String> dataJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TimelineEventsCompanion({
    this.sessionId = const Value.absent(),
    this.sequence = const Value.absent(),
    this.turnId = const Value.absent(),
    this.type = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TimelineEventsCompanion.insert({
    required String sessionId,
    required int sequence,
    this.turnId = const Value.absent(),
    required String type,
    required String dataJson,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       sequence = Value(sequence),
       type = Value(type),
       dataJson = Value(dataJson),
       createdAt = Value(createdAt);
  static Insertable<TimelineEvent> custom({
    Expression<String>? sessionId,
    Expression<int>? sequence,
    Expression<String>? turnId,
    Expression<String>? type,
    Expression<String>? dataJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (sequence != null) 'sequence': sequence,
      if (turnId != null) 'turn_id': turnId,
      if (type != null) 'type': type,
      if (dataJson != null) 'data_json': dataJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TimelineEventsCompanion copyWith({
    Value<String>? sessionId,
    Value<int>? sequence,
    Value<String?>? turnId,
    Value<String>? type,
    Value<String>? dataJson,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TimelineEventsCompanion(
      sessionId: sessionId ?? this.sessionId,
      sequence: sequence ?? this.sequence,
      turnId: turnId ?? this.turnId,
      type: type ?? this.type,
      dataJson: dataJson ?? this.dataJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (turnId.present) {
      map['turn_id'] = Variable<String>(turnId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TimelineEventsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('sequence: $sequence, ')
          ..write('turnId: $turnId, ')
          ..write('type: $type, ')
          ..write('dataJson: $dataJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ApprovalRequestsTable extends ApprovalRequests
    with TableInfo<$ApprovalRequestsTable, ApprovalRequest> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ApprovalRequestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id)',
    ),
  );
  static const VerificationMeta _turnIdMeta = const VerificationMeta('turnId');
  @override
  late final GeneratedColumn<String> turnId = GeneratedColumn<String>(
    'turn_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES turns (id)',
    ),
  );
  static const VerificationMeta _toolCallIdMeta = const VerificationMeta(
    'toolCallId',
  );
  @override
  late final GeneratedColumn<String> toolCallId = GeneratedColumn<String>(
    'tool_call_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toolNameMeta = const VerificationMeta(
    'toolName',
  );
  @override
  late final GeneratedColumn<String> toolName = GeneratedColumn<String>(
    'tool_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _riskMeta = const VerificationMeta('risk');
  @override
  late final GeneratedColumn<String> risk = GeneratedColumn<String>(
    'risk',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _argumentsJsonMeta = const VerificationMeta(
    'argumentsJson',
  );
  @override
  late final GeneratedColumn<String> argumentsJson = GeneratedColumn<String>(
    'arguments_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _previewMeta = const VerificationMeta(
    'preview',
  );
  @override
  late final GeneratedColumn<String> preview = GeneratedColumn<String>(
    'preview',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    turnId,
    toolCallId,
    toolName,
    risk,
    argumentsJson,
    preview,
    status,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'approval_requests';
  @override
  VerificationContext validateIntegrity(
    Insertable<ApprovalRequest> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('turn_id')) {
      context.handle(
        _turnIdMeta,
        turnId.isAcceptableOrUnknown(data['turn_id']!, _turnIdMeta),
      );
    } else if (isInserting) {
      context.missing(_turnIdMeta);
    }
    if (data.containsKey('tool_call_id')) {
      context.handle(
        _toolCallIdMeta,
        toolCallId.isAcceptableOrUnknown(
          data['tool_call_id']!,
          _toolCallIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_toolCallIdMeta);
    }
    if (data.containsKey('tool_name')) {
      context.handle(
        _toolNameMeta,
        toolName.isAcceptableOrUnknown(data['tool_name']!, _toolNameMeta),
      );
    } else if (isInserting) {
      context.missing(_toolNameMeta);
    }
    if (data.containsKey('risk')) {
      context.handle(
        _riskMeta,
        risk.isAcceptableOrUnknown(data['risk']!, _riskMeta),
      );
    } else if (isInserting) {
      context.missing(_riskMeta);
    }
    if (data.containsKey('arguments_json')) {
      context.handle(
        _argumentsJsonMeta,
        argumentsJson.isAcceptableOrUnknown(
          data['arguments_json']!,
          _argumentsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_argumentsJsonMeta);
    }
    if (data.containsKey('preview')) {
      context.handle(
        _previewMeta,
        preview.isAcceptableOrUnknown(data['preview']!, _previewMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ApprovalRequest map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ApprovalRequest(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      turnId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}turn_id'],
      )!,
      toolCallId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tool_call_id'],
      )!,
      toolName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tool_name'],
      )!,
      risk: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}risk'],
      )!,
      argumentsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}arguments_json'],
      )!,
      preview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preview'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ApprovalRequestsTable createAlias(String alias) {
    return $ApprovalRequestsTable(attachedDatabase, alias);
  }
}

class ApprovalRequest extends DataClass implements Insertable<ApprovalRequest> {
  /// The id public API member.
  final String id;

  /// The sessionId public API member.
  final String sessionId;

  /// The turnId public API member.
  final String turnId;

  /// The toolCallId public API member.
  final String toolCallId;

  /// The toolName public API member.
  final String toolName;

  /// The risk public API member.
  final String risk;

  /// The argumentsJson public API member.
  final String argumentsJson;

  /// The preview public API member.
  final String? preview;

  /// The status public API member.
  final String status;

  /// The createdAt public API member.
  final DateTime createdAt;
  const ApprovalRequest({
    required this.id,
    required this.sessionId,
    required this.turnId,
    required this.toolCallId,
    required this.toolName,
    required this.risk,
    required this.argumentsJson,
    this.preview,
    required this.status,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['turn_id'] = Variable<String>(turnId);
    map['tool_call_id'] = Variable<String>(toolCallId);
    map['tool_name'] = Variable<String>(toolName);
    map['risk'] = Variable<String>(risk);
    map['arguments_json'] = Variable<String>(argumentsJson);
    if (!nullToAbsent || preview != null) {
      map['preview'] = Variable<String>(preview);
    }
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ApprovalRequestsCompanion toCompanion(bool nullToAbsent) {
    return ApprovalRequestsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      turnId: Value(turnId),
      toolCallId: Value(toolCallId),
      toolName: Value(toolName),
      risk: Value(risk),
      argumentsJson: Value(argumentsJson),
      preview: preview == null && nullToAbsent
          ? const Value.absent()
          : Value(preview),
      status: Value(status),
      createdAt: Value(createdAt),
    );
  }

  factory ApprovalRequest.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ApprovalRequest(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      turnId: serializer.fromJson<String>(json['turnId']),
      toolCallId: serializer.fromJson<String>(json['toolCallId']),
      toolName: serializer.fromJson<String>(json['toolName']),
      risk: serializer.fromJson<String>(json['risk']),
      argumentsJson: serializer.fromJson<String>(json['argumentsJson']),
      preview: serializer.fromJson<String?>(json['preview']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'turnId': serializer.toJson<String>(turnId),
      'toolCallId': serializer.toJson<String>(toolCallId),
      'toolName': serializer.toJson<String>(toolName),
      'risk': serializer.toJson<String>(risk),
      'argumentsJson': serializer.toJson<String>(argumentsJson),
      'preview': serializer.toJson<String?>(preview),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ApprovalRequest copyWith({
    String? id,
    String? sessionId,
    String? turnId,
    String? toolCallId,
    String? toolName,
    String? risk,
    String? argumentsJson,
    Value<String?> preview = const Value.absent(),
    String? status,
    DateTime? createdAt,
  }) => ApprovalRequest(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    turnId: turnId ?? this.turnId,
    toolCallId: toolCallId ?? this.toolCallId,
    toolName: toolName ?? this.toolName,
    risk: risk ?? this.risk,
    argumentsJson: argumentsJson ?? this.argumentsJson,
    preview: preview.present ? preview.value : this.preview,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
  );
  ApprovalRequest copyWithCompanion(ApprovalRequestsCompanion data) {
    return ApprovalRequest(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      turnId: data.turnId.present ? data.turnId.value : this.turnId,
      toolCallId: data.toolCallId.present
          ? data.toolCallId.value
          : this.toolCallId,
      toolName: data.toolName.present ? data.toolName.value : this.toolName,
      risk: data.risk.present ? data.risk.value : this.risk,
      argumentsJson: data.argumentsJson.present
          ? data.argumentsJson.value
          : this.argumentsJson,
      preview: data.preview.present ? data.preview.value : this.preview,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ApprovalRequest(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('turnId: $turnId, ')
          ..write('toolCallId: $toolCallId, ')
          ..write('toolName: $toolName, ')
          ..write('risk: $risk, ')
          ..write('argumentsJson: $argumentsJson, ')
          ..write('preview: $preview, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    turnId,
    toolCallId,
    toolName,
    risk,
    argumentsJson,
    preview,
    status,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ApprovalRequest &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.turnId == this.turnId &&
          other.toolCallId == this.toolCallId &&
          other.toolName == this.toolName &&
          other.risk == this.risk &&
          other.argumentsJson == this.argumentsJson &&
          other.preview == this.preview &&
          other.status == this.status &&
          other.createdAt == this.createdAt);
}

class ApprovalRequestsCompanion extends UpdateCompanion<ApprovalRequest> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> turnId;
  final Value<String> toolCallId;
  final Value<String> toolName;
  final Value<String> risk;
  final Value<String> argumentsJson;
  final Value<String?> preview;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ApprovalRequestsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.turnId = const Value.absent(),
    this.toolCallId = const Value.absent(),
    this.toolName = const Value.absent(),
    this.risk = const Value.absent(),
    this.argumentsJson = const Value.absent(),
    this.preview = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ApprovalRequestsCompanion.insert({
    required String id,
    required String sessionId,
    required String turnId,
    required String toolCallId,
    required String toolName,
    required String risk,
    required String argumentsJson,
    this.preview = const Value.absent(),
    required String status,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       turnId = Value(turnId),
       toolCallId = Value(toolCallId),
       toolName = Value(toolName),
       risk = Value(risk),
       argumentsJson = Value(argumentsJson),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<ApprovalRequest> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? turnId,
    Expression<String>? toolCallId,
    Expression<String>? toolName,
    Expression<String>? risk,
    Expression<String>? argumentsJson,
    Expression<String>? preview,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (turnId != null) 'turn_id': turnId,
      if (toolCallId != null) 'tool_call_id': toolCallId,
      if (toolName != null) 'tool_name': toolName,
      if (risk != null) 'risk': risk,
      if (argumentsJson != null) 'arguments_json': argumentsJson,
      if (preview != null) 'preview': preview,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ApprovalRequestsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? turnId,
    Value<String>? toolCallId,
    Value<String>? toolName,
    Value<String>? risk,
    Value<String>? argumentsJson,
    Value<String?>? preview,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ApprovalRequestsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      turnId: turnId ?? this.turnId,
      toolCallId: toolCallId ?? this.toolCallId,
      toolName: toolName ?? this.toolName,
      risk: risk ?? this.risk,
      argumentsJson: argumentsJson ?? this.argumentsJson,
      preview: preview ?? this.preview,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (turnId.present) {
      map['turn_id'] = Variable<String>(turnId.value);
    }
    if (toolCallId.present) {
      map['tool_call_id'] = Variable<String>(toolCallId.value);
    }
    if (toolName.present) {
      map['tool_name'] = Variable<String>(toolName.value);
    }
    if (risk.present) {
      map['risk'] = Variable<String>(risk.value);
    }
    if (argumentsJson.present) {
      map['arguments_json'] = Variable<String>(argumentsJson.value);
    }
    if (preview.present) {
      map['preview'] = Variable<String>(preview.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ApprovalRequestsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('turnId: $turnId, ')
          ..write('toolCallId: $toolCallId, ')
          ..write('toolName: $toolName, ')
          ..write('risk: $risk, ')
          ..write('argumentsJson: $argumentsJson, ')
          ..write('preview: $preview, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserQuestionsTable extends UserQuestions
    with TableInfo<$UserQuestionsTable, UserQuestionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserQuestionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id)',
    ),
  );
  static const VerificationMeta _turnIdMeta = const VerificationMeta('turnId');
  @override
  late final GeneratedColumn<String> turnId = GeneratedColumn<String>(
    'turn_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES turns (id)',
    ),
  );
  static const VerificationMeta _toolCallIdMeta = const VerificationMeta(
    'toolCallId',
  );
  @override
  late final GeneratedColumn<String> toolCallId = GeneratedColumn<String>(
    'tool_call_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionsJsonMeta = const VerificationMeta(
    'questionsJson',
  );
  @override
  late final GeneratedColumn<String> questionsJson = GeneratedColumn<String>(
    'questions_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answersJsonMeta = const VerificationMeta(
    'answersJson',
  );
  @override
  late final GeneratedColumn<String> answersJson = GeneratedColumn<String>(
    'answers_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    turnId,
    toolCallId,
    questionsJson,
    answersJson,
    status,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_questions';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserQuestionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('turn_id')) {
      context.handle(
        _turnIdMeta,
        turnId.isAcceptableOrUnknown(data['turn_id']!, _turnIdMeta),
      );
    } else if (isInserting) {
      context.missing(_turnIdMeta);
    }
    if (data.containsKey('tool_call_id')) {
      context.handle(
        _toolCallIdMeta,
        toolCallId.isAcceptableOrUnknown(
          data['tool_call_id']!,
          _toolCallIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_toolCallIdMeta);
    }
    if (data.containsKey('questions_json')) {
      context.handle(
        _questionsJsonMeta,
        questionsJson.isAcceptableOrUnknown(
          data['questions_json']!,
          _questionsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_questionsJsonMeta);
    }
    if (data.containsKey('answers_json')) {
      context.handle(
        _answersJsonMeta,
        answersJson.isAcceptableOrUnknown(
          data['answers_json']!,
          _answersJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_answersJsonMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserQuestionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserQuestionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      turnId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}turn_id'],
      )!,
      toolCallId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tool_call_id'],
      )!,
      questionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}questions_json'],
      )!,
      answersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answers_json'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $UserQuestionsTable createAlias(String alias) {
    return $UserQuestionsTable(attachedDatabase, alias);
  }
}

class UserQuestionRow extends DataClass implements Insertable<UserQuestionRow> {
  /// The id public API member.
  final String id;

  /// The sessionId public API member.
  final String sessionId;

  /// The turnId public API member.
  final String turnId;

  /// The toolCallId public API member.
  final String toolCallId;

  /// The questions, serialized as a JSON array.
  final String questionsJson;

  /// The answers, serialized as a JSON array; empty while pending.
  final String answersJson;

  /// The status public API member.
  final String status;

  /// The createdAt public API member.
  final DateTime createdAt;
  const UserQuestionRow({
    required this.id,
    required this.sessionId,
    required this.turnId,
    required this.toolCallId,
    required this.questionsJson,
    required this.answersJson,
    required this.status,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['turn_id'] = Variable<String>(turnId);
    map['tool_call_id'] = Variable<String>(toolCallId);
    map['questions_json'] = Variable<String>(questionsJson);
    map['answers_json'] = Variable<String>(answersJson);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  UserQuestionsCompanion toCompanion(bool nullToAbsent) {
    return UserQuestionsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      turnId: Value(turnId),
      toolCallId: Value(toolCallId),
      questionsJson: Value(questionsJson),
      answersJson: Value(answersJson),
      status: Value(status),
      createdAt: Value(createdAt),
    );
  }

  factory UserQuestionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserQuestionRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      turnId: serializer.fromJson<String>(json['turnId']),
      toolCallId: serializer.fromJson<String>(json['toolCallId']),
      questionsJson: serializer.fromJson<String>(json['questionsJson']),
      answersJson: serializer.fromJson<String>(json['answersJson']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'turnId': serializer.toJson<String>(turnId),
      'toolCallId': serializer.toJson<String>(toolCallId),
      'questionsJson': serializer.toJson<String>(questionsJson),
      'answersJson': serializer.toJson<String>(answersJson),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  UserQuestionRow copyWith({
    String? id,
    String? sessionId,
    String? turnId,
    String? toolCallId,
    String? questionsJson,
    String? answersJson,
    String? status,
    DateTime? createdAt,
  }) => UserQuestionRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    turnId: turnId ?? this.turnId,
    toolCallId: toolCallId ?? this.toolCallId,
    questionsJson: questionsJson ?? this.questionsJson,
    answersJson: answersJson ?? this.answersJson,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
  );
  UserQuestionRow copyWithCompanion(UserQuestionsCompanion data) {
    return UserQuestionRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      turnId: data.turnId.present ? data.turnId.value : this.turnId,
      toolCallId: data.toolCallId.present
          ? data.toolCallId.value
          : this.toolCallId,
      questionsJson: data.questionsJson.present
          ? data.questionsJson.value
          : this.questionsJson,
      answersJson: data.answersJson.present
          ? data.answersJson.value
          : this.answersJson,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserQuestionRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('turnId: $turnId, ')
          ..write('toolCallId: $toolCallId, ')
          ..write('questionsJson: $questionsJson, ')
          ..write('answersJson: $answersJson, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    turnId,
    toolCallId,
    questionsJson,
    answersJson,
    status,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserQuestionRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.turnId == this.turnId &&
          other.toolCallId == this.toolCallId &&
          other.questionsJson == this.questionsJson &&
          other.answersJson == this.answersJson &&
          other.status == this.status &&
          other.createdAt == this.createdAt);
}

class UserQuestionsCompanion extends UpdateCompanion<UserQuestionRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> turnId;
  final Value<String> toolCallId;
  final Value<String> questionsJson;
  final Value<String> answersJson;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const UserQuestionsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.turnId = const Value.absent(),
    this.toolCallId = const Value.absent(),
    this.questionsJson = const Value.absent(),
    this.answersJson = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserQuestionsCompanion.insert({
    required String id,
    required String sessionId,
    required String turnId,
    required String toolCallId,
    required String questionsJson,
    required String answersJson,
    required String status,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       turnId = Value(turnId),
       toolCallId = Value(toolCallId),
       questionsJson = Value(questionsJson),
       answersJson = Value(answersJson),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<UserQuestionRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? turnId,
    Expression<String>? toolCallId,
    Expression<String>? questionsJson,
    Expression<String>? answersJson,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (turnId != null) 'turn_id': turnId,
      if (toolCallId != null) 'tool_call_id': toolCallId,
      if (questionsJson != null) 'questions_json': questionsJson,
      if (answersJson != null) 'answers_json': answersJson,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserQuestionsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? turnId,
    Value<String>? toolCallId,
    Value<String>? questionsJson,
    Value<String>? answersJson,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return UserQuestionsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      turnId: turnId ?? this.turnId,
      toolCallId: toolCallId ?? this.toolCallId,
      questionsJson: questionsJson ?? this.questionsJson,
      answersJson: answersJson ?? this.answersJson,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (turnId.present) {
      map['turn_id'] = Variable<String>(turnId.value);
    }
    if (toolCallId.present) {
      map['tool_call_id'] = Variable<String>(toolCallId.value);
    }
    if (questionsJson.present) {
      map['questions_json'] = Variable<String>(questionsJson.value);
    }
    if (answersJson.present) {
      map['answers_json'] = Variable<String>(answersJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserQuestionsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('turnId: $turnId, ')
          ..write('toolCallId: $toolCallId, ')
          ..write('questionsJson: $questionsJson, ')
          ..write('answersJson: $answersJson, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProviderStatesTable extends ProviderStates
    with TableInfo<$ProviderStatesTable, ProviderState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProviderStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id)',
    ),
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemJsonMeta = const VerificationMeta(
    'itemJson',
  );
  @override
  late final GeneratedColumn<String> itemJson = GeneratedColumn<String>(
    'item_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contextEpochMeta = const VerificationMeta(
    'contextEpoch',
  );
  @override
  late final GeneratedColumn<int> contextEpoch = GeneratedColumn<int>(
    'context_epoch',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    ordinal,
    itemJson,
    contextEpoch,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'provider_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProviderState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    if (data.containsKey('item_json')) {
      context.handle(
        _itemJsonMeta,
        itemJson.isAcceptableOrUnknown(data['item_json']!, _itemJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_itemJsonMeta);
    }
    if (data.containsKey('context_epoch')) {
      context.handle(
        _contextEpochMeta,
        contextEpoch.isAcceptableOrUnknown(
          data['context_epoch']!,
          _contextEpochMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId, ordinal};
  @override
  ProviderState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProviderState(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
      itemJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_json'],
      )!,
      contextEpoch: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}context_epoch'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ProviderStatesTable createAlias(String alias) {
    return $ProviderStatesTable(attachedDatabase, alias);
  }
}

class ProviderState extends DataClass implements Insertable<ProviderState> {
  /// The sessionId public API member.
  final String sessionId;

  /// The ordinal public API member.
  final int ordinal;

  /// The itemJson public API member.
  final String itemJson;

  /// Context window this item belongs to; older windows are never replayed.
  final int contextEpoch;

  /// The createdAt public API member.
  final DateTime createdAt;
  const ProviderState({
    required this.sessionId,
    required this.ordinal,
    required this.itemJson,
    required this.contextEpoch,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['ordinal'] = Variable<int>(ordinal);
    map['item_json'] = Variable<String>(itemJson);
    map['context_epoch'] = Variable<int>(contextEpoch);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ProviderStatesCompanion toCompanion(bool nullToAbsent) {
    return ProviderStatesCompanion(
      sessionId: Value(sessionId),
      ordinal: Value(ordinal),
      itemJson: Value(itemJson),
      contextEpoch: Value(contextEpoch),
      createdAt: Value(createdAt),
    );
  }

  factory ProviderState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProviderState(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
      itemJson: serializer.fromJson<String>(json['itemJson']),
      contextEpoch: serializer.fromJson<int>(json['contextEpoch']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'ordinal': serializer.toJson<int>(ordinal),
      'itemJson': serializer.toJson<String>(itemJson),
      'contextEpoch': serializer.toJson<int>(contextEpoch),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ProviderState copyWith({
    String? sessionId,
    int? ordinal,
    String? itemJson,
    int? contextEpoch,
    DateTime? createdAt,
  }) => ProviderState(
    sessionId: sessionId ?? this.sessionId,
    ordinal: ordinal ?? this.ordinal,
    itemJson: itemJson ?? this.itemJson,
    contextEpoch: contextEpoch ?? this.contextEpoch,
    createdAt: createdAt ?? this.createdAt,
  );
  ProviderState copyWithCompanion(ProviderStatesCompanion data) {
    return ProviderState(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      itemJson: data.itemJson.present ? data.itemJson.value : this.itemJson,
      contextEpoch: data.contextEpoch.present
          ? data.contextEpoch.value
          : this.contextEpoch,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProviderState(')
          ..write('sessionId: $sessionId, ')
          ..write('ordinal: $ordinal, ')
          ..write('itemJson: $itemJson, ')
          ..write('contextEpoch: $contextEpoch, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(sessionId, ordinal, itemJson, contextEpoch, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderState &&
          other.sessionId == this.sessionId &&
          other.ordinal == this.ordinal &&
          other.itemJson == this.itemJson &&
          other.contextEpoch == this.contextEpoch &&
          other.createdAt == this.createdAt);
}

class ProviderStatesCompanion extends UpdateCompanion<ProviderState> {
  final Value<String> sessionId;
  final Value<int> ordinal;
  final Value<String> itemJson;
  final Value<int> contextEpoch;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ProviderStatesCompanion({
    this.sessionId = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.itemJson = const Value.absent(),
    this.contextEpoch = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProviderStatesCompanion.insert({
    required String sessionId,
    required int ordinal,
    required String itemJson,
    this.contextEpoch = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       ordinal = Value(ordinal),
       itemJson = Value(itemJson),
       createdAt = Value(createdAt);
  static Insertable<ProviderState> custom({
    Expression<String>? sessionId,
    Expression<int>? ordinal,
    Expression<String>? itemJson,
    Expression<int>? contextEpoch,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (ordinal != null) 'ordinal': ordinal,
      if (itemJson != null) 'item_json': itemJson,
      if (contextEpoch != null) 'context_epoch': contextEpoch,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProviderStatesCompanion copyWith({
    Value<String>? sessionId,
    Value<int>? ordinal,
    Value<String>? itemJson,
    Value<int>? contextEpoch,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ProviderStatesCompanion(
      sessionId: sessionId ?? this.sessionId,
      ordinal: ordinal ?? this.ordinal,
      itemJson: itemJson ?? this.itemJson,
      contextEpoch: contextEpoch ?? this.contextEpoch,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (itemJson.present) {
      map['item_json'] = Variable<String>(itemJson.value);
    }
    if (contextEpoch.present) {
      map['context_epoch'] = Variable<int>(contextEpoch.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProviderStatesCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('ordinal: $ordinal, ')
          ..write('itemJson: $itemJson, ')
          ..write('contextEpoch: $contextEpoch, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  /// The key public API member.
  final String key;

  /// The value public API member.
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProviderConnectionsTable extends ProviderConnections
    with TableInfo<$ProviderConnectionsTable, ProviderConnection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProviderConnectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _definitionIdMeta = const VerificationMeta(
    'definitionId',
  );
  @override
  late final GeneratedColumn<String> definitionId = GeneratedColumn<String>(
    'definition_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelPrefixMeta = const VerificationMeta(
    'modelPrefix',
  );
  @override
  late final GeneratedColumn<String> modelPrefix = GeneratedColumn<String>(
    'model_prefix',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authKindMeta = const VerificationMeta(
    'authKind',
  );
  @override
  late final GeneratedColumn<String> authKind = GeneratedColumn<String>(
    'auth_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _credentialOriginMeta = const VerificationMeta(
    'credentialOrigin',
  );
  @override
  late final GeneratedColumn<String> credentialOrigin = GeneratedColumn<String>(
    'credential_origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customConfigJsonMeta = const VerificationMeta(
    'customConfigJson',
  );
  @override
  late final GeneratedColumn<String> customConfigJson = GeneratedColumn<String>(
    'custom_config_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    definitionId,
    modelPrefix,
    displayName,
    status,
    authKind,
    credentialOrigin,
    error,
    customConfigJson,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'provider_connections';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProviderConnection> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('definition_id')) {
      context.handle(
        _definitionIdMeta,
        definitionId.isAcceptableOrUnknown(
          data['definition_id']!,
          _definitionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_definitionIdMeta);
    }
    if (data.containsKey('model_prefix')) {
      context.handle(
        _modelPrefixMeta,
        modelPrefix.isAcceptableOrUnknown(
          data['model_prefix']!,
          _modelPrefixMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_modelPrefixMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('auth_kind')) {
      context.handle(
        _authKindMeta,
        authKind.isAcceptableOrUnknown(data['auth_kind']!, _authKindMeta),
      );
    } else if (isInserting) {
      context.missing(_authKindMeta);
    }
    if (data.containsKey('credential_origin')) {
      context.handle(
        _credentialOriginMeta,
        credentialOrigin.isAcceptableOrUnknown(
          data['credential_origin']!,
          _credentialOriginMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_credentialOriginMeta);
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('custom_config_json')) {
      context.handle(
        _customConfigJsonMeta,
        customConfigJson.isAcceptableOrUnknown(
          data['custom_config_json']!,
          _customConfigJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProviderConnection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProviderConnection(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      definitionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}definition_id'],
      )!,
      modelPrefix: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_prefix'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      authKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}auth_kind'],
      )!,
      credentialOrigin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}credential_origin'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      customConfigJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_config_json'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ProviderConnectionsTable createAlias(String alias) {
    return $ProviderConnectionsTable(attachedDatabase, alias);
  }
}

class ProviderConnection extends DataClass
    implements Insertable<ProviderConnection> {
  /// The id public API member.
  final String id;

  /// Built-in definition identifier, or `custom`.
  final String definitionId;

  /// Globally unique prefix used by qualified model identifiers.
  final String modelPrefix;

  /// Human-readable connection name.
  final String displayName;

  /// Current connection state.
  final String status;

  /// Active authentication kind.
  final String authKind;

  /// Non-secret credential origin.
  final String credentialOrigin;

  /// Last user-safe connection error.
  final String? error;

  /// Advanced custom configuration, never used by built-in definitions.
  final String? customConfigJson;

  /// The createdAt public API member.
  final DateTime createdAt;

  /// The updatedAt public API member.
  final DateTime updatedAt;
  const ProviderConnection({
    required this.id,
    required this.definitionId,
    required this.modelPrefix,
    required this.displayName,
    required this.status,
    required this.authKind,
    required this.credentialOrigin,
    this.error,
    this.customConfigJson,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['definition_id'] = Variable<String>(definitionId);
    map['model_prefix'] = Variable<String>(modelPrefix);
    map['display_name'] = Variable<String>(displayName);
    map['status'] = Variable<String>(status);
    map['auth_kind'] = Variable<String>(authKind);
    map['credential_origin'] = Variable<String>(credentialOrigin);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    if (!nullToAbsent || customConfigJson != null) {
      map['custom_config_json'] = Variable<String>(customConfigJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProviderConnectionsCompanion toCompanion(bool nullToAbsent) {
    return ProviderConnectionsCompanion(
      id: Value(id),
      definitionId: Value(definitionId),
      modelPrefix: Value(modelPrefix),
      displayName: Value(displayName),
      status: Value(status),
      authKind: Value(authKind),
      credentialOrigin: Value(credentialOrigin),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      customConfigJson: customConfigJson == null && nullToAbsent
          ? const Value.absent()
          : Value(customConfigJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProviderConnection.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProviderConnection(
      id: serializer.fromJson<String>(json['id']),
      definitionId: serializer.fromJson<String>(json['definitionId']),
      modelPrefix: serializer.fromJson<String>(json['modelPrefix']),
      displayName: serializer.fromJson<String>(json['displayName']),
      status: serializer.fromJson<String>(json['status']),
      authKind: serializer.fromJson<String>(json['authKind']),
      credentialOrigin: serializer.fromJson<String>(json['credentialOrigin']),
      error: serializer.fromJson<String?>(json['error']),
      customConfigJson: serializer.fromJson<String?>(json['customConfigJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'definitionId': serializer.toJson<String>(definitionId),
      'modelPrefix': serializer.toJson<String>(modelPrefix),
      'displayName': serializer.toJson<String>(displayName),
      'status': serializer.toJson<String>(status),
      'authKind': serializer.toJson<String>(authKind),
      'credentialOrigin': serializer.toJson<String>(credentialOrigin),
      'error': serializer.toJson<String?>(error),
      'customConfigJson': serializer.toJson<String?>(customConfigJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProviderConnection copyWith({
    String? id,
    String? definitionId,
    String? modelPrefix,
    String? displayName,
    String? status,
    String? authKind,
    String? credentialOrigin,
    Value<String?> error = const Value.absent(),
    Value<String?> customConfigJson = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ProviderConnection(
    id: id ?? this.id,
    definitionId: definitionId ?? this.definitionId,
    modelPrefix: modelPrefix ?? this.modelPrefix,
    displayName: displayName ?? this.displayName,
    status: status ?? this.status,
    authKind: authKind ?? this.authKind,
    credentialOrigin: credentialOrigin ?? this.credentialOrigin,
    error: error.present ? error.value : this.error,
    customConfigJson: customConfigJson.present
        ? customConfigJson.value
        : this.customConfigJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ProviderConnection copyWithCompanion(ProviderConnectionsCompanion data) {
    return ProviderConnection(
      id: data.id.present ? data.id.value : this.id,
      definitionId: data.definitionId.present
          ? data.definitionId.value
          : this.definitionId,
      modelPrefix: data.modelPrefix.present
          ? data.modelPrefix.value
          : this.modelPrefix,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      status: data.status.present ? data.status.value : this.status,
      authKind: data.authKind.present ? data.authKind.value : this.authKind,
      credentialOrigin: data.credentialOrigin.present
          ? data.credentialOrigin.value
          : this.credentialOrigin,
      error: data.error.present ? data.error.value : this.error,
      customConfigJson: data.customConfigJson.present
          ? data.customConfigJson.value
          : this.customConfigJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProviderConnection(')
          ..write('id: $id, ')
          ..write('definitionId: $definitionId, ')
          ..write('modelPrefix: $modelPrefix, ')
          ..write('displayName: $displayName, ')
          ..write('status: $status, ')
          ..write('authKind: $authKind, ')
          ..write('credentialOrigin: $credentialOrigin, ')
          ..write('error: $error, ')
          ..write('customConfigJson: $customConfigJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    definitionId,
    modelPrefix,
    displayName,
    status,
    authKind,
    credentialOrigin,
    error,
    customConfigJson,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderConnection &&
          other.id == this.id &&
          other.definitionId == this.definitionId &&
          other.modelPrefix == this.modelPrefix &&
          other.displayName == this.displayName &&
          other.status == this.status &&
          other.authKind == this.authKind &&
          other.credentialOrigin == this.credentialOrigin &&
          other.error == this.error &&
          other.customConfigJson == this.customConfigJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ProviderConnectionsCompanion extends UpdateCompanion<ProviderConnection> {
  final Value<String> id;
  final Value<String> definitionId;
  final Value<String> modelPrefix;
  final Value<String> displayName;
  final Value<String> status;
  final Value<String> authKind;
  final Value<String> credentialOrigin;
  final Value<String?> error;
  final Value<String?> customConfigJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProviderConnectionsCompanion({
    this.id = const Value.absent(),
    this.definitionId = const Value.absent(),
    this.modelPrefix = const Value.absent(),
    this.displayName = const Value.absent(),
    this.status = const Value.absent(),
    this.authKind = const Value.absent(),
    this.credentialOrigin = const Value.absent(),
    this.error = const Value.absent(),
    this.customConfigJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProviderConnectionsCompanion.insert({
    required String id,
    required String definitionId,
    required String modelPrefix,
    required String displayName,
    required String status,
    required String authKind,
    required String credentialOrigin,
    this.error = const Value.absent(),
    this.customConfigJson = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       definitionId = Value(definitionId),
       modelPrefix = Value(modelPrefix),
       displayName = Value(displayName),
       status = Value(status),
       authKind = Value(authKind),
       credentialOrigin = Value(credentialOrigin),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ProviderConnection> custom({
    Expression<String>? id,
    Expression<String>? definitionId,
    Expression<String>? modelPrefix,
    Expression<String>? displayName,
    Expression<String>? status,
    Expression<String>? authKind,
    Expression<String>? credentialOrigin,
    Expression<String>? error,
    Expression<String>? customConfigJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (definitionId != null) 'definition_id': definitionId,
      if (modelPrefix != null) 'model_prefix': modelPrefix,
      if (displayName != null) 'display_name': displayName,
      if (status != null) 'status': status,
      if (authKind != null) 'auth_kind': authKind,
      if (credentialOrigin != null) 'credential_origin': credentialOrigin,
      if (error != null) 'error': error,
      if (customConfigJson != null) 'custom_config_json': customConfigJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProviderConnectionsCompanion copyWith({
    Value<String>? id,
    Value<String>? definitionId,
    Value<String>? modelPrefix,
    Value<String>? displayName,
    Value<String>? status,
    Value<String>? authKind,
    Value<String>? credentialOrigin,
    Value<String?>? error,
    Value<String?>? customConfigJson,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ProviderConnectionsCompanion(
      id: id ?? this.id,
      definitionId: definitionId ?? this.definitionId,
      modelPrefix: modelPrefix ?? this.modelPrefix,
      displayName: displayName ?? this.displayName,
      status: status ?? this.status,
      authKind: authKind ?? this.authKind,
      credentialOrigin: credentialOrigin ?? this.credentialOrigin,
      error: error ?? this.error,
      customConfigJson: customConfigJson ?? this.customConfigJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (definitionId.present) {
      map['definition_id'] = Variable<String>(definitionId.value);
    }
    if (modelPrefix.present) {
      map['model_prefix'] = Variable<String>(modelPrefix.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (authKind.present) {
      map['auth_kind'] = Variable<String>(authKind.value);
    }
    if (credentialOrigin.present) {
      map['credential_origin'] = Variable<String>(credentialOrigin.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (customConfigJson.present) {
      map['custom_config_json'] = Variable<String>(customConfigJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProviderConnectionsCompanion(')
          ..write('id: $id, ')
          ..write('definitionId: $definitionId, ')
          ..write('modelPrefix: $modelPrefix, ')
          ..write('displayName: $displayName, ')
          ..write('status: $status, ')
          ..write('authKind: $authKind, ')
          ..write('credentialOrigin: $credentialOrigin, ')
          ..write('error: $error, ')
          ..write('customConfigJson: $customConfigJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProviderModelsTable extends ProviderModels
    with TableInfo<$ProviderModelsTable, ProviderModel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProviderModelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _connectionIdMeta = const VerificationMeta(
    'connectionId',
  );
  @override
  late final GeneratedColumn<String> connectionId = GeneratedColumn<String>(
    'connection_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES provider_connections (id)',
    ),
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerModelIdMeta = const VerificationMeta(
    'providerModelId',
  );
  @override
  late final GeneratedColumn<String> providerModelId = GeneratedColumn<String>(
    'provider_model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capabilitiesJsonMeta = const VerificationMeta(
    'capabilitiesJson',
  );
  @override
  late final GeneratedColumn<String> capabilitiesJson = GeneratedColumn<String>(
    'capabilities_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pricingJsonMeta = const VerificationMeta(
    'pricingJson',
  );
  @override
  late final GeneratedColumn<String> pricingJson = GeneratedColumn<String>(
    'pricing_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _limitsJsonMeta = const VerificationMeta(
    'limitsJson',
  );
  @override
  late final GeneratedColumn<String> limitsJson = GeneratedColumn<String>(
    'limits_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _diagnosticStatusMeta = const VerificationMeta(
    'diagnosticStatus',
  );
  @override
  late final GeneratedColumn<String> diagnosticStatus = GeneratedColumn<String>(
    'diagnostic_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unknown'),
  );
  static const VerificationMeta _verifiedAtMeta = const VerificationMeta(
    'verifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> verifiedAt = GeneratedColumn<DateTime>(
    'verified_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _diagnosticErrorMeta = const VerificationMeta(
    'diagnosticError',
  );
  @override
  late final GeneratedColumn<String> diagnosticError = GeneratedColumn<String>(
    'diagnostic_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    connectionId,
    modelId,
    providerModelId,
    label,
    source,
    capabilitiesJson,
    pricingJson,
    limitsJson,
    diagnosticStatus,
    verifiedAt,
    diagnosticError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'provider_models';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProviderModel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('connection_id')) {
      context.handle(
        _connectionIdMeta,
        connectionId.isAcceptableOrUnknown(
          data['connection_id']!,
          _connectionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_connectionIdMeta);
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_modelIdMeta);
    }
    if (data.containsKey('provider_model_id')) {
      context.handle(
        _providerModelIdMeta,
        providerModelId.isAcceptableOrUnknown(
          data['provider_model_id']!,
          _providerModelIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providerModelIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('capabilities_json')) {
      context.handle(
        _capabilitiesJsonMeta,
        capabilitiesJson.isAcceptableOrUnknown(
          data['capabilities_json']!,
          _capabilitiesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capabilitiesJsonMeta);
    }
    if (data.containsKey('pricing_json')) {
      context.handle(
        _pricingJsonMeta,
        pricingJson.isAcceptableOrUnknown(
          data['pricing_json']!,
          _pricingJsonMeta,
        ),
      );
    }
    if (data.containsKey('limits_json')) {
      context.handle(
        _limitsJsonMeta,
        limitsJson.isAcceptableOrUnknown(data['limits_json']!, _limitsJsonMeta),
      );
    }
    if (data.containsKey('diagnostic_status')) {
      context.handle(
        _diagnosticStatusMeta,
        diagnosticStatus.isAcceptableOrUnknown(
          data['diagnostic_status']!,
          _diagnosticStatusMeta,
        ),
      );
    }
    if (data.containsKey('verified_at')) {
      context.handle(
        _verifiedAtMeta,
        verifiedAt.isAcceptableOrUnknown(data['verified_at']!, _verifiedAtMeta),
      );
    }
    if (data.containsKey('diagnostic_error')) {
      context.handle(
        _diagnosticErrorMeta,
        diagnosticError.isAcceptableOrUnknown(
          data['diagnostic_error']!,
          _diagnosticErrorMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {connectionId, modelId};
  @override
  ProviderModel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProviderModel(
      connectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}connection_id'],
      )!,
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      )!,
      providerModelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_model_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      capabilitiesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capabilities_json'],
      )!,
      pricingJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pricing_json'],
      ),
      limitsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}limits_json'],
      ),
      diagnosticStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}diagnostic_status'],
      )!,
      verifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}verified_at'],
      ),
      diagnosticError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}diagnostic_error'],
      ),
    );
  }

  @override
  $ProviderModelsTable createAlias(String alias) {
    return $ProviderModelsTable(attachedDatabase, alias);
  }
}

class ProviderModel extends DataClass implements Insertable<ProviderModel> {
  /// Owning provider connection.
  final String connectionId;

  /// The modelId public API member.
  final String modelId;

  /// Model identifier sent to the upstream provider.
  final String providerModelId;

  /// The label public API member.
  final String label;

  /// The source public API member.
  final String source;

  /// The capabilitiesJson public API member.
  final String capabilitiesJson;

  /// Optional model pricing metadata.
  final String? pricingJson;

  /// Optional model token-limit metadata.
  final String? limitsJson;

  /// The diagnosticStatus public API member.
  final String diagnosticStatus;

  /// The verifiedAt public API member.
  final DateTime? verifiedAt;

  /// The diagnosticError public API member.
  final String? diagnosticError;
  const ProviderModel({
    required this.connectionId,
    required this.modelId,
    required this.providerModelId,
    required this.label,
    required this.source,
    required this.capabilitiesJson,
    this.pricingJson,
    this.limitsJson,
    required this.diagnosticStatus,
    this.verifiedAt,
    this.diagnosticError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['connection_id'] = Variable<String>(connectionId);
    map['model_id'] = Variable<String>(modelId);
    map['provider_model_id'] = Variable<String>(providerModelId);
    map['label'] = Variable<String>(label);
    map['source'] = Variable<String>(source);
    map['capabilities_json'] = Variable<String>(capabilitiesJson);
    if (!nullToAbsent || pricingJson != null) {
      map['pricing_json'] = Variable<String>(pricingJson);
    }
    if (!nullToAbsent || limitsJson != null) {
      map['limits_json'] = Variable<String>(limitsJson);
    }
    map['diagnostic_status'] = Variable<String>(diagnosticStatus);
    if (!nullToAbsent || verifiedAt != null) {
      map['verified_at'] = Variable<DateTime>(verifiedAt);
    }
    if (!nullToAbsent || diagnosticError != null) {
      map['diagnostic_error'] = Variable<String>(diagnosticError);
    }
    return map;
  }

  ProviderModelsCompanion toCompanion(bool nullToAbsent) {
    return ProviderModelsCompanion(
      connectionId: Value(connectionId),
      modelId: Value(modelId),
      providerModelId: Value(providerModelId),
      label: Value(label),
      source: Value(source),
      capabilitiesJson: Value(capabilitiesJson),
      pricingJson: pricingJson == null && nullToAbsent
          ? const Value.absent()
          : Value(pricingJson),
      limitsJson: limitsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(limitsJson),
      diagnosticStatus: Value(diagnosticStatus),
      verifiedAt: verifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(verifiedAt),
      diagnosticError: diagnosticError == null && nullToAbsent
          ? const Value.absent()
          : Value(diagnosticError),
    );
  }

  factory ProviderModel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProviderModel(
      connectionId: serializer.fromJson<String>(json['connectionId']),
      modelId: serializer.fromJson<String>(json['modelId']),
      providerModelId: serializer.fromJson<String>(json['providerModelId']),
      label: serializer.fromJson<String>(json['label']),
      source: serializer.fromJson<String>(json['source']),
      capabilitiesJson: serializer.fromJson<String>(json['capabilitiesJson']),
      pricingJson: serializer.fromJson<String?>(json['pricingJson']),
      limitsJson: serializer.fromJson<String?>(json['limitsJson']),
      diagnosticStatus: serializer.fromJson<String>(json['diagnosticStatus']),
      verifiedAt: serializer.fromJson<DateTime?>(json['verifiedAt']),
      diagnosticError: serializer.fromJson<String?>(json['diagnosticError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'connectionId': serializer.toJson<String>(connectionId),
      'modelId': serializer.toJson<String>(modelId),
      'providerModelId': serializer.toJson<String>(providerModelId),
      'label': serializer.toJson<String>(label),
      'source': serializer.toJson<String>(source),
      'capabilitiesJson': serializer.toJson<String>(capabilitiesJson),
      'pricingJson': serializer.toJson<String?>(pricingJson),
      'limitsJson': serializer.toJson<String?>(limitsJson),
      'diagnosticStatus': serializer.toJson<String>(diagnosticStatus),
      'verifiedAt': serializer.toJson<DateTime?>(verifiedAt),
      'diagnosticError': serializer.toJson<String?>(diagnosticError),
    };
  }

  ProviderModel copyWith({
    String? connectionId,
    String? modelId,
    String? providerModelId,
    String? label,
    String? source,
    String? capabilitiesJson,
    Value<String?> pricingJson = const Value.absent(),
    Value<String?> limitsJson = const Value.absent(),
    String? diagnosticStatus,
    Value<DateTime?> verifiedAt = const Value.absent(),
    Value<String?> diagnosticError = const Value.absent(),
  }) => ProviderModel(
    connectionId: connectionId ?? this.connectionId,
    modelId: modelId ?? this.modelId,
    providerModelId: providerModelId ?? this.providerModelId,
    label: label ?? this.label,
    source: source ?? this.source,
    capabilitiesJson: capabilitiesJson ?? this.capabilitiesJson,
    pricingJson: pricingJson.present ? pricingJson.value : this.pricingJson,
    limitsJson: limitsJson.present ? limitsJson.value : this.limitsJson,
    diagnosticStatus: diagnosticStatus ?? this.diagnosticStatus,
    verifiedAt: verifiedAt.present ? verifiedAt.value : this.verifiedAt,
    diagnosticError: diagnosticError.present
        ? diagnosticError.value
        : this.diagnosticError,
  );
  ProviderModel copyWithCompanion(ProviderModelsCompanion data) {
    return ProviderModel(
      connectionId: data.connectionId.present
          ? data.connectionId.value
          : this.connectionId,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      providerModelId: data.providerModelId.present
          ? data.providerModelId.value
          : this.providerModelId,
      label: data.label.present ? data.label.value : this.label,
      source: data.source.present ? data.source.value : this.source,
      capabilitiesJson: data.capabilitiesJson.present
          ? data.capabilitiesJson.value
          : this.capabilitiesJson,
      pricingJson: data.pricingJson.present
          ? data.pricingJson.value
          : this.pricingJson,
      limitsJson: data.limitsJson.present
          ? data.limitsJson.value
          : this.limitsJson,
      diagnosticStatus: data.diagnosticStatus.present
          ? data.diagnosticStatus.value
          : this.diagnosticStatus,
      verifiedAt: data.verifiedAt.present
          ? data.verifiedAt.value
          : this.verifiedAt,
      diagnosticError: data.diagnosticError.present
          ? data.diagnosticError.value
          : this.diagnosticError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProviderModel(')
          ..write('connectionId: $connectionId, ')
          ..write('modelId: $modelId, ')
          ..write('providerModelId: $providerModelId, ')
          ..write('label: $label, ')
          ..write('source: $source, ')
          ..write('capabilitiesJson: $capabilitiesJson, ')
          ..write('pricingJson: $pricingJson, ')
          ..write('limitsJson: $limitsJson, ')
          ..write('diagnosticStatus: $diagnosticStatus, ')
          ..write('verifiedAt: $verifiedAt, ')
          ..write('diagnosticError: $diagnosticError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    connectionId,
    modelId,
    providerModelId,
    label,
    source,
    capabilitiesJson,
    pricingJson,
    limitsJson,
    diagnosticStatus,
    verifiedAt,
    diagnosticError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderModel &&
          other.connectionId == this.connectionId &&
          other.modelId == this.modelId &&
          other.providerModelId == this.providerModelId &&
          other.label == this.label &&
          other.source == this.source &&
          other.capabilitiesJson == this.capabilitiesJson &&
          other.pricingJson == this.pricingJson &&
          other.limitsJson == this.limitsJson &&
          other.diagnosticStatus == this.diagnosticStatus &&
          other.verifiedAt == this.verifiedAt &&
          other.diagnosticError == this.diagnosticError);
}

class ProviderModelsCompanion extends UpdateCompanion<ProviderModel> {
  final Value<String> connectionId;
  final Value<String> modelId;
  final Value<String> providerModelId;
  final Value<String> label;
  final Value<String> source;
  final Value<String> capabilitiesJson;
  final Value<String?> pricingJson;
  final Value<String?> limitsJson;
  final Value<String> diagnosticStatus;
  final Value<DateTime?> verifiedAt;
  final Value<String?> diagnosticError;
  final Value<int> rowid;
  const ProviderModelsCompanion({
    this.connectionId = const Value.absent(),
    this.modelId = const Value.absent(),
    this.providerModelId = const Value.absent(),
    this.label = const Value.absent(),
    this.source = const Value.absent(),
    this.capabilitiesJson = const Value.absent(),
    this.pricingJson = const Value.absent(),
    this.limitsJson = const Value.absent(),
    this.diagnosticStatus = const Value.absent(),
    this.verifiedAt = const Value.absent(),
    this.diagnosticError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProviderModelsCompanion.insert({
    required String connectionId,
    required String modelId,
    required String providerModelId,
    required String label,
    required String source,
    required String capabilitiesJson,
    this.pricingJson = const Value.absent(),
    this.limitsJson = const Value.absent(),
    this.diagnosticStatus = const Value.absent(),
    this.verifiedAt = const Value.absent(),
    this.diagnosticError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : connectionId = Value(connectionId),
       modelId = Value(modelId),
       providerModelId = Value(providerModelId),
       label = Value(label),
       source = Value(source),
       capabilitiesJson = Value(capabilitiesJson);
  static Insertable<ProviderModel> custom({
    Expression<String>? connectionId,
    Expression<String>? modelId,
    Expression<String>? providerModelId,
    Expression<String>? label,
    Expression<String>? source,
    Expression<String>? capabilitiesJson,
    Expression<String>? pricingJson,
    Expression<String>? limitsJson,
    Expression<String>? diagnosticStatus,
    Expression<DateTime>? verifiedAt,
    Expression<String>? diagnosticError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (connectionId != null) 'connection_id': connectionId,
      if (modelId != null) 'model_id': modelId,
      if (providerModelId != null) 'provider_model_id': providerModelId,
      if (label != null) 'label': label,
      if (source != null) 'source': source,
      if (capabilitiesJson != null) 'capabilities_json': capabilitiesJson,
      if (pricingJson != null) 'pricing_json': pricingJson,
      if (limitsJson != null) 'limits_json': limitsJson,
      if (diagnosticStatus != null) 'diagnostic_status': diagnosticStatus,
      if (verifiedAt != null) 'verified_at': verifiedAt,
      if (diagnosticError != null) 'diagnostic_error': diagnosticError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProviderModelsCompanion copyWith({
    Value<String>? connectionId,
    Value<String>? modelId,
    Value<String>? providerModelId,
    Value<String>? label,
    Value<String>? source,
    Value<String>? capabilitiesJson,
    Value<String?>? pricingJson,
    Value<String?>? limitsJson,
    Value<String>? diagnosticStatus,
    Value<DateTime?>? verifiedAt,
    Value<String?>? diagnosticError,
    Value<int>? rowid,
  }) {
    return ProviderModelsCompanion(
      connectionId: connectionId ?? this.connectionId,
      modelId: modelId ?? this.modelId,
      providerModelId: providerModelId ?? this.providerModelId,
      label: label ?? this.label,
      source: source ?? this.source,
      capabilitiesJson: capabilitiesJson ?? this.capabilitiesJson,
      pricingJson: pricingJson ?? this.pricingJson,
      limitsJson: limitsJson ?? this.limitsJson,
      diagnosticStatus: diagnosticStatus ?? this.diagnosticStatus,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      diagnosticError: diagnosticError ?? this.diagnosticError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (connectionId.present) {
      map['connection_id'] = Variable<String>(connectionId.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (providerModelId.present) {
      map['provider_model_id'] = Variable<String>(providerModelId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (capabilitiesJson.present) {
      map['capabilities_json'] = Variable<String>(capabilitiesJson.value);
    }
    if (pricingJson.present) {
      map['pricing_json'] = Variable<String>(pricingJson.value);
    }
    if (limitsJson.present) {
      map['limits_json'] = Variable<String>(limitsJson.value);
    }
    if (diagnosticStatus.present) {
      map['diagnostic_status'] = Variable<String>(diagnosticStatus.value);
    }
    if (verifiedAt.present) {
      map['verified_at'] = Variable<DateTime>(verifiedAt.value);
    }
    if (diagnosticError.present) {
      map['diagnostic_error'] = Variable<String>(diagnosticError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProviderModelsCompanion(')
          ..write('connectionId: $connectionId, ')
          ..write('modelId: $modelId, ')
          ..write('providerModelId: $providerModelId, ')
          ..write('label: $label, ')
          ..write('source: $source, ')
          ..write('capabilitiesJson: $capabilitiesJson, ')
          ..write('pricingJson: $pricingJson, ')
          ..write('limitsJson: $limitsJson, ')
          ..write('diagnosticStatus: $diagnosticStatus, ')
          ..write('verifiedAt: $verifiedAt, ')
          ..write('diagnosticError: $diagnosticError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$TinestDatabase extends GeneratedDatabase {
  _$TinestDatabase(QueryExecutor e) : super(e);
  $TinestDatabaseManager get managers => $TinestDatabaseManager(this);
  late final $WorkspacesTable workspaces = $WorkspacesTable(this);
  late final $WorktreesTable worktrees = $WorktreesTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $TurnsTable turns = $TurnsTable(this);
  late final $AgentMailboxMessagesTable agentMailboxMessages =
      $AgentMailboxMessagesTable(this);
  late final $AttachmentsTable attachments = $AttachmentsTable(this);
  late final $TurnAttachmentsTable turnAttachments = $TurnAttachmentsTable(
    this,
  );
  late final $TimelineEventsTable timelineEvents = $TimelineEventsTable(this);
  late final $ApprovalRequestsTable approvalRequests = $ApprovalRequestsTable(
    this,
  );
  late final $UserQuestionsTable userQuestions = $UserQuestionsTable(this);
  late final $ProviderStatesTable providerStates = $ProviderStatesTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $ProviderConnectionsTable providerConnections =
      $ProviderConnectionsTable(this);
  late final $ProviderModelsTable providerModels = $ProviderModelsTable(this);
  late final SettingsDao settingsDao = SettingsDao(this as TinestDatabase);
  late final WorkspaceDao workspaceDao = WorkspaceDao(this as TinestDatabase);
  late final WorktreeDao worktreeDao = WorktreeDao(this as TinestDatabase);
  late final SessionDao sessionDao = SessionDao(this as TinestDatabase);
  late final AgentMailboxDao agentMailboxDao = AgentMailboxDao(
    this as TinestDatabase,
  );
  late final AttachmentDao attachmentDao = AttachmentDao(
    this as TinestDatabase,
  );
  late final TimelineDao timelineDao = TimelineDao(this as TinestDatabase);
  late final ProviderDao providerDao = ProviderDao(this as TinestDatabase);
  late final RuntimeDao runtimeDao = RuntimeDao(this as TinestDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    workspaces,
    worktrees,
    sessions,
    turns,
    agentMailboxMessages,
    attachments,
    turnAttachments,
    timelineEvents,
    approvalRequests,
    userQuestions,
    providerStates,
    settings,
    providerConnections,
    providerModels,
  ];
}

typedef $$WorkspacesTableCreateCompanionBuilder = WorkspacesCompanion Function({
  required String id,
  required String name,
  required String rootPath,
  required String kind,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$WorkspacesTableUpdateCompanionBuilder = WorkspacesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> rootPath,
  Value<String> kind,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$WorkspacesTableReferences
    extends BaseReferences<_$TinestDatabase, $WorkspacesTable, Workspace> {
  $$WorkspacesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$WorktreesTable, List<Worktree>>
  _worktreesRefsTable(_$TinestDatabase db) => MultiTypedResultKey.fromTable(
    db.worktrees,
    aliasName: 'workspaces__id__worktrees__workspace_id',
  );

  $$WorktreesTableProcessedTableManager get worktreesRefs {
    final manager = $$WorktreesTableTableManager(
      $_db,
      $_db.worktrees,
    ).filter((f) => f.workspaceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_worktreesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorkspacesTableFilterComposer
    extends Composer<_$TinestDatabase, $WorkspacesTable> {
  $$WorkspacesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rootPath => $composableBuilder(
    column: $table.rootPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> worktreesRefs(
    Expression<bool> Function($$WorktreesTableFilterComposer f) f,
  ) {
    final $$WorktreesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.worktrees,
      getReferencedColumn: (t) => t.workspaceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorktreesTableFilterComposer(
            $db: $db,
            $table: $db.worktrees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkspacesTableOrderingComposer
    extends Composer<_$TinestDatabase, $WorkspacesTable> {
  $$WorkspacesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rootPath => $composableBuilder(
    column: $table.rootPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkspacesTableAnnotationComposer
    extends Composer<_$TinestDatabase, $WorkspacesTable> {
  $$WorkspacesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get rootPath =>
      $composableBuilder(column: $table.rootPath, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> worktreesRefs<T extends Object>(
    Expression<T> Function($$WorktreesTableAnnotationComposer a) f,
  ) {
    final $$WorktreesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.worktrees,
      getReferencedColumn: (t) => t.workspaceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorktreesTableAnnotationComposer(
            $db: $db,
            $table: $db.worktrees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkspacesTableTableManager
    extends
        RootTableManager<
          _$TinestDatabase,
          $WorkspacesTable,
          Workspace,
          $$WorkspacesTableFilterComposer,
          $$WorkspacesTableOrderingComposer,
          $$WorkspacesTableAnnotationComposer,
          $$WorkspacesTableCreateCompanionBuilder,
          $$WorkspacesTableUpdateCompanionBuilder,
          (Workspace, $$WorkspacesTableReferences),
          Workspace,
          PrefetchHooks Function({bool worktreesRefs})
        > {
  $$WorkspacesTableTableManager(_$TinestDatabase db, $WorkspacesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkspacesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkspacesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkspacesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> rootPath = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkspacesCompanion(
                id: id,
                name: name,
                rootPath: rootPath,
                kind: kind,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String rootPath,
                required String kind,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => WorkspacesCompanion.insert(
                id: id,
                name: name,
                rootPath: rootPath,
                kind: kind,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkspacesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({worktreesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (worktreesRefs) db.worktrees],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (worktreesRefs)
                    await $_getPrefetchedData<
                      Workspace,
                      $WorkspacesTable,
                      Worktree
                    >(
                      currentTable: table,
                      referencedTable: $$WorkspacesTableReferences
                          ._worktreesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$WorkspacesTableReferences(
                            db,
                            table,
                            p0,
                          ).worktreesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.workspaceId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$WorkspacesTableProcessedTableManager =
    ProcessedTableManager<
      _$TinestDatabase,
      $WorkspacesTable,
      Workspace,
      $$WorkspacesTableFilterComposer,
      $$WorkspacesTableOrderingComposer,
      $$WorkspacesTableAnnotationComposer,
      $$WorkspacesTableCreateCompanionBuilder,
      $$WorkspacesTableUpdateCompanionBuilder,
      (Workspace, $$WorkspacesTableReferences),
      Workspace,
      PrefetchHooks Function({bool worktreesRefs})
    >;
typedef $$WorktreesTableCreateCompanionBuilder = WorktreesCompanion Function({
  required String id,
  required String workspaceId,
  required String name,
  required String path,
  Value<String?> branch,
  Value<String?> head,
  required String kind,
  required bool isTinestOwned,
  Value<DateTime?> archivedAt,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$WorktreesTableUpdateCompanionBuilder = WorktreesCompanion Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> name,
  Value<String> path,
  Value<String?> branch,
  Value<String?> head,
  Value<String> kind,
  Value<bool> isTinestOwned,
  Value<DateTime?> archivedAt,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$WorktreesTableReferences
    extends BaseReferences<_$TinestDatabase, $WorktreesTable, Worktree> {
  $$WorktreesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WorkspacesTable _workspaceIdTable(_$TinestDatabase db) =>
      db.workspaces.createAlias('worktrees__workspace_id__workspaces__id');

  $$WorkspacesTableProcessedTableManager get workspaceId {
    final $_column = $_itemColumn<String>('workspace_id')!;

    final manager = $$WorkspacesTableTableManager(
      $_db,
      $_db.workspaces,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workspaceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SessionsTable, List<Session>> _sessionsRefsTable(
    _$TinestDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.sessions,
    aliasName: 'worktrees__id__sessions__worktree_id',
  );

  $$SessionsTableProcessedTableManager get sessionsRefs {
    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.worktreeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sessionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorktreesTableFilterComposer
    extends Composer<_$TinestDatabase, $WorktreesTable> {
  $$WorktreesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get branch => $composableBuilder(
    column: $table.branch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get head => $composableBuilder(
    column: $table.head,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isTinestOwned => $composableBuilder(
    column: $table.isTinestOwned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkspacesTableFilterComposer get workspaceId {
    final $$WorkspacesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workspaceId,
      referencedTable: $db.workspaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkspacesTableFilterComposer(
            $db: $db,
            $table: $db.workspaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> sessionsRefs(
    Expression<bool> Function($$SessionsTableFilterComposer f) f,
  ) {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.worktreeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorktreesTableOrderingComposer
    extends Composer<_$TinestDatabase, $WorktreesTable> {
  $$WorktreesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get branch => $composableBuilder(
    column: $table.branch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get head => $composableBuilder(
    column: $table.head,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isTinestOwned => $composableBuilder(
    column: $table.isTinestOwned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkspacesTableOrderingComposer get workspaceId {
    final $$WorkspacesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workspaceId,
      referencedTable: $db.workspaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkspacesTableOrderingComposer(
            $db: $db,
            $table: $db.workspaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorktreesTableAnnotationComposer
    extends Composer<_$TinestDatabase, $WorktreesTable> {
  $$WorktreesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get branch =>
      $composableBuilder(column: $table.branch, builder: (column) => column);

  GeneratedColumn<String> get head =>
      $composableBuilder(column: $table.head, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<bool> get isTinestOwned => $composableBuilder(
    column: $table.isTinestOwned,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$WorkspacesTableAnnotationComposer get workspaceId {
    final $$WorkspacesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workspaceId,
      referencedTable: $db.workspaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkspacesTableAnnotationComposer(
            $db: $db,
            $table: $db.workspaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> sessionsRefs<T extends Object>(
    Expression<T> Function($$SessionsTableAnnotationComposer a) f,
  ) {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.worktreeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorktreesTableTableManager
    extends
        RootTableManager<
          _$TinestDatabase,
          $WorktreesTable,
          Worktree,
          $$WorktreesTableFilterComposer,
          $$WorktreesTableOrderingComposer,
          $$WorktreesTableAnnotationComposer,
          $$WorktreesTableCreateCompanionBuilder,
          $$WorktreesTableUpdateCompanionBuilder,
          (Worktree, $$WorktreesTableReferences),
          Worktree,
          PrefetchHooks Function({bool workspaceId, bool sessionsRefs})
        > {
  $$WorktreesTableTableManager(_$TinestDatabase db, $WorktreesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorktreesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorktreesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorktreesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> workspaceId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String?> branch = const Value.absent(),
                Value<String?> head = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<bool> isTinestOwned = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorktreesCompanion(
                id: id,
                workspaceId: workspaceId,
                name: name,
                path: path,
                branch: branch,
                head: head,
                kind: kind,
                isTinestOwned: isTinestOwned,
                archivedAt: archivedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String workspaceId,
                required String name,
                required String path,
                Value<String?> branch = const Value.absent(),
                Value<String?> head = const Value.absent(),
                required String kind,
                required bool isTinestOwned,
                Value<DateTime?> archivedAt = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => WorktreesCompanion.insert(
                id: id,
                workspaceId: workspaceId,
                name: name,
                path: path,
                branch: branch,
                head: head,
                kind: kind,
                isTinestOwned: isTinestOwned,
                archivedAt: archivedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorktreesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({workspaceId = false, sessionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (sessionsRefs) db.sessions],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (workspaceId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.workspaceId,
                        referencedTable: $$WorktreesTableReferences
                            ._workspaceIdTable(db),
                        referencedColumn: $$WorktreesTableReferences
                            ._workspaceIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sessionsRefs)
                    await $_getPrefetchedData<
                      Worktree,
                      $WorktreesTable,
                      Session
                    >(
                      currentTable: table,
                      referencedTable: $$WorktreesTableReferences
                          ._sessionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$WorktreesTableReferences(
                            db,
                            table,
                            p0,
                          ).sessionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.worktreeId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$WorktreesTableProcessedTableManager =
    ProcessedTableManager<
      _$TinestDatabase,
      $WorktreesTable,
      Worktree,
      $$WorktreesTableFilterComposer,
      $$WorktreesTableOrderingComposer,
      $$WorktreesTableAnnotationComposer,
      $$WorktreesTableCreateCompanionBuilder,
      $$WorktreesTableUpdateCompanionBuilder,
      (Worktree, $$WorktreesTableReferences),
      Worktree,
      PrefetchHooks Function({bool workspaceId, bool sessionsRefs})
    >;
typedef $$SessionsTableCreateCompanionBuilder = SessionsCompanion Function({
  required String id,
  required String worktreeId,
  required String title,
  required String agentDefinitionId,
  required String origin,
  Value<String?> parentSessionId,
  Value<String?> taskName,
  Value<String?> agentPath,
  Value<String?> rootSessionId,
  Value<String?> lifecycle,
  required String status,
  Value<String?> activeTurnId,
  Value<String?> lastError,
  Value<String?> modelId,
  Value<String> modelControlsJson,
  Value<String> permissionMode,
  Value<int> currentContextEpoch,
  Value<int> contextTokensUsed,
  Value<int?> contextWindowTokens,
  Value<double> totalCostUsd,
  Value<bool> hasCompleteCost,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$SessionsTableUpdateCompanionBuilder = SessionsCompanion Function({
  Value<String> id,
  Value<String> worktreeId,
  Value<String> title,
  Value<String> agentDefinitionId,
  Value<String> origin,
  Value<String?> parentSessionId,
  Value<String?> taskName,
  Value<String?> agentPath,
  Value<String?> rootSessionId,
  Value<String?> lifecycle,
  Value<String> status,
  Value<String?> activeTurnId,
  Value<String?> lastError,
  Value<String?> modelId,
  Value<String> modelControlsJson,
  Value<String> permissionMode,
  Value<int> currentContextEpoch,
  Value<int> contextTokensUsed,
  Value<int?> contextWindowTokens,
  Value<double> totalCostUsd,
  Value<bool> hasCompleteCost,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$SessionsTableReferences
    extends BaseReferences<_$TinestDatabase, $SessionsTable, Session> {
  $$SessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WorktreesTable _worktreeIdTable(_$TinestDatabase db) =>
      db.worktrees.createAlias('sessions__worktree_id__worktrees__id');

  $$WorktreesTableProcessedTableManager get worktreeId {
    final $_column = $_itemColumn<String>('worktree_id')!;

    final manager = $$WorktreesTableTableManager(
      $_db,
      $_db.worktrees,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_worktreeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SessionsTable _parentSessionIdTable(_$TinestDatabase db) =>
      db.sessions.createAlias('sessions__parent_session_id__sessions__id');

  $$SessionsTableProcessedTableManager? get parentSessionId {
    final $_column = $_itemColumn<String>('parent_session_id');
    if ($_column == null) return null;
    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentSessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SessionsTable _rootSessionIdTable(_$TinestDatabase db) =>
      db.sessions.createAlias('sessions__root_session_id__sessions__id');

  $$SessionsTableProcessedTableManager? get rootSessionId {
    final $_column = $_itemColumn<String>('root_session_id');
    if ($_column == null) return null;
    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_rootSessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TurnsTable, List<Turn>> _turnsRefsTable(
    _$TinestDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.turns,
    aliasName: 'sessions__id__turns__session_id',
  );

  $$TurnsTableProcessedTableManager get turnsRefs {
    final manager = $$TurnsTableTableManager(
      $_db,
      $_db.turns,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_turnsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $AgentMailboxMessagesTable,
    List<AgentMailboxMessage>
  >
  _agentMailboxMessagesRefsTable(_$TinestDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.agentMailboxMessages,
        aliasName: 'sessions__id__agent_mailbox_messages__session_id',
      );

  $$AgentMailboxMessagesTableProcessedTableManager
  get agentMailboxMessagesRefs {
    final manager = $$AgentMailboxMessagesTableTableManager(
      $_db,
      $_db.agentMailboxMessages,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _agentMailboxMessagesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TimelineEventsTable, List<TimelineEvent>>
  _timelineEventsRefsTable(_$TinestDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.timelineEvents,
        aliasName: 'sessions__id__timeline_events__session_id',
      );

  $$TimelineEventsTableProcessedTableManager get timelineEventsRefs {
    final manager = $$TimelineEventsTableTableManager(
      $_db,
      $_db.timelineEvents,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_timelineEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ApprovalRequestsTable, List<ApprovalRequest>>
  _approvalRequestsRefsTable(_$TinestDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.approvalRequests,
        aliasName: 'sessions__id__approval_requests__session_id',
      );

  $$ApprovalRequestsTableProcessedTableManager get approvalRequestsRefs {
    final manager = $$ApprovalRequestsTableTableManager(
      $_db,
      $_db.approvalRequests,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _approvalRequestsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$UserQuestionsTable, List<UserQuestionRow>>
  _userQuestionsRefsTable(_$TinestDatabase db) => MultiTypedResultKey.fromTable(
    db.userQuestions,
    aliasName: 'sessions__id__user_questions__session_id',
  );

  $$UserQuestionsTableProcessedTableManager get userQuestionsRefs {
    final manager = $$UserQuestionsTableTableManager(
      $_db,
      $_db.userQuestions,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_userQuestionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ProviderStatesTable, List<ProviderState>>
  _providerStatesRefsTable(_$TinestDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.providerStates,
        aliasName: 'sessions__id__provider_states__session_id',
      );

  $$ProviderStatesTableProcessedTableManager get providerStatesRefs {
    final manager = $$ProviderStatesTableTableManager(
      $_db,
      $_db.providerStates,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_providerStatesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SessionsTableFilterComposer
    extends Composer<_$TinestDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get agentDefinitionId => $composableBuilder(
    column: $table.agentDefinitionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskName => $composableBuilder(
    column: $table.taskName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get agentPath => $composableBuilder(
    column: $table.agentPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activeTurnId => $composableBuilder(
    column: $table.activeTurnId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelControlsJson => $composableBuilder(
    column: $table.modelControlsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get permissionMode => $composableBuilder(
    column: $table.permissionMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentContextEpoch => $composableBuilder(
    column: $table.currentContextEpoch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contextTokensUsed => $composableBuilder(
    column: $table.contextTokensUsed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contextWindowTokens => $composableBuilder(
    column: $table.contextWindowTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalCostUsd => $composableBuilder(
    column: $table.totalCostUsd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasCompleteCost => $composableBuilder(
    column: $table.hasCompleteCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$WorktreesTableFilterComposer get worktreeId {
    final $$WorktreesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.worktreeId,
      referencedTable: $db.worktrees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorktreesTableFilterComposer(
            $db: $db,
            $table: $db.worktrees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SessionsTableFilterComposer get parentSessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentSessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SessionsTableFilterComposer get rootSessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rootSessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> turnsRefs(
    Expression<bool> Function($$TurnsTableFilterComposer f) f,
  ) {
    final $$TurnsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.turns,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TurnsTableFilterComposer(
            $db: $db,
            $table: $db.turns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> agentMailboxMessagesRefs(
    Expression<bool> Function($$AgentMailboxMessagesTableFilterComposer f) f,
  ) {
    final $$AgentMailboxMessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.agentMailboxMessages,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentMailboxMessagesTableFilterComposer(
            $db: $db,
            $table: $db.agentMailboxMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> timelineEventsRefs(
    Expression<bool> Function($$TimelineEventsTableFilterComposer f) f,
  ) {
    final $$TimelineEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.timelineEvents,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TimelineEventsTableFilterComposer(
            $db: $db,
            $table: $db.timelineEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> approvalRequestsRefs(
    Expression<bool> Function($$ApprovalRequestsTableFilterComposer f) f,
  ) {
    final $$ApprovalRequestsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.approvalRequests,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ApprovalRequestsTableFilterComposer(
            $db: $db,
            $table: $db.approvalRequests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> userQuestionsRefs(
    Expression<bool> Function($$UserQuestionsTableFilterComposer f) f,
  ) {
    final $$UserQuestionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.userQuestions,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserQuestionsTableFilterComposer(
            $db: $db,
            $table: $db.userQuestions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> providerStatesRefs(
    Expression<bool> Function($$ProviderStatesTableFilterComposer f) f,
  ) {
    final $$ProviderStatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.providerStates,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProviderStatesTableFilterComposer(
            $db: $db,
            $table: $db.providerStates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableOrderingComposer
    extends Composer<_$TinestDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get agentDefinitionId => $composableBuilder(
    column: $table.agentDefinitionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskName => $composableBuilder(
    column: $table.taskName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get agentPath => $composableBuilder(
    column: $table.agentPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activeTurnId => $composableBuilder(
    column: $table.activeTurnId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelControlsJson => $composableBuilder(
    column: $table.modelControlsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get permissionMode => $composableBuilder(
    column: $table.permissionMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentContextEpoch => $composableBuilder(
    column: $table.currentContextEpoch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contextTokensUsed => $composableBuilder(
    column: $table.contextTokensUsed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contextWindowTokens => $composableBuilder(
    column: $table.contextWindowTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalCostUsd => $composableBuilder(
    column: $table.totalCostUsd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasCompleteCost => $composableBuilder(
    column: $table.hasCompleteCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorktreesTableOrderingComposer get worktreeId {
    final $$WorktreesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.worktreeId,
      referencedTable: $db.worktrees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorktreesTableOrderingComposer(
            $db: $db,
            $table: $db.worktrees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SessionsTableOrderingComposer get parentSessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentSessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SessionsTableOrderingComposer get rootSessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rootSessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$TinestDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get agentDefinitionId => $composableBuilder(
    column: $table.agentDefinitionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get taskName =>
      $composableBuilder(column: $table.taskName, builder: (column) => column);

  GeneratedColumn<String> get agentPath =>
      $composableBuilder(column: $table.agentPath, builder: (column) => column);

  GeneratedColumn<String> get lifecycle =>
      $composableBuilder(column: $table.lifecycle, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get activeTurnId => $composableBuilder(
    column: $table.activeTurnId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<String> get modelControlsJson => $composableBuilder(
    column: $table.modelControlsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get permissionMode => $composableBuilder(
    column: $table.permissionMode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentContextEpoch => $composableBuilder(
    column: $table.currentContextEpoch,
    builder: (column) => column,
  );

  GeneratedColumn<int> get contextTokensUsed => $composableBuilder(
    column: $table.contextTokensUsed,
    builder: (column) => column,
  );

  GeneratedColumn<int> get contextWindowTokens => $composableBuilder(
    column: $table.contextWindowTokens,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalCostUsd => $composableBuilder(
    column: $table.totalCostUsd,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasCompleteCost => $composableBuilder(
    column: $table.hasCompleteCost,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$WorktreesTableAnnotationComposer get worktreeId {
    final $$WorktreesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.worktreeId,
      referencedTable: $db.worktrees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorktreesTableAnnotationComposer(
            $db: $db,
            $table: $db.worktrees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SessionsTableAnnotationComposer get parentSessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentSessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SessionsTableAnnotationComposer get rootSessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rootSessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> turnsRefs<T extends Object>(
    Expression<T> Function($$TurnsTableAnnotationComposer a) f,
  ) {
    final $$TurnsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.turns,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TurnsTableAnnotationComposer(
            $db: $db,
            $table: $db.turns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> agentMailboxMessagesRefs<T extends Object>(
    Expression<T> Function($$AgentMailboxMessagesTableAnnotationComposer a) f,
  ) {
    final $$AgentMailboxMessagesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.agentMailboxMessages,
          getReferencedColumn: (t) => t.sessionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AgentMailboxMessagesTableAnnotationComposer(
                $db: $db,
                $table: $db.agentMailboxMessages,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> timelineEventsRefs<T extends Object>(
    Expression<T> Function($$TimelineEventsTableAnnotationComposer a) f,
  ) {
    final $$TimelineEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.timelineEvents,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TimelineEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.timelineEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> approvalRequestsRefs<T extends Object>(
    Expression<T> Function($$ApprovalRequestsTableAnnotationComposer a) f,
  ) {
    final $$ApprovalRequestsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.approvalRequests,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ApprovalRequestsTableAnnotationComposer(
            $db: $db,
            $table: $db.approvalRequests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> userQuestionsRefs<T extends Object>(
    Expression<T> Function($$UserQuestionsTableAnnotationComposer a) f,
  ) {
    final $$UserQuestionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.userQuestions,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserQuestionsTableAnnotationComposer(
            $db: $db,
            $table: $db.userQuestions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> providerStatesRefs<T extends Object>(
    Expression<T> Function($$ProviderStatesTableAnnotationComposer a) f,
  ) {
    final $$ProviderStatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.providerStates,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProviderStatesTableAnnotationComposer(
            $db: $db,
            $table: $db.providerStates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$TinestDatabase,
          $SessionsTable,
          Session,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (Session, $$SessionsTableReferences),
          Session,
          PrefetchHooks Function({
            bool worktreeId,
            bool parentSessionId,
            bool rootSessionId,
            bool turnsRefs,
            bool agentMailboxMessagesRefs,
            bool timelineEventsRefs,
            bool approvalRequestsRefs,
            bool userQuestionsRefs,
            bool providerStatesRefs,
          })
        > {
  $$SessionsTableTableManager(_$TinestDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> worktreeId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> agentDefinitionId = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<String?> parentSessionId = const Value.absent(),
                Value<String?> taskName = const Value.absent(),
                Value<String?> agentPath = const Value.absent(),
                Value<String?> rootSessionId = const Value.absent(),
                Value<String?> lifecycle = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> activeTurnId = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String?> modelId = const Value.absent(),
                Value<String> modelControlsJson = const Value.absent(),
                Value<String> permissionMode = const Value.absent(),
                Value<int> currentContextEpoch = const Value.absent(),
                Value<int> contextTokensUsed = const Value.absent(),
                Value<int?> contextWindowTokens = const Value.absent(),
                Value<double> totalCostUsd = const Value.absent(),
                Value<bool> hasCompleteCost = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                worktreeId: worktreeId,
                title: title,
                agentDefinitionId: agentDefinitionId,
                origin: origin,
                parentSessionId: parentSessionId,
                taskName: taskName,
                agentPath: agentPath,
                rootSessionId: rootSessionId,
                lifecycle: lifecycle,
                status: status,
                activeTurnId: activeTurnId,
                lastError: lastError,
                modelId: modelId,
                modelControlsJson: modelControlsJson,
                permissionMode: permissionMode,
                currentContextEpoch: currentContextEpoch,
                contextTokensUsed: contextTokensUsed,
                contextWindowTokens: contextWindowTokens,
                totalCostUsd: totalCostUsd,
                hasCompleteCost: hasCompleteCost,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String worktreeId,
                required String title,
                required String agentDefinitionId,
                required String origin,
                Value<String?> parentSessionId = const Value.absent(),
                Value<String?> taskName = const Value.absent(),
                Value<String?> agentPath = const Value.absent(),
                Value<String?> rootSessionId = const Value.absent(),
                Value<String?> lifecycle = const Value.absent(),
                required String status,
                Value<String?> activeTurnId = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String?> modelId = const Value.absent(),
                Value<String> modelControlsJson = const Value.absent(),
                Value<String> permissionMode = const Value.absent(),
                Value<int> currentContextEpoch = const Value.absent(),
                Value<int> contextTokensUsed = const Value.absent(),
                Value<int?> contextWindowTokens = const Value.absent(),
                Value<double> totalCostUsd = const Value.absent(),
                Value<bool> hasCompleteCost = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                worktreeId: worktreeId,
                title: title,
                agentDefinitionId: agentDefinitionId,
                origin: origin,
                parentSessionId: parentSessionId,
                taskName: taskName,
                agentPath: agentPath,
                rootSessionId: rootSessionId,
                lifecycle: lifecycle,
                status: status,
                activeTurnId: activeTurnId,
                lastError: lastError,
                modelId: modelId,
                modelControlsJson: modelControlsJson,
                permissionMode: permissionMode,
                currentContextEpoch: currentContextEpoch,
                contextTokensUsed: contextTokensUsed,
                contextWindowTokens: contextWindowTokens,
                totalCostUsd: totalCostUsd,
                hasCompleteCost: hasCompleteCost,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                worktreeId = false,
                parentSessionId = false,
                rootSessionId = false,
                turnsRefs = false,
                agentMailboxMessagesRefs = false,
                timelineEventsRefs = false,
                approvalRequestsRefs = false,
                userQuestionsRefs = false,
                providerStatesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (turnsRefs) db.turns,
                    if (agentMailboxMessagesRefs) db.agentMailboxMessages,
                    if (timelineEventsRefs) db.timelineEvents,
                    if (approvalRequestsRefs) db.approvalRequests,
                    if (userQuestionsRefs) db.userQuestions,
                    if (providerStatesRefs) db.providerStates,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (worktreeId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.worktreeId,
                            referencedTable: $$SessionsTableReferences
                                ._worktreeIdTable(db),
                            referencedColumn: $$SessionsTableReferences
                                ._worktreeIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (parentSessionId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.parentSessionId,
                            referencedTable: $$SessionsTableReferences
                                ._parentSessionIdTable(db),
                            referencedColumn: $$SessionsTableReferences
                                ._parentSessionIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (rootSessionId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.rootSessionId,
                            referencedTable: $$SessionsTableReferences
                                ._rootSessionIdTable(db),
                            referencedColumn: $$SessionsTableReferences
                                ._rootSessionIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (turnsRefs)
                        await $_getPrefetchedData<
                          Session,
                          $SessionsTable,
                          Turn
                        >(
                          currentTable: table,
                          referencedTable: $$SessionsTableReferences
                              ._turnsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).turnsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (agentMailboxMessagesRefs)
                        await $_getPrefetchedData<
                          Session,
                          $SessionsTable,
                          AgentMailboxMessage
                        >(
                          currentTable: table,
                          referencedTable: $$SessionsTableReferences
                              ._agentMailboxMessagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).agentMailboxMessagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (timelineEventsRefs)
                        await $_getPrefetchedData<
                          Session,
                          $SessionsTable,
                          TimelineEvent
                        >(
                          currentTable: table,
                          referencedTable: $$SessionsTableReferences
                              ._timelineEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).timelineEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (approvalRequestsRefs)
                        await $_getPrefetchedData<
                          Session,
                          $SessionsTable,
                          ApprovalRequest
                        >(
                          currentTable: table,
                          referencedTable: $$SessionsTableReferences
                              ._approvalRequestsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).approvalRequestsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (userQuestionsRefs)
                        await $_getPrefetchedData<
                          Session,
                          $SessionsTable,
                          UserQuestionRow
                        >(
                          currentTable: table,
                          referencedTable: $$SessionsTableReferences
                              ._userQuestionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).userQuestionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (providerStatesRefs)
                        await $_getPrefetchedData<
                          Session,
                          $SessionsTable,
                          ProviderState
                        >(
                          currentTable: table,
                          referencedTable: $$SessionsTableReferences
                              ._providerStatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).providerStatesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$TinestDatabase,
      $SessionsTable,
      Session,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (Session, $$SessionsTableReferences),
      Session,
      PrefetchHooks Function({
        bool worktreeId,
        bool parentSessionId,
        bool rootSessionId,
        bool turnsRefs,
        bool agentMailboxMessagesRefs,
        bool timelineEventsRefs,
        bool approvalRequestsRefs,
        bool userQuestionsRefs,
        bool providerStatesRefs,
      })
    >;
typedef $$TurnsTableCreateCompanionBuilder = TurnsCompanion Function({
  required String id,
  required String sessionId,
  required String prompt,
  required String status,
  Value<String?> error,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$TurnsTableUpdateCompanionBuilder = TurnsCompanion Function({
  Value<String> id,
  Value<String> sessionId,
  Value<String> prompt,
  Value<String> status,
  Value<String?> error,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$TurnsTableReferences
    extends BaseReferences<_$TinestDatabase, $TurnsTable, Turn> {
  $$TurnsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$TinestDatabase db) =>
      db.sessions.createAlias('turns__session_id__sessions__id');

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TurnAttachmentsTable, List<TurnAttachment>>
  _turnAttachmentsRefsTable(_$TinestDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.turnAttachments,
        aliasName: 'turns__id__turn_attachments__turn_id',
      );

  $$TurnAttachmentsTableProcessedTableManager get turnAttachmentsRefs {
    final manager = $$TurnAttachmentsTableTableManager(
      $_db,
      $_db.turnAttachments,
    ).filter((f) => f.turnId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _turnAttachmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ApprovalRequestsTable, List<ApprovalRequest>>
  _approvalRequestsRefsTable(_$TinestDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.approvalRequests,
        aliasName: 'turns__id__approval_requests__turn_id',
      );

  $$ApprovalRequestsTableProcessedTableManager get approvalRequestsRefs {
    final manager = $$ApprovalRequestsTableTableManager(
      $_db,
      $_db.approvalRequests,
    ).filter((f) => f.turnId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _approvalRequestsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$UserQuestionsTable, List<UserQuestionRow>>
  _userQuestionsRefsTable(_$TinestDatabase db) => MultiTypedResultKey.fromTable(
    db.userQuestions,
    aliasName: 'turns__id__user_questions__turn_id',
  );

  $$UserQuestionsTableProcessedTableManager get userQuestionsRefs {
    final manager = $$UserQuestionsTableTableManager(
      $_db,
      $_db.userQuestions,
    ).filter((f) => f.turnId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_userQuestionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TurnsTableFilterComposer
    extends Composer<_$TinestDatabase, $TurnsTable> {
  $$TurnsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prompt => $composableBuilder(
    column: $table.prompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> turnAttachmentsRefs(
    Expression<bool> Function($$TurnAttachmentsTableFilterComposer f) f,
  ) {
    final $$TurnAttachmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.turnAttachments,
      getReferencedColumn: (t) => t.turnId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TurnAttachmentsTableFilterComposer(
            $db: $db,
            $table: $db.turnAttachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> approvalRequestsRefs(
    Expression<bool> Function($$ApprovalRequestsTableFilterComposer f) f,
  ) {
    final $$ApprovalRequestsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.approvalRequests,
      getReferencedColumn: (t) => t.turnId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ApprovalRequestsTableFilterComposer(
            $db: $db,
            $table: $db.approvalRequests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> userQuestionsRefs(
    Expression<bool> Function($$UserQuestionsTableFilterComposer f) f,
  ) {
    final $$UserQuestionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.userQuestions,
      getReferencedColumn: (t) => t.turnId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserQuestionsTableFilterComposer(
            $db: $db,
            $table: $db.userQuestions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TurnsTableOrderingComposer
    extends Composer<_$TinestDatabase, $TurnsTable> {
  $$TurnsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prompt => $composableBuilder(
    column: $table.prompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TurnsTableAnnotationComposer
    extends Composer<_$TinestDatabase, $TurnsTable> {
  $$TurnsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get prompt =>
      $composableBuilder(column: $table.prompt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> turnAttachmentsRefs<T extends Object>(
    Expression<T> Function($$TurnAttachmentsTableAnnotationComposer a) f,
  ) {
    final $$TurnAttachmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.turnAttachments,
      getReferencedColumn: (t) => t.turnId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TurnAttachmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.turnAttachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> approvalRequestsRefs<T extends Object>(
    Expression<T> Function($$ApprovalRequestsTableAnnotationComposer a) f,
  ) {
    final $$ApprovalRequestsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.approvalRequests,
      getReferencedColumn: (t) => t.turnId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ApprovalRequestsTableAnnotationComposer(
            $db: $db,
            $table: $db.approvalRequests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> userQuestionsRefs<T extends Object>(
    Expression<T> Function($$UserQuestionsTableAnnotationComposer a) f,
  ) {
    final $$UserQuestionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.userQuestions,
      getReferencedColumn: (t) => t.turnId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserQuestionsTableAnnotationComposer(
            $db: $db,
            $table: $db.userQuestions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TurnsTableTableManager
    extends
        RootTableManager<
          _$TinestDatabase,
          $TurnsTable,
          Turn,
          $$TurnsTableFilterComposer,
          $$TurnsTableOrderingComposer,
          $$TurnsTableAnnotationComposer,
          $$TurnsTableCreateCompanionBuilder,
          $$TurnsTableUpdateCompanionBuilder,
          (Turn, $$TurnsTableReferences),
          Turn,
          PrefetchHooks Function({
            bool sessionId,
            bool turnAttachmentsRefs,
            bool approvalRequestsRefs,
            bool userQuestionsRefs,
          })
        > {
  $$TurnsTableTableManager(_$TinestDatabase db, $TurnsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TurnsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TurnsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TurnsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> prompt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TurnsCompanion(
                id: id,
                sessionId: sessionId,
                prompt: prompt,
                status: status,
                error: error,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String prompt,
                required String status,
                Value<String?> error = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TurnsCompanion.insert(
                id: id,
                sessionId: sessionId,
                prompt: prompt,
                status: status,
                error: error,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TurnsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                sessionId = false,
                turnAttachmentsRefs = false,
                approvalRequestsRefs = false,
                userQuestionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (turnAttachmentsRefs) db.turnAttachments,
                    if (approvalRequestsRefs) db.approvalRequests,
                    if (userQuestionsRefs) db.userQuestions,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (sessionId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.sessionId,
                            referencedTable: $$TurnsTableReferences
                                ._sessionIdTable(db),
                            referencedColumn: $$TurnsTableReferences
                                ._sessionIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (turnAttachmentsRefs)
                        await $_getPrefetchedData<
                          Turn,
                          $TurnsTable,
                          TurnAttachment
                        >(
                          currentTable: table,
                          referencedTable: $$TurnsTableReferences
                              ._turnAttachmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TurnsTableReferences(
                                db,
                                table,
                                p0,
                              ).turnAttachmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.turnId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (approvalRequestsRefs)
                        await $_getPrefetchedData<
                          Turn,
                          $TurnsTable,
                          ApprovalRequest
                        >(
                          currentTable: table,
                          referencedTable: $$TurnsTableReferences
                              ._approvalRequestsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TurnsTableReferences(
                                db,
                                table,
                                p0,
                              ).approvalRequestsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.turnId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (userQuestionsRefs)
                        await $_getPrefetchedData<
                          Turn,
                          $TurnsTable,
                          UserQuestionRow
                        >(
                          currentTable: table,
                          referencedTable: $$TurnsTableReferences
                              ._userQuestionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TurnsTableReferences(
                                db,
                                table,
                                p0,
                              ).userQuestionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.turnId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TurnsTableProcessedTableManager =
    ProcessedTableManager<
      _$TinestDatabase,
      $TurnsTable,
      Turn,
      $$TurnsTableFilterComposer,
      $$TurnsTableOrderingComposer,
      $$TurnsTableAnnotationComposer,
      $$TurnsTableCreateCompanionBuilder,
      $$TurnsTableUpdateCompanionBuilder,
      (Turn, $$TurnsTableReferences),
      Turn,
      PrefetchHooks Function({
        bool sessionId,
        bool turnAttachmentsRefs,
        bool approvalRequestsRefs,
        bool userQuestionsRefs,
      })
    >;
typedef $$AgentMailboxMessagesTableCreateCompanionBuilder =
    AgentMailboxMessagesCompanion Function({
      required String id,
      required String sessionId,
      Value<String?> senderSessionId,
      required String senderPath,
      required String recipientPath,
      required String messageType,
      required String payload,
      required bool triggerTurn,
      required DateTime createdAt,
      Value<DateTime?> deliveredAt,
      Value<int> rowid,
    });
typedef $$AgentMailboxMessagesTableUpdateCompanionBuilder =
    AgentMailboxMessagesCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String?> senderSessionId,
      Value<String> senderPath,
      Value<String> recipientPath,
      Value<String> messageType,
      Value<String> payload,
      Value<bool> triggerTurn,
      Value<DateTime> createdAt,
      Value<DateTime?> deliveredAt,
      Value<int> rowid,
    });

final class $$AgentMailboxMessagesTableReferences
    extends
        BaseReferences<
          _$TinestDatabase,
          $AgentMailboxMessagesTable,
          AgentMailboxMessage
        > {
  $$AgentMailboxMessagesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SessionsTable _sessionIdTable(_$TinestDatabase db) => db.sessions
      .createAlias('agent_mailbox_messages__session_id__sessions__id');

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AgentMailboxMessagesTableFilterComposer
    extends Composer<_$TinestDatabase, $AgentMailboxMessagesTable> {
  $$AgentMailboxMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderSessionId => $composableBuilder(
    column: $table.senderSessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderPath => $composableBuilder(
    column: $table.senderPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipientPath => $composableBuilder(
    column: $table.recipientPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageType => $composableBuilder(
    column: $table.messageType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get triggerTurn => $composableBuilder(
    column: $table.triggerTurn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deliveredAt => $composableBuilder(
    column: $table.deliveredAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AgentMailboxMessagesTableOrderingComposer
    extends Composer<_$TinestDatabase, $AgentMailboxMessagesTable> {
  $$AgentMailboxMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderSessionId => $composableBuilder(
    column: $table.senderSessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderPath => $composableBuilder(
    column: $table.senderPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipientPath => $composableBuilder(
    column: $table.recipientPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageType => $composableBuilder(
    column: $table.messageType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get triggerTurn => $composableBuilder(
    column: $table.triggerTurn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deliveredAt => $composableBuilder(
    column: $table.deliveredAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AgentMailboxMessagesTableAnnotationComposer
    extends Composer<_$TinestDatabase, $AgentMailboxMessagesTable> {
  $$AgentMailboxMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get senderSessionId => $composableBuilder(
    column: $table.senderSessionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get senderPath => $composableBuilder(
    column: $table.senderPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recipientPath => $composableBuilder(
    column: $table.recipientPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get messageType => $composableBuilder(
    column: $table.messageType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<bool> get triggerTurn => $composableBuilder(
    column: $table.triggerTurn,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deliveredAt => $composableBuilder(
    column: $table.deliveredAt,
    builder: (column) => column,
  );

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AgentMailboxMessagesTableTableManager
    extends
        RootTableManager<
          _$TinestDatabase,
          $AgentMailboxMessagesTable,
          AgentMailboxMessage,
          $$AgentMailboxMessagesTableFilterComposer,
          $$AgentMailboxMessagesTableOrderingComposer,
          $$AgentMailboxMessagesTableAnnotationComposer,
          $$AgentMailboxMessagesTableCreateCompanionBuilder,
          $$AgentMailboxMessagesTableUpdateCompanionBuilder,
          (AgentMailboxMessage, $$AgentMailboxMessagesTableReferences),
          AgentMailboxMessage,
          PrefetchHooks Function({bool sessionId})
        > {
  $$AgentMailboxMessagesTableTableManager(
    _$TinestDatabase db,
    $AgentMailboxMessagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AgentMailboxMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AgentMailboxMessagesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AgentMailboxMessagesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String?> senderSessionId = const Value.absent(),
                Value<String> senderPath = const Value.absent(),
                Value<String> recipientPath = const Value.absent(),
                Value<String> messageType = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<bool> triggerTurn = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deliveredAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AgentMailboxMessagesCompanion(
                id: id,
                sessionId: sessionId,
                senderSessionId: senderSessionId,
                senderPath: senderPath,
                recipientPath: recipientPath,
                messageType: messageType,
                payload: payload,
                triggerTurn: triggerTurn,
                createdAt: createdAt,
                deliveredAt: deliveredAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                Value<String?> senderSessionId = const Value.absent(),
                required String senderPath,
                required String recipientPath,
                required String messageType,
                required String payload,
                required bool triggerTurn,
                required DateTime createdAt,
                Value<DateTime?> deliveredAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AgentMailboxMessagesCompanion.insert(
                id: id,
                sessionId: sessionId,
                senderSessionId: senderSessionId,
                senderPath: senderPath,
                recipientPath: recipientPath,
                messageType: messageType,
                payload: payload,
                triggerTurn: triggerTurn,
                createdAt: createdAt,
                deliveredAt: deliveredAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AgentMailboxMessagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $$AgentMailboxMessagesTableReferences
                            ._sessionIdTable(db),
                        referencedColumn: $$AgentMailboxMessagesTableReferences
                            ._sessionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AgentMailboxMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$TinestDatabase,
      $AgentMailboxMessagesTable,
      AgentMailboxMessage,
      $$AgentMailboxMessagesTableFilterComposer,
      $$AgentMailboxMessagesTableOrderingComposer,
      $$AgentMailboxMessagesTableAnnotationComposer,
      $$AgentMailboxMessagesTableCreateCompanionBuilder,
      $$AgentMailboxMessagesTableUpdateCompanionBuilder,
      (AgentMailboxMessage, $$AgentMailboxMessagesTableReferences),
      AgentMailboxMessage,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$AttachmentsTableCreateCompanionBuilder =
    AttachmentsCompanion Function({
      required String id,
      required String fileName,
      required String mimeType,
      required int byteSize,
      required String kind,
      required String sha256,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$AttachmentsTableUpdateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<String> id,
      Value<String> fileName,
      Value<String> mimeType,
      Value<int> byteSize,
      Value<String> kind,
      Value<String> sha256,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$AttachmentsTableReferences
    extends BaseReferences<_$TinestDatabase, $AttachmentsTable, Attachment> {
  $$AttachmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TurnAttachmentsTable, List<TurnAttachment>>
  _turnAttachmentsRefsTable(_$TinestDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.turnAttachments,
        aliasName: 'attachments__id__turn_attachments__attachment_id',
      );

  $$TurnAttachmentsTableProcessedTableManager get turnAttachmentsRefs {
    final manager = $$TurnAttachmentsTableTableManager(
      $_db,
      $_db.turnAttachments,
    ).filter((f) => f.attachmentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _turnAttachmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AttachmentsTableFilterComposer
    extends Composer<_$TinestDatabase, $AttachmentsTable> {
  $$AttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> turnAttachmentsRefs(
    Expression<bool> Function($$TurnAttachmentsTableFilterComposer f) f,
  ) {
    final $$TurnAttachmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.turnAttachments,
      getReferencedColumn: (t) => t.attachmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TurnAttachmentsTableFilterComposer(
            $db: $db,
            $table: $db.turnAttachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AttachmentsTableOrderingComposer
    extends Composer<_$TinestDatabase, $AttachmentsTable> {
  $$AttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttachmentsTableAnnotationComposer
    extends Composer<_$TinestDatabase, $AttachmentsTable> {
  $$AttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get byteSize =>
      $composableBuilder(column: $table.byteSize, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> turnAttachmentsRefs<T extends Object>(
    Expression<T> Function($$TurnAttachmentsTableAnnotationComposer a) f,
  ) {
    final $$TurnAttachmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.turnAttachments,
      getReferencedColumn: (t) => t.attachmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TurnAttachmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.turnAttachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AttachmentsTableTableManager
    extends
        RootTableManager<
          _$TinestDatabase,
          $AttachmentsTable,
          Attachment,
          $$AttachmentsTableFilterComposer,
          $$AttachmentsTableOrderingComposer,
          $$AttachmentsTableAnnotationComposer,
          $$AttachmentsTableCreateCompanionBuilder,
          $$AttachmentsTableUpdateCompanionBuilder,
          (Attachment, $$AttachmentsTableReferences),
          Attachment,
          PrefetchHooks Function({bool turnAttachmentsRefs})
        > {
  $$AttachmentsTableTableManager(_$TinestDatabase db, $AttachmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion(
                id: id,
                fileName: fileName,
                mimeType: mimeType,
                byteSize: byteSize,
                kind: kind,
                sha256: sha256,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String fileName,
                required String mimeType,
                required int byteSize,
                required String kind,
                required String sha256,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion.insert(
                id: id,
                fileName: fileName,
                mimeType: mimeType,
                byteSize: byteSize,
                kind: kind,
                sha256: sha256,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AttachmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({turnAttachmentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (turnAttachmentsRefs) db.turnAttachments,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (turnAttachmentsRefs)
                    await $_getPrefetchedData<
                      Attachment,
                      $AttachmentsTable,
                      TurnAttachment
                    >(
                      currentTable: table,
                      referencedTable: $$AttachmentsTableReferences
                          ._turnAttachmentsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$AttachmentsTableReferences(
                            db,
                            table,
                            p0,
                          ).turnAttachmentsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.attachmentId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$AttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$TinestDatabase,
      $AttachmentsTable,
      Attachment,
      $$AttachmentsTableFilterComposer,
      $$AttachmentsTableOrderingComposer,
      $$AttachmentsTableAnnotationComposer,
      $$AttachmentsTableCreateCompanionBuilder,
      $$AttachmentsTableUpdateCompanionBuilder,
      (Attachment, $$AttachmentsTableReferences),
      Attachment,
      PrefetchHooks Function({bool turnAttachmentsRefs})
    >;
typedef $$TurnAttachmentsTableCreateCompanionBuilder =
    TurnAttachmentsCompanion Function({
      required String turnId,
      required String attachmentId,
      required String direction,
      required int ordinal,
      Value<int> rowid,
    });
typedef $$TurnAttachmentsTableUpdateCompanionBuilder =
    TurnAttachmentsCompanion Function({
      Value<String> turnId,
      Value<String> attachmentId,
      Value<String> direction,
      Value<int> ordinal,
      Value<int> rowid,
    });

final class $$TurnAttachmentsTableReferences
    extends
        BaseReferences<
          _$TinestDatabase,
          $TurnAttachmentsTable,
          TurnAttachment
        > {
  $$TurnAttachmentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TurnsTable _turnIdTable(_$TinestDatabase db) =>
      db.turns.createAlias('turn_attachments__turn_id__turns__id');

  $$TurnsTableProcessedTableManager get turnId {
    final $_column = $_itemColumn<String>('turn_id')!;

    final manager = $$TurnsTableTableManager(
      $_db,
      $_db.turns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_turnIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AttachmentsTable _attachmentIdTable(_$TinestDatabase db) => db
      .attachments
      .createAlias('turn_attachments__attachment_id__attachments__id');

  $$AttachmentsTableProcessedTableManager get attachmentId {
    final $_column = $_itemColumn<String>('attachment_id')!;

    final manager = $$AttachmentsTableTableManager(
      $_db,
      $_db.attachments,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_attachmentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TurnAttachmentsTableFilterComposer
    extends Composer<_$TinestDatabase, $TurnAttachmentsTable> {
  $$TurnAttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  $$TurnsTableFilterComposer get turnId {
    final $$TurnsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.turnId,
      referencedTable: $db.turns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TurnsTableFilterComposer(
            $db: $db,
            $table: $db.turns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AttachmentsTableFilterComposer get attachmentId {
    final $$AttachmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attachmentId,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableFilterComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TurnAttachmentsTableOrderingComposer
    extends Composer<_$TinestDatabase, $TurnAttachmentsTable> {
  $$TurnAttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  $$TurnsTableOrderingComposer get turnId {
    final $$TurnsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.turnId,
      referencedTable: $db.turns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TurnsTableOrderingComposer(
            $db: $db,
            $table: $db.turns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AttachmentsTableOrderingComposer get attachmentId {
    final $$AttachmentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attachmentId,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableOrderingComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TurnAttachmentsTableAnnotationComposer
    extends Composer<_$TinestDatabase, $TurnAttachmentsTable> {
  $$TurnAttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  $$TurnsTableAnnotationComposer get turnId {
    final $$TurnsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.turnId,
      referencedTable: $db.turns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TurnsTableAnnotationComposer(
            $db: $db,
            $table: $db.turns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AttachmentsTableAnnotationComposer get attachmentId {
    final $$AttachmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attachmentId,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TurnAttachmentsTableTableManager
    extends
        RootTableManager<
          _$TinestDatabase,
          $TurnAttachmentsTable,
          TurnAttachment,
          $$TurnAttachmentsTableFilterComposer,
          $$TurnAttachmentsTableOrderingComposer,
          $$TurnAttachmentsTableAnnotationComposer,
          $$TurnAttachmentsTableCreateCompanionBuilder,
          $$TurnAttachmentsTableUpdateCompanionBuilder,
          (TurnAttachment, $$TurnAttachmentsTableReferences),
          TurnAttachment,
          PrefetchHooks Function({bool turnId, bool attachmentId})
        > {
  $$TurnAttachmentsTableTableManager(
    _$TinestDatabase db,
    $TurnAttachmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TurnAttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TurnAttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TurnAttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> turnId = const Value.absent(),
                Value<String> attachmentId = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TurnAttachmentsCompanion(
                turnId: turnId,
                attachmentId: attachmentId,
                direction: direction,
                ordinal: ordinal,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String turnId,
                required String attachmentId,
                required String direction,
                required int ordinal,
                Value<int> rowid = const Value.absent(),
              }) => TurnAttachmentsCompanion.insert(
                turnId: turnId,
                attachmentId: attachmentId,
                direction: direction,
                ordinal: ordinal,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TurnAttachmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({turnId = false, attachmentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (turnId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.turnId,
                        referencedTable: $$TurnAttachmentsTableReferences
                            ._turnIdTable(db),
                        referencedColumn: $$TurnAttachmentsTableReferences
                            ._turnIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (attachmentId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.attachmentId,
                        referencedTable: $$TurnAttachmentsTableReferences
                            ._attachmentIdTable(db),
                        referencedColumn: $$TurnAttachmentsTableReferences
                            ._attachmentIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TurnAttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$TinestDatabase,
      $TurnAttachmentsTable,
      TurnAttachment,
      $$TurnAttachmentsTableFilterComposer,
      $$TurnAttachmentsTableOrderingComposer,
      $$TurnAttachmentsTableAnnotationComposer,
      $$TurnAttachmentsTableCreateCompanionBuilder,
      $$TurnAttachmentsTableUpdateCompanionBuilder,
      (TurnAttachment, $$TurnAttachmentsTableReferences),
      TurnAttachment,
      PrefetchHooks Function({bool turnId, bool attachmentId})
    >;
typedef $$TimelineEventsTableCreateCompanionBuilder =
    TimelineEventsCompanion Function({
      required String sessionId,
      required int sequence,
      Value<String?> turnId,
      required String type,
      required String dataJson,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$TimelineEventsTableUpdateCompanionBuilder =
    TimelineEventsCompanion Function({
      Value<String> sessionId,
      Value<int> sequence,
      Value<String?> turnId,
      Value<String> type,
      Value<String> dataJson,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$TimelineEventsTableReferences
    extends
        BaseReferences<_$TinestDatabase, $TimelineEventsTable, TimelineEvent> {
  $$TimelineEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SessionsTable _sessionIdTable(_$TinestDatabase db) =>
      db.sessions.createAlias('timeline_events__session_id__sessions__id');

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TimelineEventsTableFilterComposer
    extends Composer<_$TinestDatabase, $TimelineEventsTable> {
  $$TimelineEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get turnId => $composableBuilder(
    column: $table.turnId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimelineEventsTableOrderingComposer
    extends Composer<_$TinestDatabase, $TimelineEventsTable> {
  $$TimelineEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get turnId => $composableBuilder(
    column: $table.turnId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimelineEventsTableAnnotationComposer
    extends Composer<_$TinestDatabase, $TimelineEventsTable> {
  $$TimelineEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get turnId =>
      $composableBuilder(column: $table.turnId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimelineEventsTableTableManager
    extends
        RootTableManager<
          _$TinestDatabase,
          $TimelineEventsTable,
          TimelineEvent,
          $$TimelineEventsTableFilterComposer,
          $$TimelineEventsTableOrderingComposer,
          $$TimelineEventsTableAnnotationComposer,
          $$TimelineEventsTableCreateCompanionBuilder,
          $$TimelineEventsTableUpdateCompanionBuilder,
          (TimelineEvent, $$TimelineEventsTableReferences),
          TimelineEvent,
          PrefetchHooks Function({bool sessionId})
        > {
  $$TimelineEventsTableTableManager(
    _$TinestDatabase db,
    $TimelineEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TimelineEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TimelineEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TimelineEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<String?> turnId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TimelineEventsCompanion(
                sessionId: sessionId,
                sequence: sequence,
                turnId: turnId,
                type: type,
                dataJson: dataJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required int sequence,
                Value<String?> turnId = const Value.absent(),
                required String type,
                required String dataJson,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TimelineEventsCompanion.insert(
                sessionId: sessionId,
                sequence: sequence,
                turnId: turnId,
                type: type,
                dataJson: dataJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TimelineEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $$TimelineEventsTableReferences
                            ._sessionIdTable(db),
                        referencedColumn: $$TimelineEventsTableReferences
                            ._sessionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TimelineEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$TinestDatabase,
      $TimelineEventsTable,
      TimelineEvent,
      $$TimelineEventsTableFilterComposer,
      $$TimelineEventsTableOrderingComposer,
      $$TimelineEventsTableAnnotationComposer,
      $$TimelineEventsTableCreateCompanionBuilder,
      $$TimelineEventsTableUpdateCompanionBuilder,
      (TimelineEvent, $$TimelineEventsTableReferences),
      TimelineEvent,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$ApprovalRequestsTableCreateCompanionBuilder =
    ApprovalRequestsCompanion Function({
      required String id,
      required String sessionId,
      required String turnId,
      required String toolCallId,
      required String toolName,
      required String risk,
      required String argumentsJson,
      Value<String?> preview,
      required String status,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ApprovalRequestsTableUpdateCompanionBuilder =
    ApprovalRequestsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String> turnId,
      Value<String> toolCallId,
      Value<String> toolName,
      Value<String> risk,
      Value<String> argumentsJson,
      Value<String?> preview,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ApprovalRequestsTableReferences
    extends
        BaseReferences<
          _$TinestDatabase,
          $ApprovalRequestsTable,
          ApprovalRequest
        > {
  $$ApprovalRequestsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SessionsTable _sessionIdTable(_$TinestDatabase db) =>
      db.sessions.createAlias('approval_requests__session_id__sessions__id');

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TurnsTable _turnIdTable(_$TinestDatabase db) =>
      db.turns.createAlias('approval_requests__turn_id__turns__id');

  $$TurnsTableProcessedTableManager get turnId {
    final $_column = $_itemColumn<String>('turn_id')!;

    final manager = $$TurnsTableTableManager(
      $_db,
      $_db.turns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_turnIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ApprovalRequestsTableFilterComposer
    extends Composer<_$TinestDatabase, $ApprovalRequestsTable> {
  $$ApprovalRequestsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toolCallId => $composableBuilder(
    column: $table.toolCallId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toolName => $composableBuilder(
    column: $table.toolName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get risk => $composableBuilder(
    column: $table.risk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get argumentsJson => $composableBuilder(
    column: $table.argumentsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preview => $composableBuilder(
    column: $table.preview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TurnsTableFilterComposer get turnId {
    final $$TurnsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.turnId,
      referencedTable: $db.turns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TurnsTableFilterComposer(
            $db: $db,
            $table: $db.turns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ApprovalRequestsTableOrderingComposer
    extends Composer<_$TinestDatabase, $ApprovalRequestsTable> {
  $$ApprovalRequestsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toolCallId => $composableBuilder(
    column: $table.toolCallId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toolName => $composableBuilder(
    column: $table.toolName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get risk => $composableBuilder(
    column: $table.risk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get argumentsJson => $composableBuilder(
    column: $table.argumentsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preview => $composableBuilder(
    column: $table.preview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TurnsTableOrderingComposer get turnId {
    final $$TurnsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.turnId,
      referencedTable: $db.turns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TurnsTableOrderingComposer(
            $db: $db,
            $table: $db.turns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ApprovalRequestsTableAnnotationComposer
    extends Composer<_$TinestDatabase, $ApprovalRequestsTable> {
  $$ApprovalRequestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get toolCallId => $composableBuilder(
    column: $table.toolCallId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toolName =>
      $composableBuilder(column: $table.toolName, builder: (column) => column);

  GeneratedColumn<String> get risk =>
      $composableBuilder(column: $table.risk, builder: (column) => column);

  GeneratedColumn<String> get argumentsJson => $composableBuilder(
    column: $table.argumentsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preview =>
      $composableBuilder(column: $table.preview, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TurnsTableAnnotationComposer get turnId {
    final $$TurnsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.turnId,
      referencedTable: $db.turns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TurnsTableAnnotationComposer(
            $db: $db,
            $table: $db.turns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ApprovalRequestsTableTableManager
    extends
        RootTableManager<
          _$TinestDatabase,
          $ApprovalRequestsTable,
          ApprovalRequest,
          $$ApprovalRequestsTableFilterComposer,
          $$ApprovalRequestsTableOrderingComposer,
          $$ApprovalRequestsTableAnnotationComposer,
          $$ApprovalRequestsTableCreateCompanionBuilder,
          $$ApprovalRequestsTableUpdateCompanionBuilder,
          (ApprovalRequest, $$ApprovalRequestsTableReferences),
          ApprovalRequest,
          PrefetchHooks Function({bool sessionId, bool turnId})
        > {
  $$ApprovalRequestsTableTableManager(
    _$TinestDatabase db,
    $ApprovalRequestsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ApprovalRequestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ApprovalRequestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ApprovalRequestsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> turnId = const Value.absent(),
                Value<String> toolCallId = const Value.absent(),
                Value<String> toolName = const Value.absent(),
                Value<String> risk = const Value.absent(),
                Value<String> argumentsJson = const Value.absent(),
                Value<String?> preview = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ApprovalRequestsCompanion(
                id: id,
                sessionId: sessionId,
                turnId: turnId,
                toolCallId: toolCallId,
                toolName: toolName,
                risk: risk,
                argumentsJson: argumentsJson,
                preview: preview,
                status: status,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String turnId,
                required String toolCallId,
                required String toolName,
                required String risk,
                required String argumentsJson,
                Value<String?> preview = const Value.absent(),
                required String status,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ApprovalRequestsCompanion.insert(
                id: id,
                sessionId: sessionId,
                turnId: turnId,
                toolCallId: toolCallId,
                toolName: toolName,
                risk: risk,
                argumentsJson: argumentsJson,
                preview: preview,
                status: status,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ApprovalRequestsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false, turnId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $$ApprovalRequestsTableReferences
                            ._sessionIdTable(db),
                        referencedColumn: $$ApprovalRequestsTableReferences
                            ._sessionIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (turnId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.turnId,
                        referencedTable: $$ApprovalRequestsTableReferences
                            ._turnIdTable(db),
                        referencedColumn: $$ApprovalRequestsTableReferences
                            ._turnIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ApprovalRequestsTableProcessedTableManager =
    ProcessedTableManager<
      _$TinestDatabase,
      $ApprovalRequestsTable,
      ApprovalRequest,
      $$ApprovalRequestsTableFilterComposer,
      $$ApprovalRequestsTableOrderingComposer,
      $$ApprovalRequestsTableAnnotationComposer,
      $$ApprovalRequestsTableCreateCompanionBuilder,
      $$ApprovalRequestsTableUpdateCompanionBuilder,
      (ApprovalRequest, $$ApprovalRequestsTableReferences),
      ApprovalRequest,
      PrefetchHooks Function({bool sessionId, bool turnId})
    >;
typedef $$UserQuestionsTableCreateCompanionBuilder =
    UserQuestionsCompanion Function({
      required String id,
      required String sessionId,
      required String turnId,
      required String toolCallId,
      required String questionsJson,
      required String answersJson,
      required String status,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$UserQuestionsTableUpdateCompanionBuilder =
    UserQuestionsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String> turnId,
      Value<String> toolCallId,
      Value<String> questionsJson,
      Value<String> answersJson,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$UserQuestionsTableReferences
    extends
        BaseReferences<_$TinestDatabase, $UserQuestionsTable, UserQuestionRow> {
  $$UserQuestionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SessionsTable _sessionIdTable(_$TinestDatabase db) =>
      db.sessions.createAlias('user_questions__session_id__sessions__id');

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TurnsTable _turnIdTable(_$TinestDatabase db) =>
      db.turns.createAlias('user_questions__turn_id__turns__id');

  $$TurnsTableProcessedTableManager get turnId {
    final $_column = $_itemColumn<String>('turn_id')!;

    final manager = $$TurnsTableTableManager(
      $_db,
      $_db.turns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_turnIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$UserQuestionsTableFilterComposer
    extends Composer<_$TinestDatabase, $UserQuestionsTable> {
  $$UserQuestionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toolCallId => $composableBuilder(
    column: $table.toolCallId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get questionsJson => $composableBuilder(
    column: $table.questionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answersJson => $composableBuilder(
    column: $table.answersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TurnsTableFilterComposer get turnId {
    final $$TurnsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.turnId,
      referencedTable: $db.turns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TurnsTableFilterComposer(
            $db: $db,
            $table: $db.turns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserQuestionsTableOrderingComposer
    extends Composer<_$TinestDatabase, $UserQuestionsTable> {
  $$UserQuestionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toolCallId => $composableBuilder(
    column: $table.toolCallId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get questionsJson => $composableBuilder(
    column: $table.questionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answersJson => $composableBuilder(
    column: $table.answersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TurnsTableOrderingComposer get turnId {
    final $$TurnsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.turnId,
      referencedTable: $db.turns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TurnsTableOrderingComposer(
            $db: $db,
            $table: $db.turns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserQuestionsTableAnnotationComposer
    extends Composer<_$TinestDatabase, $UserQuestionsTable> {
  $$UserQuestionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get toolCallId => $composableBuilder(
    column: $table.toolCallId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get questionsJson => $composableBuilder(
    column: $table.questionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get answersJson => $composableBuilder(
    column: $table.answersJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TurnsTableAnnotationComposer get turnId {
    final $$TurnsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.turnId,
      referencedTable: $db.turns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TurnsTableAnnotationComposer(
            $db: $db,
            $table: $db.turns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserQuestionsTableTableManager
    extends
        RootTableManager<
          _$TinestDatabase,
          $UserQuestionsTable,
          UserQuestionRow,
          $$UserQuestionsTableFilterComposer,
          $$UserQuestionsTableOrderingComposer,
          $$UserQuestionsTableAnnotationComposer,
          $$UserQuestionsTableCreateCompanionBuilder,
          $$UserQuestionsTableUpdateCompanionBuilder,
          (UserQuestionRow, $$UserQuestionsTableReferences),
          UserQuestionRow,
          PrefetchHooks Function({bool sessionId, bool turnId})
        > {
  $$UserQuestionsTableTableManager(
    _$TinestDatabase db,
    $UserQuestionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserQuestionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserQuestionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserQuestionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> turnId = const Value.absent(),
                Value<String> toolCallId = const Value.absent(),
                Value<String> questionsJson = const Value.absent(),
                Value<String> answersJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserQuestionsCompanion(
                id: id,
                sessionId: sessionId,
                turnId: turnId,
                toolCallId: toolCallId,
                questionsJson: questionsJson,
                answersJson: answersJson,
                status: status,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String turnId,
                required String toolCallId,
                required String questionsJson,
                required String answersJson,
                required String status,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => UserQuestionsCompanion.insert(
                id: id,
                sessionId: sessionId,
                turnId: turnId,
                toolCallId: toolCallId,
                questionsJson: questionsJson,
                answersJson: answersJson,
                status: status,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$UserQuestionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false, turnId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $$UserQuestionsTableReferences
                            ._sessionIdTable(db),
                        referencedColumn: $$UserQuestionsTableReferences
                            ._sessionIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (turnId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.turnId,
                        referencedTable: $$UserQuestionsTableReferences
                            ._turnIdTable(db),
                        referencedColumn: $$UserQuestionsTableReferences
                            ._turnIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$UserQuestionsTableProcessedTableManager =
    ProcessedTableManager<
      _$TinestDatabase,
      $UserQuestionsTable,
      UserQuestionRow,
      $$UserQuestionsTableFilterComposer,
      $$UserQuestionsTableOrderingComposer,
      $$UserQuestionsTableAnnotationComposer,
      $$UserQuestionsTableCreateCompanionBuilder,
      $$UserQuestionsTableUpdateCompanionBuilder,
      (UserQuestionRow, $$UserQuestionsTableReferences),
      UserQuestionRow,
      PrefetchHooks Function({bool sessionId, bool turnId})
    >;
typedef $$ProviderStatesTableCreateCompanionBuilder =
    ProviderStatesCompanion Function({
      required String sessionId,
      required int ordinal,
      required String itemJson,
      Value<int> contextEpoch,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ProviderStatesTableUpdateCompanionBuilder =
    ProviderStatesCompanion Function({
      Value<String> sessionId,
      Value<int> ordinal,
      Value<String> itemJson,
      Value<int> contextEpoch,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ProviderStatesTableReferences
    extends
        BaseReferences<_$TinestDatabase, $ProviderStatesTable, ProviderState> {
  $$ProviderStatesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SessionsTable _sessionIdTable(_$TinestDatabase db) =>
      db.sessions.createAlias('provider_states__session_id__sessions__id');

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ProviderStatesTableFilterComposer
    extends Composer<_$TinestDatabase, $ProviderStatesTable> {
  $$ProviderStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemJson => $composableBuilder(
    column: $table.itemJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contextEpoch => $composableBuilder(
    column: $table.contextEpoch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProviderStatesTableOrderingComposer
    extends Composer<_$TinestDatabase, $ProviderStatesTable> {
  $$ProviderStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemJson => $composableBuilder(
    column: $table.itemJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contextEpoch => $composableBuilder(
    column: $table.contextEpoch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProviderStatesTableAnnotationComposer
    extends Composer<_$TinestDatabase, $ProviderStatesTable> {
  $$ProviderStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  GeneratedColumn<String> get itemJson =>
      $composableBuilder(column: $table.itemJson, builder: (column) => column);

  GeneratedColumn<int> get contextEpoch => $composableBuilder(
    column: $table.contextEpoch,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProviderStatesTableTableManager
    extends
        RootTableManager<
          _$TinestDatabase,
          $ProviderStatesTable,
          ProviderState,
          $$ProviderStatesTableFilterComposer,
          $$ProviderStatesTableOrderingComposer,
          $$ProviderStatesTableAnnotationComposer,
          $$ProviderStatesTableCreateCompanionBuilder,
          $$ProviderStatesTableUpdateCompanionBuilder,
          (ProviderState, $$ProviderStatesTableReferences),
          ProviderState,
          PrefetchHooks Function({bool sessionId})
        > {
  $$ProviderStatesTableTableManager(
    _$TinestDatabase db,
    $ProviderStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProviderStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProviderStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProviderStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<String> itemJson = const Value.absent(),
                Value<int> contextEpoch = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProviderStatesCompanion(
                sessionId: sessionId,
                ordinal: ordinal,
                itemJson: itemJson,
                contextEpoch: contextEpoch,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required int ordinal,
                required String itemJson,
                Value<int> contextEpoch = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ProviderStatesCompanion.insert(
                sessionId: sessionId,
                ordinal: ordinal,
                itemJson: itemJson,
                contextEpoch: contextEpoch,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProviderStatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $$ProviderStatesTableReferences
                            ._sessionIdTable(db),
                        referencedColumn: $$ProviderStatesTableReferences
                            ._sessionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ProviderStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$TinestDatabase,
      $ProviderStatesTable,
      ProviderState,
      $$ProviderStatesTableFilterComposer,
      $$ProviderStatesTableOrderingComposer,
      $$ProviderStatesTableAnnotationComposer,
      $$ProviderStatesTableCreateCompanionBuilder,
      $$ProviderStatesTableUpdateCompanionBuilder,
      (ProviderState, $$ProviderStatesTableReferences),
      ProviderState,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$TinestDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$TinestDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$TinestDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$TinestDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$TinestDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$TinestDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$TinestDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$TinestDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$ProviderConnectionsTableCreateCompanionBuilder =
    ProviderConnectionsCompanion Function({
      required String id,
      required String definitionId,
      required String modelPrefix,
      required String displayName,
      required String status,
      required String authKind,
      required String credentialOrigin,
      Value<String?> error,
      Value<String?> customConfigJson,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ProviderConnectionsTableUpdateCompanionBuilder =
    ProviderConnectionsCompanion Function({
      Value<String> id,
      Value<String> definitionId,
      Value<String> modelPrefix,
      Value<String> displayName,
      Value<String> status,
      Value<String> authKind,
      Value<String> credentialOrigin,
      Value<String?> error,
      Value<String?> customConfigJson,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$ProviderConnectionsTableReferences
    extends
        BaseReferences<
          _$TinestDatabase,
          $ProviderConnectionsTable,
          ProviderConnection
        > {
  $$ProviderConnectionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$ProviderModelsTable, List<ProviderModel>>
  _providerModelsRefsTable(_$TinestDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.providerModels,
        aliasName: 'provider_connections__id__provider_models__connection_id',
      );

  $$ProviderModelsTableProcessedTableManager get providerModelsRefs {
    final manager = $$ProviderModelsTableTableManager(
      $_db,
      $_db.providerModels,
    ).filter((f) => f.connectionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_providerModelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProviderConnectionsTableFilterComposer
    extends Composer<_$TinestDatabase, $ProviderConnectionsTable> {
  $$ProviderConnectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get definitionId => $composableBuilder(
    column: $table.definitionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelPrefix => $composableBuilder(
    column: $table.modelPrefix,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authKind => $composableBuilder(
    column: $table.authKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get credentialOrigin => $composableBuilder(
    column: $table.credentialOrigin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customConfigJson => $composableBuilder(
    column: $table.customConfigJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> providerModelsRefs(
    Expression<bool> Function($$ProviderModelsTableFilterComposer f) f,
  ) {
    final $$ProviderModelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.providerModels,
      getReferencedColumn: (t) => t.connectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProviderModelsTableFilterComposer(
            $db: $db,
            $table: $db.providerModels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProviderConnectionsTableOrderingComposer
    extends Composer<_$TinestDatabase, $ProviderConnectionsTable> {
  $$ProviderConnectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get definitionId => $composableBuilder(
    column: $table.definitionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelPrefix => $composableBuilder(
    column: $table.modelPrefix,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authKind => $composableBuilder(
    column: $table.authKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get credentialOrigin => $composableBuilder(
    column: $table.credentialOrigin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customConfigJson => $composableBuilder(
    column: $table.customConfigJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProviderConnectionsTableAnnotationComposer
    extends Composer<_$TinestDatabase, $ProviderConnectionsTable> {
  $$ProviderConnectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get definitionId => $composableBuilder(
    column: $table.definitionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelPrefix => $composableBuilder(
    column: $table.modelPrefix,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get authKind =>
      $composableBuilder(column: $table.authKind, builder: (column) => column);

  GeneratedColumn<String> get credentialOrigin => $composableBuilder(
    column: $table.credentialOrigin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<String> get customConfigJson => $composableBuilder(
    column: $table.customConfigJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> providerModelsRefs<T extends Object>(
    Expression<T> Function($$ProviderModelsTableAnnotationComposer a) f,
  ) {
    final $$ProviderModelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.providerModels,
      getReferencedColumn: (t) => t.connectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProviderModelsTableAnnotationComposer(
            $db: $db,
            $table: $db.providerModels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProviderConnectionsTableTableManager
    extends
        RootTableManager<
          _$TinestDatabase,
          $ProviderConnectionsTable,
          ProviderConnection,
          $$ProviderConnectionsTableFilterComposer,
          $$ProviderConnectionsTableOrderingComposer,
          $$ProviderConnectionsTableAnnotationComposer,
          $$ProviderConnectionsTableCreateCompanionBuilder,
          $$ProviderConnectionsTableUpdateCompanionBuilder,
          (ProviderConnection, $$ProviderConnectionsTableReferences),
          ProviderConnection,
          PrefetchHooks Function({bool providerModelsRefs})
        > {
  $$ProviderConnectionsTableTableManager(
    _$TinestDatabase db,
    $ProviderConnectionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProviderConnectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProviderConnectionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ProviderConnectionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> definitionId = const Value.absent(),
                Value<String> modelPrefix = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> authKind = const Value.absent(),
                Value<String> credentialOrigin = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<String?> customConfigJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProviderConnectionsCompanion(
                id: id,
                definitionId: definitionId,
                modelPrefix: modelPrefix,
                displayName: displayName,
                status: status,
                authKind: authKind,
                credentialOrigin: credentialOrigin,
                error: error,
                customConfigJson: customConfigJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String definitionId,
                required String modelPrefix,
                required String displayName,
                required String status,
                required String authKind,
                required String credentialOrigin,
                Value<String?> error = const Value.absent(),
                Value<String?> customConfigJson = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ProviderConnectionsCompanion.insert(
                id: id,
                definitionId: definitionId,
                modelPrefix: modelPrefix,
                displayName: displayName,
                status: status,
                authKind: authKind,
                credentialOrigin: credentialOrigin,
                error: error,
                customConfigJson: customConfigJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProviderConnectionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({providerModelsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (providerModelsRefs) db.providerModels,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (providerModelsRefs)
                    await $_getPrefetchedData<
                      ProviderConnection,
                      $ProviderConnectionsTable,
                      ProviderModel
                    >(
                      currentTable: table,
                      referencedTable: $$ProviderConnectionsTableReferences
                          ._providerModelsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ProviderConnectionsTableReferences(
                            db,
                            table,
                            p0,
                          ).providerModelsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.connectionId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ProviderConnectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$TinestDatabase,
      $ProviderConnectionsTable,
      ProviderConnection,
      $$ProviderConnectionsTableFilterComposer,
      $$ProviderConnectionsTableOrderingComposer,
      $$ProviderConnectionsTableAnnotationComposer,
      $$ProviderConnectionsTableCreateCompanionBuilder,
      $$ProviderConnectionsTableUpdateCompanionBuilder,
      (ProviderConnection, $$ProviderConnectionsTableReferences),
      ProviderConnection,
      PrefetchHooks Function({bool providerModelsRefs})
    >;
typedef $$ProviderModelsTableCreateCompanionBuilder =
    ProviderModelsCompanion Function({
      required String connectionId,
      required String modelId,
      required String providerModelId,
      required String label,
      required String source,
      required String capabilitiesJson,
      Value<String?> pricingJson,
      Value<String?> limitsJson,
      Value<String> diagnosticStatus,
      Value<DateTime?> verifiedAt,
      Value<String?> diagnosticError,
      Value<int> rowid,
    });
typedef $$ProviderModelsTableUpdateCompanionBuilder =
    ProviderModelsCompanion Function({
      Value<String> connectionId,
      Value<String> modelId,
      Value<String> providerModelId,
      Value<String> label,
      Value<String> source,
      Value<String> capabilitiesJson,
      Value<String?> pricingJson,
      Value<String?> limitsJson,
      Value<String> diagnosticStatus,
      Value<DateTime?> verifiedAt,
      Value<String?> diagnosticError,
      Value<int> rowid,
    });

final class $$ProviderModelsTableReferences
    extends
        BaseReferences<_$TinestDatabase, $ProviderModelsTable, ProviderModel> {
  $$ProviderModelsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProviderConnectionsTable _connectionIdTable(_$TinestDatabase db) => db
      .providerConnections
      .createAlias('provider_models__connection_id__provider_connections__id');

  $$ProviderConnectionsTableProcessedTableManager get connectionId {
    final $_column = $_itemColumn<String>('connection_id')!;

    final manager = $$ProviderConnectionsTableTableManager(
      $_db,
      $_db.providerConnections,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_connectionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ProviderModelsTableFilterComposer
    extends Composer<_$TinestDatabase, $ProviderModelsTable> {
  $$ProviderModelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerModelId => $composableBuilder(
    column: $table.providerModelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pricingJson => $composableBuilder(
    column: $table.pricingJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get limitsJson => $composableBuilder(
    column: $table.limitsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get diagnosticStatus => $composableBuilder(
    column: $table.diagnosticStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get verifiedAt => $composableBuilder(
    column: $table.verifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get diagnosticError => $composableBuilder(
    column: $table.diagnosticError,
    builder: (column) => ColumnFilters(column),
  );

  $$ProviderConnectionsTableFilterComposer get connectionId {
    final $$ProviderConnectionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.connectionId,
      referencedTable: $db.providerConnections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProviderConnectionsTableFilterComposer(
            $db: $db,
            $table: $db.providerConnections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProviderModelsTableOrderingComposer
    extends Composer<_$TinestDatabase, $ProviderModelsTable> {
  $$ProviderModelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerModelId => $composableBuilder(
    column: $table.providerModelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pricingJson => $composableBuilder(
    column: $table.pricingJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get limitsJson => $composableBuilder(
    column: $table.limitsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get diagnosticStatus => $composableBuilder(
    column: $table.diagnosticStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get verifiedAt => $composableBuilder(
    column: $table.verifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get diagnosticError => $composableBuilder(
    column: $table.diagnosticError,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProviderConnectionsTableOrderingComposer get connectionId {
    final $$ProviderConnectionsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.connectionId,
          referencedTable: $db.providerConnections,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ProviderConnectionsTableOrderingComposer(
                $db: $db,
                $table: $db.providerConnections,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$ProviderModelsTableAnnotationComposer
    extends Composer<_$TinestDatabase, $ProviderModelsTable> {
  $$ProviderModelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<String> get providerModelId => $composableBuilder(
    column: $table.providerModelId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pricingJson => $composableBuilder(
    column: $table.pricingJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get limitsJson => $composableBuilder(
    column: $table.limitsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get diagnosticStatus => $composableBuilder(
    column: $table.diagnosticStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get verifiedAt => $composableBuilder(
    column: $table.verifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get diagnosticError => $composableBuilder(
    column: $table.diagnosticError,
    builder: (column) => column,
  );

  $$ProviderConnectionsTableAnnotationComposer get connectionId {
    final $$ProviderConnectionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.connectionId,
          referencedTable: $db.providerConnections,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ProviderConnectionsTableAnnotationComposer(
                $db: $db,
                $table: $db.providerConnections,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$ProviderModelsTableTableManager
    extends
        RootTableManager<
          _$TinestDatabase,
          $ProviderModelsTable,
          ProviderModel,
          $$ProviderModelsTableFilterComposer,
          $$ProviderModelsTableOrderingComposer,
          $$ProviderModelsTableAnnotationComposer,
          $$ProviderModelsTableCreateCompanionBuilder,
          $$ProviderModelsTableUpdateCompanionBuilder,
          (ProviderModel, $$ProviderModelsTableReferences),
          ProviderModel,
          PrefetchHooks Function({bool connectionId})
        > {
  $$ProviderModelsTableTableManager(
    _$TinestDatabase db,
    $ProviderModelsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProviderModelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProviderModelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProviderModelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> connectionId = const Value.absent(),
                Value<String> modelId = const Value.absent(),
                Value<String> providerModelId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> capabilitiesJson = const Value.absent(),
                Value<String?> pricingJson = const Value.absent(),
                Value<String?> limitsJson = const Value.absent(),
                Value<String> diagnosticStatus = const Value.absent(),
                Value<DateTime?> verifiedAt = const Value.absent(),
                Value<String?> diagnosticError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProviderModelsCompanion(
                connectionId: connectionId,
                modelId: modelId,
                providerModelId: providerModelId,
                label: label,
                source: source,
                capabilitiesJson: capabilitiesJson,
                pricingJson: pricingJson,
                limitsJson: limitsJson,
                diagnosticStatus: diagnosticStatus,
                verifiedAt: verifiedAt,
                diagnosticError: diagnosticError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String connectionId,
                required String modelId,
                required String providerModelId,
                required String label,
                required String source,
                required String capabilitiesJson,
                Value<String?> pricingJson = const Value.absent(),
                Value<String?> limitsJson = const Value.absent(),
                Value<String> diagnosticStatus = const Value.absent(),
                Value<DateTime?> verifiedAt = const Value.absent(),
                Value<String?> diagnosticError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProviderModelsCompanion.insert(
                connectionId: connectionId,
                modelId: modelId,
                providerModelId: providerModelId,
                label: label,
                source: source,
                capabilitiesJson: capabilitiesJson,
                pricingJson: pricingJson,
                limitsJson: limitsJson,
                diagnosticStatus: diagnosticStatus,
                verifiedAt: verifiedAt,
                diagnosticError: diagnosticError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProviderModelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({connectionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (connectionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.connectionId,
                        referencedTable: $$ProviderModelsTableReferences
                            ._connectionIdTable(db),
                        referencedColumn: $$ProviderModelsTableReferences
                            ._connectionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ProviderModelsTableProcessedTableManager =
    ProcessedTableManager<
      _$TinestDatabase,
      $ProviderModelsTable,
      ProviderModel,
      $$ProviderModelsTableFilterComposer,
      $$ProviderModelsTableOrderingComposer,
      $$ProviderModelsTableAnnotationComposer,
      $$ProviderModelsTableCreateCompanionBuilder,
      $$ProviderModelsTableUpdateCompanionBuilder,
      (ProviderModel, $$ProviderModelsTableReferences),
      ProviderModel,
      PrefetchHooks Function({bool connectionId})
    >;

class $TinestDatabaseManager {
  final _$TinestDatabase _db;
  $TinestDatabaseManager(this._db);
  $$WorkspacesTableTableManager get workspaces =>
      $$WorkspacesTableTableManager(_db, _db.workspaces);
  $$WorktreesTableTableManager get worktrees =>
      $$WorktreesTableTableManager(_db, _db.worktrees);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$TurnsTableTableManager get turns =>
      $$TurnsTableTableManager(_db, _db.turns);
  $$AgentMailboxMessagesTableTableManager get agentMailboxMessages =>
      $$AgentMailboxMessagesTableTableManager(_db, _db.agentMailboxMessages);
  $$AttachmentsTableTableManager get attachments =>
      $$AttachmentsTableTableManager(_db, _db.attachments);
  $$TurnAttachmentsTableTableManager get turnAttachments =>
      $$TurnAttachmentsTableTableManager(_db, _db.turnAttachments);
  $$TimelineEventsTableTableManager get timelineEvents =>
      $$TimelineEventsTableTableManager(_db, _db.timelineEvents);
  $$ApprovalRequestsTableTableManager get approvalRequests =>
      $$ApprovalRequestsTableTableManager(_db, _db.approvalRequests);
  $$UserQuestionsTableTableManager get userQuestions =>
      $$UserQuestionsTableTableManager(_db, _db.userQuestions);
  $$ProviderStatesTableTableManager get providerStates =>
      $$ProviderStatesTableTableManager(_db, _db.providerStates);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$ProviderConnectionsTableTableManager get providerConnections =>
      $$ProviderConnectionsTableTableManager(_db, _db.providerConnections);
  $$ProviderModelsTableTableManager get providerModels =>
      $$ProviderModelsTableTableManager(_db, _db.providerModels);
}
