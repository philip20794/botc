import 'package:blood_on_the_clocktower/models/statistics_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads only ready-to-display aggregates, never the public game collection.
abstract interface class StatisticsRepository {
  Future<StatisticsTotals?> loadOverview();
  Future<List<StatisticsRole>> loadRoles();
  Future<List<StatisticsScript>> loadScripts();
}

class CloudStatisticsRepository implements StatisticsRepository {
  final FirebaseFirestore _firestore;

  CloudStatisticsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<StatisticsTotals?> loadOverview() async {
    final document = await _firestore.doc('statistics/global').get();
    final data = document.data();
    if (data == null) return null;
    return StatisticsTotals.fromMap(data);
  }

  @override
  Future<List<StatisticsRole>> loadRoles() async {
    final snapshot = await _firestore.doc('statistics/roles').get();
    final data = snapshot.data();
    final byRole = data?['byRole'];
    if (byRole is! Map) return [];
    return [
      for (final entry in byRole.entries)
        if (entry.key is String && entry.value is Map)
          StatisticsRole.fromMap(
            entry.key as String,
            Map<String, dynamic>.from(entry.value as Map),
          ),
    ];
  }

  @override
  Future<List<StatisticsScript>> loadScripts() async {
    // Bounded query: even a large number of community scripts must not
    // produce unlimited Firestore reads on a mobile device.
    final snapshot = await _firestore
        .collection('statistics_scripts')
        .orderBy('games', descending: true)
        .limit(50)
        .get();
    return [
      for (final document in snapshot.docs)
        StatisticsScript.fromMap(document.id, document.data()),
    ];
  }
}
