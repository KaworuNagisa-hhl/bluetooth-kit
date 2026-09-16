import {
  BluetoothBearer,
  BluetoothDeviceProfile,
  BluetoothDeviceSnapshot,
  BluetoothTransport,
  TransportFactory
} from '../model/BluetoothTypes'
import { BleGattTransport } from './BleGattTransport'
import { ClassicSppTransport } from './ClassicSppTransport'
import {
  BleGattClientAdapterFactory,
  ClassicSppClientAdapterFactory
} from './HarmonyBluetoothAdapters'

export class HarmonyBluetoothTransportFactory implements TransportFactory {
  private readonly bleFactory?: BleGattClientAdapterFactory
  private readonly classicFactory?: ClassicSppClientAdapterFactory

  constructor(bleFactory?: BleGattClientAdapterFactory, classicFactory?: ClassicSppClientAdapterFactory) {
    this.bleFactory = bleFactory
    this.classicFactory = classicFactory
  }

  create(profile: BluetoothDeviceProfile, device?: BluetoothDeviceSnapshot): BluetoothTransport {
    if (!device) {
      throw new Error('HarmonyBluetoothTransportFactory requires a device from BluetoothConnectionManager.connect(device, profileId).')
    }
    if (profile.bearer === BluetoothBearer.BleGatt) {
      if (!this.bleFactory) {
        throw new Error('BLE GATT adapter factory is not configured.')
      }
      return new BleGattTransport(this.bleFactory.create(device, profile))
    }
    if (!this.classicFactory) {
      throw new Error('Classic SPP adapter factory is not configured.')
    }
    return new ClassicSppTransport(this.classicFactory.create(device, profile))
  }
}
