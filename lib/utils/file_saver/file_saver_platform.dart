abstract class FileSaverPlatform {
  Future<String> saveAndLaunch({
    required List<int> bytes,
    required String fileName,
  });
}
