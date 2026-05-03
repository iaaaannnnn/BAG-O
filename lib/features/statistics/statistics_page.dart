part of '../../app/app.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: StatisticsSection(),
      ),
    );
  }
}

class StatisticsSection extends StatefulWidget {
  final bool embedInCard;
  const StatisticsSection({Key? key, this.embedInCard = false}) : super(key: key);

  @override
  State<StatisticsSection> createState() => _StatisticsSectionState();
}

class _StatisticsSectionState extends State<StatisticsSection> {
  String? _barangay;
  bool _loadingBarangay = true;
  String? _barangayError;
  String _timePeriod = 'Monthly'; // weekly, monthly, yearly for residents vs guests
  String _populationTrendPeriod = 'Weekly'; // Daily, Weekly, Monthly, Yearly for population trend

  @override
  void initState() {
    super.initState();
    _loadBarangay();
  }

  Future<void> _loadBarangay() async {
    setState(() {
      _loadingBarangay = true;
      _barangayError = null;
    });

    try {
      final b = await AuthService.waitForBarangay();
      if (!mounted) return;
      setState(() {
        _barangay = b;
        _loadingBarangay = false;
        if (b == null || b.isEmpty) {
          _barangayError = 'Barangay information not available.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingBarangay = false;
        _barangayError = 'Failed to load barangay information.';
      });
    }
  }

  // Live stream of resident status counts for the current barangay
  Stream<Map<String, int>> _residentStatsStream() {
    final barangay = _barangay ?? '';
    if (barangay.isEmpty) {
      return const Stream<Map<String, int>>.empty();
    }
    return FirebaseFirestore.instance
        .collection('users')
        .where('type', isEqualTo: 'Resident')
        .where('barangay', isEqualTo: barangay)
        .snapshots()

        .map((snap) {
      int pending = 0, approved = 0, rejected = 0;
      for (var doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // Count rejected by presence of rejectedAt timestamp (not by status, so deletions don't affect count)
        if (data['rejectedAt'] != null) {
          rejected++;
        } else {
          final status = (data['status'] ?? data['approvalStatus'] ?? data['approval'] ?? '')
              .toString()
              .toLowerCase();
          if (status == 'pending') pending++;
          else if (status == 'approved') approved++;
        }
      }
      return {'pending': pending, 'approved': approved, 'rejected': rejected};
    });
  }

  // Live stream of complaint status counts for the current barangay
  Stream<Map<String, int>> _complaintStatsStream() {
    final barangay = _barangay ?? '';
    if (barangay.isEmpty) {
      return const Stream<Map<String, int>>.empty();
    }
    return FirebaseFirestore.instance
        .collection('complaints')
        .where('barangay', isEqualTo: barangay)
        .snapshots()
        .map((snap) {
      int pending = 0, resolved = 0, invalid = 0;
      for (var doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = (data['status'] ?? '')
            .toString()
            .toLowerCase();
        if (status == 'resolved') {
          resolved++;
        } else if (status == 'rejected' || status == 'invalid') {
          invalid++;
        } else {
          pending++;
        }
      }
      return {'pending': pending, 'resolved': resolved, 'invalid': invalid};
    });
  }

  Future<Map<String, int>> _getResidentStats() async {
    if (kUseMockData) {
      return {'pending': 2, 'approved': 5, 'rejected': 1};
    }

    final barangay = _barangay ?? '';
    if (barangay.isEmpty) return {'pending': 0, 'approved': 0, 'rejected': 0};

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('type', isEqualTo: 'Resident')
          .where('barangay', isEqualTo: barangay)
          .get()
          .timeout(const Duration(seconds: 8));

      int pending = 0, approved = 0, rejected = 0;
      for (var doc in snap.docs) {
        final data = doc.data();
        // Count rejected by presence of rejectedAt timestamp (not by status, so deletions don't affect count)
        if (data['rejectedAt'] != null) {
          rejected++;
        } else {
          final status = (data['status'] ?? data['approvalStatus'] ?? data['approval'] ?? '').toString().toLowerCase();
          if (status == 'pending') pending++;
          else if (status == 'approved') approved++;
        }
      }
      return {'pending': pending, 'approved': approved, 'rejected': rejected};
    } catch (e) {
      debugLog('Error fetching resident stats: $e');
      return {'pending': 0, 'approved': 0, 'rejected': 0};
    }
  }

