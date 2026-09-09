import 'package:daemon/src/features/relay/application/relay_control_service.dart';
import 'package:daemon/src/transport/rpc/binding.dart';
import 'package:protocol/protocol.dart';

/// Creates typed relay RPC bindings.
List<RpcBindingDescriptor> relayRpcBindings(
  RelayControlService relay,
) => <RpcBindingDescriptor>[
  RpcBinding<RelayEmptyParamsDto, RelayStatusDto>(
    relayStatusProcedure,
    (_, _) async => relayStatusToDto(relay.status),
  ),
  RpcBinding<RelaySetEnabledParamsDto, RelayStatusDto>(
    relaySetEnabledProcedure,
    (params, _) async =>
        relayStatusToDto(await relay.setEnabled(enabled: params.enabled)),
  ),
  RpcBinding<RelaySetEndpointParamsDto, RelayStatusDto>(
    relaySetEndpointProcedure,
    (params, _) async =>
        relayStatusToDto(await relay.setEndpoint(params.endpoint)),
  ),
  RpcBinding<RelayEmptyParamsDto, RelayPairingOfferDto>(
    relayCreateOfferProcedure,
    (_, _) async {
      final offer = relay.createOffer();
      return RelayPairingOfferDto(url: offer.url, expiresAt: offer.expiresAt);
    },
  ),
  RpcBinding<RelayEmptyParamsDto, RelayDeviceListDto>(
    relayListDevicesProcedure,
    (_, _) async => RelayDeviceListDto(
      devices: (await relay.listDevices())
          .map(
            (device) => RelayDeviceDto(
              id: device.id,
              name: device.name,
              registeredAt: device.registeredAt,
              lastConnectedAt: device.lastConnectedAt,
            ),
          )
          .toList(growable: false),
    ),
  ),
  RpcBinding<RelayRevokeDeviceParamsDto, EmptyResultDto>(
    relayRevokeDeviceProcedure,
    (params, _) async {
      await relay.revokeDevice(params.deviceId);
      return const EmptyResultDto();
    },
  ),
];

/// Maps application relay state at the protocol transport boundary.
RelayStatusDto relayStatusToDto(RelayStatus status) => RelayStatusDto(
  enabled: status.enabled,
  connected: status.connected,
  endpoint: status.endpoint,
  serverId: status.serverId,
);
