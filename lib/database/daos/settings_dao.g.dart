// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_dao.dart';

// ignore_for_file: type=lint
mixin _$SettingsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SettingOptionsTable get settingOptions => attachedDatabase.settingOptions;
  SettingsDaoManager get managers => SettingsDaoManager(this);
}

class SettingsDaoManager {
  final _$SettingsDaoMixin _db;
  SettingsDaoManager(this._db);
  $$SettingOptionsTableTableManager get settingOptions =>
      $$SettingOptionsTableTableManager(
          _db.attachedDatabase, _db.settingOptions);
}
