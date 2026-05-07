// v23.1 part 80 — Admin dashboard redesigned around 2 pages instead of 5.
//
// Daniel : "mettre a jour tout ladmin car tout est melanger ... 2 pages
// au lieu de 4 ... voir depense owner walker sitter avec dates + statut
// paiement + revenus avec encaissement commissions et boutique pour
// visualiser combien je gagne".
//
// Page 1 — Activité : every transaction (booking + wallet) with role,
// amount, status (paid / pending / refunded / completed), dates.
// Filters by role + status + date range.
//
// Page 2 — Revenus : split-view of HoPetSit revenue.
//   • Côté gauche : commissions des bookings (20% du paiement owner).
//   • Côté droit : boutique (Boost, PawSpot, PawFollow, ChatAddon,
//     KYC, Donations).
//
// Both pages call the new /admin/v2/* endpoints (see adminRoutes.js).

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:intl/intl.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _adminSecretController = TextEditingController();
  bool _authenticated = false;
  String _adminSecret = '';

  // ─── Activity state ────────────────────────────────────────────────
  List<Map<String, dynamic>> _activityRows = [];
  bool _activityLoading = false;
  String _filterRole = 'all'; // all | owner | walker | sitter
  String _filterStatus = 'all'; // all | paid | pending_payment | refunded | completed | scheduled

  // ─── Revenue state ─────────────────────────────────────────────────
  Map<String, dynamic> _revenue = {};
  bool _revenueLoading = false;

  // ─── Platform balance ──────────────────────────────────────────────
  List<Map<String, dynamic>> _balance = [];
  bool _beneficiaryConfigured = false;
  String? _beneficiaryId;
  bool _sweepBusy = false;
  List<Map<String, dynamic>> _sweepHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _adminSecretController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    _adminSecret = _adminSecretController.text.trim();
    if (_adminSecret.isEmpty) return;
    try {
      // ping a known endpoint to validate the secret
      await ApiClient().get(
        '/admin/v2/revenue',
        headers: {'x-admin-secret': _adminSecret},
      );
      setState(() => _authenticated = true);
      await _loadAll();
    } catch (_) {
      Get.snackbar('Error', 'Invalid admin credentials',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadActivity(), _loadRevenue(), _loadBalance()]);
  }

  Future<void> _loadActivity() async {
    setState(() => _activityLoading = true);
    try {
      final params = <String, String>{
        'role': _filterRole,
        'status': _filterStatus,
        'limit': '300',
      };
      final qs = params.entries.map((e) => '${e.key}=${e.value}').join('&');
      final r = await ApiClient().get(
        '/admin/v2/activity?$qs',
        headers: {'x-admin-secret': _adminSecret},
      );
      final rows = ((r as Map)['rows'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [];
      setState(() => _activityRows = rows);
    } catch (e) {
      Get.snackbar('Error', 'activity: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      setState(() => _activityLoading = false);
    }
  }

  Future<void> _loadRevenue() async {
    setState(() => _revenueLoading = true);
    try {
      final r = await ApiClient().get(
        '/admin/v2/revenue',
        headers: {'x-admin-secret': _adminSecret},
      );
      setState(() => _revenue = Map<String, dynamic>.from(r as Map));
    } catch (e) {
      Get.snackbar('Error', 'revenue: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      setState(() => _revenueLoading = false);
    }
  }

  Future<void> _loadBalance() async {
    try {
      final r = await ApiClient().get(
        '/admin/platform-balance',
        headers: {'x-admin-secret': _adminSecret},
      );
      final m = r as Map;
      final items = ((m['items'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()) ??
          [];
      setState(() {
        _balance = items;
        _beneficiaryConfigured = m['beneficiaryConfigured'] == true;
        _beneficiaryId = (m['beneficiaryId'] ?? '').toString();
      });
    } catch (_) { /* non-critical */ }
    // History
    try {
      final r = await ApiClient().get(
        '/admin/sweep-history',
        headers: {'x-admin-secret': _adminSecret},
      );
      final items = ((r as Map)['items'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [];
      setState(() => _sweepHistory = items);
    } catch (_) { /* non-critical */ }
  }

  Future<void> _sweep() async {
    if (_sweepBusy) return;
    setState(() => _sweepBusy = true);
    try {
      final r = await ApiClient().post(
        '/admin/sweep-platform-balance',
        body: {},
        headers: {'x-admin-secret': _adminSecret},
      );
      final swept = ((r as Map)['swept'] as List?) ?? [];
      Get.snackbar(
        'Virement réussi 💰',
        '${swept.length} virement(s) lancé(s) vers ton compte société',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      await _loadBalance();
    } catch (e) {
      Get.snackbar('Virement échoué', e.toString(),
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      setState(() => _sweepBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_authenticated) return _buildLogin();
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        title: const Text('HoPetSit · Admin'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recharger',
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt_rounded), text: 'Activité'),
            Tab(icon: Icon(Icons.savings_rounded), text: 'Revenus'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActivityTab(),
          _buildRevenueTab(),
        ],
      ),
    );
  }

  Widget _buildLogin() {
    return Scaffold(
      backgroundColor: AppColors.primaryColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🔐', style: TextStyle(fontSize: 60.sp)),
                SizedBox(height: 16.h),
                PoppinsText(
                  text: 'Connexion admin',
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                SizedBox(height: 24.h),
                TextField(
                  controller: _adminSecretController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Code admin',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _login(),
                ),
                SizedBox(height: 12.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryColor,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                    ),
                    child: const Text('Se connecter'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Tab 1 — Activité
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildActivityTab() {
    return RefreshIndicator(
      onRefresh: _loadActivity,
      child: ListView(
        padding: EdgeInsets.all(12.w),
        children: [
          // Filters
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildFilterDropdown('Rôle', _filterRole, const {
                'all': 'Tous',
                'owner': 'Owner',
                'walker': 'Walker',
                'sitter': 'Sitter',
              }, (v) {
                setState(() => _filterRole = v);
                _loadActivity();
              }),
              _buildFilterDropdown('Statut', _filterStatus, const {
                'all': 'Tous',
                'paid': 'Payé',
                'pending_payment': 'En attente',
                'completed': 'Service fini',
                'refunded': 'Remboursé',
                'cancelled': 'Annulé',
              }, (v) {
                setState(() => _filterStatus = v);
                _loadActivity();
              }),
            ],
          ),
          SizedBox(height: 12.h),
          if (_activityLoading)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
          if (!_activityLoading && _activityRows.isEmpty)
            Padding(
              padding: EdgeInsets.all(40.w),
              child: Center(
                child: Text('Aucune activité avec ces filtres.',
                    style: TextStyle(color: Colors.grey, fontSize: 14.sp)),
              ),
            ),
          ..._activityRows.map(_buildActivityRow),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    Map<String, String> options,
    void Function(String) onChanged,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.divider(context)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.arrow_drop_down),
          items: options.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text('$label: ${e.value}')))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _buildActivityRow(Map<String, dynamic> r) {
    final isWithdrawal = r['kind'] == 'withdrawal';
    final status = (r['status'] ?? '').toString();
    final color = _statusColor(status);
    final amt = (r['gross'] as num?)?.toDouble() ?? 0;
    final commission = (r['commission'] as num?)?.toDouble() ?? 0;
    final currency = (r['currency'] ?? 'EUR').toString();
    final dateRaw = r['date']?.toString() ?? '';
    final date = DateTime.tryParse(dateRaw);
    final dateLbl = date != null
        ? DateFormat('dd/MM/yyyy HH:mm', 'fr').format(date.toLocal())
        : '—';

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isWithdrawal ? Icons.money_off_rounded : Icons.shopping_cart_rounded,
                color: color,
                size: 20.sp,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: PoppinsText(
                  text: isWithdrawal
                      ? 'Retrait wallet'
                      : 'Booking ${r['providerRole']?.toString().toUpperCase() ?? ''}',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    color: color,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          if (!isWithdrawal)
            Text('Owner: ${r['ownerName']}  →  Provider: ${r['providerName']}',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[700])),
          if (isWithdrawal)
            Text('${r['providerName']} (${r['providerRole']}) · méthode ${r['method'] ?? '—'}',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[700])),
          SizedBox(height: 4.h),
          Row(
            children: [
              Text(
                '${amt.abs().toStringAsFixed(2)} $currency',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              if (!isWithdrawal && commission > 0) ...[
                SizedBox(width: 8.w),
                Text(
                  '(commission HoPetSit: ${commission.toStringAsFixed(2)} $currency)',
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                ),
              ],
              const Spacer(),
              Text(dateLbl, style: TextStyle(fontSize: 11.sp, color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'paid':
        return const Color(0xFF16A34A);
      case 'completed':
        return const Color(0xFF2563EB);
      case 'pending_payment':
      case 'pending':
      case 'processing':
        return const Color(0xFFF59E0B);
      case 'refunded':
      case 'cancelled':
      case 'failed':
        return const Color(0xFFE53935);
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'paid': return 'Payé';
      case 'pending_payment': return 'En attente';
      case 'pending': return 'En attente';
      case 'processing': return 'En cours';
      case 'completed': return 'Service fini';
      case 'refunded': return 'Remboursé';
      case 'cancelled': return 'Annulé';
      case 'failed': return 'Échoué';
      default: return s.isEmpty ? '—' : s;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Tab 2 — Revenus
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildRevenueTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_loadRevenue(), _loadBalance()]);
      },
      child: ListView(
        padding: EdgeInsets.all(12.w),
        children: [
          if (_revenueLoading) const LinearProgressIndicator(),
          // 1. Beneficiary config status (warning if not set)
          if (!_beneficiaryConfigured) _buildBeneficiaryWarning(),
          if (!_beneficiaryConfigured) SizedBox(height: 16.h),
          // 2. Platform balance + RETIRER MES BÉNÉFICES
          _buildBalanceCard(),
          SizedBox(height: 16.h),
          // 3. Historique des virements société
          _buildSweepHistoryCard(),
          SizedBox(height: 16.h),
          // 4. Commissions card (booking 20%)
          _buildCommissionsCard(),
          SizedBox(height: 16.h),
          // 5. Boutique card
          _buildBoutiqueCard(),
        ],
      ),
    );
  }

  Widget _buildBeneficiaryWarning() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        border: Border.all(color: const Color(0xFFF59E0B)),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: const Color(0xFFF59E0B), size: 22.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: PoppinsText(
                  text: 'Compte société non configuré',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFB35900),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'Pour pouvoir retirer tes bénéfices vers ton compte société, '
            'configure d\'abord ton beneficiary Airwallex :\n'
            '\n1. Va sur https://www.airwallex.com/app/recipients\n'
            '2. Crée un beneficiary "HoPetSit Company Bank"\n'
            '3. Récupère son ID (ben_xxx)\n'
            '4. Sur Render → Environment → ajoute COMPANY_AIRWALLEX_BENEFICIARY_ID=ben_xxx',
            style: TextStyle(fontSize: 12.sp, color: const Color(0xFF7A4F00), height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSweepHistoryCard() {
    return _section(
      icon: Icons.history_rounded,
      iconColor: const Color(0xFF6B7280),
      title: 'Historique des virements société',
      subtitle: '${_sweepHistory.length} virement(s) effectué(s)',
      child: _sweepHistory.isEmpty
          ? Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: Center(
                child: Text('Aucun virement effectué pour l\'instant.',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
              ),
            )
          : Column(
              children: _sweepHistory.take(20).map((s) {
                final status = (s['status'] ?? '').toString();
                final statusColor = status == 'completed'
                    ? const Color(0xFF16A34A)
                    : status == 'failed'
                        ? const Color(0xFFE53935)
                        : const Color(0xFFF59E0B);
                final amt = (s['amount'] as num?)?.toDouble() ?? 0;
                final cur = (s['currency'] ?? 'EUR').toString();
                final dateRaw = s['createdAt']?.toString() ?? '';
                final date = DateTime.tryParse(dateRaw);
                final dateLbl = date != null
                    ? DateFormat('dd/MM/yyyy HH:mm', 'fr').format(date.toLocal())
                    : '—';
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 6.h),
                  child: Row(
                    children: [
                      Container(
                        width: 8.w,
                        height: 8.w,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${amt.toStringAsFixed(2)} $cur',
                              style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700),
                            ),
                            Text(dateLbl,
                                style: TextStyle(
                                    fontSize: 11.sp,
                                    color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      Text(
                        _frenchSweepStatus(status),
                        style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w800,
                            color: statusColor),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  String _frenchSweepStatus(String s) {
    switch (s) {
      case 'completed': return 'Reçu ✓';
      case 'failed': return 'Échec';
      case 'initiated':
      default: return 'En cours';
    }
  }

  Future<void> _showPartialSweepDialog() async {
    final ctrl = TextEditingController();
    final firstCur = _balance.isNotEmpty
        ? (_balance.first['currency'] ?? 'EUR').toString().toUpperCase()
        : 'EUR';
    final firstAvail = _balance.isNotEmpty
        ? ((_balance.first['available_amount'] as num?)?.toDouble() ?? 0)
        : 0;
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Retirer un montant précis'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Solde dispo : ${firstAvail.toStringAsFixed(2)} $firstCur',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[700])),
            SizedBox(height: 12.h),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Montant à retirer',
                suffixText: 'EUR',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final amt = double.tryParse(ctrl.text.replaceAll(',', '.'));
    if (amt == null || amt <= 0) {
      Get.snackbar('Montant invalide', 'Entre un montant numérique positif.',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    setState(() => _sweepBusy = true);
    try {
      await ApiClient().post(
        '/admin/sweep-platform-balance',
        body: {'amount': amt, 'currency': firstCur},
        headers: {'x-admin-secret': _adminSecret},
      );
      Get.snackbar('Virement réussi 💰', '${amt.toStringAsFixed(2)} $firstCur lancé(s) vers ton compte société',
          backgroundColor: Colors.green, colorText: Colors.white);
      await _loadBalance();
    } catch (e) {
      Get.snackbar('Virement échoué', e.toString(),
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      setState(() => _sweepBusy = false);
    }
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEF4324), Color(0xFFFF6B45)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4324).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.savings_rounded, color: Colors.white, size: 24.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text('💰 MES BÉNÉFICES À RETIRER',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          if (_balance.isEmpty)
            Text('— € (en attente de paiements)',
                style: TextStyle(color: Colors.white, fontSize: 24.sp, fontWeight: FontWeight.w800)),
          ..._balance.map((b) {
            final available = (b['available_amount'] as num?)?.toDouble() ?? 0;
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 2.h),
              child: Text(
                '${available.toStringAsFixed(2)} ${(b['currency'] ?? 'EUR').toString().toUpperCase()}',
                style: TextStyle(color: Colors.white, fontSize: 28.sp, fontWeight: FontWeight.w900),
              ),
            );
          }),
          SizedBox(height: 8.h),
          Text(
            'Argent disponible sur ta plateforme HoPetSit (commissions + boutique). Tape ci-dessous pour le virer vers ton IBAN société.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11.sp),
          ),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_sweepBusy || !_beneficiaryConfigured) ? null : _sweep,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFEF4324),
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
                elevation: 4,
              ),
              icon: Icon(_sweepBusy ? Icons.hourglass_top : Icons.account_balance_rounded, size: 22.sp),
              label: Text(
                _sweepBusy
                    ? 'Virement en cours…'
                    : 'Retirer TOUT mes bénéfices vers mon IBAN',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          // Bouton "montant précis" pour les retraits partiels
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (_sweepBusy || !_beneficiaryConfigured) ? null : _showPartialSweepDialog,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white, width: 1.5),
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: Text(
                'Retirer un montant précis…',
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionsCard() {
    final c = (_revenue['commissions'] as Map?) ?? {};
    final allTime = (c['allTime'] as num?)?.toDouble() ?? 0;
    final thisMonth = (c['thisMonth'] as num?)?.toDouble() ?? 0;
    final last7d = (c['last7d'] as num?)?.toDouble() ?? 0;
    final bookingCount = (c['bookingCount'] as num?)?.toInt() ?? 0;
    final gross = (c['grossAllTime'] as num?)?.toDouble() ?? 0;

    return _section(
      icon: Icons.percent_rounded,
      iconColor: const Color(0xFF2563EB),
      title: 'Commissions bookings (20%)',
      subtitle: '$bookingCount bookings payés · ${gross.toStringAsFixed(2)} € de paiements owner',
      child: Column(
        children: [
          _row('Tous temps', '${allTime.toStringAsFixed(2)} €', big: true),
          _row('Ce mois-ci', '${thisMonth.toStringAsFixed(2)} €'),
          _row('7 derniers jours', '${last7d.toStringAsFixed(2)} €'),
        ],
      ),
    );
  }

  Widget _buildBoutiqueCard() {
    final b = (_revenue['boutique'] as Map?) ?? {};
    final profileBoost = (b['profileBoost'] as Map?) ?? {};
    final mapBoost = (b['mapBoost'] as Map?) ?? {};
    final donations = (b['donations'] as Map?) ?? {};
    final subs = ((b['subscriptionsByPlan'] as List?) ?? []).whereType<Map>().toList();
    final knownTotal = (b['knownTotal'] as num?)?.toDouble() ?? 0;

    return _section(
      icon: Icons.shopping_bag_rounded,
      iconColor: const Color(0xFFEF4324),
      title: 'Boutique HoPetSit',
      subtitle: 'Boost / PawSpot / PawFollow / Donations',
      child: Column(
        children: [
          _row('Total connu', '${knownTotal.toStringAsFixed(2)} €', big: true),
          _row(
            'Profile Boost',
            '${(profileBoost['count'] ?? 0)} achats · ${((profileBoost['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} €',
          ),
          _row(
            'PawSpot (Map Boost)',
            '${(mapBoost['count'] ?? 0)} achats · ${((mapBoost['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} €',
          ),
          _row(
            'Abonnements actifs (PawFollow / Premium)',
            '${subs.fold<int>(0, (s, p) => s + ((p['count'] as num?)?.toInt() ?? 0))} payments',
          ),
          _row(
            'Donations',
            '${(donations['count'] ?? 0)} dons · ${((donations['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} €',
          ),
        ],
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, color: iconColor, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PoppinsText(text: title, fontSize: 14.sp, fontWeight: FontWeight.w800),
                    if (subtitle != null)
                      Text(subtitle,
                          style: TextStyle(fontSize: 11.sp, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          child,
        ],
      ),
    );
  }

  Widget _row(String k, String v, {bool big = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: TextStyle(fontSize: big ? 13.sp : 12.sp, color: Colors.grey[700])),
          Text(
            v,
            style: TextStyle(
              fontSize: big ? 16.sp : 13.sp,
              fontWeight: big ? FontWeight.w800 : FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}
