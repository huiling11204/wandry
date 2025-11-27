import 'package:flutter/material.dart';
import '../controller/budget_controller.dart';
import '../utilities/currency_helper.dart';

class BudgetTab extends StatelessWidget {
  final String tripId;

  const BudgetTab({super.key, required this.tripId});

  @override
  Widget build(BuildContext context) {
    final budgetController = BudgetController();

    // Use StreamBuilder for real-time updates
    return StreamBuilder<BudgetData>(
      stream: budgetController.watchBudget(tripId),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading budget...'),
              ],
            ),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                const SizedBox(height: 16),
                Text(
                  'Error loading budget',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    // Trigger rebuild
                    (context as Element).markNeedsBuild();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // No data state
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'No budget data yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add itinerary items or accommodations\nto see your budget',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final budget = snapshot.data!;
        final localCurrency = budget.localCurrency ?? 'MYR';

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Total Budget Card
            _buildTotalBudgetCard(budget, localCurrency),
            const SizedBox(height: 24),

            // Header with item count
            _buildHeader(budget),
            const SizedBox(height: 16),

            // Budget Items
            _buildBudgetItem(
              'Accommodation',
              budget.accommodationMYR,
              budget.accommodationLocal,
              localCurrency,
              Icons.hotel,
              Colors.purple,
              budget.totalMYR,
            ),
            _buildBudgetItem(
              'Meals & Dining',
              budget.mealsMYR,
              budget.mealsLocal,
              localCurrency,
              Icons.restaurant,
              Colors.orange,
              budget.totalMYR,
            ),
            _buildBudgetItem(
              'Attractions & Museums',
              budget.attractionsMYR,
              budget.attractionsLocal,
              localCurrency,
              Icons.place,
              Colors.blue,
              budget.totalMYR,
            ),
            _buildBudgetItem(
              'Entertainment & Shopping',
              budget.entertainmentMYR,
              budget.entertainmentLocal,
              localCurrency,
              Icons.movie,
              Colors.pink,
              budget.totalMYR,
            ),
            if (budget.otherMYR > 0)
              _buildBudgetItem(
                'Other',
                budget.otherMYR,
                budget.otherLocal,
                localCurrency,
                Icons.more_horiz,
                Colors.grey,
                budget.totalMYR,
              ),

            const SizedBox(height: 24),

            // Currency Info
            if (localCurrency != 'MYR') _buildCurrencyInfo(localCurrency),

            const SizedBox(height: 16),

            // Budget Summary Stats
            _buildBudgetStats(budget, localCurrency),
          ],
        );
      },
    );
  }

  /// Build total budget card with gradient
  Widget _buildTotalBudgetCard(BudgetData budget, String localCurrency) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[400]!, Colors.green[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.account_balance_wallet,
            color: Colors.white,
            size: 40,
          ),
          const SizedBox(height: 12),
          const Text(
            'Total Estimated Budget',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'RM ${budget.totalMYR.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (localCurrency != 'MYR') ...[
            const SizedBox(height: 8),
            Text(
              '≈ ${CurrencyHelper.formatLocalCurrency(budget.totalLocal, localCurrency)}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              budget.accommodationCount > 0
                  ? 'Includes accommodation costs'
                  : 'Activities and meals only',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build header with item count
  Widget _buildHeader(BudgetData budget) {
    return Row(
      children: [
        const Text(
          'Budget Breakdown',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${budget.itemCount + budget.accommodationCount} items',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Build individual budget category item
  Widget _buildBudgetItem(
      String label,
      double amountMYR,
      double amountLocal,
      String localCurrency,
      IconData icon,
      Color color,
      double totalMYR,
      ) {
    final percentage = totalMYR > 0 ? (amountMYR / totalMYR * 100) : 0.0;

    // Don't show items with zero amount
    if (amountMYR == 0) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${percentage.toStringAsFixed(1)}% of total',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'RM ${amountMYR.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    if (localCurrency != 'MYR') ...[
                      const SizedBox(height: 2),
                      Text(
                        CurrencyHelper.formatLocalCurrency(
                          amountLocal,
                          localCurrency,
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build currency information card
  Widget _buildCurrencyInfo(String localCurrency) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Currency Information',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Amounts shown in Malaysian Ringgit (MYR) with approximate conversion to $localCurrency.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.blue[800],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '💡 Exchange rates are updated daily for accuracy.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  /// Build budget statistics summary
  Widget _buildBudgetStats(BudgetData budget, String localCurrency) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: Colors.grey[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Budget Statistics',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Activities',
                  budget.itemCount.toString(),
                  Icons.event,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  'Stays',
                  budget.accommodationCount.toString(),
                  Icons.hotel,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Avg per Day',
                  budget.itemCount > 0
                      ? 'RM ${(budget.totalMYR / budget.itemCount).toStringAsFixed(0)}'
                      : 'N/A',
                  Icons.today,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  'Largest',
                  _getLargestCategory(budget),
                  Icons.trending_up,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build individual stat item
  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Get the name of the largest budget category
  String _getLargestCategory(BudgetData budget) {
    final categories = {
      'Meals': budget.mealsMYR,
      'Attractions': budget.attractionsMYR,
      'Entertainment': budget.entertainmentMYR,
      'Accommodation': budget.accommodationMYR,
      'Other': budget.otherMYR,
    };

    var largest = categories.entries.first;
    for (var entry in categories.entries) {
      if (entry.value > largest.value) {
        largest = entry;
      }
    }

    return largest.value > 0 ? largest.key : 'None';
  }
}