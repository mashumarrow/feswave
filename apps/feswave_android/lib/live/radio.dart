import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import '../profile/models.dart';
import 'protocol.dart';

final serviceId = UUID.fromString('610c0ca1-1541-4164-b568-c6c27807fda1');
final profileId = UUID.fromString('610c0ca2-1541-4164-b568-c6c27807fda1');
const pageSize = 384;

class LiveRadio {
  final central = CentralManager(), peripheral = PeripheralManager();
  final pages = <UUID, int>{};
  final sources = <int, Peripheral>{};
  final subscriptions = <StreamSubscription<dynamic>>[];
  bool advertising = false, scanning = false, serving = false;
  int localId = 0, revision = 0;
  Profile _profile = const Profile();
  void publish(Profile profile) {
    if (_profile == profile) return;
    _profile = profile;
    revision++;
  }

  LiveRadio(void Function(Signal, int) receive, void Function(String) failed) {
    subscriptions.add(
      central.discovered.listen((e) {
        final bytes = e.advertisement.serviceData[serviceId];
        if (bytes == null) return;
        final signal = Signal.decode(
          bytes,
          DateTime.now().millisecondsSinceEpoch ~/ slotMs,
        );
        if (signal == null || signal.id == localId) return;
        sources[signal.id] = e.peripheral;
        receive(signal, e.rssi);
      }),
    );
    subscriptions.add(
      central.stateChanged.listen((e) {
        if (e.state == BluetoothLowEnergyState.poweredOff) {
          failed('Bluetoothをオンにしてください');
        }
      }),
    );
    subscriptions.add(
      peripheral.characteristicWriteRequested.listen((e) async {
        final v = e.request.value;
        if (e.characteristic.uuid != profileId ||
            v.length != 1 ||
            e.request.offset != 0) {
          await peripheral.respondWriteRequestWithError(
            e.request,
            error: GATTError.invalidAttributeValueLength,
          );
          return;
        }
        pages[e.central.uuid] = v.first;
        await peripheral.respondWriteRequest(e.request);
      }),
    );
    subscriptions.add(
      peripheral.characteristicReadRequested.listen((e) async {
        final selector = pages[e.central.uuid] ?? 0;
        final page = selector & 0x7f;
        final public = _profile.publicView;
        final view = selector & 0x80 == 0
            ? public
            : public.copyWith(tracks: [?public.favorite]);
        final payload = utf8.encode(jsonEncode(view));
        final count = (payload.length + pageSize - 1) ~/ pageSize;
        if (e.characteristic.uuid != profileId ||
            page >= count ||
            count > 128) {
          await peripheral.respondReadRequestWithError(
            e.request,
            error: GATTError.invalidOffset,
          );
          return;
        }
        final header = ByteData(8)
          ..setUint32(0, localId)
          ..setUint16(4, revision & 65535)
          ..setUint8(6, page)
          ..setUint8(7, count);
        final result = Uint8List.fromList([
          ...header.buffer.asUint8List(),
          ...payload.sublist(
            page * pageSize,
            min(payload.length, (page + 1) * pageSize),
          ),
        ]);
        if (e.request.offset > result.length) {
          await peripheral.respondReadRequestWithError(
            e.request,
            error: GATTError.invalidOffset,
          );
          return;
        }
        await peripheral.respondReadRequestWithValue(
          e.request,
          value: result.sublist(e.request.offset),
        );
      }),
    );
  }
  Future<void> start(Signal signal) async {
    localId = signal.id;
    final characteristic = GATTCharacteristic.mutable(
      uuid: profileId,
      properties: [
        GATTCharacteristicProperty.read,
        GATTCharacteristicProperty.write,
      ],
      permissions: [
        GATTCharacteristicPermission.read,
        GATTCharacteristicPermission.write,
      ],
      descriptors: [],
    );
    await peripheral.addService(
      GATTService(
        uuid: serviceId,
        isPrimary: true,
        includedServices: [],
        characteristics: [characteristic],
      ),
    );
    serving = true;
    await advertise(signal);
    await central.startDiscovery();
    scanning = true;
  }

  Future<void> advertise(Signal signal) async {
    if (advertising) {
      await peripheral.stopAdvertising();
      advertising = false;
    }
    await peripheral.startAdvertising(
      Advertisement(serviceData: {serviceId: signal.encode()}),
    );
    advertising = true;
  }

  Future<Profile> readProfile(int id, {required bool summary}) async {
    final source = sources[id];
    if (source == null) throw StateError('参加者が見つかりません');
    try {
      await central.connect(source).timeout(const Duration(seconds: 6));
      try {
        await central
            .requestMTU(source, mtu: 512)
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        /* Read Blob remains available at the default MTU. */
      }
      final services = await central
          .discoverGATT(source)
          .timeout(const Duration(seconds: 5));
      final ch = services
          .firstWhere((s) => s.uuid == serviceId)
          .characteristics
          .firstWhere((c) => c.uuid == profileId);
      final buffer = BytesBuilder();
      int count = 1, version = -1;
      for (int page = 0; page < count; page++) {
        await central
            .writeCharacteristic(
              source,
              ch,
              value: Uint8List.fromList([page | (summary ? 0x80 : 0)]),
              type: GATTCharacteristicWriteType.withResponse,
            )
            .timeout(const Duration(seconds: 3));
        final bytes = await central
            .readCharacteristic(source, ch)
            .timeout(const Duration(seconds: 3));
        if (bytes.length < 8 || bytes.length > pageSize + 8) {
          throw const FormatException('プロフィール形式が不正です');
        }
        final h = ByteData.sublistView(bytes);
        if (page == 0) {
          count = h.getUint8(7);
          version = h.getUint16(4);
        }
        if (count == 0 ||
            count > 128 ||
            h.getUint32(0) != id ||
            h.getUint8(6) != page ||
            h.getUint8(7) != count ||
            h.getUint16(4) != version) {
          throw const FormatException('プロフィールが更新されました');
        }
        buffer.add(bytes.sublist(8));
      }
      final profile = Profile.fromJson(
        jsonDecode(utf8.decode(buffer.takeBytes())) as Map<String, dynamic>,
      );
      if (profile.tracks.length > 20) {
        throw const FormatException('曲数が上限を超えています');
      }
      return profile.publicView;
    } finally {
      try {
        await central.disconnect(source).timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
  }

  Future<void> stop() async {
    try {
      if (scanning) await central.stopDiscovery();
    } finally {
      scanning = false;
      try {
        if (advertising) await peripheral.stopAdvertising();
      } finally {
        advertising = false;
        try {
          if (serving) await peripheral.removeAllServices();
        } finally {
          serving = false;
          pages.clear();
          sources.clear();
        }
      }
    }
  }
}
