import 'dart:async';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:file_picker/file_picker.dart';

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
  List<String> columns,
  List<List<dynamic>> rows,
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

  void _openInMemoryDatabase() {
    _database = duckdb.open(':memory:');
    _connection = duckdb.connect(_database!);
    setState(() {});
  }

  Future<void> _openDatabase() async {
    String? filePath = await FilePicker.platform
        .pickFiles(
          type: FileType.any,
        )
        .then((result) => result?.files.single.path);

    if (filePath != null) {
      // Close the existing database and connection
      _connection?.dispose();
      _database?.dispose();

      _database = duckdb.open(filePath);
      _connection = duckdb.connect(_database!);
      setState(() {});
    }
  }

  Future<void> _executeQuery({bool resetOffset = true}) async {
    if (_connection != null && _sqlController.text.isNotEmpty) {
      try {
        if (resetOffset) {
          _offset = 0;
        }

        final completer = Completer<void>();
        final receivePort = ReceivePort();

        final stopwatch = Stopwatch()..start();

        String query = _sqlController.text.trim();
        query =
            query.replaceAll(RegExp(r';+$'), ''); // Remove trailing semicolons

        String countQuery = '';
        if (query.toLowerCase().startsWith('select')) {
          countQuery = 'SELECT COUNT(*) FROM (${query}) AS count_query';
          query += " LIMIT $_limit OFFSET $_offset";
        }

        await Isolate.spawn(
          _backgroundQueryTask,
          _QueryTaskParams(
            transferableDb: _database!.transferrable,
            query: query,
            countQuery: countQuery,
            sendPort: receivePort.sendPort,
          ),
        );

        receivePort.listen((dynamic message) {
          if (message is QueryResponse) {
            setState(() {
              _columnNames = message.columns;
              _rows = message.rows;
              _totalRows = message.totalRows;
              stopwatch.stop();
              _executionTimeController.text =
                  '${stopwatch.elapsedMilliseconds} ms';
              _totalRowCountController.text = 'Total: $_totalRows';
              _currentPageController.text =
                  'Page: ${(_offset / _limit).ceil() + 1}';
            });
            completer.complete();
          } else if (message is String) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $message')),
            );
            completer.completeError(message);
          }
        });

        await completer.future;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  static void _backgroundQueryTask(_QueryTaskParams params) {
    try {
      final connection = duckdb.connectWithTransferred(params.transferableDb);
      final results = connection.query(params.query);
      final columns = results.columnNames;
      final rows = results.fetchAll();

      int totalRows = 0;
      if (params.countQuery.isNotEmpty) {
        final countResults = connection.query(params.countQuery);
        totalRows = countResults.fetchAll().first.first as int;
      }

      params.sendPort.send((
        columns: columns,
        rows: rows,
        totalRows: totalRows,
      ));
    } catch (e) {
      params.sendPort.send(e.toString());
    }
  }

  void _loadNextPage() {
    setState(() {
      _offset += _limit;
    });
    _executeQuery(resetOffset: false);
  }

  void _loadPreviousPage() {
    setState(() {
      _offset = (_offset - _limit).clamp(0, _offset);
    });
    _executeQuery(resetOffset: false);
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
      return DataRow(
        cells: row.map((value) => DataCell(Text(value.toString()))).toList(),
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

class _QueryTaskParams {
  final TransferableDatabase transferableDb;
  final String query;
  final String countQuery;
  final SendPort sendPort;

  _QueryTaskParams({
    required this.transferableDb,
    required this.query,
    required this.countQuery,
    required this.sendPort,
  });
}
