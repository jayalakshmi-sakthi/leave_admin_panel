import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';

/// A utility to save or download files across Web, Android, and iOS.
class UniversalFileSaver {
  /// Saves file bytes and handles platform-specific download/sharing.
  static Future<void> saveFile({
    required List<int> bytes,
    required String fileName,
  }) async {
    if (kIsWeb) {
      // Handle Web Download
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: fileName,
      );
    } else {
      // Handle Mobile Save/Share
      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/$fileName";
      final file = File(path);
      await file.writeAsBytes(bytes);
      
      // Share/Open on Mobile
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: fileName,
      );
    }
  }
}
