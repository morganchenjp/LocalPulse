import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/peers_table.dart';
import 'tables/messages_table.dart';
import 'tables/transfers_table.dart';
import 'daos/peer_dao.dart';
import 'daos/message_dao.dart';
import 'daos/transfer_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Peers, Messages, FileTransfers], daos: [PeerDao, MessageDao, TransferDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(_openConnection());

  static AppDatabase? _instance;
  static AppDatabase get instance {
    _instance ??= AppDatabase._();
    return _instance!;
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationSupportDirectory();
    final file = File(p.join(dbFolder.path, 'lanshare.db'));
    return NativeDatabase.createInBackground(file);
  });
}
