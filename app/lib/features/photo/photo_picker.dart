import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

enum PhotoSource { camera, gallery }

/// La foto elegida o `null` si se canceló. Lanza [PhotoPermissionDenied] sin permiso de cámara.
abstract class PhotoPicker {
  Future<String?> pick(PhotoSource source);
}

class PhotoPermissionDenied implements Exception {
  const PhotoPermissionDenied();
}

/// `image_picker` con la foto ya reducida a 1024 px y JPEG al 80 % (research R14).
class ImagePickerPhotoPicker implements PhotoPicker {
  final _picker = ImagePicker();

  @override
  Future<String?> pick(PhotoSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      return file?.path;
    } on Exception catch (e) {
      if (source == PhotoSource.camera && '$e'.contains('access_denied')) {
        throw const PhotoPermissionDenied();
      }
      rethrow;
    }
  }
}

final photoPickerProvider = Provider<PhotoPicker>(
  (ref) => ImagePickerPhotoPicker(),
);
