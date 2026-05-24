import 'package:flutter/material.dart';
import 'package:arash_curier/models/order_model.dart';
import 'package:arash_curier/widgets/home/order_tile_widget.dart';
import 'package:arash_curier/utils/pvz_style.dart';
import 'package:arash_curier/services/database_service.dart';

class PvzFolderCard extends StatelessWidget {
  final String folderKey;
  final List<OrderModel> orders;
  final String userRole;
  final String userEmail;
  final VoidCallback onRefresh;

  const PvzFolderCard({
    super.key,
    required this.folderKey,
    required this.orders,
    required this.userRole,
    required this.userEmail,
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
    
    final style = getPvzStyle(company);
    
    // Проверяем, взят ли этот адрес в работу (кто responsiblePerson у первого заказа)
    final responsible = orders.isNotEmpty ? orders.first.responsiblePerson : '';
    final isTaken = responsible.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: style.color.withValues(alpha: 0.15), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text(company, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: style.color)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(address, style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade100,
                    color: style.color,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Text('$doneCount из ${orders.length} готово', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
              ],
            ),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: isTaken ? Colors.grey.shade100 : style.color.withValues(alpha: 0.1),
              child: isTaken 
                ? Text(getUserAvatar(responsible), style: const TextStyle(fontSize: 22))
                : Text(style.initials, style: TextStyle(color: style.color, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            children: [
            if (!isTaken)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      try {
                        await DatabaseService().takeFolderInWork(orders.map((o) => o.id).toList(), userEmail);
                        onRefresh();
                      } catch (e) {
                        // ignore error
                      }
                    },
                    icon: const Icon(Icons.handshake),
                    label: const Text('Взять в работу адрес', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              )
            else if (responsible == userEmail || userRole == 'admin' || userRole == 'manager')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      try {
                        await DatabaseService().releaseFolderFromWork(orders.map((o) => o.id).toList());
                        onRefresh();
                      } catch (e) {
                        // ignore error
                      }
                    },
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Отказаться от адреса', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ...orders.map(
              (order) => OrderTileWidget(
                key: ValueKey(order.id),
                order: order,
                userRole: userRole,
                onRefresh: onRefresh,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}
