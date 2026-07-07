import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/config/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../data/gemini_service.dart';
import '../services/voice_service.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction_model.dart';

class Message {
  final String text;
  final bool isUser;
  final DateTime time;

  Message({required this.text, required this.isUser, required this.time});
}

class AiChatScreen extends ConsumerStatefulWidget {
  final bool startWithVoice;
  final bool showAppBar;

  const AiChatScreen({
    super.key,
    this.startWithVoice = false,
    this.showAppBar = true,
  });

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final List<Message> _messages = [];
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _voiceService = VoiceService();
  
  bool _isLoading = false;
  bool _isListening = false;
  bool _ttsEnabled = true;
  String _listeningText = 'Listening...';

  @override
  void initState() {
    super.initState();
    _messages.add(
      Message(
        text: "Hello! I am Antigravity AI, your dedicated financial strategist. Ask me about your expenses, savings rates, or say something like 'Spent 450 rupees on groceries' to enter a transaction via voice.",
        isUser: false,
        time: DateTime.now(),
      ),
    );
    _voiceService.init().then((_) {
      if (widget.startWithVoice) {
        _startVoiceRecording();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _voiceService.stopListening();
    _voiceService.stopSpeaking();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(Message(text: text, isUser: true, time: DateTime.now()));
      _isLoading = true;
    });
    _scrollToBottom();
    _textController.clear();

    final txsState = ref.read(transactionListProvider);
    final transactions = txsState.maybeWhen(
      data: (list) => list,
      orElse: () => <TransactionModel>[],
    );

    final gemini = ref.read(geminiServiceProvider);
    final response = await gemini.askAssistant(
      question: text,
      transactions: transactions,
    );

    setState(() {
      _messages.add(Message(text: response, isUser: false, time: DateTime.now()));
      _isLoading = false;
    });
    _scrollToBottom();

    if (_ttsEnabled) {
      // Speak response without markdown tokens
      final cleanText = response.replaceAll('**', '').replaceAll('*', '');
      await _voiceService.speak(cleanText);
    }
  }

  Future<void> _startVoiceRecording() async {
    await _voiceService.stopSpeaking();
    setState(() {
      _isListening = true;
      _listeningText = 'Listening...';
    });

    await _voiceService.startListening(
      onResult: (words) {
        setState(() {
          _listeningText = words;
        });
      },
      onSoundLevelChange: (_) {},
    );
  }

  Future<void> _stopVoiceRecording() async {
    await _voiceService.stopListening();
    setState(() {
      _isListening = false;
    });

    final recordedText = _listeningText;
    if (recordedText.isNotEmpty && recordedText != 'Listening...') {
      // Process voice entry
      setState(() => _isLoading = true);
      
      final isTransactionEntry = _isPotentialTransaction(recordedText);
      
      if (isTransactionEntry) {
        final gemini = ref.read(geminiServiceProvider);
        final details = await gemini.parseVoiceInput(recordedText);
        
        final amt = (details['amount'] as num?)?.toDouble() ?? 0.0;
        final notes = details['notes'] as String? ?? 'Voice entry';
        final cat = details['category'] as String? ?? 'Others';
        final typeStr = details['type'] as String? ?? 'expense';
        final type = typeStr == 'income' ? TransactionType.income : TransactionType.expense;

        if (amt > 0) {
          final tx = TransactionModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            amount: amt,
            type: type,
            category: cat,
            date: DateTime.now(),
            notes: notes,
            paymentMethod: PaymentMethod.cash,
            isSynced: false,
            updatedAt: DateTime.now(),
          );
          
          await ref.read(transactionListProvider.notifier).addTransaction(tx);
          
          final feedback = "Success! Added ₹$amt to your $cat ${type.name} logs.";
          
          setState(() {
            _messages.add(Message(text: 'Voice: "$recordedText"', isUser: true, time: DateTime.now()));
            _messages.add(Message(text: feedback, isUser: false, time: DateTime.now()));
            _isLoading = false;
          });
          _scrollToBottom();
          
          if (_ttsEnabled) {
            await _voiceService.speak(feedback);
          }
          return;
        }
      }
      
      // Fallback: send text to regular Gemini Chat
      await _sendMessage(recordedText);
    }
  }

  bool _isPotentialTransaction(String text) {
    final lower = text.toLowerCase();
    return lower.contains('spent') || 
           lower.contains('paid') || 
           lower.contains('rupees') || 
           lower.contains('rs') || 
           lower.contains('cost') ||
           lower.contains('received') ||
           lower.contains('earned');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Antigravity AI'),
              actions: [
                // TTS toggle
                IconButton(
                  icon: Icon(
                      _ttsEnabled
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      color: _ttsEnabled ? AppColors.accent : Colors.grey),
                  onPressed: () {
                    setState(() => _ttsEnabled = !_ttsEnabled);
                    if (!_ttsEnabled) _voiceService.stopSpeaking();
                  },
                )
              ],
            )
          : null,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppColors.darkBackground, const Color(0xFF0F101A)]
                : [AppColors.lightBackground, const Color(0xFFEDF2F7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Suggestions bar
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: [
                    _SuggestionChip(
                      label: 'Where did I spend the most?',
                      onTap: () => _sendMessage('Where did I spend the most?'),
                    ),
                    const SizedBox(width: 8),
                    _SuggestionChip(
                      label: 'Predict month-end balance',
                      onTap: () => _sendMessage('Predict my month-end balance and budget risks.'),
                    ),
                    const SizedBox(width: 8),
                    _SuggestionChip(
                      label: 'Suggest ways to save money',
                      onTap: () => _sendMessage('Suggest some ways to save money based on my data.'),
                    ),
                  ],
                ),
              ),
              
              // Messages Chat Area
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return _ChatBubble(message: msg);
                  },
                ),
              ),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),

              // Listening overlay indicator
              if (_isListening)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppColors.primary.withOpacity(0.08),
                  child: Row(
                    children: [
                      const Icon(Icons.hearing_rounded, color: AppColors.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _listeningText,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      GestureDetector(
                        onTap: _stopVoiceRecording,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.expense,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('STOP', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                ),

              // Inputs bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        borderRadius: 30,
                        child: TextField(
                          controller: _textController,
                          decoration: const InputDecoration(
                            hintText: 'Type query...',
                            border: InputBorder.none,
                          ),
                          onSubmitted: _sendMessage,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Mic button
                    GestureDetector(
                      onTap: _isListening ? _stopVoiceRecording : _startVoiceRecording,
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: _isListening ? AppColors.expense : AppColors.primary,
                        child: Icon(
                          _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final Message message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(message.isUser ? 20 : 0),
            bottomRight: Radius.circular(message.isUser ? 0 : 20),
          ),
        ),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          borderRadius: 20,
          color: message.isUser 
              ? AppColors.primary.withOpacity(0.12)
              : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.01)),
          border: Border.all(
            color: message.isUser 
                ? AppColors.primary.withOpacity(0.3)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Text(
            message.text,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
