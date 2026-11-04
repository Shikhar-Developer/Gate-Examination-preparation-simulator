import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/exam_provider.dart';
import '../exam/gate_exam_screen.dart';
import '../auth/login_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  List<dynamic> tests = [];
  List<dynamic> history = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  void _fetchDashboardData() async {
    final token = context.read<AuthProvider>().token;
    try {
      final resTests = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/exam/tests'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final resHistory = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/analytics/my-history'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (resTests.statusCode == 200 && resHistory.statusCode == 200) {
        setState(() {
          tests = jsonDecode(resTests.body);
          history = jsonDecode(resHistory.body);
          loading = false;
        });
      }
    } catch (e) {
      debugPrint("Fetch error: $e");
      setState(() => loading = false);
    }
  }

  void _launchTest(int testId) async {
    final auth = context.read<AuthProvider>();
    final exam = context.read<ExamProvider>();
    final ok = await exam.startExam(testId, auth.token!);
    if (ok && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GateExamScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text("GATE Portal - ${auth.username}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              auth.logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Available Tests
                  Expanded(
                    flex: 3,
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Assigned Chapter Tests",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            Expanded(
                              child: ListView.separated(
                                itemCount: tests.length,
                                separatorBuilder: (_, __) => const Divider(),
                                itemBuilder: (ctx, i) {
                                  final t = tests[i];
                                  return ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: Color(0xFF1E3A8A),
                                      child: Icon(Icons.assignment, color: Colors.white),
                                    ),
                                    title: Text(t['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text("${t['duration_minutes']} Mins | ${t['question_count']} Questions | Total Marks: ${t['total_marks']}"),
                                    trailing: ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                                      onPressed: () => _launchTest(t['id']),
                                      child: const Text("Start Test", style: TextStyle(color: Colors.white)),
                                    ),
                                  );
                                },
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Performance Records
                  Expanded(
                    flex: 2,
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Recent Attempts & Tukka Accuracy",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            Expanded(
                              child: history.isEmpty
                                  ? const Center(child: Text("No completed tests yet."))
                                  : ListView.builder(
                                      itemCount: history.length,
                                      itemBuilder: (ctx, i) {
                                        final h = history[i];
                                        return Card(
                                          margin: const EdgeInsets.symmetric(vertical: 6),
                                          color: const Color(0xFFF8FAFC),
                                          child: ListTile(
                                            title: Text(h['test_title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                            subtitle: Text("Score: ${h['score']} | Accuracy: ${h['accuracy']}%\nTukka Guesses: ${h['tukka_count']} (Accuracy: ${h['tukka_accuracy']}%)"),
                                          ),
                                        );
                                      },
                                    ),
                            )
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
    );
  }
}
