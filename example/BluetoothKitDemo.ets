import {
  BleMtuChunker,
  BluetoothBearer,
  BluetoothConnectionManager,
  BluetoothConnectionState,
  BluetoothDeviceProfile,
  BluetoothDeviceSnapshot,
  BluetoothKitConfig,
  BluetoothScanner,
  BluetoothScanMode,
  BluetoothTransport,
  BluetoothWriteMode,
  ByteUtils,
  HarmonyBluetoothPermissionGuide,
  JsonLineCodec,
  LengthPrefixedCodec,
  MemoryBluetoothScanner,
  MemoryLoopbackTransport,
  ScannerFactory,
  TransportFactory
} from 'bluetooth_kit'

class DemoTransportFactory implements TransportFactory {
  create(): BluetoothTransport {
    return new MemoryLoopbackTransport()
  }
}

class DemoScannerFactory implements ScannerFactory {
  private readonly devices: BluetoothDeviceSnapshot[]

  constructor(devices: BluetoothDeviceSnapshot[]) {
    this.devices = devices
  }

  create(): BluetoothScanner {
    return new MemoryBluetoothScanner(this.devices)
  }
}

@Entry
@Component
struct Index {
  @State private connectionState: string = BluetoothConnectionState.Idle
  @State private profileSummary: string = 'profiles not checked'
  @State private permissionSummary: string = 'permission not checked'
  @State private scanSummary: string = 'scan not started'
  @State private commandSummary: string = 'command not sent'
  @State private packetSummary: string = 'waiting for demo packet'
  @State private chunkSummary: string = 'mtu not tested'
  @State private errorSummary: string = 'none'
  @State private toastVisible: boolean = false
  @State private toastText: string = ''
  @State private dialogVisible: boolean = false
  @State private dialogTitle: string = ''
  @State private dialogMessage: string = ''

  aboutToAppear(): void {
    this.runBluetoothKitDemo()
  }

  private async runBluetoothKitDemo(): Promise<void> {
    const bleServiceUuid = '0000fff0-0000-1000-8000-00805f9b34fb'
    const profiles: BluetoothDeviceProfile[] = [
      {
        profileId: 'demo-ble-device',
        displayName: 'Demo BLE Device',
        bearer: BluetoothBearer.BleGatt,
        protocolId: 'length-prefixed-v1',
        ble: {
          serviceUuid: bleServiceUuid,
          writeCharacteristicUuid: '0000fff1-0000-1000-8000-00805f9b34fb',
          notifyCharacteristicUuid: '0000fff2-0000-1000-8000-00805f9b34fb',
          descriptorUuid: '00002902-0000-1000-8000-00805f9b34fb',
          mtu: 23,
          writeMode: BluetoothWriteMode.WithResponse
        },
        policy: {
          connectTimeoutMs: 10000,
          commandTimeoutMs: 3000,
          retryCount: 2,
          retryBackoffMs: 300,
          reconnectKnownDevice: true
        }
      },
      {
        profileId: 'demo-classic-spp-device',
        displayName: 'Demo Classic SPP Device',
        bearer: BluetoothBearer.ClassicSpp,
        protocolId: 'json-line-v1',
        classic: {
          serviceUuid: '00001101-0000-1000-8000-00805f9b34fb',
          secure: true
        },
        policy: {
          connectTimeoutMs: 12000,
          commandTimeoutMs: 4000,
          retryCount: 1,
          retryBackoffMs: 500,
          reconnectKnownDevice: false
        }
      }
    ]

    const memoryDevices: BluetoothDeviceSnapshot[] = [
      {
        deviceId: 'memory-loopback-001',
        name: 'Memory Lock BLE',
        rssi: -48,
        connectable: true,
        serviceUuids: [bleServiceUuid],
        manufacturerId: 4096
      },
      {
        deviceId: 'memory-spp-001',
        name: 'Memory Serial Classic',
        rssi: -58,
        connectable: true
      }
    ]
    const config: BluetoothKitConfig = {
      profiles,
      codecs: [new LengthPrefixedCodec(), new JsonLineCodec()],
      transportFactory: new DemoTransportFactory(),
      scannerFactory: new DemoScannerFactory(memoryDevices)
    }
    const manager = new BluetoothConnectionManager(config)

    const errors = manager.validate()
    this.profileSummary = errors.length === 0 ?
      '2 profiles / BLE length-prefixed + Classic JSON line' : errors[0].code
    this.permissionSummary = HarmonyBluetoothPermissionGuide.accessBluetoothPermission()
    this.showToast('Profile 已校验：' + this.profileSummary)
    this.showToast('蓝牙权限：' + this.permissionSummary)

    manager.onStateChange((state: BluetoothConnectionState) => {
      this.connectionState = state
      if (state === BluetoothConnectionState.Scanning) {
        this.showToast('正在扫描蓝牙设备')
      }
      if (state === BluetoothConnectionState.Ready) {
        this.showToast('蓝牙连接已就绪')
      }
    })
    manager.onPacket((packet) => {
      const payload = ByteUtils.toNumbers(packet.payload).join(',')
      this.packetSummary = 'kind=' + packet.kind + ', command=' + packet.command.toString() +
        ', seq=' + packet.sequence.toString() + ', payload=[' + payload + ']'
      this.showToast('收到协议包 command=' + packet.command.toString())
    })
    manager.onError((error) => {
      this.errorSummary = error.code + ': ' + error.message
      this.showErrorDialog(this.errorSummary)
    })

    const foundDevices: BluetoothDeviceSnapshot[] = []
    await manager.scan({
      mode: BluetoothScanMode.Ble,
      timeoutMs: 1500,
      filters: [{ serviceUuid: bleServiceUuid, namePrefix: 'Memory' }]
    }, (device: BluetoothDeviceSnapshot) => {
      foundDevices.push(device)
    })
    const firstDeviceName = foundDevices.length > 0 && foundDevices[0].name ? foundDevices[0].name : 'none'
    this.scanSummary = foundDevices.length.toString() + ' device / first=' + firstDeviceName
    this.showToast('扫描完成：' + this.scanSummary)

    const chunks = BleMtuChunker.chunk(ByteUtils.fromNumbers([
      1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
      11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
      21, 22
    ]), 23)
    this.chunkSummary = chunks.length.toString() + ' chunks / first=' + chunks[0].byteLength.toString() + ' bytes'
    this.showToast('MTU 分包完成：' + this.chunkSummary)

    await manager.connect({
      deviceId: 'memory-loopback-001',
      name: 'Memory Loopback'
    }, 'demo-ble-device')

    const result = await manager.request({
      command: 0x10,
      payload: ByteUtils.fromNumbers([0x01, 0x02, 0x03]),
      expectAck: true
    })
    const responseKind = result.response ? result.response.kind : 'none'
    this.commandSummary = 'attempts=' + result.attempts.toString() + ', response=' +
      responseKind + ', timedOut=' + result.timedOut.toString()
    if (result.error) {
      this.showErrorDialog(result.error.code + ': ' + result.error.message)
      return
    }
    this.showCompleteDialog()
  }

