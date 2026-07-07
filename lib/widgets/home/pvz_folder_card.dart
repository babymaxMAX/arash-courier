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
  final bool compact;
  final void Function(String company, String address)? onAddOrder;

  const PvzFolderCard({
    super.key,
    required this.folderKey,
    required this.orders,
    required this.userRole,
    required this.userEmail,
    required this.onRefresh,
    this.compact = false,
    this.onAddOrder,
  });

  @override
  Widget build(BuildContext context) {
    final parts = folderKey.split(' - ');
    final company = parts.isNotEmpty ? parts[0] : 'Неизвестно';
    // Фиксим случай когда в ключе нет адреса
    final address = parts.length > 1 ? parts.sublist(1).join(' - ') : '';

    final doneCount = orders
        .where((o) => o.status == 'Готово' || o.status == 'SHIPPING')
        .length;
    final progress = orders.isEmpty ? 0.0 : doneCount / orders.length;
    
    final style = getPvzStyle(company);
    
    // Проверяем, взят ли этот адрес в работу (кто responsiblePerson у первого заказа)
    final responsible = orders.isNotEmpty ? orders.first.responsiblePerson : '';
    final isTaken = responsible.isNotEmpty;
    final canRelease = isTaken && (responsible == userEmail || userRole == 'admin' || userRole == 'manager');

    Future<void> takeOrRelease() async {
      try {
        if (!isTaken) {
          await DatabaseService().takeFolderInWork(orders.map((o) => o.id).toList(), userEmail);
        } else if (canRelease) {
          await DatabaseService().releaseFolderFromWork(orders.map((o) => o.id).toList());
        }
        onRefresh();
      } catch (e) {
        // ignore error
      }
    }

    final swipeCard = Container(
      margin: EdgeInsets.only(bottom: compact ? 6 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 12 : 20),
        boxShadow: compact
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
        border: Border.all(color: style.color.withValues(alpha: 0.15), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 12 : 20),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
          ),
          child: ExpansionTile(
            dense: compact,
            tilePadding: compact
                ? const EdgeInsets.symmetric(horizontal: 10, vertical: 0)
                : null,
            title: onAddOrder == null
                ? Text(
                    company,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: compact ? 13 : 16, color: style.color),
                  )
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onAddOrder!(company, address),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            company,
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: compact ? 13 : 16, color: style.color),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.add_circle, size: compact ? 14 : 18, color: style.color.withValues(alpha: 0.6)),
                      ],
                    ),
                  ),
            subtitle: compact
                ? Text(
                    '$address · $doneCount/${orders.length}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  )
                : Column(
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
              radius: compact ? 14 : 24,
              backgroundColor: isTaken ? Colors.grey.shade100 : style.color.withValues(alpha: 0.1),
              child: isTaken
                  ? Text(getUserAvatar(responsible), style: TextStyle(fontSize: compact ? 13 : 22))
                  : (style.assetPath != null
                      ? ClipOval(
                          child: Image.asset(
                            style.assetPath!,
                            width: compact ? 28 : 48,
                            height: compact ? 28 : 48,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Text(style.initials, style: TextStyle(color: style.color, fontWeight: FontWeight.bold, fontSize: compact ? 9 : 14))),
            ),
            children: [
            if (!compact && (!isTaken || canRelease))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  children: [
                    Icon(Icons.swipe_right_alt_rounded, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      isTaken ? 'Смахните карточку вправо, чтобы отказаться' : 'Смахните карточку вправо, чтобы взять в работу',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
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

    if (!isTaken || canRelease) {
      return Dismissible(
        key: ValueKey('swipe-$folderKey'),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (_) async {
          await takeOrRelease();
          return false;
        },
        background: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.only(left: 24),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: isTaken ? Colors.red.shade400 : Colors.blue.shade600,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(isTaken ? Icons.close_rounded : Icons.handshake, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                isTaken ? 'Отказаться' : 'Взять в работу',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        child: swipeCard,
      );
    }
    return swipeCard;
  }
}
