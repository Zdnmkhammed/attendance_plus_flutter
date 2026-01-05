import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AttendanceListScreen extends StatelessWidget {
  final String sessionId;
  final String sessionCode;

  const AttendanceListScreen({
    super.key,
    required this.sessionId,
    required this.sessionCode,
  });

  /// Разбиваем "Фамилия Имя" -> (фамилия, имя)
  (String last, String first) _splitName(String full) {
    final parts = full.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return (parts[0], '');
    final last = parts.first; // фамилия
    final first = parts.sublist(1).join(' ');
    return (last, first);
  }

  @override
  Widget build(BuildContext context) {
    // Реальное время: слушаем коллекцию attendance для этой сессии
    final query = FirebaseFirestore.instance
        .collection('attendance')
        .where('sessionId', isEqualTo: sessionId);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        title: Text('Attendance – $sessionCode'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No attendance yet',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          // Преобразуем документы в удобный вид
          final records = docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            final name = (data['studentName'] ?? '') as String;
            final group = (data['groupName'] ?? '') as String;

            // по твоей логике: present = true если студент ДЕЙСТВИТЕЛЬНО пришёл;
            // предполагаем, что у тебя есть поле 'present' (bool), иначе ставь всегда true
            final present = (data['present'] ?? true) as bool;

            return _AttendanceRecord(
              name: name,
              group: group,
              present: present,
            );
          }).toList();

          // Сортировка: по группе, потом по фамилии, потом по имени
          records.sort((a, b) {
            final byGroup = a.group.compareTo(b.group);
            if (byGroup != 0) return byGroup;

            final (alast, afirst) = _splitName(a.name);
            final (blast, bfirst) = _splitName(b.name);

            final lastCmp = alast.toLowerCase().compareTo(blast.toLowerCase());
            if (lastCmp != 0) return lastCmp;

            return afirst.toLowerCase().compareTo(bfirst.toLowerCase());
          });

          // Группируем по группе
          final Map<String, List<_AttendanceRecord>> byGroup = {};
          for (final r in records) {
            byGroup.putIfAbsent(r.group, () => []).add(r);
          }
          final sortedGroups = byGroup.keys.toList()..sort();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: sortedGroups.map((groupName) {
              final students = byGroup[groupName]!;
              final presentCount =
                  students.where((s) => s.present).length;
              final total = students.length;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                color: const Color(0xFF252525),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Заголовок группы
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Group $groupName',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$presentCount / $total present',
                            style:
                                const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Список студентов с нумерацией
                      ...students.asMap().entries.map((entry) {
                        final index = entry.key;
                        final s = entry.value;

                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              // Номер
                              Text(
                                '${index + 1}.',
                                style: const TextStyle(
                                    color: Colors.white70),
                              ),
                              const SizedBox(width: 8),
                              // Фамилия Имя
                              Expanded(
                                child: Text(
                                  s.name,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              // Статус
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: s.present
                                      ? Colors.green
                                      : Colors.redAccent,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: Text(
                                  s.present ? 'Present' : 'Absent',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _AttendanceRecord {
  final String name;
  final String group;
  final bool present;

  _AttendanceRecord({
    required this.name,
    required this.group,
    required this.present,
  });
}
