import {
  BluetoothBearer,
  BluetoothConnectionState,
  BluetoothDeviceProfile,
  BluetoothDeviceSnapshot,
  BluetoothError,
  BluetoothTransport
} from '../model/BluetoothTypes'
import { ClassicSppClientAdapter } from './HarmonyBluetoothAdapters'

export class ClassicSppTransport implements BluetoothTransport {
  private readonly adapter: ClassicSppClientAdapter
  private dataListeners: Array<(data: ArrayBuffer) => void> = []
  private stateListeners: Array<(state: BluetoothConnectionState) => void> = []
  private errorListeners: Array<(error: BluetoothError) => void> = []
  private connected: boolean = false

  constructor(adapter: ClassicSppClientAdapter) {
    this.adapter = adapter
    this.adapter.onData((data: ArrayBuffer) => this.emitData(data))
    this.adapter.onStateChange((state: BluetoothConnectionState) => this.emitState(state))
    this.adapter.onError((error: BluetoothError) => this.emitError(error))
  }

  async connect(device: BluetoothDeviceSnapshot, profile: BluetoothDeviceProfile): Promise<void> {
    if (profile.bearer !== BluetoothBearer.ClassicSpp || !profile.classic) {
      const error: BluetoothError = {
        code: 'CLASSIC_PROFILE_REQUIRED',
        message: 'ClassicSppTransport requires a classic SPP profile.'
      }
      this.emitError(error)
      throw new Error(error.message)
    }
    this.emitState(BluetoothConnectionState.Connecting)
    await this.adapter.connect({
      device,
      serviceUuid: profile.classic.serviceUuid,
      secure: profile.classic.secure === undefined ? true : profile.classic.secure
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
    if (!this.connected) {
      const error: BluetoothError = { code: 'CLASSIC_NOT_CONNECTED', message: 'Classic SPP transport is disconnected.' }
      this.emitError(error)
      throw new Error(error.message)
    }
    await this.adapter.write(data)
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
