import 'package:flutter/material.dart';
import 'package:arash_curier/models/order_model.dart';
import 'package:arash_curier/utils/pvz_style.dart';
import 'package:arash_curier/widgets/home/order_tile_widget.dart';

class PvzFolderCard extends StatelessWidget {
  final String folderKey;
  final List<OrderModel> orders;
  final VoidCallback onRefresh;

  const PvzFolderCard({
    super.key,
    required this.folderKey,
    required this.orders,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final style = getPvzStyle(orders.first.companyName);
    final doneCount = orders.where((o) => o.status == 'Готово').length;
    final progress = orders.isEmpty ? 0.0 : doneCount / orders.length;

    final parts = folderKey.split(' - ');
    final title = parts.isNotEmpty ? parts.first : folderKey;
    final address = parts.length > 1 ? parts.sublist(1).join(' - ') : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: style.color,
            child: Text(
              style.initials,
              style: TextStyle(
                color: _textOnColor(style.color),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (address.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  address,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  color: style.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Готово $doneCount из ${orders.length}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          children: orders
              .map(
                (order) => OrderTileWidget(
                  key: ValueKey(order.id),
                  order: order,
                  onRefresh: onRefresh,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Color _textOnColor(Color bg) {
    return bg.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;
  }
}
