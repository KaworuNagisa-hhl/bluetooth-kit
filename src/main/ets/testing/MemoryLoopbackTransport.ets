import {
  BluetoothConnectionState,
  BluetoothDeviceProfile,
  BluetoothDeviceSnapshot,
  BluetoothError,
  BluetoothTransport
} from '../model/BluetoothTypes'

export class MemoryLoopbackTransport implements BluetoothTransport {
  private dataListeners: Array<(data: ArrayBuffer) => void> = []
  private stateListeners: Array<(state: BluetoothConnectionState) => void> = []
  private errorListeners: Array<(error: BluetoothError) => void> = []
  private connected: boolean = false

  async connect(device: BluetoothDeviceSnapshot, profile: BluetoothDeviceProfile): Promise<void> {
    this.connected = true
    this.emitState(BluetoothConnectionState.Ready)
  }

  async disconnect(): Promise<void> {
    this.connected = false
    this.emitState(BluetoothConnectionState.Disconnected)
  }

  async write(data: ArrayBuffer): Promise<void> {
    if (!this.connected) {
      const error: BluetoothError = { code: 'LOOPBACK_CLOSED', message: 'Loopback transport is disconnected.' }
      this.emitError(error)
      throw new Error(error.message)
    }
    for (let index = 0; index < this.dataListeners.length; index++) {
      this.dataListeners[index](data)
    }
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
