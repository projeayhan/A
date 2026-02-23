import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'supabase_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return StorageService(supabase);
});

class StorageService {
  final SupabaseClient _supabase;

  StorageService(this._supabase);

  /// Pick an image file (PNG/JPG/WEBP, max 5MB)
  Future<({Uint8List bytes, String name})?> pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: false,
      );
      if (result != null && result.files.single.bytes != null) {
        final file = result.files.single;
        if (file.size > 5 * 1024 * 1024) {
          throw Exception('Dosya boyutu 5MB\'dan büyük olamaz');
        }
        return (bytes: file.bytes!, name: file.name);
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('File pick error: $e');
      rethrow;
    }
  }

  /// Upload image to Supabase Storage
  Future<String> uploadImage(String folder, Uint8List bytes, String fileName) async {
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = '$folder/${DateTime.now().millisecondsSinceEpoch}_$safeName';

    await _supabase.storage.from('images').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(cacheControl: '31536000', upsert: true),
    );

    return _supabase.storage.from('images').getPublicUrl(path);
  }

  /// Delete image from Supabase Storage
  Future<void> deleteImage(String publicUrl) async {
    try {
      // Extract path from public URL
      final uri = Uri.parse(publicUrl);
      final segments = uri.pathSegments;
      final storageIndex = segments.indexOf('images');
      if (storageIndex >= 0 && storageIndex < segments.length - 1) {
        final path = segments.sublist(storageIndex + 1).join('/');
        await _supabase.storage.from('images').remove([path]);
      }
    } catch (e) {
      if (kDebugMode) print('Image delete error: $e');
    }
  }
}
