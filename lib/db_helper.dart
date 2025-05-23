import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;

class DBHelper {
  static Database? _database;

  // Path for the downloaded DB file
  static const String _dbFileName = "data.db";

  // URL to download the latest DB version
  static const String dbUrl = "https://techodbquery.onrender.com/static/data.db";

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _dbFileName);

    // Copy from assets if not already present
    if (!await File(path).exists()) {
      ByteData data = await rootBundle.load("assets/$_dbFileName");
      List<int> bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes);
    }

    return await openDatabase(path);
  }

  // Update DB by downloading new version
  static Future<void> updateDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _dbFileName);

    final response = await http.get(Uri.parse(dbUrl));
    if (response.statusCode == 200) {
      await File(path).writeAsBytes(response.bodyBytes);

      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      _database = await openDatabase(path);
    } else {
      throw Exception("Failed to download database");
    }
  }

  // Query DB by CEDULA or CONTACTO 1
  static Future<List<Map<String, dynamic>>> queryData(String field, String value) async {
    final db = await database;
    // Remove any existing quotes from field
    String cleanField = field.replaceAll('"', '');

    return await db.query(
      'records',
      where: '"$cleanField" = ?',
      whereArgs: [value],
    );
  }
}
