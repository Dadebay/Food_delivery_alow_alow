import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/data/order_repository.dart';
import 'package:food_delivery/core/network/api_client.dart';

void main() {
  test('seeded orders keep destination, branch and courier points distinct', () async {
    final repo = OrderRepository(api: ApiClient());
    final orders = await repo.orders();

    for (final o in orders) {
      expect(o.branchPoint, isNotNull, reason: 'order ${o.id} should have a branch point');
      expect(
        o.address.point,
        isNot(equals(o.branchPoint)),
        reason: 'order ${o.id}: destination pin must not sit on the branch coordinate',
      );
      if (o.courierPoint != null) {
        expect(
          o.courierPoint,
          isNot(equals(o.address.point)),
          reason: 'order ${o.id}: courier marker must not sit on the destination pin',
        );
      }
    }
  });
}
