import 'package:arash_curier/models/order_model.dart';

/// Шкала прогресса заказа (как на Wildberries) — отдельный слой поверх
/// уже переведённого order.status, ничего не меняет в существующей логике
/// "готово"/сортировки, которая завязана на точный текст статуса.
class OrderProgressInfo {
  final List<String> steps;

  /// Индекс текущего шага в [steps], либо -1 если заказ в состоянии
  /// исключения (отменён/отложен/задерживается) — тогда прогресс не рисуется
  /// как линейный, а показывается отдельным предупреждением.
  final int currentStep;
  final bool isCancelled;
  final bool isException; // отложена / задерживается
  final String exceptionLabel;

  const OrderProgressInfo({
    required this.steps,
    required this.currentStep,
    required this.isCancelled,
    required this.isException,
    this.exceptionLabel = '',
  });
}

const _deliverySteps = ['Принята', 'В пути', 'Готово к выдаче', 'Выдано'];
const _shipmentSteps = ['Создана', 'Принята', 'В пути', 'Отправлено'];

OrderProgressInfo computeOrderProgress(OrderModel order) {
  final isShipmentFlow = order.orderType == 'RETURN' || order.orderType == 'SHIPMENT';
  final steps = isShipmentFlow ? _shipmentSteps : _deliverySteps;
  final status = order.status;

  if (status == 'Отменено') {
    return OrderProgressInfo(steps: steps, currentStep: -1, isCancelled: true, isException: false);
  }

  if (status == 'Отложено') {
    final reason = order.cancelReason;
    return OrderProgressInfo(
      steps: steps,
      currentStep: -1,
      isCancelled: false,
      isException: true,
      exceptionLabel: reason != null && reason.isNotEmpty ? 'Отложена: $reason' : 'Отложена',
    );
  }

  if (status == 'Задерживается') {
    final reason = order.cancelReason;
    return OrderProgressInfo(
      steps: steps,
      currentStep: -1,
      isCancelled: false,
      isException: true,
      exceptionLabel:
          reason != null && reason.isNotEmpty ? 'Задерживается: $reason' : 'Задерживается на складе в Адлере',
    );
  }

  int index;
  if (isShipmentFlow) {
    switch (status) {
      case 'Создана':
        index = 0;
        break;
      case 'Принята':
        index = 1;
        break;
      case 'В пути':
        index = 2;
        break;
      case 'Отправлено':
        index = 3;
        break;
      default:
        index = 0;
    }
  } else {
    switch (status) {
      case 'Ожидает':
        index = 0;
        break;
      case 'В пути':
        index = 1;
        break;
      case 'На складе':
        index = 1;
        break;
      case 'Готово':
        index = 2;
        break;
      case 'Выдано':
        index = 3;
        break;
      default:
        index = 0;
    }
  }

  return OrderProgressInfo(steps: steps, currentStep: index, isCancelled: false, isException: false);
}
