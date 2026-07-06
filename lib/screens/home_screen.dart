import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arash_curier/models/order_model.dart';
import 'package:arash_curier/services/realtime_service.dart';
import 'package:arash_curier/services/database_service.dart';
import 'package:arash_curier/services/auth_service.dart';
import 'package:arash_curier/screens/login_screen.dart';
import 'package:arash_curier/screens/add_order_screen.dart';
import 'package:arash_curier/screens/chat_screen.dart';
import 'package:arash_curier/screens/qr_scanner_screen.dart';
import 'package:arash_curier/utils/order_grouping.dart';
import 'package:arash_curier/utils/app_snackbar.dart';
import 'package:arash_curier/utils/media_kind.dart';
import 'package:arash_curier/utils/pvz_style.dart';
import 'package:arash_curier/widgets/home/pvz_folder_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _realtimeService = RealtimeService();
  String _searchQuery = '';
  String? _selectedPvz;
  String? _selectedAddress;
  Map<String, List<OrderModel>>? _allOrders;
  bool _isLoading = true;
  String _userRole = 'courier';
  String _userEmail = '';
  int _currentIndex = 0; // Индекс для нижнего меню
  List<String> _customOrder = [];
  static const _customOrderPrefsKey = 'pvz_folder_order';
  StreamSubscription<List<SharedMediaFile>>? _intentSub;

  Future<void> _loadCustomOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customOrderPrefsKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List).map((e) => e.toString()).toList();
      if (mounted) setState(() => _customOrder = list);
    } catch (_) {}
  }

  Future<void> _saveCustomOrder(List<String> order) async {
    _customOrder = order;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customOrderPrefsKey, jsonEncode(order));
  }

  String get _roleName {
    if (_userRole == 'admin' || _userRole == 'manager') return 'Менеджер';
    return 'Курьер';
  }

  bool get _isManager => _userRole == 'admin' || _userRole == 'manager';

  int get _totalOrders {
    final orders = _allOrders;
    if (orders == null) return 0;
    return orders.values.fold(0, (sum, list) => sum + list.length);
  }

  int get _completedOrders {
    final orders = _allOrders;
    if (orders == null) return 0;
    int count = 0;
    for (var list in orders.values) {
      count += list.where((o) => o.status == 'Готово' || o.status == 'SHIPPING').length;
    }
    return count;
  }

  int get _pendingOrders {
    return _totalOrders - _completedOrders;
  }

  Future<void> _refreshOrders() async {
    try {
      final orders = await DatabaseService().fetchAndSortOrders(_userRole);
      if (mounted) {
        setState(() {
          _allOrders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showAppSnackBar(context, 'Не удалось загрузить заказы', isError: true);
      }
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти?'),
        content: const Text('Вы уверены, что хотите выйти из аккаунта?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<void> _scanToSearch() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );
    if (code == null || code.isEmpty || !mounted) return;
    _searchController.text = code;
    setState(() => _searchQuery = code.toLowerCase());
  }

  Future<void> _openAddOrder() => _createOrder();

  Future<void> _openAddOrderForFolder(String company, String address) =>
      _createOrder(prefillCompanyName: company, prefillCompanyAddress: address);

  Future<void> _createOrder({
    String? prefillCompanyName,
    String? prefillCompanyAddress,
    File? prefillPendingMedia,
  }) async {
    final result = await Navigator.push<OrderModel>(
      context,
      MaterialPageRoute(
        builder: (context) => AddOrderScreen(
          prefillCompanyName: prefillCompanyName,
          prefillCompanyAddress: prefillCompanyAddress,
          prefillPendingMedia: prefillPendingMedia,
        ),
      ),
    );
    if (result == null || !mounted) return;
    try {
      await DatabaseService().createOrder(result);
      if (prefillPendingMedia != null) {
        await DatabaseService().addOrderMedia(
          result.id,
          prefillPendingMedia,
          [],
          isVideo: isVideoAttachment(prefillPendingMedia.path),
        );
      }
      if (!mounted) return;
      showAppSnackBar(context, 'Заказ создан');
      _refreshOrders();
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Ошибка создания: $e', isError: true);
    }
  }

  Future<void> _initSharingIntent() async {
    final initial = await ReceiveSharingIntent.instance.getInitialMedia();
    if (initial.isNotEmpty) {
      _handleSharedMedia(initial);
      ReceiveSharingIntent.instance.reset();
    }
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((media) {
      if (media.isNotEmpty) {
        _handleSharedMedia(media);
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  void _handleSharedMedia(List<SharedMediaFile> media) {
    if (!_isManager || !mounted) return;
    final file = media.first;
    _createOrder(prefillPendingMedia: File(file.path));
  }

  @override
  void initState() {
    super.initState();
    _initData();
    _loadCustomOrder();

    _realtimeService.subscribeToOrders(() {
      if (mounted) {
        _refreshOrders();
      }
    });
  }

  Future<void> _initData() async {
    try {
      final role = await AuthService().getUserRole();
      final email = AuthService().supabase.auth.currentUser?.email ?? '';
      if (mounted) {
        setState(() {
          _userRole = role;
          _userEmail = email;
        });
      }
    } catch (e) {
      debugPrint('Ошибка получения роли: $e');
    } finally {
      await _refreshOrders();
      // Роль должна быть загружена до обработки шаринга — фича только для менеджеров.
      _initSharingIntent();
    }
  }

  @override
  void dispose() {
    _realtimeService.dispose();
    _searchController.dispose();
    _intentSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filterOrdersBySearch(_allOrders ?? {}, _searchQuery, _selectedPvz, _selectedAddress);

    // Цвет бренда ПВЗ из ТЗ
    const Color brandGreen = Color(0xFF2E7D32);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: brandGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${getUserAvatar(_userEmail)} $_roleName ', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    _userEmail.split('@').first, 
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (!_isManager)
              const Text('Смена открыта', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Badge(
              label: Text('2'),
              backgroundColor: Colors.red,
              child: Icon(Icons.notifications_none, color: Colors.white),
            ),
            onPressed: () {
              showAppSnackBar(context, 'Уведомления находятся в разработке');
            },
          ),
          IconButton(
            onPressed: () {
              setState(() => _isLoading = true);
              _refreshOrders();
            },
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Обновить',
          ),
          IconButton(
            onPressed: _confirmLogout,
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: _currentIndex == 0
          ? _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    if (!_isManager)
                      _StatsBanner(
                        totalOrders: _totalOrders,
                        completedOrders: _completedOrders,
                        pendingOrders: _pendingOrders,
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Клиент или номер заказа...',
                                fillColor: Colors.white,
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: const Icon(Icons.search_rounded),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (value) {
                                setState(() => _searchQuery = value.toLowerCase());
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                              tooltip: 'Найти по штрих-коду',
                              onPressed: _scanToSearch,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? RefreshIndicator(
                              onRefresh: _refreshOrders,
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height * 0.35,
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.inbox_outlined,
                                              size: 64, color: Colors.grey.shade400),
                                          const SizedBox(height: 12),
                                          Text(
                                            _searchQuery.isEmpty
                                                ? 'Нет заказов'
                                                : 'Ничего не найдено',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Builder(builder: (context) {
                              final orderedKeys = sortFolderKeys(
                                filtered.keys.toList(),
                                filtered,
                                _customOrder,
                              );
                              final activeKeys = orderedKeys
                                  .where((k) => !isFolderDone(filtered[k]!))
                                  .toList();
                              final doneKeys = orderedKeys
                                  .where((k) => isFolderDone(filtered[k]!))
                                  .toList();

                              Widget buildCard(String folderKey) => PvzFolderCard(
                                    key: ValueKey(folderKey),
                                    folderKey: folderKey,
                                    orders: sortOrders(filtered[folderKey]!),
                                    userRole: _userRole,
                                    userEmail: _userEmail,
                                    onRefresh: _refreshOrders,
                                    compact: _isManager,
                                    onAddOrder: _isManager ? _openAddOrderForFolder : null,
                                  );

                              return RefreshIndicator(
                                onRefresh: _refreshOrders,
                                child: ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                                  children: [
                                    ReorderableListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      buildDefaultDragHandles: false,
                                      itemCount: activeKeys.length,
                                      onReorder: (oldIndex, newIndex) {
                                        final reordered = List<String>.from(activeKeys);
                                        if (newIndex > oldIndex) newIndex -= 1;
                                        final moved = reordered.removeAt(oldIndex);
                                        reordered.insert(newIndex, moved);
                                        setState(() {});
                                        _saveCustomOrder(reordered);
                                      },
                                      itemBuilder: (context, index) {
                                        final folderKey = activeKeys[index];
                                        return ReorderableDragStartListener(
                                          key: ValueKey(folderKey),
                                          index: index,
                                          child: buildCard(folderKey),
                                        );
                                      },
                                    ),
                                    ...doneKeys.map(buildCard),
                                  ],
                                ),
                              );
                            }),
                    ),
                  ],
                )
          : const ChatScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: brandGreen,
        backgroundColor: Colors.white,
        elevation: 8,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Заявки',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              label: Text('1'),
              child: Icon(Icons.chat_bubble_outline),
            ),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Чат',
          ),
        ],
      ),
      // Показываем кнопку создания заказа ТОЛЬКО если роль manager или admin
      floatingActionButton: (_currentIndex == 0 &&
              (_userRole == 'manager' || _userRole == 'admin'))
          ? FloatingActionButton.extended(
              onPressed: _openAddOrder,
              backgroundColor: Colors.amber[700],
              icon: const Icon(Icons.add_rounded, color: Colors.black87),
              label: const Text(
                'Заказ',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }
}

class _StatsBanner extends StatelessWidget {
  final int totalOrders;
  final int completedOrders;
  final int pendingOrders;

  const _StatsBanner({
    required this.totalOrders,
    required this.completedOrders,
    required this.pendingOrders,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatItem(
                  icon: Icons.inventory_2_rounded,
                  value: '$totalOrders',
                  label: 'Заказов сегодня',
                  iconColor: const Color(0xFF2962FF),
                  bgColor: const Color(0xFFE3F2FD),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 140,
            height: 140,
            child: totalOrders == 0 
              ? const Center(
                  child: Text(
                    'Нет\nзаказов', 
                    textAlign: TextAlign.center, 
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)
                  )
                )
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 4,
                        centerSpaceRadius: 50,
                        startDegreeOffset: -90,
                        sections: [
                          PieChartSectionData(
                            color: const Color(0xFF00C853), // Яркий зеленый
                            value: completedOrders.toDouble(),
                            showTitle: false,
                            radius: 16,
                          ),
                          if (pendingOrders > 0)
                            PieChartSectionData(
                              color: const Color(0xFFFF9100), // Яркий оранжевый
                              value: pendingOrders.toDouble(),
                              showTitle: false,
                              radius: 12,
                            ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${((completedOrders / totalOrders) * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1A1A2E),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Text(
                          'готово',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;
  final Color bgColor;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1A1A2E),
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}