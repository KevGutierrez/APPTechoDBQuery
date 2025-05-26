import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Consulta de Registros',
      theme: ThemeData(
        primarySwatch: MaterialColor(0xFF0092DD, {
          50: Color(0xFFE3F4FF),
          100: Color(0xFFB8E3FF),
          200: Color(0xFF8BD1FF),
          300: Color(0xFF5EBFFF),
          400: Color(0xFF3DB1FF),
          500: Color(0xFF0092DD),
          600: Color(0xFF0085C9),
          700: Color(0xFF0074B3),
          800: Color(0xFF00649D),
          900: Color(0xFF004677),
        }),
        primaryColor: Color(0xFF0092DD),
        fontFamily: 'Montserrat',
      ),
      home: SplashScreen(nextScreen: QueryPage()),
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
  DateTime? _lastSyncTime;
  String? _estado;
  String? _selectedComunidad;
  String? _selectedEstado;
  bool _showFilters = false;
  List<String> _recentCedulaSearches = [];
  List<String> _recentContactoSearches = [];
  List<String> _recentNombreSearches = [];
  bool _showSuggestions = false;
  FocusNode _searchFocusNode = FocusNode();


  @override
  void initState() {
    super.initState();
    _checkUnsyncedComments();
    _loadLastSyncTime();
    _loadRecentSearches(); // Add this line
    _searchFocusNode.addListener(_onFocusChange); // Add this line
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  bool _areFiltersActive() {
    return (_selectedComunidad != null && _selectedComunidad != "Todas") ||
          (_selectedEstado != null && _selectedEstado != "Todos");
  }
  bool _hasActiveFilters() {
    return _selectedComunidad != null || _selectedEstado != null;
  }


  Future<void> _checkUnsyncedComments() async {
    bool hasUnsynced = await DBHelper.hasUnsyncedComments();
    setState(() {
      _hasUnsyncedComments = hasUnsynced;
    });
  }

  Future<void> _loadLastSyncTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? timestamp = prefs.getInt('last_sync_timestamp');
    if (timestamp != null) {
      setState(() {
        _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      });
    }
  }

  void _onFocusChange() {
    setState(() {
      _showSuggestions = _searchFocusNode.hasFocus && _getRecentSearches().isNotEmpty;
    });
  }

  Future<void> _loadRecentSearches() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentCedulaSearches = prefs.getStringList('recent_cedula') ?? [];
      _recentContactoSearches = prefs.getStringList('recent_contacto') ?? [];
      _recentNombreSearches = prefs.getStringList('recent_nombre') ?? [];
    });
  }

  Future<void> _saveRecentSearch(String term) async {
    if (term.trim().isEmpty) return;
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> currentList = _getRecentSearches();
    
    // Remove if exists and add to beginning
    currentList.remove(term);
    currentList.insert(0, term);
    
    // Keep only last 5 searches
    if (currentList.length > 5) {
      currentList = currentList.take(5).toList();
    }
    
    // Save based on current field
    switch (_selectedField) {
      case "CEDULA":
        _recentCedulaSearches = currentList;
        await prefs.setStringList('recent_cedula', currentList);
        break;
      case "CONTACTO 1":
        _recentContactoSearches = currentList;
        await prefs.setStringList('recent_contacto', currentList);
        break;
      case "NOMBRE COMPLETO":
        _recentNombreSearches = currentList;
        await prefs.setStringList('recent_nombre', currentList);
        break;
    }
    setState(() {});
  }

  List<String> _getRecentSearches() {
    switch (_selectedField) {
      case "CEDULA":
        return _recentCedulaSearches;
      case "CONTACTO 1":
        return _recentContactoSearches;
      case "NOMBRE COMPLETO":
        return _recentNombreSearches;
      default:
        return [];
    }
  }

  String _formatSyncTime(DateTime syncTime) {
    DateTime now = DateTime.now();
    Duration difference = now.difference(syncTime);
    
    if (difference.inDays == 0) {
      return "Hoy ${syncTime.hour.toString().padLeft(2, '0')}:${syncTime.minute.toString().padLeft(2, '0')}";
    } else if (difference.inDays == 1) {
      return "Ayer ${syncTime.hour.toString().padLeft(2, '0')}:${syncTime.minute.toString().padLeft(2, '0')}";
    } else if (difference.inDays < 7) {
      List<String> days = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
      return "${days[syncTime.weekday - 1]} ${syncTime.hour.toString().padLeft(2, '0')}:${syncTime.minute.toString().padLeft(2, '0')}";
    } else {
      return "${syncTime.day}/${syncTime.month} ${syncTime.hour.toString().padLeft(2, '0')}:${syncTime.minute.toString().padLeft(2, '0')}";
    }
  }

  Future<void> _search() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    await _saveRecentSearch(input);
    setState(() {
      _showSuggestions = false;
    });

    List<Map<String, dynamic>> results;
    if (_selectedField == "NOMBRE COMPLETO") {
      results = await DBHelper.queryByName(input);
    } else {
      final field = _selectedField == "CONTACTO 1" ? '"CONTACTO 1"' : _selectedField;
      results = await DBHelper.queryData(field, input);
    }

    // Apply filters
    if (_selectedComunidad != null) {
      results = results.where((record) => 
        record['COMUNIDAD']?.toString().toLowerCase() == _selectedComunidad!.toLowerCase()
      ).toList();
    }
    
    if (_selectedEstado != null) {
      results = results.where((record) => 
        record['ESTADO']?.toString().toLowerCase() == _selectedEstado!.toLowerCase()
      ).toList();
    }

    setState(() {
      _results = results;
      _hasQueried = true;
      _showingMultipleResults = results.length > 1;
      
      if (results.length == 1) {
        _selectedRecord = results[0];
        _estado = results[0]['ESTADO'];
      } else {
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
      await DBHelper.updateDatabase();
      
      if (_hasUnsyncedComments) {
        await DBHelper.syncComments();
        await _checkUnsyncedComments();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Base de datos actualizada correctamente"),
          backgroundColor: Color(0xFF0092DD),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al actualizar la base de datos"),
          backgroundColor: Colors.red,
        ),
      );
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_sync_timestamp', DateTime.now().millisecondsSinceEpoch);
    await _loadLastSyncTime();
    setState(() => _isSyncing = false);
  }

  Future<void> _showAddCommentDialog() async {
    if (_selectedRecord == null) return;
    TextEditingController commentController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Añadir Comentario",
            style: TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w600),
          ),
          content: TextField(
            controller: commentController,
            decoration: InputDecoration(
              hintText: "Escribe tu comentario aquí...",
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF0092DD)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF0092DD), width: 2),
              ),
            ),
            maxLines: 4,
            minLines: 2,
            style: TextStyle(fontFamily: 'Montserrat'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                "Cancelar",
                style: TextStyle(color: Colors.grey, fontFamily: 'Montserrat'),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                String comment = commentController.text.trim().replaceAll('\n', ' ');
                if (comment.isNotEmpty) {
                  try {
                    await DBHelper.saveComment(_selectedRecord!, comment);
                    Navigator.of(context).pop();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Comentario añadido, recuerda sincronizar"),
                        backgroundColor: Color(0xFF0092DD),
                      ),
                    );
                    
                    await _checkUnsyncedComments();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Error al guardar comentario"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0092DD),
                foregroundColor: Colors.white,
              ),
              child: Text("Guardar", style: TextStyle(fontFamily: 'Montserrat')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCommentsDialog() async {
    List<Map<String, dynamic>> comments = await DBHelper.getUnsyncedComments();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                "Comentarios sin sincronizar",
                style: TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w600),
              ),
              content: Container(
                width: double.maxFinite,
                height: 400,
                child: comments.isEmpty 
                  ? Center(
                      child: Text(
                        "No hay comentarios sin sincronizar",
                        style: TextStyle(fontFamily: 'Montserrat'),
                      ),
                    )
                  : ListView.builder(
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return Card(
                          margin: EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comment['nombre'] ?? 'Sin nombre',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Fredoka',
                                    color: Color(0xFF0092DD),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Cédula: ${comment['cedula'] ?? 'N/A'}",
                                  style: TextStyle(fontSize: 12, fontFamily: 'Montserrat'),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  comment['comment'] ?? '',
                                  style: TextStyle(fontFamily: 'Montserrat'),
                                ),
                                SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit, size: 20, color: Color(0xFF0092DD)),
                                      onPressed: () => _editComment(comment, () async {
                                        comments = await DBHelper.getUnsyncedComments();
                                        setState(() {});
                                      }),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete, size: 20, color: Colors.red),
                                      onPressed: () async {
                                        await DBHelper.deleteComment(comment['filename']);
                                        comments = await DBHelper.getUnsyncedComments();
                                        setState(() {});
                                        await _checkUnsyncedComments();
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    "Cerrar",
                    style: TextStyle(fontFamily: 'Montserrat'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editComment(Map<String, dynamic> comment, VoidCallback onUpdated) async {
    TextEditingController editController = TextEditingController(text: comment['comment']);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Editar Comentario",
            style: TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w600),
          ),
          content: TextField(
            controller: editController,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF0092DD)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF0092DD), width: 2),
              ),
            ),
            maxLines: 4,
            minLines: 2,
            style: TextStyle(fontFamily: 'Montserrat'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                "Cancelar",
                style: TextStyle(color: Colors.grey, fontFamily: 'Montserrat'),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                String newComment = editController.text.trim().replaceAll('\n', ' ');
                if (newComment.isNotEmpty) {
                  await DBHelper.updateComment(comment['filename'], newComment);
                  Navigator.of(context).pop();
                  onUpdated();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0092DD),
                foregroundColor: Colors.white,
              ),
              child: Text("Guardar", style: TextStyle(fontFamily: 'Montserrat')),
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
              Expanded(
                child: Text(
                  "Comentarios sin sincronizar",
                  style: TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          content: Text(
            "Hay comentarios sin sincronizar. Conéctate a internet y toca el ícono de Sincronizar",
            style: TextStyle(fontFamily: 'Montserrat'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                "Entendido",
                style: TextStyle(fontFamily: 'Montserrat'),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getEstadoColor(String estado) {
    switch (estado.toLowerCase()) {
      case "caracterizado":
        return Color(0xFF954B97).withOpacity(0.1);
      case "encuestado":
        return Color(0xFF0092DD).withOpacity(0.1);
      case "preasignado":
        return Color(0xFFfdc533).withOpacity(0.1);
      case "inactivo":
        return Color(0xFFe94362).withOpacity(0.1);
      case "asignado":
        return Color(0xFF2fac66).withOpacity(0.1);
      default:
        return Colors.grey.shade200;
    }
  }

  Color _getEstadoTextColor(String estado) {
    switch (estado.toLowerCase()) {
      case "caracterizado":
        return Color(0xFF954B97);
      case "encuestado":
        return Color(0xFF0092DD);
      case "preasignado":
        return Color(0xFFfdc533);
      case "inactivo":
        return Color(0xFFe94362);
      case "asignado":
        return Color(0xFF2fac66);
      default:
        return Colors.black;
    }
  }

  Widget _buildFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: _showFilters
              ? Card(
                  key: ValueKey('filters'),
                  margin: EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      children: [
                        // Comunidad Dropdown (same as your code)
                        DropdownButtonFormField<String>(
                          value: _selectedComunidad,
                          decoration: InputDecoration(
                            labelText: 'Filtrar por Comunidad',
                            labelStyle: TextStyle(fontFamily: 'Montserrat', color: Color(0xFF0092DD)),
                            border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF0092DD))),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF0092DD), width: 2)),
                          ),
                          items: [
                            DropdownMenuItem(value: null, child: Text("Todas", style: TextStyle(fontFamily: 'Montserrat'))),
                            DropdownMenuItem(value: "Granizal", child: Text("Granizal", style: TextStyle(fontFamily: 'Montserrat'))),
                            DropdownMenuItem(value: "La Honda", child: Text("La Honda", style: TextStyle(fontFamily: 'Montserrat'))),
                            DropdownMenuItem(value: "La Nueva Jerusalén", child: Text("La Nueva Jerusalén", style: TextStyle(fontFamily: 'Montserrat'))),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedComunidad = value;
                            });
                          },
                        ),
                        SizedBox(height: 12),
                        // Estado Dropdown (same as your code)
                        DropdownButtonFormField<String>(
                          value: _selectedEstado,
                          decoration: InputDecoration(
                            labelText: 'Filtrar por Estado',
                            labelStyle: TextStyle(fontFamily: 'Montserrat', color: Color(0xFF0092DD)),
                            border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF0092DD))),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF0092DD), width: 2)),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text("Todos", style: TextStyle(fontFamily: 'Montserrat')),
                            ),
                            DropdownMenuItem(
                              value: "caracterizado",
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Color(0xFF954B97).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Text(
                                  "Caracterizado",
                                  style: TextStyle(fontFamily: 'Montserrat', color: Color(0xFF954B97), fontSize: 16),
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: "encuestado",
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Color(0xFF0092DD).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Text(
                                  "Encuestado",
                                  style: TextStyle(fontFamily: 'Montserrat', color: Color(0xFF0092DD), fontSize: 16),
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: "preasignado",
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Color(0xFFFDC533).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Text(
                                  "Preasignado",
                                  style: TextStyle(fontFamily: 'Montserrat', color: Color(0xFFFDC533), fontSize: 16),
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: "asignado",
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Color(0xFF2FAC66).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Text(
                                  "Asignado",
                                  style: TextStyle(fontFamily: 'Montserrat', color: Color(0xFF2FAC66), fontSize: 16),
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: "inactivo",
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Color(0xFFE94362).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Text(
                                  "Inactivo",
                                  style: TextStyle(fontFamily: 'Montserrat', color: Color(0xFFE94362), fontSize: 16),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedEstado = value;
                            });
                          },

                          // ✅ Fixes the selected item rendering
                          selectedItemBuilder: (context) {
                            return [
                              Text("Todos", style: TextStyle(fontFamily: 'Montserrat')),
                              Text("Caracterizado", style: TextStyle(fontFamily: 'Montserrat', color: Color(0xFF954B97))),
                              Text("Encuestado", style: TextStyle(fontFamily: 'Montserrat', color: Color(0xFF0092DD))),
                              Text("Preasignado", style: TextStyle(fontFamily: 'Montserrat', color: Color(0xFFFDC533))),
                              Text("Asignado", style: TextStyle(fontFamily: 'Montserrat', color: Color(0xFF2FAC66))),
                              Text("Inactivo", style: TextStyle(fontFamily: 'Montserrat', color: Color(0xFFE94362))),
                            ];
                          },
                        ),

                      ],
                    ),
                  ),
                )
              : SizedBox.shrink(key: ValueKey('empty')),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    List<Widget> chips = [];
    
    if (_selectedComunidad != null) {
      chips.add(
        Chip(
          label: Text(
            'Comunidad: $_selectedComunidad',
            style: TextStyle(fontFamily: 'Montserrat', fontSize: 12),
          ),
          backgroundColor: Color(0xFF0092DD).withOpacity(0.1),
          deleteIcon: Icon(Icons.close, size: 16),
          onDeleted: () {
            setState(() {
              _selectedComunidad = null;
            });
          },
        ),
      );
    }
    
    if (_selectedEstado != null) {
      chips.add(
        Chip(
          label: Text(
            'Estado: $_selectedEstado',
            style: TextStyle(fontFamily: 'Montserrat', fontSize: 12),
          ),
          backgroundColor: _getEstadoColor(_selectedEstado!),
          deleteIcon: Icon(Icons.close, size: 16),
          onDeleted: () {
            setState(() {
              _selectedEstado = null;
            });
          },
        ),
      );
    }
    
    if (chips.isEmpty) return SizedBox.shrink();
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: chips,
      ),
    );
  }

  Widget _buildHighlightedText(String fullText, String searchTerm, TextStyle style) {
    if (searchTerm.isEmpty) {
      return Text(fullText, style: style);
    }

    String normalizedFull = DBHelper.normalizeString(fullText);
    String normalizedSearch = DBHelper.normalizeString(searchTerm);

    int index = normalizedFull.indexOf(normalizedSearch);
    if (index == -1) {
      return Text(fullText, style: style);
    }

    return RichText(
      text: TextSpan(
        style: style,
        children: [
          if (index > 0)
            TextSpan(text: fullText.substring(0, index)),
          TextSpan(
            text: fullText.substring(index, index + searchTerm.length),
            style: style.copyWith(
              color: Colors.black, // darker for contrast
              fontWeight: FontWeight.w800, // heavier than default bold
              fontSize: style.fontSize != null ? style.fontSize! + 1 : null,
            ),
          ),
          if (index + searchTerm.length < fullText.length)
            TextSpan(text: fullText.substring(index + searchTerm.length)),
        ],
      ),
    );
  }


  Widget _buildMultipleResultsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Se encontraron ${_results.length} resultados:",
          style: TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.bold,
            fontFamily: 'Fredoka',
            color: Color(0xFF0092DD),
          ),
        ),
        SizedBox(height: 12),
        ...List.generate(_results.length, (index) {
          final record = _results[index];
          return Card(
            margin: EdgeInsets.only(bottom: 8),
            elevation: 2,
            child: ListTile(
              title: _buildHighlightedText(
                record['NOMBRE COMPLETO']?.toString() ?? 'Sin nombre',
                _selectedField == "NOMBRE COMPLETO" ? _controller.text.trim() : "",
                TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Fredoka',
                  color: Color(0xFF0092DD),
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comunidad: ${record['COMUNIDAD']?.toString() ?? 'N/A'}',
                    style: TextStyle(fontFamily: 'Montserrat'),
                  ),
                  Text(
                    'Cédula: ${record['CEDULA']?.toString() ?? 'N/A'}',
                    style: TextStyle(fontFamily: 'Montserrat'),
                  ),
                ],
              ),
              trailing: Icon(Icons.arrow_forward_ios, color: Color(0xFF0092DD)),
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
        child: Text(
          "No se encontraron resultados.",
          style: TextStyle(fontFamily: 'Montserrat'),
        ),
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
        if (_results.length > 1)
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: ElevatedButton.icon(
              onPressed: _backToResults,
              icon: Icon(Icons.arrow_back),
              label: Text(
                "Volver a resultados",
                style: TextStyle(fontFamily: 'Montserrat'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.black87,
              ),
            ),
          ),
        
        if (_estado != null)
          Container(
            padding: EdgeInsets.all(16),
            margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _getEstadoColor(_estado!),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFF0092DD).withOpacity(0.3)),
            ),
            child: Text(
              "ESTADO: $_estado",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _getEstadoTextColor(_estado!),
                fontFamily: 'Fredoka',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        
        Container(
          margin: EdgeInsets.only(bottom: 12),
          child: ElevatedButton.icon(
            onPressed: _showAddCommentDialog,
            icon: Icon(Icons.comment_outlined),
            label: Text(
              "Añadir Comentario",
              style: TextStyle(fontFamily: 'Montserrat'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF0092DD),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        
        ...data.entries.map((entry) {
          if (entry.key == "ESTADO") return SizedBox.shrink();
          return Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xFF0092DD).withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    "${entry.key}:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Fredoka',
                      color: Color(0xFF0092DD),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Text(
                    "${entry.value ?? '-'}",
                    style: TextStyle(
                      color: Colors.black87,
                      fontFamily: 'Montserrat',
                    ),
                  ),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Consulta de Registros",
              style: TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w600),
            ),
            if (_lastSyncTime != null)
              Text(
                "Última sync: ${_formatSyncTime(_lastSyncTime!)}",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w300),
              ),
          ],
        ),
        backgroundColor: Color(0xFF0092DD),
        foregroundColor: Colors.white,
        actions: [
          if (_hasUnsyncedComments) ...[
            IconButton(
              icon: Icon(Icons.warning, color: Colors.orange),
              tooltip: "Comentarios sin sincronizar",
              onPressed: _showUnsyncedWarning,
            ),
            IconButton(
              icon: Icon(Icons.comment_outlined),
              tooltip: "Ver comentarios",
              onPressed: _showCommentsDialog,
            ),
          ],
          IconButton(
            icon: _isSyncing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                      strokeWidth: 2,
                    ),
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
              _buildFilterSection(),
              _buildFilterChips(),
              DropdownButtonFormField<String>(
                value: _selectedField,
                decoration: InputDecoration(
                  labelText: 'Buscar por',
                  labelStyle: TextStyle(fontFamily: 'Montserrat', color: Color(0xFF0092DD)),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF0092DD)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF0092DD), width: 2),
                  ),
                ),
                style: TextStyle(fontFamily: 'Montserrat', color: Colors.black),
                items: [
                  DropdownMenuItem(
                    value: "CEDULA", 
                    child: Text("CÉDULA", style: TextStyle(fontFamily: 'Montserrat')),
                  ),
                  DropdownMenuItem(
                    value: "CONTACTO 1", 
                    child: Text("CONTACTO (Celular)", style: TextStyle(fontFamily: 'Montserrat')),
                  ),
                  DropdownMenuItem(
                    value: "NOMBRE COMPLETO", 
                    child: Text("NOMBRE", style: TextStyle(fontFamily: 'Montserrat')),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedField = value!;
                  });
                },
              ),
              SizedBox(height: 20),
              
              // Replace the existing TextField with this:
              Column(
                children: [
                  TextField(
                    controller: _controller,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      labelText: _selectedField == "CEDULA" 
                          ? 'Ingrese número de cédula'
                          : _selectedField == "CONTACTO 1"
                          ? 'Ingrese número de celular'
                          : 'Ingrese nombre (búsqueda parcial)',
                      labelStyle: TextStyle(fontFamily: 'Montserrat', color: Color(0xFF0092DD)),
                      contentPadding: EdgeInsets.fromLTRB(12, 20, 12, 12),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF0092DD)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF0092DD), width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF0092DD)),
                      ),
                      suffixIcon: _controller.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                setState(() {
                                  _controller.clear();
                                  _showSuggestions = false;
                                });
                              },
                            )
                          : null,
                    ),
                    style: TextStyle(fontFamily: 'Montserrat'),
                    keyboardType: _selectedField == "NOMBRE COMPLETO" 
                        ? TextInputType.text 
                        : TextInputType.number,
                    onSubmitted: (_) => _search(),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                  
                  // Suggestions as a separate widget below the TextField
                  if (_showSuggestions && _getRecentSearches().isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(top: 4),
                      constraints: BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _getRecentSearches().length,
                        itemBuilder: (context, index) {
                          final suggestion = _getRecentSearches()[index];
                          return ListTile(
                            dense: true,
                            leading: Icon(Icons.history, size: 16, color: Colors.grey),
                            title: Text(
                              suggestion,
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 14,
                              ),
                            ),
                            onTap: () {
                              _controller.text = suggestion;
                              setState(() {
                                _showSuggestions = false;
                              });
                              _search();
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),

              SizedBox(height: 16),
              Row(
                children: [
                  // Buscar button takes most of the space
                  Expanded(
                    flex: 9,
                    child: ElevatedButton(
                      onPressed: _search,
                      child: Text(
                        'Buscar',
                        style: TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0092DD),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  SizedBox(width: 8), // spacing between button and icon
                  // Filter icon on the right
                  IconButton(
                    icon: Icon(
                      _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                      color: _areFiltersActive() ? Color(0xFF0066AA) : Color(0xFF0092DD),
                    ),
                    tooltip: "Mostrar filtros",
                    onPressed: () {
                      setState(() {
                        _showFilters = !_showFilters;
                      });
                    },
                  ),
                ],
              ),

              SizedBox(height: 20),
              _buildResultTable(),
            ],
          ),
        ),
      ),
    );
  }
}