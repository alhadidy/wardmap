import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardmap/floor_plan.dart';

void main() {
  test('map labels get an icon from their name', () {
    expect(
      PlanFixture.iconFor('Nurse station'),
      Icons.medical_services_outlined,
    );
    expect(PlanFixture.iconFor('WC'), Icons.wc);
    expect(
      PlanFixture.iconFor('Main entrance'),
      Icons.door_front_door_outlined,
    );
    expect(PlanFixture.iconFor('Something else'), Icons.place_outlined);
  });
}
