class ChatQA {
  final String category;
  final String subCategory;
  final String question;
  final String answerTemplate;
  final List<String>? variables;

  const ChatQA({
    required this.category,
    required this.subCategory,
    required this.question,
    required this.answerTemplate,
    this.variables,
  });

  /// Convert map (e.g., from Firestore or JSON) into ChatQA object
  factory ChatQA.fromMap(Map<String, dynamic> map) {
    return ChatQA(
      category: map['category'] ?? '',
      subCategory: map['subCategory'] ?? '',
      question: map['question'] ?? '',
      answerTemplate: map['answerTemplate'] ?? '',
      variables: map['variables'] != null
          ? List<String>.from(map['variables'])
          : null,
    );
  }

  /// Convert ChatQA object into map (e.g., to save in Firestore or JSON)
  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'subCategory': subCategory,
      'question': question,
      'answerTemplate': answerTemplate,
      if (variables != null) 'variables': variables,
    };
  }

  /// Generate final answer by replacing variables with context values
  String getAnswer(Map<String, dynamic>? context) {
    if (variables == null || context == null) return answerTemplate;

    String answer = answerTemplate;
    for (var variable in variables!) {
      if (context.containsKey(variable)) {
        answer = answer.replaceAll('{$variable}', context[variable].toString());
      }
    }
    return answer;
  }

  @override
  String toString() {
    return 'ChatQA(category: $category, subCategory: $subCategory, question: $question)';
  }
}
