import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'package:diacritic/diacritic.dart';

class DBHelper {
  static Database? _database;
  static const String _dbFileName = 'data.db';
  static const String dbUrl = 'https://techodbquery.onrender.com/static/data.db';
  static const String commentsFile = 'comments.txt';

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, _dbFileName);
    if (!await File(path).exists()) {
      final data = await rootBundle.load('assets/$_dbFileName');
      final bytes = data.buffer.asUint8List();
      await File(path).writeAsBytes(bytes, flush: true);
    }
    return openDatabase(path);
  }

  static Future<void> updateDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, _dbFileName);
    final resp = await http.get(Uri.parse(dbUrl));
    if (resp.statusCode == 200) {
      await File(path).writeAsBytes(resp.bodyBytes, flush: true);
      if (_database != null && _database!.isOpen) await _database!.close();
      _database = await openDatabase(path);
    } else {
      throw Exception('HTTP ${resp.statusCode}');
    }
  }

  static Future<List<Map<String, dynamic>>> queryData(String field, String value) async {
    final db = await database;
    return db.query(
      'records',
      where: '"\$field" = ?',
      whereArgs: [value],
    );
  }

  // Partial, case-insensitive, accent-insensitive search by name
  static Future<List<Map<String, dynamic>>> queryByName(String input) async {
    final db = await database;
    final rows = await db.query('records');
    final normIn = removeDiacritics(input).toLowerCase();
    return rows.where((r) {
      final name = r['NOMBRE COMPLETO'] as String? ?? '';
      final normName = removeDiacritics(name).toLowerCase();
      return normName.contains(normIn);
    }).toList();
  }

  // Save comments locally to a .txt
  static Future<void> saveComment(Map<String, dynamic> record, String comment) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(join(dir.path, commentsFile));
    final row = jsonEncode({
      'record': record,
      'comment': comment,
    });
    await file.writeAsString(row + '\n', mode: FileMode.append, flush: true);
  }

  // Upload comments file to server via POST
  static Future<void> uploadComments() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(join(dir.path, commentsFile));
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();
    final request = http.MultipartRequest('POST', Uri.parse('https://techodbquery.onrender.com/upload_comments'));
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: commentsFile));
    final resp = await request.send();
    if (resp.statusCode != 200) throw Exception('Upload failed');
  }
  static Future<List<Map<String, dynamic>>> getUnsyncedComments() async {
    final db = await DBHelper.database();
    return await db.query(
      'comments',
      where: 'synced = ?',
      whereArgs: [0],
    );
  }
  static Future<void> updateComment(Map commentRow, String newComment) async {
    final db = await DBHelper.database();
    await db.update(
      'comments',
      {
        'comentario': newComment,
        'synced': 0, // stay unsynced until manually pushed
      },
      where: 'id = ?',
      whereArgs: [commentRow['id']],
    );
  }

}