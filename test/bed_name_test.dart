import 'package:flutter_test/flutter_test.dart';
import 'package:wardmap/ui.dart';

void main() {
  Map<String, dynamic> bed(String label, String roomId, String room) => {
    'label': label,
    'room_id': roomId,
    'rooms': {'name': room},
  };

  test('bed name leaves the room out when there is only one', () {
    final beds = [bed('1', 'a', 'Room 1'), bed('2', 'a', 'Room 1')];
    expect(bedName(beds.first, beds), 'Bed 1');
  });

  test('bed name adds the room when beds span several rooms', () {
    final beds = [bed('1', 'a', 'Room 1'), bed('5', 'b', 'Side room')];
    expect(bedName(beds.last, beds), 'Bed 5 · Side room');
  });
}
