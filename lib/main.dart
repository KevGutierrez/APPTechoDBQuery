import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  List<String> _history = [];
  List<String> _filteredHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _controller.addListener(_filterHistory);
    _checkUnsyncedComments();
  }

  Future<void> _checkUnsyncedComments() async {
    final comments = await DBHelper.getUnsyncedComments();
    setState(() {
      _hasUnsyncedComments = comments.isNotEmpty;
    });
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _history = prefs.getStringList('query_history') ?? [];
    _filteredHistory = List.from(_history);
    setState(() {});
  }

  void _filterHistory() {
    final input = _controller.text.toLowerCase();
    _filteredHistory = _history.where((item) => item.toLowerCase().contains(input)).toList();
    setState(() {});
  }

  Future<void> _addToHistory(String value) async {
    if (value.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _history.remove(value);
    _history.insert(0, value);
    if (_history.length > 5) _history = _history.sublist(0, 5);
    await prefs.setStringList('query_history', _history);
    _filteredHistory = List.from(_history);
  }

  Future<void> _search() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;
    await _addToHistory(input);
    setState(() => _hasQueried = true);

    if (_selectedField == 'NOMBRE') {
      _results = await DBHelper.queryByName(input);
    } else {
      final field = _selectedField == 'CONTACTO 1' ? 'CONTACTO 1' : _selectedField;
      _results = await DBHelper.queryData(field, input);
    }
    if (_results.isNotEmpty) {
      _estado = _results.first['ESTADO'];
    }
    setState(() {});
  }

  Future<void> _syncDatabase() async {
    setState(() => _isSyncing = true);
    await DBHelper.updateDatabase();
    if (_hasUnsyncedComments) {
      await DBHelper.uploadComments();
      setState(() => _hasUnsyncedComments = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Comentarios sincronizados correctamente'),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Base de datos actualizada correctamente'),
      ));
    }
    setState(() => _isSyncing = false);
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
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
    if (comment != null && comment.isNotEmpty) {
      await DBHelper.saveComment(record, comment);
      setState(() => _hasUnsyncedComments = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Comentario añadido, recuerda sincronizar'),
      ));
    }
  }

  Future<void> _showCommentsDialog() async {
    final comments = await DBHelper.getUnsyncedComments();
    if (comments.isEmpty) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Comentarios pendientes'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('NOMBRE COMPLETO')),
                  DataColumn(label: Text('COMUNIDAD')),
                  DataColumn(label: Text('COMENTARIO')),
                  DataColumn(label: Text('')),
                ],
                rows: comments.map((row) {
                  return DataRow(cells: [
                    DataCell(Text(row['NOMBRE COMPLETO'] ?? '')),
                    DataCell(Text(row['COMUNIDAD'] ?? '')),
                    DataCell(Text(row['COMENTARIO'] ?? '')),
                    DataCell(IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () async {
                        final newComment = await showDialog<String>(
                          context: context,
                          builder: (ctx2) {
                            final ctrl = TextEditingController(text: row['COMENTARIO']);
                            return AlertDialog(
                              title: const Text('Editar Comentario'),
                              content: TextField(
                                controller: ctrl,
                                decoration: const InputDecoration(hintText: 'Nuevo comentario'),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx2),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx2, ctrl.text.trim()),
                                  child: const Text('Guardar'),
                                ),
                              ],
                            );
                          },
                        );
                        if (newComment != null && newComment.isNotEmpty) {
                          await DBHelper.updateComment(row, newComment);
                          _showCommentsDialog();
                        }
                      },
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
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
            title: Text(r['NOMBRE COMPLETO']),
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
              tooltip: 'Ver comentarios pendientes',
              onPressed: _showCommentsDialog,
            ),
          if (_hasUnsyncedComments)
            IconButton(
              icon: const Icon(Icons.warning, color: Colors.yellow),
              tooltip: 'Hay comentarios sin sincronizar. ...',
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const AlertDialog(
                  content: Text('Hay comentarios sin sincronizar. Conéctate a internet y toca el ícono de Sincronizar'),
                ),
              ),
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
              Center(child: Image.asset('assets/logo.png', height: 100)),
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
              if (_filteredHistory.isNotEmpty && _controller.text.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredHistory.length,
                    itemBuilder: (_, i) => ListTile(
                      title: Text(_filteredHistory[i]),
                      onTap: () {
                        _controller.text = _filteredHistory[i];
                        _search();
                      },
                    ),
                  ),
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
