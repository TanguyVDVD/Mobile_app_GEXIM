// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'point_dao.dart';

// ignore_for_file: type=lint
mixin _$PointDaoMixin on DatabaseAccessor<AppDatabase> {
  $ClientsTable get clients => attachedDatabase.clients;
  $ProjectsTable get projects => attachedDatabase.projects;
  $SettingOptionsTable get settingOptions => attachedDatabase.settingOptions;
  $ProfilesTable get profiles => attachedDatabase.profiles;
  $PointsTable get points => attachedDatabase.points;
  $PhotosTable get photos => attachedDatabase.photos;
  PointDaoManager get managers => PointDaoManager(this);
}

class PointDaoManager {
  final _$PointDaoMixin _db;
  PointDaoManager(this._db);
  $$ClientsTableTableManager get clients =>
      $$ClientsTableTableManager(_db.attachedDatabase, _db.clients);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db.attachedDatabase, _db.projects);
  $$SettingOptionsTableTableManager get settingOptions =>
      $$SettingOptionsTableTableManager(
          _db.attachedDatabase, _db.settingOptions);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db.attachedDatabase, _db.profiles);
  $$PointsTableTableManager get points =>
      $$PointsTableTableManager(_db.attachedDatabase, _db.points);
  $$PhotosTableTableManager get photos =>
      $$PhotosTableTableManager(_db.attachedDatabase, _db.photos);
}
