///// https://github.com/simolus3/sqlite3.dart/blob/main/sqlite3/lib/src/implementation/finalizer.dart
const _debugFinalizers = false;

/// Some core part of a database, connection or statement that can be used to
/// dispose the entire element natively.
///
/// When registering a database or statement to a finalizer, we need to supply
/// the API object as a `value` so that it being unreachable triggers the
/// finalizer. In addition, we need to supply a `finalizationToken` to which we
/// hold a reference until finalization happens. This can't be the database
/// or statement object itself (because then the finalizer would reference it
/// and it'd never get GCed), so we extract just the functionality necessary to
/// dispose it into a [FinalizablePart] subclass and register that to the
/// finalizer.
///
/// Typically, such part may contain a pointer towards the native duckdb object
/// and bindings to invoke the C destructor.
/// It needs to be carefully designed to not accidentally cause references back
/// to API-level objects.
abstract class FinalizablePart {
  StackTrace? _creationTrace;

  FinalizablePart() {
    if (_debugFinalizers) {
      _creationTrace = StackTrace.current;
    }
  }

  void dispose();
}

final Finalizer<FinalizablePart> disposeFinalizer = Finalizer((element) {
  if (_debugFinalizers) {
    // ignore: avoid_print
    print('Auto-disposing $element, created at\n${element._creationTrace}');
  }

  element.dispose();
});
