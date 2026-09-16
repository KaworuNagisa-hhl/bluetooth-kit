export class HarmonyBluetoothPermissionGuide {
  static accessBluetoothPermission(): string {
    return 'ohos.permission.ACCESS_BLUETOOTH'
  }

  static legacyBluetoothPermissions(): string[] {
    return [
      'ohos.permission.USE_BLUETOOTH',
      'ohos.permission.DISCOVER_BLUETOOTH',
      'ohos.permission.LOCATION'
    ]
  }

  static moduleJson5Snippet(): string {
    return '"requestPermissions": [{ "name": "ohos.permission.ACCESS_BLUETOOTH" }]'
  }
}
