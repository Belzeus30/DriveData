import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../../models/insurance_policy.dart';
import '../../providers/car_provider.dart';
import '../../providers/insurance_provider.dart';
import '../../utils/constants.dart';
import 'add_edit_insurance_screen.dart';
import 'travel_insurance_info_screen.dart';
import '../settings/settings_screen.dart';

/// Plná obrazovka Pojistky — vlastní Scaffold pro použití v hlavní navigaci.
class InsurancesScreen extends StatelessWidget {
  const InsurancesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pojistky'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Nastavení',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: const InsurancesContent(),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_insurance',
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddEditInsuranceScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Přidat pojistku'),
      ),
    );
  }
}

/// Obsah záložky Pojistky — seznam pojistných smluv + dálniční známky.
class InsurancesContent extends StatelessWidget {
  const InsurancesContent({super.key});

  @override
  Widget build(BuildContext context) {
    final insuranceProvider = context.watch<InsuranceProvider>();
    final carProvider = context.watch<CarProvider>();
    final policies = insuranceProvider.policies;
    final reminders = insuranceProvider.getReminders();
    final reminderIds = reminders.map((r) => r.policy.id).toSet();

    if (policies.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🛡️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'Zatím žádné pojistky.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Přidej POV, havarijní pojistku,\ndálniční známku nebo cestovní pojistku.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.info_outline),
              label: const Text('Co kryjí pojistky?'),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TravelInsuranceInfoScreen())),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // ---- UPOZORNĚNÍ ----
        if (reminders.isNotEmpty) ...[
          Text('⚠️ Vyžadují pozornost',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 8),
          ...reminders.map((r) => _PolicyCard(
                policy: r.policy,
                carName: _carName(r.policy, carProvider),
                isOverdue: r.isOverdue,
                isDueSoon: r.isDueSoon,
                onTap: () => _openEdit(context, r.policy),
                onDelete: () => _delete(context, r.policy),
                onOpenAttachment: r.policy.attachmentPath != null
                    ? () => OpenFilex.open(r.policy.attachmentPath!)
                    : null,
              )),
          const Divider(height: 24),
        ],

        // ---- AKTIVNÍ ----
        if (policies.any((p) => p.isActive && !reminderIds.contains(p.id))) ...[
          Text('✅ Aktivní pojistky',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.green.shade700)),
          const SizedBox(height: 8),
          ...policies
              .where((p) => p.isActive && !reminderIds.contains(p.id))
              .map((p) => _PolicyCard(
                    policy: p,
                    carName: _carName(p, carProvider),
                    onTap: () => _openEdit(context, p),
                    onDelete: () => _delete(context, p),                    onOpenAttachment: p.attachmentPath != null
                        ? () => OpenFilex.open(p.attachmentPath!)
                        : null,                  )),
        ],

        // ---- PROPADLÉ ----
        if (policies.any((p) => p.isExpired)) ...[
          const SizedBox(height: 8),
          Text('🗄️ Prošlé',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          ...policies
              .where((p) => p.isExpired)
              .map((p) => _PolicyCard(
                    policy: p,
                    carName: _carName(p, carProvider),
                    dimmed: true,
                    onTap: () => _openEdit(context, p),
                    onDelete: () => _delete(context, p),
                    onOpenAttachment: p.attachmentPath != null
                        ? () => OpenFilex.open(p.attachmentPath!)
                        : null,
                  )),
        ],

        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.info_outline),
          label: const Text('Průvodce krytím pojišťění'),
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const TravelInsuranceInfoScreen())),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _carName(InsurancePolicy policy, CarProvider carProvider) {
    if (policy.carId == null) return 'osobní';
    return carProvider.getCarById(policy.carId!)?.fullName ?? 'neznámé auto';
  }

  void _openEdit(BuildContext context, InsurancePolicy policy) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => AddEditInsuranceScreen(policy: policy)));
  }

  Future<void> _delete(BuildContext context, InsurancePolicy policy) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Smazat pojistku?'),
        content: Text(
            '${AppConstants.insuranceTypeLabels[policy.type]} — ${policy.provider}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Zrušit')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  Text('Smazat', style: TextStyle(color: Colors.red.shade700))),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<InsuranceProvider>().deletePolicy(policy.id);
    }
  }
}

// --------------------------------------------------------------------------

class _PolicyCard extends StatelessWidget {
  static final _dateFmt = DateFormat('d. M. yyyy');
  static final _amtFmt = NumberFormat('#,##0', 'cs');

  final InsurancePolicy policy;
  final String carName;
  final bool isOverdue;
  final bool isDueSoon;
  final bool dimmed;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;
  final VoidCallback? onOpenAttachment;

  const _PolicyCard({
    required this.policy,
    required this.carName,
    this.isOverdue = false,
    this.isDueSoon = false,
    this.dimmed = false,
    required this.onTap,
    required this.onDelete,
    this.onOpenAttachment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Color? cardColor;
    if (isOverdue) cardColor = cs.errorContainer;
    if (isDueSoon) cardColor = Colors.orange.shade50;

    return Dismissible(
      key: Key(policy.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: cs.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await onDelete();
        return false; // Provider already rebuilds the list
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        color: cardColor,
        elevation: dimmed ? 0 : 1,
        child: ListTile(
          leading: Text(
            AppConstants.insuranceTypeIcons[policy.type] ?? '📜',
            style: TextStyle(
                fontSize: 28,
                color: dimmed ? Colors.grey : null),
          ),
          title: Text(
            '${AppConstants.insuranceTypeLabels[policy.type]} — ${policy.provider}',
            style: TextStyle(
                color: dimmed ? cs.onSurfaceVariant : null,
                fontWeight: isOverdue ? FontWeight.bold : null),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Platnost do: ${_dateFmt.format(policy.validTo)}',
                style: TextStyle(
                    color: isOverdue
                        ? cs.error
                        : isDueSoon
                            ? Colors.orange.shade800
                            : null,
                    fontWeight:
                        (isOverdue || isDueSoon) ? FontWeight.bold : null),
              ),
              Text('auto: $carName',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant)),
              if (isOverdue)
                Text('❌ Propadlá ${policy.daysUntilExpiry.abs()} dní zpět',
                    style: TextStyle(
                        color: cs.error, fontSize: 12, fontWeight: FontWeight.bold)),
              if (isDueSoon)
                Text('⏳ Vyprší za ${policy.daysUntilExpiry} dní',
                    style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (policy.costPerYear != null)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_amtFmt.format(policy.costPerYear)} Kč',
                      style: theme.textTheme.labelMedium,
                    ),
                    Text('/ rok', style: theme.textTheme.bodySmall),
                  ],
                ),
              const SizedBox(width: 4),
              if (onOpenAttachment != null)
                IconButton(
                  icon: Icon(Icons.attach_file,
                      color: Theme.of(context).colorScheme.primary),
                  tooltip: 'Otevřít přílohu',
                  onPressed: onOpenAttachment,
                ),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: onTap,
          // Travel insurance info badge
          isThreeLine: policy.type == 'travel' && _hasCoverage(),
        ),
      ),
    );
  }

  bool _hasCoverage() =>
      policy.coversMedical ||
      policy.coversLuggage ||
      policy.coversDelay ||
      policy.coversLiability ||
      policy.coversCancellation ||
      policy.coversSports;
}
