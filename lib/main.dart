import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'design/components.dart';
import 'design/tokens.dart';
import 'pos_models.dart';
import 'pos_restaurant_store.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

void main() {
  runApp(const CashierDashApp());
}

/// Legacy palette kept for backwards compatibility with widgets that still
/// reference `PosColors.*`. New code should use [DS] from `design/tokens.dart`.
/// Values delegate to the design system so the whole app reflects palette
/// changes from a single place.
class PosColors {
  static const Color background = DS.bg;
  static const Color surface = DS.surface;
  static const Color surfaceHighlight = DS.surfaceMuted;
  static const Color primary = DS.accent;
  static const Color primaryGlow = DS.focus;
  static const Color accent = DS.green;
  static const Color warning = DS.amber;
  static const Color error = DS.red;
  static const Color textMain = DS.text;
  static const Color textMuted = DS.textMuted;
  static const Color border = DS.border;
}

/// (background, accent border, ink) for floor table tiles + legend swatches.
/// Tones are tuned to be muted / state-only — they should never feel decorative.
({Color bg, Color border, Color ink}) floorToneStyle(TableFloorTone tone) {
  return switch (tone) {
    TableFloorTone.empty =>
      (bg: DS.surface, border: DS.border, ink: DS.textMuted),
    TableFloorTone.orderOpen =>
      (bg: DS.amberSurface, border: DS.amber, ink: DS.amber),
    TableFloorTone.billPrinted =>
      (bg: DS.violetSurface, border: DS.violet, ink: DS.violet),
    TableFloorTone.paid =>
      (bg: DS.greenSurface, border: DS.green, ink: DS.green),
  };
}

String _floorToneLabel(TableFloorTone tone) {
  return switch (tone) {
    TableFloorTone.empty => 'Empty',
    TableFloorTone.orderOpen => 'Order open',
    TableFloorTone.billPrinted => 'Bill printed',
    TableFloorTone.paid => 'Paid',
  };
}

