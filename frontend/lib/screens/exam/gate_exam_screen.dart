import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/exam_provider.dart';

class GateExamScreen extends StatelessWidget {
  const GateExamScreen({super.key});

  String _formatTimer(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final exam = context.watch<ExamProvider>();
    final auth = context.read<AuthProvider>();

    if (exam.questions.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final q = exam.currentQuestion;
    final isLocked = exam.isQuestionLocked(q.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(exam.testTitle),
        automaticallyImplyLeading: false,
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  "Time Left: ${_formatTimer(exam.remainingSeconds)}",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
            onPressed: () async {
              final res = await exam.submitExam(auth.token!);
              if (res != null && context.mounted) {
                _showResultDialog(context, res);
              }
            },
            child: const Text("SUBMIT TEST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          // Left: Question Statement & Interactive Options
          Expanded(
            flex: 7,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Question ${exam.currentQuestionIndex + 1} (${q.type})",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "Marks: +${q.marks} | -${q.negativeMarks}",
                        style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  if (isLocked)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_clock, color: Colors.orange),
                          SizedBox(width: 12),
                          Text(
                            "Question is temporarily locked for 5 minutes after viewing solution.",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    // Question text
                    SelectableText(
                      q.statement,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    // Options Render
                    if (q.type == 'MCQ') ...[
                      for (var opt in q.options)
                        RadioListTile<String>(
                          title: Text("${opt['identifier']}) ${opt['text']}"),
                          value: opt['identifier'],
                          groupValue: exam.userAnswers[q.id],
                          onChanged: (val) {
                            if (val != null) exam.setAnswer(val);
                          },
                        ),
                    ] else if (q.type == 'NAT') ...[
                      SizedBox(
                        width: 250,
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: "Enter Numerical Answer",
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (val) => exam.setAnswer(val),
                          controller: TextEditingController(text: exam.userAnswers[q.id] ?? ""),
                        ),
                      ),
                    ] else if (q.type == 'MSQ') ...[
                      for (var opt in q.options)
                        CheckboxListTile(
                          title: Text("${opt['identifier']}) ${opt['text']}"),
                          value: (exam.userAnswers[q.id] ?? "").split(',').contains(opt['identifier']),
                          onChanged: (bool? checked) {
                            List<String> cur = (exam.userAnswers[q.id] ?? "")
                                .split(',')
                                .where((e) => e.isNotEmpty)
                                .toList();
                            if (checked == true) {
                              cur.add(opt['identifier']);
                            } else {
                              cur.remove(opt['identifier']);
                            }
                            exam.setAnswer(cur.join(','));
                          },
                        ),
                    ],
                  ],
                  const Spacer(),
                  // Bottom controls
                  Row(
                    children: [
                      // TUKKA Button (Violet)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.tukkaViolet,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        ),
                        icon: const Icon(Icons.casino, color: Colors.white),
                        label: Text(
                          (exam.isTukkaMap[q.id] ?? false) ? "TUKKA (GUESSED)" : "TUKKA (GUESS)",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        onPressed: isLocked ? null : () => exam.toggleTukka(),
                      ),
                      const SizedBox(width: 12),
                      // Mark for Review
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                        onPressed: isLocked ? null : () => exam.toggleMarkForReview(),
                        child: Text(
                          (exam.isMarkedReviewMap[q.id] ?? false) ? "UNMARK REVIEW" : "MARK FOR REVIEW",
                        ),
                      ),
                      const SizedBox(width: 12),
                      // See Solution
                      OutlinedButton.icon(
                        icon: const Icon(Icons.lightbulb_outline),
                        label: const Text("SEE SOLUTION"),
                        onPressed: () async {
                          final sol = await exam.viewSolution(auth.token!);
                          if (sol != null && context.mounted) {
                            _showSolutionModal(context, sol);
                          }
                        },
                      ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed: () => exam.clearResponse(),
                        child: const Text("CLEAR RESPONSE"),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                        onPressed: () => exam.saveAndNext(auth.token!),
                        child: const Text("SAVE & NEXT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
          // Right: Question Palette
          Container(
            width: 320,
            color: const Color(0xFFF1F5F9),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Question Palette", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildLegend(),
                const Divider(),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const dynamicGridDelegate(),
                    itemCount: exam.questions.length,
                    itemBuilder: (ctx, i) {
                      final qItem = exam.questions[i];
                      final isAnswered = exam.userAnswers[qItem.id] != null && exam.userAnswers[qItem.id]!.isNotEmpty;
                      final isMarked = exam.isMarkedReviewMap[qItem.id] ?? false;
                      final isVisited = exam.isVisitedMap[qItem.id] ?? false;

                      Color bg = AppTheme.notVisitedGrey;
                      Color fg = Colors.black87;

                      if (isAnswered && isMarked) {
                        bg = Colors.deepPurple;
                        fg = Colors.white;
                      } else if (isMarked) {
                        bg = AppTheme.markedReviewPurple;
                        fg = Colors.white;
                      } else if (isAnswered) {
                        bg = AppTheme.answeredGreen;
                        fg = Colors.white;
                      } else if (isVisited) {
                        bg = AppTheme.notAnsweredRed;
                        fg = Colors.white;
                      }

                      return InkWell(
                        onTap: () => exam.selectQuestion(i),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: exam.currentQuestionIndex == i ? Colors.black : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            "${i + 1}",
                            style: TextStyle(color: fg, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Column(
      children: [
        _legendRow(AppTheme.answeredGreen, "Answered"),
        _legendRow(AppTheme.notAnsweredRed, "Not Answered"),
        _legendRow(AppTheme.markedReviewPurple, "Marked for Review"),
        _legendRow(AppTheme.notVisitedGrey, "Not Visited"),
      ],
    );
  }

  Widget _legendRow(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  void _showSolutionModal(BuildContext context, Map<String, dynamic> sol) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Solution & Detailed Explanation"),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Correct Answer: ${sol['correct_answer']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
              const SizedBox(height: 12),
              Text("Explanation: ${sol['explanation'] ?? 'No explanation attached.'}"),
              const SizedBox(height: 16),
              if (sol['youtube_url'] != null)
                ElevatedButton.icon(
                  icon: const Icon(Icons.video_library, color: Colors.white),
                  label: const Text("Watch YouTube Explanation", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () {
                    launchUrl(Uri.parse(sol['youtube_url']));
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
        ],
      ),
    );
  }

  void _showResultDialog(BuildContext context, Map<String, dynamic> res) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Test Submitted Successfully!"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Total Marks: ${res['score']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
            Text("Accuracy: ${res['accuracy']}%"),
            Text("Total Answered: ${res['total_answered']}"),
            Text("Correct: ${res['correct_count']}"),
            const Divider(),
            Text("TUKKA (Guesses): ${res['tukka_total']}"),
            Text("TUKKA Accuracy: ${res['tukka_accuracy']}%", style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Back to student dash
            },
            child: const Text("Return to Dashboard"),
          )
        ],
      ),
    );
  }
}

class dynamicGridDelegate extends SliverGridDelegate {
  const dynamicGridDelegate();
  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    return SliverGridRegularTileLayout(
      crossAxisCount: 5,
      mainAxisStride: 52,
      crossAxisStride: 52,
      childMainAxisExtent: 44,
      childCrossAxisExtent: 44,
      reverseCrossAxis: false,
    );
  }
  @override
  bool shouldRelayout(covariant SliverGridDelegate oldDelegate) => false;
}
