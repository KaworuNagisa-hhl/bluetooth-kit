import {
  BluetoothDeviceSnapshot,
  BluetoothScanConfig,
  BluetoothScanFilter,
  BluetoothScanner,
  BluetoothScanMode
} from '../model/BluetoothTypes'
import { HarmonyBluetoothScanAdapter } from './HarmonyBluetoothAdapters'

export class HarmonyBluetoothScanner implements BluetoothScanner {
  private readonly adapter: HarmonyBluetoothScanAdapter
  private running: boolean = false
  private seenDeviceIds: string[] = []
  private currentMode: BluetoothScanMode = BluetoothScanMode.Mixed

  constructor(adapter: HarmonyBluetoothScanAdapter) {
    this.adapter = adapter
  }

  async startScan(config: BluetoothScanConfig, listener: (device: BluetoothDeviceSnapshot) => void): Promise<void> {
    this.running = true
    this.currentMode = config.mode
    this.seenDeviceIds = []
    setTimeout(() => {
      this.stopScan()
    }, config.timeoutMs)
    await this.adapter.start(config, (device: BluetoothDeviceSnapshot) => {
      if (!this.running) {
        return
      }
      if (!config.allowDuplicates && this.seenDeviceIds.indexOf(device.deviceId) >= 0) {
        return
      }
      if (!this.matches(config, device)) {
        return
      }
      this.seenDeviceIds.push(device.deviceId)
      listener(device)
    })
  }

  async stopScan(): Promise<void> {
    if (!this.running) {
      return
    }
    this.running = false
    await this.adapter.stop(this.currentMode)
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
