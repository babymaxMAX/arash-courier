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

  /// Подписка на INSERT/UPDATE/DELETE в public.orders.
  void subscribeToOrders(VoidCallback onDataChanged) {
    unsubscribeFromOrders();

    _ordersChannel = supabase.channel('public:orders');
    _ordersChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            debugPrint(
              'Обновление в таблице orders: ${payload.eventType}',
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
