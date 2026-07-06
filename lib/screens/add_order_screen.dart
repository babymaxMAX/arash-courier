import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arash_curier/models/order_model.dart';
import 'package:uuid/uuid.dart';

/// Города доставки — фиксированный список реальных пунктов ARASH (таблица
/// Office), не меняется сам по себе, пока физически не откроется новый пункт.
const List<String> kDeliveryCities = ['Сухум', 'Гудаута', 'Новый Афон', 'Очамчыра'];

class AddOrderScreen extends StatefulWidget {
  final OrderModel? orderToEdit;

  /// Если заказ создаётся по нажатию на папку ПВЗ, сюда приходят её
  /// компания/адрес — форма открывается уже с заполненным пунктом.
  final String? prefillCompanyName;
  final String? prefillCompanyAddress;

  const AddOrderScreen({
    super.key,
    this.orderToEdit,
    this.prefillCompanyName,
    this.prefillCompanyAddress,
  });

  @override
  State<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends State<AddOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  TextEditingController? _pvzCtrl;
  TextEditingController? _clientCtrl;
  TextEditingController? _cityCtrl;
  late TextEditingController _phoneController;
  late TextEditingController _commentController;

  List<String> _pvzOptions = [];
  List<String> _clientNameOptions = [];
  final Map<String, String> _phoneByClientName = {};
  bool _loadingCatalog = true;

  String get _initialPvzText {
    final o = widget.orderToEdit;
    if (o != null) {
      return o.companyAddress.isNotEmpty
          ? '${o.companyName} · ${o.companyAddress}'
          : o.companyName;
    }
    if (widget.prefillCompanyName != null) {
      final address = widget.prefillCompanyAddress ?? '';
      return address.isNotEmpty
          ? '${widget.prefillCompanyName} · $address'
          : widget.prefillCompanyName!;
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    final o = widget.orderToEdit;
    _phoneController = TextEditingController(text: o?.clientPhone ?? '');
    _commentController = TextEditingController(text: o?.comment ?? '');
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final pvzRows = await Supabase.instance.client
          .from('pvz_canonical')
          .select('display')
          .order('display');
      final displays =
          (pvzRows as List).map((r) => r['display'] as String).toList();
      if (!displays.contains('Аптека')) displays.add('Аптека');

      final recentRows = await Supabase.instance.client
          .from('orders')
          .select('client_name, client_phone')
          .order('date_created', ascending: false)
          .limit(300);
      final names = <String>[];
      for (final r in (recentRows as List)) {
        final name = (r['client_name'] as String?)?.trim() ?? '';
        final phone = (r['client_phone'] as String?)?.trim() ?? '';
        if (name.isEmpty || name == 'Без имени' || _phoneByClientName.containsKey(name)) {
          continue;
        }
        _phoneByClientName[name] = phone;
        names.add(name);
      }

      if (mounted) {
        setState(() {
          _pvzOptions = displays;
          _clientNameOptions = names;
          _loadingCatalog = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingCatalog = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final isEditing = widget.orderToEdit != null;
    final existing = widget.orderToEdit;
    final now = DateTime.now();

    final pvzRaw = (_pvzCtrl?.text ?? '').trim();
    final sepIndex = pvzRaw.indexOf(' · ');
    final companyName = sepIndex > 0 ? pvzRaw.substring(0, sepIndex).trim() : pvzRaw;
    final companyAddress = sepIndex > 0 ? pvzRaw.substring(sepIndex + 3).trim() : '';

    final phone = _phoneController.text.trim();

    final order = OrderModel.create(
      id: isEditing ? existing!.id : const Uuid().v4(),
      dateCreated: isEditing ? existing!.dateCreated : now,
      dateUpdated: now,
      companyName: companyName,
      companyAddress: companyAddress,
      responsiblePerson: isEditing ? existing!.responsiblePerson : '',
      clientName: (_clientCtrl?.text ?? '').trim(),
      clientPhone: phone.isEmpty ? null : phone,
      deliveryCity: (_cityCtrl?.text ?? '').trim(),
      status: isEditing ? existing!.status : 'NEW',
      comment: _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
      cancelReason: isEditing ? existing!.cancelReason : null,
      clientPayment: isEditing ? existing!.clientPayment : 0,
      debtAmount: isEditing ? existing!.debtAmount : 0,
      deliveryPrice: isEditing ? existing!.deliveryPrice : 0,
      pointsDeduction: isEditing ? existing!.pointsDeduction : 0,
      photos: isEditing ? existing!.photos : [],
      clientQrCodes: isEditing ? existing!.clientQrCodes : [],
      pvzQrCodes: isEditing ? existing!.pvzQrCodes : [],
    );

    Navigator.pop(context, order);
  }

  Widget _optionsListView(Iterable<String> options, void Function(String) onSelected) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260, minWidth: 280),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options.elementAt(index);
              return ListTile(
                dense: true,
                title: Text(option),
                onTap: () => onSelected(option),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.orderToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Редактировать заказ' : 'Новый заказ'),
        backgroundColor: Colors.green.shade800,
        actions: [
          if (_loadingCatalog)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Autocomplete<String>(
              initialValue: TextEditingValue(text: widget.orderToEdit?.clientName ?? ''),
              optionsBuilder: (value) {
                if (value.text.isEmpty) return const Iterable<String>.empty();
                final q = value.text.toLowerCase();
                return _clientNameOptions.where((o) => o.toLowerCase().contains(q));
              },
              onSelected: (name) {
                _clientCtrl?.text = name;
                final phone = _phoneByClientName[name];
                if (phone != null && phone.isNotEmpty) {
                  _phoneController.text = phone;
                }
              },
              optionsViewBuilder: (context, onSelected, options) =>
                  _optionsListView(options, onSelected),
              fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                _clientCtrl = controller;
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Клиент',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null,
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Телефон клиента',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 16),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: widget.orderToEdit?.deliveryCity ?? ''),
              optionsBuilder: (value) {
                if (value.text.isEmpty) return kDeliveryCities;
                final q = value.text.toLowerCase();
                return kDeliveryCities.where((o) => o.toLowerCase().contains(q));
              },
              optionsViewBuilder: (context, onSelected, options) =>
                  _optionsListView(options, onSelected),
              fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                _cityCtrl = controller;
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Город доставки',
                    prefixIcon: Icon(Icons.apartment_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null,
                );
              },
            ),
            const SizedBox(height: 16),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _initialPvzText),
              optionsBuilder: (value) {
                if (value.text.isEmpty) return _pvzOptions;
                final q = value.text.toLowerCase();
                return _pvzOptions.where((o) => o.toLowerCase().contains(q));
              },
              optionsViewBuilder: (context, onSelected, options) =>
                  _optionsListView(options, onSelected),
              fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                _pvzCtrl = controller;
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'ПВЗ / Компания',
                    hintText: 'Например: Wildberries · Урожайная 96',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null,
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Комментарий',
                hintText: 'Заметка по заказу (необязательно)',
                prefixIcon: Icon(Icons.comment_outlined),
                alignLabelWithHint: true,
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
