import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../transactions/domain/transaction_model.dart';

class ReportGenerator {
  
  // Generate PDF Report
  static Future<File> generatePDF({
    required List<TransactionModel> transactions,
    required double totalIncome,
    required double totalExpense,
  }) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('dd MMM yyyy').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          // Header
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Antigravity Finance Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Text('Generated: $dateStr', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Overview Table
          pw.Text('Financial Summary', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['Parameter', 'Value'],
            data: [
              ['Total Income', 'Rs. ${totalIncome.toStringAsFixed(2)}'],
              ['Total Expenses', 'Rs. ${totalExpense.toStringAsFixed(2)}'],
              ['Net Balance', 'Rs. ${(totalIncome - totalExpense).toStringAsFixed(2)}'],
              ['Savings Rate', '${totalIncome > 0 ? ((totalIncome - totalExpense) / totalIncome * 100).toStringAsFixed(1) : 0.0}%'],
            ],
          ),
          pw.SizedBox(height: 30),

          // Transactions Table
          pw.Text('Recent Transactions Log', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Category', 'Notes', 'Type', 'Method', 'Amount (Rs.)'],
            data: transactions.map((t) => [
              DateFormat('dd-MM-yyyy').format(t.date),
              t.category,
              t.notes.isNotEmpty ? t.notes : '-',
              t.type.name.toUpperCase(),
              t.paymentMethod.displayName,
              t.amount.toStringAsFixed(2),
            ]).toList(),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Antigravity_Report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // Generate Excel Spreadsheet
  static Future<File> generateExcel({
    required List<TransactionModel> transactions,
  }) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Transactions'];
    
    // Set headers
    sheet.appendRow([
      TextCellValue('Transaction ID'),
      TextCellValue('Date'),
      TextCellValue('Type'),
      TextCellValue('Category'),
      TextCellValue('Merchant'),
      TextCellValue('Amount (Rs.)'),
      TextCellValue('Payment Method'),
      TextCellValue('Notes'),
    ]);

    for (var tx in transactions) {
      sheet.appendRow([
        TextCellValue(tx.id),
        TextCellValue(DateFormat('dd-MM-yyyy HH:mm').format(tx.date)),
        TextCellValue(tx.type.name.toUpperCase()),
        TextCellValue(tx.category),
        TextCellValue(tx.merchantName ?? '-'),
        DoubleCellValue(tx.amount),
        TextCellValue(tx.paymentMethod.displayName),
        TextCellValue(tx.notes),
      ]);
    }

    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/Antigravity_Transactions_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    
    final fileBytes = excel.save();
    if (fileBytes != null) {
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      return file;
    }
    throw Exception('Failed to generate Excel file bytes');
  }

  // Generate CSV String File
  static Future<File> generateCSV({
    required List<TransactionModel> transactions,
  }) async {
    final buffer = StringBuffer();
    // Headers
    buffer.writeln('Date,Type,Category,Merchant,Amount,PaymentMethod,Notes');

    for (var tx in transactions) {
      final date = DateFormat('yyyy-MM-dd HH:mm').format(tx.date);
      final notes = tx.notes.replaceAll('"', '""');
      buffer.writeln(
        '$date,${tx.type.name.toUpperCase()},"${tx.category}","${tx.merchantName ?? ''}",${tx.amount},${tx.paymentMethod.displayName},"$notes"'
      );
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Antigravity_CSV_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(buffer.toString());
    return file;
  }
}
