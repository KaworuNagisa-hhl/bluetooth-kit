import {
  BluetoothCapabilityProvider,
  BluetoothPlatformCapabilities
} from '../model/BluetoothTypes'

export class StaticBluetoothCapabilityProvider implements BluetoothCapabilityProvider {
  private readonly capabilities: BluetoothPlatformCapabilities

  constructor(capabilities?: BluetoothPlatformCapabilities) {
    this.capabilities = capabilities === undefined ? StaticBluetoothCapabilityProvider.demoCapabilities() : capabilities
  }

  async getCapabilities(): Promise<BluetoothPlatformCapabilities> {
    return this.capabilities
  }

  static demoCapabilities(): BluetoothPlatformCapabilities {
    return {
      bleCentral: true,
      blePeripheral: false,
      classicSppClient: true,
      classicSppServer: false,
      bonding: true,
      rssi: true,
      mtu: true,
      phy: false,
      l2capChannel: false,
      extendedAdvertising: false,
      backgroundScan: false,
      multipleConnections: false,
      notes: ['Demo provider for mock scan and loopback validation.']
    }
  }
}
