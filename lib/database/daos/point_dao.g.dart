// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'point_dao.dart';

// ignore_for_file: type=lint
mixin _$PointDaoMixin on DatabaseAccessor<AppDatabase> {
  $ReportTemplatesTable get reportTemplates => attachedDatabase.reportTemplates;
  $ClientsTable get clients => attachedDatabase.clients;
  $ProjectsTable get projects => attachedDatabase.projects;
  $ProfilesTable get profiles => attachedDatabase.profiles;
  $PointsTable get points => attachedDatabase.points;
  $PhotosTable get photos => attachedDatabase.photos;
  $MaterialsTable get materials => attachedDatabase.materials;
  $PointMaterialsTable get pointMaterials => attachedDatabase.pointMaterials;
  PointDaoManager get managers => PointDaoManager(this);
}

class PointDaoManager {
  final _$PointDaoMixin _db;
  PointDaoManager(this._db);
  $$ReportTemplatesTableTableManager get reportTemplates =>
      $$ReportTemplatesTableTableManager(
          _db.attachedDatabase, _db.reportTemplates);
  $$ClientsTableTableManager get clients =>
      $$ClientsTableTableManager(_db.attachedDatabase, _db.clients);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db.attachedDatabase, _db.projects);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db.attachedDatabase, _db.profiles);
  $$PointsTableTableManager get points =>
      $$PointsTableTableManager(_db.attachedDatabase, _db.points);
  $$PhotosTableTableManager get photos =>
      $$PhotosTableTableManager(_db.attachedDatabase, _db.photos);
  $$MaterialsTableTableManager get materials =>
      $$MaterialsTableTableManager(_db.attachedDatabase, _db.materials);
  $$PointMaterialsTableTableManager get pointMaterials =>
      $$PointMaterialsTableTableManager(
          _db.attachedDatabase, _db.pointMaterials);
}
