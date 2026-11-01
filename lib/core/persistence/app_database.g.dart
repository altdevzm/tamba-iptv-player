// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PlaylistsTableTable extends PlaylistsTable
    with TableInfo<$PlaylistsTableTable, PlaylistsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
      'url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _serverUrlMeta =
      const VerificationMeta('serverUrl');
  @override
  late final GeneratedColumn<String> serverUrl = GeneratedColumn<String>(
      'server_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _usernameMeta =
      const VerificationMeta('username');
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
      'username', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _macAddressMeta =
      const VerificationMeta('macAddress');
  @override
  late final GeneratedColumn<String> macAddress = GeneratedColumn<String>(
      'mac_address', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _userAgentMeta =
      const VerificationMeta('userAgent');
  @override
  late final GeneratedColumn<String> userAgent = GeneratedColumn<String>(
      'user_agent', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _autoRefreshMeta =
      const VerificationMeta('autoRefresh');
  @override
  late final GeneratedColumn<bool> autoRefresh = GeneratedColumn<bool>(
      'auto_refresh', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("auto_refresh" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _channelCountMeta =
      const VerificationMeta('channelCount');
  @override
  late final GeneratedColumn<int> channelCount = GeneratedColumn<int>(
      'channel_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _lastUpdatedMeta =
      const VerificationMeta('lastUpdated');
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
      'last_updated', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        type,
        url,
        filePath,
        serverUrl,
        username,
        macAddress,
        userAgent,
        autoRefresh,
        channelCount,
        position,
        createdAt,
        lastUpdated
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists_table';
  @override
  VerificationContext validateIntegrity(Insertable<PlaylistsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
          _urlMeta, url.isAcceptableOrUnknown(data['url']!, _urlMeta));
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    }
    if (data.containsKey('server_url')) {
      context.handle(_serverUrlMeta,
          serverUrl.isAcceptableOrUnknown(data['server_url']!, _serverUrlMeta));
    }
    if (data.containsKey('username')) {
      context.handle(_usernameMeta,
          username.isAcceptableOrUnknown(data['username']!, _usernameMeta));
    }
    if (data.containsKey('mac_address')) {
      context.handle(
          _macAddressMeta,
          macAddress.isAcceptableOrUnknown(
              data['mac_address']!, _macAddressMeta));
    }
    if (data.containsKey('user_agent')) {
      context.handle(_userAgentMeta,
          userAgent.isAcceptableOrUnknown(data['user_agent']!, _userAgentMeta));
    }
    if (data.containsKey('auto_refresh')) {
      context.handle(
          _autoRefreshMeta,
          autoRefresh.isAcceptableOrUnknown(
              data['auto_refresh']!, _autoRefreshMeta));
    }
    if (data.containsKey('channel_count')) {
      context.handle(
          _channelCountMeta,
          channelCount.isAcceptableOrUnknown(
              data['channel_count']!, _channelCountMeta));
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('last_updated')) {
      context.handle(
          _lastUpdatedMeta,
          lastUpdated.isAcceptableOrUnknown(
              data['last_updated']!, _lastUpdatedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaylistsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      url: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}url']),
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path']),
      serverUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_url']),
      username: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}username']),
      macAddress: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mac_address']),
      userAgent: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_agent']),
      autoRefresh: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}auto_refresh'])!,
      channelCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}channel_count'])!,
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      lastUpdated: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_updated']),
    );
  }

  @override
  $PlaylistsTableTable createAlias(String alias) {
    return $PlaylistsTableTable(attachedDatabase, alias);
  }
}

class PlaylistsTableData extends DataClass
    implements Insertable<PlaylistsTableData> {
  final String id;
  final String name;
  final String type;
  final String? url;
  final String? filePath;
  final String? serverUrl;
  final String? username;
  final String? macAddress;
  final String? userAgent;
  final bool autoRefresh;
  final int channelCount;
  final int position;
  final DateTime createdAt;
  final DateTime? lastUpdated;
  const PlaylistsTableData(
      {required this.id,
      required this.name,
      required this.type,
      this.url,
      this.filePath,
      this.serverUrl,
      this.username,
      this.macAddress,
      this.userAgent,
      required this.autoRefresh,
      required this.channelCount,
      required this.position,
      required this.createdAt,
      this.lastUpdated});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || url != null) {
      map['url'] = Variable<String>(url);
    }
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    if (!nullToAbsent || serverUrl != null) {
      map['server_url'] = Variable<String>(serverUrl);
    }
    if (!nullToAbsent || username != null) {
      map['username'] = Variable<String>(username);
    }
    if (!nullToAbsent || macAddress != null) {
      map['mac_address'] = Variable<String>(macAddress);
    }
    if (!nullToAbsent || userAgent != null) {
      map['user_agent'] = Variable<String>(userAgent);
    }
    map['auto_refresh'] = Variable<bool>(autoRefresh);
    map['channel_count'] = Variable<int>(channelCount);
    map['position'] = Variable<int>(position);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastUpdated != null) {
      map['last_updated'] = Variable<DateTime>(lastUpdated);
    }
    return map;
  }

  PlaylistsTableCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsTableCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      url: url == null && nullToAbsent ? const Value.absent() : Value(url),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      serverUrl: serverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(serverUrl),
      username: username == null && nullToAbsent
          ? const Value.absent()
          : Value(username),
      macAddress: macAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(macAddress),
      userAgent: userAgent == null && nullToAbsent
          ? const Value.absent()
          : Value(userAgent),
      autoRefresh: Value(autoRefresh),
      channelCount: Value(channelCount),
      position: Value(position),
      createdAt: Value(createdAt),
      lastUpdated: lastUpdated == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUpdated),
    );
  }

  factory PlaylistsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistsTableData(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      url: serializer.fromJson<String?>(json['url']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      serverUrl: serializer.fromJson<String?>(json['serverUrl']),
      username: serializer.fromJson<String?>(json['username']),
      macAddress: serializer.fromJson<String?>(json['macAddress']),
      userAgent: serializer.fromJson<String?>(json['userAgent']),
      autoRefresh: serializer.fromJson<bool>(json['autoRefresh']),
      channelCount: serializer.fromJson<int>(json['channelCount']),
      position: serializer.fromJson<int>(json['position']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastUpdated: serializer.fromJson<DateTime?>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'url': serializer.toJson<String?>(url),
      'filePath': serializer.toJson<String?>(filePath),
      'serverUrl': serializer.toJson<String?>(serverUrl),
      'username': serializer.toJson<String?>(username),
      'macAddress': serializer.toJson<String?>(macAddress),
      'userAgent': serializer.toJson<String?>(userAgent),
      'autoRefresh': serializer.toJson<bool>(autoRefresh),
      'channelCount': serializer.toJson<int>(channelCount),
      'position': serializer.toJson<int>(position),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastUpdated': serializer.toJson<DateTime?>(lastUpdated),
    };
  }

  PlaylistsTableData copyWith(
          {String? id,
          String? name,
          String? type,
          Value<String?> url = const Value.absent(),
          Value<String?> filePath = const Value.absent(),
          Value<String?> serverUrl = const Value.absent(),
          Value<String?> username = const Value.absent(),
          Value<String?> macAddress = const Value.absent(),
          Value<String?> userAgent = const Value.absent(),
          bool? autoRefresh,
          int? channelCount,
          int? position,
          DateTime? createdAt,
          Value<DateTime?> lastUpdated = const Value.absent()}) =>
      PlaylistsTableData(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        url: url.present ? url.value : this.url,
        filePath: filePath.present ? filePath.value : this.filePath,
        serverUrl: serverUrl.present ? serverUrl.value : this.serverUrl,
        username: username.present ? username.value : this.username,
        macAddress: macAddress.present ? macAddress.value : this.macAddress,
        userAgent: userAgent.present ? userAgent.value : this.userAgent,
        autoRefresh: autoRefresh ?? this.autoRefresh,
        channelCount: channelCount ?? this.channelCount,
        position: position ?? this.position,
        createdAt: createdAt ?? this.createdAt,
        lastUpdated: lastUpdated.present ? lastUpdated.value : this.lastUpdated,
      );
  PlaylistsTableData copyWithCompanion(PlaylistsTableCompanion data) {
    return PlaylistsTableData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      url: data.url.present ? data.url.value : this.url,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      serverUrl: data.serverUrl.present ? data.serverUrl.value : this.serverUrl,
      username: data.username.present ? data.username.value : this.username,
      macAddress:
          data.macAddress.present ? data.macAddress.value : this.macAddress,
      userAgent: data.userAgent.present ? data.userAgent.value : this.userAgent,
      autoRefresh:
          data.autoRefresh.present ? data.autoRefresh.value : this.autoRefresh,
      channelCount: data.channelCount.present
          ? data.channelCount.value
          : this.channelCount,
      position: data.position.present ? data.position.value : this.position,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastUpdated:
          data.lastUpdated.present ? data.lastUpdated.value : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsTableData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('url: $url, ')
          ..write('filePath: $filePath, ')
          ..write('serverUrl: $serverUrl, ')
          ..write('username: $username, ')
          ..write('macAddress: $macAddress, ')
          ..write('userAgent: $userAgent, ')
          ..write('autoRefresh: $autoRefresh, ')
          ..write('channelCount: $channelCount, ')
          ..write('position: $position, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      type,
      url,
      filePath,
      serverUrl,
      username,
      macAddress,
      userAgent,
      autoRefresh,
      channelCount,
      position,
      createdAt,
      lastUpdated);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistsTableData &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.url == this.url &&
          other.filePath == this.filePath &&
          other.serverUrl == this.serverUrl &&
          other.username == this.username &&
          other.macAddress == this.macAddress &&
          other.userAgent == this.userAgent &&
          other.autoRefresh == this.autoRefresh &&
          other.channelCount == this.channelCount &&
          other.position == this.position &&
          other.createdAt == this.createdAt &&
          other.lastUpdated == this.lastUpdated);
}

