import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/peers_table.dart';

part 'peer_dao.g.dart';

@DriftAccessor(tables: [Peers])
class PeerDao extends DatabaseAccessor<AppDatabase> with _$PeerDaoMixin {
  PeerDao(super.db);

  Future<List<Peer>> getAllPeers() => select(peers).get();

  Stream<List<Peer>> watchAllPeers() {
    return (select(peers)
          ..orderBy([
            (t) => OrderingTerm(expression: t.isOnline, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.lastSeenAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<Peer?> getPeerById(String id) =>
      (select(peers)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertPeer(PeersCompanion peer) =>
      into(peers).insertOnConflictUpdate(peer);

  Future<void> setOnlineStatus(String id, bool online) {
    return (update(peers)..where((t) => t.id.equals(id))).write(
      PeersCompanion(
        isOnline: Value(online),
        lastSeenAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> setAllOffline() {
    return update(peers).write(
      const PeersCompanion(isOnline: Value(false)),
    );
  }
}
