import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// مزوّد قاعدة البيانات المحلية — يُفتح بأول استعلام (كسول) وقفل عند التخلص.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
