import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/taxi_service.dart';
import '../../models/ride_models.dart';

class OnlineNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle(bool value) => state = value;
}

final isOnlineProvider =
    NotifierProvider<OnlineNotifier, bool>(() => OnlineNotifier());

final pendingRidesProvider = FutureProvider<List<Ride>>((ref) async {
  final driver = ref.watch(driverProfileProvider).asData?.value;
  final vehicleTypes = driver?.vehicleTypes;
  final rides =
      await TaxiService.getPendingRides(driverVehicleTypes: vehicleTypes);
  return rides.map((e) => Ride.fromJson(e)).toList();
});

final activeRideProvider = FutureProvider<Ride?>((ref) async {
  final ride = await TaxiService.getActiveRide();
  return ride != null ? Ride.fromJson(ride) : null;
});

final driverProfileProvider = FutureProvider<Driver?>((ref) async {
  final driver = await TaxiService.getDriverProfile();
  return driver != null ? Driver.fromJson(driver) : null;
});
