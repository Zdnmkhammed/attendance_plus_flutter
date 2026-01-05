import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../screens/attendance_list_screen.dart';
import '../services/firestore_service.dart';

class TeacherScreen extends StatefulWidget {
  const TeacherScreen({super.key});

  @override
  State<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends State<TeacherScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  static const int totalSeconds = 120; // 2 minutes

  String? sessionCode;
  String? sessionId; // id документа в Firestore
  bool isRunning = false;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: totalSeconds),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (!mounted) return;
          setState(() {
            isRunning = false;
            sessionCode = null;
            sessionId = null;
          });
          _ctrl.reset();
        }
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> startSession() async {
    if (isSaving) return;

    try {
      setState(() {
        isSaving = true;
      });

      // 1) Генерируем код
      final rnd = Random();
      final code = (100000 + rnd.nextInt(900000)).toString();

      // 2) Получаем геолокацию учителя
      final hasPermission = await _ensureLocationPermission();
      if (!hasPermission) {
        if (!mounted) return;
        setState(() {
          isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission required for session'),
          ),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 3) Сохраняем сессию в Firestore
      final id = await FirestoreService.instance.createSession(
        code: code,
        teacherLat: pos.latitude,
        teacherLon: pos.longitude,
        radiusMeters: 30,
      );

      if (!mounted) return;

      // 4) Обновляем UI и запускаем таймер
      setState(() {
        sessionCode = code;
        sessionId = id;
        isRunning = true;
        isSaving = false;
      });
      _ctrl.forward(from: 0.0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting session: $e')),
      );
    }
  }

  Future<bool> _ensureLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

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

  String get remainingTimeText {
    final remaining =
        totalSeconds - (_ctrl.value * totalSeconds).round(); // seconds left
    final m = (remaining ~/ 60).toString();
    final s = (remaining % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  Color get currentColor {
    final remainingFraction = 1.0 - _ctrl.value;
    return Color.lerp(Colors.red, Colors.green, remainingFraction)!
        .withValues(alpha: 1.0);
  }

  double get progress => _ctrl.value; // 0.0 -> 1.0

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        title: const Text('Teacher Mode'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 28),

              /// === MAIN CIRCLE ===
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  return GestureDetector(
                    onTap: (isRunning || isSaving) ? null : startSession,
                    child: SizedBox(
                      width: 280,
                      height: 280,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          /// Circle background
                          Container(
                            width: 280,
                            height: 280,
                            decoration: BoxDecoration(
                              color: const Color(0xFF121212),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      currentColor.withValues(alpha: 0.18),
                                  blurRadius: 40,
                                  spreadRadius: 6,
                                ),
                              ],
                            ),
                          ),

                          /// Progress arc
                          CustomPaint(
                            size: const Size(280, 280),
                            painter: _ArcPainter(
                              progress: progress,
                              color: currentColor,
                              strokeWidth: 14,
                            ),
                          ),

                          /// START button or timer
                          if (isSaving)
                            const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          else if (isRunning)
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  remainingTimeText,
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'remaining',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              'START',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: Colors.white
                                    .withValues(alpha: 0.95),
                                letterSpacing: 2,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 22),

              /// Session code display
              if (sessionCode != null)
                Column(
                  children: [
                    const Text(
                      'Session Code',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      sessionCode!,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: currentColor,
                        shadows: [
                          Shadow(
                            blurRadius: 12,
                            color: currentColor
                                .withValues(alpha: 0.6),
                            offset: const Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 18),

              /// Button
              ElevatedButton(
                onPressed: () {
                  if (sessionId == null || sessionCode == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No active session'),
                      ),
                    );
                    return;
                  }

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AttendanceListScreen(
                        sessionId: sessionId!,
                        sessionCode: sessionCode!,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 36, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 6,
                ),
                child: const Text(
                  'View Attendance',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter draws the circular arc (progress).
class _ArcPainter extends CustomPainter {
  final double progress; // 0.0 - 1.0
  final Color color;
  final double strokeWidth;

  _ArcPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width / 2) - strokeWidth;
    final rect = Rect.fromCircle(center: center, radius: radius);

    /// Background arc
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, bgPaint);

    /// FIXED SweepGradient (for Web/DartPad)
    final double gradientSweep =
        math.pi * 2 * math.max(progress, 0.00001);

    final fgPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + gradientSweep,
        colors: [
          color,
          color.withValues(alpha: 0.4),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
        rect, -math.pi / 2, math.pi * 2 * progress, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) {
    return old.progress != progress || old.color != color;
  }
}
