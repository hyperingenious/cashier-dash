import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'pos_models.dart';

double _dec(dynamic v) {
  if (v == null) {
    return 0;
  }
  if (v is num) {
    return v.toDouble();
  }
  return double.tryParse(v.toString()) ?? 0;
}

String _dioErrorMessage(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) {
      return data['error'] as String;
    }
    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    final code = e.response?.statusCode;
    if (code != null) {
      return 'Request failed ($code)';
    }
  }
  return e.toString();
}

class RestaurantStore extends ChangeNotifier {
  RestaurantStore._(this._dio);

  factory RestaurantStore.connect({
    required String baseUrl,
    required String token,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl.replaceAll(RegExp(r'/$'), ''),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );
    return RestaurantStore._(dio)..refreshAll();
  }

  final Dio _dio;

  final List<DiningTable> _tables = [];
  final List<FloorSection> _sections = [];
  final List<MenuItem> _menuItems = [];
  final List<TransactionRecord> _transactions = [];
  final Map<String, Map<String, dynamic>> _orderDetailById = {};
  final Map<String, String?> _activeOrderIdByTableId = {};

  String? lastError;

  /// Removing catalog rows is reserved for the admin app; cashiers only add via API.
  bool get canDeleteMenuItems => false;

  UnmodifiableListView<DiningTable> get tables =>
      UnmodifiableListView(_tables);
  UnmodifiableListView<FloorSection> get sections =>
      UnmodifiableListView(_sections);
  UnmodifiableListView<MenuItem> get menuItems =>
      UnmodifiableListView(_menuItems);
  UnmodifiableListView<TransactionRecord> get transactions =>
      UnmodifiableListView(_transactions);

  Future<void> refreshAll() async {
    lastError = null;
    final errs = <String>[];
    try {
      await _loadMenu();
    } catch (e) {
      errs.add('Menu: $e');
    }
    try {
      await _loadSections();
    } catch (e) {
      errs.add('Sections: $e');
    }
    try {
      await _loadTablesAndActiveOrders();
    } catch (e) {
      errs.add('Tables: $e');
    }
    try {
      await _loadCompletedTransactions();
    } catch (e) {
      errs.add('History: $e');
    }
    if (errs.isNotEmpty) {
      lastError = errs.join('\n');
    }
    notifyListeners();
  }

  /// Reload menu only (e.g. after admin adds items while POS is open).
  Future<void> refreshMenu() async {
    try {
      await _loadMenu();
    } catch (e) {
      lastError = '${lastError ?? ''}\nMenu refresh: $e'.trim();
    }
    notifyListeners();
  }

  Future<void> _loadMenu() async {
    final res = await _dio.get<dynamic>('/api/cashier/menu');
    final raw = res.data;
    if (raw == null) {
      _menuItems.clear();
      return;
    }
    if (raw is! List) {
      throw Exception(
        'Menu API expected a JSON array, got ${raw.runtimeType}',
      );
    }
    _menuItems
      ..clear()
      ..addAll(
        raw.map((dynamic item) {
          final m = item as Map<String, dynamic>;
          return MenuItem(
            id: (m['id'] ?? '').toString(),
            name: (m['name'] ?? '').toString(),
            category: (m['category'] ?? 'General').toString(),
            price: _dec(m['price']),
          );
        }),
      );
  }

