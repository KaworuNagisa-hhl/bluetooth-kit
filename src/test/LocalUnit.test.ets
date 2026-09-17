import { describe, it, expect } from '@ohos/hypium'
import {
  BleMtuChunker,
  BluetoothBearer,
  BluetoothConnectionManager,
  BluetoothConnectionState,
  BluetoothDeviceSnapshot,
  BluetoothScanMode,
  BluetoothTransport,
  BluetoothWriteMode,
  ByteUtils,
  Crc16,
  LengthPrefixedCodec,
  MemoryBluetoothScanner,
  MemoryLoopbackTransport,
  ProtocolFrameKind,
  ScannerFactory,
  TransportFactory
} from 'bluetooth_kit'

class TestTransportFactory implements TransportFactory {
  create(): BluetoothTransport {
    return new MemoryLoopbackTransport()
  }
}

class TestScannerFactory implements ScannerFactory {
  private readonly devices: BluetoothDeviceSnapshot[]

  constructor(devices: BluetoothDeviceSnapshot[]) {
    this.devices = devices
  }

  create(mode: BluetoothScanMode) {
    return new MemoryBluetoothScanner(this.devices)
  }
}

export default function localUnitTest() {
  describe('BluetoothKit', () => {
    it('keeps_crc16_modbus_contract', 0, () => {
      const crc = Crc16.modbus(ByteUtils.asciiToBuffer('123456789'))
      expect(crc).assertEqual(0x4B37)
    })

    it('decodes_sticky_and_half_packets', 0, () => {
      const codec = new LengthPrefixedCodec()
      const first = codec.encode({
        kind: ProtocolFrameKind.Data,
        command: 1,
        sequence: 1,
        payload: ByteUtils.fromNumbers([1, 2, 3])
      })
      const second = codec.encode({
        kind: ProtocolFrameKind.Ack,
        command: 1,
        sequence: 1,
        payload: ByteUtils.empty()
      })
      const half = ByteUtils.slice(second, 0, 4)
      const decoded = codec.decode(ByteUtils.concat(first, half))
      expect(decoded.packets.length).assertEqual(1)
      expect(decoded.rest.byteLength).assertEqual(4)
      const completed = codec.decode(ByteUtils.concat(decoded.rest, ByteUtils.slice(second, 4)))
      expect(completed.packets.length).assertEqual(1)
      expect(completed.packets[0].kind).assertEqual(ProtocolFrameKind.Ack)
    })

    it('chunks_ble_payload_by_mtu_minus_att_header', 0, () => {
      const chunks = BleMtuChunker.chunk(ByteUtils.fromNumbers([1, 2, 3, 4, 5, 6]), 6)
      expect(chunks.length).assertEqual(2)
      expect(chunks[0].byteLength).assertEqual(3)
    })

    it('filters_scan_by_name_mac_and_device_id', 0, async () => {
      const scanner = new MemoryBluetoothScanner([
        {
          deviceId: 'lock-1',
          macAddress: 'AA:BB:CC:00:00:01',
          name: 'Memory Lock BLE',
          rssi: -45,
          serviceUuids: ['service-a']
        },
        {
          deviceId: 'lock-2',
          macAddress: 'AA:BB:CC:00:00:02',
          name: 'Other Lock',
          rssi: -55,
          serviceUuids: ['service-a']
        }
      ])
      const matches: BluetoothDeviceSnapshot[] = []
      await scanner.startScan({
        mode: BluetoothScanMode.Ble,
        timeoutMs: 100,
        filters: [{
          deviceId: 'lock-1',
          macAddress: 'aa:bb:cc:00:00:01',
          name: 'Memory Lock BLE',
          serviceUuid: 'service-a',
          minRssi: -60
        }]
      }, (device: BluetoothDeviceSnapshot) => {
        matches.push(device)
      })
      expect(matches.length).assertEqual(1)
      expect(matches[0].deviceId).assertEqual('lock-1')
    })

    it('scan_and_connect_uses_preferred_mac_or_name', 0, async () => {
      const serviceUuid = '0000fff0-0000-1000-8000-00805f9b34fb'
      const manager = new BluetoothConnectionManager({
        profiles: [{
          profileId: 'lock-ble',
          displayName: 'Lock BLE',
          bearer: BluetoothBearer.BleGatt,
          protocolId: 'length-prefixed-v1',
          ble: {
            serviceUuid,
            writeCharacteristicUuid: '0000fff1-0000-1000-8000-00805f9b34fb',
            notifyCharacteristicUuid: '0000fff2-0000-1000-8000-00805f9b34fb',
            mtu: 23,
            writeMode: BluetoothWriteMode.WithResponse
          },
          policy: {
            connectTimeoutMs: 1000,
            commandTimeoutMs: 1000,
            retryCount: 0,
            retryBackoffMs: 0
          }
        }],
        codecs: [new LengthPrefixedCodec()],
        transportFactory: new TestTransportFactory(),
        scannerFactory: new TestScannerFactory([{
          deviceId: 'memory-lock',
          macAddress: 'AA:BB:CC:00:00:01',
          name: 'Memory Lock BLE',
          rssi: -45,
          serviceUuids: [serviceUuid],
          connectable: true
        }])
      })
      const device = await manager.scanAndConnect({
        profileId: 'lock-ble',
        preferredMacAddress: 'AA:BB:CC:00:00:01',
        preferredName: 'Memory Lock BLE',
        scan: {
          mode: BluetoothScanMode.Ble,
          timeoutMs: 100,
          filters: [{ macAddress: 'AA:BB:CC:00:00:01', name: 'Memory Lock BLE' }]
        }
      })
      expect(device !== undefined).assertTrue()
      expect(manager.getState()).assertEqual(BluetoothConnectionState.Ready)
    })
  })
}
