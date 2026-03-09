import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/trailer.dart';
import '../../providers/trailer_provider.dart';
import '../settings/settings_screen.dart';
import 'add_edit_trailer_screen.dart';

class TrailersScreen extends StatelessWidget {
  const TrailersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vozíky a přívěsy'),
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
      body: Consumer<TrailerProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final trailers = provider.trailers;
          final reminders = provider.getReminders();
          final reminderIds = reminders.map((r) => r.trailer.id).toSet();

          if (trailers.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🚗🔗', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text('Žádné vozíky',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Přidej přívěs nebo karavan.\nDostaneš upozornění na STK.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // --- MOT REMINDERS ---
              if (reminders.isNotEmpty) ...[
                Text(
                  '⚠️ Vyžadují pozornost',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 8),
                ...reminders.map((r) => _TrailerCard(
                      trailer: r.trailer,
                      isOverdue: r.isOverdue,
                      isDueSoon: r.isDueSoon,
                      onTap: () => _openEdit(context, r.trailer),
                      onDelete: () => _delete(context, r.trailer),
                    )),
                const Divider(height: 24),
              ],

              // --- OTHER TRAILERS ---
              if (trailers.any((t) => !reminderIds.contains(t.id))) ...[
                Text(
                  '🔗 Vozíky',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 8),
                ...trailers
                    .where((t) => !reminderIds.contains(t.id))
                    .map((t) => _TrailerCard(
                          trailer: t,
                          onTap: () => _openEdit(context, t),
                          onDelete: () => _delete(context, t),
                        )),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_trailers',
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddEditTrailerScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Přidat vozík'),
      ),
    );
  }

  void _openEdit(BuildContext context, Trailer trailer) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => AddEditTrailerScreen(trailer: trailer)));
  }

  Future<void> _delete(BuildContext context, Trailer trailer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Smazat vozík?'),
        content: Text(
            '${trailer.name} — jízdy s tímto vozíkem budou zachovány, ale bez vazby na vozík.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Zrušit')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Smazat',
                  style: TextStyle(color: Colors.red.shade700))),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<TrailerProvider>().deleteTrailer(trailer.id);
    }
  }
}

// --------------------------------------------------------------------------

class _TrailerCard extends StatelessWidget {
  final Trailer trailer;
  final bool isOverdue;
  final bool isDueSoon;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TrailerCard({
    required this.trailer,
    this.isOverdue = false,
    this.isDueSoon = false,
    required this.onTap,
    required this.onDelete,
  });

  static final _dateFmt = DateFormat('d. M. yyyy');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Color? cardColor;
    if (isOverdue) cardColor = cs.errorContainer;
    if (isDueSoon) cardColor = Colors.orange.shade50;

    String techStatus = 'STK nezadáno';
    Color techColor = cs.onSurfaceVariant;
    if (trailer.nextTechDate != null) {
      if (isOverdue) {
        techStatus =
            '❌ STK propadlo ${trailer.daysUntilTech.abs()} dní zpět';
        techColor = cs.error;
      } else if (isDueSoon) {
        techStatus =
            '⏳ STK za ${trailer.daysUntilTech} dní (${_dateFmt.format(trailer.nextTechDate!)})';
        techColor = Colors.orange.shade800;
      } else {
        techStatus = '✅ STK do ${_dateFmt.format(trailer.nextTechDate!)}';
        techColor = Colors.green.shade700;
      }
    }

    return Dismissible(
      key: Key(trailer.id),
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
        onDelete();
        return false;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        color: cardColor,
        child: ListTile(
          onTap: onTap,
          leading: const Text('🚗🔗', style: TextStyle(fontSize: 26)),
          title: Text(
            trailer.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (trailer.licensePlate != null)
                Text(trailer.licensePlate!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(
                techStatus,
                style: TextStyle(
                    fontSize: 12,
                    color: techColor,
                    fontWeight: (isOverdue || isDueSoon)
                        ? FontWeight.w600
                        : FontWeight.normal),
              ),
              if (trailer.maxWeightKg != null)
                Text(
                  '${trailer.maxWeightKg!.toStringAsFixed(0)} kg celk. hmotnost',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
            ],
          ),
          trailing: Icon(
            isOverdue
                ? Icons.warning_rounded
                : isDueSoon
                    ? Icons.access_time_rounded
                    : Icons.rv_hookup,
            color: isOverdue
                ? cs.error
                : isDueSoon
                    ? Colors.orange
                    : cs.onSurfaceVariant,
          ),
          isThreeLine: true,
        ),
      ),
    );
  }
}
