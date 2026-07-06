import 'package:flutter/material.dart';

import 'package:arash_curier/models/order_model.dart';
import 'package:arash_curier/utils/order_progress.dart';
import 'package:arash_curier/utils/order_type_style.dart';

/// Шкала прогресса заказа в стиле Wildberries — точки-шаги соединены линией,
/// пройденные шаги закрашены цветом вида заявки. Отменённые/отложенные заказы
/// показываются отдельным предупреждением вместо линейного прогресса.
class OrderProgressBar extends StatelessWidget {
  final OrderModel order;

  const OrderProgressBar({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final progress = computeOrderProgress(order);
    final style = getOrderTypeStyle(order.orderType);

    if (progress.isCancelled) {
      return _ExceptionBanner(
        icon: Icons.cancel_rounded,
        color: Colors.red.shade600,
        label: 'Отменена',
      );
    }
    if (progress.isException) {
      return _ExceptionBanner(
        icon: Icons.warning_amber_rounded,
        color: Colors.orange.shade700,
        label: progress.exceptionLabel,
      );
    }

    final steps = progress.steps;
    final current = progress.currentStep.clamp(0, steps.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(steps.length * 2 - 1, (i) {
            if (i.isOdd) {
              final segmentDone = (i ~/ 2) < current;
              return Expanded(
                child: Container(
                  height: 3,
                  color: segmentDone ? style.color : Colors.grey.shade300,
                ),
              );
            }
            final stepIndex = i ~/ 2;
            final done = stepIndex < current;
            final active = stepIndex == current;
            return Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done || active ? style.color : Colors.grey.shade300,
                border: active
                    ? Border.all(color: style.color.withValues(alpha: 0.3), width: 4)
                    : null,
              ),
              child: done
                  ? const Icon(Icons.check, size: 10, color: Colors.white)
                  : null,
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          steps[current],
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: style.color),
        ),
      ],
    );
  }
}

class _ExceptionBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _ExceptionBanner({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