class PlaylistsTableCompanion extends UpdateCompanion<PlaylistsTableData> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String?> url;
  final Value<String?> filePath;
  final Value<String?> serverUrl;
  final Value<String?> username;
  final Value<String?> macAddress;
  final Value<String?> userAgent;
  final Value<bool> autoRefresh;
  final Value<int> channelCount;
  final Value<int> position;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastUpdated;
  final Value<int> rowid;
  const PlaylistsTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.url = const Value.absent(),
    this.filePath = const Value.absent(),
    this.serverUrl = const Value.absent(),
    this.username = const Value.absent(),
    this.macAddress = const Value.absent(),
    this.userAgent = const Value.absent(),
    this.autoRefresh = const Value.absent(),
    this.channelCount = const Value.absent(),
    this.position = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistsTableCompanion.insert({
    required String id,
    required String name,
    required String type,
    this.url = const Value.absent(),
    this.filePath = const Value.absent(),
    this.serverUrl = const Value.absent(),
    this.username = const Value.absent(),
    this.macAddress = const Value.absent(),
    this.userAgent = const Value.absent(),
    this.autoRefresh = const Value.absent(),
    this.channelCount = const Value.absent(),
    this.position = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        type = Value(type);
  static Insertable<PlaylistsTableData> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? url,
    Expression<String>? filePath,
    Expression<String>? serverUrl,
    Expression<String>? username,
    Expression<String>? macAddress,
    Expression<String>? userAgent,
    Expression<bool>? autoRefresh,
    Expression<int>? channelCount,
    Expression<int>? position,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastUpdated,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (url != null) 'url': url,
      if (filePath != null) 'file_path': filePath,
      if (serverUrl != null) 'server_url': serverUrl,
      if (username != null) 'username': username,
      if (macAddress != null) 'mac_address': macAddress,
      if (userAgent != null) 'user_agent': userAgent,
      if (autoRefresh != null) 'auto_refresh': autoRefresh,
      if (channelCount != null) 'channel_count': channelCount,
      if (position != null) 'position': position,
      if (createdAt != null) 'created_at': createdAt,
      if (lastUpdated != null) 'last_updated': lastUpdated,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? type,
      Value<String?>? url,
      Value<String?>? filePath,
      Value<String?>? serverUrl,
      Value<String?>? username,
      Value<String?>? macAddress,
      Value<String?>? userAgent,
      Value<bool>? autoRefresh,
      Value<int>? channelCount,
      Value<int>? position,
      Value<DateTime>? createdAt,
      Value<DateTime?>? lastUpdated,
      Value<int>? rowid}) {
    return PlaylistsTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      url: url ?? this.url,
      filePath: filePath ?? this.filePath,
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      macAddress: macAddress ?? this.macAddress,
      userAgent: userAgent ?? this.userAgent,
      autoRefresh: autoRefresh ?? this.autoRefresh,
      channelCount: channelCount ?? this.channelCount,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
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
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (serverUrl.present) {
      map['server_url'] = Variable<String>(serverUrl.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (macAddress.present) {
      map['mac_address'] = Variable<String>(macAddress.value);
    }
    if (userAgent.present) {
      map['user_agent'] = Variable<String>(userAgent.value);
    }
    if (autoRefresh.present) {
      map['auto_refresh'] = Variable<bool>(autoRefresh.value);
    }
    if (channelCount.present) {
      map['channel_count'] = Variable<int>(channelCount.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('url: $url, ')
          ..write('filePath: $filePath, ')
          ..write('serverUrl: $serverUrl, ')
          ..write('username: $username, ')
          ..write('macAddress: $macAddress, ')
          ..write('userAgent: $userAgent, ')
          ..write('autoRefresh: $autoRefresh, ')
          ..write('channelCount: $channelCount, ')
          ..write('position: $position, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTableTable extends CategoriesTable
    with TableInfo<$CategoriesTableTable, CategoriesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _playlistIdMeta =
      const VerificationMeta('playlistId');
  @override
  late final GeneratedColumn<String> playlistId = GeneratedColumn<String>(
      'playlist_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _providerIdMeta =
      const VerificationMeta('providerId');
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
      'provider_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
      'hidden', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("hidden" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _lockedMeta = const VerificationMeta('locked');
  @override
  late final GeneratedColumn<bool> locked = GeneratedColumn<bool>(
      'locked', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("locked" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [id, playlistId, name, type, providerId, hidden, locked];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<CategoriesTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
          _playlistIdMeta,
          playlistId.isAcceptableOrUnknown(
              data['playlist_id']!, _playlistIdMeta));
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
          _providerIdMeta,
          providerId.isAcceptableOrUnknown(
              data['provider_id']!, _providerIdMeta));
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('hidden')) {
      context.handle(_hiddenMeta,
          hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta));
    }
    if (data.containsKey('locked')) {
      context.handle(_lockedMeta,
          locked.isAcceptableOrUnknown(data['locked']!, _lockedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {playlistId, type, providerId},
      ];
  @override
  CategoriesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoriesTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      playlistId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}playlist_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      providerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}provider_id'])!,
      hidden: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}hidden'])!,
      locked: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}locked'])!,
    );
  }

  @override
  $CategoriesTableTable createAlias(String alias) {
    return $CategoriesTableTable(attachedDatabase, alias);
  }
}

class CategoriesTableData extends DataClass
    implements Insertable<CategoriesTableData> {
  final int id;
  final String playlistId;
  final String name;
  final String type;
  final String providerId;
  final bool hidden;
  final bool locked;
  const CategoriesTableData(
      {required this.id,
      required this.playlistId,
      required this.name,
      required this.type,
      required this.providerId,
      required this.hidden,
      required this.locked});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['playlist_id'] = Variable<String>(playlistId);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['provider_id'] = Variable<String>(providerId);
    map['hidden'] = Variable<bool>(hidden);
    map['locked'] = Variable<bool>(locked);
    return map;
  }

  CategoriesTableCompanion toCompanion(bool nullToAbsent) {
    return CategoriesTableCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      name: Value(name),
      type: Value(type),
      providerId: Value(providerId),
      hidden: Value(hidden),
      locked: Value(locked),
    );
  }

  factory CategoriesTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoriesTableData(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<String>(json['playlistId']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      providerId: serializer.fromJson<String>(json['providerId']),
      hidden: serializer.fromJson<bool>(json['hidden']),
      locked: serializer.fromJson<bool>(json['locked']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<String>(playlistId),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'providerId': serializer.toJson<String>(providerId),
      'hidden': serializer.toJson<bool>(hidden),
      'locked': serializer.toJson<bool>(locked),
    };
  }

  CategoriesTableData copyWith(
          {int? id,
          String? playlistId,
          String? name,
          String? type,
          String? providerId,
          bool? hidden,
          bool? locked}) =>
      CategoriesTableData(
        id: id ?? this.id,
        playlistId: playlistId ?? this.playlistId,
        name: name ?? this.name,
        type: type ?? this.type,
        providerId: providerId ?? this.providerId,
        hidden: hidden ?? this.hidden,
        locked: locked ?? this.locked,
      );
  CategoriesTableData copyWithCompanion(CategoriesTableCompanion data) {
    return CategoriesTableData(
      id: data.id.present ? data.id.value : this.id,
      playlistId:
          data.playlistId.present ? data.playlistId.value : this.playlistId,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      providerId:
          data.providerId.present ? data.providerId.value : this.providerId,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
      locked: data.locked.present ? data.locked.value : this.locked,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesTableData(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('providerId: $providerId, ')
          ..write('hidden: $hidden, ')
          ..write('locked: $locked')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, playlistId, name, type, providerId, hidden, locked);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoriesTableData &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.name == this.name &&
          other.type == this.type &&
          other.providerId == this.providerId &&
          other.hidden == this.hidden &&
          other.locked == this.locked);
}

class CategoriesTableCompanion extends UpdateCompanion<CategoriesTableData> {
  final Value<int> id;
  final Value<String> playlistId;
  final Value<String> name;
  final Value<String> type;
  final Value<String> providerId;
  final Value<bool> hidden;
  final Value<bool> locked;
  const CategoriesTableCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.providerId = const Value.absent(),
    this.hidden = const Value.absent(),
    this.locked = const Value.absent(),
  });
  CategoriesTableCompanion.insert({
    this.id = const Value.absent(),
    required String playlistId,
    required String name,
    required String type,
    required String providerId,
    this.hidden = const Value.absent(),
    this.locked = const Value.absent(),
  })  : playlistId = Value(playlistId),
        name = Value(name),
        type = Value(type),
        providerId = Value(providerId);
  static Insertable<CategoriesTableData> custom({
    Expression<int>? id,
    Expression<String>? playlistId,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? providerId,
    Expression<bool>? hidden,
    Expression<bool>? locked,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (providerId != null) 'provider_id': providerId,
      if (hidden != null) 'hidden': hidden,
      if (locked != null) 'locked': locked,
    });
  }

  CategoriesTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? playlistId,
      Value<String>? name,
      Value<String>? type,
      Value<String>? providerId,
      Value<bool>? hidden,
      Value<bool>? locked}) {
    return CategoriesTableCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      name: name ?? this.name,
      type: type ?? this.type,
      providerId: providerId ?? this.providerId,
      hidden: hidden ?? this.hidden,
      locked: locked ?? this.locked,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<String>(playlistId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (locked.present) {
      map['locked'] = Variable<bool>(locked.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesTableCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('providerId: $providerId, ')
          ..write('hidden: $hidden, ')
          ..write('locked: $locked')
          ..write(')'))
        .toString();
  }
}

class $ContentItemsTableTable extends ContentItemsTable
    with TableInfo<$ContentItemsTableTable, ContentItemsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentItemsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _playlistIdMeta =
      const VerificationMeta('playlistId');
  @override
  late final GeneratedColumn<String> playlistId = GeneratedColumn<String>(
      'playlist_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
      'category_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _providerIdMeta =
      const VerificationMeta('providerId');
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
      'provider_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _streamUrlMeta =
      const VerificationMeta('streamUrl');
  @override
  late final GeneratedColumn<String> streamUrl = GeneratedColumn<String>(
      'stream_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _containerExtensionMeta =
      const VerificationMeta('containerExtension');
  @override
  late final GeneratedColumn<String> containerExtension =
      GeneratedColumn<String>('container_extension', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _posterUrlMeta =
      const VerificationMeta('posterUrl');
  @override
  late final GeneratedColumn<String> posterUrl = GeneratedColumn<String>(
      'poster_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _backdropUrlMeta =
      const VerificationMeta('backdropUrl');
  @override
  late final GeneratedColumn<String> backdropUrl = GeneratedColumn<String>(
      'backdrop_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<double> rating = GeneratedColumn<double>(
      'rating', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _releaseYearMeta =
      const VerificationMeta('releaseYear');
  @override
  late final GeneratedColumn<int> releaseYear = GeneratedColumn<int>(
      'release_year', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _epgChannelIdMeta =
      const VerificationMeta('epgChannelId');
  @override
  late final GeneratedColumn<String> epgChannelId = GeneratedColumn<String>(
      'epg_channel_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _tvArchiveMeta =
      const VerificationMeta('tvArchive');
  @override
  late final GeneratedColumn<int> tvArchive = GeneratedColumn<int>(
      'tv_archive', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _tvArchiveDurationMeta =
      const VerificationMeta('tvArchiveDuration');
  @override
  late final GeneratedColumn<int> tvArchiveDuration = GeneratedColumn<int>(
      'tv_archive_duration', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _tmdbIdMeta = const VerificationMeta('tmdbId');
  @override
  late final GeneratedColumn<int> tmdbId = GeneratedColumn<int>(
      'tmdb_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _addedAtMeta =
      const VerificationMeta('addedAt');
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
      'added_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        playlistId,
        categoryId,
        title,
        type,
        providerId,
        streamUrl,
        containerExtension,
        posterUrl,
        backdropUrl,
        rating,
        releaseYear,
        epgChannelId,
        tvArchive,
        tvArchiveDuration,
        tmdbId,
        addedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_items_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<ContentItemsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
          _playlistIdMeta,
          playlistId.isAcceptableOrUnknown(
              data['playlist_id']!, _playlistIdMeta));
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
          _providerIdMeta,
          providerId.isAcceptableOrUnknown(
              data['provider_id']!, _providerIdMeta));
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('stream_url')) {
      context.handle(_streamUrlMeta,
          streamUrl.isAcceptableOrUnknown(data['stream_url']!, _streamUrlMeta));
    }
    if (data.containsKey('container_extension')) {
      context.handle(
          _containerExtensionMeta,
          containerExtension.isAcceptableOrUnknown(
              data['container_extension']!, _containerExtensionMeta));
    }
    if (data.containsKey('poster_url')) {
      context.handle(_posterUrlMeta,
          posterUrl.isAcceptableOrUnknown(data['poster_url']!, _posterUrlMeta));
    }
    if (data.containsKey('backdrop_url')) {
      context.handle(
          _backdropUrlMeta,
          backdropUrl.isAcceptableOrUnknown(
              data['backdrop_url']!, _backdropUrlMeta));
    }
    if (data.containsKey('rating')) {
      context.handle(_ratingMeta,
          rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta));
    }
    if (data.containsKey('release_year')) {
      context.handle(
          _releaseYearMeta,
          releaseYear.isAcceptableOrUnknown(
              data['release_year']!, _releaseYearMeta));
    }
    if (data.containsKey('epg_channel_id')) {
      context.handle(
          _epgChannelIdMeta,
          epgChannelId.isAcceptableOrUnknown(
              data['epg_channel_id']!, _epgChannelIdMeta));
    }
    if (data.containsKey('tv_archive')) {
      context.handle(_tvArchiveMeta,
          tvArchive.isAcceptableOrUnknown(data['tv_archive']!, _tvArchiveMeta));
    }
    if (data.containsKey('tv_archive_duration')) {
      context.handle(
          _tvArchiveDurationMeta,
          tvArchiveDuration.isAcceptableOrUnknown(
              data['tv_archive_duration']!, _tvArchiveDurationMeta));
    }
    if (data.containsKey('tmdb_id')) {
      context.handle(_tmdbIdMeta,
          tmdbId.isAcceptableOrUnknown(data['tmdb_id']!, _tmdbIdMeta));
    }
    if (data.containsKey('added_at')) {
      context.handle(_addedAtMeta,
          addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {playlistId, type, providerId},
      ];
  @override
  ContentItemsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentItemsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      playlistId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}playlist_id'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}category_id']),
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      providerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}provider_id'])!,
      streamUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}stream_url']),
      containerExtension: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}container_extension']),
      posterUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}poster_url']),
      backdropUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}backdrop_url']),
      rating: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}rating']),
      releaseYear: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}release_year']),
      epgChannelId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}epg_channel_id']),
      tvArchive: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tv_archive'])!,
      tvArchiveDuration: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}tv_archive_duration'])!,
      tmdbId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tmdb_id']),
      addedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}added_at']),
    );
  }

  @override
  $ContentItemsTableTable createAlias(String alias) {
    return $ContentItemsTableTable(attachedDatabase, alias);
  }
}

