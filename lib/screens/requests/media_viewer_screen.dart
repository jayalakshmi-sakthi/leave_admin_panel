import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class MediaViewerScreen extends StatelessWidget {
  final String url;
  final String title;

  const MediaViewerScreen({
    super.key,
    required this.url,
    this.title = "View Attachment",
  });

  bool get _isPdf => url.toLowerCase().contains(".pdf") || url.toLowerCase().contains("/raw/upload/");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Better for viewing media
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: () {
               // Fallback to browser for download/share if needed
               // But usually PDF viewer has its own toolbar
            },
          )
        ],
      ),
      body: Center(
        child: _isPdf
            ? SfPdfViewer.network(
                url,
                enableDoubleTapZooming: true,
                onDocumentLoadFailed: (details) {
                   debugPrint("PDF Load Failed: ${details.description}");
                },
              )
            : InteractiveViewer(
                child: Image.network(
                  url,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.white, size: 48),
                        SizedBox(height: 12),
                        Text("Failed to load image", style: TextStyle(color: Colors.white)),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }
}
