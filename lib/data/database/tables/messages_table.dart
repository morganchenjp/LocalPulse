import 'package:drift/drift.dart';

class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get peerId => text()();
  TextColumn get type => text()(); // text, file, clipboard
  TextColumn get content => text().nullable()();
  BoolColumn get isOutgoing => boolean()();
  TextColumn get status => text().withDefault(const Constant('sent'))();
  TextColumn get metadata => text().nullable()(); // JSON
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
