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

      // 4. Также ищем по ID заказа (содержит)
      return matchesNamePrefix || order.id.toLowerCase().contains(q);
    }).toList();

    if (filtered.isNotEmpty) {
      result[folderKey] = filtered;
    }
  }
  return result;
}