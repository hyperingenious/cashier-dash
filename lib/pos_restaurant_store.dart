import 'dart:collection';
import 'dart:convert';

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

String _orderItemGroupKey(Map<String, dynamic> im) {
  final mid = im['menu_item_id']?.toString();
  if (mid != null && mid.isNotEmpty) {
    return 'm:$mid';
  }
  final name = (im['name_snapshot'] ?? '').toString();
  final price = _dec(im['price_snapshot']);
  return 'np:$name|${price.toStringAsFixed(4)}';
}

/// Combines duplicate API rows (same menu item) into one row for display.
List<Map<String, dynamic>> _mergeRawOrderItems(List<dynamic> items) {
  final map = <String, Map<String, dynamic>>{};
  for (final it in items) {
    if (it is! Map) {
      continue;
    }
    final im = Map<String, dynamic>.from(it);
    final qty = (im['quantity'] as num?)?.toInt() ?? 0;
    if (qty <= 0) {
      continue;
    }
    final key = _orderItemGroupKey(im);
    final prev = map[key];
    if (prev == null) {
      map[key] = im;
    } else {
      final pq = (prev['quantity'] as num?)?.toInt() ?? 0;
      prev['quantity'] = pq + qty;
    }
  }
  return map.values.toList();
}

String _dioErrorMessage(Object e) {
  if (e is DioException) {
    final uri = e.requestOptions.uri.toString();
    final method = e.requestOptions.method;
    final code = e.response?.statusCode;
    final data = e.response?.data;
    if (data is Map && data['error'] is String) {
      final base = data['error'] as String;
      if (code == 404) {
        return '$base ($method $uri returned 404). Backend may be outdated or API base URL is wrong.';
      }
      return base;
    }
    if (data is String && data.trim().isNotEmpty) {
      final base = data.trim();
      if (code == 404) {
        return '$base ($method $uri returned 404). Backend may be outdated or API base URL is wrong.';
      }
      return base;
    }
    if (code == 404) {
      return 'Endpoint not found: $method $uri (404). '
          'Make sure cashier service is updated and API base URL points to the backend root (example: http://localhost:8000).';
    }
    if (code != null) {
      return 'Request failed ($code): $method $uri';
    }
  }
  return e.toString();
}

class RestaurantStore extends ChangeNotifier {
  RestaurantStore._(this._dio, {this.cashierRestaurantId});

