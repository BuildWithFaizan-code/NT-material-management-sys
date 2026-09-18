import 'file_saver/file_saver_stub.dart'
    if (dart.library.io) 'file_saver/file_saver_io.dart'
    if (dart.library.html) 'file_saver/file_saver_web.dart';

class FileExportHelper {
  /// Saves bytes to disk (on Desktop/Mobile) or downloads via browser (on Web),
  /// and opens or highlights the exported file.
  static Future<String> saveAndLaunchFile({
    required List<int> bytes,
    required String fileName,
  }) {
    final saver = getFileSaver();
    return saver.saveAndLaunch(bytes: bytes, fileName: fileName);
  }
}
