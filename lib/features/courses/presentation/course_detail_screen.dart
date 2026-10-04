import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/daos.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/url_utils.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../dashboard/presentation/main_shell.dart';
import '../data/file_download_service.dart';
import 'pdf_viewer_screen.dart';

/// معطيات شاشة تفاصيل المقرر (تُمرَّر عبر Route arguments).
class CourseDetailArgs {
  const CourseDetailArgs({required this.id, required this.title});

  /// معرّف المقرر (id المركّب accountId:moodleId).
  final String id;
  final String title;
}

/// شاشة تفاصيل مقرر: أقسامه ووحداته من القاعدة مباشرة (Offline-First).
class CourseDetailScreen extends ConsumerWidget {
  const CourseDetailScreen({super.key, required this.args});

  final CourseDetailArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(activeAccountProvider);
    if (account == null) return const SizedBox.shrink();
    final daos = ref.watch(daosProvider);
    final baseUrl = UrlUtils.normalizeServerUrl(account.serverUrl);

    return Scaffold(
      appBar: AppBar(
        title: Text(args.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: StreamBuilder<List<CourseSection>>(
        stream: daos.content.watchSections(account.id, args.id),
        builder: (context, snap) {
          if (snap.hasError) {
            return const TabEmpty(
              icon: Icons.error_outline_rounded,
              title: AppStrings.error,
              message: 'تعذّر قراءة أقسام المقرر المحفوظة',
            );
          }
          final sections = (snap.data ?? const <CourseSection>[])
              .where((s) => s.visible)
              .toList();
          if (sections.isEmpty) {
            return const TabEmpty(
              icon: Icons.menu_book_outlined,
              title: AppStrings.noResults,
              message: 'ستظهر أقسام المقرر ووحداته بعد المزامنة الأولى.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: sections.length,
            itemBuilder: (context, i) => _SectionBlock(
              daos: daos,
              accountId: account.id,
              baseUrl: baseUrl,
              section: sections[i],
            ),
          );
        },
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.daos,
    required this.accountId,
    required this.baseUrl,
    required this.section,
  });

  final Daos daos;
  final String accountId;
  final String baseUrl;
  final CourseSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = section.title.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        StreamBuilder<List<CourseModule>>(
          stream: daos.content.watchModules(accountId, section.id),
          builder: (context, snap) {
            if (snap.hasError) return const SizedBox.shrink();
            final modules = snap.data ?? const <CourseModule>[];
            if (modules.isEmpty) return const SizedBox.shrink();
            return Column(
              children: [
                for (final module in modules)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: _ModuleTile(
                      accountId: accountId,
                      baseUrl: baseUrl,
                      module: module,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ModuleTile extends ConsumerStatefulWidget {
  const _ModuleTile({
    required this.accountId,
    required this.baseUrl,
    required this.module,
  });

  final String accountId;
  final String baseUrl;
  final CourseModule module;

  @override
  ConsumerState<_ModuleTile> createState() => _ModuleTileState();
}

class _ModuleTileState extends ConsumerState<_ModuleTile> {
  bool _busy = false;

  CourseModule get _m => widget.module;

  IconData get _icon {
    switch (_m.modType) {
      case 'assign':
        return Icons.assignment_outlined;
      case 'url':
        return Icons.link_rounded;
      case 'page':
        return Icons.article_outlined;
      case 'forum':
        return Icons.forum_outlined;
      case 'label':
        return Icons.label_important_outline_rounded;
      case 'quiz':
        return Icons.help_outline_rounded;
      default:
        return Icons.description_outlined;
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _handleTap() async {
    if (_busy) return;
    // ملف محفوظ محلياً ← فتح فوري (PDF داخلي أو تطبيق النظام).
    final local = (_m.localPath ?? '').trim();
    if (_m.isDownloaded && local.isNotEmpty) {
      _openLocal(local);
      return;
    }
    // ملف بعدٌ ← تنزيل ثم فتح.
    if ((_m.fileUrl ?? '').trim().isNotEmpty) {
      await _downloadThenOpen();
      return;
    }
    // رابط خارجي (وحدة url) ← فتح بالمتصفح.
    final url = (_m.externalUrl ?? '').trim();
    if (url.isNotEmpty) {
      await _openExternal(url);
    }
  }

  Future<void> _downloadThenOpen() async {
    setState(() => _busy = true);
    try {
      final path = await ref.read(fileDownloadServiceProvider).downloadModule(
            accountId: widget.accountId,
            module: _m,
            baseUrl: widget.baseUrl,
          );
      _snack(AppStrings.savedOffline);
      _openLocal(path);
    } catch (_) {
      _snack(AppStrings.downloadFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openLocal(String path) {
    if (path.toLowerCase().endsWith('.pdf')) {
      Navigator.of(context).pushNamed(
        AppRoutes.pdfViewer,
        args: PdfViewerArgs(path: path, title: _m.name),
      );
      return;
    }
    _openExternal(path);
  }

  Future<void> _openExternal(String target) async {
    try {
      final result = await OpenFilex.open(target);
      if (result.type != OpenResultType.done) _snack(AppStrings.error);
    } catch (_) {
      _snack(AppStrings.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = _m.filename ?? _m.intro;
    final hasAction =
        _m.isDownloaded || (_m.fileUrl ?? '').isNotEmpty || (_m.externalUrl ?? '').isNotEmpty;

    return ListTile(
      onTap: hasAction ? _handleTap : null,
      leading: CircleAvatar(
        backgroundColor: AppColors.primarySurface,
        child: Icon(_icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        _m.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle.trim().isEmpty
          ? null
          : Text(
              subtitle.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : _m.isDownloaded
              ? const Icon(
                  Icons.download_done_rounded,
                  size: 20,
                  color: AppColors.primary,
                )
              : (!(_m.available)
                  ? Icon(
                      Icons.visibility_off_outlined,
                      size: 20,
                      color: theme.colorScheme.outline,
                    )
                  : ((_m.fileUrl ?? '').isNotEmpty
                      ? Icon(
                          Icons.download_outlined,
                          size: 20,
                          color: theme.colorScheme.outline,
                        )
                      : null)),
    );
  }
}
