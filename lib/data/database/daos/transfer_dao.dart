import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/transfers_table.dart';

part 'transfer_dao.g.dart';

@DriftAccessor(tables: [FileTransfers])
class TransferDao extends DatabaseAccessor<AppDatabase> with _$TransferDaoMixin {
  TransferDao(super.db);

  Stream<List<FileTransfer>> watchActiveTransfers() {
    return (select(fileTransfers)
          ..where((t) => t.status.isIn(['pending', 'transferring']))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<FileTransfer?> getTransfer(String id) {
    return (select(fileTransfers)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Stream<FileTransfer?> watchTransfer(String id) {
    return (select(fileTransfers)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<void> insertTransfer(FileTransfersCompanion transfer) =>
      into(fileTransfers).insert(transfer);

  Future<void> updateProgress(String id, int bytesTransferred) {
    return (update(fileTransfers)..where((t) => t.id.equals(id)))
        .write(FileTransfersCompanion(bytesTransferred: Value(bytesTransferred)));
  }

  Future<void> updateStatus(String id, String status, {String? filePath}) {
    final companion = FileTransfersCompanion(
      status: Value(status),
      filePath: filePath != null ? Value(filePath) : const Value.absent(),
      completedAt: status == 'completed' || status == 'failed' || status == 'cancelled'
          ? Value(DateTime.now().millisecondsSinceEpoch)
          : const Value.absent(),
    );
    return (update(fileTransfers)..where((t) => t.id.equals(id)))
        .write(companion);
  }
}
