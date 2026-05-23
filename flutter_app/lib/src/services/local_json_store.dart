import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LocalJsonStore {
  const LocalJsonStore(this.fileName);

  final String fileName;

  Future<File> file() async {
    final Directory directory = await _baseDirectory();

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  Future<Directory> _baseDirectory() async {
    try {
      final Directory supportDirectory = await getApplicationSupportDirectory();
      return Directory(
        '${supportDirectory.path}${Platform.pathSeparator}streamed',
      );
    } catch (_) {
      return Directory(
          '${Directory.current.path}${Platform.pathSeparator}data');
    }
  }
}
