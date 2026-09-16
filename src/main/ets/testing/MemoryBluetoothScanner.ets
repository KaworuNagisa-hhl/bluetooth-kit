import {
  BluetoothDeviceSnapshot,
  BluetoothScanConfig,
  BluetoothScanFilter,
  BluetoothScanner
} from '../model/BluetoothTypes'

export class MemoryBluetoothScanner implements BluetoothScanner {
  private readonly devices: BluetoothDeviceSnapshot[]
  private running: boolean = false

  constructor(devices: BluetoothDeviceSnapshot[]) {
    this.devices = devices
  }

  async startScan(config: BluetoothScanConfig, listener: (device: BluetoothDeviceSnapshot) => void): Promise<void> {
    this.running = true
    const seenDeviceIds: string[] = []
    setTimeout(() => {
      this.running = false
    }, config.timeoutMs)
    for (let index = 0; index < this.devices.length; index++) {
      if (!this.running) {
        return
      }
      const device = this.devices[index]
      if (!config.allowDuplicates && seenDeviceIds.indexOf(device.deviceId) >= 0) {
        continue
      }
      if (this.matches(config, device)) {
        seenDeviceIds.push(device.deviceId)
        listener(device)
      }
    }
  }

  async stopScan(): Promise<void> {
    this.running = false
  }

  private matches(config: BluetoothScanConfig, device: BluetoothDeviceSnapshot): boolean {
    if (!config.filters || config.filters.length === 0) {
      return true
    }
    for (let index = 0; index < config.filters.length; index++) {
      if (this.matchesFilter(config.filters[index], device)) {
        return true
      }
    }
    return false
  }

  private matchesFilter(filter: BluetoothScanFilter, device: BluetoothDeviceSnapshot): boolean {
    if (filter.namePrefix && (!device.name || device.name.indexOf(filter.namePrefix) !== 0)) {
      return false
    }
    if (filter.manufacturerId !== undefined && device.manufacturerId !== filter.manufacturerId) {
      return false
    }
    if (filter.serviceUuid && !this.hasServiceUuid(device, filter.serviceUuid)) {
      return false
    }
    return true
  }

  private hasServiceUuid(device: BluetoothDeviceSnapshot, serviceUuid: string): boolean {
    if (!device.serviceUuids) {
      return false
    }
    for (let index = 0; index < device.serviceUuids.length; index++) {
      if (device.serviceUuids[index] === serviceUuid) {
        return true
      }
    }
    return false
  }
}
