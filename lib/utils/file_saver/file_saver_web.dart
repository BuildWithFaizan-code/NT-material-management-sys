// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'file_saver_platform.dart';

class FileSaverWeb implements FileSaverPlatform {
  @override
  Future<String> saveAndLaunch({
    required List<int> bytes,
    required String fileName,
  }) async {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = fileName;
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
    return fileName;
  }
}

FileSaverPlatform getFileSaver() => FileSaverWeb();
