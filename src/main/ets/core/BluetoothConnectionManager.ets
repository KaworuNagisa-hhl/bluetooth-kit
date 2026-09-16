import {
  BluetoothConnectionState,
  BluetoothDeviceProfile,
  BluetoothDeviceSnapshot,
  BluetoothError,
  BluetoothKitConfig,
  BluetoothPacket,
  BluetoothProtocolCodec,
  BluetoothScanConfig,
  BluetoothScanner,
  BluetoothTransport,
  CommandOptions,
  CommandResult,
  ProtocolFrameKind
} from '../model/BluetoothTypes'
import { ByteUtils } from '../utils/ByteUtils'
import { BluetoothCommandQueue } from './BluetoothCommandQueue'
import { BluetoothProfileRegistry } from './BluetoothProfileRegistry'

export class BluetoothConnectionManager {
  private readonly config: BluetoothKitConfig
  private readonly registry: BluetoothProfileRegistry
  private readonly commandQueue: BluetoothCommandQueue = new BluetoothCommandQueue()
  private state: BluetoothConnectionState = BluetoothConnectionState.Idle
  private codec?: BluetoothProtocolCodec
  private transport?: BluetoothTransport
  private scanner?: BluetoothScanner
  private receiveBuffer: ArrayBuffer = ByteUtils.empty()
  private sequence: number = 0
  private stateListeners: Array<(state: BluetoothConnectionState) => void> = []
  private packetListeners: Array<(packet: BluetoothPacket) => void> = []
  private errorListeners: Array<(error: BluetoothError) => void> = []

  constructor(config: BluetoothKitConfig) {
    this.config = config
    this.registry = new BluetoothProfileRegistry(config.profiles, config.codecs)
  }

  getState(): BluetoothConnectionState {
    return this.state
  }

  getProfiles(): BluetoothDeviceProfile[] {
    return this.registry.getProfiles()
  }

  validate(): BluetoothError[] {
    return this.registry.validate()
  }

  onStateChange(listener: (state: BluetoothConnectionState) => void): void {
    this.stateListeners.push(listener)
  }

  onPacket(listener: (packet: BluetoothPacket) => void): void {
    this.packetListeners.push(listener)
  }

  onError(listener: (error: BluetoothError) => void): void {
    this.errorListeners.push(listener)
  }

  async connect(device: BluetoothDeviceSnapshot, profileId: string): Promise<void> {
    const profile = this.findProfile(profileId)
    if (!profile) {
      this.emitError('PROFILE_NOT_FOUND', 'Device profile not found: ' + profileId)
      return
    }
    const codec = this.findCodec(profile.protocolId)
    if (!codec) {
      this.emitError('CODEC_NOT_FOUND', 'Protocol codec not found: ' + profile.protocolId)
      return
    }
    this.codec = codec
    const transport = this.config.transportFactory.create(profile)
    transport.onData((data: ArrayBuffer) => this.handleData(data))
    transport.onStateChange((state: BluetoothConnectionState) => this.setState(state))
    transport.onError((error: BluetoothError) => this.emitError(error.code, error.message, error.cause))
    this.transport = transport
    this.commandQueue.bind(transport, codec)
    this.commandQueue.configure(profile.policy.commandTimeoutMs, profile.policy.retryCount, profile.policy.retryBackoffMs)
    this.setState(BluetoothConnectionState.Connecting)
    const connected = await this.withTimeout(
      transport.connect(device, profile),
      profile.policy.connectTimeoutMs,
      'CONNECT_TIMEOUT',
      'Bluetooth connect timed out: ' + profile.profileId
    )
    if (!connected) {
      this.setState(BluetoothConnectionState.Failed)
      return
    }
    this.setState(BluetoothConnectionState.Ready)
  }

  async disconnect(): Promise<void> {
    if (!this.transport) {
      this.setState(BluetoothConnectionState.Disconnected)
      return
    }
    this.setState(BluetoothConnectionState.Disconnecting)
    this.commandQueue.clear()
    await this.transport.disconnect()
    this.receiveBuffer = ByteUtils.empty()
    this.setState(BluetoothConnectionState.Disconnected)
  }

