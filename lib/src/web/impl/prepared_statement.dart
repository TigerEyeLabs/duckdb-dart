part of 'implementation.dart';

class PreparedStatementImpl extends PreparedStatement {
  final bindings.PreparedStatement _statement;
  final _bindings = <int, Object?>{};

  PreparedStatementImpl({required bindings.PreparedStatement statement})
      : _statement = statement;

  @override
  void bind(Object? param, int index) {
    if (index <= 0) {
      throw RangeError.value(index, 'index', 'Index must be greater than 0');
    }
    _bindings[index] = param;
  }

  @override
  void bindNamed(Object? param, String name) {
    // TODO: implement bindNamed
  }

  @override
  void bindNamedParams(Map<String, Object?> params) {
    // TODO: implement bindNamedParams
  }

  @override
  void bindParams(List params) {
    clearBinding();
    for (var i = 0; i < params.length; i++) {
      _bindings[i + 1] = params[i];
    }
  }

  @override
  void clearBinding() {
    _bindings.clear();
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<ResultSet> execute({DuckDBCancellationToken? token}) async {
    final jsParams = List.generate(
      _bindings.length,
      (i) => _bindings[i + 1]?.jsifyValueStrict(),
    );

    // Check if already cancelled before starting
    if (token != null && token.isCancelled) {
      throw DuckDBCancelledException('Operation cancelled');
    }

    // Race between query execution and cancellation
    return Future.any<ResultSet>([
      // The actual query
      _statement.query(jsParams).toDart.then((table) => ResultSetImpl(table)),
      // Cancellation handler
      if (token != null)
        token.cancelled.then((_) {
          throw DuckDBCancelledException('Operation cancelled');
        }),
    ]);
  }

  @override
  Future<ResultSet?> executePending({
    DuckDBCancellationToken? token,
  }) {
    return execute(token: token);
  }

  @override
  int get parameterCount => _bindings.length;

  @override
  DatabaseType parameterType(int index) {
    return DatabaseTypeWeb.none;
  }
}
