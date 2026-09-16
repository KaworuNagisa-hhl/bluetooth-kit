import {
  BluetoothConnectionState,
  BluetoothDeviceProfile,
  BluetoothDeviceSnapshot,
  BluetoothError,
  BluetoothScanConfig,
  BluetoothScanMode,
  BluetoothWriteMode
} from '../model/BluetoothTypes'

export interface BleGattWriteRequest {
  serviceUuid: string
  characteristicUuid: string
  data: ArrayBuffer
  mode: BluetoothWriteMode
}

export interface BleGattNotifyRequest {
  serviceUuid: string
  characteristicUuid: string
  descriptorUuid?: string
}

export interface BleGattClientAdapter {
  connect(device: BluetoothDeviceSnapshot, profile: BluetoothDeviceProfile): Promise<void>
  disconnect(): Promise<void>
  discoverServices(): Promise<void>
  requestMtu(mtu: number): Promise<void>
  enableNotifications(request: BleGattNotifyRequest): Promise<void>
  write(request: BleGattWriteRequest): Promise<void>
  onData(listener: (data: ArrayBuffer) => void): void
  onStateChange(listener: (state: BluetoothConnectionState) => void): void
  onError(listener: (error: BluetoothError) => void): void
}

export interface ClassicSppConnectRequest {
  device: BluetoothDeviceSnapshot
  serviceUuid: string
  secure: boolean
}

export interface ClassicSppClientAdapter {
  connect(request: ClassicSppConnectRequest): Promise<void>
  disconnect(): Promise<void>
  write(data: ArrayBuffer): Promise<void>
  onData(listener: (data: ArrayBuffer) => void): void
  onStateChange(listener: (state: BluetoothConnectionState) => void): void
  onError(listener: (error: BluetoothError) => void): void
}

export interface HarmonyBluetoothScanAdapter {
  start(config: BluetoothScanConfig, listener: (device: BluetoothDeviceSnapshot) => void): Promise<void>
  stop(mode: BluetoothScanMode): Promise<void>
}

export interface BleGattClientAdapterFactory {
  create(device: BluetoothDeviceSnapshot, profile: BluetoothDeviceProfile): BleGattClientAdapter
}

export interface ClassicSppClientAdapterFactory {
  create(device: BluetoothDeviceSnapshot, profile: BluetoothDeviceProfile): ClassicSppClientAdapter
}
