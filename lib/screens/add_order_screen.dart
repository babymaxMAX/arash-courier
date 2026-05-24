import 'package:flutter/material.dart';
import 'package:arash_curier/models/order_model.dart';
import 'package:uuid/uuid.dart';

class AddOrderScreen extends StatefulWidget {
  final OrderModel? orderToEdit;

  const AddOrderScreen({super.key, this.orderToEdit});

  @override
  State<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends State<AddOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _companyController;
  late TextEditingController _addressController;
  late TextEditingController _clientController;
  late TextEditingController _cityController;
  late TextEditingController _paymentController;

  @override
  void initState() {
    super.initState();
    final o = widget.orderToEdit;
    _companyController = TextEditingController(text: o?.companyName ?? '');
    _addressController = TextEditingController(text: o?.companyAddress ?? '');
    _clientController = TextEditingController(text: o?.clientName ?? '');
    _cityController = TextEditingController(text: o?.deliveryCity ?? '');
    _paymentController = TextEditingController(
      text: o != null ? o.clientPayment.toString() : '0',
    );
  }

  @override
  void dispose() {
    _companyController.dispose();
    _addressController.dispose();
    _clientController.dispose();
    _cityController.dispose();
    _paymentController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final isEditing = widget.orderToEdit != null;
    final existing = widget.orderToEdit;
    final now = DateTime.now();

    final order = OrderModel.create(
      id: isEditing ? existing!.id : const Uuid().v4(),
      dateCreated: isEditing ? existing!.dateCreated : now,
      dateUpdated: now,
      companyName: _companyController.text.trim(),
      companyAddress: _addressController.text.trim(),
      responsiblePerson: isEditing ? existing!.responsiblePerson : '',
      clientName: _clientController.text.trim(),
      deliveryCity: _cityController.text.trim(),
      status: isEditing ? existing!.status : 'NEW',
      comment: isEditing ? existing!.comment : null,
      cancelReason: isEditing ? existing!.cancelReason : null,
      clientPayment: double.tryParse(_paymentController.text) ?? 0.0,
      debtAmount: isEditing ? existing!.debtAmount : 0,
      deliveryPrice: isEditing ? existing!.deliveryPrice : 0,
      pointsDeduction: isEditing ? existing!.pointsDeduction : 0,
      photos: isEditing ? existing!.photos : [],
      clientQrCodes: isEditing ? existing!.clientQrCodes : [],
      pvzQrCodes: isEditing ? existing!.pvzQrCodes : [],
    );

    Navigator.pop(context, order);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.orderToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Редактировать заказ' : 'Новый заказ'),
        backgroundColor: Colors.green.shade800,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _companyController,
              decoration: const InputDecoration(
                labelText: 'ПВЗ / Компания (СДЭК)',
              ),
              validator: (v) => v!.isEmpty ? 'Обязательное поле' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Адрес ПВЗ (ул. Урожайная)',
              ),
              validator: (v) => v!.isEmpty ? 'Обязательное поле' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _clientController,
              decoration: const InputDecoration(labelText: 'ФИО Клиента'),
              validator: (v) => v!.isEmpty ? 'Обязательное поле' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cityController,
              decoration: const InputDecoration(labelText: 'Город доставки'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _paymentController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Оплата курьером (₽)',
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade600,
                padding: const EdgeInsets.all(16),
              ),
              onPressed: _save,
              child: Text(
                isEditing ? 'СОХРАНИТЬ ИЗМЕНЕНИЯ' : 'СОЗДАТЬ ЗАКАЗ',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
