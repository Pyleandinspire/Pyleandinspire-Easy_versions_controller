import 'package:file_picker/file_picker.dart';

class FilePickerService {
  Future<List<String>> pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null) {
      return result.files
          .where((file) => file.path != null)
          .map((file) => file.path!)
          .toList();
    }

    return [];
  }
}
