# bluetooth_kit

`bluetooth_kit` 是一个面向 OpenHarmony/HarmonyOS ArkTS 的蓝牙连接与协议配置工具包，适合智能家居、IoT 设备、工控外设、仪表设备等场景。它把设备画像、扫描、连接传输和业务协议拆开，同一套业务代码可以接 BLE GATT、传统蓝牙 SPP，也可以接用户自己的私有协议。

![bluetooth kit demo](https://cdn.jsdelivr.net/gh/KaworuNagisa-hhl/bluetooth-kit@main/docs/assets/bluetooth-kit-demo.gif)

## 安装

```bash
ohpm install bluetooth_kit
```

安装后从 `bluetooth_kit` 导入需要的管理器、协议编解码器、传输适配器和测试工具。

## 能力概览

- 支持 `BluetoothDeviceProfile` 统一配置 BLE GATT 与传统蓝牙 SPP。
- 支持 BLE Service/Characteristic、SPP UUID、协议 ID、连接超时、命令超时、重试、重连策略等配置。
- 内置 `LengthPrefixedCodec` 与 `JsonLineCodec`，并可通过 `BluetoothProtocolCodec` 接入私有协议。
- 内置命令队列、序号、ACK/DATA 应答匹配、超时重试、半包/粘包解析、CRC 与 BLE MTU 分包工具。
- 提供 `BleGattTransport`、`ClassicSppTransport`、`HarmonyBluetoothScanner`、`HarmonyBluetoothTransportFactory` 和权限辅助接口，方便按项目 API 版本接入 HarmonyOS 系统蓝牙能力。
- 提供 `MemoryBluetoothScanner` 与 `MemoryLoopbackTransport`，可在没有真实外设时验证配置、协议、命令链路和页面反馈。

本包专注蓝牙连接与协议链路，不包含 Cookie 管理、HTTP 缓存或业务账号缓存等非蓝牙能力。

## HarmonyOS 权限

应用侧需要按目标 SDK 和实际 API 版本声明并申请蓝牙权限。HarmonyOS NEXT 文档重点要求 `ohos.permission.ACCESS_BLUETOOTH`；旧版 OpenHarmony/HarmonyOS 兼容场景还需要评估 `USE_BLUETOOTH`、`DISCOVER_BLUETOOTH` 等权限差异。后台蓝牙扫描/交互需要按长时任务能力单独设计，不能默认承诺后台常连。

`module.json5` 权限声明可参考：

```json5
{
  "module": {
    "requestPermissions": [
      { "name": "ohos.permission.ACCESS_BLUETOOTH" }
    ]
  }
}
```

权限检查和申请可通过 `HarmonyBluetoothPermissionHelper` 接入项目自己的权限适配器：

```ts
const permissionHelper = new HarmonyBluetoothPermissionHelper(permissionAdapter)
const permissionState = await permissionHelper.request()
const permissionError = permissionHelper.toError(permissionState)
if (permissionError) {
  console.error(permissionError.message)
}
```

## 基础用法

下面示例使用内存扫描器和回环传输，可先验证 profile、协议、扫描、连接、请求和响应流程。

```ts
import {
  BluetoothBearer,
  BluetoothConnectionManager,
  BluetoothScanMode,
  BluetoothWriteMode,
  JsonLineCodec,
  LengthPrefixedCodec,
  MemoryBluetoothScanner,
  MemoryLoopbackTransport
} from 'bluetooth_kit'

const bleServiceUuid = '0000fff0-0000-1000-8000-00805f9b34fb'

const manager = new BluetoothConnectionManager({
  profiles: [
    {
      profileId: 'smart-lock-ble',
      displayName: 'Smart Lock BLE',
      bearer: BluetoothBearer.BleGatt,
      protocolId: 'length-prefixed-v1',
      ble: {
        serviceUuid: bleServiceUuid,
        writeCharacteristicUuid: '0000fff1-0000-1000-8000-00805f9b34fb',
        notifyCharacteristicUuid: '0000fff2-0000-1000-8000-00805f9b34fb',
        descriptorUuid: '00002902-0000-1000-8000-00805f9b34fb',
        mtu: 185,
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
      profileId: 'serial-classic',
      displayName: 'Serial Classic Device',
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
  ],
  codecs: [new LengthPrefixedCodec(), new JsonLineCodec()],
  transportFactory: {
    create() {
      return new MemoryLoopbackTransport()
    }
  },
  scannerFactory: {
    create() {
      return new MemoryBluetoothScanner([{
        deviceId: 'memory-loopback-001',
        name: 'Memory Lock BLE',
        serviceUuids: [bleServiceUuid],
        connectable: true
      }])
    }
  }
})

const profileErrors = manager.validate()
if (profileErrors.length > 0) {
  console.error(profileErrors[0].message)
}

await manager.scan({
  mode: BluetoothScanMode.Ble,
  timeoutMs: 1500,
  filters: [{ serviceUuid: bleServiceUuid }]
}, (device) => {
  console.info('found device=' + device.deviceId)
})

manager.onPacket((packet) => {
  console.info('packet command=' + packet.command.toString())
})

await manager.connect({
  deviceId: 'memory-loopback-001',
  name: 'Memory Lock BLE'
}, 'smart-lock-ble')

const result = await manager.request({
  command: 0x10,
  payload: new ArrayBuffer(0),
  expectAck: true
})
console.info('attempts=' + result.attempts.toString() + ', timeout=' + result.timedOut.toString())
```

## 接入真实设备

库内的 manager、协议层和 profile 不直接 import `@kit.ConnectivityKit`，真实系统 API 由应用层适配到下面这些接口。这样可以兼容不同 HarmonyOS/OpenHarmony API 版本，也方便在业务项目中处理权限、弹窗、日志和厂商设备差异。

```ts
import {
  BleGattClientAdapter,
  ClassicSppClientAdapter,
  HarmonyBluetoothScanner,
  HarmonyBluetoothTransportFactory
} from 'bluetooth_kit'

const transportFactory = new HarmonyBluetoothTransportFactory(
  {
    create(device, profile): BleGattClientAdapter {
      return new MyBleGattClientAdapter(device, profile)
    }
  },
  {
    create(device, profile): ClassicSppClientAdapter {
      return new MyClassicSppClientAdapter(device, profile)
    }
  }
)

const scannerFactory = {
  create() {
    return new HarmonyBluetoothScanner(new MyHarmonyBluetoothScanAdapter())
  }
}
```

适配器职责：

- `BleGattClientAdapter`：包装 GATT 连接、服务发现、MTU 设置、通知/指示订阅、Characteristic 写入、断连和异常回调。
- `ClassicSppClientAdapter`：包装传统蓝牙配对后的 SPP socket 连接、读写循环、断连和异常回调。
- `HarmonyBluetoothScanAdapter`：包装 BLE 扫描、传统蓝牙发现和停止扫描，并把系统扫描结果转换为 `BluetoothDeviceSnapshot`。
- `HarmonyBluetoothPermissionHelper`：把权限检查和申请结果转换成稳定的蓝牙错误模型，便于页面 Toast/Dialog 提示。

真实扫描、配对、连接、MTU 协商、后台行为和厂商设备协议都必须在真机验证。库本身提供稳定边界和可测试协议链路，系统 API 的具体调用由项目适配器负责。

## 自定义协议

实现 `BluetoothProtocolCodec` 即可接入私有协议。协议对象只负责 `BluetoothPacket` 与 `ArrayBuffer` 之间的转换，半包缓存、请求序号、超时重试由连接管理器处理。

```ts
class VendorCodec implements BluetoothProtocolCodec {
  readonly protocolId: string = 'vendor-v1'

  encode(packet: BluetoothPacket): ArrayBuffer {
    return packet.payload
  }

  decode(buffer: ArrayBuffer): DecodeResult {
    return {
      packets: [],
      rest: buffer
    }
  }
}
```

如果协议 ID 需要运行时决定，可以通过 `customProtocolFactory` 延迟创建：

```ts
customProtocolFactory: {
  create(protocolId: string): BluetoothProtocolCodec | undefined {
    return protocolId === 'vendor-v1' ? new VendorCodec() : undefined
  }
}
```

## Demo 验证

仓库中的 `example/BluetoothKitDemo.ets` 可直接拷到 HarmonyOS entry 页面中运行。示例使用 `MemoryBluetoothScanner` 和 `MemoryLoopbackTransport`，并提供页面内 Toast/Dialog，让用户能明显感知扫描、连接、收包、完成和异常状态。它可验证：

- BLE profile 与 Classic SPP profile 可同时配置。
- `LengthPrefixedCodec` 与 `JsonLineCodec` 可同时注册。
- `BluetoothConnectionManager.validate()` 能检查配置。
- `scan()` 能按 Service UUID/name 过滤设备。
- `request()` 能走命令队列，匹配同序号响应。
- `BleMtuChunker` 能按 MTU 生成分包。

## License

Apache-2.0
