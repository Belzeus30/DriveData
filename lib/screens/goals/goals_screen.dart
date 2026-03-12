import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/goal.dart';
import '../../providers/car_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/trip_provider.dart';
import '../../utils/constants.dart';
import 'add_edit_goal_screen.dart';
import '../settings/settings_screen.dart';

/// Goals & challenges screen.
///
/// Displays two tabs — **Active** and **Archive** — backed by a [TabController].
/// Each tab renders a [_GoalsList] that shows progress (computed on-the-fly from
/// [TripProvider]) for every [Goal] in [GoalProvider].
///
/// Depends on [GoalProvider], [TripProvider], and [CarProvider].
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

/// State for [GoalsScreen].
///
/// Uses [SingleTickerProviderStateMixin] to provide a vsync for [TabController].
class _GoalsScreenState extends State<GoalsScreen>
    with SingleTickerProviderStateMixin {
  /// Controls the Active / Archive tab selection.
  late TabController _tabController;

  /// Initialises the [TabController] with 2 tabs.
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  /// Disposes [_tabController] to free the animation ticker.
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cíle a výzvy'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Nastavení',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Aktivní'),
            Tab(text: 'Archiv'),
          ],
        ),
      ),
      body: Consumer3<GoalProvider, TripProvider, CarProvider>(
        builder: (context, goalProvider, tripProvider, carProvider, _) {
          if (goalProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final active = goalProvider.activeGoals;
          final archive =
              goalProvider.goals.where((g) => !g.isActive).toList();
          return TabBarView(
            controller: _tabController,
            children: [
              _GoalsList(
                goals: active,
                goalProvider: goalProvider,
                tripProvider: tripProvider,
                carProvider: carProvider,
                emptyText: 'Žádné aktivní cíle\nPřidej první výzvu!',
              ),
              _GoalsList(
                goals: archive,
                goalProvider: goalProvider,
                tripProvider: tripProvider,
                carProvider: carProvider,
                emptyText: 'Archiv je prázdný',
                isArchive: true,
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
          heroTag: 'fab_goals',
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AddEditGoalScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Přidat cíl'),
      ),
    );
  }
}

/// Reusable list widget for a single tab in [GoalsScreen].
///
/// Computes live progress for each [Goal] via [GoalProvider.computeProgress]
/// and renders a [_GoalCard] per goal. Handles empty state with [emptyText].
class _GoalsList extends StatelessWidget {
  /// Goals to display in this list.
  final List<Goal> goals;
  final GoalProvider goalProvider;
  final TripProvider tripProvider;
  final CarProvider carProvider;
  /// Message shown when [goals] is empty.
  final String emptyText;
  /// `true` when displaying the archive tab (changes menu labels).
  final bool isArchive;

  const _GoalsList({
    required this.goals,
    required this.goalProvider,
    required this.tripProvider,
    required this.carProvider,
    required this.emptyText,
    this.isArchive = false,
  });

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      return Center(
        child: Text(emptyText,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600])),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: goals.length,
      itemBuilder: (context, i) {
        final goal = goals[i];
        final progress =
            goalProvider.computeProgress(goal, tripProvider.trips);
        final carName = goal.carId != null
            ? carProvider.getCarById(goal.carId!)?.fullName ?? '?'
          : 'Všechna vozidla';
        return _GoalCard(
          goal: goal,
          progress: progress,
          carName: carName,
          isArchive: isArchive,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => AddEditGoalScreen(goal: goal))),
          onToggle: () => goalProvider.toggleActive(goal),
          onDelete: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Smazat cíl?'),
                content: Text(
                    AppConstants.goalTypeLabels[goal.type] ?? goal.type),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Zrušit')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Smazat')),
                ],
              ),
            );
            if (confirmed == true && context.mounted) await goalProvider.deleteGoal(goal.id);
          },
        );
      },
    );
  }
}

/// Card widget for a single [Goal] showing type, car scope, progress bar,
/// percentage, and optional deadline.
///
/// The progress bar colour is green when achieved, orange when ≥70%, or
/// the theme primary colour otherwise. A "Splneno!" badge is shown when
/// [GoalProgress.isAchieved] is `true`.
class _GoalCard extends StatelessWidget {
  /// The goal to display.
  final Goal goal;
  /// Pre-computed progress snapshot for this goal.
  final GoalProgress progress;
  /// Human-readable vehicle name (or `'Všechna vozidla'` for global goals).
  final String carName;
  /// `true` when the goal is in the archive tab.
  final bool isArchive;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _GoalCard({
    required this.goal,
    required this.progress,
    required this.carName,
    required this.isArchive,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = AppConstants.goalTypeIcons[goal.type] ?? '🎯';
    final label = AppConstants.goalTypeLabels[goal.type] ?? goal.type;
    final unit = AppConstants.goalTypeUnits[goal.type] ?? '';
    final progressColor = progress.isAchieved
        ? Colors.green
        : progress.progress >= 0.7
            ? Colors.orange
            : theme.colorScheme.primary;

    String currentStr = progress.current != null
        ? '${progress.current!.toStringAsFixed(1)} $unit'
        : '–';
    String targetStr = '${goal.targetValue.toStringAsFixed(
      goal.type == 'trips_month' || goal.type == 'km_month' ? 0 : 1,
    )} $unit';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(carName,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                if (progress.isAchieved)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('✅ Splněno!',
                        style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'toggle') onToggle();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'toggle',
                        child:
                            Text(isArchive ? 'Obnovit' : 'Archivovat')),
                    const PopupMenuItem(
                        value: 'delete', child: Text('Smazat')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Flexible(
                  child: Text('Aktuálně: $currentStr',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
                const Spacer(),
                const SizedBox(width: 8),
                Flexible(
                  child: Text('Cíl: $targetStr',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.progress,
                minHeight: 10,
                color: progressColor,
                backgroundColor: progressColor.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${(progress.progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                            fontSize: 12,
                            color: progressColor,
                            fontWeight: FontWeight.bold)),
                    if (progress.isLowerBetter) ...
                      [
                        const SizedBox(width: 4),
                        Text('↓ méně = lépe',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[500])),
                      ],
                  ],
                ),
                if (goal.deadline != null) _DeadlineChip(goal.deadline!),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }
}

/// Small inline chip showing the goal deadline date.
///
/// Turns red with a warning icon when the deadline has already passed.
class _DeadlineChip extends StatelessWidget {
  /// Date formatter shared across all chip instances.
  static final _fmt = DateFormat('d. M. yyyy');
  /// The deadline date to display.
  final DateTime deadline;
  const _DeadlineChip(this.deadline);

  @override
  Widget build(BuildContext context) {
    final overdue = deadline.isBefore(DateTime.now());
    final color = overdue ? Colors.red : Colors.grey[600]!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(overdue ? Icons.warning_amber_rounded : Icons.event,
            size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          overdue
              ? 'Po term\u00ednu!'
              : 'Do: ${_fmt.format(deadline)}',
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}