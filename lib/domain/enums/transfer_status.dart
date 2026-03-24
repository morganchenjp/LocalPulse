enum TransferStatus {
  pending,
  transferring,
  completed,
  failed,
  cancelled;

  static TransferStatus fromString(String value) {
    return TransferStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TransferStatus.pending,
    );
  }
}
