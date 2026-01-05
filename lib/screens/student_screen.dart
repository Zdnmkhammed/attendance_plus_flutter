import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/firestore_service.dart';

class StudentScreen extends StatefulWidget {
  const StudentScreen({super.key});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  final TextEditingController codeController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController groupController = TextEditingController();

  bool isLoading = false;
  String? resultMessage;
  Color? resultColor;

  @override
  void dispose() {
    codeController.dispose();
    nameController.dispose();
    groupController.dispose();
    super.dispose();
  }

  Future<bool> _ensureLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  Future<void> checkAttendance() async {
    final code = codeController.text.trim();
    final name = nameController.text.trim();
    final group = groupController.text.trim();

    if (code.length != 6) {
      setState(() {
        resultMessage = 'Enter valid 6-digit code';
        resultColor = Colors.orange;
      });
      return;
    }
    if (name.isEmpty || group.isEmpty) {
      setState(() {
        resultMessage = 'Enter your name and group';
        resultColor = Colors.orange;
      });
      return;
    }

    setState(() {
      isLoading = true;
      resultMessage = null;
    });

    try {
      // 1) Проверяем локацию
      final hasPermission = await _ensureLocationPermission();
      if (!hasPermission) {
        if (!mounted) return;
        setState(() {
          isLoading = false;
          resultMessage = 'Location permission required';
          resultColor = Colors.orange;
        });
        return;
      }

      // 2) Ищем сессию по коду
      final sessionSnap =
          await FirestoreService.instance.getActiveSessionByCode(code);

      if (sessionSnap == null || !sessionSnap.exists) {
        if (!mounted) return;
        setState(() {
          isLoading = false;
          resultMessage = 'Session not found or expired';
          resultColor = Colors.red;
        });
        return;
      }

      final data = sessionSnap.data()!;
      final double teacherLat = (data['teacherLat'] as num).toDouble();
      final double teacherLon = (data['teacherLon'] as num).toDouble();
      final int radiusMeters = (data['radiusMeters'] as num).toInt();

      // 3) Берём позицию студента
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final distance = Geolocator.distanceBetween(
        teacherLat,
        teacherLon,
        pos.latitude,
        pos.longitude,
      );

      final bool isPresent = distance <= radiusMeters;

      // 4) Пишем в коллекцию attendance
      await FirestoreService.instance.submitAttendance(
        sessionId: sessionSnap.id,
        sessionCode: code,
        studentName: name,
        groupName: group,
        studentLat: pos.latitude,
        studentLon: pos.longitude,
        distanceMeters: distance,
        present: isPresent,
      );

      if (!mounted) return;
      setState(() {
        isLoading = false;
        if (isPresent) {
          resultMessage = '✅ You are marked present!';
          resultColor = Colors.green;
        } else {
          resultMessage =
              '❌ You are out of range (${distance.toStringAsFixed(1)} m)';
          resultColor = Colors.red;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        resultMessage = '⚠️ Error: $e';
        resultColor = Colors.orange;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        title: const Text('Student Mode'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Mark Attendance',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Enter your 6-digit session code',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),

                // CODE
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Colors.white, fontSize: 20),
                  decoration: InputDecoration(
                    hintText: '000000',
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.black45,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // NAME
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Surname Name',
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.black45,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // GROUP
                TextField(
                  controller: groupController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Group (e.g. CS-2440)',
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.black45,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                ElevatedButton(
                  onPressed: isLoading ? null : checkAttendance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 50, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    elevation: 10,
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : const Text(
                          'Submit Attendance',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 20),
                if (resultMessage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: resultColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      resultMessage!,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
