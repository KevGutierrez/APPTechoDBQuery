import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DBHelper {
  static Database? _database;
  
  // Path for the downloaded DB file
  static const String _dbFileName = "data.db";
  
  // URL to download the latest DB version
  static const String dbUrl = "https://techodbquery.onrender.com/static/data.db";
  
  // URL to upload comments
  static const String uploadUrl = "https://techodbquery.onrender.com/upload_comments";

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
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, _dbFileName);
      
      final response = await http.get(Uri.parse(dbUrl));
      if (response.statusCode == 200) {
        // Write the downloaded database to the app directory
        final file = File(path);
        await file.writeAsBytes(response.bodyBytes, flush: true);
        
        // Close the existing database if open
        if (_database != null && _database!.isOpen) {
          await _database!.close();
          _database = null;
        }
        
        // Reopen the database
        _database = await openDatabase(path);
        print("✅ Database updated successfully");
      } else {
        print("❌ HTTP Error: ${response.statusCode}");
        throw Exception("Failed to download database");
      }
    } catch (e) {
      print("❌ Exception in updateDatabase(): $e");
      throw Exception("Error updating database: $e");
    }
  }

  // Query DB by CEDULA or CONTACTO 1 (exact match)
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

  // Query DB by name (partial, case-insensitive, accent-insensitive)
  static Future<List<Map<String, dynamic>>> queryByName(String searchTerm) async {
    final db = await database;
    
    // Normalize the search term (remove accents, convert to lowercase)
    String normalizedSearch = _normalizeString(searchTerm);
    
    // Get all records with NOMBRE COMPLETO
    final results = await db.query('records');
    
    // Filter results manually for accent-insensitive search
    List<Map<String, dynamic>> filteredResults = [];
    
    for (var record in results) {
      String? nombreCompleto = record['NOMBRE COMPLETO']?.toString();
      if (nombreCompleto != null) {
        String normalizedNombre = _normalizeString(nombreCompleto);
        if (normalizedNombre.contains(normalizedSearch)) {
          filteredResults.add(record);
        }
      }
    }
    
    return filteredResults;
  }

  // Helper function to normalize strings (remove accents, convert to lowercase)
  static String _normalizeString(String input) {
    String normalized = input.toLowerCase();
    
    // Remove accents
    normalized = normalized
        .replaceAll(RegExp(r'[áàäâã]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöôõ]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[ç]'), 'c');
    
    return normalized;
  }

  // Save comment locally to a timestamped file
  static Future<void> saveComment(Map<String, dynamic> record, String comment) async {
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      
      // Create timestamp for filename
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String fileName = "comments_$timestamp.txt";
      String filePath = join(documentsDirectory.path, fileName);
      
      // Create timestamp for content
      String contentTimestamp = DateTime.now().toIso8601String();
      
      // Format: CEDULA|NOMBRE|COMUNIDAD|COMMENT|TIMESTAMP
      String cedula = record['CEDULA']?.toString() ?? '';
      String nombre = record['NOMBRE COMPLETO']?.toString() ?? '';
      String comunidad = record['COMUNIDAD']?.toString() ?? '';
      
      String line = "$cedula|$nombre|$comunidad|$comment|$contentTimestamp\n";
      
      // Write to file
      final file = File(filePath);
      await file.writeAsString(line);
      
      // Mark that there are unsynced comments
      await _setHasUnsyncedComments(true);
      
      print("✅ Comment saved locally: $fileName");
    } catch (e) {
      print("❌ Error saving comment: $e");
      throw Exception("Error saving comment: $e");
    }
  }

  // Upload all comment files to server
  static Future<void> syncComments() async {
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      
      // Find all comment files
      List<FileSystemEntity> files = documentsDirectory.listSync()
          .where((file) => file.path.contains('comments_') && file.path.endsWith('.txt'))
          .toList();
      
      if (files.isEmpty) {
        print("ℹ️ No comment files to sync");
        return;
      }
      
      int uploadedCount = 0;
      
      for (FileSystemEntity fileEntity in files) {
        File file = File(fileEntity.path);
        
        // Create multipart request
        var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
        request.files.add(await http.MultipartFile.fromPath('file', file.path));
        
        // Send request
        var response = await request.send();
        
        if (response.statusCode == 200) {
          // Delete the local file after successful upload
          await file.delete();
          uploadedCount++;
          print("✅ Uploaded and deleted: ${file.path}");
        } else {
          print("❌ Failed to upload: ${file.path}, Status: ${response.statusCode}");
        }
      }
      
      if (uploadedCount > 0) {
        // Mark that comments are synced
        await _setHasUnsyncedComments(false);
        print("✅ Successfully synced $uploadedCount comment files");
      }
      
    } catch (e) {
      print("❌ Error syncing comments: $e");
      throw Exception("Error syncing comments: $e");
    }
  }

  // Check if there are unsynced comments
  static Future<bool> hasUnsyncedComments() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_unsynced_comments') ?? false;
  }

  // Set unsynced comments flag
  static Future<void> _setHasUnsyncedComments(bool hasUnsynced) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_unsynced_comments', hasUnsynced);
  }
}