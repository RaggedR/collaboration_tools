import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Displays a file preview based on its URL extension.
///
/// - Images (png, jpg, gif, webp, svg): rendered inline
/// - PDFs: "Open PDF" button
/// - Other: clickable link
class FileViewer extends StatelessWidget {
  final String url;
  final String baseUrl;

  const FileViewer({
    super.key,
    required this.url,
    this.baseUrl = 'http://localhost:8080',
  });

  String get _fullUrl => url.startsWith('http') ? url : '$baseUrl$url';
  String get _extension => url.split('.').last.toLowerCase();

  bool get _isImage =>
      {'png', 'jpg', 'jpeg', 'gif', 'webp', 'svg'}.contains(_extension);

  bool get _isPdf => _extension == 'pdf';

  @override
  Widget build(BuildContext context) {
    if (_isImage) return _buildImageViewer(context);
    if (_isPdf) return _buildPdfButton(context);
    return _buildLink(context);
  }

  Widget _buildImageViewer(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Image.network(
          _fullUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, error, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image,
                    size: 48,
                    color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 8),
                Text('Failed to load image',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPdfButton(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.picture_as_pdf),
      label: const Text('Open PDF'),
      onPressed: () {
        launchUrl(Uri.parse(_fullUrl), mode: LaunchMode.externalApplication);
      },
    );
  }

  Widget _buildLink(BuildContext context) {
    return InkWell(
      onTap: () {
        launchUrl(Uri.parse(_fullUrl), mode: LaunchMode.externalApplication);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.open_in_new, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              url,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
