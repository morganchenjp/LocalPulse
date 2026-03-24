import 'package:drift/drift.dart';

class Peers extends Table {
  TextColumn get id => text()();
  TextColumn get deviceName => text()();
  TextColumn get os => text()();
  TextColumn get ipAddress => text().nullable()();
  IntColumn get port => integer().nullable()();
  BoolColumn get isOnline => boolean().withDefault(const Constant(false))();
  IntColumn get lastSeenAt => integer().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
