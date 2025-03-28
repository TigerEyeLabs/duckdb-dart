import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:test/test.dart';

void main() {
  late Database database;
  late Connection connection;

  setUp(() async {
    database = await duckdb.open(":memory:");
    connection = await duckdb.connect(database);
  });

  tearDown(() async {
    await connection.dispose();
    await database.dispose();
  });

  test('simple struct', () async {
    final results = (await connection
            .query("SELECT {int_field: 5, varchar_field: 'foo'} as struct"))
        .fetchAll();

    final struct = results[0][0]! as Map<String, dynamic>;
    expect(struct['int_field'], 5);
    expect(struct['varchar_field'], 'foo');
  });

  test('multiple rows', () async {
    final results = (await connection.query(
      "SELECT {int_field: range, varchar_field: 'foo'} as struct FROM RANGE(1, 3)",
    ))
        .fetchAll();

    final struct1 = results[0][0]! as Map<String, dynamic>;
    final struct2 = results[1][0]! as Map<String, dynamic>;
    expect(struct1['int_field'], 1);
    expect(struct1['varchar_field'], 'foo');
    expect(struct2['int_field'], 2);
    expect(struct2['varchar_field'], 'foo');
  });

  test('nested struct', () async {
    final results = (await connection.query(
      "SELECT {int_field: 5, nested_struct: {value1: 24, value2: 42}} as struct",
    ))
        .fetchAll();

    final struct = results[0][0]! as Map<String, dynamic>;
    expect(struct['int_field'], 5);

    final nestedStruct = struct['nested_struct'] as Map<String, dynamic>;
    expect(nestedStruct['value1'], 24);
    expect(nestedStruct['value2'], 42);
  });

  test('Struct of structs with NULL values', () async {
    final results = (await connection.query(
      """
        SELECT [{'birds':
            {'yes': 'duck', 'maybe': 'goose', 'huh': NULL, 'no': 'heron'},
        'aliens':
            NULL,
        'amphibians':
            {'yes':'frog', 'maybe': 'salamander', 'huh': 'dragon', 'no':'toad'}
        },{'birds':
            {'yes': 'monkey', 'maybe': 'cat', 'huh': NULL, 'no': 'sparrow'},
        'aliens':
            NULL,
        'amphibians':
            {'yes':'frog', 'maybe': 'salamander', 'huh': 'dragon', 'no':'toad'}
        }];
      """,
    ))
        .fetchAll();

    expect(results[0][0], [
      {
        'birds': {
          'yes': 'duck',
          'maybe': 'goose',
          'huh': null,
          'no': 'heron',
        },
        'aliens': null,
        'amphibians': {
          'yes': 'frog',
          'maybe': 'salamander',
          'huh': 'dragon',
          'no': 'toad',
        },
      },
      {
        'birds': {
          'yes': 'monkey',
          'maybe': 'cat',
          'huh': null,
          'no': 'sparrow',
        },
        'aliens': null,
        'amphibians': {
          'yes': 'frog',
          'maybe': 'salamander',
          'huh': 'dragon',
          'no': 'toad',
        },
      }
    ]);
  });

  test('Struct of lists of structs of lists of structs', () async {
    final results = (await connection.query(
      """
      SELECT [
            {'column_name': 'close_date', 'column_title': NULL, 'old_value': '2024-11-01', 'another_value': '2024-10-31'},
            {'column_name': 'stage_name', 'column_title': NULL, 'old_value': 'Proposal', 'another_value': 'Closed Won'},
            {'column_name': 'Gross_New__c', 'column_title': NULL, 'old_value': '25000.0', 'another_value': '10000.0'},
            {'column_name': 'amount', 'column_title': NULL, 'old_value': '25000.0', 'another_value': '10000.0'},
            {'column_name': 'close_date', 'column_title': NULL, 'old_value': '2024-11-29', 'another_value': '2024-11-01'},
            {'column_name': 'next_step_date', 'column_title': NULL, 'old_value': '2024-08-30', 'another_value': '2024-11-01'},
            {'column_name': 'next_step_details', 'column_title': NULL, 'old_value': 'follow up demo w/ Janis and Jim', 'another_value': 'signature'},
            {'column_name': 'Status__c', 'column_title': NULL, 'old_value': NULL, 'another_value': 'To Be Connected'},
            {'column_name': 'next_step_details', 'column_title': NULL, 'old_value': 'follow up demo w/ Janis and JJim', 'another_value': 'signature'},
        ];
        """,
    ))
        .fetchAll();

    expect(results[0][0], [
      {
        'column_name': 'close_date',
        'column_title': null,
        'old_value': '2024-11-01',
        'another_value': '2024-10-31',
      },
      {
        'column_name': 'stage_name',
        'column_title': null,
        'old_value': 'Proposal',
        'another_value': 'Closed Won',
      },
      {
        'column_name': 'Gross_New__c',
        'column_title': null,
        'old_value': '25000.0',
        'another_value': '10000.0',
      },
      {
        'column_name': 'amount',
        'column_title': null,
        'old_value': '25000.0',
        'another_value': '10000.0',
      },
      {
        'column_name': 'close_date',
        'column_title': null,
        'old_value': '2024-11-29',
        'another_value': '2024-11-01',
      },
      {
        'column_name': 'next_step_date',
        'column_title': null,
        'old_value': '2024-08-30',
        'another_value': '2024-11-01',
      },
      {
        'column_name': 'next_step_details',
        'column_title': null,
        'old_value': 'follow up demo w/ Janis and Jim',
        'another_value': 'signature',
      },
      {
        'column_name': 'Status__c',
        'column_title': null,
        'old_value': null,
        'another_value': 'To Be Connected',
      },
      {
        'column_name': 'next_step_details',
        'column_title': null,
        'old_value': 'follow up demo w/ Janis and JJim',
        'another_value': 'signature',
      }
    ]);
  });
}
