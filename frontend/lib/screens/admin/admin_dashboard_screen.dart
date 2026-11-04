import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<dynamic> students = [];
  List<dynamic> liveExams = [];
  List<dynamic> analytics = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchAdminData();
  }

  void _fetchAdminData() async {
    final token = context.read<AuthProvider>().token;
    try {
      final resStud = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/admin/students'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final resLive = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/admin/live-monitoring'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final resComp = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/admin/comparative-analytics'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (resStud.statusCode == 200 && resLive.statusCode == 200 && resComp.statusCode == 200) {
        setState(() {
          students = jsonDecode(resStud.body);
          liveExams = jsonDecode(resLive.body);
          analytics = jsonDecode(resComp.body);
          loading = false;
        });
      }
    } catch (e) {
      debugPrint("Admin fetch error: $e");
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text("GATE Central Administrator Command Center"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => loading = true);
              _fetchAdminData();
            },
          ),
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
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  // Live Monitoring
                  Expanded(
                    flex: 1,
                    child: Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Live Active Tests (Cross-Computer)",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Expanded(
                              child: liveExams.isEmpty
                                  ? const Center(child: Text("No live examinations in progress"))
                                  : ListView.builder(
                                      itemCount: liveExams.length,
                                      itemBuilder: (ctx, i) {
                                        final item = liveExams[i];
                                        return Card(
                                          color: Colors.blue.shade50,
                                          child: ListTile(
                                            title: Text("${item['student_name']} - ${item['test_title']}"),
                                            subtitle: Text("Seconds Left: ${item['time_remaining']}\nRecent Events: ${item['recent_events']}"),
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
                  const SizedBox(width: 16),
                  // Comparative Analytics
                  Expanded(
                    flex: 2,
                    child: Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Comparative Performance & Consistency Analytics",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Expanded(
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text("Student Name")),
                                  DataColumn(label: Text("Tests Completed")),
                                  DataColumn(label: Text("Avg Score")),
                                  DataColumn(label: Text("Accuracy")),
                                  DataColumn(label: Text("Total Tukka")),
                                ],
                                rows: analytics.map((a) {
                                  return DataRow(cells: [
                                    DataCell(Text(a['student_name'])),
                                    DataCell(Text(a['completed_tests'].toString())),
                                    DataCell(Text(a['average_score'].toString())),
                                    DataCell(Text("${a['average_accuracy']}%")),
                                    DataCell(Text(a['total_guesses'].toString())),
                                  ]);
                                }).toList(),
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
