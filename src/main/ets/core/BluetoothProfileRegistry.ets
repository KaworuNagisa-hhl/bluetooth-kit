import {
  BluetoothBearer,
  BluetoothDeviceProfile,
  BluetoothError,
  BluetoothProtocolCodec
} from '../model/BluetoothTypes'

export class BluetoothProfileRegistry {
  private readonly profiles: BluetoothDeviceProfile[]
  private readonly codecs: BluetoothProtocolCodec[]

  constructor(profiles: BluetoothDeviceProfile[], codecs: BluetoothProtocolCodec[]) {
    this.profiles = profiles
    this.codecs = codecs
  }

  getProfiles(): BluetoothDeviceProfile[] {
    return this.profiles.slice()
  }

  findProfile(profileId: string): BluetoothDeviceProfile | undefined {
    for (let index = 0; index < this.profiles.length; index++) {
      if (this.profiles[index].profileId === profileId) {
        return this.profiles[index]
      }
    }
    return undefined
  }

  findCodec(protocolId: string): BluetoothProtocolCodec | undefined {
    for (let index = 0; index < this.codecs.length; index++) {
      if (this.codecs[index].protocolId === protocolId) {
        return this.codecs[index]
      }
    }
    return undefined
  }

  validate(): BluetoothError[] {
    const errors: BluetoothError[] = []
    this.validateProfiles(errors)
    this.validateCodecs(errors)
    return errors
  }

  private validateProfiles(errors: BluetoothError[]): void {
    const profileIds: string[] = []
    for (let index = 0; index < this.profiles.length; index++) {
      const profile = this.profiles[index]
      if (profile.profileId.length === 0) {
        errors.push({ code: 'PROFILE_ID_EMPTY', message: 'profileId must not be empty.' })
      }
      if (profileIds.indexOf(profile.profileId) >= 0) {
        errors.push({ code: 'PROFILE_ID_DUPLICATED', message: 'Duplicated profileId: ' + profile.profileId })
      }
      profileIds.push(profile.profileId)
      if (profile.bearer === BluetoothBearer.BleGatt && !profile.ble) {
        errors.push({ code: 'BLE_ENDPOINT_MISSING', message: 'BLE profile requires ble endpoint: ' + profile.profileId })
      }
      if (profile.bearer === BluetoothBearer.ClassicSpp && !profile.classic) {
        errors.push({ code: 'CLASSIC_ENDPOINT_MISSING', message: 'Classic profile requires classic endpoint: ' + profile.profileId })
      }
      if (profile.policy.connectTimeoutMs <= 0 || profile.policy.commandTimeoutMs <= 0) {
        errors.push({ code: 'POLICY_TIMEOUT_INVALID', message: 'Timeout values must be positive: ' + profile.profileId })
      }
    }
  }

  private validateCodecs(errors: BluetoothError[]): void {
    const codecIds: string[] = []
    for (let index = 0; index < this.codecs.length; index++) {
      const codecId = this.codecs[index].protocolId
      if (codecId.length === 0) {
        errors.push({ code: 'CODEC_ID_EMPTY', message: 'protocolId must not be empty.' })
      }
      if (codecIds.indexOf(codecId) >= 0) {
        errors.push({ code: 'CODEC_ID_DUPLICATED', message: 'Duplicated protocolId: ' + codecId })
      }
      codecIds.push(codecId)
    }
  }
}
