class ProtocolConstants {
  ProtocolConstants._();

  static const String apiPrefix = '/api/v1';
  static const String infoPath = '$apiPrefix/info';
  static const String messagePath = '$apiPrefix/message';
  static const String filePreparePath = '$apiPrefix/file/prepare';
  static const String fileUploadPath = '$apiPrefix/file/upload';
  static const String fileTransferPath = '$apiPrefix/file/transfer';
  static const String clipboardPath = '$apiPrefix/clipboard';
}
