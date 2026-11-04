import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';

class ExamQuestion {
  final int id;
  final int order;
  final String statement;
  final String type;
  final double marks;
  final double negativeMarks;
  final List<dynamic> options;
  final int? examYear;

  ExamQuestion({
    required this.id,
    required this.order,
    required this.statement,
    required this.type,
    required this.marks,
    required this.negativeMarks,
    required this.options,
    this.examYear,
  });

  factory ExamQuestion.fromJson(Map<String, dynamic> json) {
    return ExamQuestion(
      id: json['id'],
      order: json['order'],
      statement: json['statement'],
      type: json['type'],
      marks: (json['marks'] as num).toDouble(),
      negativeMarks: (json['negative_marks'] as num).toDouble(),
      options: json['options'] ?? [],
      examYear: json['exam_year'],
    );
  }
}

class ExamProvider extends ChangeNotifier {
  int? attemptId;
  String testTitle = "";
  List<ExamQuestion> questions = [];
  int currentQuestionIndex = 0;
  int remainingSeconds = 0;
  Timer? _examTimer;

  // Question states & answers
  Map<int, String?> userAnswers = {};
  Map<int, bool> isTukkaMap = {};
  Map<int, bool> isMarkedReviewMap = {};
  Map<int, bool> isVisitedMap = {};

  // Solution View Locks: question_id -> unlock time
  Map<int, DateTime> solutionLockedUntil = {};

  ExamQuestion get currentQuestion => questions[currentQuestionIndex];

  Future<bool> startExam(int testId, String token) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/exam/start/$testId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        attemptId = data['attempt_id'];
        testTitle = data['test_title'];
        remainingSeconds = data['server_time_remaining'];
        
        questions = (data['questions'] as List)
            .map((q) => ExamQuestion.fromJson(q))
            .toList();

        // Restore responses
        userAnswers.clear();
        isTukkaMap.clear();
        isMarkedReviewMap.clear();
        isVisitedMap.clear();

        Map<String, dynamic> saved = data['saved_responses'] ?? {};
        saved.forEach((key, val) {
          int qId = int.parse(key);
          userAnswers[qId] = val['selected_answer'];
          isTukkaMap[qId] = val['is_tukka'] ?? false;
          isMarkedReviewMap[qId] = val['is_marked_for_review'] ?? false;
          if (val['is_answered'] == true) isVisitedMap[qId] = true;
        });

        if (questions.isNotEmpty) {
          isVisitedMap[questions[0].id] = true;
        }

        _startTimer(token);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("Error starting exam: $e");
    }
    return false;
  }

  void _startTimer(String token) {
    _examTimer?.cancel();
    _examTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        remainingSeconds--;
        notifyListeners();
      } else {
        timer.cancel();
        submitExam(token);
      }
    });
  }

  void selectQuestion(int index) {
    currentQuestionIndex = index;
    isVisitedMap[currentQuestion.id] = true;
    notifyListeners();
  }

  void setAnswer(String answer) {
    userAnswers[currentQuestion.id] = answer;
    notifyListeners();
  }

  void toggleTukka() {
    int qId = currentQuestion.id;
    isTukkaMap[qId] = !(isTukkaMap[qId] ?? false);
    notifyListeners();
  }

  void toggleMarkForReview() {
    int qId = currentQuestion.id;
    isMarkedReviewMap[qId] = !(isMarkedReviewMap[qId] ?? false);
    notifyListeners();
  }

  void clearResponse() {
    int qId = currentQuestion.id;
    userAnswers[qId] = null;
    isTukkaMap[qId] = false;
    notifyListeners();
  }

  Future<void> saveAndNext(String token) async {
    await _syncCurrentResponse(token);
    if (currentQuestionIndex < questions.length - 1) {
      selectQuestion(currentQuestionIndex + 1);
    }
  }

  Future<void> _syncCurrentResponse(String token) async {
    if (attemptId == null) return;
    int qId = currentQuestion.id;
    String? ans = userAnswers[qId];
    bool answered = (ans != null && ans.trim().isNotEmpty);

    try {
      await http.post(
        Uri.parse('${ApiConstants.baseUrl}/exam/save-response/$attemptId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'question_id': qId,
          'selected_answer': ans,
          'is_tukka': isTukkaMap[qId] ?? false,
          'is_marked_for_review': isMarkedReviewMap[qId] ?? false,
          'is_answered': answered,
          'time_spent_seconds': 5,
        }),
      );
    } catch (e) {
      debugPrint("Sync response error: $e");
    }
  }

  Future<Map<String, dynamic>?> viewSolution(String token) async {
    int qId = currentQuestion.id;
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/exam/solution-view/$qId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        solutionLockedUntil[qId] = DateTime.parse(data['locked_until']);
        notifyListeners();
        return data;
      }
    } catch (e) {
      debugPrint("View solution error: $e");
    }
    return null;
  }

  bool isQuestionLocked(int qId) {
    if (solutionLockedUntil.containsKey(qId)) {
      return DateTime.now().isBefore(solutionLockedUntil[qId]!);
    }
    return false;
  }

  Future<Map<String, dynamic>?> submitExam(String token) async {
    _examTimer?.cancel();
    if (attemptId == null) return null;
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/exam/submit/$attemptId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      debugPrint("Submission error: $e");
    }
    return null;
  }

  @override
  void dispose() {
    _examTimer?.cancel();
    super.dispose();
  }
}
