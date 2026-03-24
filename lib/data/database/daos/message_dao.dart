import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/messages_table.dart';

part 'message_dao.g.dart';

@DriftAccessor(tables: [Messages])
class MessageDao extends DatabaseAccessor<AppDatabase> with _$MessageDaoMixin {
  MessageDao(super.db);

  Stream<List<Message>> watchMessagesForPeer(String peerId) {
    return (select(messages)
          ..where((t) => t.peerId.equals(peerId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Future<List<Message>> getMessagesForPeer(String peerId, {int limit = 50, int offset = 0}) {
    return (select(messages)
          ..where((t) => t.peerId.equals(peerId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit, offset: offset))
        .get();
  }

  Future<void> insertMessage(MessagesCompanion message) =>
      into(messages).insert(message);

  Future<void> updateMessageStatus(String id, String status) {
    return (update(messages)..where((t) => t.id.equals(id)))
        .write(MessagesCompanion(status: Value(status)));
  }
}
