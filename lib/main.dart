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
  bool _hasQueried = false;
  bool _isSyncing = false;
  String? _estado;

  Future<void> _search() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    // Fix: escape field with space
    final field = _selectedField == "CONTACTO 1" ? '"CONTACTO 1"' : _selectedField;
    final results = await DBHelper.queryData(field, input);

    setState(() {
      _results = results;
      _hasQueried = true;
      _estado = results.isNotEmpty ? results[0]['ESTADO'] : null;
    });
  }

  Future<void> _syncDatabase() async {
    setState(() => _isSyncing = true);
    try {
      await DBHelper.updateDatabase();
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

  Widget _buildResultTable() {
    if (_results.isEmpty && _hasQueried) {
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text("No se encontraron resultados."),
      );
    }

    if (_results.isEmpty) return SizedBox();

    final data = _results[0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text("Consulta de Registros"),
        actions: [
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
                  labelText: 'Ingrese valor',
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
