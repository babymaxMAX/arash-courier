// =============================================================================
// order_grouping.dart
// =============================================================================
// WHAT: Pure functions — filter by search, group by city and PVZ folder key.
// NO UI — only data transformations.
//
// Functions to implement:
//   filterOrdersBySearch(allOrders, searchQuery)
//   groupOrdersByCity(filteredOrders) → Map<city, Map<folderKey, List<OrderModel>>>
//   sortOrdersInPlace or sortOrdersCopy(list) — sort "Готово" to bottom
//
// MOVE FROM: home_screen.dart — filteredOrders + cityGroups logic inside Builder.
// =============================================================================

import 'package:arash_curier/models/order_model.dart';

bool isFolderDone(List<OrderModel> orders) {
  return orders.isNotEmpty &&
      orders.every((o) => o.status == 'Готово' || o.status == 'SHIPPING');
}

/// Порядок папок ПВЗ: сначала активные (в ручном порядке пользователя, если
/// задан, иначе по алфавиту, "другое" всегда последним среди активных),
/// затем полностью завершённые — внизу. Как только в завершённую папку
/// попадает новый заказ, она перестаёт быть "done" и сама возвращается
/// в активную группу на своё место.
List<String> sortFolderKeys(
  List<String> keys,
  Map<String, List<OrderModel>> grouped,
  List<String> customOrder,
) {
  final active = <String>[];
  final done = <String>[];
  for (final k in keys) {
    if (isFolderDone(grouped[k] ?? [])) {
      done.add(k);
    } else {
      active.add(k);
    }
  }

  int customIndex(String k) {
    final i = customOrder.indexOf(k);
    return i == -1 ? customOrder.length : i;
  }

  active.sort((a, b) {
    final ci = customIndex(a).compareTo(customIndex(b));
    if (ci != 0) return ci;
    final aOther = a.toLowerCase().startsWith('другое');
    final bOther = b.toLowerCase().startsWith('другое');
    if (aOther && !bOther) return 1;
    if (!aOther && bOther) return -1;
    return a.compareTo(b);
  });
  done.sort((a, b) => a.compareTo(b));
  return [...active, ...done];
}

List<OrderModel> sortOrders(List<OrderModel> orders) {
  List<OrderModel> copy = List.from(orders);
  copy.sort((a, b) {
    if (a.status == "Готово" && b.status != "Готово") {
      return 1;
    }
    if (a.status != "Готово" && b.status == "Готово") {
      return -1;
    }
    return 0;
  });
  return copy;
}

Map<String, List<OrderModel>> filterOrdersBySearch(
  Map<String, List<OrderModel>> allOrders,
  String searchQuery,
  String? selectedPvz,
  String? selectedAddress,
) {
  final q = searchQuery.trim().toLowerCase();
  final result = <String, List<OrderModel>>{};

  for (final entry in allOrders.entries) {
    final folderKey = entry.key;
    final filtered = entry.value.where((order) {
      // 1. Фильтрация по ПВЗ и Адресу
      if (selectedPvz != null && selectedPvz.isNotEmpty && order.companyName != selectedPvz) return false;
      if (selectedAddress != null && selectedAddress.isNotEmpty && order.companyAddress != selectedAddress) return false;

      // 2. Если поисковая строка пуста, оставляем заказ
      if (q.isEmpty) return true;

      // 3. Поиск по первым буквам имени клиента
      final clientNameLower = order.clientName.toLowerCase();
      final words = clientNameLower.split(RegExp(r'\s+'));
      final matchesNamePrefix = words.any((word) => word.startsWith(q));

      // 4. Также ищем по номеру заказа (содержит)
      final matchesOrderNumber = order.id.toLowerCase().contains(q);

      // 5. Точное совпадение со штрих-кодом (например, после сканирования)
      final matchesBarcode = order.clientQrCodes.any((c) => c.toLowerCase() == q) ||
          order.pvzQrCodes.any((c) => c.toLowerCase() == q);

      return matchesNamePrefix || matchesOrderNumber || matchesBarcode;
    }).toList();

    if (filtered.isNotEmpty) {
      result[folderKey] = filtered;
    }
  }
  return result;
}