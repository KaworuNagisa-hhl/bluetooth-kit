import {
  BluetoothBearer,
  BluetoothConnectionState,
  BluetoothDeviceProfile,
  BluetoothDeviceSnapshot,
  BluetoothError,
  BluetoothTransport,
  BluetoothWriteMode
} from '../model/BluetoothTypes'
import { BleGattClientAdapter } from './HarmonyBluetoothAdapters'

export class BleGattTransport implements BluetoothTransport {
  private readonly adapter: BleGattClientAdapter
  private dataListeners: Array<(data: ArrayBuffer) => void> = []
  private stateListeners: Array<(state: BluetoothConnectionState) => void> = []
  private errorListeners: Array<(error: BluetoothError) => void> = []
  private profile?: BluetoothDeviceProfile
  private connected: boolean = false

  constructor(adapter: BleGattClientAdapter) {
    this.adapter = adapter
    this.adapter.onData((data: ArrayBuffer) => this.emitData(data))
    this.adapter.onStateChange((state: BluetoothConnectionState) => this.emitState(state))
    this.adapter.onError((error: BluetoothError) => this.emitError(error))
  }

  async connect(device: BluetoothDeviceSnapshot, profile: BluetoothDeviceProfile): Promise<void> {
    if (profile.bearer !== BluetoothBearer.BleGatt || !profile.ble) {
      const error: BluetoothError = {
        code: 'BLE_PROFILE_REQUIRED',
        message: 'BleGattTransport requires a BLE GATT profile.'
      }
      this.emitError(error)
      throw new Error(error.message)
    }
    this.profile = profile
    this.emitState(BluetoothConnectionState.Connecting)
    await this.adapter.connect(device, profile)
    this.emitState(BluetoothConnectionState.Discovering)
    await this.adapter.discoverServices()
    if (profile.ble.mtu !== undefined) {
      await this.adapter.requestMtu(profile.ble.mtu)
    }
    await this.adapter.enableNotifications({
      serviceUuid: profile.ble.serviceUuid,
      characteristicUuid: profile.ble.notifyCharacteristicUuid,
      descriptorUuid: profile.ble.descriptorUuid
    })
    this.connected = true
    this.emitState(BluetoothConnectionState.Ready)
  }

  async disconnect(): Promise<void> {
    this.connected = false
    this.emitState(BluetoothConnectionState.Disconnecting)
    await this.adapter.disconnect()
    this.emitState(BluetoothConnectionState.Disconnected)
  }

  async write(data: ArrayBuffer): Promise<void> {
    if (!this.connected || !this.profile || !this.profile.ble) {
      const error: BluetoothError = { code: 'BLE_NOT_CONNECTED', message: 'BLE GATT transport is disconnected.' }
      this.emitError(error)
      throw new Error(error.message)
    }
    await this.adapter.write({
      serviceUuid: this.profile.ble.serviceUuid,
      characteristicUuid: this.profile.ble.writeCharacteristicUuid,
      data,
      mode: this.profile.ble.writeMode === undefined ? BluetoothWriteMode.WithResponse : this.profile.ble.writeMode
    })
  }

  onData(listener: (data: ArrayBuffer) => void): void {
    this.dataListeners.push(listener)
  }

  onStateChange(listener: (state: BluetoothConnectionState) => void): void {
    this.stateListeners.push(listener)
  }

  onError(listener: (error: BluetoothError) => void): void {
    this.errorListeners.push(listener)
  }

  private emitData(data: ArrayBuffer): void {
    for (let index = 0; index < this.dataListeners.length; index++) {
      this.dataListeners[index](data)
    }
  }

  private emitState(state: BluetoothConnectionState): void {
    for (let index = 0; index < this.stateListeners.length; index++) {
      this.stateListeners[index](state)
    }
  }

  private emitError(error: BluetoothError): void {
    for (let index = 0; index < this.errorListeners.length; index++) {
      this.errorListeners[index](error)
    }
  }
}
