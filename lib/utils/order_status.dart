/// Статусы в Supabase (англ.) и отображение в UI (рус.).
class OrderStatus {
  OrderStatus._();

  static const doneDb = {'SHIPPING', 'READY', 'DELIVERED', 'DONE', 'COMPLETED'};
  static const doneUi = {'Готово', 'Доставлено'};
  static const delayedDb = {'DELAYED', 'POSTPONED'};
  static const delayedUi = {'Отложено'};

  static bool isDone(String status) {
    final upper = status.toUpperCase();
    return doneDb.contains(upper) || doneUi.contains(status);
  }

  static bool isDelayed(String status) {
    final upper = status.toUpperCase();
    return upper == 'DELAYED' ||
        upper == 'POSTPONED' ||
        status == 'delayed' ||
        delayedUi.contains(status);
  }

  /// Следующий статус для записи в БД (галочка на карточке).
  static String toggleDbStatus(String current) {
    return isDone(current) ? 'NEW' : 'SHIPPING';
  }

  /// Нормализация любого статуса (RU/EN) → код для Supabase.
  static String forDatabase(String status) {
    switch (status) {
      case 'Готово':
      case 'В пути':
        return 'SHIPPING';
      case 'Новый':
        return 'NEW';
      case 'Отложено':
        return 'delayed';
      case 'Доставлено':
        return 'DELIVERED';
      case 'Ожидает':
        return 'WAITING';
      case 'Выдано':
        return 'ISSUED';
      case 'Отменено':
        return 'CANCELLED';
      case 'Возврат':
        return 'RETURN';
      default:
        final upper = status.toUpperCase();
        if (upper == 'DELAYED' || upper == 'POSTPONED') return 'delayed';
        return status;
    }
  }
}
