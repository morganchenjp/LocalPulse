class AppConstants {
  AppConstants._();

  static const String appName = 'LANShare';
  static const String version = '1.0.0';
  static const int protocolVersion = 1;

  static const int defaultPortMin = 53100;
  static const int defaultPortMax = 53200;

  static const String serviceType = '_lanshare._tcp';

  static const int maxConcurrentTransfers = 3;
  static const int fileChunkSize = 4 * 1024 * 1024; // 4MB

  static const int clipboardPollIntervalMs = 2000;

  static const double minWindowWidth = 1024;
  static const double minWindowHeight = 640;
  static const double defaultWindowWidth = 1280;
  static const double defaultWindowHeight = 800;
}
