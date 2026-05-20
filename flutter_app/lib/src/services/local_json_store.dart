import 'dart:io';

class LocalJsonStore {
  const LocalJsonStore(this.fileName);

  final String fileName;

  Future<File> file() async {
    final Directory directory =
        Directory('${Directory.current.path}${Platform.pathSeparator}data');

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }
}
