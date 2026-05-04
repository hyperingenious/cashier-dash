enum TableStatus { available, occupied }

/// Cashier floor tile colors (see legend on floor plan).
enum TableFloorTone {
  /// No active order — grey.
  empty,
  /// Active order, bill not printed yet — amber.
  orderOpen,
  /// Bill/receipt printed — purple.
  billPrinted,
  /// Payment settled (recent highlight) — green.
  paid,
}

extension TableStatusX on TableStatus {
  String get label {
    switch (this) {
      case TableStatus.available:
        return 'Available';
      case TableStatus.occupied:
        return 'Occupied';
    }
  }
}

/// A named area on the floor (e.g. Family, Garden) — from `floor_sections`.
class FloorSection {
  const FloorSection({
    required this.id,
    required this.name,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final int sortOrder;
}

class DiningTable {
  const DiningTable({
    required this.id,
    required this.name,
    required this.capacity,
    required this.status,
    this.gridX = 0,
    this.gridY = 0,
    this.tableNumber,
    this.sectionId,
    this.sectionName,
    this.label,
    this.orderStartedAt,
    this.activeOrderTotal,
  });

  final String id;
  /// Display name (label or T{n}).
  final String name;
  final int capacity;
  final TableStatus status;
  final int gridX;
  final int gridY;
  /// Slot within section from API (`table_number`).
  final int? tableNumber;
  final String? sectionId;
  final String? sectionName;
  final String? label;
  final DateTime? orderStartedAt;
  final double? activeOrderTotal;

  DiningTable copyWith({
    String? id,
    String? name,
    int? capacity,
    TableStatus? status,
    int? gridX,
    int? gridY,
    int? tableNumber,
    String? sectionId,
    String? sectionName,
    String? label,
    DateTime? orderStartedAt,
    double? activeOrderTotal,
  }) {
    return DiningTable(
      id: id ?? this.id,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      gridX: gridX ?? this.gridX,
      gridY: gridY ?? this.gridY,
      tableNumber: tableNumber ?? this.tableNumber,
      sectionId: sectionId ?? this.sectionId,
      sectionName: sectionName ?? this.sectionName,
      label: label ?? this.label,
      orderStartedAt: orderStartedAt ?? this.orderStartedAt,
      activeOrderTotal: activeOrderTotal ?? this.activeOrderTotal,
    );
  }

  String get statusLabel => status.label;
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
  });

  final String id;
  final String name;
  final String category;
  final double price;

  String get formattedPrice => price.toCurrency();
}

class BillLine {
  const BillLine({
    required this.itemName,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    this.orderItemId,
    this.menuItemId,
  });

  final String itemName;
  final double unitPrice;
  final int quantity;
  final double lineTotal;
  /// `order_items.id` for the active order; used to remove or change quantity.
  final String? orderItemId;
  /// `menu_items.id` when known; used to add units with the same API as Quick Add.
  final String? menuItemId;

  String get unitPriceFormatted => unitPrice.toCurrency();
  String get lineTotalFormatted => lineTotal.toCurrency();
}

class BillTotals {
  const BillTotals({
    required this.subtotal,
    required this.tax,
    required this.total,
  });

  final double subtotal;
  final double tax;
  final double total;

  String get subtotalFormatted => subtotal.toCurrency();
  String get taxFormatted => tax.toCurrency();
  String get totalFormatted => total.toCurrency();
}

class TransactionRecord {
  TransactionRecord({
    required this.id,
    required this.tableName,
    required this.timestamp,
    required this.lines,
    required this.totals,
  });

  final String id;
  final String tableName;
  final DateTime timestamp;
  final List<BillLine> lines;
  final BillTotals totals;
}

extension NumCurrencyFormatting on num {
  String toCurrency() {
    return '₹${toStringAsFixed(2)}';
  }
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) {
      return null;
    }
    return first;
  }
}
