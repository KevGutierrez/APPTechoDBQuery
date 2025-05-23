import 'package:flutter/material.dart';
import 'db_helper.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Consulta de Registros',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const QueryPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class QueryPage extends StatefulWidget {
  const QueryPage({super.key});

  @override
  State<QueryPage> createState() => _QueryPageState();
}

class _QueryPageState extends State<QueryPage> {
  final _controller = TextEditingController();
  String _selectedField = 'CEDULA';
  List<Map<String, dynamic>> _results = [];
  bool _hasQueried = false;
  bool _isSyncing = false;
  String? _estado;
  bool _hasUnsyncedComments = false;

  @override
  void initState() {
    super.initState();
    DBHelper.checkUnsyncedComments().then((hasUnsynced) {
      setState(() => _hasUnsyncedComments = hasUnsynced);
    });
  }

  Future<void> _search() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;
    setState(() => _hasQueried = true);

    if (_selectedField == 'NOMBRE') {
      _results = await DBHelper.queryByName(input);
    } else {
      _results = await DBHelper.queryData(_selectedField, input);
    }

    if (_results.length == 1) {
      _estado = _results.first['ESTADO'];
    }

    setState(() {});
  }

  Future<void> _syncDatabase() async {
    setState(() => _isSyncing = true);
    await DBHelper.updateDatabase();
    await DBHelper.uploadComments();
    final hasUnsynced = await DBHelper.checkUnsyncedComments();
    setState(() {
      _hasUnsyncedComments = hasUnsynced;
      _isSyncing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Base de datos sincronizada.'),
    ));
  }

  Future<void> _showUnsyncedComments() async {
    final comments = await DBHelper.getUnsyncedComments();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Comentarios sin sincronizar'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: comments.map((comment) {
              final ctrl = TextEditingController(text: comment['comentario']);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(comment['nombre'] ?? '')),
                    Expanded(flex: 2, child: Text(comment['comunidad'] ?? '')),
                    Expanded(
                      flex: 5,
                      child: TextField(
                        controller: ctrl,
                        onSubmitted: (newValue) => DBHelper.updateComment(comment['id'], newValue),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
      ),
    );
  }

  void _addComment(Map<String, dynamic> record) async {
    final comment = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Añadir Comentario'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(hintText: 'Ingrese comentario'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Guardar')),
          ],
        );
      },
    );
    if (comment != null && comment.isNotEmpty) {
      await DBHelper.saveComment(record, comment);
      setState(() => _hasUnsyncedComments = true);
    }
  }

  Widget _buildResultsView() {
    if (!_hasQueried) return const SizedBox();
    if (_results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: Text('No se encontraron resultados.'),
      );
    }
    if (_selectedField == 'NOMBRE' && _results.length > 1) {
      return ListView.builder(
        shrinkWrap: true,
        itemCount: _results.length,
        itemBuilder: (_, i) {
          final r = _results[i];
          return ListTile(
            title: Text(r['NOMBRE COMPLETO'] ?? ''),
            subtitle: Text('${r['COMUNIDAD']} | ${r['CEDULA']}'),
            onTap: () {
              setState(() {
                _results = [r];
                _estado = r['ESTADO'];
              });
            },
          );
        },
      );
    }
    final record = _results.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Nombre: ${record['NOMBRE COMPLETO']}'),
        Text('Comunidad: ${record['COMUNIDAD']}'),
        Text('Cédula: ${record['CEDULA']}'),
        if (_estado != null) Text('Estado: $_estado'),
        ElevatedButton(
          onPressed: () => _addComment(record),
          child: const Text('Añadir comentario'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consulta de Registros'),
        actions: [
          if (_hasUnsyncedComments)
            IconButton(
              icon: const Icon(Icons.comment),
              tooltip: 'Ver comentarios sin sincronizar',
              onPressed: _showUnsyncedComments,
            ),
          IconButton(
            icon: _isSyncing
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.sync),
            onPressed: _isSyncing ? null : _syncDatabase,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedField,
                decoration: const InputDecoration(
                  labelText: 'Buscar por',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'CEDULA', child: Text('CEDULA')),
                  DropdownMenuItem(value: 'CONTACTO 1', child: Text('CONTACTO (Celular)')),
                  DropdownMenuItem(value: 'NOMBRE', child: Text('Nombre')),
                ],
                onChanged: (v) => setState(() => _selectedField = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Ingrese valor',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _search(),
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _search, child: const Text('Buscar')),
              const SizedBox(height: 24),
              _buildResultsView(),
            ],
          ),
        ),
      ),
    );
  }
}