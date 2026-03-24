enum PeerStatus {
  online,
  offline;

  static PeerStatus fromString(String value) {
    return PeerStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PeerStatus.offline,
    );
  }
}
