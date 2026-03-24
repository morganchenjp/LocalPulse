import 'package:drift/drift.dart';

class FileTransfers extends Table {
  TextColumn get id => text()();
  TextColumn get messageId => text().nullable()();
  TextColumn get peerId => text()();
  TextColumn get fileName => text()();
  TextColumn get filePath => text().nullable()();
  IntColumn get fileSize => integer()();
  IntColumn get bytesTransferred => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get checksum => text().nullable()();
  BoolColumn get isOutgoing => boolean()();
  IntColumn get createdAt => integer()();
  IntColumn get completedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
