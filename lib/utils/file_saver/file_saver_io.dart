import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'file_saver_platform.dart';

class FileSaverIO implements FileSaverPlatform {
  @override
  Future<String> saveAndLaunch({
    required List<int> bytes,
    required String fileName,
  }) async {
    String downloadsPath;
    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        downloadsPath = downloadsDir.path;
      } else if (Platform.isWindows) {
        final userProfile =
            Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Default';
        downloadsPath = '$userProfile\\Downloads';
      } else {
        final docsDir = await getApplicationDocumentsDirectory();
        downloadsPath = docsDir.path;
      }
    } catch (_) {
      if (Platform.isWindows) {
        final userProfile =
            Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Default';
        downloadsPath = '$userProfile\\Downloads';
      } else {
        downloadsPath = '.';
      }
    }

    final dir = Directory(downloadsPath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final fullPath = '$downloadsPath${Platform.pathSeparator}$fileName';
    final file = File(fullPath);
    await file.writeAsBytes(bytes, flush: true);

    if (Platform.isWindows) {
      try {
        await Process.run('explorer.exe', ['/select,', fullPath]);
        return fullPath;
      } catch (_) {}
    }

    try {
      await launchUrl(Uri.file(fullPath));
    } catch (_) {}

    return fullPath;
  }
}

FileSaverPlatform getFileSaver() => FileSaverIO();
