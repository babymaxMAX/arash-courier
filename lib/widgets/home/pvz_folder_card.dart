import 'package:flutter/material.dart';
import 'package:arash_curier/models/order_model.dart';
import 'package:arash_curier/widgets/home/order_tile_widget.dart';

class PvzFolderCard extends StatelessWidget {
  final String folderKey;
  final List<OrderModel> orders;
  final String userRole;
  final VoidCallback onRefresh;

  const PvzFolderCard({
    super.key,
    required this.folderKey,
    required this.orders,
    required this.userRole,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final parts = folderKey.split(' - ');
    final company = parts.isNotEmpty ? parts[0] : 'Неизвестно';
    final address = parts.length > 1 ? parts[1] : '';

    final doneCount = orders
        .where((o) => o.status == 'Готово' || o.status == 'SHIPPING')
        .length;
    final progress = orders.isEmpty ? 0.0 : doneCount / orders.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(company, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(address),
          leading: CircularProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            color: Colors.green,
          ),
          children: orders
              .map(
                (order) => OrderTileWidget(
                  key: ValueKey(order.id),
                  order: order,
                  userRole: userRole,
                  onRefresh: onRefresh,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