  async scan(config: BluetoothScanConfig, listener: (device: BluetoothDeviceSnapshot) => void): Promise<void> {
    if (!this.config.scannerFactory) {
      this.emitError('SCANNER_NOT_CONFIGURED', 'Bluetooth scanner factory is not configured.')
      return
    }
    this.setState(BluetoothConnectionState.Scanning)
    this.scanner = this.config.scannerFactory.create(config.mode)
    await this.scanner.startScan(config, listener)
    this.setState(BluetoothConnectionState.Idle)
  }

  async stopScan(): Promise<void> {
    if (!this.scanner) {
      return
    }
    await this.scanner.stopScan()
    this.scanner = undefined
    this.setState(BluetoothConnectionState.Idle)
  }

  async send(options: CommandOptions): Promise<BluetoothPacket> {
    const packet = this.createPacket(options)
    if (!this.transport || !this.codec) {
      this.emitError('NOT_CONNECTED', 'Bluetooth transport is not connected.')
      return packet
    }
    const encoded = this.codec.encode(packet)
    await this.transport.write(encoded)
    return packet
  }

  async request(options: CommandOptions): Promise<CommandResult> {
    const packet = this.createPacket(options)
    if (!this.transport || !this.codec) {
      const error: BluetoothError = { code: 'NOT_CONNECTED', message: 'Bluetooth transport is not connected.' }
      this.emitError(error.code, error.message)
      return {
        request: packet,
        attempts: 0,
        timedOut: false,
        error
      }
    }
    return this.commandQueue.enqueue(packet, options)
  }

  private createPacket(options: CommandOptions): BluetoothPacket {
    return {
      kind: ProtocolFrameKind.Data,
      command: options.command,
      sequence: this.nextSequence(),
      payload: options.payload === undefined ? ByteUtils.empty() : options.payload
    }
  }

  private handleData(data: ArrayBuffer): void {
    if (!this.codec) {
      return
    }
    this.receiveBuffer = ByteUtils.concat(this.receiveBuffer, data)
    const result = this.codec.decode(this.receiveBuffer)
    this.receiveBuffer = result.rest
    for (let index = 0; index < result.packets.length; index++) {
      const packet = result.packets[index]
      this.commandQueue.handlePacket(packet)
      this.emitPacket(packet)
    }
  }

  private findProfile(profileId: string): BluetoothDeviceProfile | undefined {
    return this.registry.findProfile(profileId)
  }

  private findCodec(protocolId: string): BluetoothProtocolCodec | undefined {
    const codec = this.registry.findCodec(protocolId)
    if (codec) {
      return codec
    }
    if (this.config.customProtocolFactory) {
      return this.config.customProtocolFactory.create(protocolId)
    }
    return undefined
  }

  private nextSequence(): number {
    this.sequence = (this.sequence + 1) & 0xFF
    return this.sequence
  }

  private setState(state: BluetoothConnectionState): void {
    this.state = state
    for (let index = 0; index < this.stateListeners.length; index++) {
      this.stateListeners[index](state)
    }
  }

  private emitPacket(packet: BluetoothPacket): void {
    for (let index = 0; index < this.packetListeners.length; index++) {
      this.packetListeners[index](packet)
    }
  }

  private emitError(code: string, message: string, cause?: Error): void {
    const error: BluetoothError = { code, message, cause }
    for (let index = 0; index < this.errorListeners.length; index++) {
      this.errorListeners[index](error)
    }
  }

  private withTimeout(work: Promise<void>, timeoutMs: number, code: string, message: string): Promise<boolean> {
    return new Promise<boolean>((resolve) => {
      let completed = false
      setTimeout(() => {
        if (completed) {
          return
        }
        completed = true
        this.emitError(code, message)
        resolve(false)
      }, timeoutMs)
      work.then(() => {
        if (completed) {
          return
        }
        completed = true
        resolve(true)
      }).catch((err: Error) => {
        if (completed) {
          return
        }
        completed = true
        this.emitError('CONNECT_FAILED', err.message, err)
        resolve(false)
      })
    })
  }
}
