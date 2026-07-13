import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Подписка на изменения таблицы orders через Supabase Realtime.
class RealtimeService {
  RealtimeService({SupabaseClient? client})
      : supabase = client ?? Supabase.instance.client;

  final SupabaseClient supabase;

  RealtimeChannel? _ordersChannel;
  Timer? _debounceTimer;
  VoidCallback? _pendingCallback;

  static const _debounceDuration = Duration(seconds: 1);

  /// Подписка на INSERT/UPDATE/DELETE в LogisticsOrder и app_order_meta.
  ///
  /// public.orders — это VIEW поверх этих двух таблиц, а Postgres logical
  /// replication (на котором работает Supabase Realtime) не может публиковать
  /// изменения VIEW напрямую — подписка на 'orders' никогда не срабатывает.
  /// Слушаем реальные таблицы вместо неё.
  void subscribeToOrders(VoidCallback onDataChanged) {
    unsubscribeFromOrders();

    _ordersChannel = supabase.channel('public:orders-sync');
    _ordersChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'LogisticsOrder',
          callback: (payload) {
            debugPrint(
              'Обновление в таблице LogisticsOrder: ${payload.eventType}',
            );
            _debounced(onDataChanged);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'app_order_meta',
          callback: (payload) {
            debugPrint(
              'Обновление в таблице app_order_meta: ${payload.eventType}',
            );
            _debounced(onDataChanged);
          },
        )
        .subscribe();
  }

  void _debounced(VoidCallback onDataChanged) {
    _pendingCallback = onDataChanged;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _pendingCallback?.call();
      _pendingCallback = null;
    });
  }

  Future<void> unsubscribeFromOrders() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pendingCallback = null;

    final channel = _ordersChannel;
    _ordersChannel = null;
    if (channel != null) {
      await supabase.removeChannel(channel);
    }
  }

  void dispose() {
    unsubscribeFromOrders();
  }
}
