import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/models/order.dart';
import 'package:latlong2/latlong.dart';

void main() {
  // Duz bir hat: batidan doguya bes nokta.
  const route = [
    LatLng(37.90, 58.30),
    LatLng(37.90, 58.31),
    LatLng(37.90, 58.32),
    LatLng(37.90, 58.33),
    LatLng(37.90, 58.34),
  ];
  const destination = LatLng(37.90, 58.34);

  test('kuryenin gectigi kisim cizilmiyor', () {
    final line = remainingRoute(
      route: route,
      destination: destination,
      courier: const LatLng(37.9001, 58.325), // ucuncu noktanin yaninda
    );
    expect(line.first, const LatLng(37.9001, 58.325), reason: 'hat kuryeden baslamali');
    expect(line.last, destination);
    // Gecilen ilk iki nokta dusmeli.
    expect(line.contains(const LatLng(37.90, 58.30)), isFalse);
    expect(line.contains(const LatLng(37.90, 58.31)), isFalse);
  });

  test('kurye yola yeni ciktiysa hat neredeyse tam kaliyor', () {
    final line = remainingRoute(
      route: route,
      destination: destination,
      courier: const LatLng(37.90, 58.301),
    );
    expect(line.length, route.length + 1); // kurye + tum rota
    expect(line.last, destination);
  });

  test('rota henuz gelmediyse duz hat ciziliyor', () {
    final line = remainingRoute(
      route: const [],
      destination: destination,
      courier: const LatLng(37.91, 58.29),
    );
    expect(line, [const LatLng(37.91, 58.29), destination]);
  });

  test('kurye gorunmuyorsa varsa rota, yoksa bos', () {
    expect(
      remainingRoute(route: route, destination: destination),
      route,
    );
    expect(
      remainingRoute(route: const [], destination: destination),
      isEmpty,
    );
  });
}
