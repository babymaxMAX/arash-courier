// UI Flutter.
import 'package:flutter/material.dart';
// Модель заказа для сборки из полей формы.
import 'package:arash_curier/models/order_model.dart';

// Экран формы: создание заказа или редактирование, если передан widget.order.
class AddOrderScreen extends StatefulWidget {
  final OrderModel? order; // null — новый заказ; не null — редактирование.
  const AddOrderScreen({super.key, this.order});

  @override
  State<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends State<AddOrderScreen> {
  final _formKey = GlobalKey<FormState>(); // Ключ для validate() всей формы.

  final _companyNameController = TextEditingController(); // Текст: название компании/ПВЗ.
  final _clientNameController = TextEditingController(); // Текст: ФИО клиента.
  final _companyAddressController = TextEditingController();
  final _responsiblePersonController = TextEditingController();
  final _deliveryCityController = TextEditingController();
  final _pvzQrCodeController = TextEditingController();
  final _clientQrCodeController = TextEditingController();
  final _urlPhotoController = TextEditingController();
  final _statusController = TextEditingController();
  final _commentController = TextEditingController();
  final _cancelReasonController = TextEditingController();
  final _clientPaymentController = TextEditingController();
  final _debtAmountController = TextEditingController();
  final _deliveryPriceController = TextEditingController();
  final _pointsDeductionController = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.order != null) {
      _companyNameController.text = widget.order!.companyName;
      _clientNameController.text = widget.order!.clientName;
      _companyAddressController.text = widget.order!.companyAddress;
      _responsiblePersonController.text = widget.order!.responsiblePerson;
      _deliveryCityController.text = widget.order!.deliveryCity;
      _pvzQrCodeController.text = widget.order!.pvzQrCode;
      _clientQrCodeController.text = widget.order!.clientQrCode;
      _urlPhotoController.text = widget.order!.urlPhoto;
      _statusController.text = widget.order!.status;
      _commentController.text = widget.order!.comment ?? '';
      _cancelReasonController.text = widget.order!.cancelReason ?? '';
      _clientPaymentController.text = widget.order!.clientPayment.toString();
      _debtAmountController.text = widget.order!.debtAmount.toString();
      _deliveryPriceController.text = widget.order!.deliveryPrice.toString();
      _pointsDeductionController.text = widget.order!.pointsDeduction.toString();
    } else {
      _statusController.text = 'NEW';
    }
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _clientNameController.dispose();
    _companyAddressController.dispose();
    _responsiblePersonController.dispose();
    _deliveryCityController.dispose();
    _pvzQrCodeController.dispose();
    _clientQrCodeController.dispose();
    _urlPhotoController.dispose();
    _statusController.dispose();
    _commentController.dispose();
    _cancelReasonController.dispose();
    _clientPaymentController.dispose();
    _debtAmountController.dispose();
    _deliveryPriceController.dispose();
    _pointsDeductionController.dispose();
    super.dispose();
  }

  void _saveOrder() {
    if (!_formKey.currentState!.validate()) {
      return; // Есть ошибки валидации — не сохраняем.
    }

    final now = DateTime.now(); // Текущее время для dateUpdated (и id при создании).

    final order = OrderModel.create(
      id: widget.order?.id ?? now.millisecondsSinceEpoch.toString(),
      dateCreated: widget.order?.dateCreated ?? now,
      dateUpdated: now,
      companyName: _companyNameController.text.trim(),
      companyAddress: _companyAddressController.text.trim(),
      responsiblePerson: _responsiblePersonController.text.trim(),
      clientName: _clientNameController.text.trim(),
      deliveryCity: _deliveryCityController.text.trim(),
      pvzQrCode: _pvzQrCodeController.text.trim(),
      clientQrCode: _clientQrCodeController.text.trim(),
      urlPhoto: _urlPhotoController.text.trim(),
      status: _statusController.text.trim(),
      comment: _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
      cancelReason: _cancelReasonController.text.trim().isEmpty
          ? null
          : _cancelReasonController.text.trim(),
      clientPayment: double.tryParse(_clientPaymentController.text) ?? 0,
      debtAmount: double.tryParse(_debtAmountController.text) ?? 0,
      deliveryPrice: double.tryParse(_deliveryPriceController.text) ?? 0,
      pointsDeduction: double.tryParse(_pointsDeductionController.text) ?? 0,
    );

    Navigator.pop(context, order); // Возвращаем OrderModel на HomeScreen.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.order == null ? 'Создание заказа' : 'Редактирование заказа'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              AppTextField(
                controller: _companyNameController,
                label: 'Название компании',
                icon: Icons.business,
              ),
              AppTextField(
                controller: _clientNameController,
                label: 'ФИО клиента',
                icon: Icons.person,
              ),
              AppTextField(
                controller: _companyAddressController,
                label: 'Адрес компании',
                icon: Icons.location_on,
              ),
              AppTextField(
                controller: _responsiblePersonController,
                label: 'Ответственное лицо',
                icon: Icons.person,
              ),
              AppTextField(
                controller: _deliveryCityController,
                label: 'Город доставки',
                icon: Icons.location_city,
              ),
              AppTextField(
                controller: _pvzQrCodeController,
                label: 'QR-код ПВЗ',
                icon: Icons.qr_code,
              ),
              AppTextField(
                controller: _clientQrCodeController,
                label: 'QR-код клиента',
                icon: Icons.qr_code,
              ),
              AppTextField(
                controller: _urlPhotoController,
                label: 'URL фото',
                icon: Icons.photo,
                isRequired: false,
              ),
              AppTextField(
                controller: _statusController,
                label: 'Статус',
                icon: Icons.check_circle,
              ),
              AppTextField(
                controller: _commentController,
                label: 'Комментарий',
                icon: Icons.comment,
                isRequired: false,
              ),
              AppTextField(
                controller: _cancelReasonController,
                label: 'Причина отмены',
                icon: Icons.cancel,
                isRequired: false,
              ),
              AppTextField(
                controller: _clientPaymentController,
                label: 'Оплата клиента',
                icon: Icons.payment,
                keyboardType: TextInputType.number,
              ),
              AppTextField(
                controller: _debtAmountController,
                label: 'Задолженность',
                icon: Icons.credit_card,
                keyboardType: TextInputType.number,
              ),
              AppTextField(
                controller: _deliveryPriceController,
                label: 'Стоимость доставки',
                icon: Icons.delivery_dining,
                keyboardType: TextInputType.number,
              ),
              AppTextField(
                controller: _pointsDeductionController,
                label: 'Бонусы клиента',
                icon: Icons.loyalty,
                keyboardType: TextInputType.number,
                isRequired: false,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveOrder,
                  child: Text(widget.order == null ? 'Создать заказ' : 'Сохранить изменения'),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Дата создания: ${widget.order?.dateCreated.toString() ?? DateTime.now().toString()}',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                'Дата обновления: ${widget.order?.dateUpdated.toString() ?? DateTime.now().toString()}',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Переиспользуемое поле формы с единым стилем и валидацией.
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final bool isRequired;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.isRequired = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: TextCapitalization.sentences,
        validator: (value) {
          if (isRequired && (value == null || value.trim().isEmpty)) {
            return 'Заполните это поле';
          }
          if (validator != null) {
            return validator!(value);
          }
          return null; // Поле валидно.
        },
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
