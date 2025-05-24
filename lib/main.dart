import 'package:flutter/material.dart';
import 'db_helper.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Consulta de Registros',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: QueryPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class QueryPage extends StatefulWidget {
  @override
  _QueryPageState createState() => _QueryPageState();
}

class _QueryPageState extends State<QueryPage> {
  final _controller = TextEditingController();
  String _selectedField = "CEDULA";
  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _selectedRecord;
  bool _hasQueried = false;
  bool _isSyncing = false;
  bool _showingMultipleResults = false;
  bool _hasUnsyncedComments = false;
  String? _estado;

  @override
  void initState() {
    super.initState();
    _checkUnsyncedComments();
  }

  Future<void> _checkUnsyncedComments() async {
    bool hasUnsynced = await DBHelper.hasUnsyncedComments();
    setState(() {
      _hasUnsyncedComments = hasUnsynced;
    });
  }

  Future<void> _search() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    List<Map<String, dynamic>> results;

    if (_selectedField == "NOMBRE COMPLETO") {
      // Use name search for partial matching
      results = await DBHelper.queryByName(input);
    } else {
      // Use exact search for CEDULA and CONTACTO 1
      final field = _selectedField == "CONTACTO 1" ? '"CONTACTO 1"' : _selectedField;
      results = await DBHelper.queryData(field, input);
    }

    setState(() {
      _results = results;
      _hasQueried = true;
      _showingMultipleResults = results.length > 1;
      
      if (results.length == 1) {
        // Single result - show directly
        _selectedRecord = results[0];
        _estado = results[0]['ESTADO'];
      } else {
        // Multiple or no results
        _selectedRecord = null;
        _estado = null;
      }
    });
  }

  void _selectRecord(Map<String, dynamic> record) {
    setState(() {
      _selectedRecord = record;
      _estado = record['ESTADO'];
      _showingMultipleResults = false;
    });
  }

  void _backToResults() {
    setState(() {
      _selectedRecord = null;
      _estado = null;
      _showingMultipleResults = _results.length > 1;
    });
  }

  Future<void> _syncDatabase() async {
    setState(() => _isSyncing = true);
    try {
      // Sync database
      await DBHelper.updateDatabase();
      
      // Sync comments if there are any
      if (_hasUnsyncedComments) {
        await DBHelper.syncComments();
        await _checkUnsyncedComments(); // Refresh the unsynced status
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Base de datos actualizada correctamente")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al actualizar la base de datos")),
      );
    }
    setState(() => _isSyncing = false);
  }

  Future<void> _showAddCommentDialog() async {
    if (_selectedRecord == null) return;

    TextEditingController commentController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Añadir Comentario"),
          content: TextField(
            controller: commentController,
            decoration: InputDecoration(
              hintText: "Escribe tu comentario aquí...",
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
            minLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                String comment = commentController.text.trim();
                if (comment.isNotEmpty) {
                  try {
                    await DBHelper.saveComment(_selectedRecord!, comment);
                    Navigator.of(context).pop();
                    
                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Comentario añadido, recuerda sincronizar")),
                    );
                    
                    // Update unsynced comments status
                    await _checkUnsyncedComments();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error al guardar comentario")),
                    );
                  }
                }
              },
              child: Text("Guardar"),
            ),
          ],
        );
      },
    );
  }

  void _showUnsyncedWarning() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text("Comentarios sin sincronizar"),
            ],
          ),
          content: Text("Hay comentarios sin sincronizar. Conéctate a internet y toca el ícono de Sincronizar"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Entendido"),
            ),
          ],
        );
      },
    );
  }

  Color _getEstadoColor(String estado) {
    switch (estado.toLowerCase()) {
      case "encuestado":
        return Colors.blue.shade100;
      case "caracterizado":
        return Colors.purple.shade100;
      case "asignado":
        return Colors.green.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _getEstadoTextColor(String estado) {
    switch (estado.toLowerCase()) {
      case "encuestado":
        return Colors.blue.shade900;
      case "caracterizado":
        return Colors.purple.shade900;
      case "asignado":
        return Colors.green.shade900;
      default:
        return Colors.black;
    }
  }

  Widget _buildMultipleResultsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Se encontraron ${_results.length} resultados:",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        ...List.generate(_results.length, (index) {
          final record = _results[index];
          return Card(
            margin: EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(
                record['NOMBRE COMPLETO']?.toString() ?? 'Sin nombre',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Comunidad: ${record['COMUNIDAD']?.toString() ?? 'N/A'}'),
                  Text('Cédula: ${record['CEDULA']?.toString() ?? 'N/A'}'),
                ],
              ),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _selectRecord(record),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildResultTable() {
    if (_results.isEmpty && _hasQueried) {
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text("No se encontraron resultados."),
      );
    }

    if (_results.isEmpty) return SizedBox();

    if (_showingMultipleResults) {
      return _buildMultipleResultsList();
    }

    if (_selectedRecord == null) return SizedBox();

    final data = _selectedRecord!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Back button when viewing a selected record from multiple results
        if (_results.length > 1)
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: ElevatedButton.icon(
              onPressed: _backToResults,
              icon: Icon(Icons.arrow_back),
              label: Text("Volver a resultados"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.black87,
              ),
            ),
          ),
        
        // Estado display
        if (_estado != null)
          Container(
            padding: EdgeInsets.all(16),
            margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _getEstadoColor(_estado!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "ESTADO: $_estado",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _getEstadoTextColor(_estado!),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        
        // Add comment button
        Container(
          margin: EdgeInsets.only(bottom: 12),
          child: ElevatedButton.icon(
            onPressed: _showAddCommentDialog,
            icon: Icon(Icons.comment_outlined),
            label: Text("Añadir Comentario"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        
        // Record details
        ...data.entries.map((entry) {
          if (entry.key == "ESTADO") return SizedBox.shrink();
          return Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    "${entry.key}:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Text("${entry.value ?? '-'}",
                      style: TextStyle(color: Colors.black87)),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Consulta de Registros"),
        actions: [
          // Warning icon for unsynced comments
          if (_hasUnsyncedComments)
            IconButton(
              icon: Icon(Icons.warning, color: Colors.orange),
              tooltip: "Comentarios sin sincronizar",
              onPressed: _showUnsyncedWarning,
            ),
          // Sync button
          IconButton(
            icon: _isSyncing
                ? CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  )
                : Icon(Icons.sync),
            tooltip: "Actualizar Base de Datos",
            onPressed: _isSyncing ? null : _syncDatabase,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Center(
                child: Image.asset(
                  'assets/logo.png',
                  height: 100,
                ),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedField,
                decoration: InputDecoration(
                  labelText: 'Buscar por',
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: "CEDULA", child: Text("CÉDULA")),
                  DropdownMenuItem(
                      value: "CONTACTO 1", child: Text("CONTACTO (Celular)")),
                  DropdownMenuItem(
                      value: "NOMBRE COMPLETO", child: Text("NOMBRE")),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedField = value!;
                  });
                },
              ),
              SizedBox(height: 12),
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: _selectedField == "NOMBRE COMPLETO" 
                      ? 'Ingrese nombre (búsqueda parcial)'
                      : 'Ingrese valor',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
                onSubmitted: (_) => _search(),
              ),
              SizedBox(height: 12),
              ElevatedButton(
                onPressed: _search,
                child: Text('Buscar'),
                style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14)),
              ),
              SizedBox(height: 24),
              _buildResultTable(),
            ],
          ),
        ),
      ),
    );
  }
}