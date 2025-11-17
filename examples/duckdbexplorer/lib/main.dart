import 'dart:async';

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DuckDB Explorer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SqlExecutorPage(),
    );
  }
}

class SqlExecutorPage extends StatefulWidget {
  @override
  _SqlExecutorPageState createState() => _SqlExecutorPageState();
}

typedef QueryResponse = ({
  List<String>? columns,
  List<List<Object?>>? rows,
  int totalRows,
});

class _SqlExecutorPageState extends State<SqlExecutorPage> {
  final _sqlController = TextEditingController();
  final _executionTimeController = TextEditingController();
  final _totalRowCountController = TextEditingController();
  final _currentPageController = TextEditingController();
  final _horizontalScrollController = ScrollController();
  final _verticalScrollController = ScrollController();

  Database? _database;
  Connection? _connection;
  List<String> _columnNames = [];
  List<List<dynamic>> _rows = [];
  int _limit = 10;
  int _offset = 0;
  int _totalRows = 0;

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _openInMemoryDatabase();
  }

  Future<void> _openInMemoryDatabase() async {
    _database = await duckdb.open(':memory:');
    _connection = await duckdb.connect(_database!);
    setState(() {});
  }

  Future<void> _openDatabase() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null) {
      final file = result.files.first;

      // Close the existing database and connection
      _connection?.dispose();
      _database?.dispose();

      if (kIsWeb) {
        _database = await duckdb.open('opfs://db.db', settings: {
          'access_mode': 'READ_WRITE',
        });
        await _database!.registerFileBuffer(file.name!, file.bytes!);
      } else {
        _database = await duckdb.open(file.path!);
      }

      _connection = await duckdb.connect(_database!);

      if (kIsWeb) {
        await _connection!.execute(
          "ATTACH '${file.name}' AS remote (READ_ONLY);",
        );
      }

      setState(() {});
    }
  }

  Future<void> _executeQuery({bool resetOffset = true}) async {
    if (_connection != null && _sqlController.text.isNotEmpty) {
      try {
        if (resetOffset) {
          _offset = 0;
        }

        final stopwatch = Stopwatch()..start();
        String query = _sqlController.text.trim();
        // Remove trailing semicolons
        query = query.replaceAll(RegExp(r';+$'), '');

        String countQuery = '';
        if (query.toLowerCase().startsWith('select')) {
          countQuery = 'SELECT COUNT(*) FROM ($query) AS count_query';
          query += ' LIMIT $_limit OFFSET $_offset';
        }

        // Execute the main query
        final results = await _connection?.query(query);
        final columns = results?.columnNames;
        final rows = results?.fetchAll();

        // Execute count query if needed
        int totalRows = 0;
        if (countQuery.isNotEmpty) {
          final countResults = await _connection?.query(countQuery);
          final count = countResults?.fetchAll();
          if (count?.first.first != null) {
            var countValue = count!.first.first;
            if (countValue is int) {
              totalRows = countValue;
            } else if (countValue is BigInt) {
              totalRows = countValue.toInt();
            }
          }
        }

        setState(() {
          _columnNames = columns ?? [];
          _rows = rows ?? [[]];
          _totalRows = totalRows;
          stopwatch.stop();
          _executionTimeController.text = '${stopwatch.elapsedMilliseconds} ms';
          _totalRowCountController.text = 'Total: $_totalRows';
          _currentPageController.text =
              'Page: ${(_offset / _limit).ceil() + 1}';
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _loadNextPage() async {
    setState(() {
      _offset += _limit;
    });
    await _executeQuery(resetOffset: false);
  }

  Future<void> _loadPreviousPage() async {
    setState(() {
      _offset = (_offset - _limit).clamp(0, _offset);
    });
    await _executeQuery(resetOffset: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('DuckDB Explorer'),
        actions: [
          IconButton(
            icon: Icon(Icons.folder_open),
            onPressed: _openDatabase,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _sqlController,
              decoration: InputDecoration(
                labelText: 'Enter SQL Query',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ),
          ElevatedButton(
            onPressed: _executeQuery,
            child: Text('Run SQL'),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _executionTimeController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Execution Time',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _totalRowCountController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Total Rows',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _currentPageController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Current Page',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildResultsTable(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: _offset > 0 ? _loadPreviousPage : null,
                child: Text('Previous'),
              ),
              ElevatedButton(
                onPressed: _rows.length == _limit ? _loadNextPage : null,
                child: Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsTable() {
    if (_columnNames.isEmpty) {
      return Center(child: Text('No results to display.'));
    }

    List<DataColumn> columns =
        _columnNames.map((key) => DataColumn(label: Text(key))).toList();

    List<DataRow> rows = _rows.map((row) {
      // Create a cell for each column
      return DataRow(
        cells: row.map((value) {
          String displayValue = value?.toString() ?? 'NULL';
          return DataCell(Text(displayValue));
        }).toList(),
      );
    }).toList();

    return Scrollbar(
      controller: _verticalScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalScrollController,
        scrollDirection: Axis.vertical,
        child: Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: DataTable(columns: columns, rows: rows),
          ),
        ),
      ),
    );
  }
}
