import 'package:flutter/material.dart';

/// [StreamBuilder] يُبقي هوية الـ stream ثابتة بين الإطارات.
///
/// استدعاء `StreamBuilder(stream: dao.watch…)` مباشرة داخل `build` يُنشئ
/// stream جديداً في كل إطار، فيُلغي StreamBuilder اشتراكه القديم ويشترك
/// بالجديد بلا نهاية (إعادة بناء لا نهائية تمنع `pumpAndSettle` من
/// الاستقرار). هذا الودجت يُخزّن الـ stream ويعيد إنشائه فقط عند تغيّر
/// [cacheKey] (مثل تبديل الحساب).
class CachedStreamBuilder<T> extends StatefulWidget {
  const CachedStreamBuilder({
    super.key,
    required this.cacheKey,
    required this.create,
    required this.builder,
  });

  /// مفتاح يمثّل مُدخلات الاستعلام؛ عند تغيّره يعاد إنشاء الـ stream.
  final Object cacheKey;

  /// يُستدعى مرة واحدة لكل قيمة مفتاح لإنشاء الـ stream.
  final Stream<T> Function() create;

  final AsyncWidgetBuilder<T> builder;

  @override
  State<CachedStreamBuilder<T>> createState() => _CachedStreamBuilderState<T>();
}

class _CachedStreamBuilderState<T> extends State<CachedStreamBuilder<T>> {
  Stream<T>? _stream;
  Object? _key;

  @override
  Widget build(BuildContext context) {
    if (_stream == null || _key != widget.cacheKey) {
      _key = widget.cacheKey;
      _stream = widget.create();
    }
    return StreamBuilder<T>(stream: _stream, builder: widget.builder);
  }
}
