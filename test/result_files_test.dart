import 'package:flutter_test/flutter_test.dart';
import 'package:wardmap/record_sections.dart';
import 'package:wardmap/screens/result_files_view.dart';

void main() {
  test('results load their file count', () {
    final results = recordSections.firstWhere((s) => s.table == 'results');
    expect(results.columns, contains('result_files(count)'));
  });

  test('file count on a result row', () {
    expect(
      ResultFilesSheet.countOn({
        'result_files': [
          {'count': 3},
        ],
      }),
      3,
    );
    expect(ResultFilesSheet.countOn({'result_files': []}), 0);
    expect(ResultFilesSheet.countOn({}), 0);
  });
}
