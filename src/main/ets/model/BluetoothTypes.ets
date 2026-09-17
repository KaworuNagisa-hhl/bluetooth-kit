export enum BluetoothBearer {
  BleGatt = 'ble-gatt',
  ClassicSpp = 'classic-spp'
}

export enum BluetoothConnectionState {
  Idle = 'idle',
  Scanning = 'scanning',
  Connecting = 'connecting',
  Discovering = 'discovering',
  Ready = 'ready',
  Disconnecting = 'disconnecting',
  Disconnected = 'disconnected',
  Failed = 'failed'
}

export enum BluetoothScanMode {
  Ble = 'ble',
  Classic = 'classic',
  Mixed = 'mixed'
}

export enum BluetoothWriteMode {
  WithResponse = 'with-response',
  WithoutResponse = 'without-response'
}

export enum ProtocolFrameKind {
  Data = 'data',
  Ack = 'ack',
  Nak = 'nak',
  Heartbeat = 'heartbeat'
}

export interface BleEndpoint {
  serviceUuid: string
  writeCharacteristicUuid: string
  notifyCharacteristicUuid: string
  descriptorUuid?: string
  mtu?: number
  writeMode?: BluetoothWriteMode
}

export interface ClassicEndpoint {
  serviceUuid: string
  secure?: boolean
}

export interface ConnectionPolicy {
  connectTimeoutMs: number
  commandTimeoutMs: number
  retryCount: number
  retryBackoffMs: number
  heartbeatIntervalMs?: number
  reconnectKnownDevice?: boolean
}

export interface BluetoothScanFilter {
  serviceUuid?: string
  namePrefix?: string
  manufacturerId?: number
  minRssi?: number
}

export interface BluetoothScanConfig {
  mode: BluetoothScanMode
  timeoutMs: number
  filters?: BluetoothScanFilter[]
  allowDuplicates?: boolean
}

export interface BluetoothDeviceProfile {
  profileId: string
  displayName: string
  bearer: BluetoothBearer
  ble?: BleEndpoint
  classic?: ClassicEndpoint
  protocolId: string
  policy: ConnectionPolicy
}

export interface BluetoothDeviceSnapshot {
  deviceId: string
  name?: string
  rssi?: number
  connectable?: boolean
  serviceUuids?: string[]
  manufacturerId?: number
  rawAdvertisement?: ArrayBuffer
}

export interface BluetoothError {
  code: string
  message: string
  cause?: Error
}

export interface BluetoothPacket {
  kind: ProtocolFrameKind
  command: number
  sequence: number
  payload: ArrayBuffer
}

export interface CommandResult {
  request: BluetoothPacket
  response?: BluetoothPacket
  attempts: number
  timedOut: boolean
  error?: BluetoothError
}

export interface DecodeResult {
  packets: BluetoothPacket[]
  rest: ArrayBuffer
}

export interface BluetoothProtocolCodec {
  readonly protocolId: string
  encode(packet: BluetoothPacket): ArrayBuffer
  decode(buffer: ArrayBuffer): DecodeResult
}

export interface CommandOptions {
  command: number
  payload?: ArrayBuffer
  timeoutMs?: number
  retryCount?: number
  expectAck?: boolean
  expectedResponseCommand?: number
}

export interface BluetoothTransport {
  connect(device: BluetoothDeviceSnapshot, profile: BluetoothDeviceProfile): Promise<void>
  disconnect(): Promise<void>
  write(data: ArrayBuffer): Promise<void>
  onData(listener: (data: ArrayBuffer) => void): void
  onStateChange(listener: (state: BluetoothConnectionState) => void): void
  onError(listener: (error: BluetoothError) => void): void
}

export interface BluetoothScanner {
  startScan(config: BluetoothScanConfig, listener: (device: BluetoothDeviceSnapshot) => void): Promise<void>
  stopScan(): Promise<void>
}

export interface TransportFactory {
  create(profile: BluetoothDeviceProfile, device?: BluetoothDeviceSnapshot): BluetoothTransport
}

export interface ScannerFactory {
  create(mode: BluetoothScanMode): BluetoothScanner
}

export interface CustomProtocolFactory {
  create(protocolId: string): BluetoothProtocolCodec | undefined
}

export interface BluetoothPlatformCapabilities {
  bleCentral: boolean
  blePeripheral: boolean
  classicSppClient: boolean
  classicSppServer: boolean
  bonding: boolean
  rssi: boolean
  mtu: boolean
  phy: boolean
  l2capChannel: boolean
  extendedAdvertising: boolean
  backgroundScan: boolean
  multipleConnections: boolean
  apiVersion?: number
  notes?: string[]
}

export interface BluetoothCapabilityProvider {
  getCapabilities(): Promise<BluetoothPlatformCapabilities>
}

export enum BluetoothLogLevel {
  Debug = 'debug',
  Info = 'info',
  Warn = 'warn',
  Error = 'error'
}

export interface BluetoothLogEvent {
  level: BluetoothLogLevel
  event: string
  timestamp: number
  profileId?: string
  deviceId?: string
  state?: BluetoothConnectionState
  error?: BluetoothError
  message?: string
}

export interface BluetoothLogger {
  log(event: BluetoothLogEvent): void
}

export interface BluetoothKitConfig {
  profiles: BluetoothDeviceProfile[]
  codecs: BluetoothProtocolCodec[]
  transportFactory: TransportFactory
  scannerFactory?: ScannerFactory
  customProtocolFactory?: CustomProtocolFactory
  capabilityProvider?: BluetoothCapabilityProvider
  logger?: BluetoothLogger
}