class ContentItemsTableData extends DataClass
    implements Insertable<ContentItemsTableData> {
  final int id;
  final String playlistId;
  final int? categoryId;
  final String title;
  final String type;
  final String providerId;
  final String? streamUrl;
  final String? containerExtension;
  final String? posterUrl;
  final String? backdropUrl;
  final double? rating;
  final int? releaseYear;
  final String? epgChannelId;
  final int tvArchive;
  final int tvArchiveDuration;
  final int? tmdbId;
  final DateTime? addedAt;
  const ContentItemsTableData(
      {required this.id,
      required this.playlistId,
      this.categoryId,
      required this.title,
      required this.type,
      required this.providerId,
      this.streamUrl,
      this.containerExtension,
      this.posterUrl,
      this.backdropUrl,
      this.rating,
      this.releaseYear,
      this.epgChannelId,
      required this.tvArchive,
      required this.tvArchiveDuration,
      this.tmdbId,
      this.addedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['playlist_id'] = Variable<String>(playlistId);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    map['title'] = Variable<String>(title);
    map['type'] = Variable<String>(type);
    map['provider_id'] = Variable<String>(providerId);
    if (!nullToAbsent || streamUrl != null) {
      map['stream_url'] = Variable<String>(streamUrl);
    }
    if (!nullToAbsent || containerExtension != null) {
      map['container_extension'] = Variable<String>(containerExtension);
    }
    if (!nullToAbsent || posterUrl != null) {
      map['poster_url'] = Variable<String>(posterUrl);
    }
    if (!nullToAbsent || backdropUrl != null) {
      map['backdrop_url'] = Variable<String>(backdropUrl);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<double>(rating);
    }
    if (!nullToAbsent || releaseYear != null) {
      map['release_year'] = Variable<int>(releaseYear);
    }
    if (!nullToAbsent || epgChannelId != null) {
      map['epg_channel_id'] = Variable<String>(epgChannelId);
    }
    map['tv_archive'] = Variable<int>(tvArchive);
    map['tv_archive_duration'] = Variable<int>(tvArchiveDuration);
    if (!nullToAbsent || tmdbId != null) {
      map['tmdb_id'] = Variable<int>(tmdbId);
    }
    if (!nullToAbsent || addedAt != null) {
      map['added_at'] = Variable<DateTime>(addedAt);
    }
    return map;
  }

  ContentItemsTableCompanion toCompanion(bool nullToAbsent) {
    return ContentItemsTableCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      title: Value(title),
      type: Value(type),
      providerId: Value(providerId),
      streamUrl: streamUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(streamUrl),
      containerExtension: containerExtension == null && nullToAbsent
          ? const Value.absent()
          : Value(containerExtension),
      posterUrl: posterUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(posterUrl),
      backdropUrl: backdropUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(backdropUrl),
      rating:
          rating == null && nullToAbsent ? const Value.absent() : Value(rating),
      releaseYear: releaseYear == null && nullToAbsent
          ? const Value.absent()
          : Value(releaseYear),
      epgChannelId: epgChannelId == null && nullToAbsent
          ? const Value.absent()
          : Value(epgChannelId),
      tvArchive: Value(tvArchive),
      tvArchiveDuration: Value(tvArchiveDuration),
      tmdbId:
          tmdbId == null && nullToAbsent ? const Value.absent() : Value(tmdbId),
      addedAt: addedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(addedAt),
    );
  }

  factory ContentItemsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentItemsTableData(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<String>(json['playlistId']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      title: serializer.fromJson<String>(json['title']),
      type: serializer.fromJson<String>(json['type']),
      providerId: serializer.fromJson<String>(json['providerId']),
      streamUrl: serializer.fromJson<String?>(json['streamUrl']),
      containerExtension:
          serializer.fromJson<String?>(json['containerExtension']),
      posterUrl: serializer.fromJson<String?>(json['posterUrl']),
      backdropUrl: serializer.fromJson<String?>(json['backdropUrl']),
      rating: serializer.fromJson<double?>(json['rating']),
      releaseYear: serializer.fromJson<int?>(json['releaseYear']),
      epgChannelId: serializer.fromJson<String?>(json['epgChannelId']),
      tvArchive: serializer.fromJson<int>(json['tvArchive']),
      tvArchiveDuration: serializer.fromJson<int>(json['tvArchiveDuration']),
      tmdbId: serializer.fromJson<int?>(json['tmdbId']),
      addedAt: serializer.fromJson<DateTime?>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<String>(playlistId),
      'categoryId': serializer.toJson<int?>(categoryId),
      'title': serializer.toJson<String>(title),
      'type': serializer.toJson<String>(type),
      'providerId': serializer.toJson<String>(providerId),
      'streamUrl': serializer.toJson<String?>(streamUrl),
      'containerExtension': serializer.toJson<String?>(containerExtension),
      'posterUrl': serializer.toJson<String?>(posterUrl),
      'backdropUrl': serializer.toJson<String?>(backdropUrl),
      'rating': serializer.toJson<double?>(rating),
      'releaseYear': serializer.toJson<int?>(releaseYear),
      'epgChannelId': serializer.toJson<String?>(epgChannelId),
      'tvArchive': serializer.toJson<int>(tvArchive),
      'tvArchiveDuration': serializer.toJson<int>(tvArchiveDuration),
      'tmdbId': serializer.toJson<int?>(tmdbId),
      'addedAt': serializer.toJson<DateTime?>(addedAt),
    };
  }

  ContentItemsTableData copyWith(
          {int? id,
          String? playlistId,
          Value<int?> categoryId = const Value.absent(),
          String? title,
          String? type,
          String? providerId,
          Value<String?> streamUrl = const Value.absent(),
          Value<String?> containerExtension = const Value.absent(),
          Value<String?> posterUrl = const Value.absent(),
          Value<String?> backdropUrl = const Value.absent(),
          Value<double?> rating = const Value.absent(),
          Value<int?> releaseYear = const Value.absent(),
          Value<String?> epgChannelId = const Value.absent(),
          int? tvArchive,
          int? tvArchiveDuration,
          Value<int?> tmdbId = const Value.absent(),
          Value<DateTime?> addedAt = const Value.absent()}) =>
      ContentItemsTableData(
        id: id ?? this.id,
        playlistId: playlistId ?? this.playlistId,
        categoryId: categoryId.present ? categoryId.value : this.categoryId,
        title: title ?? this.title,
        type: type ?? this.type,
        providerId: providerId ?? this.providerId,
        streamUrl: streamUrl.present ? streamUrl.value : this.streamUrl,
        containerExtension: containerExtension.present
            ? containerExtension.value
            : this.containerExtension,
        posterUrl: posterUrl.present ? posterUrl.value : this.posterUrl,
        backdropUrl: backdropUrl.present ? backdropUrl.value : this.backdropUrl,
        rating: rating.present ? rating.value : this.rating,
        releaseYear: releaseYear.present ? releaseYear.value : this.releaseYear,
        epgChannelId:
            epgChannelId.present ? epgChannelId.value : this.epgChannelId,
        tvArchive: tvArchive ?? this.tvArchive,
        tvArchiveDuration: tvArchiveDuration ?? this.tvArchiveDuration,
        tmdbId: tmdbId.present ? tmdbId.value : this.tmdbId,
        addedAt: addedAt.present ? addedAt.value : this.addedAt,
      );
  ContentItemsTableData copyWithCompanion(ContentItemsTableCompanion data) {
    return ContentItemsTableData(
      id: data.id.present ? data.id.value : this.id,
      playlistId:
          data.playlistId.present ? data.playlistId.value : this.playlistId,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      title: data.title.present ? data.title.value : this.title,
      type: data.type.present ? data.type.value : this.type,
      providerId:
          data.providerId.present ? data.providerId.value : this.providerId,
      streamUrl: data.streamUrl.present ? data.streamUrl.value : this.streamUrl,
      containerExtension: data.containerExtension.present
          ? data.containerExtension.value
          : this.containerExtension,
      posterUrl: data.posterUrl.present ? data.posterUrl.value : this.posterUrl,
      backdropUrl:
          data.backdropUrl.present ? data.backdropUrl.value : this.backdropUrl,
      rating: data.rating.present ? data.rating.value : this.rating,
      releaseYear:
          data.releaseYear.present ? data.releaseYear.value : this.releaseYear,
      epgChannelId: data.epgChannelId.present
          ? data.epgChannelId.value
          : this.epgChannelId,
      tvArchive: data.tvArchive.present ? data.tvArchive.value : this.tvArchive,
      tvArchiveDuration: data.tvArchiveDuration.present
          ? data.tvArchiveDuration.value
          : this.tvArchiveDuration,
      tmdbId: data.tmdbId.present ? data.tmdbId.value : this.tmdbId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentItemsTableData(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('categoryId: $categoryId, ')
          ..write('title: $title, ')
          ..write('type: $type, ')
          ..write('providerId: $providerId, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('containerExtension: $containerExtension, ')
          ..write('posterUrl: $posterUrl, ')
          ..write('backdropUrl: $backdropUrl, ')
          ..write('rating: $rating, ')
          ..write('releaseYear: $releaseYear, ')
          ..write('epgChannelId: $epgChannelId, ')
          ..write('tvArchive: $tvArchive, ')
          ..write('tvArchiveDuration: $tvArchiveDuration, ')
          ..write('tmdbId: $tmdbId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      playlistId,
      categoryId,
      title,
      type,
      providerId,
      streamUrl,
      containerExtension,
      posterUrl,
      backdropUrl,
      rating,
      releaseYear,
      epgChannelId,
      tvArchive,
      tvArchiveDuration,
      tmdbId,
      addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentItemsTableData &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.categoryId == this.categoryId &&
          other.title == this.title &&
          other.type == this.type &&
          other.providerId == this.providerId &&
          other.streamUrl == this.streamUrl &&
          other.containerExtension == this.containerExtension &&
          other.posterUrl == this.posterUrl &&
          other.backdropUrl == this.backdropUrl &&
          other.rating == this.rating &&
          other.releaseYear == this.releaseYear &&
          other.epgChannelId == this.epgChannelId &&
          other.tvArchive == this.tvArchive &&
          other.tvArchiveDuration == this.tvArchiveDuration &&
          other.tmdbId == this.tmdbId &&
          other.addedAt == this.addedAt);
}

class ContentItemsTableCompanion
    extends UpdateCompanion<ContentItemsTableData> {
  final Value<int> id;
  final Value<String> playlistId;
  final Value<int?> categoryId;
  final Value<String> title;
  final Value<String> type;
  final Value<String> providerId;
  final Value<String?> streamUrl;
  final Value<String?> containerExtension;
  final Value<String?> posterUrl;
  final Value<String?> backdropUrl;
  final Value<double?> rating;
  final Value<int?> releaseYear;
  final Value<String?> epgChannelId;
  final Value<int> tvArchive;
  final Value<int> tvArchiveDuration;
  final Value<int?> tmdbId;
  final Value<DateTime?> addedAt;
  const ContentItemsTableCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.title = const Value.absent(),
    this.type = const Value.absent(),
    this.providerId = const Value.absent(),
    this.streamUrl = const Value.absent(),
    this.containerExtension = const Value.absent(),
    this.posterUrl = const Value.absent(),
    this.backdropUrl = const Value.absent(),
    this.rating = const Value.absent(),
    this.releaseYear = const Value.absent(),
    this.epgChannelId = const Value.absent(),
    this.tvArchive = const Value.absent(),
    this.tvArchiveDuration = const Value.absent(),
    this.tmdbId = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  ContentItemsTableCompanion.insert({
    this.id = const Value.absent(),
    required String playlistId,
    this.categoryId = const Value.absent(),
    required String title,
    required String type,
    required String providerId,
    this.streamUrl = const Value.absent(),
    this.containerExtension = const Value.absent(),
    this.posterUrl = const Value.absent(),
    this.backdropUrl = const Value.absent(),
    this.rating = const Value.absent(),
    this.releaseYear = const Value.absent(),
    this.epgChannelId = const Value.absent(),
    this.tvArchive = const Value.absent(),
    this.tvArchiveDuration = const Value.absent(),
    this.tmdbId = const Value.absent(),
    this.addedAt = const Value.absent(),
  })  : playlistId = Value(playlistId),
        title = Value(title),
        type = Value(type),
        providerId = Value(providerId);
  static Insertable<ContentItemsTableData> custom({
    Expression<int>? id,
    Expression<String>? playlistId,
    Expression<int>? categoryId,
    Expression<String>? title,
    Expression<String>? type,
    Expression<String>? providerId,
    Expression<String>? streamUrl,
    Expression<String>? containerExtension,
    Expression<String>? posterUrl,
    Expression<String>? backdropUrl,
    Expression<double>? rating,
    Expression<int>? releaseYear,
    Expression<String>? epgChannelId,
    Expression<int>? tvArchive,
    Expression<int>? tvArchiveDuration,
    Expression<int>? tmdbId,
    Expression<DateTime>? addedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (categoryId != null) 'category_id': categoryId,
      if (title != null) 'title': title,
      if (type != null) 'type': type,
      if (providerId != null) 'provider_id': providerId,
      if (streamUrl != null) 'stream_url': streamUrl,
      if (containerExtension != null) 'container_extension': containerExtension,
      if (posterUrl != null) 'poster_url': posterUrl,
      if (backdropUrl != null) 'backdrop_url': backdropUrl,
      if (rating != null) 'rating': rating,
      if (releaseYear != null) 'release_year': releaseYear,
      if (epgChannelId != null) 'epg_channel_id': epgChannelId,
      if (tvArchive != null) 'tv_archive': tvArchive,
      if (tvArchiveDuration != null) 'tv_archive_duration': tvArchiveDuration,
      if (tmdbId != null) 'tmdb_id': tmdbId,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  ContentItemsTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? playlistId,
      Value<int?>? categoryId,
      Value<String>? title,
      Value<String>? type,
      Value<String>? providerId,
      Value<String?>? streamUrl,
      Value<String?>? containerExtension,
      Value<String?>? posterUrl,
      Value<String?>? backdropUrl,
      Value<double?>? rating,
      Value<int?>? releaseYear,
      Value<String?>? epgChannelId,
      Value<int>? tvArchive,
      Value<int>? tvArchiveDuration,
      Value<int?>? tmdbId,
      Value<DateTime?>? addedAt}) {
    return ContentItemsTableCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      type: type ?? this.type,
      providerId: providerId ?? this.providerId,
      streamUrl: streamUrl ?? this.streamUrl,
      containerExtension: containerExtension ?? this.containerExtension,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      rating: rating ?? this.rating,
      releaseYear: releaseYear ?? this.releaseYear,
      epgChannelId: epgChannelId ?? this.epgChannelId,
      tvArchive: tvArchive ?? this.tvArchive,
      tvArchiveDuration: tvArchiveDuration ?? this.tvArchiveDuration,
      tmdbId: tmdbId ?? this.tmdbId,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<String>(playlistId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (streamUrl.present) {
      map['stream_url'] = Variable<String>(streamUrl.value);
    }
    if (containerExtension.present) {
      map['container_extension'] = Variable<String>(containerExtension.value);
    }
    if (posterUrl.present) {
      map['poster_url'] = Variable<String>(posterUrl.value);
    }
    if (backdropUrl.present) {
      map['backdrop_url'] = Variable<String>(backdropUrl.value);
    }
    if (rating.present) {
      map['rating'] = Variable<double>(rating.value);
    }
    if (releaseYear.present) {
      map['release_year'] = Variable<int>(releaseYear.value);
    }
    if (epgChannelId.present) {
      map['epg_channel_id'] = Variable<String>(epgChannelId.value);
    }
    if (tvArchive.present) {
      map['tv_archive'] = Variable<int>(tvArchive.value);
    }
    if (tvArchiveDuration.present) {
      map['tv_archive_duration'] = Variable<int>(tvArchiveDuration.value);
    }
    if (tmdbId.present) {
      map['tmdb_id'] = Variable<int>(tmdbId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentItemsTableCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('categoryId: $categoryId, ')
          ..write('title: $title, ')
          ..write('type: $type, ')
          ..write('providerId: $providerId, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('containerExtension: $containerExtension, ')
          ..write('posterUrl: $posterUrl, ')
          ..write('backdropUrl: $backdropUrl, ')
          ..write('rating: $rating, ')
          ..write('releaseYear: $releaseYear, ')
          ..write('epgChannelId: $epgChannelId, ')
          ..write('tvArchive: $tvArchive, ')
          ..write('tvArchiveDuration: $tvArchiveDuration, ')
          ..write('tmdbId: $tmdbId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class $FavoritesTableTable extends FavoritesTable
    with TableInfo<$FavoritesTableTable, FavoritesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoritesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _playlistIdMeta =
      const VerificationMeta('playlistId');
  @override
  late final GeneratedColumn<String> playlistId = GeneratedColumn<String>(
      'playlist_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentIdMeta =
      const VerificationMeta('contentId');
  @override
  late final GeneratedColumn<int> contentId = GeneratedColumn<int>(
      'content_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _providerIdMeta =
      const VerificationMeta('providerId');
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
      'provider_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _posterUrlMeta =
      const VerificationMeta('posterUrl');
  @override
  late final GeneratedColumn<String> posterUrl = GeneratedColumn<String>(
      'poster_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _backdropUrlMeta =
      const VerificationMeta('backdropUrl');
  @override
  late final GeneratedColumn<String> backdropUrl = GeneratedColumn<String>(
      'backdrop_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _addedAtMeta =
      const VerificationMeta('addedAt');
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
      'added_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        playlistId,
        contentId,
        providerId,
        type,
        title,
        posterUrl,
        backdropUrl,
        position,
        addedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorites_table';
  @override
  VerificationContext validateIntegrity(Insertable<FavoritesTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
          _playlistIdMeta,
          playlistId.isAcceptableOrUnknown(
              data['playlist_id']!, _playlistIdMeta));
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('content_id')) {
      context.handle(_contentIdMeta,
          contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta));
    }
    if (data.containsKey('provider_id')) {
      context.handle(
          _providerIdMeta,
          providerId.isAcceptableOrUnknown(
              data['provider_id']!, _providerIdMeta));
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('poster_url')) {
      context.handle(_posterUrlMeta,
          posterUrl.isAcceptableOrUnknown(data['poster_url']!, _posterUrlMeta));
    }
    if (data.containsKey('backdrop_url')) {
      context.handle(
          _backdropUrlMeta,
          backdropUrl.isAcceptableOrUnknown(
              data['backdrop_url']!, _backdropUrlMeta));
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    }
    if (data.containsKey('added_at')) {
      context.handle(_addedAtMeta,
          addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {playlistId, type, providerId},
      ];
  @override
  FavoritesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoritesTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      playlistId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}playlist_id'])!,
      contentId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}content_id']),
      providerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}provider_id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      posterUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}poster_url']),
      backdropUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}backdrop_url']),
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      addedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}added_at'])!,
    );
  }

  @override
  $FavoritesTableTable createAlias(String alias) {
    return $FavoritesTableTable(attachedDatabase, alias);
  }
}

class FavoritesTableData extends DataClass
    implements Insertable<FavoritesTableData> {
  final int id;
  final String playlistId;
  final int? contentId;
  final String providerId;
  final String type;
  final String title;
  final String? posterUrl;
  final String? backdropUrl;
  final int position;
  final DateTime addedAt;
  const FavoritesTableData(
      {required this.id,
      required this.playlistId,
      this.contentId,
      required this.providerId,
      required this.type,
      required this.title,
      this.posterUrl,
      this.backdropUrl,
      required this.position,
      required this.addedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['playlist_id'] = Variable<String>(playlistId);
    if (!nullToAbsent || contentId != null) {
      map['content_id'] = Variable<int>(contentId);
    }
    map['provider_id'] = Variable<String>(providerId);
    map['type'] = Variable<String>(type);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || posterUrl != null) {
      map['poster_url'] = Variable<String>(posterUrl);
    }
    if (!nullToAbsent || backdropUrl != null) {
      map['backdrop_url'] = Variable<String>(backdropUrl);
    }
    map['position'] = Variable<int>(position);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  FavoritesTableCompanion toCompanion(bool nullToAbsent) {
    return FavoritesTableCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      contentId: contentId == null && nullToAbsent
          ? const Value.absent()
          : Value(contentId),
      providerId: Value(providerId),
      type: Value(type),
      title: Value(title),
      posterUrl: posterUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(posterUrl),
      backdropUrl: backdropUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(backdropUrl),
      position: Value(position),
      addedAt: Value(addedAt),
    );
  }

  factory FavoritesTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoritesTableData(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<String>(json['playlistId']),
      contentId: serializer.fromJson<int?>(json['contentId']),
      providerId: serializer.fromJson<String>(json['providerId']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String>(json['title']),
      posterUrl: serializer.fromJson<String?>(json['posterUrl']),
      backdropUrl: serializer.fromJson<String?>(json['backdropUrl']),
      position: serializer.fromJson<int>(json['position']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<String>(playlistId),
      'contentId': serializer.toJson<int?>(contentId),
      'providerId': serializer.toJson<String>(providerId),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String>(title),
      'posterUrl': serializer.toJson<String?>(posterUrl),
      'backdropUrl': serializer.toJson<String?>(backdropUrl),
      'position': serializer.toJson<int>(position),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  FavoritesTableData copyWith(
          {int? id,
          String? playlistId,
          Value<int?> contentId = const Value.absent(),
          String? providerId,
          String? type,
          String? title,
          Value<String?> posterUrl = const Value.absent(),
          Value<String?> backdropUrl = const Value.absent(),
          int? position,
          DateTime? addedAt}) =>
      FavoritesTableData(
        id: id ?? this.id,
        playlistId: playlistId ?? this.playlistId,
        contentId: contentId.present ? contentId.value : this.contentId,
        providerId: providerId ?? this.providerId,
        type: type ?? this.type,
        title: title ?? this.title,
        posterUrl: posterUrl.present ? posterUrl.value : this.posterUrl,
        backdropUrl: backdropUrl.present ? backdropUrl.value : this.backdropUrl,
        position: position ?? this.position,
        addedAt: addedAt ?? this.addedAt,
      );
  FavoritesTableData copyWithCompanion(FavoritesTableCompanion data) {
    return FavoritesTableData(
      id: data.id.present ? data.id.value : this.id,
      playlistId:
          data.playlistId.present ? data.playlistId.value : this.playlistId,
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      providerId:
          data.providerId.present ? data.providerId.value : this.providerId,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      posterUrl: data.posterUrl.present ? data.posterUrl.value : this.posterUrl,
      backdropUrl:
          data.backdropUrl.present ? data.backdropUrl.value : this.backdropUrl,
      position: data.position.present ? data.position.value : this.position,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoritesTableData(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('contentId: $contentId, ')
          ..write('providerId: $providerId, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('posterUrl: $posterUrl, ')
          ..write('backdropUrl: $backdropUrl, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, playlistId, contentId, providerId, type,
      title, posterUrl, backdropUrl, position, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoritesTableData &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.contentId == this.contentId &&
          other.providerId == this.providerId &&
          other.type == this.type &&
          other.title == this.title &&
          other.posterUrl == this.posterUrl &&
          other.backdropUrl == this.backdropUrl &&
          other.position == this.position &&
          other.addedAt == this.addedAt);
}

class FavoritesTableCompanion extends UpdateCompanion<FavoritesTableData> {
  final Value<int> id;
  final Value<String> playlistId;
  final Value<int?> contentId;
  final Value<String> providerId;
  final Value<String> type;
  final Value<String> title;
  final Value<String?> posterUrl;
  final Value<String?> backdropUrl;
  final Value<int> position;
  final Value<DateTime> addedAt;
  const FavoritesTableCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.contentId = const Value.absent(),
    this.providerId = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.posterUrl = const Value.absent(),
    this.backdropUrl = const Value.absent(),
    this.position = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  FavoritesTableCompanion.insert({
    this.id = const Value.absent(),
    required String playlistId,
    this.contentId = const Value.absent(),
    required String providerId,
    required String type,
    required String title,
    this.posterUrl = const Value.absent(),
    this.backdropUrl = const Value.absent(),
    this.position = const Value.absent(),
    this.addedAt = const Value.absent(),
  })  : playlistId = Value(playlistId),
        providerId = Value(providerId),
        type = Value(type),
        title = Value(title);
  static Insertable<FavoritesTableData> custom({
    Expression<int>? id,
    Expression<String>? playlistId,
    Expression<int>? contentId,
    Expression<String>? providerId,
    Expression<String>? type,
    Expression<String>? title,
    Expression<String>? posterUrl,
    Expression<String>? backdropUrl,
    Expression<int>? position,
    Expression<DateTime>? addedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (contentId != null) 'content_id': contentId,
      if (providerId != null) 'provider_id': providerId,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (posterUrl != null) 'poster_url': posterUrl,
      if (backdropUrl != null) 'backdrop_url': backdropUrl,
      if (position != null) 'position': position,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  FavoritesTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? playlistId,
      Value<int?>? contentId,
      Value<String>? providerId,
      Value<String>? type,
      Value<String>? title,
      Value<String?>? posterUrl,
      Value<String?>? backdropUrl,
      Value<int>? position,
      Value<DateTime>? addedAt}) {
    return FavoritesTableCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      contentId: contentId ?? this.contentId,
      providerId: providerId ?? this.providerId,
      type: type ?? this.type,
      title: title ?? this.title,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      position: position ?? this.position,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<String>(playlistId.value);
    }
    if (contentId.present) {
      map['content_id'] = Variable<int>(contentId.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (posterUrl.present) {
      map['poster_url'] = Variable<String>(posterUrl.value);
    }
    if (backdropUrl.present) {
      map['backdrop_url'] = Variable<String>(backdropUrl.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoritesTableCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('contentId: $contentId, ')
          ..write('providerId: $providerId, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('posterUrl: $posterUrl, ')
          ..write('backdropUrl: $backdropUrl, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class $RecentlyViewedTableTable extends RecentlyViewedTable
    with TableInfo<$RecentlyViewedTableTable, RecentlyViewedTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecentlyViewedTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _playlistIdMeta =
      const VerificationMeta('playlistId');
  @override
  late final GeneratedColumn<String> playlistId = GeneratedColumn<String>(
      'playlist_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentIdMeta =
      const VerificationMeta('contentId');
  @override
  late final GeneratedColumn<int> contentId = GeneratedColumn<int>(
      'content_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _viewedAtMeta =
      const VerificationMeta('viewedAt');
  @override
  late final GeneratedColumn<DateTime> viewedAt = GeneratedColumn<DateTime>(
      'viewed_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, playlistId, contentId, viewedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recently_viewed_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<RecentlyViewedTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
          _playlistIdMeta,
          playlistId.isAcceptableOrUnknown(
              data['playlist_id']!, _playlistIdMeta));
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('content_id')) {
      context.handle(_contentIdMeta,
          contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta));
    } else if (isInserting) {
      context.missing(_contentIdMeta);
    }
    if (data.containsKey('viewed_at')) {
      context.handle(_viewedAtMeta,
          viewedAt.isAcceptableOrUnknown(data['viewed_at']!, _viewedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {playlistId, contentId},
      ];
  @override
  RecentlyViewedTableData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecentlyViewedTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      playlistId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}playlist_id'])!,
      contentId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}content_id'])!,
      viewedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}viewed_at'])!,
    );
  }

  @override
  $RecentlyViewedTableTable createAlias(String alias) {
    return $RecentlyViewedTableTable(attachedDatabase, alias);
  }
}

class RecentlyViewedTableData extends DataClass
    implements Insertable<RecentlyViewedTableData> {
  final int id;
  final String playlistId;
  final int contentId;
  final DateTime viewedAt;
  const RecentlyViewedTableData(
      {required this.id,
      required this.playlistId,
      required this.contentId,
      required this.viewedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['playlist_id'] = Variable<String>(playlistId);
    map['content_id'] = Variable<int>(contentId);
    map['viewed_at'] = Variable<DateTime>(viewedAt);
    return map;
  }

  RecentlyViewedTableCompanion toCompanion(bool nullToAbsent) {
    return RecentlyViewedTableCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      contentId: Value(contentId),
      viewedAt: Value(viewedAt),
    );
  }

  factory RecentlyViewedTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecentlyViewedTableData(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<String>(json['playlistId']),
      contentId: serializer.fromJson<int>(json['contentId']),
      viewedAt: serializer.fromJson<DateTime>(json['viewedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<String>(playlistId),
      'contentId': serializer.toJson<int>(contentId),
      'viewedAt': serializer.toJson<DateTime>(viewedAt),
    };
  }

  RecentlyViewedTableData copyWith(
          {int? id, String? playlistId, int? contentId, DateTime? viewedAt}) =>
      RecentlyViewedTableData(
        id: id ?? this.id,
        playlistId: playlistId ?? this.playlistId,
        contentId: contentId ?? this.contentId,
        viewedAt: viewedAt ?? this.viewedAt,
      );
  RecentlyViewedTableData copyWithCompanion(RecentlyViewedTableCompanion data) {
    return RecentlyViewedTableData(
      id: data.id.present ? data.id.value : this.id,
      playlistId:
          data.playlistId.present ? data.playlistId.value : this.playlistId,
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      viewedAt: data.viewedAt.present ? data.viewedAt.value : this.viewedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecentlyViewedTableData(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('contentId: $contentId, ')
          ..write('viewedAt: $viewedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, playlistId, contentId, viewedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecentlyViewedTableData &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.contentId == this.contentId &&
          other.viewedAt == this.viewedAt);
}

class RecentlyViewedTableCompanion
    extends UpdateCompanion<RecentlyViewedTableData> {
  final Value<int> id;
  final Value<String> playlistId;
  final Value<int> contentId;
  final Value<DateTime> viewedAt;
  const RecentlyViewedTableCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.contentId = const Value.absent(),
    this.viewedAt = const Value.absent(),
  });
  RecentlyViewedTableCompanion.insert({
    this.id = const Value.absent(),
    required String playlistId,
    required int contentId,
    this.viewedAt = const Value.absent(),
  })  : playlistId = Value(playlistId),
        contentId = Value(contentId);
  static Insertable<RecentlyViewedTableData> custom({
    Expression<int>? id,
    Expression<String>? playlistId,
    Expression<int>? contentId,
    Expression<DateTime>? viewedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (contentId != null) 'content_id': contentId,
      if (viewedAt != null) 'viewed_at': viewedAt,
    });
  }

  RecentlyViewedTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? playlistId,
      Value<int>? contentId,
      Value<DateTime>? viewedAt}) {
    return RecentlyViewedTableCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      contentId: contentId ?? this.contentId,
      viewedAt: viewedAt ?? this.viewedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<String>(playlistId.value);
    }
    if (contentId.present) {
      map['content_id'] = Variable<int>(contentId.value);
    }
    if (viewedAt.present) {
      map['viewed_at'] = Variable<DateTime>(viewedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecentlyViewedTableCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('contentId: $contentId, ')
          ..write('viewedAt: $viewedAt')
          ..write(')'))
        .toString();
  }
}

class $PlaybackPositionsTableTable extends PlaybackPositionsTable
    with TableInfo<$PlaybackPositionsTableTable, PlaybackPositionsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackPositionsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _playlistIdMeta =
      const VerificationMeta('playlistId');
  @override
  late final GeneratedColumn<String> playlistId = GeneratedColumn<String>(
      'playlist_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentProviderIdMeta =
      const VerificationMeta('contentProviderId');
  @override
  late final GeneratedColumn<String> contentProviderId =
      GeneratedColumn<String>('content_provider_id', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentTypeMeta =
      const VerificationMeta('contentType');
  @override
  late final GeneratedColumn<String> contentType = GeneratedColumn<String>(
      'content_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _seriesProviderIdMeta =
      const VerificationMeta('seriesProviderId');
  @override
  late final GeneratedColumn<String> seriesProviderId = GeneratedColumn<String>(
      'series_provider_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _seasonNumberMeta =
      const VerificationMeta('seasonNumber');
  @override
  late final GeneratedColumn<int> seasonNumber = GeneratedColumn<int>(
      'season_number', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _episodeNumberMeta =
      const VerificationMeta('episodeNumber');
  @override
  late final GeneratedColumn<int> episodeNumber = GeneratedColumn<int>(
      'episode_number', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _positionSecondsMeta =
      const VerificationMeta('positionSeconds');
  @override
  late final GeneratedColumn<int> positionSeconds = GeneratedColumn<int>(
      'position_seconds', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _durationSecondsMeta =
      const VerificationMeta('durationSeconds');
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
      'duration_seconds', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        playlistId,
        contentProviderId,
        contentType,
        seriesProviderId,
        seasonNumber,
        episodeNumber,
        positionSeconds,
        durationSeconds,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_positions_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<PlaybackPositionsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
          _playlistIdMeta,
          playlistId.isAcceptableOrUnknown(
              data['playlist_id']!, _playlistIdMeta));
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('content_provider_id')) {
      context.handle(
          _contentProviderIdMeta,
          contentProviderId.isAcceptableOrUnknown(
              data['content_provider_id']!, _contentProviderIdMeta));
    } else if (isInserting) {
      context.missing(_contentProviderIdMeta);
    }
    if (data.containsKey('content_type')) {
      context.handle(
          _contentTypeMeta,
          contentType.isAcceptableOrUnknown(
              data['content_type']!, _contentTypeMeta));
    } else if (isInserting) {
      context.missing(_contentTypeMeta);
    }
    if (data.containsKey('series_provider_id')) {
      context.handle(
          _seriesProviderIdMeta,
          seriesProviderId.isAcceptableOrUnknown(
              data['series_provider_id']!, _seriesProviderIdMeta));
    }
    if (data.containsKey('season_number')) {
      context.handle(
          _seasonNumberMeta,
          seasonNumber.isAcceptableOrUnknown(
              data['season_number']!, _seasonNumberMeta));
    }
    if (data.containsKey('episode_number')) {
      context.handle(
          _episodeNumberMeta,
          episodeNumber.isAcceptableOrUnknown(
              data['episode_number']!, _episodeNumberMeta));
    }
    if (data.containsKey('position_seconds')) {
      context.handle(
          _positionSecondsMeta,
          positionSeconds.isAcceptableOrUnknown(
              data['position_seconds']!, _positionSecondsMeta));
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
          _durationSecondsMeta,
          durationSeconds.isAcceptableOrUnknown(
              data['duration_seconds']!, _durationSecondsMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {playlistId, contentType, contentProviderId},
      ];
  @override
  PlaybackPositionsTableData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackPositionsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      playlistId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}playlist_id'])!,
      contentProviderId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}content_provider_id'])!,
      contentType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content_type'])!,
      seriesProviderId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}series_provider_id']),
      seasonNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}season_number']),
      episodeNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}episode_number']),
      positionSeconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position_seconds'])!,
      durationSeconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_seconds']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $PlaybackPositionsTableTable createAlias(String alias) {
    return $PlaybackPositionsTableTable(attachedDatabase, alias);
  }
}

class PlaybackPositionsTableData extends DataClass
    implements Insertable<PlaybackPositionsTableData> {
  final int id;
  final String playlistId;
  final String contentProviderId;
  final String contentType;
  final String? seriesProviderId;
  final int? seasonNumber;
  final int? episodeNumber;
  final int positionSeconds;
  final int? durationSeconds;
  final DateTime updatedAt;
  const PlaybackPositionsTableData(
      {required this.id,
      required this.playlistId,
      required this.contentProviderId,
      required this.contentType,
      this.seriesProviderId,
      this.seasonNumber,
      this.episodeNumber,
      required this.positionSeconds,
      this.durationSeconds,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['playlist_id'] = Variable<String>(playlistId);
    map['content_provider_id'] = Variable<String>(contentProviderId);
    map['content_type'] = Variable<String>(contentType);
    if (!nullToAbsent || seriesProviderId != null) {
      map['series_provider_id'] = Variable<String>(seriesProviderId);
    }
    if (!nullToAbsent || seasonNumber != null) {
      map['season_number'] = Variable<int>(seasonNumber);
    }
    if (!nullToAbsent || episodeNumber != null) {
      map['episode_number'] = Variable<int>(episodeNumber);
    }
    map['position_seconds'] = Variable<int>(positionSeconds);
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<int>(durationSeconds);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PlaybackPositionsTableCompanion toCompanion(bool nullToAbsent) {
    return PlaybackPositionsTableCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      contentProviderId: Value(contentProviderId),
      contentType: Value(contentType),
      seriesProviderId: seriesProviderId == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesProviderId),
      seasonNumber: seasonNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(seasonNumber),
      episodeNumber: episodeNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeNumber),
      positionSeconds: Value(positionSeconds),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlaybackPositionsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackPositionsTableData(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<String>(json['playlistId']),
      contentProviderId: serializer.fromJson<String>(json['contentProviderId']),
      contentType: serializer.fromJson<String>(json['contentType']),
      seriesProviderId: serializer.fromJson<String?>(json['seriesProviderId']),
      seasonNumber: serializer.fromJson<int?>(json['seasonNumber']),
      episodeNumber: serializer.fromJson<int?>(json['episodeNumber']),
      positionSeconds: serializer.fromJson<int>(json['positionSeconds']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<String>(playlistId),
      'contentProviderId': serializer.toJson<String>(contentProviderId),
      'contentType': serializer.toJson<String>(contentType),
      'seriesProviderId': serializer.toJson<String?>(seriesProviderId),
      'seasonNumber': serializer.toJson<int?>(seasonNumber),
      'episodeNumber': serializer.toJson<int?>(episodeNumber),
      'positionSeconds': serializer.toJson<int>(positionSeconds),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PlaybackPositionsTableData copyWith(
          {int? id,
          String? playlistId,
          String? contentProviderId,
          String? contentType,
          Value<String?> seriesProviderId = const Value.absent(),
          Value<int?> seasonNumber = const Value.absent(),
          Value<int?> episodeNumber = const Value.absent(),
          int? positionSeconds,
          Value<int?> durationSeconds = const Value.absent(),
          DateTime? updatedAt}) =>
      PlaybackPositionsTableData(
        id: id ?? this.id,
        playlistId: playlistId ?? this.playlistId,
        contentProviderId: contentProviderId ?? this.contentProviderId,
        contentType: contentType ?? this.contentType,
        seriesProviderId: seriesProviderId.present
            ? seriesProviderId.value
            : this.seriesProviderId,
        seasonNumber:
            seasonNumber.present ? seasonNumber.value : this.seasonNumber,
        episodeNumber:
            episodeNumber.present ? episodeNumber.value : this.episodeNumber,
        positionSeconds: positionSeconds ?? this.positionSeconds,
        durationSeconds: durationSeconds.present
            ? durationSeconds.value
            : this.durationSeconds,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  PlaybackPositionsTableData copyWithCompanion(
      PlaybackPositionsTableCompanion data) {
    return PlaybackPositionsTableData(
      id: data.id.present ? data.id.value : this.id,
      playlistId:
          data.playlistId.present ? data.playlistId.value : this.playlistId,
      contentProviderId: data.contentProviderId.present
          ? data.contentProviderId.value
          : this.contentProviderId,
      contentType:
          data.contentType.present ? data.contentType.value : this.contentType,
      seriesProviderId: data.seriesProviderId.present
          ? data.seriesProviderId.value
          : this.seriesProviderId,
      seasonNumber: data.seasonNumber.present
          ? data.seasonNumber.value
          : this.seasonNumber,
      episodeNumber: data.episodeNumber.present
          ? data.episodeNumber.value
          : this.episodeNumber,
      positionSeconds: data.positionSeconds.present
          ? data.positionSeconds.value
          : this.positionSeconds,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackPositionsTableData(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('contentProviderId: $contentProviderId, ')
          ..write('contentType: $contentType, ')
          ..write('seriesProviderId: $seriesProviderId, ')
          ..write('seasonNumber: $seasonNumber, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('positionSeconds: $positionSeconds, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      playlistId,
      contentProviderId,
      contentType,
      seriesProviderId,
      seasonNumber,
      episodeNumber,
      positionSeconds,
      durationSeconds,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackPositionsTableData &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.contentProviderId == this.contentProviderId &&
          other.contentType == this.contentType &&
          other.seriesProviderId == this.seriesProviderId &&
          other.seasonNumber == this.seasonNumber &&
          other.episodeNumber == this.episodeNumber &&
          other.positionSeconds == this.positionSeconds &&
          other.durationSeconds == this.durationSeconds &&
          other.updatedAt == this.updatedAt);
}

class PlaybackPositionsTableCompanion
    extends UpdateCompanion<PlaybackPositionsTableData> {
  final Value<int> id;
  final Value<String> playlistId;
  final Value<String> contentProviderId;
  final Value<String> contentType;
  final Value<String?> seriesProviderId;
  final Value<int?> seasonNumber;
  final Value<int?> episodeNumber;
  final Value<int> positionSeconds;
  final Value<int?> durationSeconds;
  final Value<DateTime> updatedAt;
  const PlaybackPositionsTableCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.contentProviderId = const Value.absent(),
    this.contentType = const Value.absent(),
    this.seriesProviderId = const Value.absent(),
    this.seasonNumber = const Value.absent(),
    this.episodeNumber = const Value.absent(),
    this.positionSeconds = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  PlaybackPositionsTableCompanion.insert({
    this.id = const Value.absent(),
    required String playlistId,
    required String contentProviderId,
    required String contentType,
    this.seriesProviderId = const Value.absent(),
    this.seasonNumber = const Value.absent(),
    this.episodeNumber = const Value.absent(),
    this.positionSeconds = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : playlistId = Value(playlistId),
        contentProviderId = Value(contentProviderId),
        contentType = Value(contentType);
  static Insertable<PlaybackPositionsTableData> custom({
    Expression<int>? id,
    Expression<String>? playlistId,
    Expression<String>? contentProviderId,
    Expression<String>? contentType,
    Expression<String>? seriesProviderId,
    Expression<int>? seasonNumber,
    Expression<int>? episodeNumber,
    Expression<int>? positionSeconds,
    Expression<int>? durationSeconds,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (contentProviderId != null) 'content_provider_id': contentProviderId,
      if (contentType != null) 'content_type': contentType,
      if (seriesProviderId != null) 'series_provider_id': seriesProviderId,
      if (seasonNumber != null) 'season_number': seasonNumber,
      if (episodeNumber != null) 'episode_number': episodeNumber,
      if (positionSeconds != null) 'position_seconds': positionSeconds,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  PlaybackPositionsTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? playlistId,
      Value<String>? contentProviderId,
      Value<String>? contentType,
      Value<String?>? seriesProviderId,
      Value<int?>? seasonNumber,
      Value<int?>? episodeNumber,
      Value<int>? positionSeconds,
      Value<int?>? durationSeconds,
      Value<DateTime>? updatedAt}) {
    return PlaybackPositionsTableCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      contentProviderId: contentProviderId ?? this.contentProviderId,
      contentType: contentType ?? this.contentType,
      seriesProviderId: seriesProviderId ?? this.seriesProviderId,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<String>(playlistId.value);
    }
    if (contentProviderId.present) {
      map['content_provider_id'] = Variable<String>(contentProviderId.value);
    }
    if (contentType.present) {
      map['content_type'] = Variable<String>(contentType.value);
    }
    if (seriesProviderId.present) {
      map['series_provider_id'] = Variable<String>(seriesProviderId.value);
    }
    if (seasonNumber.present) {
      map['season_number'] = Variable<int>(seasonNumber.value);
    }
    if (episodeNumber.present) {
      map['episode_number'] = Variable<int>(episodeNumber.value);
    }
    if (positionSeconds.present) {
      map['position_seconds'] = Variable<int>(positionSeconds.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackPositionsTableCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('contentProviderId: $contentProviderId, ')
          ..write('contentType: $contentType, ')
          ..write('seriesProviderId: $seriesProviderId, ')
          ..write('seasonNumber: $seasonNumber, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('positionSeconds: $positionSeconds, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $EpgChannelsTableTable extends EpgChannelsTable
    with TableInfo<$EpgChannelsTableTable, EpgChannelsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpgChannelsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _iconUrlMeta =
      const VerificationMeta('iconUrl');
  @override
  late final GeneratedColumn<String> iconUrl = GeneratedColumn<String>(
      'icon_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceUrlMeta =
      const VerificationMeta('sourceUrl');
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
      'source_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, displayName, iconUrl, sourceUrl, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'epg_channels_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<EpgChannelsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('icon_url')) {
      context.handle(_iconUrlMeta,
          iconUrl.isAcceptableOrUnknown(data['icon_url']!, _iconUrlMeta));
    }
    if (data.containsKey('source_url')) {
      context.handle(_sourceUrlMeta,
          sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta));
    } else if (isInserting) {
      context.missing(_sourceUrlMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EpgChannelsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpgChannelsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name'])!,
      iconUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon_url']),
      sourceUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_url'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $EpgChannelsTableTable createAlias(String alias) {
    return $EpgChannelsTableTable(attachedDatabase, alias);
  }
}

class EpgChannelsTableData extends DataClass
    implements Insertable<EpgChannelsTableData> {
  final String id;
  final String displayName;
  final String? iconUrl;
  final String sourceUrl;
  final DateTime updatedAt;
  const EpgChannelsTableData(
      {required this.id,
      required this.displayName,
      this.iconUrl,
      required this.sourceUrl,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || iconUrl != null) {
      map['icon_url'] = Variable<String>(iconUrl);
    }
    map['source_url'] = Variable<String>(sourceUrl);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  EpgChannelsTableCompanion toCompanion(bool nullToAbsent) {
    return EpgChannelsTableCompanion(
      id: Value(id),
      displayName: Value(displayName),
      iconUrl: iconUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(iconUrl),
      sourceUrl: Value(sourceUrl),
      updatedAt: Value(updatedAt),
    );
  }

  factory EpgChannelsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpgChannelsTableData(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      iconUrl: serializer.fromJson<String?>(json['iconUrl']),
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String>(displayName),
      'iconUrl': serializer.toJson<String?>(iconUrl),
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  EpgChannelsTableData copyWith(
          {String? id,
          String? displayName,
          Value<String?> iconUrl = const Value.absent(),
          String? sourceUrl,
          DateTime? updatedAt}) =>
      EpgChannelsTableData(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        iconUrl: iconUrl.present ? iconUrl.value : this.iconUrl,
        sourceUrl: sourceUrl ?? this.sourceUrl,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  EpgChannelsTableData copyWithCompanion(EpgChannelsTableCompanion data) {
    return EpgChannelsTableData(
      id: data.id.present ? data.id.value : this.id,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      iconUrl: data.iconUrl.present ? data.iconUrl.value : this.iconUrl,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpgChannelsTableData(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('iconUrl: $iconUrl, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, displayName, iconUrl, sourceUrl, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpgChannelsTableData &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.iconUrl == this.iconUrl &&
          other.sourceUrl == this.sourceUrl &&
          other.updatedAt == this.updatedAt);
}

class EpgChannelsTableCompanion extends UpdateCompanion<EpgChannelsTableData> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<String?> iconUrl;
  final Value<String> sourceUrl;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const EpgChannelsTableCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.iconUrl = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EpgChannelsTableCompanion.insert({
    required String id,
    required String displayName,
    this.iconUrl = const Value.absent(),
    required String sourceUrl,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        displayName = Value(displayName),
        sourceUrl = Value(sourceUrl);
  static Insertable<EpgChannelsTableData> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<String>? iconUrl,
    Expression<String>? sourceUrl,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (iconUrl != null) 'icon_url': iconUrl,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EpgChannelsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? displayName,
      Value<String?>? iconUrl,
      Value<String>? sourceUrl,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return EpgChannelsTableCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      iconUrl: iconUrl ?? this.iconUrl,
      sourceUrl: sourceUrl ?? this.sourceUrl,
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
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (iconUrl.present) {
      map['icon_url'] = Variable<String>(iconUrl.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
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
    return (StringBuffer('EpgChannelsTableCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('iconUrl: $iconUrl, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EpgProgramsTableTable extends EpgProgramsTable
    with TableInfo<$EpgProgramsTableTable, EpgProgramsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpgProgramsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _channelIdMeta =
      const VerificationMeta('channelId');
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
      'channel_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _startMeta = const VerificationMeta('start');
  @override
  late final GeneratedColumn<DateTime> start = GeneratedColumn<DateTime>(
      'start', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _stopMeta = const VerificationMeta('stop');
  @override
  late final GeneratedColumn<DateTime> stop = GeneratedColumn<DateTime>(
      'stop', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _iconUrlMeta =
      const VerificationMeta('iconUrl');
  @override
  late final GeneratedColumn<String> iconUrl = GeneratedColumn<String>(
      'icon_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<String> rating = GeneratedColumn<String>(
      'rating', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _episodeNumMeta =
      const VerificationMeta('episodeNum');
  @override
  late final GeneratedColumn<String> episodeNum = GeneratedColumn<String>(
      'episode_num', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceUrlMeta =
      const VerificationMeta('sourceUrl');
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
      'source_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        channelId,
        start,
        stop,
        title,
        description,
        category,
        iconUrl,
        rating,
        episodeNum,
        sourceUrl
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'epg_programs_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<EpgProgramsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('channel_id')) {
      context.handle(_channelIdMeta,
          channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta));
    } else if (isInserting) {
      context.missing(_channelIdMeta);
    }
    if (data.containsKey('start')) {
      context.handle(
          _startMeta, start.isAcceptableOrUnknown(data['start']!, _startMeta));
    } else if (isInserting) {
      context.missing(_startMeta);
    }
    if (data.containsKey('stop')) {
      context.handle(
          _stopMeta, stop.isAcceptableOrUnknown(data['stop']!, _stopMeta));
    } else if (isInserting) {
      context.missing(_stopMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('icon_url')) {
      context.handle(_iconUrlMeta,
          iconUrl.isAcceptableOrUnknown(data['icon_url']!, _iconUrlMeta));
    }
    if (data.containsKey('rating')) {
      context.handle(_ratingMeta,
          rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta));
    }
    if (data.containsKey('episode_num')) {
      context.handle(
          _episodeNumMeta,
          episodeNum.isAcceptableOrUnknown(
              data['episode_num']!, _episodeNumMeta));
    }
    if (data.containsKey('source_url')) {
      context.handle(_sourceUrlMeta,
          sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EpgProgramsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpgProgramsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      channelId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}channel_id'])!,
      start: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start'])!,
      stop: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}stop'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category']),
      iconUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon_url']),
      rating: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rating']),
      episodeNum: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}episode_num']),
      sourceUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_url']),
    );
  }

  @override
  $EpgProgramsTableTable createAlias(String alias) {
    return $EpgProgramsTableTable(attachedDatabase, alias);
  }
}

class EpgProgramsTableData extends DataClass
    implements Insertable<EpgProgramsTableData> {
  final int id;
  final String channelId;
  final DateTime start;
  final DateTime stop;
  final String title;
  final String? description;
  final String? category;
  final String? iconUrl;
  final String? rating;
  final String? episodeNum;
  final String? sourceUrl;
  const EpgProgramsTableData(
      {required this.id,
      required this.channelId,
      required this.start,
      required this.stop,
      required this.title,
      this.description,
      this.category,
      this.iconUrl,
      this.rating,
      this.episodeNum,
      this.sourceUrl});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['channel_id'] = Variable<String>(channelId);
    map['start'] = Variable<DateTime>(start);
    map['stop'] = Variable<DateTime>(stop);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || iconUrl != null) {
      map['icon_url'] = Variable<String>(iconUrl);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<String>(rating);
    }
    if (!nullToAbsent || episodeNum != null) {
      map['episode_num'] = Variable<String>(episodeNum);
    }
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    return map;
  }

  EpgProgramsTableCompanion toCompanion(bool nullToAbsent) {
    return EpgProgramsTableCompanion(
      id: Value(id),
      channelId: Value(channelId),
      start: Value(start),
      stop: Value(stop),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      iconUrl: iconUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(iconUrl),
      rating:
          rating == null && nullToAbsent ? const Value.absent() : Value(rating),
      episodeNum: episodeNum == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeNum),
      sourceUrl: sourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrl),
    );
  }

  factory EpgProgramsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpgProgramsTableData(
      id: serializer.fromJson<int>(json['id']),
      channelId: serializer.fromJson<String>(json['channelId']),
      start: serializer.fromJson<DateTime>(json['start']),
      stop: serializer.fromJson<DateTime>(json['stop']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      category: serializer.fromJson<String?>(json['category']),
      iconUrl: serializer.fromJson<String?>(json['iconUrl']),
      rating: serializer.fromJson<String?>(json['rating']),
      episodeNum: serializer.fromJson<String?>(json['episodeNum']),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'channelId': serializer.toJson<String>(channelId),
      'start': serializer.toJson<DateTime>(start),
      'stop': serializer.toJson<DateTime>(stop),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'category': serializer.toJson<String?>(category),
      'iconUrl': serializer.toJson<String?>(iconUrl),
      'rating': serializer.toJson<String?>(rating),
      'episodeNum': serializer.toJson<String?>(episodeNum),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
    };
  }

  EpgProgramsTableData copyWith(
          {int? id,
          String? channelId,
          DateTime? start,
          DateTime? stop,
          String? title,
          Value<String?> description = const Value.absent(),
          Value<String?> category = const Value.absent(),
          Value<String?> iconUrl = const Value.absent(),
          Value<String?> rating = const Value.absent(),
          Value<String?> episodeNum = const Value.absent(),
          Value<String?> sourceUrl = const Value.absent()}) =>
      EpgProgramsTableData(
        id: id ?? this.id,
        channelId: channelId ?? this.channelId,
        start: start ?? this.start,
        stop: stop ?? this.stop,
        title: title ?? this.title,
        description: description.present ? description.value : this.description,
        category: category.present ? category.value : this.category,
        iconUrl: iconUrl.present ? iconUrl.value : this.iconUrl,
        rating: rating.present ? rating.value : this.rating,
        episodeNum: episodeNum.present ? episodeNum.value : this.episodeNum,
        sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
      );
  EpgProgramsTableData copyWithCompanion(EpgProgramsTableCompanion data) {
    return EpgProgramsTableData(
      id: data.id.present ? data.id.value : this.id,
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      start: data.start.present ? data.start.value : this.start,
      stop: data.stop.present ? data.stop.value : this.stop,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      category: data.category.present ? data.category.value : this.category,
      iconUrl: data.iconUrl.present ? data.iconUrl.value : this.iconUrl,
      rating: data.rating.present ? data.rating.value : this.rating,
      episodeNum:
          data.episodeNum.present ? data.episodeNum.value : this.episodeNum,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpgProgramsTableData(')
          ..write('id: $id, ')
          ..write('channelId: $channelId, ')
          ..write('start: $start, ')
          ..write('stop: $stop, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('category: $category, ')
          ..write('iconUrl: $iconUrl, ')
          ..write('rating: $rating, ')
          ..write('episodeNum: $episodeNum, ')
          ..write('sourceUrl: $sourceUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, channelId, start, stop, title,
      description, category, iconUrl, rating, episodeNum, sourceUrl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpgProgramsTableData &&
          other.id == this.id &&
          other.channelId == this.channelId &&
          other.start == this.start &&
          other.stop == this.stop &&
          other.title == this.title &&
          other.description == this.description &&
          other.category == this.category &&
          other.iconUrl == this.iconUrl &&
          other.rating == this.rating &&
          other.episodeNum == this.episodeNum &&
          other.sourceUrl == this.sourceUrl);
}

class EpgProgramsTableCompanion extends UpdateCompanion<EpgProgramsTableData> {
  final Value<int> id;
  final Value<String> channelId;
  final Value<DateTime> start;
  final Value<DateTime> stop;
  final Value<String> title;
  final Value<String?> description;
  final Value<String?> category;
  final Value<String?> iconUrl;
  final Value<String?> rating;
  final Value<String?> episodeNum;
  final Value<String?> sourceUrl;
  const EpgProgramsTableCompanion({
    this.id = const Value.absent(),
    this.channelId = const Value.absent(),
    this.start = const Value.absent(),
    this.stop = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.category = const Value.absent(),
    this.iconUrl = const Value.absent(),
    this.rating = const Value.absent(),
    this.episodeNum = const Value.absent(),
    this.sourceUrl = const Value.absent(),
  });
  EpgProgramsTableCompanion.insert({
    this.id = const Value.absent(),
    required String channelId,
    required DateTime start,
    required DateTime stop,
    required String title,
    this.description = const Value.absent(),
    this.category = const Value.absent(),
    this.iconUrl = const Value.absent(),
    this.rating = const Value.absent(),
    this.episodeNum = const Value.absent(),
    this.sourceUrl = const Value.absent(),
  })  : channelId = Value(channelId),
        start = Value(start),
        stop = Value(stop),
        title = Value(title);
  static Insertable<EpgProgramsTableData> custom({
    Expression<int>? id,
    Expression<String>? channelId,
    Expression<DateTime>? start,
    Expression<DateTime>? stop,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? category,
    Expression<String>? iconUrl,
    Expression<String>? rating,
    Expression<String>? episodeNum,
    Expression<String>? sourceUrl,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (channelId != null) 'channel_id': channelId,
      if (start != null) 'start': start,
      if (stop != null) 'stop': stop,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (category != null) 'category': category,
      if (iconUrl != null) 'icon_url': iconUrl,
      if (rating != null) 'rating': rating,
      if (episodeNum != null) 'episode_num': episodeNum,
      if (sourceUrl != null) 'source_url': sourceUrl,
    });
  }

  EpgProgramsTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? channelId,
      Value<DateTime>? start,
      Value<DateTime>? stop,
      Value<String>? title,
      Value<String?>? description,
      Value<String?>? category,
      Value<String?>? iconUrl,
      Value<String?>? rating,
      Value<String?>? episodeNum,
      Value<String?>? sourceUrl}) {
    return EpgProgramsTableCompanion(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      start: start ?? this.start,
      stop: stop ?? this.stop,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      iconUrl: iconUrl ?? this.iconUrl,
      rating: rating ?? this.rating,
      episodeNum: episodeNum ?? this.episodeNum,
      sourceUrl: sourceUrl ?? this.sourceUrl,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (start.present) {
      map['start'] = Variable<DateTime>(start.value);
    }
    if (stop.present) {
      map['stop'] = Variable<DateTime>(stop.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (iconUrl.present) {
      map['icon_url'] = Variable<String>(iconUrl.value);
    }
    if (rating.present) {
      map['rating'] = Variable<String>(rating.value);
    }
    if (episodeNum.present) {
      map['episode_num'] = Variable<String>(episodeNum.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpgProgramsTableCompanion(')
          ..write('id: $id, ')
          ..write('channelId: $channelId, ')
          ..write('start: $start, ')
          ..write('stop: $stop, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('category: $category, ')
          ..write('iconUrl: $iconUrl, ')
          ..write('rating: $rating, ')
          ..write('episodeNum: $episodeNum, ')
          ..write('sourceUrl: $sourceUrl')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PlaylistsTableTable playlistsTable = $PlaylistsTableTable(this);
  late final $CategoriesTableTable categoriesTable =
      $CategoriesTableTable(this);
  late final $ContentItemsTableTable contentItemsTable =
      $ContentItemsTableTable(this);
  late final $FavoritesTableTable favoritesTable = $FavoritesTableTable(this);
  late final $RecentlyViewedTableTable recentlyViewedTable =
      $RecentlyViewedTableTable(this);
  late final $PlaybackPositionsTableTable playbackPositionsTable =
      $PlaybackPositionsTableTable(this);
  late final $EpgChannelsTableTable epgChannelsTable =
      $EpgChannelsTableTable(this);
  late final $EpgProgramsTableTable epgProgramsTable =
      $EpgProgramsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        playlistsTable,
        categoriesTable,
        contentItemsTable,
        favoritesTable,
        recentlyViewedTable,
        playbackPositionsTable,
        epgChannelsTable,
        epgProgramsTable
      ];
}

typedef $$PlaylistsTableTableCreateCompanionBuilder = PlaylistsTableCompanion
    Function({
  required String id,
  required String name,
  required String type,
  Value<String?> url,
  Value<String?> filePath,
  Value<String?> serverUrl,
  Value<String?> username,
  Value<String?> macAddress,
  Value<String?> userAgent,
  Value<bool> autoRefresh,
  Value<int> channelCount,
  Value<int> position,
  Value<DateTime> createdAt,
  Value<DateTime?> lastUpdated,
  Value<int> rowid,
});
typedef $$PlaylistsTableTableUpdateCompanionBuilder = PlaylistsTableCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<String> type,
  Value<String?> url,
  Value<String?> filePath,
  Value<String?> serverUrl,
  Value<String?> username,
  Value<String?> macAddress,
  Value<String?> userAgent,
  Value<bool> autoRefresh,
  Value<int> channelCount,
  Value<int> position,
  Value<DateTime> createdAt,
  Value<DateTime?> lastUpdated,
  Value<int> rowid,
});

class $$PlaylistsTableTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistsTableTable> {
  $$PlaylistsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get url => $composableBuilder(
      column: $table.url, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverUrl => $composableBuilder(
      column: $table.serverUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get username => $composableBuilder(
      column: $table.username, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get macAddress => $composableBuilder(
      column: $table.macAddress, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userAgent => $composableBuilder(
      column: $table.userAgent, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get autoRefresh => $composableBuilder(
      column: $table.autoRefresh, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get channelCount => $composableBuilder(
      column: $table.channelCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => ColumnFilters(column));
}

class $$PlaylistsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistsTableTable> {
  $$PlaylistsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get url => $composableBuilder(
      column: $table.url, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverUrl => $composableBuilder(
      column: $table.serverUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get username => $composableBuilder(
      column: $table.username, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get macAddress => $composableBuilder(
      column: $table.macAddress, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userAgent => $composableBuilder(
      column: $table.userAgent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get autoRefresh => $composableBuilder(
      column: $table.autoRefresh, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get channelCount => $composableBuilder(
      column: $table.channelCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => ColumnOrderings(column));
}

class $$PlaylistsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistsTableTable> {
  $$PlaylistsTableTableAnnotationComposer({
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

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get serverUrl =>
      $composableBuilder(column: $table.serverUrl, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get macAddress => $composableBuilder(
      column: $table.macAddress, builder: (column) => column);

  GeneratedColumn<String> get userAgent =>
      $composableBuilder(column: $table.userAgent, builder: (column) => column);

  GeneratedColumn<bool> get autoRefresh => $composableBuilder(
      column: $table.autoRefresh, builder: (column) => column);

  GeneratedColumn<int> get channelCount => $composableBuilder(
      column: $table.channelCount, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => column);
}

class $$PlaylistsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlaylistsTableTable,
    PlaylistsTableData,
    $$PlaylistsTableTableFilterComposer,
    $$PlaylistsTableTableOrderingComposer,
    $$PlaylistsTableTableAnnotationComposer,
    $$PlaylistsTableTableCreateCompanionBuilder,
    $$PlaylistsTableTableUpdateCompanionBuilder,
    (
      PlaylistsTableData,
      BaseReferences<_$AppDatabase, $PlaylistsTableTable, PlaylistsTableData>
    ),
    PlaylistsTableData,
    PrefetchHooks Function()> {
  $$PlaylistsTableTableTableManager(
      _$AppDatabase db, $PlaylistsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String?> url = const Value.absent(),
            Value<String?> filePath = const Value.absent(),
            Value<String?> serverUrl = const Value.absent(),
            Value<String?> username = const Value.absent(),
            Value<String?> macAddress = const Value.absent(),
            Value<String?> userAgent = const Value.absent(),
            Value<bool> autoRefresh = const Value.absent(),
            Value<int> channelCount = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> lastUpdated = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlaylistsTableCompanion(
            id: id,
            name: name,
            type: type,
            url: url,
            filePath: filePath,
            serverUrl: serverUrl,
            username: username,
            macAddress: macAddress,
            userAgent: userAgent,
            autoRefresh: autoRefresh,
            channelCount: channelCount,
            position: position,
            createdAt: createdAt,
            lastUpdated: lastUpdated,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String type,
            Value<String?> url = const Value.absent(),
            Value<String?> filePath = const Value.absent(),
            Value<String?> serverUrl = const Value.absent(),
            Value<String?> username = const Value.absent(),
            Value<String?> macAddress = const Value.absent(),
            Value<String?> userAgent = const Value.absent(),
            Value<bool> autoRefresh = const Value.absent(),
            Value<int> channelCount = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> lastUpdated = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlaylistsTableCompanion.insert(
            id: id,
            name: name,
            type: type,
            url: url,
            filePath: filePath,
            serverUrl: serverUrl,
            username: username,
            macAddress: macAddress,
            userAgent: userAgent,
            autoRefresh: autoRefresh,
            channelCount: channelCount,
            position: position,
            createdAt: createdAt,
            lastUpdated: lastUpdated,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PlaylistsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlaylistsTableTable,
    PlaylistsTableData,
    $$PlaylistsTableTableFilterComposer,
    $$PlaylistsTableTableOrderingComposer,
    $$PlaylistsTableTableAnnotationComposer,
    $$PlaylistsTableTableCreateCompanionBuilder,
    $$PlaylistsTableTableUpdateCompanionBuilder,
    (
      PlaylistsTableData,
      BaseReferences<_$AppDatabase, $PlaylistsTableTable, PlaylistsTableData>
    ),
    PlaylistsTableData,
    PrefetchHooks Function()>;
typedef $$CategoriesTableTableCreateCompanionBuilder = CategoriesTableCompanion
    Function({
  Value<int> id,
  required String playlistId,
  required String name,
  required String type,
  required String providerId,
  Value<bool> hidden,
  Value<bool> locked,
});
typedef $$CategoriesTableTableUpdateCompanionBuilder = CategoriesTableCompanion
    Function({
  Value<int> id,
  Value<String> playlistId,
  Value<String> name,
  Value<String> type,
  Value<String> providerId,
  Value<bool> hidden,
  Value<bool> locked,
});

class $$CategoriesTableTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTableTable> {
  $$CategoriesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get playlistId => $composableBuilder(
      column: $table.playlistId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get hidden => $composableBuilder(
      column: $table.hidden, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get locked => $composableBuilder(
      column: $table.locked, builder: (column) => ColumnFilters(column));
}

class $$CategoriesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTableTable> {
  $$CategoriesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get playlistId => $composableBuilder(
      column: $table.playlistId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get hidden => $composableBuilder(
      column: $table.hidden, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get locked => $composableBuilder(
      column: $table.locked, builder: (column) => ColumnOrderings(column));
}

class $$CategoriesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTableTable> {
  $$CategoriesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get playlistId => $composableBuilder(
      column: $table.playlistId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => column);

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  GeneratedColumn<bool> get locked =>
      $composableBuilder(column: $table.locked, builder: (column) => column);
}

class $$CategoriesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CategoriesTableTable,
    CategoriesTableData,
    $$CategoriesTableTableFilterComposer,
    $$CategoriesTableTableOrderingComposer,
    $$CategoriesTableTableAnnotationComposer,
    $$CategoriesTableTableCreateCompanionBuilder,
    $$CategoriesTableTableUpdateCompanionBuilder,
    (
      CategoriesTableData,
      BaseReferences<_$AppDatabase, $CategoriesTableTable, CategoriesTableData>
    ),
    CategoriesTableData,
    PrefetchHooks Function()> {
  $$CategoriesTableTableTableManager(
      _$AppDatabase db, $CategoriesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> playlistId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> providerId = const Value.absent(),
            Value<bool> hidden = const Value.absent(),
            Value<bool> locked = const Value.absent(),
          }) =>
              CategoriesTableCompanion(
            id: id,
            playlistId: playlistId,
            name: name,
            type: type,
            providerId: providerId,
            hidden: hidden,
            locked: locked,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String playlistId,
            required String name,
            required String type,
            required String providerId,
            Value<bool> hidden = const Value.absent(),
            Value<bool> locked = const Value.absent(),
          }) =>
              CategoriesTableCompanion.insert(
            id: id,
            playlistId: playlistId,
            name: name,
            type: type,
            providerId: providerId,
            hidden: hidden,
            locked: locked,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CategoriesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CategoriesTableTable,
    CategoriesTableData,
    $$CategoriesTableTableFilterComposer,
    $$CategoriesTableTableOrderingComposer,
    $$CategoriesTableTableAnnotationComposer,
    $$CategoriesTableTableCreateCompanionBuilder,
    $$CategoriesTableTableUpdateCompanionBuilder,
    (
      CategoriesTableData,
      BaseReferences<_$AppDatabase, $CategoriesTableTable, CategoriesTableData>
    ),
    CategoriesTableData,
    PrefetchHooks Function()>;
typedef $$ContentItemsTableTableCreateCompanionBuilder
    = ContentItemsTableCompanion Function({
  Value<int> id,
  required String playlistId,
  Value<int?> categoryId,
  required String title,
  required String type,
  required String providerId,
  Value<String?> streamUrl,
  Value<String?> containerExtension,
  Value<String?> posterUrl,
  Value<String?> backdropUrl,
  Value<double?> rating,
  Value<int?> releaseYear,
  Value<String?> epgChannelId,
  Value<int> tvArchive,
  Value<int> tvArchiveDuration,
  Value<int?> tmdbId,
  Value<DateTime?> addedAt,
});
typedef $$ContentItemsTableTableUpdateCompanionBuilder
    = ContentItemsTableCompanion Function({
  Value<int> id,
  Value<String> playlistId,
  Value<int?> categoryId,
  Value<String> title,
  Value<String> type,
  Value<String> providerId,
  Value<String?> streamUrl,
  Value<String?> containerExtension,
  Value<String?> posterUrl,
  Value<String?> backdropUrl,
  Value<double?> rating,
  Value<int?> releaseYear,
  Value<String?> epgChannelId,
  Value<int> tvArchive,
  Value<int> tvArchiveDuration,
  Value<int?> tmdbId,
  Value<DateTime?> addedAt,
});

class $$ContentItemsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ContentItemsTableTable> {
  $$ContentItemsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get playlistId => $composableBuilder(
      column: $table.playlistId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get streamUrl => $composableBuilder(
      column: $table.streamUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get containerExtension => $composableBuilder(
      column: $table.containerExtension,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get posterUrl => $composableBuilder(
      column: $table.posterUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get backdropUrl => $composableBuilder(
      column: $table.backdropUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get releaseYear => $composableBuilder(
      column: $table.releaseYear, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get epgChannelId => $composableBuilder(
      column: $table.epgChannelId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tvArchive => $composableBuilder(
      column: $table.tvArchive, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tvArchiveDuration => $composableBuilder(
      column: $table.tvArchiveDuration,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tmdbId => $composableBuilder(
      column: $table.tmdbId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnFilters(column));
}

class $$ContentItemsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ContentItemsTableTable> {
  $$ContentItemsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get playlistId => $composableBuilder(
      column: $table.playlistId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get streamUrl => $composableBuilder(
      column: $table.streamUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get containerExtension => $composableBuilder(
      column: $table.containerExtension,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get posterUrl => $composableBuilder(
      column: $table.posterUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get backdropUrl => $composableBuilder(
      column: $table.backdropUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get releaseYear => $composableBuilder(
      column: $table.releaseYear, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get epgChannelId => $composableBuilder(
      column: $table.epgChannelId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tvArchive => $composableBuilder(
      column: $table.tvArchive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tvArchiveDuration => $composableBuilder(
      column: $table.tvArchiveDuration,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tmdbId => $composableBuilder(
      column: $table.tmdbId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnOrderings(column));
}

class $$ContentItemsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContentItemsTableTable> {
  $$ContentItemsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get playlistId => $composableBuilder(
      column: $table.playlistId, builder: (column) => column);

  GeneratedColumn<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => column);

  GeneratedColumn<String> get streamUrl =>
      $composableBuilder(column: $table.streamUrl, builder: (column) => column);

  GeneratedColumn<String> get containerExtension => $composableBuilder(
      column: $table.containerExtension, builder: (column) => column);

  GeneratedColumn<String> get posterUrl =>
      $composableBuilder(column: $table.posterUrl, builder: (column) => column);

  GeneratedColumn<String> get backdropUrl => $composableBuilder(
      column: $table.backdropUrl, builder: (column) => column);

  GeneratedColumn<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<int> get releaseYear => $composableBuilder(
      column: $table.releaseYear, builder: (column) => column);

  GeneratedColumn<String> get epgChannelId => $composableBuilder(
      column: $table.epgChannelId, builder: (column) => column);

  GeneratedColumn<int> get tvArchive =>
      $composableBuilder(column: $table.tvArchive, builder: (column) => column);

  GeneratedColumn<int> get tvArchiveDuration => $composableBuilder(
      column: $table.tvArchiveDuration, builder: (column) => column);

  GeneratedColumn<int> get tmdbId =>
      $composableBuilder(column: $table.tmdbId, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$ContentItemsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ContentItemsTableTable,
    ContentItemsTableData,
    $$ContentItemsTableTableFilterComposer,
    $$ContentItemsTableTableOrderingComposer,
    $$ContentItemsTableTableAnnotationComposer,
    $$ContentItemsTableTableCreateCompanionBuilder,
    $$ContentItemsTableTableUpdateCompanionBuilder,
    (
      ContentItemsTableData,
      BaseReferences<_$AppDatabase, $ContentItemsTableTable,
          ContentItemsTableData>
    ),
    ContentItemsTableData,
    PrefetchHooks Function()> {
  $$ContentItemsTableTableTableManager(
      _$AppDatabase db, $ContentItemsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentItemsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentItemsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentItemsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> playlistId = const Value.absent(),
            Value<int?> categoryId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> providerId = const Value.absent(),
            Value<String?> streamUrl = const Value.absent(),
            Value<String?> containerExtension = const Value.absent(),
            Value<String?> posterUrl = const Value.absent(),
            Value<String?> backdropUrl = const Value.absent(),
            Value<double?> rating = const Value.absent(),
            Value<int?> releaseYear = const Value.absent(),
            Value<String?> epgChannelId = const Value.absent(),
            Value<int> tvArchive = const Value.absent(),
            Value<int> tvArchiveDuration = const Value.absent(),
            Value<int?> tmdbId = const Value.absent(),
            Value<DateTime?> addedAt = const Value.absent(),
          }) =>
              ContentItemsTableCompanion(
            id: id,
            playlistId: playlistId,
            categoryId: categoryId,
            title: title,
            type: type,
            providerId: providerId,
            streamUrl: streamUrl,
            containerExtension: containerExtension,
            posterUrl: posterUrl,
            backdropUrl: backdropUrl,
            rating: rating,
            releaseYear: releaseYear,
            epgChannelId: epgChannelId,
            tvArchive: tvArchive,
            tvArchiveDuration: tvArchiveDuration,
            tmdbId: tmdbId,
            addedAt: addedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String playlistId,
            Value<int?> categoryId = const Value.absent(),
            required String title,
            required String type,
            required String providerId,
            Value<String?> streamUrl = const Value.absent(),
            Value<String?> containerExtension = const Value.absent(),
            Value<String?> posterUrl = const Value.absent(),
            Value<String?> backdropUrl = const Value.absent(),
            Value<double?> rating = const Value.absent(),
            Value<int?> releaseYear = const Value.absent(),
            Value<String?> epgChannelId = const Value.absent(),
            Value<int> tvArchive = const Value.absent(),
            Value<int> tvArchiveDuration = const Value.absent(),
            Value<int?> tmdbId = const Value.absent(),
            Value<DateTime?> addedAt = const Value.absent(),
          }) =>
              ContentItemsTableCompanion.insert(
            id: id,
            playlistId: playlistId,
            categoryId: categoryId,
            title: title,
            type: type,
            providerId: providerId,
            streamUrl: streamUrl,
            containerExtension: containerExtension,
            posterUrl: posterUrl,
            backdropUrl: backdropUrl,
            rating: rating,
            releaseYear: releaseYear,
            epgChannelId: epgChannelId,
            tvArchive: tvArchive,
            tvArchiveDuration: tvArchiveDuration,
            tmdbId: tmdbId,
            addedAt: addedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ContentItemsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ContentItemsTableTable,
    ContentItemsTableData,
    $$ContentItemsTableTableFilterComposer,
    $$ContentItemsTableTableOrderingComposer,
    $$ContentItemsTableTableAnnotationComposer,
    $$ContentItemsTableTableCreateCompanionBuilder,
    $$ContentItemsTableTableUpdateCompanionBuilder,
    (
      ContentItemsTableData,
      BaseReferences<_$AppDatabase, $ContentItemsTableTable,
          ContentItemsTableData>
    ),
    ContentItemsTableData,
    PrefetchHooks Function()>;
typedef $$FavoritesTableTableCreateCompanionBuilder = FavoritesTableCompanion
    Function({
  Value<int> id,
  required String playlistId,
  Value<int?> contentId,
  required String providerId,
  required String type,
  required String title,
  Value<String?> posterUrl,
  Value<String?> backdropUrl,
  Value<int> position,
  Value<DateTime> addedAt,
});
typedef $$FavoritesTableTableUpdateCompanionBuilder = FavoritesTableCompanion
    Function({
  Value<int> id,
  Value<String> playlistId,
  Value<int?> contentId,
  Value<String> providerId,
  Value<String> type,
  Value<String> title,
  Value<String?> posterUrl,
  Value<String?> backdropUrl,
  Value<int> position,
  Value<DateTime> addedAt,
});

class $$FavoritesTableTableFilterComposer
    extends Composer<_$AppDatabase, $FavoritesTableTable> {
  $$FavoritesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get playlistId => $composableBuilder(
      column: $table.playlistId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get contentId => $composableBuilder(
      column: $table.contentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get posterUrl => $composableBuilder(
      column: $table.posterUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get backdropUrl => $composableBuilder(
      column: $table.backdropUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnFilters(column));
}

class $$FavoritesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoritesTableTable> {
  $$FavoritesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get playlistId => $composableBuilder(
      column: $table.playlistId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get contentId => $composableBuilder(
      column: $table.contentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get posterUrl => $composableBuilder(
      column: $table.posterUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get backdropUrl => $composableBuilder(
      column: $table.backdropUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnOrderings(column));
}

class $$FavoritesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoritesTableTable> {
  $$FavoritesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get playlistId => $composableBuilder(
      column: $table.playlistId, builder: (column) => column);

  GeneratedColumn<int> get contentId =>
      $composableBuilder(column: $table.contentId, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get posterUrl =>
      $composableBuilder(column: $table.posterUrl, builder: (column) => column);

  GeneratedColumn<String> get backdropUrl => $composableBuilder(
      column: $table.backdropUrl, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$FavoritesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FavoritesTableTable,
    FavoritesTableData,
    $$FavoritesTableTableFilterComposer,
    $$FavoritesTableTableOrderingComposer,
    $$FavoritesTableTableAnnotationComposer,
    $$FavoritesTableTableCreateCompanionBuilder,
    $$FavoritesTableTableUpdateCompanionBuilder,
    (
      FavoritesTableData,
      BaseReferences<_$AppDatabase, $FavoritesTableTable, FavoritesTableData>
    ),
    FavoritesTableData,
    PrefetchHooks Function()> {
  $$FavoritesTableTableTableManager(
      _$AppDatabase db, $FavoritesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoritesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoritesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoritesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> playlistId = const Value.absent(),
            Value<int?> contentId = const Value.absent(),
            Value<String> providerId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> posterUrl = const Value.absent(),
            Value<String?> backdropUrl = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<DateTime> addedAt = const Value.absent(),
          }) =>
              FavoritesTableCompanion(
            id: id,
            playlistId: playlistId,
            contentId: contentId,
            providerId: providerId,
            type: type,
            title: title,
            posterUrl: posterUrl,
            backdropUrl: backdropUrl,
            position: position,
            addedAt: addedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String playlistId,
            Value<int?> contentId = const Value.absent(),
            required String providerId,
            required String type,
            required String title,
            Value<String?> posterUrl = const Value.absent(),
            Value<String?> backdropUrl = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<DateTime> addedAt = const Value.absent(),
          }) =>
              FavoritesTableCompanion.insert(
            id: id,
            playlistId: playlistId,
            contentId: contentId,
            providerId: providerId,
            type: type,
            title: title,
            posterUrl: posterUrl,
            backdropUrl: backdropUrl,
            position: position,
            addedAt: addedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FavoritesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FavoritesTableTable,
    FavoritesTableData,
    $$FavoritesTableTableFilterComposer,
    $$FavoritesTableTableOrderingComposer,
    $$FavoritesTableTableAnnotationComposer,
    $$FavoritesTableTableCreateCompanionBuilder,
    $$FavoritesTableTableUpdateCompanionBuilder,
    (
      FavoritesTableData,
      BaseReferences<_$AppDatabase, $FavoritesTableTable, FavoritesTableData>
    ),
    FavoritesTableData,
    PrefetchHooks Function()>;
typedef $$RecentlyViewedTableTableCreateCompanionBuilder
    = RecentlyViewedTableCompanion Function({
  Value<int> id,
  required String playlistId,
  required int contentId,
  Value<DateTime> viewedAt,
});
typedef $$RecentlyViewedTableTableUpdateCompanionBuilder
    = RecentlyViewedTableCompanion Function({
  Value<int> id,
  Value<String> playlistId,
  Value<int> contentId,
  Value<DateTime> viewedAt,
});

class $$RecentlyViewedTableTableFilterComposer
    extends Composer<_$AppDatabase, $RecentlyViewedTableTable> {
  $$RecentlyViewedTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get playlistId => $composableBuilder(
      column: $table.playlistId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get contentId => $composableBuilder(
      column: $table.contentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get viewedAt => $composableBuilder(
      column: $table.viewedAt, builder: (column) => ColumnFilters(column));
}

class $$RecentlyViewedTableTableOrderingComposer
    extends Composer<_$AppDatabase, $RecentlyViewedTableTable> {
  $$RecentlyViewedTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get playlistId => $composableBuilder(
      column: $table.playlistId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get contentId => $composableBuilder(
      column: $table.contentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get viewedAt => $composableBuilder(
      column: $table.viewedAt, builder: (column) => ColumnOrderings(column));
}

class $$RecentlyViewedTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecentlyViewedTableTable> {
  $$RecentlyViewedTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get playlistId => $composableBuilder(
      column: $table.playlistId, builder: (column) => column);

  GeneratedColumn<int> get contentId =>
      $composableBuilder(column: $table.contentId, builder: (column) => column);

  GeneratedColumn<DateTime> get viewedAt =>
      $composableBuilder(column: $table.viewedAt, builder: (column) => column);
}

class $$RecentlyViewedTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RecentlyViewedTableTable,
    RecentlyViewedTableData,
    $$RecentlyViewedTableTableFilterComposer,
    $$RecentlyViewedTableTableOrderingComposer,
    $$RecentlyViewedTableTableAnnotationComposer,
    $$RecentlyViewedTableTableCreateCompanionBuilder,
    $$RecentlyViewedTableTableUpdateCompanionBuilder,
    (
      RecentlyViewedTableData,
      BaseReferences<_$AppDatabase, $RecentlyViewedTableTable,
          RecentlyViewedTableData>
    ),
    RecentlyViewedTableData,
    PrefetchHooks Function()> {
  $$RecentlyViewedTableTableTableManager(
      _$AppDatabase db, $RecentlyViewedTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecentlyViewedTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecentlyViewedTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecentlyViewedTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> playlistId = const Value.absent(),
            Value<int> contentId = const Value.absent(),
            Value<DateTime> viewedAt = const Value.absent(),
          }) =>
              RecentlyViewedTableCompanion(
            id: id,
            playlistId: playlistId,
            contentId: contentId,
            viewedAt: viewedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String playlistId,
            required int contentId,
            Value<DateTime> viewedAt = const Value.absent(),
          }) =>
              RecentlyViewedTableCompanion.insert(
            id: id,
            playlistId: playlistId,
            contentId: contentId,
            viewedAt: viewedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RecentlyViewedTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RecentlyViewedTableTable,
    RecentlyViewedTableData,
    $$RecentlyViewedTableTableFilterComposer,
    $$RecentlyViewedTableTableOrderingComposer,
    $$RecentlyViewedTableTableAnnotationComposer,
    $$RecentlyViewedTableTableCreateCompanionBuilder,
    $$RecentlyViewedTableTableUpdateCompanionBuilder,
    (
      RecentlyViewedTableData,
      BaseReferences<_$AppDatabase, $RecentlyViewedTableTable,
          RecentlyViewedTableData>
    ),
    RecentlyViewedTableData,
    PrefetchHooks Function()>;
typedef $$PlaybackPositionsTableTableCreateCompanionBuilder
    = PlaybackPositionsTableCompanion Function({
  Value<int> id,
  required String playlistId,
  required String contentProviderId,
  required String contentType,
  Value<String?> seriesProviderId,
  Value<int?> seasonNumber,
  Value<int?> episodeNumber,
  Value<int> positionSeconds,
  Value<int?> durationSeconds,
  Value<DateTime> updatedAt,
});
typedef $$PlaybackPositionsTableTableUpdateCompanionBuilder
    = PlaybackPositionsTableCompanion Function({
  Value<int> id,
  Value<String> playlistId,
  Value<String> contentProviderId,
  Value<String> contentType,
  Value<String?> seriesProviderId,
  Value<int?> seasonNumber,
  Value<int?> episodeNumber,
  Value<int> positionSeconds,
  Value<int?> durationSeconds,
  Value<DateTime> updatedAt,
});

class $$PlaybackPositionsTableTableFilterComposer
    extends Composer<_$AppDatabase, $PlaybackPositionsTableTable> {
  $$PlaybackPositionsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get playlistId => $composableBuilder(
      column: $table.playlistId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contentProviderId => $composableBuilder(
      column: $table.contentProviderId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contentType => $composableBuilder(
      column: $table.contentType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get seriesProviderId => $composableBuilder(
      column: $table.seriesProviderId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seasonNumber => $composableBuilder(
      column: $table.seasonNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get episodeNumber => $composableBuilder(
      column: $table.episodeNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get positionSeconds => $composableBuilder(
      column: $table.positionSeconds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$PlaybackPositionsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaybackPositionsTableTable> {
  $$PlaybackPositionsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get playlistId => $composableBuilder(
      column: $table.playlistId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contentProviderId => $composableBuilder(
      column: $table.contentProviderId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contentType => $composableBuilder(
      column: $table.contentType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get seriesProviderId => $composableBuilder(
      column: $table.seriesProviderId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seasonNumber => $composableBuilder(
      column: $table.seasonNumber,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get episodeNumber => $composableBuilder(
      column: $table.episodeNumber,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get positionSeconds => $composableBuilder(
      column: $table.positionSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$PlaybackPositionsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaybackPositionsTableTable> {
  $$PlaybackPositionsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get playlistId => $composableBuilder(
      column: $table.playlistId, builder: (column) => column);

  GeneratedColumn<String> get contentProviderId => $composableBuilder(
      column: $table.contentProviderId, builder: (column) => column);

  GeneratedColumn<String> get contentType => $composableBuilder(
      column: $table.contentType, builder: (column) => column);

  GeneratedColumn<String> get seriesProviderId => $composableBuilder(
      column: $table.seriesProviderId, builder: (column) => column);

  GeneratedColumn<int> get seasonNumber => $composableBuilder(
      column: $table.seasonNumber, builder: (column) => column);

  GeneratedColumn<int> get episodeNumber => $composableBuilder(
      column: $table.episodeNumber, builder: (column) => column);

  GeneratedColumn<int> get positionSeconds => $composableBuilder(
      column: $table.positionSeconds, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PlaybackPositionsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlaybackPositionsTableTable,
    PlaybackPositionsTableData,
    $$PlaybackPositionsTableTableFilterComposer,
    $$PlaybackPositionsTableTableOrderingComposer,
    $$PlaybackPositionsTableTableAnnotationComposer,
    $$PlaybackPositionsTableTableCreateCompanionBuilder,
    $$PlaybackPositionsTableTableUpdateCompanionBuilder,
    (
      PlaybackPositionsTableData,
      BaseReferences<_$AppDatabase, $PlaybackPositionsTableTable,
          PlaybackPositionsTableData>
    ),
    PlaybackPositionsTableData,
    PrefetchHooks Function()> {
  $$PlaybackPositionsTableTableTableManager(
      _$AppDatabase db, $PlaybackPositionsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackPositionsTableTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackPositionsTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaybackPositionsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> playlistId = const Value.absent(),
            Value<String> contentProviderId = const Value.absent(),
            Value<String> contentType = const Value.absent(),
            Value<String?> seriesProviderId = const Value.absent(),
            Value<int?> seasonNumber = const Value.absent(),
            Value<int?> episodeNumber = const Value.absent(),
            Value<int> positionSeconds = const Value.absent(),
            Value<int?> durationSeconds = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              PlaybackPositionsTableCompanion(
            id: id,
            playlistId: playlistId,
            contentProviderId: contentProviderId,
            contentType: contentType,
            seriesProviderId: seriesProviderId,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
            positionSeconds: positionSeconds,
            durationSeconds: durationSeconds,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String playlistId,
            required String contentProviderId,
            required String contentType,
            Value<String?> seriesProviderId = const Value.absent(),
            Value<int?> seasonNumber = const Value.absent(),
            Value<int?> episodeNumber = const Value.absent(),
            Value<int> positionSeconds = const Value.absent(),
            Value<int?> durationSeconds = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              PlaybackPositionsTableCompanion.insert(
            id: id,
            playlistId: playlistId,
            contentProviderId: contentProviderId,
            contentType: contentType,
            seriesProviderId: seriesProviderId,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
            positionSeconds: positionSeconds,
            durationSeconds: durationSeconds,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PlaybackPositionsTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $PlaybackPositionsTableTable,
        PlaybackPositionsTableData,
        $$PlaybackPositionsTableTableFilterComposer,
        $$PlaybackPositionsTableTableOrderingComposer,
        $$PlaybackPositionsTableTableAnnotationComposer,
        $$PlaybackPositionsTableTableCreateCompanionBuilder,
        $$PlaybackPositionsTableTableUpdateCompanionBuilder,
        (
          PlaybackPositionsTableData,
          BaseReferences<_$AppDatabase, $PlaybackPositionsTableTable,
              PlaybackPositionsTableData>
        ),
        PlaybackPositionsTableData,
        PrefetchHooks Function()>;
typedef $$EpgChannelsTableTableCreateCompanionBuilder
    = EpgChannelsTableCompanion Function({
  required String id,
  required String displayName,
  Value<String?> iconUrl,
  required String sourceUrl,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$EpgChannelsTableTableUpdateCompanionBuilder
    = EpgChannelsTableCompanion Function({
  Value<String> id,
  Value<String> displayName,
  Value<String?> iconUrl,
  Value<String> sourceUrl,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$EpgChannelsTableTableFilterComposer
    extends Composer<_$AppDatabase, $EpgChannelsTableTable> {
  $$EpgChannelsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconUrl => $composableBuilder(
      column: $table.iconUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceUrl => $composableBuilder(
      column: $table.sourceUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$EpgChannelsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $EpgChannelsTableTable> {
  $$EpgChannelsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconUrl => $composableBuilder(
      column: $table.iconUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
      column: $table.sourceUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$EpgChannelsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpgChannelsTableTable> {
  $$EpgChannelsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => column);

  GeneratedColumn<String> get iconUrl =>
      $composableBuilder(column: $table.iconUrl, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$EpgChannelsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $EpgChannelsTableTable,
    EpgChannelsTableData,
    $$EpgChannelsTableTableFilterComposer,
    $$EpgChannelsTableTableOrderingComposer,
    $$EpgChannelsTableTableAnnotationComposer,
    $$EpgChannelsTableTableCreateCompanionBuilder,
    $$EpgChannelsTableTableUpdateCompanionBuilder,
    (
      EpgChannelsTableData,
      BaseReferences<_$AppDatabase, $EpgChannelsTableTable,
          EpgChannelsTableData>
    ),
    EpgChannelsTableData,
    PrefetchHooks Function()> {
  $$EpgChannelsTableTableTableManager(
      _$AppDatabase db, $EpgChannelsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpgChannelsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpgChannelsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpgChannelsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> displayName = const Value.absent(),
            Value<String?> iconUrl = const Value.absent(),
            Value<String> sourceUrl = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EpgChannelsTableCompanion(
            id: id,
            displayName: displayName,
            iconUrl: iconUrl,
            sourceUrl: sourceUrl,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String displayName,
            Value<String?> iconUrl = const Value.absent(),
            required String sourceUrl,
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EpgChannelsTableCompanion.insert(
            id: id,
            displayName: displayName,
            iconUrl: iconUrl,
            sourceUrl: sourceUrl,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$EpgChannelsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $EpgChannelsTableTable,
    EpgChannelsTableData,
    $$EpgChannelsTableTableFilterComposer,
    $$EpgChannelsTableTableOrderingComposer,
    $$EpgChannelsTableTableAnnotationComposer,
    $$EpgChannelsTableTableCreateCompanionBuilder,
    $$EpgChannelsTableTableUpdateCompanionBuilder,
    (
      EpgChannelsTableData,
      BaseReferences<_$AppDatabase, $EpgChannelsTableTable,
          EpgChannelsTableData>
    ),
    EpgChannelsTableData,
    PrefetchHooks Function()>;
typedef $$EpgProgramsTableTableCreateCompanionBuilder
    = EpgProgramsTableCompanion Function({
  Value<int> id,
  required String channelId,
  required DateTime start,
  required DateTime stop,
  required String title,
  Value<String?> description,
  Value<String?> category,
  Value<String?> iconUrl,
  Value<String?> rating,
  Value<String?> episodeNum,
  Value<String?> sourceUrl,
});
typedef $$EpgProgramsTableTableUpdateCompanionBuilder
    = EpgProgramsTableCompanion Function({
  Value<int> id,
  Value<String> channelId,
  Value<DateTime> start,
  Value<DateTime> stop,
  Value<String> title,
  Value<String?> description,
  Value<String?> category,
  Value<String?> iconUrl,
  Value<String?> rating,
  Value<String?> episodeNum,
  Value<String?> sourceUrl,
});

class $$EpgProgramsTableTableFilterComposer
    extends Composer<_$AppDatabase, $EpgProgramsTableTable> {
  $$EpgProgramsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get channelId => $composableBuilder(
      column: $table.channelId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get start => $composableBuilder(
      column: $table.start, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get stop => $composableBuilder(
      column: $table.stop, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconUrl => $composableBuilder(
      column: $table.iconUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get episodeNum => $composableBuilder(
      column: $table.episodeNum, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceUrl => $composableBuilder(
      column: $table.sourceUrl, builder: (column) => ColumnFilters(column));
}

class $$EpgProgramsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $EpgProgramsTableTable> {
  $$EpgProgramsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get channelId => $composableBuilder(
      column: $table.channelId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get start => $composableBuilder(
      column: $table.start, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get stop => $composableBuilder(
      column: $table.stop, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconUrl => $composableBuilder(
      column: $table.iconUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get episodeNum => $composableBuilder(
      column: $table.episodeNum, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
      column: $table.sourceUrl, builder: (column) => ColumnOrderings(column));
}

class $$EpgProgramsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpgProgramsTableTable> {
  $$EpgProgramsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get channelId =>
      $composableBuilder(column: $table.channelId, builder: (column) => column);

  GeneratedColumn<DateTime> get start =>
      $composableBuilder(column: $table.start, builder: (column) => column);

  GeneratedColumn<DateTime> get stop =>
      $composableBuilder(column: $table.stop, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get iconUrl =>
      $composableBuilder(column: $table.iconUrl, builder: (column) => column);

  GeneratedColumn<String> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get episodeNum => $composableBuilder(
      column: $table.episodeNum, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);
}

class $$EpgProgramsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $EpgProgramsTableTable,
    EpgProgramsTableData,
    $$EpgProgramsTableTableFilterComposer,
    $$EpgProgramsTableTableOrderingComposer,
    $$EpgProgramsTableTableAnnotationComposer,
    $$EpgProgramsTableTableCreateCompanionBuilder,
    $$EpgProgramsTableTableUpdateCompanionBuilder,
    (
      EpgProgramsTableData,
      BaseReferences<_$AppDatabase, $EpgProgramsTableTable,
          EpgProgramsTableData>
    ),
    EpgProgramsTableData,
    PrefetchHooks Function()> {
  $$EpgProgramsTableTableTableManager(
      _$AppDatabase db, $EpgProgramsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpgProgramsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpgProgramsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpgProgramsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> channelId = const Value.absent(),
            Value<DateTime> start = const Value.absent(),
            Value<DateTime> stop = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<String?> iconUrl = const Value.absent(),
            Value<String?> rating = const Value.absent(),
            Value<String?> episodeNum = const Value.absent(),
            Value<String?> sourceUrl = const Value.absent(),
          }) =>
              EpgProgramsTableCompanion(
            id: id,
            channelId: channelId,
            start: start,
            stop: stop,
            title: title,
            description: description,
            category: category,
            iconUrl: iconUrl,
            rating: rating,
            episodeNum: episodeNum,
            sourceUrl: sourceUrl,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String channelId,
            required DateTime start,
            required DateTime stop,
            required String title,
            Value<String?> description = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<String?> iconUrl = const Value.absent(),
            Value<String?> rating = const Value.absent(),
            Value<String?> episodeNum = const Value.absent(),
            Value<String?> sourceUrl = const Value.absent(),
          }) =>
              EpgProgramsTableCompanion.insert(
            id: id,
            channelId: channelId,
            start: start,
            stop: stop,
            title: title,
            description: description,
            category: category,
            iconUrl: iconUrl,
            rating: rating,
            episodeNum: episodeNum,
            sourceUrl: sourceUrl,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$EpgProgramsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $EpgProgramsTableTable,
    EpgProgramsTableData,
    $$EpgProgramsTableTableFilterComposer,
    $$EpgProgramsTableTableOrderingComposer,
    $$EpgProgramsTableTableAnnotationComposer,
    $$EpgProgramsTableTableCreateCompanionBuilder,
    $$EpgProgramsTableTableUpdateCompanionBuilder,
    (
      EpgProgramsTableData,
      BaseReferences<_$AppDatabase, $EpgProgramsTableTable,
          EpgProgramsTableData>
    ),
    EpgProgramsTableData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PlaylistsTableTableTableManager get playlistsTable =>
      $$PlaylistsTableTableTableManager(_db, _db.playlistsTable);
  $$CategoriesTableTableTableManager get categoriesTable =>
      $$CategoriesTableTableTableManager(_db, _db.categoriesTable);
  $$ContentItemsTableTableTableManager get contentItemsTable =>
      $$ContentItemsTableTableTableManager(_db, _db.contentItemsTable);
  $$FavoritesTableTableTableManager get favoritesTable =>
      $$FavoritesTableTableTableManager(_db, _db.favoritesTable);
  $$RecentlyViewedTableTableTableManager get recentlyViewedTable =>
      $$RecentlyViewedTableTableTableManager(_db, _db.recentlyViewedTable);
  $$PlaybackPositionsTableTableTableManager get playbackPositionsTable =>
      $$PlaybackPositionsTableTableTableManager(
          _db, _db.playbackPositionsTable);
  $$EpgChannelsTableTableTableManager get epgChannelsTable =>
      $$EpgChannelsTableTableTableManager(_db, _db.epgChannelsTable);
  $$EpgProgramsTableTableTableManager get epgProgramsTable =>
      $$EpgProgramsTableTableTableManager(_db, _db.epgProgramsTable);
}
