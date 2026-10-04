import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/l10n/app_strings.dart';

/// معطيات عارض PDF (تُمرَّر عبر Route arguments).
class PdfViewerArgs {
  const PdfViewerArgs({required this.path, required this.title});

  final String path;
  final String title;
}

/// عارض PDF داخلي (PdfRenderer أصلي — بلا WebView) للملفات المُنزَّلة.
class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({super.key, required this.args});

  final PdfViewerArgs args;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  int _pages = 0;
  int _current = 0;
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.args.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_pages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  '${_current + 1}/$_pages',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
        ],
      ),
      body: _failed
          ? _Fallback(path: widget.args.path)
          : PDFView(
              filePath: widget.args.path,
              enableSwipe: true,
              swipeHorizontal: false,
              autoSpacing: true,
              pageFling: true,
              pageSnap: true,
              fitPolicy: FitPolicy.WIDTH,
              onRender: (pages) {
                if (!mounted) return;
                setState(() => _pages = pages ?? 0);
              },
              onPageChanged: (page, total) {
                if (!mounted) return;
                setState(() => _current = page ?? 0);
              },
              onError: (_) {
                if (!mounted) return;
                setState(() => _failed = true);
              },
            ),
    );
  }
}

/// بديل عند تعذّر العرض الداخلي: فتح بالتطبيق النظامي.
class _Fallback extends StatelessWidget {
  const _Fallback({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf_outlined, size: 56),
            const SizedBox(height: 12),
            const Text(AppStrings.error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => OpenFilex.open(path),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text(AppStrings.openFile),
            ),
          ],
        ),
      ),
    );
  }
}
