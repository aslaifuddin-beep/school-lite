import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates_ar.dart';
import '../../../core/utils/html_text.dart';
import '../../sync/application/sync_controller.dart';
import '../../sync/application/sync_providers.dart';
import '../domain/assignment_urgency.dart';

/// يفتح ورقة تسليم الواجب (نص + مرفقات) — الحفظ في الطابور أولاً
/// ثم محاولة رفع فورية عبر المزامنة إن توفرت الشبكة.
Future<void> showAssignmentSheet(
  BuildContext context,
  Assignment assignment,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AssignmentSheet(assignment: assignment),
  );
}

class _AssignmentSheet extends ConsumerStatefulWidget {
  const _AssignmentSheet({required this.assignment});

  final Assignment assignment;

  @override
  ConsumerState<_AssignmentSheet> createState() => _AssignmentSheetState();
}

class _AssignmentSheetState extends ConsumerState<_AssignmentSheet> {
  late final TextEditingController _answer;
  final List<String> _files = <String>[];
  bool _saving = false;

  Assignment get _a => widget.assignment;

  @override
  void initState() {
    super.initState();
    _answer = TextEditingController(text: _a.onlineText ?? '');
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null) return;
      for (final f in result.files) {
        final path = f.path;
        if (path != null && path.isNotEmpty && !_files.contains(path)) {
          _files.add(path);
        }
      }
      setState(() {});
    } catch (_) {
      _snack(AppStrings.pickFileFailed);
    }
  }

  Future<void> _submit() async {
    final text = _answer.text.trim();
    if (text.isEmpty && _files.isEmpty) {
      _snack(AppStrings.answerRequired);
      return;
    }
    setState(() => _saving = true);
    final service = ref.read(submissionServiceProvider);
    final sync = ref.read(syncControllerProvider.notifier);
    try {
      if (_files.isNotEmpty) {
        await service.saveFileSubmission(
          accountId: _a.accountId,
          assignmentMoodleId: _a.moodleId,
          filePaths: List.of(_files),
          text: text.isEmpty ? null : text,
        );
      } else {
        await service.saveTextSubmission(
          accountId: _a.accountId,
          assignmentMoodleId: _a.moodleId,
          text: text,
        );
      }
      if (!mounted) return;

      // نلتقط messenger قبل الإغلاق (context يصبح غير صالح بعده).
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.queuedForSync)),
      );

      // محاولة رفع فوري إن توفرت الشبكة (الطابور يبقى للأمان).
      try {
        await sync.syncNow();
      } catch (_) {
        // فشل المزامنة لا يُلغي نجاح الحفظ في الطابور.
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _snack(AppStrings.error);
      }
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urgency = classifyAssignment(_a);
    final intro = HtmlText.strip(_a.intro);

    return Padding(
      // رفع الورقة فوق لوحة المفاتيح.
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_a.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_a.dueAt != null)
                  Text(
                    '${AppStrings.dueDate}: ${DatesAr.formatDateTime(_a.dueAt!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                _UrgencyChip(urgency: urgency, pending: _a.pendingSync),
              ],
            ),
            if (intro.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                intro,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (_a.gradeText != null && _a.gradeText!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${AppStrings.gradeLabel}: ${_a.gradeText}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _answer,
              maxLines: 5,
              minLines: 3,
              enabled: !_saving,
              decoration: InputDecoration(
                labelText: AppStrings.answer,
                hintText: AppStrings.draftAnswer,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickFiles,
              icon: const Icon(Icons.attach_file_rounded),
              label: const Text(AppStrings.attachFile),
            ),
            if (_files.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final path in _files)
                    Chip(
                      avatar: const Icon(Icons.insert_drive_file_rounded,
                          size: 18),
                      label: Text(
                        path.split(RegExp(r'[\\/]/')).last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onDeleted:
                          _saving ? null : () => setState(() => _files.remove(path)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(
                _saving ? AppStrings.loading : AppStrings.submitOffline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UrgencyChip extends StatelessWidget {
  const _UrgencyChip({required this.urgency, required this.pending});

  final AssignmentUrgency urgency;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    if (pending) {
      return const _SmallChip(text: AppStrings.pendingSync, danger: false);
    }
    switch (urgency) {
      case AssignmentUrgency.done:
        return const _SmallChip(text: AppStrings.submitted, done: true);
      case AssignmentUrgency.overdue:
        return const _SmallChip(text: AppStrings.overdue, danger: true);
      case AssignmentUrgency.dueSoon:
        return const _SmallChip(text: AppStrings.dueSoonLabel, danger: true);
      case AssignmentUrgency.upcoming:
      case AssignmentUrgency.noDate:
        return const SizedBox.shrink();
    }
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({
    required this.text,
    this.danger = false,
    this.done = false,
  });

  final String text;
  final bool danger;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (done) {
      bg = Colors.green.withValues(alpha: 0.14);
      fg = Colors.green.shade800;
    } else if (danger) {
      bg = Colors.red.withValues(alpha: 0.12);
      fg = Colors.red.shade800;
    } else {
      bg = Colors.orange.withValues(alpha: 0.14);
      fg = Colors.orange.shade900;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11.5, color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}
