import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/network/connectivity.dart';
import '../../../core/network/content_source.dart';
import '../../../core/security/security_providers.dart';
import '../../accounts/application/accounts_providers.dart';
import 'sync_engine.dart';
import 'sync_providers.dart';

/// مرحلة المزامنة الحالية (للواجهة).
enum SyncPhase { idle, syncing, error }

/// حالة المزامنة العامة للتطبيق.
class SyncState {
  const SyncState({
    this.phase = SyncPhase.idle,
    this.lastSyncedAt,
    this.lastError,
  });

  final SyncPhase phase;
  final DateTime? lastSyncedAt;
  final String? lastError;

  bool get isSyncing => phase == SyncPhase.syncing;

  SyncState copyWith({
    SyncPhase? phase,
    DateTime? lastSyncedAt,
    String? lastError,
    bool clearError = false,
  }) {
    return SyncState(
      phase: phase ?? this.phase,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

/// متحكّم المزامنة:
/// • مزامنة يدوية (سحب/زر) وعند عودة الإنترنت تلقائياً.
/// • ترتيب ثابت: رفع الطابور أولاً ثم جلب المحتوى.
/// • لا تشغيلان متزامنان أبداً (_running يمنع التداخل).
final syncControllerProvider =
    NotifierProvider<SyncController, SyncState>(SyncController.new);

class SyncController extends Notifier<SyncState> {
  bool _running = false;
  bool _disposed = false;

  @override
  SyncState build() {
    // عودة الشبكة → مزامنة تلقائية صامتة (البيانات المحلية معروضة أصلاً).
    // onError مطلوب: في بيئة الاختبار قد يرمي بثّ القنوات أخطاء منصة.
    final sub = ref.read(connectivityServiceProvider).onConnectivityChanged.listen(
          _onConnectivity,
          onError: (Object _) {},
        );
    ref.onDispose(() {
      _disposed = true;
      sub.cancel();
    });

    // مزامنة أولى هادئة عند الإقلاع إن كان هناك إنترنت (لا تؤخر الواجهة).
    Future<void>(() async {
      if (_disposed) return;
      final online = await checkOnlineNow(ref.read(connectivityServiceProvider));
      if (online && !_disposed) await syncNow();
    });
    return const SyncState();
  }

  Future<void> _onConnectivity(List<ConnectivityResult> results) async {
    if (_disposed) return;
    if (isOnlineResults(results)) await syncNow();
  }

  /// مزامنة واحدة كاملة (طابور + محتوى) للحساب النشط.
  Future<void> syncNow() async {
    if (_running || _disposed) return;
    final account = ref.read(activeAccountProvider);
    if (account == null) return;

    // القفل قبل أي await يمنع تشغيلين متزامنين (يدوي + عودة شبكة).
    _running = true;
    state = state.copyWith(phase: SyncPhase.syncing, clearError: true);
    try {
      final online =
          await checkOnlineNow(ref.read(connectivityServiceProvider));
      if (_disposed) return;
      if (!online) {
        state = state.copyWith(
          phase: SyncPhase.error,
          lastError: AppStrings.networkError,
        );
        return;
      }

      try {
        final session = await createSession(
          tokenStore: ref.read(secureTokenStoreProvider),
          account: account,
        );
        final source = ref.read(contentSourceFactoryProvider)(account);
        final engine = SyncEngine(
          db: ref.read(databaseProvider),
          source: source,
        );

        // أولاً: رفع أي إجابات محفوظة محلياً أثناء عدم الاتصال.
        await engine.processQueue(account, session);

        final result = await engine.syncAccount(account, session);
        if (_disposed) return;
        if (result.ok) {
          await ref.read(accountsProvider.notifier).markSynced(account.id);
          state = SyncState(
            phase: SyncPhase.idle,
            lastSyncedAt: DateTime.now(),
          );
        } else if (result.offline) {
          // انقطعت الشبكة أثناء التنفيذ — نعود للوضع الهادئ بلا خطأ عريض.
          state = state.copyWith(phase: SyncPhase.idle, clearError: true);
        } else {
          state = state.copyWith(
            phase: SyncPhase.error,
            lastError: result.error ?? AppStrings.syncFailed,
          );
        }
      } on MoodleSourceException catch (e) {
        if (_disposed) return;
        state = state.copyWith(
          phase: e.isNetwork ? SyncPhase.idle : SyncPhase.error,
          lastError: e.message,
          clearError: e.isNetwork,
        );
      } catch (e) {
        if (_disposed) return;
        state = state.copyWith(
          phase: SyncPhase.error,
          lastError: AppStrings.syncFailed,
        );
        // تفاصيل الفشل تُطبع للتشخيص فقط.
        // ignore: avoid_print
        print('sync error: $e');
      }
    } finally {
      _running = false;
    }
  }
}