  /// Root URL only (e.g. `https://host:8000`). Paths use `/api/cashier/...`.
  /// Strips accidental `/api` or `/api/cashier` suffixes so requests are not doubled.
  static String normalizeApiBaseUrl(String input) {
    var u = input.trim();
    if (u.isEmpty) {
      return 'http://localhost:8000';
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (u.endsWith('/api/cashier')) {
      u = u.substring(0, u.length - '/api/cashier'.length);
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (u.endsWith('/api')) {
      u = u.substring(0, u.length - '/api'.length);
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u.isEmpty ? 'http://localhost:8000' : u;
  }

  factory RestaurantStore.connect({
    required String baseUrl,
    required String token,
    String? cashierRestaurantId,
  }) {
    final root = normalizeApiBaseUrl(baseUrl);
    final dio = Dio(
      BaseOptions(
        baseUrl: root,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );
    return RestaurantStore._(
      dio,
      cashierRestaurantId: cashierRestaurantId,
    )..refreshAll();
  }

  final Dio _dio;

  /// From login `user.restaurant_id` (same tenant as admin menu for this cashier).
  final String? cashierRestaurantId;

  final List<DiningTable> _tables = [];
  final List<FloorSection> _sections = [];
  final List<MenuItem> _menuItems = [];
  final List<TransactionRecord> _transactions = [];
  final List<OffPremOrderRow> _pickupQueue = [];
  final List<OffPremOrderRow> _deliveryQueue = [];
  final Map<String, Map<String, dynamic>> _orderDetailById = {};
  final Map<String, String?> _activeOrderIdByTableId = {};

  /// Tables where the cashier ran Print on the bill dialog (cleared when order ends).
  final Set<String> _billPrintedTableIds = {};

  /// Pickup / delivery orders: bill printed (no physical table).
  final Set<String> _billPrintedOrderIds = {};

  /// Brief green highlight after settle for off-prem orders.
  final Map<String, DateTime> _paidHighlightOrderUntil = {};

  /// Brief green highlight after settle/payment (wall-clock expiry).
  final Map<String, DateTime> _paidHighlightUntil = {};

  static const Duration _paidHighlightDuration = Duration(seconds: 90);

  String? lastError;

  /// Removing catalog rows is reserved for the admin app; cashiers only add via API.
  bool get canDeleteMenuItems => false;

  void clearLastError() {
    lastError = null;
    notifyListeners();
  }

  void _prunePaidHighlights() {
    final now = DateTime.now();
    _paidHighlightUntil.removeWhere((_, until) => !until.isAfter(now));
  }

  /// Tile color for floor plan / legend.
  TableFloorTone tableFloorToneFor(String tableId) {
    _prunePaidHighlights();
    final paidUntil = _paidHighlightUntil[tableId];
    if (paidUntil != null && DateTime.now().isBefore(paidUntil)) {
      return TableFloorTone.paid;
    }
    if (!hasActiveOrder(tableId)) {
      return TableFloorTone.empty;
    }
    if (_billPrintedTableIds.contains(tableId)) {
      return TableFloorTone.billPrinted;
    }
    return TableFloorTone.orderOpen;
  }

  void markBillPrinted(String tableId) {
    if (!hasActiveOrder(tableId)) {
      return;
    }
    _billPrintedTableIds.add(tableId);
    notifyListeners();
  }

  void markTablePaidHighlight(String tableId) {
    _billPrintedTableIds.remove(tableId);
    _paidHighlightUntil[tableId] =
        DateTime.now().add(_paidHighlightDuration);
    notifyListeners();
  }

  void _syncFloorToneWithTables() {
    for (final t in _tables) {
      if (hasActiveOrder(t.id)) {
        _paidHighlightUntil.remove(t.id);
      }
    }
    _billPrintedTableIds.removeWhere((id) => !hasActiveOrder(id));
  }

  UnmodifiableListView<DiningTable> get tables =>
      UnmodifiableListView(_tables);
  UnmodifiableListView<FloorSection> get sections =>
      UnmodifiableListView(_sections);
  UnmodifiableListView<MenuItem> get menuItems =>
      UnmodifiableListView(_menuItems);
  UnmodifiableListView<TransactionRecord> get transactions =>
      UnmodifiableListView(_transactions);

  UnmodifiableListView<OffPremOrderRow> get pickupQueue =>
      UnmodifiableListView(_pickupQueue);

  UnmodifiableListView<OffPremOrderRow> get deliveryQueue =>
      UnmodifiableListView(_deliveryQueue);

  Future<void> refreshAll() async {
    lastError = null;
    final errs = <String>[];
    try {
      await _loadMenu();
    } catch (e) {
      errs.add('Menu: ${_dioErrorMessage(e)}');
    }
    try {
      await _loadSections();
    } catch (e) {
      errs.add('Sections: ${_dioErrorMessage(e)}');
    }
    try {
      await _loadTablesAndActiveOrders();
    } catch (e) {
      errs.add('Tables: ${_dioErrorMessage(e)}');
    }
    try {
      await _loadCompletedTransactions();
    } catch (e) {
      errs.add('History: ${_dioErrorMessage(e)}');
    }
    try {
      await refreshOffPremQueues();
    } catch (e) {
      errs.add('Pickup/Delivery: ${_dioErrorMessage(e)}');
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
      lastError = '${lastError ?? ''}\nMenu refresh: ${_dioErrorMessage(e)}'.trim();
    }
    notifyListeners();
  }

  List<dynamic> _decodeJsonList(dynamic raw) {
    if (raw == null) {
      return [];
    }
    if (raw is List) {
      return raw;
    }
    if (raw is String) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded;
      }
    }
    throw Exception(
      'Menu API expected a JSON array, got ${raw.runtimeType}',
    );
  }

  Map<String, dynamic> _rowAsMap(dynamic item) {
    if (item is Map<String, dynamic>) {
      return item;
    }
    if (item is Map) {
      return Map<String, dynamic>.from(item);
    }
    throw Exception('Menu row must be an object, got ${item.runtimeType}');
  }

  Future<void> _loadMenu() async {
    final res = await _dio.get<dynamic>('/api/cashier/menu');
    final rows = _decodeJsonList(res.data);
    _menuItems
      ..clear()
      ..addAll(
        rows.map((dynamic item) {
          final m = _rowAsMap(item);
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
    _syncFloorToneWithTables();
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

  Future<void> ensureOrderLoaded(String orderId) async {
    if (orderId.isEmpty) {
      return;
    }
    await _fetchOrderDetail(orderId);
    notifyListeners();
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
        final rawItems = body['items'] as List<dynamic>? ?? const [];
        final items = _mergeRawOrderItems(rawItems);
        final tn = order['table_number'];
        final tableName =
            tn != null ? 'T-$tn' : 'Order ${id.substring(0, 8)}';
        final created = order['created_at']?.toString();
        final ts = DateTime.tryParse(created ?? '') ?? DateTime.now();
        final lines = <BillLine>[];
        for (final im in items) {
          final qty = (im['quantity'] as num?)?.toInt() ?? 0;
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

  List<BillLine> _linesForOrderId(String? orderId) {
    if (orderId == null || orderId.isEmpty) {
      return const [];
    }
    final d = _orderDetailById[orderId];
    final rawItems = d?['items'] as List<dynamic>? ?? const [];
    final items = _mergeRawOrderItems(rawItems);
    final out = <BillLine>[];
    for (final im in items) {
      final qty = (im['quantity'] as num?)?.toInt() ?? 0;
      final price = _dec(im['price_snapshot']);
      final name = (im['name_snapshot'] ?? '').toString();
      final idRaw = im['id'];
      final oidStr = idRaw == null ? null : idRaw.toString().trim();
      final midRaw = im['menu_item_id'];
      final midStr = midRaw == null ? null : midRaw.toString().trim();
      out.add(
        BillLine(
          itemName: name,
          unitPrice: price,
          quantity: qty,
          lineTotal: price * qty,
          orderItemId: (oidStr == null || oidStr.isEmpty) ? null : oidStr,
          menuItemId: (midStr == null || midStr.isEmpty) ? null : midStr,
        ),
      );
    }
    return out;
  }

  List<BillLine> orderDetailsForTable(String tableId) {
    final oid = _activeOrderForTable(tableId);
    return _linesForOrderId(oid);
  }

  List<BillLine> orderDetailsForOrderId(String orderId) {
    return _linesForOrderId(orderId);
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

  BillTotals calculateBillForOrderId(String orderId) {
    final lines = _linesForOrderId(orderId);
    final subtotal = lines.fold<double>(0, (a, b) => a + b.lineTotal);
    final d = _orderDetailById[orderId];
    final order = d?['order'] as Map<String, dynamic>?;
    final total = order != null ? _dec(order['total_amount']) : subtotal;
    final discount = order != null ? _dec(order['discount']) : 0.0;
    const tax = 0.0;
    return BillTotals(
      subtotal: subtotal,
      tax: tax,
      total: total > 0 ? total : (subtotal - discount).clamp(0, double.infinity),
    );
  }

  String? _orderStatusFromDetail(String orderId) {
    final d = _orderDetailById[orderId];
    final o = d?['order'] as Map<String, dynamic>?;
    return o?['status']?.toString();
  }

  bool _isActiveOrderStatus(String? s) {
    if (s == null || s.isEmpty) {
      return false;
    }
    return const {
      'pending',
      'accepted',
      'preparing',
      'ready',
      'served',
    }.contains(s);
  }

  void _prunePaidOrderHighlights() {
    final now = DateTime.now();
    _paidHighlightOrderUntil
        .removeWhere((_, until) => !until.isAfter(now));
  }

  /// Floor-style tone for pickup/delivery queue tiles (legend matches).
  TableFloorTone channelOrderToneFor(String orderId) {
    _prunePaidOrderHighlights();
    final paidUntil = _paidHighlightOrderUntil[orderId];
    if (paidUntil != null && DateTime.now().isBefore(paidUntil)) {
      return TableFloorTone.paid;
    }
    final st = _orderStatusFromDetail(orderId);
    if (!_isActiveOrderStatus(st)) {
      return TableFloorTone.empty;
    }
    if (_billPrintedOrderIds.contains(orderId)) {
      return TableFloorTone.billPrinted;
    }
    return TableFloorTone.orderOpen;
  }

  void markBillPrintedForOrder(String orderId) {
    if (!_isActiveOrderStatus(_orderStatusFromDetail(orderId))) {
      return;
    }
    _billPrintedOrderIds.add(orderId);
    notifyListeners();
  }

  void _markChannelOrderPaidHighlight(String orderId) {
    _billPrintedOrderIds.remove(orderId);
    _paidHighlightOrderUntil[orderId] =
        DateTime.now().add(_paidHighlightDuration);
    notifyListeners();
  }

  Future<void> refreshOffPremQueues() async {
    _pickupQueue.clear();
    _deliveryQueue.clear();
    for (final ch in const ['pickup', 'delivery']) {
      try {
        final res = await _dio.get<List<dynamic>>(
          '/api/cashier/orders',
          queryParameters: <String, dynamic>{
            'source': ch,
            'active': true,
          },
        );
        final list = res.data ?? const [];
        final rows = <OffPremOrderRow>[];
        for (final raw in list) {
          if (raw is! Map) {
            continue;
          }
          final m = Map<String, dynamic>.from(raw);
          final id = (m['id'] ?? '').toString();
          if (id.isEmpty) {
            continue;
          }
          rows.add(
            OffPremOrderRow(
              id: id,
              total: _dec(m['total_amount']),
              status: (m['status'] ?? '').toString(),
              source: (m['source'] ?? ch).toString(),
              createdAt: DateTime.tryParse((m['created_at'] ?? '').toString()),
            ),
          );
        }
        if (ch == 'pickup') {
          _pickupQueue.addAll(rows);
        } else {
          _deliveryQueue.addAll(rows);
        }
      } catch (_) {
        // leave queue empty; lastError set elsewhere if needed
      }
    }
    _syncChannelBillPrinted();
    notifyListeners();
  }

  void _syncChannelBillPrinted() {
    final activeIds = <String>{
      ..._pickupQueue.map((e) => e.id),
      ..._deliveryQueue.map((e) => e.id),
    };
    _billPrintedOrderIds.removeWhere((id) => !activeIds.contains(id));
  }

  Future<String?> createOffPremOrder(String channel) async {
    final c = channel.toLowerCase();
    if (c != 'pickup' && c != 'delivery') {
      return null;
    }
    lastError = null;
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/cashier/orders',
        data: <String, dynamic>{'channel': c},
      );
      final id = res.data?['id']?.toString();
      if (id != null && id.isNotEmpty) {
        await _fetchOrderDetail(id);
        await refreshOffPremQueues();
        notifyListeners();
        return id;
      }
    } catch (e) {
      lastError = _dioErrorMessage(e);
      notifyListeners();
    }
    return null;
  }

  Future<void> addItemToOrderId({
    required String orderId,
    required String menuItemId,
    required int quantity,
  }) async {
    if (quantity <= 0 || orderId.isEmpty) {
      return;
    }
    lastError = null;
    try {
      await _dio.patch(
        '/api/cashier/orders/$orderId/items',
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
      await _fetchOrderDetail(orderId);
      await refreshOffPremQueues();
      notifyListeners();
    } catch (e) {
      lastError = _dioErrorMessage(e);
      notifyListeners();
    }
  }

  Future<void> removeOrderItemLineForOrderId(
    String orderId,
    String orderItemId,
  ) async {
    if (orderId.isEmpty || orderItemId.isEmpty) {
      return;
    }
    lastError = null;
    try {
      await _dio.patch(
        '/api/cashier/orders/$orderId/items',
        data: {
          'actions': [
            {
              'action': 'remove',
              'order_item_id': orderItemId,
            },
          ],
        },
      );
      await _fetchOrderDetail(orderId);
      await refreshOffPremQueues();
      notifyListeners();
    } catch (e) {
      lastError = _dioErrorMessage(e);
      notifyListeners();
    }
  }

  Future<void> setOrderItemQuantityForOrderId(
    String orderId,
    String orderItemId,
    int newQuantity,
  ) async {
    if (newQuantity <= 0) {
      await removeOrderItemLineForOrderId(orderId, orderItemId);
      return;
    }
    if (orderId.isEmpty || orderItemId.isEmpty) {
      return;
    }
    lastError = null;
    try {
      await _dio.patch(
        '/api/cashier/orders/$orderId/items',
        data: {
          'actions': [
            {
              'action': 'update_quantity',
              'order_item_id': orderItemId,
              'quantity': newQuantity,
            },
          ],
        },
      );
      await _fetchOrderDetail(orderId);
      await refreshOffPremQueues();
      notifyListeners();
    } catch (e) {
      lastError = _dioErrorMessage(e);
      notifyListeners();
    }
  }

  static const Set<String> _paymentMethods = {'cash', 'upi', 'card'};

  String _normalizePaymentMethod(String? method) {
    final m = (method ?? 'cash').toLowerCase();
    return _paymentMethods.contains(m) ? m : 'cash';
  }

  /// Records full payment with the given method and completes the order
  /// (pickup / delivery). [paymentMethod] must be `cash`, `upi`, or `card`.
  Future<void> settleOrderById(
    String orderId, {
    String paymentMethod = 'cash',
  }) async {
    if (orderId.isEmpty) {
      return;
    }
    final m = _normalizePaymentMethod(paymentMethod);
    final lines = _linesForOrderId(orderId);
    if (lines.isEmpty) {
      await refreshOffPremQueues();
      return;
    }
    try {
      await _fetchOrderDetail(orderId);
      final d = _orderDetailById[orderId];
      final order = d?['order'] as Map<String, dynamic>? ?? {};
      final total = _dec(order['total_amount']);
      if (total <= 0) {
        await _dio.patch('/api/cashier/orders/$orderId/complete');
        _markChannelOrderPaidHighlight(orderId);
        await refreshAll();
        return;
      }
      final pay = await _dio.post<Map<String, dynamic>>(
        '/api/cashier/payments',
        data: {
          'order_id': orderId,
          'amount': total,
          'method': m,
        },
      );
      final pid = pay.data?['id']?.toString();
      if (pid != null && pid.isNotEmpty) {
        await _dio.patch(
          '/api/cashier/payments/$pid',
          data: {'status': 'paid'},
        );
      }
      await _dio.patch('/api/cashier/orders/$orderId/complete');
      _markChannelOrderPaidHighlight(orderId);
      await refreshAll();
    } catch (e) {
      lastError = _dioErrorMessage(e);
      notifyListeners();
    }
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

  /// Dine-in: record full payment and free the table.
  /// [paymentMethod]: `cash`, `upi`, or `card`.
  Future<void> settleBill(
    String tableId, {
    String paymentMethod = 'cash',
  }) async {
    final m = _normalizePaymentMethod(paymentMethod);
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
        markTablePaidHighlight(tableId);
        await refreshAll();
        return;
      }
      final pay = await _dio.post<Map<String, dynamic>>(
        '/api/cashier/payments',
        data: {
          'order_id': oid,
          'amount': total,
          'method': m,
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
      markTablePaidHighlight(tableId);
      await refreshAll();
    } catch (e) {
      lastError = _dioErrorMessage(e);
      notifyListeners();
    }
  }

  /// Same as [settleBill]: records payment for the full balance and completes
  /// the order so the table is free (green highlight on the floor).
  Future<void> markTablePaid(
    String tableId, {
    String paymentMethod = 'cash',
  }) =>
      settleBill(tableId, paymentMethod: paymentMethod);

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
      lastError = _dioErrorMessage(e);
      notifyListeners();
    }
  }

  /// Remove one `order_items` row (or the merged line that maps to it).
  Future<void> removeOrderItemLine(
    String tableId,
    String orderItemId,
  ) async {
    final oid = _activeOrderForTable(tableId);
    if (oid == null || oid.isEmpty || orderItemId.isEmpty) {
      return;
    }
    lastError = null;
    try {
      await _dio.patch(
        '/api/cashier/orders/$oid/items',
        data: {
          'actions': [
            {
              'action': 'remove',
              'order_item_id': orderItemId,
            },
          ],
        },
      );
      await _fetchOrderDetail(oid);
      await _loadTablesAndActiveOrders();
      notifyListeners();
    } catch (e) {
      lastError = _dioErrorMessage(e);
      notifyListeners();
    }
  }

  /// Set line quantity. If [newQuantity] is 0 or negative, removes the line.
  Future<void> setOrderItemQuantity(
    String tableId,
    String orderItemId,
    int newQuantity,
  ) async {
    if (newQuantity <= 0) {
      await removeOrderItemLine(tableId, orderItemId);
      return;
    }
    final oid = _activeOrderForTable(tableId);
    if (oid == null || oid.isEmpty || orderItemId.isEmpty) {
      return;
    }
    lastError = null;
    try {
      await _dio.patch(
        '/api/cashier/orders/$oid/items',
        data: {
          'actions': [
            {
              'action': 'update_quantity',
              'order_item_id': orderItemId,
              'quantity': newQuantity,
            },
          ],
        },
      );
      await _fetchOrderDetail(oid);
      await _loadTablesAndActiveOrders();
      notifyListeners();
    } catch (e) {
      lastError = _dioErrorMessage(e);
      notifyListeners();
    }
  }

  Future<void> cancelOrderById(String orderId) async {
    if (orderId.isEmpty) {
      return;
    }
    lastError = null;
    try {
      await _dio.patch('/api/cashier/orders/$orderId/cancel');
      _orderDetailById.remove(orderId);
      _billPrintedOrderIds.remove(orderId);
      _paidHighlightOrderUntil.remove(orderId);
      await _loadTablesAndActiveOrders();
      await refreshOffPremQueues();
      _syncFloorToneWithTables();
      notifyListeners();
    } catch (e) {
      lastError = _dioErrorMessage(e);
      notifyListeners();
    }
  }

  /// Mark the table's active order as cancelled (frees the table for a new order).
  Future<void> cancelActiveOrder(String tableId) async {
    final oid = _activeOrderForTable(tableId);
    if (oid == null || oid.isEmpty) {
      return;
    }
    await cancelOrderById(oid);
  }
}