  Future<Map<String, int>> _getComplaintStats() async {
    if (kUseMockData) {
      return {'pending': 3, 'resolved': 2};
    }

    final barangay = _barangay ?? '';
    if (barangay.isEmpty) return {'pending': 0, 'resolved': 0};

    try {
      final snap = await FirebaseFirestore.instance
          .collection('complaints')
          .where('barangay', isEqualTo: barangay)
          .get()
          .timeout(const Duration(seconds: 8));

      int pending = 0, resolved = 0;
      for (var doc in snap.docs) {
        final data = doc.data();
        final status = (data['status'] ?? '').toString().toLowerCase();
        if (status == 'resolved') resolved++;
        else pending++;
      }
      return {'pending': pending, 'resolved': resolved};
    } catch (e) {
      debugLog('Error fetching complaint stats: $e');
      return {'pending': 0, 'resolved': 0};
    }
  }

  // Get residents and guest residents count by approval status - REAL-TIME STREAM with time period filter
  Stream<Map<String, Map<String, int>>> _getResidentsVsGuestStatsStream() {
    final barangay = _barangay ?? '';
    if (barangay.isEmpty) {
      return const Stream.empty();
    }

    // Calculate date range based on selected period
    final now = DateTime.now();
    DateTime startDate;
    
    switch (_timePeriod) {
      case 'Weekly':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'Yearly':
        startDate = now.subtract(const Duration(days: 365));
        break;
      case 'Monthly':
      default:
        startDate = now.subtract(const Duration(days: 30));
        break;
    }

    return FirebaseFirestore.instance
        .collection('users')
        .where('barangay', isEqualTo: barangay)
        .snapshots()
        .map((snap) {
      int resPending = 0, resApproved = 0, guestPending = 0, guestApproved = 0;
      
      for (var doc in snap.docs) {
        final data = doc.data();
        
        // Filter by date if createdAt exists
        final createdAt = data['createdAt'];
        if (createdAt != null) {
          try {
            final docDate = (createdAt as Timestamp).toDate();
            if (docDate.isBefore(startDate)) {
              continue; // Skip if outside the selected period
            }
          } catch (e) {
            debugLog('Error parsing date: $e');
          }
        }
        
        final type = (data['type'] ?? '').toString();
        final status = (data['status'] ?? data['approvalStatus'] ?? data['approval'] ?? 'approved').toString().toLowerCase();

        if (type == 'Resident') {
          if (status == 'pending') resPending++;
          else if (status == 'approved') resApproved++;
        } else if (type == 'Guest Resident') {
          if (status == 'pending') guestPending++;
          else if (status == 'approved') guestApproved++;
        }
      }

      return {
        'Residents': {'pending': resPending, 'approved': resApproved},
        'Guests': {'pending': guestPending, 'approved': guestApproved}
      };
    });
  }

  // Get total population data for line chart - REAL-TIME STREAM
  // Get just the total count of residents vs guests (population comparison only)
  Stream<Map<String, int>> _getPopulationComparisonStream() {
    final barangay = _barangay ?? '';
    if (barangay.isEmpty) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('users')
        .where('barangay', isEqualTo: barangay)
        .snapshots()
        .map((snap) {
      int residents = 0, guestResidents = 0;
      
      for (var doc in snap.docs) {
        final data = doc.data();
        final type = (data['type'] ?? '').toString();
        if (type == 'Resident') residents++;
        else if (type == 'Guest Resident') guestResidents++;
      }

      return {
        'residents': residents,
        'guests': guestResidents,
      };
    });
  }

