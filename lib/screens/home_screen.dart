import 'package:flutter/material.dart';
import 'package:arash_curier/models/order_model.dart';
import 'package:arash_curier/services/database_service.dart';
import 'package:arash_curier/services/auth_service.dart';
import 'package:arash_curier/screens/login_screen.dart';
import 'package:arash_curier/screens/add_order_screen.dart';
import 'package:arash_curier/screens/chat_screen.dart';
import 'package:arash_curier/utils/order_grouping.dart';
import 'package:arash_curier/utils/app_snackbar.dart';
import 'package:arash_curier/widgets/home/pvz_folder_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, List<OrderModel>>? _allOrders;
  bool _isLoading = true;
  String _userRole = 'courier';
  int _currentIndex = 0; // Индекс для нижнего меню

  int get _totalOrders {
    final orders = _allOrders;
    if (orders == null) return 0;
    return orders.values.fold(0, (sum, list) => sum + list.length);
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

  Future<void> _openAddOrder() async {
    final result = await Navigator.push<OrderModel>(
      context,
      MaterialPageRoute(builder: (context) => const AddOrderScreen()),
    );
    if (result == null || !mounted) return;
    try {
      await DatabaseService().createOrder(result);
      if (!mounted) return;
      showAppSnackBar(context, 'Заказ создан');
      _refreshOrders();
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Ошибка создания: $e', isError: true);
    }
  }

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      final role = await AuthService().getUserRole();
      if (mounted) {
        setState(() {
          _userRole = role;
        });
      }
    } catch (e) {
      print('Ошибка получения роли: $e');
    } finally {
      await _refreshOrders();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filterOrdersBySearch(_allOrders ?? {}, _searchQuery);

    // Цвет бренда ПВЗ из ТЗ
    const Color brandGreen = Color(0xFF2E7D32);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: brandGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ARASH COURIER', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            Text('Смена открыта', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white70)),
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
              // Будущий экран уведомлений
            },
          ),
          IconButton(
            onPressed: _isLoading ? null : _refreshOrders,
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
                    _StatsBanner(
                      totalOrders: _totalOrders,
                      folderCount: _allOrders?.length ?? 0,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Клиент, ПВЗ или адрес...',
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
                          : RefreshIndicator(
                              onRefresh: _refreshOrders,
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                                itemCount: filtered.keys.length,
                                itemBuilder: (context, index) {
                                  final keys = filtered.keys.toList()..sort();
                                  final folderKey = keys[index];
                                  final orders = sortOrders(filtered[folderKey]!);
                                  return PvzFolderCard(
                                    folderKey: folderKey,
                                    orders: orders,
                                    onRefresh: _refreshOrders,
                                  );
                                },
                              ),
                            ),
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
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _openAddOrder,
              backgroundColor: Colors.amber[700],
              icon: const Icon(Icons.add_rounded, color: Colors.black87),
              label: const Text('Заказ', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }
}

class _StatsBanner extends StatelessWidget {
  final int totalOrders;
  final int folderCount;

  const _StatsBanner({
    required this.totalOrders,
    required this.folderCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE65100), Color(0xFFFF8A50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE65100).withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatItem(
            icon: Icons.inventory_2_outlined,
            value: '$totalOrders',
            label: 'Заказов',
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withValues(alpha: 0.4),
          ),
          _StatItem(
            icon: Icons.store_outlined,
            value: '$folderCount',
            label: 'ПВЗ',
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

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}