import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Создаёт сессию учителя и возвращает ID документа
  Future<String> createSession({
    required String code,
    required double teacherLat,
    required double teacherLon,
    int radiusMeters = 30,
    Duration ttl = const Duration(minutes: 2),
  }) async {
    final now = DateTime.now();
    final expiresAt = now.add(ttl);

    final docRef = await _db.collection('sessions').add({
      'code': code,
      'teacherLat': teacherLat,
      'teacherLon': teacherLon,
      'radiusMeters': radiusMeters,
      'createdAt': now,
      'expiresAt': expiresAt,
    });

    return docRef.id;
  }

  /// Находит сессию по коду (если нет или истекла — вернёт null)
  Future<DocumentSnapshot<Map<String, dynamic>>?> getActiveSessionByCode(
    String code,
  ) async {
    final now = DateTime.now();

    final query = await _db
        .collection('sessions')
        .where('code', isEqualTo: code)
        .where('expiresAt', isGreaterThan: now)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return query.docs.first;
  }

  /// Записывает посещаемость студента
  Future<void> submitAttendance({
    required String sessionId,
    required String sessionCode,
    required String studentName,
    required String groupName,
    required double studentLat,
    required double studentLon,
    required double distanceMeters,
    required bool present,
  }) async {
    await _db.collection('attendance').add({
      'sessionId': sessionId,
      'sessionCode': sessionCode,
      'studentName': studentName,
      'groupName': groupName,
      'studentLat': studentLat,
      'studentLon': studentLon,
      'distanceMeters': distanceMeters,
      'present': present,
      'createdAt': DateTime.now(),
    });
  }
}