  Future<void> _loadSections() async {
    final res = await _dio.get<dynamic>('/api/cashier/sections');
    final raw = res.data;
    _sections.clear();
    if (raw is! List) {
      return;
    }
    for (final dynamic item in raw) {
      final m = item as Map<String, dynamic>;
      _sections.add(
        FloorSection(
          id: (m['id'] ?? '').toString(),
          name: (m['name'] ?? '').toString(),
          sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    _sections.sort((a, b) {
      final c = a.sortOrder.compareTo(b.sortOrder);
      if (c != 0) {
        return c;
      }
      return a.name.compareTo(b.name);
    });
  }

  Future<void> _loadTablesAndActiveOrders() async {
    final res = await _dio.get<List<dynamic>>('/api/cashier/tables');
    final list = res.data ?? const [];
    _tables.clear();
    _activeOrderIdByTableId.clear();
    for (final raw in list) {
      final m = raw as Map<String, dynamic>;
      final id = (m['id'] ?? '').toString();
      final num = m['table_number'] as int? ?? 0;
      final label = m['label'] as String?;
      final display = (label != null && label.trim().isNotEmpty)
          ? label.trim()
          : (num > 0 ? 'T-$num' : 'Table');
      final statusStr = (m['status'] ?? 'free').toString().toLowerCase();
      final status = statusStr == 'occupied'
          ? TableStatus.occupied
          : TableStatus.available;
      final sid = m['section_id']?.toString();
      final sname = m['section_name'] as String?;
      final ots = m['order_started_at'] as String?;
      final orderStarted = ots != null ? DateTime.tryParse(ots) : null;
      final atot = m['active_order_total'];
      final activeTotal = atot != null ? _dec(atot) : null;
      _tables.add(
        DiningTable(
          id: id,
          name: display,
          capacity: 4,
          status: status,
          tableNumber: num > 0 ? num : null,
          sectionId: sid,
          sectionName: sname,
          label: label,
          orderStartedAt: orderStarted,
          activeOrderTotal: activeTotal,
        ),
      );
      final oid = m['active_order_id'];
      _activeOrderIdByTableId[id] = oid?.toString();
    }

    final detailIds = _activeOrderIdByTableId.values
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toSet();
    await Future.wait(
      detailIds.map((id) => _fetchOrderDetail(id)),
    );
  }

  Future<void> _fetchOrderDetail(String orderId) async {
    if (orderId.isEmpty) {
      return;
    }
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/cashier/orders/$orderId',
      );
      final data = res.data;
      if (data != null) {
        _orderDetailById[orderId] = data;
      }
    } catch (_) {
      _orderDetailById.remove(orderId);
    }
  }

  Future<void> _loadCompletedTransactions() async {
    final res = await _dio.get<List<dynamic>>(
      '/api/cashier/orders',
      queryParameters: {'status': 'completed'},
    );
    final list = res.data ?? const [];
    _transactions.clear();
    final ids = list
        .map((e) => ((e as Map<String, dynamic>)['id'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .take(40)
        .toList();
    for (final id in ids) {
      try {
        final d = await _dio.get<Map<String, dynamic>>('/api/cashier/orders/$id');
        final body = d.data;
        if (body == null) {
          continue;
        }
        final order = body['order'] as Map<String, dynamic>? ?? {};
        final items = body['items'] as List<dynamic>? ?? const [];
        final tn = order['table_number'];
        final tableName =
            tn != null ? 'T-$tn' : 'Order ${id.substring(0, 8)}';
        final created = order['created_at']?.toString();
        final ts = DateTime.tryParse(created ?? '') ?? DateTime.now();
        final lines = <BillLine>[];
        for (final it in items) {
          final im = it as Map<String, dynamic>;
          final qty = im['quantity'] as int? ?? 0;
          final price = _dec(im['price_snapshot']);
          final name = (im['name_snapshot'] ?? '').toString();
          lines.add(
            BillLine(
              itemName: name,
              unitPrice: price,
              quantity: qty,
              lineTotal: price * qty,
            ),
          );
        }
        final subtotal = lines.fold<double>(0, (a, b) => a + b.lineTotal);
        final total = _dec(order['total_amount']);
        final discount = _dec(order['discount']);
        final tax = 0.0;
        _transactions.add(
          TransactionRecord(
            id: id,
            tableName: tableName,
            timestamp: ts,
            lines: lines,
            totals: BillTotals(
              subtotal: subtotal,
              tax: tax,
              total: total > 0 ? total : subtotal - discount,
            ),
          ),
        );
      } catch (_) {
        continue;
      }
    }
  }

  DiningTable? tableById(String tableId) {
    return _tables.where((t) => t.id == tableId).firstOrNull;
  }

  List<DiningTable> tablesInSection(String sectionId) {
    return _tables.where((t) => t.sectionId == sectionId).toList();
  }

  List<DiningTable> get tablesWithoutSection =>
      _tables.where((t) => t.sectionId == null || t.sectionId!.isEmpty).toList();

  int suggestNextTableNumber(String sectionId) {
    var maxN = 0;
    for (final t in _tables) {
      if (t.sectionId != sectionId) {
        continue;
      }
      final n = t.tableNumber ?? 0;
      if (n > maxN) {
        maxN = n;
      }
    }
    return maxN + 1;
  }

  String? _activeOrderForTable(String tableId) =>
      _activeOrderIdByTableId[tableId];

  Future<void> createSection(String name, {bool shouldNotify = true}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/cashier/sections',
        data: {'name': trimmed},
      );
      await _loadSections();
      if (shouldNotify) {
        notifyListeners();
      }
    } catch (e) {
      lastError = e.toString();
      if (shouldNotify) {
        notifyListeners();
      }
    }
  }

  Future<bool> deleteSection(String sectionId) async {
    try {
      await _dio.delete('/api/cashier/sections/$sectionId');
      await refreshAll();
      return true;
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<DiningTable?> addTableInSection({
    required String sectionId,
    required int tableNumber,
    String? label,
    bool shouldNotify = true,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/cashier/tables',
        data: {
          'section_id': sectionId,
          'table_number': tableNumber,
          if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
          'canvas_x': 80,
          'canvas_y': 80,
        },
      );
      await _loadTablesAndActiveOrders();
      if (shouldNotify) {
        notifyListeners();
      }
      return _tables
          .where((t) => t.sectionId == sectionId && t.tableNumber == tableNumber)
          .firstOrNull;
    } catch (e) {
      lastError = e.toString();
      if (shouldNotify) {
        notifyListeners();
      }
      return null;
    }
  }

  Future<bool> removeTable(String tableId) async {
    if (hasActiveOrder(tableId)) {
      return false;
    }
    try {
      await _dio.delete('/api/cashier/tables/$tableId');
      await refreshAll();
      return true;
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> addMenuItem({
    required String name,
    required String category,
    required double price,
  }) async {
    lastError = null;
    try {
      final cat = category.trim();
      await _dio.post<dynamic>(
        '/api/cashier/menu',
        data: <String, dynamic>{
          'name': name.trim(),
          'price': price,
          if (cat.isNotEmpty) 'category': cat,
        },
      );
      await refreshMenu();
      return true;
    } catch (e) {
      lastError = _dioErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeMenuItem(String menuItemId) async => false;

  bool hasActiveOrder(String tableId) {
    final oid = _activeOrderForTable(tableId);
    return oid != null && oid.isNotEmpty;
  }

  List<BillLine> orderDetailsForTable(String tableId) {
    final oid = _activeOrderForTable(tableId);
    if (oid == null || oid.isEmpty) {
      return const [];
    }
    final d = _orderDetailById[oid];
    final items = d?['items'] as List<dynamic>? ?? const [];
    final out = <BillLine>[];
    for (final it in items) {
      final im = it as Map<String, dynamic>;
      final qty = im['quantity'] as int? ?? 0;
      final price = _dec(im['price_snapshot']);
      final name = (im['name_snapshot'] ?? '').toString();
      out.add(
        BillLine(
          itemName: name,
          unitPrice: price,
          quantity: qty,
          lineTotal: price * qty,
        ),
      );
    }
    return out;
  }

  BillTotals calculateBill(String tableId) {
    final oid = _activeOrderForTable(tableId);
    final lines = orderDetailsForTable(tableId);
    final subtotal = lines.fold<double>(0, (a, b) => a + b.lineTotal);
    final d = oid != null ? _orderDetailById[oid] : null;
    final order = d?['order'] as Map<String, dynamic>?;
    final total = order != null ? _dec(order['total_amount']) : subtotal;
    final discount = order != null ? _dec(order['discount']) : 0.0;
    final tax = 0.0;
    return BillTotals(
      subtotal: subtotal,
      tax: tax,
      total: total > 0 ? total : (subtotal - discount).clamp(0, double.infinity),
    );
  }

  Future<void> markTableOccupied(String tableId) async {
    if (_activeOrderForTable(tableId) != null &&
        _activeOrderForTable(tableId)!.isNotEmpty) {
      return;
    }
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/cashier/orders',
        data: {'table_id': tableId},
      );
      await refreshAll();
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
    }
  }

  Future<void> settleBill(String tableId) async {
    final oid = _activeOrderForTable(tableId);
    final table = tableById(tableId);
    if (table == null) {
      return;
    }
    if (oid == null || oid.isEmpty) {
      await refreshAll();
      return;
    }
    final lines = orderDetailsForTable(tableId);
    if (lines.isEmpty) {
      await refreshAll();
      return;
    }
    try {
      await _fetchOrderDetail(oid);
      final d = _orderDetailById[oid];
      final order = d?['order'] as Map<String, dynamic>? ?? {};
      final total = _dec(order['total_amount']);
      if (total <= 0) {
        await _dio.patch('/api/cashier/orders/$oid/complete');
        await refreshAll();
        return;
      }
      final pay = await _dio.post<Map<String, dynamic>>(
        '/api/cashier/payments',
        data: {
          'order_id': oid,
          'amount': total,
          'method': 'cash',
        },
      );
      final pid = pay.data?['id']?.toString();
      if (pid != null && pid.isNotEmpty) {
        await _dio.patch(
          '/api/cashier/payments/$pid',
          data: {'status': 'paid'},
        );
      }
      await _dio.patch('/api/cashier/orders/$oid/complete');
      await refreshAll();
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
    }
  }

  Future<void> addItemToOrder({
    required String tableId,
    required String menuItemId,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      return;
    }
    var oid = _activeOrderForTable(tableId);
    try {
      if (oid == null || oid.isEmpty) {
        await _dio.post<Map<String, dynamic>>(
          '/api/cashier/orders',
          data: {'table_id': tableId},
        );
        await _loadTablesAndActiveOrders();
        oid = _activeOrderForTable(tableId);
      }
      if (oid == null || oid.isEmpty) {
        return;
      }
      await _dio.patch(
        '/api/cashier/orders/$oid/items',
        data: {
          'actions': [
            {
              'action': 'add',
              'menu_item_id': menuItemId,
              'quantity': quantity,
            },
          ],
        },
      );
      await _fetchOrderDetail(oid);
      await _loadTablesAndActiveOrders();
      notifyListeners();
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
    }
  }
}
