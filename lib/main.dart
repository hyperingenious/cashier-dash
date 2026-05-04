import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'pos_models.dart';
import 'pos_restaurant_store.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

void main() {
  runApp(const CashierDashApp());
}

class PosColors {
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceHighlight = Color(0xFFF1F5F9);
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryGlow = Color(0xFF3B82F6);
  static const Color accent = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color textMain = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
}

/// Background + status border for floor table tiles (see [_FloorPlanLegend]).
(Color bg, Color border) floorToneStyle(TableFloorTone tone) {
  return switch (tone) {
    TableFloorTone.empty => (
        const Color(0xFFF3F4F6),
        const Color(0xFFD1D5DB),
      ),
    TableFloorTone.orderOpen => (
        const Color(0xFFFFF9E6),
        const Color(0xFFFBBF24),
      ),
    TableFloorTone.billPrinted => (
        const Color(0xFFF3E8FF),
        const Color(0xFFA855F7),
      ),
    TableFloorTone.paid => (
        const Color(0xFFDCFCE7),
        const Color(0xFF22C55E),
      ),
  };
}

class _FloorPlanLegend extends StatelessWidget {
  const _FloorPlanLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: PosColors.surfaceHighlight.withOpacity(0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PosColors.border),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        children: [
          _chip(TableFloorTone.empty, 'Empty'),
          _chip(TableFloorTone.orderOpen, 'Order open'),
          _chip(TableFloorTone.billPrinted, 'Bill printed'),
          _chip(TableFloorTone.paid, 'Paid'),
        ],
      ),
    );
  }

  Widget _chip(TableFloorTone tone, String label) {
    final s = floorToneStyle(tone);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: s.$1,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: s.$2, width: 1.2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: PosColors.textMain,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class CashierDashApp extends StatefulWidget {
  const CashierDashApp({super.key});

  @override
  State<CashierDashApp> createState() => _CashierDashAppState();
}

class _CashierDashAppState extends State<CashierDashApp> {
  RestaurantStore? _store;
  String _cashierName = '';

  void _handleLogin(String token, String cashierName, String? restaurantId) {
    setState(() {
      _store = RestaurantStore.connect(
        baseUrl: apiBaseUrl,
        token: token,
        cashierRestaurantId: restaurantId,
      );
      _cashierName = cashierName;
    });
  }

  void _handleLogout() {
    setState(() {
      _store = null;
      _cashierName = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.outfitTextTheme(ThemeData.light().textTheme);

    return MaterialApp(
      title: 'Bawarchi Cashier',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: PosColors.background,
        colorScheme: const ColorScheme.light(
          primary: PosColors.primary,
          secondary: PosColors.accent,
          surface: PosColors.surface,
          error: PosColors.error,
        ),
        textTheme: textTheme,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(color: PosColors.textMuted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: PosColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: PosColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: PosColors.primary),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: PosColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: PosColors.textMain,
            side: const BorderSide(color: PosColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: PosColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
      home: _store != null
          ? DashboardScreen(
              cashierName: _cashierName,
              store: _store!,
              onLogout: _handleLogout,
            )
          : LoginScreen(onLogin: _handleLogin),
    );
  }
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? color;
  final BoxBorder? border;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 8.0,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(color: PosColors.border.withOpacity(0.5)),
        color: color ?? Colors.white,
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.onLogin, super.key});

  final void Function(String token, String cashierName, String? restaurantId)
      onLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  late AnimationController _animController;
  bool _busy = false;
  String? _loginError;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _loginError = null;
    });
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: RestaurantStore.normalizeApiBaseUrl(apiBaseUrl),
          headers: {'Content-Type': 'application/json'},
        ),
      );
      final res = await dio.post<Map<String, dynamic>>(
        '/api/cashier/login',
        data: {
          'phone': _phoneController.text.trim(),
          'password': _passwordController.text.trim(),
        },
      );
      final token = res.data?['token'] as String?;
      final user = res.data?['user'] as Map<String, dynamic>?;
      final name = user?['name'] as String? ?? 'Cashier';
      final restaurantId = user?['restaurant_id']?.toString();
      if (token == null || token.isEmpty) {
        throw Exception('No token in response');
      }
      if (!mounted) {
        return;
      }
      widget.onLogin(token, name, restaurantId);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _loginError = 'Sign-in failed. Check phone and password.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: GlassContainer(
              padding: const EdgeInsets.all(40),
              child: SizedBox(
                width: 340,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: PosColors.primary.withOpacity(0.1),
                          border: Border.all(
                              color: PosColors.primary.withOpacity(0.3)),
                        ),
                        child: const Icon(
                          Icons.restaurant,
                          size: 48,
                          color: PosColors.primaryGlow,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Bawarchi',
                        style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: PosColors.textMain,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in with your cashier phone and password.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: PosColors.textMuted,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 40),
                      TextFormField(
                        controller: _phoneController,
                        style: const TextStyle(color: PosColors.textMain),
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          prefixIcon: Icon(Icons.phone_outlined,
                              color: PosColors.textMuted),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter phone number'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(color: PosColors.textMain),
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline,
                              color: PosColors.textMuted),
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty
                                ? 'Enter password'
                                : null,
                      ),
                      if (_loginError != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _loginError!,
                          style: GoogleFonts.outfit(
                            color: PosColors.error,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _busy ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PosColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            _busy ? 'Signing in…' : 'Access Terminal',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum PosSection { floor, menu, billing, transactions }

extension PosSectionX on PosSection {
  String get title {
    switch (this) {
      case PosSection.floor:
        return 'Floor Control';
      case PosSection.menu:
        return 'Menu Catalog';
      case PosSection.billing:
        return 'Billing Center';
      case PosSection.transactions:
        return 'Transaction History';
    }
  }

  String get subtitle {
    switch (this) {
      case PosSection.floor:
        return 'Manage dining tables, occupancy, and live orders.';
      case PosSection.menu:
        return 'Maintain item catalog used by cashiers and KOT.';
      case PosSection.billing:
        return 'Review active bills and complete settlements.';
      case PosSection.transactions:
        return 'View and manage all past settled transactions.';
    }
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.cashierName,
    required this.store,
    required this.onLogout,
    super.key,
  });

  final String cashierName;
  final RestaurantStore store;
  final VoidCallback onLogout;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  PosSection _section = PosSection.floor;
  String? _selectedTableId;

  DiningTable? get _selectedTable {
    if (_selectedTableId == null) return null;
    return widget.store.tableById(_selectedTableId!);
  }

  Future<void> _openCreateSectionDialog() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('New section', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Section name',
            hintText: 'e.g. Family, बगीचा',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (!mounted || name == null || name.isEmpty) return;

    await widget.store.createSection(name);
    if (mounted) setState(() {});
    if (mounted && widget.store.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.store.lastError!)),
      );
    }
  }

  Future<void> _openCreateTableInSectionDialog(String sectionId) async {
    final numCtrl = TextEditingController(
      text: '${widget.store.suggestNextTableNumber(sectionId)}',
    );
    final labelCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add table', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Table number (within section)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Display label (optional)',
                hintText: 'e.g. B1, G3',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (!mounted || ok != true) return;

    final n = int.tryParse(numCtrl.text.trim());
    if (n == null || n <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid table number')),
      );
      return;
    }

    final label = labelCtrl.text.trim();
    final table = await widget.store.addTableInSection(
      sectionId: sectionId,
      tableNumber: n,
      label: label.isEmpty ? null : label,
    );

    if (!mounted) return;

    if (table != null) {
      setState(() => _selectedTableId = table.id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.store.lastError ?? 'Could not create table',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDeleteSection(FloorSection section) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete section?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'Remove "${section.name}"? Tables must be removed from this section first.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PosColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted || go != true) return;

    final success = await widget.store.deleteSection(section.id);
    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.store.lastError ?? 'Could not delete section',
          ),
        ),
      );
    } else {
      setState(() {});
    }
  }

  void _showBillPreview(DiningTable table) {
    final lines = widget.store.orderDetailsForTable(table.id);
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No order lines yet')),
      );
      return;
    }
    final totals = widget.store.calculateBill(table.id);
    showDialog<void>(
      context: context,
      builder: (_) => BillReceiptDialog(
        title: 'Preview',
        tableName: table.name,
        timestamp: DateTime.now(),
        lines: lines,
        totals: totals,
        onBillPrinted: () => widget.store.markBillPrinted(table.id),
      ),
    );
  }

  Future<void> _openAddMenuDialog() async {
    final draft = await showDialog<MenuDraft>(
      context: context,
      builder: (_) => const AddMenuItemDialog(),
    );

    if (!mounted || draft == null) return;

    final ok = await widget.store.addMenuItem(
      name: draft.name,
      category: draft.category,
      price: draft.price,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.store.lastError ?? 'Could not add menu item',
          ),
        ),
      );
    }
  }

  Future<void> _openAddOrderDialogForSelected() async {
    final table = _selectedTable;
    if (table == null) return;

    if (widget.store.menuItems.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No menu items yet. Add them from the Menu tab.'),
        ),
      );
      return;
    }

    final draft = await showDialog<OrderDraft>(
      context: context,
      builder: (_) => AddOrderDialog(menuItems: widget.store.menuItems.toList()),
    );

    if (!mounted || draft == null) return;

    await widget.store.addItemToOrder(
      tableId: table.id,
      menuItemId: draft.menuItemId,
      quantity: draft.quantity,
    );
    if (mounted) setState(() {});
  }

  Future<void> _removeSelectedTable() async {
    final table = _selectedTable;
    if (table == null) return;

    final success = await widget.store.removeTable(table.id);
    if (success) {
      setState(() {
        _selectedTableId = null;
      });
      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cannot delete a table with an active order.'),
      ),
    );
  }

  Future<void> _removeMenuItem(MenuItem item) async {
    if (!widget.store.canDeleteMenuItems) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only an administrator can remove menu items.'),
        ),
      );
      return;
    }
    final success = await widget.store.removeMenuItem(item.id);
    if (success || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cannot delete item used in active orders.'),
      ),
    );
  }

  void _quickAddToSelected(MenuItem item) {
    final table = _selectedTable;
    if (table == null) return;

    widget.store
        .addItemToOrder(
          tableId: table.id,
          menuItemId: item.id,
          quantity: 1,
        )
        .then((_) {
          if (mounted) setState(() {});
        });
  }

  Widget _buildSectionContent() {
    switch (_section) {
      case PosSection.floor:
        return RestaurantFloorTab(
          store: widget.store,
          selectedTableId: _selectedTableId,
          onSelectTable: (table) {
            setState(() {
              _selectedTableId = table.id;
            });
          },
          onAddSection: _openCreateSectionDialog,
          onAddTableInSection: _openCreateTableInSectionDialog,
          onDeleteSection: _confirmDeleteSection,
          onBillPreview: _showBillPreview,
          onAddOrder: _openAddOrderDialogForSelected,
          onQuickAddItem: _quickAddToSelected,
          onSettle: () {
            final table = _selectedTable;
            if (table != null) {
              widget.store.settleBill(table.id).then((_) {
                if (mounted) setState(() {});
              });
            }
          },
          onMarkOccupied: () {
            final table = _selectedTable;
            if (table != null) {
              widget.store.markTableOccupied(table.id).then((_) {
                if (mounted) setState(() {});
              });
            }
          },
          onDeleteTable: _removeSelectedTable,
        );
      case PosSection.menu:
        return MenuSection(
          store: widget.store,
          canDeleteMenuItems: widget.store.canDeleteMenuItems,
          onAddMenuItem: _openAddMenuDialog,
          onDeleteMenuItem: _removeMenuItem,
        );
      case PosSection.billing:
        return BillingSection(
          store: widget.store,
          onSettle: (table) {
            widget.store.settleBill(table.id).then((_) {
              if (mounted) setState(() {});
            });
          },
        );
      case PosSection.transactions:
        return TransactionsSection(
          store: widget.store,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
            child: AnimatedBuilder(
              animation: widget.store,
              builder: (context, _) {
                return Row(
                  children: [
                    PosSidebar(
                      section: _section,
                      onChangeSection: (next) {
                        setState(() {
                          _section = next;
                        });
                        if (next == PosSection.menu) {
                          widget.store.refreshMenu().then((_) {
                            if (mounted) setState(() {});
                          });
                        }
                      },
                      onLogout: widget.onLogout,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _DashboardLoadBanner(store: widget.store),
                          DashboardTopBar(
                            section: _section,
                            cashierName: widget.cashierName,
                            restaurantId: widget.store.cashierRestaurantId,
                          ),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              child: KeyedSubtree(
                                key: ValueKey(_section),
                                child: _buildSectionContent(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
    );
  }
}

class PosSidebar extends StatelessWidget {
  const PosSidebar({
    required this.section,
    required this.onChangeSection,
    required this.onLogout,
    super.key,
  });

  final PosSection section;
  final ValueChanged<PosSection> onChangeSection;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      margin: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: PosColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.restaurant, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 36),
            _SidebarItem(
              icon: Icons.grid_view_rounded,
              tooltip: 'Floor Plan',
              isSelected: section == PosSection.floor,
              onTap: () => onChangeSection(PosSection.floor),
            ),
            const SizedBox(height: 16),
            _SidebarItem(
              icon: Icons.restaurant_menu_rounded,
              tooltip: 'Menu Catalog',
              isSelected: section == PosSection.menu,
              onTap: () => onChangeSection(PosSection.menu),
            ),
            const SizedBox(height: 16),
            _SidebarItem(
              icon: Icons.receipt_long_rounded,
              tooltip: 'Billing Queue',
              isSelected: section == PosSection.billing,
              onTap: () => onChangeSection(PosSection.billing),
            ),
            const SizedBox(height: 16),
            _SidebarItem(
              icon: Icons.history_rounded,
              tooltip: 'Transactions',
              isSelected: section == PosSection.transactions,
              onTap: () => onChangeSection(PosSection.transactions),
            ),
            const Spacer(),
            _SidebarItem(
              icon: Icons.logout_rounded,
              tooltip: 'Logout',
              isSelected: false,
              onTap: onLogout,
              color: PosColors.error,
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _SidebarItem({
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? PosColors.primary;
    final iconColor = isSelected ? activeColor : PosColors.textMuted;

    return Tooltip(
      message: tooltip,
      preferBelow: false,
      verticalOffset: 30,
      textStyle: GoogleFonts.outfit(color: PosColors.textMain, fontSize: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PosColors.border),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? activeColor.withOpacity(0.3)
                  : Colors.transparent,
            ),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }
}

class _DashboardLoadBanner extends StatelessWidget {
  const _DashboardLoadBanner({required this.store});

  final RestaurantStore store;

  @override
  Widget build(BuildContext context) {
    final err = store.lastError;
    if (err == null || err.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Material(
      color: const Color(0xFFFFF7ED),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFEA580C),
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                err,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: const Color(0xFF9A3412),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                store.refreshAll();
              },
              child: const Text('Retry'),
            ),
            TextButton(
              onPressed: store.clearLastError,
              child: const Text('Dismiss'),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardTopBar extends StatelessWidget {
  const DashboardTopBar({
    required this.section,
    required this.cashierName,
    this.restaurantId,
    super.key,
  });

  final PosSection section;
  final String cashierName;
  final String? restaurantId;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(6, 12, 12, 12),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: PosColors.textMain,
                  ),
                ),
                Text(
                  section.subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: PosColors.textMuted,
                  ),
                ),
                if (restaurantId case final String rid when rid.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Signed-in restaurant: $rid — menu is only items for this tenant. '
                    'In Admin, select the same restaurant when adding menu items.',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: PosColors.textMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: PosColors.surfaceHighlight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: PosColors.border.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 18, color: PosColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.outfit(
                      color: PosColors.textMain,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 40,
              padding: const EdgeInsets.only(left: 4, right: 12, top: 4, bottom: 4),
              decoration: BoxDecoration(
                color: PosColors.surfaceHighlight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: PosColors.border.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: PosColors.primary.withOpacity(0.2),
                    child: Text(
                      cashierName.isNotEmpty
                          ? cashierName[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.outfit(
                        color: PosColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    cashierName,
                    style: GoogleFonts.outfit(
                      color: PosColors.textMain,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RestaurantFloorTab extends StatelessWidget {
  const RestaurantFloorTab({
    required this.store,
    required this.selectedTableId,
    required this.onSelectTable,
    required this.onAddSection,
    required this.onAddTableInSection,
    required this.onDeleteSection,
    required this.onBillPreview,
    required this.onAddOrder,
    required this.onQuickAddItem,
    required this.onSettle,
    required this.onMarkOccupied,
    required this.onDeleteTable,
    super.key,
  });

  final RestaurantStore store;
  final String? selectedTableId;
  final ValueChanged<DiningTable> onSelectTable;
  final VoidCallback onAddSection;
  final void Function(String sectionId) onAddTableInSection;
  final void Function(FloorSection section) onDeleteSection;
  final void Function(DiningTable table) onBillPreview;
  final VoidCallback onAddOrder;
  final ValueChanged<MenuItem> onQuickAddItem;
  final VoidCallback onSettle;
  final VoidCallback onMarkOccupied;
  final VoidCallback onDeleteTable;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: GlassContainer(
            borderRadius: 0,
            border: const Border(top: BorderSide(color: PosColors.border)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _FloorPlanLegend(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: onAddSection,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add section'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (store.sections.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'Create a section first, then add tables under it.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: PosColors.textMuted,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ...store.sections.map(
                    (sec) => Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: _FloorSectionBlock(
                        section: sec,
                        store: store,
                        selectedTableId: selectedTableId,
                        onSelectTable: onSelectTable,
                        onAddTable: () => onAddTableInSection(sec.id),
                        onDeleteSection: () => onDeleteSection(sec),
                        onBillPreview: onBillPreview,
                      ),
                    ),
                  ),
                  if (store.tablesWithoutSection.isNotEmpty) ...[
                    Text(
                      'Other tables',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: PosColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final t in store.tablesWithoutSection)
                          _SectionTableTile(
                            table: t,
                            selected: t.id == selectedTableId,
                            store: store,
                            onTap: () => onSelectTable(t),
                            onBillPreview: () => onBillPreview(t),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 340,
          child: TableWorkbench(
            store: store,
            selectedTable: selectedTableId != null
                ? store.tableById(selectedTableId!)
                : null,
            onAddOrder: onAddOrder,
            onQuickAddItem: onQuickAddItem,
            onSettle: onSettle,
            onMarkOccupied: onMarkOccupied,
            onDeleteTable: onDeleteTable,
          ),
        ),
      ],
    );
  }
}

class _FloorSectionBlock extends StatelessWidget {
  const _FloorSectionBlock({
    required this.section,
    required this.store,
    required this.selectedTableId,
    required this.onSelectTable,
    required this.onAddTable,
    required this.onDeleteSection,
    required this.onBillPreview,
  });

  final FloorSection section;
  final RestaurantStore store;
  final String? selectedTableId;
  final ValueChanged<DiningTable> onSelectTable;
  final VoidCallback onAddTable;
  final VoidCallback onDeleteSection;
  final void Function(DiningTable table) onBillPreview;

  @override
  Widget build(BuildContext context) {
    final tables = store.tablesInSection(section.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                section.name,
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: PosColors.textMain,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Add table',
              onPressed: onAddTable,
              icon: const Icon(Icons.add_circle_outline, color: PosColors.primary),
            ),
            IconButton(
              tooltip: 'Delete section',
              onPressed: onDeleteSection,
              icon: Icon(
                Icons.delete_outline,
                color: PosColors.error.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (tables.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'No tables yet — tap + to add.',
              style: GoogleFonts.outfit(fontSize: 13, color: PosColors.textMuted),
            ),
          ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final t in tables)
              _SectionTableTile(
                table: t,
                selected: t.id == selectedTableId,
                store: store,
                onTap: () => onSelectTable(t),
                onBillPreview: () => onBillPreview(t),
              ),
          ],
        ),
      ],
    );
  }
}

class _SectionTableTile extends StatelessWidget {
  const _SectionTableTile({
    required this.table,
    required this.selected,
    required this.store,
    required this.onTap,
    required this.onBillPreview,
  });

  final DiningTable table;
  final bool selected;
  final RestaurantStore store;
  final VoidCallback onTap;
  final VoidCallback onBillPreview;

  static const double _cardSize = 104;

  String _durationLabel() {
    final start = table.orderStartedAt;
    if (start == null) {
      return '';
    }
    final m = DateTime.now().difference(start).inMinutes;
    return '$m Min';
  }

  String _amountLine() {
    if (table.activeOrderTotal != null) {
      return '₹ ${table.activeOrderTotal!.toStringAsFixed(2)}';
    }
    if (table.status == TableStatus.occupied) {
      return store.calculateBill(table.id).totalFormatted;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final occupied = table.status == TableStatus.occupied;
    final tone = store.tableFloorToneFor(table.id);
    final st = floorToneStyle(tone);
    final bg = st.$1;
    final statusBorder = st.$2;
    final borderColor = selected ? PosColors.primary : statusBorder;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: _cardSize,
          height: _cardSize,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: selected ? 2 : 1.2),
          ),
          child: occupied
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (table.orderStartedAt != null)
                      Text(
                        _durationLabel(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      const SizedBox(height: 11),
                    Expanded(
                      child: Center(
                        child: Text(
                          table.name,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: PosColors.textMain,
                          ),
                        ),
                      ),
                    ),
                    if (_amountLine().isNotEmpty)
                      Text(
                        _amountLine(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: PosColors.textMain,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _MiniIconButton(
                          icon: Icons.print_rounded,
                          onPressed: onBillPreview,
                        ),
                        const SizedBox(width: 8),
                        _MiniIconButton(
                          icon: Icons.visibility_outlined,
                          onPressed: onTap,
                        ),
                      ],
                    ),
                  ],
                )
              : Center(
                  child: Text(
                    table.name,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: PosColors.textMain,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Icon(icon, size: 16, color: PosColors.textMain),
        ),
      ),
    );
  }
}

class TableWorkbench extends StatelessWidget {
  const TableWorkbench({
    required this.store,
    required this.selectedTable,
    required this.onAddOrder,
    required this.onQuickAddItem,
    required this.onSettle,
    required this.onMarkOccupied,
    required this.onDeleteTable,
    super.key,
  });

  final RestaurantStore store;
  final DiningTable? selectedTable;
  final VoidCallback onAddOrder;
  final ValueChanged<MenuItem> onQuickAddItem;
  final VoidCallback onSettle;
  final VoidCallback onMarkOccupied;
  final VoidCallback onDeleteTable;

  @override
  Widget build(BuildContext context) {
    if (selectedTable == null) {
      return GlassContainer(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PosColors.surfaceHighlight.withOpacity(0.5),
                ),
                child: Icon(Icons.touch_app_outlined,
                    size: 48, color: PosColors.textMuted.withOpacity(0.5)),
              ),
              const SizedBox(height: 24),
              Text(
                'Select a Table',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: PosColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap on the floor canvas\nto manage orders.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: PosColors.textMuted.withOpacity(0.6),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final table = selectedTable!;
    final lines = store.orderDetailsForTable(table.id);
    final totals = store.calculateBill(table.id);
    final isOccupied = table.status == TableStatus.occupied;

    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: PosColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isOccupied
                        ? PosColors.warning.withOpacity(0.15)
                        : PosColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isOccupied
                          ? PosColors.warning.withOpacity(0.3)
                          : PosColors.accent.withOpacity(0.3),
                    ),
                  ),
                  child: Icon(
                    isOccupied ? Icons.restaurant : Icons.table_restaurant,
                    color: isOccupied ? PosColors.warning : PosColors.accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        table.name,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: PosColors.textMain,
                        ),
                      ),
                      Text(
                        '${table.capacity} Seats • ${table.statusLabel}',
                        style: GoogleFonts.outfit(
                          color: PosColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: PosColors.textMuted, size: 20),
                  color: PosColors.surfaceHighlight,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  onSelected: (value) {
                    if (value == 'occupy') onMarkOccupied();
                    if (value == 'delete') onDeleteTable();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'occupy',
                      height: 36,
                      child: Row(
                        children: [
                          const Icon(Icons.event_seat,
                              color: PosColors.textMain, size: 18),
                          const SizedBox(width: 10),
                          Text('Mark Occupied',
                              style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: PosColors.textMain)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      height: 36,
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline,
                              color: PosColors.error, size: 18),
                          const SizedBox(width: 10),
                          Text('Delete Table',
                              style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: PosColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Order List
          Expanded(
            child: lines.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 40,
                            color: PosColors.textMuted.withOpacity(0.3)),
                        const SizedBox(height: 12),
                        Text('No active orders',
                            style: GoogleFonts.outfit(
                                color: PosColors.textMuted, fontSize: 14)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: lines.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final line = lines[index];
                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${line.quantity}× ${line.itemName}',
                              style: GoogleFonts.outfit(
                                color: PosColors.textMain,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            line.lineTotalFormatted,
                            style: GoogleFonts.outfit(
                              color: PosColors.textMain,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Quick Add Menu (Horizontal)
          if (store.menuItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Add',
                    style: GoogleFonts.outfit(
                      color: PosColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: store.menuItems.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => onQuickAddItem(item),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: PosColors.surfaceHighlight
                                    .withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: PosColors.border.withOpacity(0.5)),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    item.name,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: PosColors.textMain,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    item.formattedPrice,
                                    style: GoogleFonts.outfit(
                                      color: PosColors.accent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // Bill Totals & Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PosColors.surfaceHighlight.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: const Border(top: BorderSide(color: PosColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SummaryRow(label: 'Subtotal', value: totals.subtotalFormatted),
                const SizedBox(height: 8),
                _SummaryRow(label: 'Tax (10%)', value: totals.taxFormatted),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: PosColors.border),
                ),
                _SummaryRow(
                    label: 'Total',
                    value: totals.totalFormatted,
                    isTotal: true),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onAddOrder,
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: lines.isEmpty ? null : () {
                          showDialog(
                            context: context,
                            builder: (_) => BillReceiptDialog(
                              title: 'ORDER SUMMARY',
                              tableName: table.name,
                              timestamp: DateTime.now(),
                              lines: lines,
                              totals: totals,
                              onBillPrinted: () =>
                                  store.markBillPrinted(selectedTable!.id),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PosColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.receipt_long, size: 14),
                        label: const Text('Bill', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: lines.isEmpty ? null : onSettle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PosColors.accent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          disabledBackgroundColor:
                              PosColors.surfaceHighlight.withOpacity(0.5),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 14),
                        label: const Text('Settle', style: TextStyle(fontSize: 11)),
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

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            color: isTotal ? PosColors.textMain : PosColors.textMuted,
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: isTotal ? PosColors.primaryGlow : PosColors.textMain,
            fontSize: isTotal ? 24 : 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class MenuSection extends StatelessWidget {
  const MenuSection({
    required this.store,
    required this.canDeleteMenuItems,
    required this.onAddMenuItem,
    required this.onDeleteMenuItem,
    super.key,
  });

  final RestaurantStore store;
  final bool canDeleteMenuItems;
  final Future<void> Function() onAddMenuItem;
  final Future<void> Function(MenuItem item) onDeleteMenuItem;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 0,
      border: const Border(top: BorderSide(color: PosColors.border)),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PosColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: PosColors.primary.withOpacity(0.3)),
                  ),
                  child:
                      const Icon(Icons.restaurant_menu, color: PosColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Menu Catalog',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: PosColors.textMain,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: onAddMenuItem,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Menu Item', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: store.menuItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fastfood_outlined,
                              size: 56,
                              color: PosColors.textMuted.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          Text(
                            'Your catalog is empty',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: PosColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Click the Add Menu Item button to get started.',
                            style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: PosColors.textMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: store.menuItems.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: PosColors.border),
                      itemBuilder: (context, index) {
                        final item = store.menuItems[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: PosColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.category.toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    color: PosColors.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: PosColors.textMain,
                                  ),
                                ),
                              ),
                              Text(
                                item.formattedPrice,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: PosColors.accent,
                                ),
                              ),
                              if (canDeleteMenuItems) ...[
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: PosColors.error, size: 20),
                                  onPressed: () => onDeleteMenuItem(item),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
    );
  }
}

class BillingSection extends StatelessWidget {
  const BillingSection({
    required this.store,
    required this.onSettle,
    super.key,
  });

  final RestaurantStore store;
  final ValueChanged<DiningTable> onSettle;

  @override
  Widget build(BuildContext context) {
    final billedTables = store.tables
        .where((table) => store.hasActiveOrder(table.id))
        .toList(growable: false);

    return GlassContainer(
      borderRadius: 0,
      border: const Border(top: BorderSide(color: PosColors.border)),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PosColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: PosColors.accent.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.receipt_long, color: PosColors.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Active Bills Queue',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: PosColors.textMain,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: billedTables.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 56,
                              color: PosColors.textMuted.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          Text(
                            'All caught up!',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: PosColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'There are no active bills right now.',
                            style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: PosColors.textMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: billedTables.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: PosColors.border),
                      itemBuilder: (context, index) {
                        final table = billedTables[index];
                        final totals = store.calculateBill(table.id);
                        final lines = store.orderDetailsForTable(table.id);
                        final itemUnits = lines.fold<int>(
                          0,
                          (sum, line) => sum + line.quantity,
                        );

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: PosColors.warning.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.table_bar,
                                    color: PosColors.warning, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      table.name,
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: PosColors.textMain,
                                      ),
                                    ),
                                    Text(
                                      '$itemUnits items ordered',
                                      style: GoogleFonts.outfit(
                                        color: PosColors.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                totals.totalFormatted,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: PosColors.primaryGlow,
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => BillReceiptDialog(
                                      title: 'ORDER SUMMARY',
                                      tableName: table.name,
                                      timestamp: DateTime.now(),
                                      lines: lines,
                                      totals: totals,
                                      onBillPrinted: () =>
                                          store.markBillPrinted(table.id),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: PosColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Bill', style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => onSettle(table),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: PosColors.accent,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Settle', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
    );
  }
}

class TransactionsSection extends StatelessWidget {
  const TransactionsSection({
    required this.store,
    super.key,
  });

  final RestaurantStore store;

  @override
  Widget build(BuildContext context) {
    final txns = store.transactions;

    return GlassContainer(
      borderRadius: 0,
      border: const Border(top: BorderSide(color: PosColors.border)),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PosColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: PosColors.primary.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.history, color: PosColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Transaction History',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: PosColors.textMain,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: txns.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history,
                              size: 56,
                              color: PosColors.textMuted.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          Text(
                            'No transactions yet',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: PosColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Completed orders will appear here.',
                            style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: PosColors.textMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: txns.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: PosColors.border),
                      itemBuilder: (context, index) {
                        final txn = txns[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: PosColors.accent.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, color: PosColors.accent, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      txn.tableName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: PosColors.textMain,
                                      ),
                                    ),
                                    Text(
                                      '${txn.timestamp.hour}:${txn.timestamp.minute.toString().padLeft(2, '0')} • ${txn.lines.length} items',
                                      style: const TextStyle(color: PosColors.textMuted, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                txn.totals.totalFormatted,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: PosColors.textMain,
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.receipt_long_outlined, color: PosColors.primary, size: 20),
                                tooltip: 'View Bill',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => BillReceiptDialog(
                                      title: 'PAID RECEIPT',
                                      tableName: txn.tableName,
                                      timestamp: txn.timestamp,
                                      lines: txn.lines,
                                      totals: txn.totals,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
    );
  }
}

class BillReceiptDialog extends StatelessWidget {
  final String title;
  final String tableName;
  final DateTime timestamp;
  final List<BillLine> lines;
  final BillTotals totals;
  final VoidCallback? onBillPrinted;

  const BillReceiptDialog({
    super.key,
    required this.title,
    required this.tableName,
    required this.timestamp,
    required this.lines,
    required this.totals,
    this.onBillPrinted,
  });

  Future<void> _printBill() async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('HYPER POS',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Center(
                child: pw.Text(title, style: const pw.TextStyle(fontSize: 10)),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Table: $tableName', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                      '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                      style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.SizedBox(height: 10),
              ...lines.map((line) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 2),
                child: pw.Row(
                    children: [
                      pw.Expanded(
                          child: pw.Text(
                            '${line.quantity}× ${line.itemName}',
                            style: const pw.TextStyle(fontSize: 9))),
                      pw.Text(line.lineTotalFormatted, style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ))),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(totals.subtotalFormatted, style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Tax (10%)', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(totals.taxFormatted, style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text(totals.totalFormatted,
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 15),
              pw.Center(
                child: pw.Text('Thank you!',
                    style: const pw.TextStyle(fontSize: 8)),
              ),
            ],
          );
        },
      ),
    );

    try {
      await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => doc.save(),
          name:
              'Receipt_${tableName}_${timestamp.millisecondsSinceEpoch}');
      onBillPrinted?.call();
    } catch (_) {
      /* print cancelled or failed */
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassContainer(
        padding: const EdgeInsets.all(32),
        borderRadius: 24,
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PosColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.restaurant, color: PosColors.primary, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'HYPER POS',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: PosColors.textMain,
                ),
              ),
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: PosColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(color: PosColors.border, thickness: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Table: $tableName', 
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: PosColors.textMain)),
                  Text(
                    '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.outfit(color: PosColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: lines.length,
                  itemBuilder: (context, index) {
                    final line = lines[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${line.quantity}× ${line.itemName}',
                              style: GoogleFonts.outfit(
                                color: PosColors.textMain,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            line.lineTotalFormatted,
                            style: GoogleFonts.outfit(
                              color: PosColors.textMain,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(color: PosColors.border, thickness: 1, height: 1),
              ),
              _buildBillRow('Subtotal', totals.subtotalFormatted),
              const SizedBox(height: 8),
              _buildBillRow('Tax (10%)', totals.taxFormatted),
              const SizedBox(height: 16),
              _buildBillRow('Total Amount', totals.totalFormatted, isBold: true),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () async => _printBill(),
                        icon: const Icon(Icons.print_rounded, size: 20),
                        label: Text('Print', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Close', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBillRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 18 : 14,
            color: isBold ? PosColors.textMain : PosColors.textMuted,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 20 : 14,
            color: isBold ? PosColors.primary : PosColors.textMain,
          ),
        ),
      ],
    );
  }
}

class TableDraft {
  const TableDraft({required this.name, required this.capacity});
  final String name;
  final int capacity;
}

class MenuDraft {
  const MenuDraft({
    required this.name,
    required this.category,
    required this.price,
  });
  final String name;
  final String category;
  final double price;
}

class OrderDraft {
  const OrderDraft({required this.menuItemId, required this.quantity});
  final String menuItemId;
  final int quantity;
}

class CreateTableDialog extends StatefulWidget {
  const CreateTableDialog({
    required this.defaultName,
    required this.defaultCapacity,
    super.key,
  });

  final String defaultName;
  final int defaultCapacity;

  @override
  State<CreateTableDialog> createState() => _CreateTableDialogState();
}

class _CreateTableDialogState extends State<CreateTableDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _capacityController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.defaultName);
    _capacityController =
        TextEditingController(text: widget.defaultCapacity.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      TableDraft(
        name: _nameController.text.trim(),
        capacity: int.parse(_capacityController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Build New Table',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Table Name / ID'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _capacityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Seating Capacity'),
              validator: (value) {
                final parsed = int.tryParse(value ?? '');
                if (parsed == null || parsed < 1) return 'Must be 1+';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: PosColors.textMuted))),
        FilledButton(onPressed: _save, child: const Text('Build Table')),
      ],
    );
  }
}

class AddMenuItemDialog extends StatefulWidget {
  const AddMenuItemDialog({super.key});

  @override
  State<AddMenuItemDialog> createState() => _AddMenuItemDialogState();
}

class _AddMenuItemDialogState extends State<AddMenuItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Main');
  final _priceController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      MenuDraft(
        name: _nameController.text.trim(),
        category: _categoryController.text.trim(),
        price: double.parse(_priceController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('New Catalog Item',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Item Name'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(labelText: 'Category'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Price (₹)'),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                if (parsed == null || parsed <= 0) return 'Invalid price';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: PosColors.textMuted))),
        FilledButton(onPressed: _save, child: const Text('Save Item')),
      ],
    );
  }
}

class AddOrderDialog extends StatefulWidget {
  const AddOrderDialog({required this.menuItems, super.key});
  final List<MenuItem> menuItems;

  @override
  State<AddOrderDialog> createState() => _AddOrderDialogState();
}

class _AddOrderDialogState extends State<AddOrderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController(text: '1');
  late String _selectedMenuId;

  @override
  void initState() {
    super.initState();
    _selectedMenuId = widget.menuItems.first.id;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      OrderDraft(
        menuItemId: _selectedMenuId,
        quantity: int.parse(_quantityController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add to Order',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedMenuId,
              decoration: const InputDecoration(labelText: 'Select Item'),
              dropdownColor: PosColors.surfaceHighlight,
              items: widget.menuItems
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.id,
                      child: Text('${item.name} (${item.formattedPrice})',
                          style: const TextStyle(color: PosColors.textMain)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedMenuId = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
              validator: (value) {
                final parsed = int.tryParse(value ?? '');
                if (parsed == null || parsed < 1) return 'Must be 1+';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: PosColors.textMuted))),
        FilledButton(onPressed: _save, child: const Text('Add Items')),
      ],
    );
  }
}

