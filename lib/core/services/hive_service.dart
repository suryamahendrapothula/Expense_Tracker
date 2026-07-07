import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HiveService {
  static const String expensesBoxName = 'expenses_box';
  static const String incomeBoxName = 'income_box';
  static const String budgetsBoxName = 'budgets_box';
  static const String goalsBoxName = 'goals_box';
  static const String settingsBoxName = 'settings_box';

  static String? _currentUid;

  static void setCurrentUser(String? uid) {
    _currentUid = uid;
  }

  static String _getBoxName(String baseName) {
    if (baseName == settingsBoxName) return baseName;
    final uid = _currentUid ?? FirebaseAuth.instance.currentUser?.uid;
    return uid != null ? '${baseName}_$uid' : baseName;
  }

  static Future<void> openBoxesForUser(String? uid) async {
    _currentUid = uid;
    if (uid != null) {
      await Hive.openBox<Map>('${expensesBoxName}_$uid');
      await Hive.openBox<Map>('${incomeBoxName}_$uid');
      await Hive.openBox<Map>('${budgetsBoxName}_$uid');
      await Hive.openBox<Map>('${goalsBoxName}_$uid');
      await Hive.openBox<Map>('${settingsBoxName}_$uid');
    }
  }

  static Future<void> init() async {
    if (kIsWeb) {
      await Hive.initFlutter();
    } else {
      final directory = await getApplicationDocumentsDirectory();
      await Hive.initFlutter(directory.path);
    }
    
    await Hive.openBox<Map>(expensesBoxName);
    await Hive.openBox<Map>(incomeBoxName);
    await Hive.openBox<Map>(budgetsBoxName);
    await Hive.openBox<Map>(goalsBoxName);
    await Hive.openBox<Map>(settingsBoxName);

    // If user is already logged in at startup, open user specific boxes
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await openBoxesForUser(user.uid);
    }
  }

  // Generic Operations
  static Box<Map> getBox(String name) {
    final boxName = _getBoxName(name);
    if (!Hive.isBoxOpen(boxName)) {
      return Hive.box<Map>(name);
    }
    return Hive.box<Map>(boxName);
  }

  static List<Map<String, dynamic>> getAllItems(String boxName) {
    final box = getBox(boxName);
    return box.values.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  static Future<void> saveItem(String boxName, String id, Map<String, dynamic> item) async {
    final box = getBox(boxName);
    await box.put(id, item);
  }

  static Future<void> deleteItem(String boxName, String id) async {
    final box = getBox(boxName);
    await box.delete(id);
  }

  static Future<void> clearAllBoxes() async {
    // Clear only default boxes
    await Hive.box<Map>(expensesBoxName).clear();
    await Hive.box<Map>(incomeBoxName).clear();
    await Hive.box<Map>(budgetsBoxName).clear();
    await Hive.box<Map>(goalsBoxName).clear();
    await Hive.box<Map>(settingsBoxName).clear();
    _currentUid = null;
  }
}