  private showToast(message: string): void {
    this.toastText = message
    this.toastVisible = true
    setTimeout(() => {
      if (this.toastText === message) {
        this.toastVisible = false
      }
    }, 1800)
  }

  private showCompleteDialog(): void {
    this.dialogTitle = '蓝牙 Demo 验证完成'
    this.dialogMessage = 'BLE/Classic 配置、扫描过滤、连接、命令队列、协议解析和 MTU 分包已跑通。'
    this.dialogVisible = true
  }

  private showErrorDialog(message: string): void {
    this.dialogTitle = '蓝牙 Demo 异常'
    this.dialogMessage = message
    this.dialogVisible = true
  }

  build() {
    Stack() {
      Column() {
        Text('Bluetooth Kit Demo')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F8F8F8')
        Text('mock transport validates BLE profile, codec, packet receive, and MTU chunking')
          .fontSize(13)
          .fontColor('#A8ADB7')
          .margin({ top: 8 })
        Column() {
          this.infoRow('state', this.connectionState)
          this.infoRow('profiles', this.profileSummary)
          this.infoRow('permission', this.permissionSummary)
          this.infoRow('scan', this.scanSummary)
          this.infoRow('request', this.commandSummary)
          this.infoRow('packet', this.packetSummary)
          this.infoRow('mtu', this.chunkSummary)
          this.infoRow('error', this.errorSummary)
        }
        .width('88%')
        .padding(16)
        .margin({ top: 24 })
        .borderRadius(8)
        .backgroundColor('#181A20')
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)

      if (this.toastVisible) {
        this.toastLayer()
      }

      if (this.dialogVisible) {
        this.dialogLayer()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0B0B0C')
  }

  @Builder
  private toastLayer() {
    Column() {
      Text(this.toastText)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#0B0B0C')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor('#F8F8F8')
        .borderRadius(8)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 54, left: 16, right: 16 })
    .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  private dialogLayer() {
    Column() {
      Column() {
        Text(this.dialogTitle)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F8F8F8')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.dialogMessage)
          .fontSize(14)
          .fontColor('#C9CED8')
          .lineHeight(21)
          .margin({ top: 12 })

        Button('知道了')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#0B0B0C')
          .height(42)
          .width('100%')
          .margin({ top: 18 })
          .borderRadius(8)
          .backgroundColor('#F8F8F8')
          .onClick(() => {
            this.dialogVisible = false
          })
      }
      .width('82%')
      .padding(20)
      .borderRadius(8)
      .backgroundColor('#20242D')
      .border({ width: 1, color: '#33FFFFFF' })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#99000000')
  }

  @Builder
  private infoRow(label: string, value: string) {
    Row() {
      Text(label)
        .width(72)
        .fontSize(13)
        .fontColor('#7D8595')
      Text(value)
        .layoutWeight(1)
        .fontSize(14)
        .fontColor('#F8F8F8')
    }
    .width('100%')
    .margin({ bottom: 10 })
  }
}
