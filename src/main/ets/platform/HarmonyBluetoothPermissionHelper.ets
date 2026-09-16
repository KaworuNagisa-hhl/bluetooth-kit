import { BluetoothError } from '../model/BluetoothTypes'

export interface HarmonyBluetoothPermissionState {
  bluetoothGranted: boolean
  missingPermissions: string[]
}

export interface HarmonyBluetoothPermissionAdapter {
  check(permissions: string[]): Promise<HarmonyBluetoothPermissionState>
  request(permissions: string[]): Promise<HarmonyBluetoothPermissionState>
}

export class HarmonyBluetoothPermissionHelper {
  static readonly ACCESS_BLUETOOTH: string = 'ohos.permission.ACCESS_BLUETOOTH'
  private readonly adapter: HarmonyBluetoothPermissionAdapter
  private readonly permissions: string[]

  constructor(adapter: HarmonyBluetoothPermissionAdapter, permissions?: string[]) {
    this.adapter = adapter
    this.permissions = permissions === undefined ? [HarmonyBluetoothPermissionHelper.ACCESS_BLUETOOTH] : permissions
  }

  async check(): Promise<HarmonyBluetoothPermissionState> {
    return this.adapter.check(this.permissions)
  }

  async request(): Promise<HarmonyBluetoothPermissionState> {
    return this.adapter.request(this.permissions)
  }

  toError(state: HarmonyBluetoothPermissionState): BluetoothError | undefined {
    if (state.bluetoothGranted) {
      return undefined
    }
    return {
      code: 'BLUETOOTH_PERMISSION_DENIED',
      message: 'Bluetooth permission denied: ' + state.missingPermissions.join(', ')
    }
  }
}
