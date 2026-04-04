import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import '../../../core/network/api_client.dart';

class HomeService {
  final ApiClient _api = ApiClient();
  PusherChannelsClient? _client;
  final Map<String, PrivateChannel> _activeTripChannels = {};
  Future<Map<String, dynamic>?> getActiveTrip() async {
    try {
      final response = await _api.dio.get('/viajes/activo');
      if (response.data != null && response.data['status'] == 'success') {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Lógica de Socket para el Usuario
  void initUserSocket({
    required String userId,
    required String token,
    required Function(String event, Map<String, dynamic> data) onEvent,
  }) {
    _client = PusherChannelsClient.websocket(
      options: PusherChannelsOptions.fromHost(
        scheme: 'ws',
        host: '192.168.10.3',
        port: 8080,
        key: '06exymiubefjjglwmvqe',
      ),
      // CORRECCIÓN: Manejador de errores obligatorio en v1.3.1
      connectionErrorHandler: (exception, trace, client) {
        debugPrint("Socket Error: $exception");
      },
    );

    _client!.eventStream.listen((event) {
      if (event.name == 'pusher:connection_established') {
        final channel = _client!.privateChannel(
          'private-usuario.$userId',
          // CORRECCIÓN: Usar clase delegada personalizada
          authorizationDelegate: UserPusherAuth(token: token),
        );
        channel.subscribe();
        channel.bind('ViajeAceptado').listen((e) {
          if (e.data != null) onEvent('ViajeAceptado', json.decode(e.data!));
        });
      }
    });
    _client!.connect();
  }

  void unsubscribeFromTrip(String tripId) {
    final channelName = 'private-viaje.$tripId';

    // Buscamos el canal en nuestro mapa
    if (_activeTripChannels.containsKey(channelName)) {
      _activeTripChannels[channelName]!.unsubscribe(); // Cortamos la conexión
      _activeTripChannels.remove(channelName); // Limpiamos el mapa
      debugPrint("🛑 Tracking detenido para el viaje: $tripId");
    }
  }

  // Escuchar el GPS específico del viaje
  void subscribeToTripTracking(
    String tripId,
    String token,
    Function(double lat, double lng) onLocation,
  ) {
    final channelName = 'private-viaje.$tripId';

    // Creamos el canal
    final tripChannel = _client!.privateChannel(
      channelName,
      authorizationDelegate: UserPusherAuth(token: token),
    );

    // LO GUARDAMOS EN EL MAPA PARA PODER USARLO EN unsubscribeFromTrip
    _activeTripChannels[channelName] = tripChannel;

    tripChannel.subscribe();
    tripChannel.bind('PuntoTracking').listen((e) {
      if (e.data != null) {
        final data = json.decode(e.data!);
        onLocation(
          double.parse(data['lat'].toString()),
          double.parse(data['lng'].toString()),
        );
      }
    });
  }

  void dispose() {
    _client?.disconnect();
  }
}

class UserPusherAuth
    implements
        EndpointAuthorizableChannelAuthorizationDelegate<
          PrivateChannelAuthorizationData
        > {
  final String token;
  UserPusherAuth({required this.token});

  @override
  EndpointAuthFailedCallback? get onAuthFailed =>
      (exception, trace) => debugPrint("Auth Error: $exception");

  @override
  Future<PrivateChannelAuthorizationData> authorizationData(
    String socketId,
    String channelName,
  ) async {
    // Usamos la configuración de tu ApiClient
    final dio = ApiClient().dio;
    final response = await dio.post(
      'http://192.168.10.3:8000/api/broadcasting/auth',
      data: {'socket_id': socketId, 'channel_name': channelName},
    );
    return PrivateChannelAuthorizationData(
      authKey: response.data['auth'] ?? '',
    );
  }
}