class _FloorPlanLegend extends StatelessWidget {
  const _FloorPlanLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: DS.s12),
      padding: const EdgeInsets.symmetric(
        horizontal: DS.s12,
        vertical: DS.s8,
      ),
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.r6),
        border: Border.all(color: DS.border),
      ),
      child: Row(
        children: [
          Text('STATUS', style: DS.eyebrow()),
          const SizedBox(width: DS.s12),
          Expanded(
            child: Wrap(
              spacing: DS.s14,
              runSpacing: DS.s6,
              children: [
                for (final tone in TableFloorTone.values) _chip(tone),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(TableFloorTone tone) {
    final s = floorToneStyle(tone);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: s.bg,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: s.border, width: 1),
          ),
        ),
        const SizedBox(width: DS.s6),
        Text(_floorToneLabel(tone), style: DS.body()),
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
    return MaterialApp(
      title: 'Bawarchi Cashier',
      debugShowCheckedModeBanner: false,
      theme: DS.buildTheme(),
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

/// Legacy "glass" wrapper. There is no glass anymore — this is a flat
/// 1px-bordered surface. Kept named for source compatibility; new code should
/// use [Surface] from `design/components.dart`.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = DS.r6,
    this.color,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? color;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(color: DS.border),
        color: color ?? DS.surface,
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
                        style: GoogleFonts.inter(
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
                        style: GoogleFonts.inter(
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
                          style: GoogleFonts.inter(
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
                            style: GoogleFonts.inter(
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
        title: Text('New section', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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
        title: Text('Add table', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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
        title: Text('Delete section?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          'Remove "${section.name}"? Tables must be removed from this section first.',
          style: GoogleFonts.inter(),
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
      width: DS.sidebarWidth,
      decoration: const BoxDecoration(
        color: DS.surface,
        border: Border(right: BorderSide(color: DS.border)),
      ),
      child: Column(
        children: [
          const SizedBox(height: DS.s12),
          // Mark / brand. Square monogram, never an emoji icon.
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: DS.accent,
              borderRadius: BorderRadius.circular(DS.r6),
            ),
            child: Text(
              'B',
              style: DS.bodyStrong(color: DS.accentInk),
            ),
          ),
          const SizedBox(height: DS.s20),
          _SidebarItem(
            icon: Icons.grid_view_outlined,
            tooltip: 'Floor',
            isSelected: section == PosSection.floor,
            onTap: () => onChangeSection(PosSection.floor),
          ),
          _SidebarItem(
            icon: Icons.menu_book_outlined,
            tooltip: 'Menu',
            isSelected: section == PosSection.menu,
            onTap: () => onChangeSection(PosSection.menu),
          ),
          _SidebarItem(
            icon: Icons.receipt_long_outlined,
            tooltip: 'Bills',
            isSelected: section == PosSection.billing,
            onTap: () => onChangeSection(PosSection.billing),
          ),
          _SidebarItem(
            icon: Icons.history,
            tooltip: 'History',
            isSelected: section == PosSection.transactions,
            onTap: () => onChangeSection(PosSection.transactions),
          ),
          const Spacer(),
          _SidebarItem(
            icon: Icons.logout,
            tooltip: 'Sign out',
            isSelected: false,
            onTap: onLogout,
            danger: true,
          ),
          const SizedBox(height: DS.s12),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final fg = danger
        ? DS.red
        : (isSelected ? DS.text : DS.textMuted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: tooltip,
        preferBelow: false,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: DS.sidebarWidth,
              height: 44,
              child: Stack(
                children: [
                  if (isSelected)
                    Positioned.fill(
                      child: Row(
                        children: [
                          Container(width: 2, color: DS.accent),
                          const SizedBox.shrink(),
                        ],
                      ),
                    ),
                  Center(
                    child: Icon(icon, size: 20, color: fg),
                  ),
                ],
              ),
            ),
          ),
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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DS.s12,
        vertical: DS.s8,
      ),
      decoration: const BoxDecoration(
        color: DS.amberSurface,
        border: Border(bottom: BorderSide(color: DS.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          StatusDot(DS.amber, size: 8),
          const SizedBox(width: DS.s8),
          Expanded(
            child: Text(
              err,
              style: DS.body(color: DS.amber),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: DS.s8),
          TextButton(
            onPressed: store.refreshAll,
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: store.clearLastError,
            child: const Text('Dismiss'),
          ),
        ],
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

  String _hhmm() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: DS.s16),
      decoration: const BoxDecoration(
        color: DS.surface,
        border: Border(bottom: BorderSide(color: DS.border)),
      ),
      child: Row(
        children: [
          Text(section.title, style: DS.display()),
          const SizedBox(width: DS.s10),
          Container(width: 1, height: 18, color: DS.border),
          const SizedBox(width: DS.s10),
          Text(section.subtitle, style: DS.body(color: DS.textMuted)),
          const Spacer(),
          if (restaurantId case final String rid when rid.isNotEmpty) ...[
            Tooltip(
              message:
                  'Signed-in restaurant: $rid\nMenu is scoped to this tenant.',
              child: Row(
                children: [
                  Text('TENANT', style: DS.eyebrow()),
                  const SizedBox(width: DS.s6),
                  Text(
                    rid.length > 8 ? '${rid.substring(0, 8)}…' : rid,
                    style: DS.number(size: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: DS.s16),
          ],
          Text(_hhmm(), style: DS.number(size: 12, color: DS.textMuted)),
          const SizedBox(width: DS.s16),
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: DS.surfaceMuted,
                  borderRadius: BorderRadius.circular(DS.r6),
                  border: Border.all(color: DS.border),
                ),
                child: Text(
                  cashierName.isNotEmpty
                      ? cashierName[0].toUpperCase()
                      : '?',
                  style: DS.bodyStrong(),
                ),
              ),
              const SizedBox(width: DS.s8),
              Text(cashierName, style: DS.bodyStrong()),
            ],
          ),
        ],
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
          child: ColoredBox(
            color: DS.bg,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                DS.s16,
                DS.s12,
                DS.s16,
                DS.s24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _FloorPlanLegend(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: onAddSection,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New section'),
                    ),
                  ),
                  const SizedBox(height: DS.s16),
                  if (store.sections.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: DS.s24),
                      child: Center(
                        child: Text(
                          'Create a section first, then add tables under it.',
                          textAlign: TextAlign.center,
                          style: DS.body(color: DS.textMuted),
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
                    Text('OTHER TABLES', style: DS.eyebrow()),
                    const SizedBox(height: DS.s8),
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
    final occupied = tables.where((t) => store.hasActiveOrder(t.id)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(section.name.toUpperCase(), style: DS.eyebrow()),
            const SizedBox(width: DS.s8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DS.s6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: DS.surfaceMuted,
                borderRadius: BorderRadius.circular(DS.r4),
              ),
              child: Text(
                '$occupied / ${tables.length}',
                style: DS.number(size: 11, color: DS.textMuted),
              ),
            ),
            const Spacer(),
            IconAction(
              icon: Icons.add,
              tooltip: 'Add table',
              onTap: onAddTable,
            ),
            const SizedBox(width: DS.s4),
            IconAction(
              icon: Icons.delete_outline,
              tooltip: 'Delete section',
              danger: true,
              onTap: onDeleteSection,
            ),
          ],
        ),
        const SizedBox(height: DS.s8),
        if (tables.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: DS.s8),
            child: Text(
              'No tables in this section. Use + to add.',
              style: DS.body(color: DS.textMuted),
            ),
          ),
        Wrap(
          spacing: DS.s8,
          runSpacing: DS.s8,
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

/// Compact, information-dense table tile. The status color is the **left
/// edge bar**; the body stays neutral so prices and labels stay legible.
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

  static const double _cardWidth = 168;
  static const double _cardHeight = 80;

  String _durationLabel() {
    final start = table.orderStartedAt;
    if (start == null) return '';
    final mins = DateTime.now().difference(start).inMinutes;
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  double? _activeAmount() {
    if (table.activeOrderTotal != null) return table.activeOrderTotal;
    if (table.status == TableStatus.occupied) {
      return store.calculateBill(table.id).total;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tone = store.tableFloorToneFor(table.id);
    final st = floorToneStyle(tone);
    final occupied = table.status == TableStatus.occupied;
    final amount = _activeAmount();
    final dur = _durationLabel();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DS.r6),
        child: Container(
          width: _cardWidth,
          height: _cardHeight,
          decoration: BoxDecoration(
            color: DS.surface,
            borderRadius: BorderRadius.circular(DS.r6),
            border: Border.all(
              color: selected ? DS.accent : DS.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              // Status edge — only colored part of the tile.
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: st.border,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(DS.r6),
                    bottomLeft: Radius.circular(DS.r6),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DS.s10,
                    vertical: DS.s8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              table.name,
                              style: DS.bodyStrong(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _floorToneLabel(tone),
                            style: DS.caption(color: st.ink),
                          ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (amount != null && amount > 0)
                            MoneyText(amount, size: 13)
                          else
                            Text('—',
                                style: DS.number(color: DS.textSubtle)),
                          const Spacer(),
                          if (dur.isNotEmpty)
                            Text(dur,
                                style: DS.number(
                                    size: 11, color: DS.textMuted)),
                          if (occupied) ...[
                            const SizedBox(width: DS.s6),
                            IconAction(
                              icon: Icons.print_outlined,
                              tooltip: 'Bill / receipt',
                              onTap: onBillPreview,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _confirmCancelOrder(
  BuildContext context,
  RestaurantStore store,
  DiningTable table,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cancel order'),
      content: Text(
        'Void this order for ${table.name} and remove all lines?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Keep'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: PosColors.error),
          child: const Text('Cancel order'),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    await store.cancelActiveOrder(table.id);
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
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: PosColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap on the floor canvas\nto manage orders.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
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
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: PosColors.textMain,
                        ),
                      ),
                      Text(
                        '${table.capacity} Seats • ${table.statusLabel}',
                        style: GoogleFonts.inter(
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
                    if (value == 'cancel_order') {
                      _confirmCancelOrder(context, store, table);
                    }
                  },
                  itemBuilder: (context) => [
                    if (lines.isNotEmpty)
                      PopupMenuItem(
                        value: 'cancel_order',
                        height: 36,
                        child: Row(
                          children: [
                            const Icon(Icons.cancel_outlined,
                                color: PosColors.error, size: 18),
                            const SizedBox(width: 10),
                            Text('Cancel order',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: PosColors.error)),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'occupy',
                      height: 36,
                      child: Row(
                        children: [
                          const Icon(Icons.event_seat,
                              color: PosColors.textMain, size: 18),
                          const SizedBox(width: 10),
                          Text('Mark Occupied',
                              style: GoogleFonts.inter(
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
                              style: GoogleFonts.inter(
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
                            style: GoogleFonts.inter(
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
                      final oid = line.orderItemId;
                      final mid = line.menuItemId;
                      final canChQty = oid != null && oid.isNotEmpty;
                      final canAddUnit =
                          mid != null && mid.isNotEmpty && store.hasActiveOrder(table.id);
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconAction(
                            icon: Icons.remove,
                            tooltip: 'Decrease quantity',
                            onTap: !canChQty
                                ? () {}
                                : () => store.setOrderItemQuantity(
                                      table.id,
                                      oid,
                                      line.quantity - 1,
                                    ),
                          ),
                          IconAction(
                            icon: Icons.add,
                            tooltip: 'Increase quantity',
                            onTap: !canAddUnit
                                ? () {}
                                : () => store.addItemToOrder(
                                      tableId: table.id,
                                      menuItemId: mid,
                                      quantity: 1,
                                    ),
                          ),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '${line.quantity}× ${line.itemName}',
                                style: GoogleFonts.inter(
                                  color: PosColors.textMain,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          Text(
                            line.lineTotalFormatted,
                            style: GoogleFonts.inter(
                              color: PosColors.textMain,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconAction(
                            icon: Icons.close,
                            tooltip: 'Remove line',
                            danger: true,
                            onTap: !canChQty
                                ? () {}
                                : () => store.removeOrderItemLine(
                                      table.id,
                                      oid,
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
                    style: GoogleFonts.inter(
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
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: PosColors.textMain,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    item.formattedPrice,
                                    style: GoogleFonts.inter(
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
          style: GoogleFonts.inter(
            color: isTotal ? PosColors.textMain : PosColors.textMuted,
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
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
                  style: GoogleFonts.inter(
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
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: PosColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Click the Add Menu Item button to get started.',
                            style: GoogleFonts.inter(
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
                                  style: GoogleFonts.inter(
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
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: PosColors.textMain,
                                  ),
                                ),
                              ),
                              Text(
                                item.formattedPrice,
                                style: GoogleFonts.inter(
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
                  style: GoogleFonts.inter(
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
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: PosColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'There are no active bills right now.',
                            style: GoogleFonts.inter(
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
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: PosColors.textMain,
                                      ),
                                    ),
                                    Text(
                                      '$itemUnits items ordered',
                                      style: GoogleFonts.inter(
                                        color: PosColors.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                totals.totalFormatted,
                                style: GoogleFonts.inter(
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
                              TextButton(
                                onPressed: () => _confirmCancelOrder(
                                  context,
                                  store,
                                  table,
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: PosColors.error,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Void', style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 4),
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
                  style: GoogleFonts.inter(
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
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: PosColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Completed orders will appear here.',
                            style: GoogleFonts.inter(
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
                                      style: GoogleFonts.inter(
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
                                style: GoogleFonts.inter(
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
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: PosColors.textMain,
                ),
              ),
              Text(
                title,
                style: GoogleFonts.inter(
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
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: PosColors.textMain)),
                  Text(
                    '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.inter(color: PosColors.textMuted, fontSize: 12),
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
                              style: GoogleFonts.inter(
                                color: PosColors.textMain,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            line.lineTotalFormatted,
                            style: GoogleFonts.inter(
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
                        label: Text('Print', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
                        child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
          style: GoogleFonts.inter(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 18 : 14,
            color: isBold ? PosColors.textMain : PosColors.textMuted,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
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
          style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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
          style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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
          style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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

