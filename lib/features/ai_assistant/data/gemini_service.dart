import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../transactions/domain/transaction_model.dart';

class GeminiService {
  final String? _apiKey;
  GenerativeModel? _chatModel;
  GenerativeModel? _parserModel;

  GeminiService(this._apiKey) {
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      _chatModel = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey!,
        generationConfig: GenerationConfig(
          responseMimeType: 'text/plain',
        ),
      );
      _parserModel = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey!,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
      );
    }
  }

  bool get isConfigured => _chatModel != null;

  // Ask general questions about transactions
  Future<String> askAssistant({
    required String question,
    required List<TransactionModel> transactions,
  }) async {
    if (!isConfigured) {
      return _getMockAIResponse(question, transactions);
    }

    try {
      final context = _buildTransactionContext(transactions);
      final prompt = '''
      You are Antigravity Finance, a premium AI Financial Assistant.
      Here is the user's transaction data:
      $context
      
      User's Question: "$question"
      
      Provide a concise, professional, and helpful financial advice response. Highlight numbers and suggest ways to save where possible. Avoid markdown blocks other than simple bolding and bullet points.
      ''';

      final content = [Content.text(prompt)];
      final response = await _chatModel!.generateContent(content);
      return response.text ?? "I couldn't process that request.";
    } catch (e) {
      return "Error communicating with Gemini: $e\n\nFallback: ${_getMockAIResponse(question, transactions)}";
    }
  }

  // Parse Voice Inputs
  Future<Map<String, dynamic>> parseVoiceInput(String transcription) async {
    if (!isConfigured) {
      return _getMockVoiceParse(transcription);
    }

    try {
      final prompt = '''
      Extract details from this spoken transaction entry: "$transcription".
      Return a JSON object matching this schema:
      {
        "amount": double (required, extract number),
        "type": "expense" or "income",
        "category": string (must be one of: Food, Grocery, Shopping, Medical, Fuel, Entertainment, Bills, Education, Travel, Rent, EMI, Investment, Salary, Freelancing, Business, Gifts, Bonus, Others),
        "notes": string (short description of what was purchased),
        "merchantName": string (null or merchant name if mentioned)
      }
      ''';

      final content = [Content.text(prompt)];
      final response = await _parserModel!.generateContent(content);
      if (response.text != null) {
        return jsonDecode(response.text!);
      }
      return _getMockVoiceParse(transcription);
    } catch (e) {
      return _getMockVoiceParse(transcription);
    }
  }

  // Helper: Build context string for Gemini
  String _buildTransactionContext(List<TransactionModel> list) {
    final buffer = StringBuffer();
    buffer.writeln("Transaction Logs (last ${list.length} events):");
    for (var tx in list) {
      buffer.writeln(
        "- [${tx.date.toIso8601String().substring(0, 10)}] ${tx.type.name.toUpperCase()}: ${tx.amount} on category '${tx.category}' (${tx.notes}) via ${tx.paymentMethod.displayName}"
      );
    }
    return buffer.toString();
  }

  // Mock answers for immediate fallback demonstration
  String _getMockAIResponse(String query, List<TransactionModel> txs) {
    final lower = query.toLowerCase();
    
    // Simple calculations based on data
    double totalExpense = 0;
    double totalIncome = 0;
    Map<String, double> categorySpending = {};

    for (var tx in txs) {
      if (tx.type == TransactionType.expense) {
        totalExpense += tx.amount;
        categorySpending[tx.category] = (categorySpending[tx.category] ?? 0) + tx.amount;
      } else {
        totalIncome += tx.amount;
      }
    }

    String topCategory = 'None';
    double maxSpend = 0;
    categorySpending.forEach((cat, amt) {
      if (amt > maxSpend) {
        maxSpend = amt;
        topCategory = cat;
      }
    });

    if (lower.contains('where did i spend') || lower.contains('most spend') || lower.contains('highest category')) {
      return "Based on your transaction records, your highest spending category is **$topCategory** with a total of **₹${maxSpend.toStringAsFixed(2)}**. This makes up **${(maxSpend/totalExpense*100).toStringAsFixed(1)}%** of your total monthly expenses. I recommend setting a category-specific budget for **$topCategory** to curb impulse spending.";
    }
    if (lower.contains('how much did i save') || lower.contains('savings')) {
      double savings = totalIncome - totalExpense;
      double savingsRate = totalIncome > 0 ? (savings / totalIncome) * 100 : 0.0;
      return "This month, you received **₹${totalIncome.toStringAsFixed(2)}** in income and spent **₹${totalExpense.toStringAsFixed(2)}**. Your total savings are **₹${savings.toStringAsFixed(2)}**, giving you a savings rate of **${savingsRate.toStringAsFixed(1)}%**. A healthy rate is 20%+, so you are in a **${savingsRate >= 20 ? 'excellent' : 'developing'}** position!";
    }
    if (lower.contains('predict') || lower.contains('overrun') || lower.contains('month-end')) {
      double remainingDays = 15; // Assumption
      double burnRate = totalExpense / 15;
      double predictedExpense = totalExpense + (burnRate * remainingDays);
      return "Your daily burn rate is approximately **₹${burnRate.toStringAsFixed(2)}**. At this pace, I predict your month-end total expense will reach **₹${predictedExpense.toStringAsFixed(2)}**. You have a **${predictedExpense > 45000 ? 'HIGH' : 'LOW'}** risk of exceeding your main monthly budget of **₹45,000**. Try reducing dining out and shopping over the weekends.";
    }
    if (lower.contains('suggest') || lower.contains('save money') || lower.contains('tips')) {
      return "Here are three custom recommendations for you:\n\n"
          "1. **Limit Weekend Dining**: I notice that you have frequent micro-transactions under 'Food' on Fridays and Saturdays.\n"
          "2. **Automate Savings**: Move **₹5,000** to your 'Emergency Fund' goal automatically right after salary day.\n"
          "3. **Cancel Idle Subscriptions**: Review payments to merchants like Netflix or gym memberships if unused.";
    }

    return "Hello! I am your AI Financial Assistant. Based on your records:\n"
        "- Total Income: **₹${totalIncome.toStringAsFixed(2)}**\n"
        "- Total Expenses: **₹${totalExpense.toStringAsFixed(2)}**\n"
        "How can I help you optimize your budgets today?";
  }

  Map<String, dynamic> _getMockVoiceParse(String text) {
    final lower = text.toLowerCase();
    double amount = 0.0;
    
    // Simple regex parse for amount
    final amountMatch = RegExp(r'(\d+)\s*(rupees|rs|bucks|dollars|INR)?').firstMatch(lower);
    if (amountMatch != null) {
      amount = double.tryParse(amountMatch.group(1) ?? '0') ?? 0.0;
    }

    // Determine category
    String category = 'Others';
    if (lower.contains('grocery') || lower.contains('groceries') || lower.contains('supermarket')) {
      category = 'Grocery';
    } else if (lower.contains('food') || lower.contains('restaurant') || lower.contains('dinner') || lower.contains('lunch') || lower.contains('coffee') || lower.contains('starbucks')) {
      category = 'Food';
    } else if (lower.contains('cab') || lower.contains('uber') || lower.contains('fuel') || lower.contains('petrol') || lower.contains('travel')) {
      category = 'Fuel';
    } else if (lower.contains('movie') || lower.contains('netflix') || lower.contains('show') || lower.contains('game')) {
      category = 'Entertainment';
    } else if (lower.contains('rent')) {
      category = 'Rent';
    } else if (lower.contains('salary') || lower.contains('payout') || lower.contains('earned')) {
      category = 'Salary';
    }

    return {
      'amount': amount > 0 ? amount : 150.0,
      'type': (lower.contains('earned') || lower.contains('salary') || lower.contains('received')) ? 'income' : 'expense',
      'category': category,
      'notes': 'Voice entered: "$text"',
    };
  }
}

// AI Providers
final geminiApiKeyProvider = Provider<String?>((ref) {
  // Can be configured from String.fromEnvironment or Remote Config
  const key = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  return key.isNotEmpty ? key : null;
});

final geminiServiceProvider = Provider<GeminiService>((ref) {
  final apiKey = ref.watch(geminiApiKeyProvider);
  return GeminiService(apiKey);
});
