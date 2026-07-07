import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/config/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/custom_button.dart';
import '../services/ocr_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
  final _ocrService = OCRService();
  final _picker = ImagePicker();
  
  bool _isProcessing = false;
  late AnimationController _scannerAnimController;
  late Animation<double> _scannerOffset;

  @override
  void initState() {
    super.initState();
    _scannerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _scannerOffset = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scannerAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ocrService.dispose();
    _scannerAnimController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() => _isProcessing = true);
        
        // Scan with ML Kit service
        final results = await _ocrService.scanReceipt(image.path);
        
        setState(() => _isProcessing = false);
        _showExtractedDetails(results);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scanning failed: $e'), backgroundColor: AppColors.expense),
      );
    }
  }

  void _showExtractedDetails(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Extracted Receipt Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('AI Suggested', style: TextStyle(fontSize: 9, color: AppColors.accent, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              const SizedBox(height: 20),
              
              // Extracted Rows
              _DetailRow(label: 'Merchant', value: data['merchantName'] ?? 'Unknown Merchant'),
              _DetailRow(label: 'Total Amount', value: '₹${(data['amount'] as double).toStringAsFixed(2)}'),
              _DetailRow(label: 'Tax (Estimated)', value: '₹${(data['tax'] as double).toStringAsFixed(2)}'),
              _DetailRow(label: 'Suggested Category', value: data['suggestedCategory'] ?? 'Others'),
              const SizedBox(height: 24),
              
              CustomButton(
                text: 'Confirm & Populate Form',
                onTap: () {
                  context.pop(); // Close bottom sheet
                  // Navigate to Add Transaction with prefilled parameters
                  final amt = data['amount'];
                  final merchant = Uri.encodeComponent(data['merchantName'] ?? 'Unknown');
                  final category = Uri.encodeComponent(data['suggestedCategory'] ?? 'Others');
                  
                  context.pop(); // Close Scanner Screen
                  context.push('/add-transaction?id=new&prefill=true');
                  
                  // In a real app we'd pass state, here we can show prefill success notification
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Form populated with receipt details!')),
                  );
                },
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Scanner'),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppColors.darkBackground, const Color(0xFF131526)]
                : [AppColors.lightBackground, const Color(0xFFEDF2F7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Scanner view finder window
              Center(
                child: Container(
                  height: 320,
                  width: 280,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: Stack(
                    children: [
                      // Backdrop tint
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      
                      // Scanner moving line
                      if (_isProcessing)
                        const Center(child: CircularProgressIndicator())
                      else
                        AnimatedBuilder(
                          animation: _scannerOffset,
                          builder: (context, child) {
                            return Positioned(
                              top: _scannerOffset.value * 300,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 3,
                                decoration: const BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accent,
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    )
                                  ],
                                  color: AppColors.accent,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: const Text(
                  'Align your receipt within the frame. Antigravity AI will automatically extract amounts, items, and tax info.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                ),
              ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('GALLERY'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('CAMERA'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
