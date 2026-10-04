import 'package:flutter/material.dart';
import '../services/deterministic_routing_service.dart';

class DeterministicRouteCard extends StatelessWidget {
  final StrictRouteJson route;
  final VoidCallback? onOpenMap;
  final VoidCallback? onOpenCircuitStudio;

  const DeterministicRouteCard({
    super.key,
    required this.route,
    this.onOpenMap,
    this.onOpenCircuitStudio,
  });

  Color _getCategoryColor(String category) {
    final catLower = category.toLowerCase();
    if (catLower.contains('bonedi')) {
      return const Color(0xFFFFB300); // Gold
    } else if (catLower.contains('centenary')) {
      return const Color(0xFF00E5FF); // Cyan
    }
    return const Color(0xFFE62E2D); // Red (Mega Theme)
  }

  IconData _getCategoryIcon(String category) {
    final catLower = category.toLowerCase();
    if (catLower.contains('bonedi')) {
      return Icons.account_balance;
    } else if (catLower.contains('centenary')) {
      return Icons.history_edu;
    }
    return Icons.local_fire_department;
  }

  @override
  Widget build(BuildContext context) {
    const kMarigoldAmber = Color(0xFFFFB300);
    const kSindoorRed = Color(0xFFE62E2D);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141426),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: kMarigoldAmber.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kMarigoldAmber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kMarigoldAmber.withOpacity(0.6)),
                ),
                child: const Icon(Icons.verified_outlined,
                    color: kMarigoldAmber, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VERIFIED METRO CIRCUIT',
                      style: TextStyle(
                        color: kMarigoldAmber,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Origin: ${route.origin} • ${route.stops.length} Stops',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withOpacity(0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_walk,
                        color: Color(0xFF00E5FF), size: 12),
                    SizedBox(width: 4),
                    Text(
                      '≤ 900m',
                      style: TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),

          // Interchange Banner if present
          if (route.interchange != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00E5FF).withOpacity(0.15),
                    const Color(0xFF1E293B),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00E5FF).withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.swap_horiz,
                      color: Color(0xFF00E5FF), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'METRO INTERCHANGE AT ${route.interchange!.station.toUpperCase()}',
                          style: const TextStyle(
                            color: Color(0xFF00E5FF),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${route.interchange!.fromLine} ➔ ${route.interchange!.toLine}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Stop List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: route.stops.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final stop = route.stops[index];
              final catColor = _getCategoryColor(stop.category);
              final catIcon = _getCategoryIcon(stop.category);

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B2F),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: catColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Stop Number Circle
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: catColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: catColor, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: catColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  stop.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Category Pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: catColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: catColor.withOpacity(0.5),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(catIcon, color: catColor, size: 10),
                                    const SizedBox(width: 3),
                                    Text(
                                      stop.category,
                                      style: TextStyle(
                                        color: catColor,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.directions_subway,
                                  color: Colors.cyanAccent, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '${stop.nearestMetro} (${stop.metroLine})',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.directions_walk,
                                  color: kMarigoldAmber, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '${stop.walkingDistMeters}m walk',
                                style: const TextStyle(
                                  color: kMarigoldAmber,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
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
            },
          ),

          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              if (onOpenCircuitStudio != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kMarigoldAmber,
                      side: BorderSide(
                          color: kMarigoldAmber.withOpacity(0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.alt_route, size: 16),
                    label: const Text(
                      'Circuit Studio',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: onOpenCircuitStudio,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (onOpenMap != null) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kSindoorRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.navigation, size: 16),
                    label: const Text(
                      'Open Route Map',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: onOpenMap,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