  Stream<List<Map<String, dynamic>>> _getPopulationTrendDataStream() {
    final barangay = _barangay ?? '';
    if (barangay.isEmpty) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('users')
        .where('barangay', isEqualTo: barangay)
        .snapshots()
        .map((snap) {
      final now = DateTime.now();
      final List<Map<String, dynamic>> dataPoints = [];
      
      // Get all users with their creation dates
      final users = snap.docs.map((doc) {
        final data = doc.data();
        final type = (data['type'] ?? '').toString();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? 
                          (data['timestamp'] as Timestamp?)?.toDate() ?? 
                          now;
        return {'type': type, 'createdAt': createdAt};
      }).where((u) => u['type'] == 'Resident' || u['type'] == 'Guest Resident').toList();

      // Generate data points based on selected timeframe using actual creation data
      switch (_populationTrendPeriod) {
        case 'Daily':
          // Show hourly data for today
          for (int hour = 6; hour <= 21; hour += 3) {
            final cutoff = DateTime(now.year, now.month, now.day, hour);
            final count = users.where((u) => (u['createdAt'] as DateTime).isBefore(cutoff) || (u['createdAt'] as DateTime).isAtSameMomentAs(cutoff)).length;
            final label = hour < 12 ? '${hour}am' : hour == 12 ? '12pm' : '${hour - 12}pm';
            dataPoints.add({'day': label, 'total': count});
          }
          break;
        case 'Weekly':
          // Show daily data for this week
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          for (int i = 0; i < 7; i++) {
            final dayEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + i, 23, 59, 59);
            if (dayEnd.isAfter(now)) {
              // Only show up to today
              if (i <= now.weekday - 1) {
                final count = users.where((u) => (u['createdAt'] as DateTime).isBefore(dayEnd)).length;
                dataPoints.add({'day': days[i], 'total': count});
              }
            } else {
              final count = users.where((u) => (u['createdAt'] as DateTime).isBefore(dayEnd)).length;
              dataPoints.add({'day': days[i], 'total': count});
            }
          }
          break;
        case 'Monthly':
          // Show weekly data for this month
          final monthStart = DateTime(now.year, now.month, 1);
          for (int week = 0; week < 4; week++) {
            final weekEnd = monthStart.add(Duration(days: (week + 1) * 7));
            if (weekEnd.isAfter(now) && week > 0) {
              // Only show weeks that have passed or current week
              final dayOfMonth = now.day;
              final currentWeek = ((dayOfMonth - 1) / 7).floor();
              if (week <= currentWeek) {
                final count = users.where((u) => (u['createdAt'] as DateTime).isBefore(now)).length;
                dataPoints.add({'day': 'Wk${week + 1}', 'total': count});
              }
            } else {
              final cutoff = weekEnd.isAfter(now) ? now : weekEnd;
              final count = users.where((u) => (u['createdAt'] as DateTime).isBefore(cutoff)).length;
              dataPoints.add({'day': 'Wk${week + 1}', 'total': count});
            }
          }
          break;
        case 'Yearly':
          // Show monthly data for this year
          final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          for (int m = 0; m < 12; m++) {
            final monthEnd = DateTime(now.year, m + 2, 0, 23, 59, 59);
            if (m + 1 <= now.month) {
              final cutoff = (m + 1 == now.month) ? now : monthEnd;
              final count = users.where((u) => (u['createdAt'] as DateTime).isBefore(cutoff)).length;
              dataPoints.add({'day': months[m], 'total': count});
            }
          }
          break;
        default:
          // Weekly as default
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          for (int i = 0; i < 7; i++) {
            final dayEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + i, 23, 59, 59);
            if (i <= now.weekday - 1) {
              final count = users.where((u) => (u['createdAt'] as DateTime).isBefore(dayEnd)).length;
              dataPoints.add({'day': days[i], 'total': count});
            }
          }
      }
      
      // Ensure at least one data point
      if (dataPoints.isEmpty) {
        dataPoints.add({'day': 'Now', 'total': users.length});
      }
      
      return dataPoints;
    });
  }

  // Get residents and guest residents count by approval status - REAL-TIME STREAM
  Future<Map<String, Map<String, int>>> _getResidentsVsGuestStats() async {
    final barangay = _barangay ?? '';
    if (barangay.isEmpty) {
      return {
        'Residents': {'pending': 0, 'approved': 0},
        'Guests': {'pending': 0, 'approved': 0}
      };
    }

    try {
      // Get regular residents
      final residentsSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('type', isEqualTo: 'Resident')
          .where('barangay', isEqualTo: barangay)
          .get()
          .timeout(const Duration(seconds: 8));

      int resPending = 0, resApproved = 0;
      for (var doc in residentsSnap.docs) {
        final data = doc.data();
        final status = (data['status'] ?? data['approvalStatus'] ?? data['approval'] ?? 'approved')
            .toString()
            .toLowerCase();
        if (status == 'pending') resPending++;
        else if (status == 'approved') resApproved++;
      }

      // Get guest residents
      final guestSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('type', isEqualTo: 'Guest Resident')
          .where('barangay', isEqualTo: barangay)
          .get()
          .timeout(const Duration(seconds: 8));

      int guestPending = 0, guestApproved = 0;
      for (var doc in guestSnap.docs) {
        final data = doc.data();
        final status = (data['status'] ?? 'approved').toString().toLowerCase();
        if (status == 'pending') guestPending++;
        else if (status == 'approved') guestApproved++;
      }

      return {
        'Residents': {'pending': resPending, 'approved': resApproved},
        'Guests': {'pending': guestPending, 'approved': guestApproved}
      };
    } catch (e) {
      debugLog('Error fetching residents vs guests stats: $e');
      return {
        'Residents': {'pending': 0, 'approved': 0},
        'Guests': {'pending': 0, 'approved': 0}
      };
    }
  }

  // Get total population data for line chart
  Future<List<Map<String, dynamic>>> _getPopulationTrendData() async {
    final barangay = _barangay ?? '';
    if (barangay.isEmpty) return [];

    try {
      // Get all users for this barangay
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('barangay', isEqualTo: barangay)
          .get()
          .timeout(const Duration(seconds: 8));

      // Group by type
      int residents = 0, guestResidents = 0, officials = 0;
      for (var doc in snap.docs) {
        final data = doc.data();
        final type = (data['type'] ?? '').toString();
        if (type == 'Resident') residents++;
        else if (type == 'Guest Resident') guestResidents++;
        else if (type == 'Barangay Official') officials++;
      }

      final totalPopulation = residents + guestResidents;

      // Return data points for line chart (simulating daily data for the period)
      return [
        {'day': 'Mon', 'total': (totalPopulation * 0.7).toInt(), 'residents': (residents * 0.7).toInt(), 'guests': (guestResidents * 0.7).toInt()},
        {'day': 'Tue', 'total': (totalPopulation * 0.8).toInt(), 'residents': (residents * 0.8).toInt(), 'guests': (guestResidents * 0.8).toInt()},
        {'day': 'Wed', 'total': (totalPopulation * 0.85).toInt(), 'residents': (residents * 0.85).toInt(), 'guests': (guestResidents * 0.85).toInt()},
        {'day': 'Thu', 'total': (totalPopulation * 0.9).toInt(), 'residents': (residents * 0.9).toInt(), 'guests': (guestResidents * 0.9).toInt()},
        {'day': 'Fri', 'total': (totalPopulation * 0.95).toInt(), 'residents': (residents * 0.95).toInt(), 'guests': (guestResidents * 0.95).toInt()},
        {'day': 'Sat', 'total': totalPopulation, 'residents': residents, 'guests': guestResidents},
      ];
    } catch (e) {
      debugLog('Error fetching population trend data: $e');
      return [];
    }
  }

  Widget _wrap(Widget child) {
    if (widget.embedInCard) {
      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      );
    }
    return child;
  }

  Widget _buildHeader() {
    return Builder(
      builder: (context) {
        final subtitleColor = Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ?? Colors.black54;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bar_chart, color: Color(0xFF228B22)),
                SizedBox(width: 8),
                Text('STATISTICS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_loadingBarangay) {
      return _wrap(const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())));
    }

    if (_barangayError != null || (_barangay ?? '').isEmpty) {
      return _wrap(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const Icon(Icons.error_outline, size: 32, color: Colors.red),
          const SizedBox(height: 8),
          Text(_barangayError ?? 'Barangay not loaded', style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _loadBarangay,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ));
    }

    return _wrap(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 8),
        
        // Resident Status Breakdown Section
        _buildSectionCard(
          context,
          title: 'Resident Status Breakdown',
          icon: Icons.people_outline,
          child:
        StreamBuilder<Map<String, int>>(
            stream: _residentStatsStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const SizedBox(height: 140, child: Center(child: Text('Error loading resident stats')));
              }
              if (!snapshot.hasData) return const SizedBox(height: 140, child: Center(child: Text('Loading...')));

              final stats = snapshot.data!;
              final total = stats.values.fold(0, (a, b) => a + b);
              if (total == 0) return const Text('No residents data available');

              return Column(
                children: [
                  // Chart with proper padding and softened grid/labels
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    child: SizedBox(
                      height: 180,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          groupsSpace: 18,
                          maxY: (stats.values.reduce((a, b) => a > b ? a : b) + 2).toDouble(),
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  final theme = Theme.of(context);
                                  final style = theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                                  );
                                  switch (value.toInt()) {
                                    case 0: return Padding(padding: const EdgeInsets.only(top: 10.0), child: Text('Pending', style: style, textAlign: TextAlign.center));
                                    case 1: return Padding(padding: const EdgeInsets.only(top: 10.0), child: Text('Approved', style: style, textAlign: TextAlign.center));
                                    case 2: return Padding(padding: const EdgeInsets.only(top: 10.0), child: Text('Rejected', style: style, textAlign: TextAlign.center));
                                    default: return const SizedBox.shrink();
                                  }
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 36,
                                getTitlesWidget: (value, meta) {
                                  final theme = Theme.of(context);
                                  return Text(
                                    value.toInt().toString(),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppColors.axisLabel.withValues(alpha: 0.7),
                                    ),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: FlGridData(
                            show: true,
                            horizontalInterval: 1,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: AppColors.gridLine.withValues(alpha: 0.2),
                              strokeWidth: 0.8,
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: [
                            BarChartGroupData(
                              x: 0,
                              barRods: [
                                BarChartRodData(
                                  toY: stats['pending']!.toDouble(),
                                  color: AppColors.pending,
                                  width: 18,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                )
                              ],
                            ),
                            BarChartGroupData(
                              x: 1,
                              barRods: [
                                BarChartRodData(
                                  toY: stats['approved']!.toDouble(),
                                  color: AppColors.approved,
                                  width: 18,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                )
                              ],
                            ),
                            BarChartGroupData(
                              x: 2,
                              barRods: [
                                BarChartRodData(
                                  toY: stats['rejected']!.toDouble(),
                                  color: AppColors.rejected,
                                  width: 18,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                )
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Grouped compact chips/cards below chart
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(child: _buildCompactStatCard('Pending', stats['pending']!, AppColors.pending)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildCompactStatCard('Approved', stats['approved']!, AppColors.approved)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildCompactStatCard('Rejected', stats['rejected']!, AppColors.rejected)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        
        // Residents vs Guest Residents Section
        _buildSectionCard(
          context,
          title: 'Population:\nResidents vs Guest Residents',
          icon: Icons.groups,
          child: StreamBuilder<Map<String, int>>(
            stream: _getPopulationComparisonStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError || !snapshot.hasData) {
                return const SizedBox(height: 250, child: Center(child: Text('Loading data...')));
              }

              final data = snapshot.data!;
              final residentCount = data['residents'] ?? 0;
              final guestCount = data['guests'] ?? 0;
              final maxValue = [residentCount, guestCount].reduce((a, b) => a > b ? a : b);

              return Column(
                children: [
                  // Chart with proper centering and padding
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    child: SizedBox(
                      height: 240,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceEvenly,
                          maxY: (maxValue + 2).toDouble(),
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  final theme = Theme.of(context);
                                  switch (value.toInt()) {
                                    case 0: return Padding(
                                      padding: const EdgeInsets.only(top: 10.0),
                                      child: Text('Residents', textAlign: TextAlign.center, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8))),
                                    );
                                    case 1: return Padding(
                                      padding: const EdgeInsets.only(top: 10.0),
                                      child: Text('Guests', textAlign: TextAlign.center, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8))),
                                    );
                                    default: return const Text('');
                                  }
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 36,
                                getTitlesWidget: (value, meta) {
                                  final theme = Theme.of(context);
                                  return Text(
                                    value.toInt().toString(),
                                    style: theme.textTheme.labelSmall?.copyWith(color: AppColors.axisLabel.withValues(alpha: 0.7)),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: FlGridData(
                            show: true,
                            horizontalInterval: 1,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) => FlLine(color: AppColors.gridLine.withValues(alpha: 0.2), strokeWidth: 0.8),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: [
                            BarChartGroupData(
                              x: 0,
                              barRods: [
                                BarChartRodData(
                                  toY: residentCount.toDouble(),
                                  color: AppColors.approved,
                                  width: 24,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ],
                            ),
                            BarChartGroupData(
                              x: 1,
                              barRods: [
                                BarChartRodData(
                                  toY: guestCount.toDouble(),
                                  color: AppColors.pendingGuest,
                                  width: 24,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Clean legend component with exactly 2 labels
                  _buildCleanLegend(context, [
                    {'label': 'Residents', 'color': AppColors.approved, 'value': residentCount},
                    {'label': 'Guests', 'color': AppColors.pendingGuest, 'value': guestCount},
                  ]),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        
        // Total Population Trend Section
        _buildSectionCard(
          context,
          title: 'Total Population Trend',
          icon: Icons.trending_up,
          child: Column(
            children: [
              // Timeframe selector
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Timeframe:',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Container(
                      width: 170,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _populationTrendPeriod,
                          iconEnabledColor: theme.colorScheme.onSurface,
                          iconDisabledColor: theme.colorScheme.onSurface.withOpacity(0.5),
                          dropdownColor: theme.colorScheme.surfaceContainerHighest,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                          items: ['Daily', 'Weekly', 'Monthly', 'Yearly']
                              .map((e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (val) => setState(() => _populationTrendPeriod = val ?? 'Weekly'),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              StreamBuilder<List<Map<String, dynamic>>>(
                key: ValueKey(_populationTrendPeriod),
                stream: _getPopulationTrendDataStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return const SizedBox(height: 220, child: Center(child: Text('Loading trend data...')));
                  }

                  final data = snapshot.data!;
                  final maxValue = data.map((d) => d['total'] as int).reduce((a, b) => a > b ? a : b);
                  final currentTotal = data.last['total'] as int;
                  final spots = List.generate(
                    data.length,
                    (i) => FlSpot(i.toDouble(), (data[i]['total'] as int).toDouble()),
                  );
                  final theme = Theme.of(context);

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        child: SizedBox(
                          height: 200,
                          child: LineChart(
                            LineChartData(
                              maxY: (maxValue + 5).toDouble(),
                              minY: 0,
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 32,
                                    getTitlesWidget: (value, meta) {
                                      final theme = Theme.of(context);
                                      if (value.toInt() < data.length) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Text(
                                            data[value.toInt()]['day'] as String,
                                            style: theme.textTheme.labelMedium?.copyWith(
                                              color: theme.colorScheme.onSurface.withOpacity(0.85),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        );
                                      }
                                      return const Text('');
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    getTitlesWidget: (value, meta) {
                                      final theme = Theme.of(context);
                                      return Text(
                                        value.toInt().toString(),
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: 1,
                                getDrawingHorizontalLine: (value) => FlLine(
                                  color: theme.colorScheme.onSurface.withOpacity(0.12),
                                  strokeWidth: 0.8,
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: spots,
                                  isCurved: true,
                                  barWidth: 2,
                                  color: AppColors.approved,
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter: (spot, percent, barData, index) {
                                      return FlDotCirclePainter(
                                        radius: 3,
                                        color: Colors.white,
                                        strokeWidth: 2,
                                        strokeColor: AppColors.approved,
                                      );
                                    },
                                  ),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: AppColors.approved.withValues(alpha: 0.12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Current Population: ',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface.withOpacity(0.85),
                              ),
                            ),
                            Text(
                              '$currentTotal',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.approved,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Complaints Overview Section
        _buildSectionCard(
          context,
          title: 'Complaints Overview',
          icon: Icons.report_problem_outlined,
          child:
        StreamBuilder<Map<String, int>>(
            stream: _complaintStatsStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const SizedBox(height: 120, child: Center(child: Text('Error loading complaint stats')));
              }
              if (!snapshot.hasData) return const SizedBox(height: 120, child: Center(child: Text('Loading...')));

              final stats = snapshot.data!;
              final total = stats.values.fold(0, (a, b) => a + b);
              if (total == 0) return const Text('No complaints data available');

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: SizedBox(
                      height: 140,
                      child: PieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(
                              value: stats['pending']!.toDouble(),
                              title: '',
                              color: AppColors.pending,
                              radius: 50,
                              borderSide: BorderSide.none,
                            ),
                            PieChartSectionData(
                              value: stats['resolved']!.toDouble(),
                              title: '',
                              color: AppColors.approved,
                              radius: 50,
                              borderSide: BorderSide.none,
                            ),
                            PieChartSectionData(
                              value: stats['invalid']!.toDouble(),
                              title: '',
                              color: AppColors.rejected,
                              radius: 50,
                              borderSide: BorderSide.none,
                            ),
                          ],
                          sectionsSpace: 3,
                          centerSpaceRadius: 32,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Row(
                      children: [
                        Expanded(child: _buildCompactStatCard('Pending', stats['pending']!, AppColors.pending)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildCompactStatCard('Resolved', stats['resolved']!, AppColors.approved)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildCompactStatCard('Invalid', stats['invalid']!, AppColors.rejected)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ));
  }

  // Helper method to build section cards with consistent styling
  Widget _buildSectionCard(BuildContext context, {required String title, required IconData icon, required Widget child}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  // Helper method for stat summaries
  Widget _buildStatSummary(BuildContext context, String label, int count, Color color) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count.toString(),
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  // Helper method for data cards with multiple values
  Widget _buildDataCard(BuildContext context, String title, List<Map<String, dynamic>> items) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: item['color'] as Color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item['label'] as String,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    '${item['value']}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // Helper method for clean legend component
  Widget _buildCleanLegend(BuildContext context, List<Map<String, dynamic>> items) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: AppColors.legendBgLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (index > 0) const SizedBox(width: 24),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: item['color'] as Color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${item['label'] as String}${item.containsKey('value') ? ' (${item['value']})' : ''}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withOpacity(0.9),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSimpleStatText(String label, int count, Color color) {
    return Builder(
      builder: (context) {
        final labelColor = Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.black54;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              count.toString(),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: labelColor),
            ),
          ],
        );
      }
    );
  }

  Widget _buildCompactStatCard(String label, int count, Color color) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Builder(
          builder: (context) {
            final labelColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(count.toString(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: labelColor)),
              ],
            );
          }
        ),
      ),
    );
  }

}

/// Manage Document Types Page - Officials can add/edit/delete available document types

