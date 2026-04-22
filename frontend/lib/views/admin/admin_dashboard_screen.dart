import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_config.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Stats
  Map<String, dynamic> _stats = {};
  bool _statsLoading = true;

  // Lists
  List<dynamic> _bookings = [];
  List<dynamic> _sitters = [];
  List<dynamic> _owners = [];
  bool _listLoading = false;

  final _adminSecretController = TextEditingController();
  bool _authenticated = false;
  String _adminSecret = '';

  // ── Pricing (session v15) ────────────────────────────────────────────────
  // Loaded from GET /admin/pricing, edited via PATCH /admin/pricing.
  // Schema: { boost: {EUR: {bronze,silver,gold,platinum}, …}, mapBoost: {…},
  //           premium: {EUR: {monthly,yearly}, …} }
  Map<String, dynamic> _pricing = {};
  bool _pricingLoading = false;
  bool _pricingSaving = false;
  String _pricingCurrency = 'EUR';
  // One TextEditingController per pricing cell so edits persist across rebuild.
  final Map<String, TextEditingController> _priceCtrls = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _adminSecretController.dispose();
    for (final c in _priceCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _login() async {
    _adminSecret = _adminSecretController.text.trim();
    if (_adminSecret.isEmpty) return;
    try {
      final response = await ApiClient().get(
        '${ApiConfig.baseUrl}/admin/stats',
        headers: {'x-admin-secret': _adminSecret},
      );
      setState(() {
        _stats = response as Map<String, dynamic>;
        _authenticated = true;
        _statsLoading = false;
      });
      await _loadAll();
    } catch (e) {
      Get.snackbar('Error', 'Invalid admin credentials',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> _loadAll() async {
    setState(() => _listLoading = true);
    try {
      final headers = {'x-admin-secret': _adminSecret};
      final bookings = await ApiClient().get('${ApiConfig.baseUrl}/admin/bookings?limit=50', headers: headers);
      final sitters = await ApiClient().get('${ApiConfig.baseUrl}/admin/sitters?limit=50', headers: headers);
      final owners = await ApiClient().get('${ApiConfig.baseUrl}/admin/owners?limit=50', headers: headers);
      setState(() {
        _bookings = (bookings as Map)['bookings'] ?? [];
        _sitters = (sitters as Map)['sitters'] ?? [];
        _owners = (owners as Map)['owners'] ?? [];
      });
      // Also preload pricing so the Tarifs tab is ready on first open.
      await _loadPricing();
    } catch (e) {
      // ignore
    } finally {
      setState(() => _listLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PRICING (session v15) — GET / PATCH / RESET /admin/pricing
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _loadPricing() async {
    setState(() => _pricingLoading = true);
    try {
      final response = await ApiClient().get(
        '${ApiConfig.baseUrl}/admin/pricing',
        headers: {'x-admin-secret': _adminSecret},
      );
      setState(() {
        _pricing = Map<String, dynamic>.from(
            (response as Map)['pricing'] as Map? ?? {});
        _syncPriceControllers();
      });
    } catch (e) {
      Get.snackbar('Error', 'Failed to load pricing',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      setState(() => _pricingLoading = false);
    }
  }

  /// Builds / updates one TextEditingController per pricing cell so that
  /// the text fields stay in sync with whatever came back from the backend.
  /// Keys look like "boost.EUR.bronze" / "premium.EUR.monthly".
  void _syncPriceControllers() {
    final cur = _pricingCurrency;
    final groups = ['boost', 'mapBoost', 'premium'];
    for (final g in groups) {
      final byCur = (_pricing[g] as Map?) ?? {};
      final tiers = (byCur[cur] as Map?) ?? {};
      tiers.forEach((tier, value) {
        final key = '$g.$cur.$tier';
        final str = (value is num) ? value.toStringAsFixed(2) : value.toString();
        _priceCtrls.putIfAbsent(key, () => TextEditingController());
        if (_priceCtrls[key]!.text != str) {
          _priceCtrls[key]!.text = str;
        }
      });
    }
  }

  Future<void> _savePricing() async {
    setState(() => _pricingSaving = true);
    try {
      // Re-build the patch from current controller values.
      final cur = _pricingCurrency;
      final patch = <String, Map<String, Map<String, num>>>{};
      for (final g in ['boost', 'mapBoost', 'premium']) {
        final byCur = (_pricing[g] as Map?) ?? {};
        final tiers = (byCur[cur] as Map?) ?? {};
        final group = <String, num>{};
        tiers.forEach((tier, _) {
          final ctl = _priceCtrls['$g.$cur.$tier'];
          if (ctl == null) return;
          final parsed = double.tryParse(ctl.text.trim().replaceAll(',', '.'));
          if (parsed != null && parsed >= 0) group[tier] = parsed;
        });
        if (group.isNotEmpty) patch[g] = {cur: group};
      }

      await ApiClient().patch(
        '${ApiConfig.baseUrl}/admin/pricing',
        body: patch,
        headers: {'x-admin-secret': _adminSecret},
      );
      Get.snackbar('Success', 'Tarifs enregistrés',
          backgroundColor: Colors.green, colorText: Colors.white);
      await _loadPricing();
    } catch (e) {
      Get.snackbar('Error', 'Échec de la sauvegarde',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      setState(() => _pricingSaving = false);
    }
  }

  Future<void> _resetPricing() async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Réinitialiser les tarifs ?'),
        content: const Text(
            'Cela restaure tous les prix Boost / Map Boost / Premium à leurs '
            'valeurs par défaut. Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Réinitialiser', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiClient().post(
        '${ApiConfig.baseUrl}/admin/pricing/reset',
        body: {},
        headers: {'x-admin-secret': _adminSecret},
      );
      Get.snackbar('Success', 'Tarifs réinitialisés',
          backgroundColor: Colors.green, colorText: Colors.white);
      await _loadPricing();
    } catch (e) {
      Get.snackbar('Error', 'Échec du reset',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> _verifySitter(String id, bool verified) async {
    try {
      await ApiClient().patch(
        '${ApiConfig.baseUrl}/admin/sitters/$id/verify',
        body: {'verified': verified},
        headers: {'x-admin-secret': _adminSecret},
      );
      await _loadAll();
      Get.snackbar('Success', verified ? 'Sitter verified ✓' : 'Sitter unverified',
          backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Error', 'Failed to update sitter');
    }
  }

  Future<void> _verifyIban(String sitterId) async {
    try {
      await ApiClient().patch(
        '${ApiConfig.baseUrl}/admin/sitters/$sitterId/iban/verify',
        body: {},
        headers: {'x-admin-secret': _adminSecret},
      );
      Get.snackbar('Success', 'IBAN verified ✓',
          backgroundColor: Colors.green, colorText: Colors.white);
      await _loadAll();
    } catch (e) {
      Get.snackbar('Error', 'Failed to verify IBAN');
    }
  }

  Future<void> _updateBookingStatus(String id, String status) async {
    try {
      await ApiClient().patch(
        '${ApiConfig.baseUrl}/admin/bookings/$id',
        body: {'status': status},
        headers: {'x-admin-secret': _adminSecret},
      );
      await _loadAll();
      Get.snackbar('Success', 'Booking updated',
          backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Error', 'Failed to update booking');
    }
  }

  // ─── LOGIN SCREEN ──────────────────────────────────────────────────────────
  Widget _buildLoginScreen() {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: Center(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 32.w),
          padding: EdgeInsets.all(28.w),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: AppColors.cardShadow(context),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.admin_panel_settings,
                  size: 60.sp, color: AppColors.primaryColor),
              SizedBox(height: 16.h),
              InterText(
                text: 'HoPetSit Admin',
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
              SizedBox(height: 24.h),
              TextField(
                controller: _adminSecretController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Admin Secret Key',
                  prefixIcon: Icon(Icons.key, color: AppColors.primaryColor),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r)),
                  ),
                  onPressed: _login,
                  child: InterText(
                    text: 'Login',
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── STATS TAB ─────────────────────────────────────────────────────────────
  Widget _buildStatsTab() {
    if (_statsLoading) return const Center(child: CircularProgressIndicator());
    final cards = [
      {'label': 'Total Bookings', 'value': '${_stats['totalBookings'] ?? 0}', 'icon': Icons.book, 'color': Colors.blue},
      {'label': 'Paid Bookings', 'value': '${_stats['paidBookings'] ?? 0}', 'icon': Icons.check_circle, 'color': Colors.green},
      {'label': 'Pending', 'value': '${_stats['pendingBookings'] ?? 0}', 'icon': Icons.hourglass_empty, 'color': Colors.orange},
      {'label': 'Total Revenue', 'value': '€${(_stats['totalRevenue'] ?? 0).toStringAsFixed(2)}', 'icon': Icons.euro, 'color': Colors.purple},
      {'label': 'Sitters', 'value': '${_stats['totalSitters'] ?? 0}', 'icon': Icons.pets, 'color': Colors.teal},
      {'label': 'Owners', 'value': '${_stats['totalOwners'] ?? 0}', 'icon': Icons.person, 'color': Colors.indigo},
      {'label': 'Pets', 'value': '${_stats['totalPets'] ?? 0}', 'icon': Icons.emoji_nature, 'color': Colors.pink},
    ];

    return RefreshIndicator(
      onRefresh: () async { final r = await ApiClient().get('${ApiConfig.baseUrl}/admin/stats', headers: {'x-admin-secret': _adminSecret}); setState(() => _stats = r as Map<String, dynamic>); },
      child: GridView.builder(
        padding: EdgeInsets.all(16.w),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 12.w, mainAxisSpacing: 12.h, childAspectRatio: 1.4,
        ),
        itemCount: cards.length,
        itemBuilder: (ctx, i) {
          final c = cards[i];
          return Container(
            decoration: BoxDecoration(
              color: (c['color'] as Color).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: (c['color'] as Color).withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(c['icon'] as IconData, color: c['color'] as Color, size: 32.sp),
                  SizedBox(height: 8.h),
                  InterText(text: c['value'] as String, fontSize: 22.sp, fontWeight: FontWeight.w700, color: c['color'] as Color),
                  InterText(text: c['label'] as String, fontSize: 11.sp, color: AppColors.greyText),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── BOOKINGS TAB ─────────────────────────────────────────────────────────
  Widget _buildBookingsTab() {
    if (_listLoading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: EdgeInsets.all(12.w),
        itemCount: _bookings.length,
        itemBuilder: (ctx, i) {
          final b = _bookings[i];
          final status = b['status'] ?? '';
          final payStatus = b['paymentStatus'] ?? '';
          Color statusColor = status == 'agreed' ? Colors.green : status == 'pending' ? Colors.orange : Colors.grey;
          return Card(
            margin: EdgeInsets.only(bottom: 10.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            child: ListTile(
              contentPadding: EdgeInsets.all(12.w),
              title: InterText(text: b['petName'] ?? 'N/A', fontSize: 14.sp, fontWeight: FontWeight.w600),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 4.h),
                  Row(children: [
                    _chip(status, statusColor),
                    SizedBox(width: 6.w),
                    _chip(payStatus, payStatus == 'paid' ? Colors.green : Colors.orange),
                  ]),
                  SizedBox(height: 4.h),
                  InterText(text: 'Total: €${(b['totalAmount'] ?? 0).toStringAsFixed(2)}', fontSize: 12.sp, color: AppColors.greyText),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (val) => _updateBookingStatus(b['_id'], val),
                itemBuilder: (_) => ['pending', 'agreed', 'completed', 'cancelled']
                    .map((s) => PopupMenuItem(value: s, child: Text(s)))
                    .toList(),
                child: Icon(Icons.more_vert, color: AppColors.primaryColor),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── SITTERS TAB ──────────────────────────────────────────────────────────
  Widget _buildSittersTab() {
    if (_listLoading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: EdgeInsets.all(12.w),
        itemCount: _sitters.length,
        itemBuilder: (ctx, i) {
          final s = _sitters[i];
          final verified = s['verified'] == true;
          final ibanVerified = s['ibanVerified'] == true;
          final hasIban = s['ibanNumber'] != null && (s['ibanNumber'] as String).isNotEmpty;
          return Card(
            margin: EdgeInsets.only(bottom: 10.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primaryColor.withValues(alpha: 0.15),
                    child: InterText(text: (s['name'] as String? ?? 'S')[0].toUpperCase(), fontSize: 16.sp, fontWeight: FontWeight.w700, color: AppColors.primaryColor),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InterText(text: s['name'] ?? '', fontSize: 14.sp, fontWeight: FontWeight.w600),
                        InterText(text: s['email'] ?? '', fontSize: 11.sp, color: AppColors.greyText),
                        SizedBox(height: 4.h),
                        Row(children: [
                          _chip(verified ? 'Verified' : 'Unverified', verified ? Colors.green : Colors.grey),
                          if (hasIban) ...[SizedBox(width: 4.w), _chip(ibanVerified ? 'IBAN ✓' : 'IBAN pending', ibanVerified ? Colors.blue : Colors.orange)],
                        ]),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Switch(
                        value: verified,
                        activeThumbColor: AppColors.primaryColor,
                        onChanged: (val) => _verifySitter(s['_id'], val),
                      ),
                      if (hasIban && !ibanVerified)
                        TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: () => _verifyIban(s['_id']),
                          child: InterText(text: 'Verify\nIBAN', fontSize: 10.sp, color: Colors.blue),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── OWNERS TAB ───────────────────────────────────────────────────────────
  Widget _buildOwnersTab() {
    if (_listLoading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: EdgeInsets.all(12.w),
        itemCount: _owners.length,
        itemBuilder: (ctx, i) {
          final o = _owners[i];
          return Card(
            margin: EdgeInsets.only(bottom: 10.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.indigo.withValues(alpha: 0.15),
                child: InterText(text: (o['name'] as String? ?? 'O')[0].toUpperCase(), fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.indigo),
              ),
              title: InterText(text: o['name'] ?? '', fontSize: 14.sp, fontWeight: FontWeight.w600),
              subtitle: InterText(text: o['email'] ?? '', fontSize: 11.sp, color: AppColors.greyText),
              trailing: Icon(Icons.person_outline, color: AppColors.greyColor),
            ),
          );
        },
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20.r)),
    child: InterText(text: label, fontSize: 10.sp, color: color, fontWeight: FontWeight.w600),
  );

  // ─── MAIN BUILD ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_authenticated) return _buildLoginScreen();

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary(context),
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings, size: 22.sp),
            SizedBox(width: 8.w),
            InterText(text: 'Admin Dashboard', fontSize: 18.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryColor,
          labelColor: AppColors.textPrimary(context),
          unselectedLabelColor: AppColors.textSecondary(context),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Stats'),
            Tab(icon: Icon(Icons.book), text: 'Bookings'),
            Tab(icon: Icon(Icons.pets), text: 'Sitters'),
            Tab(icon: Icon(Icons.person), text: 'Owners'),
            Tab(icon: Icon(Icons.euro), text: 'Tarifs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStatsTab(),
          _buildBookingsTab(),
          _buildSittersTab(),
          _buildOwnersTab(),
          _buildPricingTab(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  TAB 5 — PRICING EDITOR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPricingTab() {
    if (_pricingLoading && _pricing.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pricing.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.euro, size: 48, color: Colors.grey),
            SizedBox(height: 8.h),
            const Text('Aucun tarif chargé.'),
            SizedBox(height: 8.h),
            ElevatedButton.icon(
              onPressed: _loadPricing,
              icon: const Icon(Icons.refresh),
              label: const Text('Charger les tarifs'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPricing,
      child: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          _buildPricingCurrencyPicker(),
          SizedBox(height: 16.h),
          _buildPricingGroup(
            title: 'Boost — mise en avant dans l\'app',
            subtitle: 'Tarifs unitaires par tier (bronze / silver / gold / platinum)',
            group: 'boost',
          ),
          SizedBox(height: 16.h),
          _buildPricingGroup(
            title: 'Map Boost — surligné sur la PawMap',
            subtitle: 'Tarifs par tier (bronze / silver / gold / platinum)',
            group: 'mapBoost',
          ),
          SizedBox(height: 16.h),
          _buildPricingGroup(
            title: 'Premium — abonnement',
            subtitle: 'Tarif mensuel et annuel (monthly / yearly)',
            group: 'premium',
          ),
          SizedBox(height: 24.h),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pricingSaving ? null : _savePricing,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                  icon: _pricingSaving
                      ? SizedBox(
                          width: 18.w,
                          height: 18.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_pricingSaving ? 'Sauvegarde...' : 'Enregistrer les tarifs'),
                ),
              ),
              SizedBox(width: 12.w),
              OutlinedButton.icon(
                onPressed: _pricingSaving ? null : _resetPricing,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                ),
                icon: const Icon(Icons.restore),
                label: const Text('Reset'),
              ),
            ],
          ),
          SizedBox(height: 40.h),
        ],
      ),
    );
  }

  Widget _buildPricingCurrencyPicker() {
    return Row(
      children: [
        const Text('Devise : '),
        SizedBox(width: 8.w),
        DropdownButton<String>(
          value: _pricingCurrency,
          items: const ['EUR', 'GBP', 'CHF', 'USD']
              .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _pricingCurrency = v;
              _syncPriceControllers();
            });
          },
        ),
        const Spacer(),
        Text(
          'Les modifications s\'appliquent à la devise sélectionnée.',
          style: TextStyle(fontSize: 11.sp, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildPricingGroup({
    required String title,
    required String subtitle,
    required String group,
  }) {
    final cur = _pricingCurrency;
    final byCur = (_pricing[group] as Map?) ?? {};
    final tiers = (byCur[cur] as Map?) ?? {};
    if (tiers.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Text('Aucun tarif $group pour $cur.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 2.h),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11.sp, color: Colors.grey),
            ),
            SizedBox(height: 12.h),
            ...tiers.keys.map((tier) => _buildPricingRow(group, cur, tier)),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingRow(String group, String currency, dynamic tier) {
    final key = '$group.$currency.$tier';
    final ctl = _priceCtrls.putIfAbsent(key, () => TextEditingController());
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: [
          SizedBox(
            width: 100.w,
            child: Text(
              tier.toString(),
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: TextField(
              controller: ctl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                isDense: true,
                prefixText: '$currency ',
                border: const OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
