import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/input_sheets.dart';
import '../widgets/shared_widgets.dart';

class EventsSavingsView extends StatelessWidget {
  const EventsSavingsView({super.key});

  void _showTargetDialog(BuildContext context, DatabaseService db, double current) {
    final controller = TextEditingController(text: current.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Set Savings Target'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Target Amount'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null) db.updateSavingsTarget(val);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseService?>();

    if (db == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Events & Savings',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                IconButton.filledTonal(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const AddEventSheet(),
                  ),
                  icon: const Icon(Icons.add_chart_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            StreamBuilder<List<ScheduledEvent>>(
              stream: db.eventsStream(),
              builder: (context, snapshot) => _CalendarGrid(events: snapshot.data ?? []),
            ),
            const SizedBox(height: 20),
            StreamBuilder<UserProfile>(
              stream: db.userProfileStream(),
              builder: (context, userSnap) {
                final target = userSnap.data?.savingsTarget ?? 5000;
                
                return StreamBuilder<List<Account>>(
                  stream: db.accountsStream(),
                  builder: (context, snapshot) {
                    final accounts = snapshot.data ?? [];
                    final saved = accounts.fold<double>(0, (sum, account) => sum + max(0, account.balance));
                    return _SavingsCard(
                      saved: saved, 
                      target: target,
                      onEditTarget: () => _showTargetDialog(context, db, target),
                    );
                  },
                );
              }
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatefulWidget {
  final List<ScheduledEvent> events;

  const _CalendarGrid({required this.events});

  @override
  State<_CalendarGrid> createState() => _CalendarGridState();
}

class _CalendarGridState extends State<_CalendarGrid> {
  int monthOffset = 0;

  bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final displayMonth = DateTime(now.year, now.month + monthOffset, 1);
    final firstDay = DateTime(displayMonth.year, displayMonth.month, 1);
    final totalDays = DateUtils.getDaysInMonth(displayMonth.year, displayMonth.month);
    final blanks = firstDay.weekday % 7;
    final totalCells = blanks + totalDays;
    final monthEvents = widget.events.where((event) => event.date.year == displayMonth.year && event.date.month == displayMonth.month).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => monthOffset--),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat('MMMM yyyy').format(displayMonth),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => monthOffset++),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [_WeekDay('S'), _WeekDay('M'), _WeekDay('T'), _WeekDay('W'), _WeekDay('T'), _WeekDay('F'), _WeekDay('S')],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            itemCount: totalCells,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              if (index < blanks) return const SizedBox.shrink();

              final day = index - blanks + 1;
              final date = DateTime(displayMonth.year, displayMonth.month, day);
              final hasEvent = widget.events.any((event) => sameDay(event.date, date));
              final isToday = sameDay(date, now);

              return Container(
                decoration: BoxDecoration(
                  color: isToday ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: hasEvent ? AppColors.primaryLight : Colors.white.withValues(alpha: 0.04)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text('$day', style: TextStyle(fontWeight: isToday ? FontWeight.w900 : FontWeight.w600)),
                    if (hasEvent)
                      Positioned(
                        bottom: 6,
                        child: Container(
                          height: 5,
                          width: 5,
                          decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          if (monthEvents.isEmpty)
            const Text('No scheduled events this month.', style: TextStyle(color: AppColors.muted))
          else
            Column(
              children: monthEvents.take(4).map((event) {
                return Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available_rounded),
                      const SizedBox(width: 10),
                      Expanded(child: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                      Text('\$${event.expectedCost.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.muted)),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _WeekDay extends StatelessWidget {
  final String text;

  const _WeekDay(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800));
  }
}

class _SavingsCard extends StatelessWidget {
  final double saved;
  final double target;
  final VoidCallback onEditTarget;

  const _SavingsCard({required this.saved, required this.target, required this.onEditTarget});

  @override
  Widget build(BuildContext context) {
    final progress = target <= 0 ? 0.0 : (saved / target).clamp(0.0, 1.0).toDouble();

    return AppCard(
      onTap: onEditTarget,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Savings Target', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              Icon(Icons.edit_note_rounded, color: AppColors.primaryLight, size: 20),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '\$${saved.toStringAsFixed(0)} saved from \$${target.toStringAsFixed(0)}',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: AppColors.surface,
              valueColor: const AlwaysStoppedAnimation(AppColors.primaryLight),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${(progress * 100).toStringAsFixed(0)}% completed',
            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.green),
          ),
        ],
      ),
    );
  }
}
