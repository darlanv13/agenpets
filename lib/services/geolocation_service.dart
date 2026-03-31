import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class GeolocationService {
  Future<Position> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Serviço de localização desativado.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Permissão de localização negada.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
        'Permissão de localização negada permanentemente. Ative nas configurações.'
      );
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition();
  }

  Future<String?> getAddressFromPosition(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        // Monta o endereço: Rua, Número - Bairro
        String endereco = "";

        if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) {
          endereco += place.thoroughfare!;
        }

        if (place.subThoroughfare != null && place.subThoroughfare!.isNotEmpty) {
           if (endereco.isNotEmpty) endereco += ", ";
           endereco += place.subThoroughfare!;
        }

        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
           if (endereco.isNotEmpty) endereco += " - ";
           endereco += place.subLocality!;
        }

        // Se ainda estiver vazio, tenta usar locality (Cidade)
        if (endereco.isEmpty && place.locality != null) {
            endereco = place.locality!;
        }

        return endereco.isNotEmpty ? endereco : null;
      }
      return null;
    } catch (e) {
      print("Erro ao converter coordenadas em endereço: $e");
      return null;
    }
  }
}
