import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/input_sheets.dart';
import '../widgets/shared_widgets.dart';

class SubscriptionsView extends StatelessWidget {
  const SubscriptionsView({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseService?>();

    if (db == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<Subscription>>(
          stream: db.subscriptionsStream(),
          builder: (context, snapshot) {
            final items = snapshot.data ?? [];

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Subscriptions', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                        Text('Recurring payments', style: TextStyle(color: AppColors.muted)),
                      ],
                    ),
                    IconButton.filledTonal(
                      onPressed: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const AddSubscriptionSheet(),
                      ),
                      icon: const Icon(Icons.add_task_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                if (items.isEmpty)
                  const EmptyState(
                    title: 'No subscriptions',
                    subtitle: 'Tap Seed demo on Home or add Netflix, Gym, Rent and other recurring payments.',
                  )
                else
                  ...items.map((subscription) => _SubscriptionTile(subscription: subscription, db: db)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  final Subscription subscription;
  final DatabaseService db;

  const _SubscriptionTile({required this.subscription, required this.db});

  IconData iconForName(String name) {
    final n = name.toLowerCase();
    if (n.contains('netflix')) return Icons.movie_rounded;
    if (n.contains('gym')) return Icons.fitness_center_rounded;
    if (n.contains('rent')) return Icons.home_rounded;
    if (n.contains('spotify')) return Icons.music_note_rounded;
    return Icons.repeat_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withValues(alpha: 0.17),
            child: Icon(iconForName(subscription.name), color: AppColors.primaryLight),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(subscription.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (subscription.isAuto ? AppColors.blue : AppColors.primary).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        subscription.isAuto ? 'AUTO' : 'MANUAL',
                        style: TextStyle(
                          color: subscription.isAuto ? AppColors.blue : AppColors.primaryLight,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Next due: ${DateFormat('MMM d, yyyy').format(subscription.dueDate)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Rs ${subscription.cost.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              if (!subscription.isAuto)
                Switch.adaptive(
                  value: subscription.isNotificationOn,
                  onChanged: (value) => db.toggleSubscriptionNotification(subscriptionId: subscription.id, enabled: value),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(top: 8, right: 4),
                  child: Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.muted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
