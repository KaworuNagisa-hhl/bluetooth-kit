import { BluetoothPacket, BluetoothProtocolCodec, DecodeResult, ProtocolFrameKind } from '../model/BluetoothTypes'
import { ByteUtils } from '../utils/ByteUtils'
import { Crc16 } from './Crc16'

export class LengthPrefixedCodec implements BluetoothProtocolCodec {
  readonly protocolId: string = 'length-prefixed-v1'
  private readonly magicA: number = 0xA5
  private readonly magicB: number = 0x5A

  encode(packet: BluetoothPacket): ArrayBuffer {
    const payload = new Uint8Array(packet.payload)
    const length = payload.length
    const frameWithoutCrcBuffer = new ArrayBuffer(7 + length)
    const frameWithoutCrc = new Uint8Array(frameWithoutCrcBuffer)
    frameWithoutCrc[0] = this.magicA
    frameWithoutCrc[1] = this.magicB
    frameWithoutCrc[2] = this.kindToByte(packet.kind)
    frameWithoutCrc[3] = packet.command & 0xFF
    frameWithoutCrc[4] = packet.sequence & 0xFF
    frameWithoutCrc[5] = length & 0xFF
    frameWithoutCrc[6] = (length >> 8) & 0xFF
    for (let index = 0; index < payload.length; index++) {
      frameWithoutCrc[7 + index] = payload[index]
    }
    const crc = Crc16.modbus(frameWithoutCrcBuffer)
    const frameBuffer = new ArrayBuffer(frameWithoutCrc.length + 2)
    const frame = new Uint8Array(frameBuffer)
    frame.set(frameWithoutCrc, 0)
    frame[frame.length - 2] = crc & 0xFF
    frame[frame.length - 1] = (crc >> 8) & 0xFF
    return frameBuffer
  }

  decode(buffer: ArrayBuffer): DecodeResult {
    const source = new Uint8Array(buffer)
    const packets: BluetoothPacket[] = []
    let offset = 0
    while (offset + 9 <= source.length) {
      if (source[offset] !== this.magicA || source[offset + 1] !== this.magicB) {
        offset++
        continue
      }
      const length = source[offset + 5] | (source[offset + 6] << 8)
      const frameLength = 9 + length
      if (offset + frameLength > source.length) {
        break
      }
      const frameWithoutCrc = ByteUtils.slice(buffer, offset, offset + frameLength - 2)
      const expected = source[offset + frameLength - 2] | (source[offset + frameLength - 1] << 8)
      const actual = Crc16.modbus(frameWithoutCrc)
      if (expected !== actual) {
        offset++
        continue
      }
      packets.push({
        kind: this.byteToKind(source[offset + 2]),
        command: source[offset + 3],
        sequence: source[offset + 4],
        payload: ByteUtils.slice(buffer, offset + 7, offset + 7 + length)
      })
      offset += frameLength
    }
    return {
      packets,
      rest: ByteUtils.slice(buffer, offset)
    }
  }

  private kindToByte(kind: ProtocolFrameKind): number {
    if (kind === ProtocolFrameKind.Ack) {
      return 0x02
    }
    if (kind === ProtocolFrameKind.Nak) {
      return 0x03
    }
    if (kind === ProtocolFrameKind.Heartbeat) {
      return 0x04
    }
    return 0x01
  }

  private byteToKind(value: number): ProtocolFrameKind {
    if (value === 0x02) {
      return ProtocolFrameKind.Ack
    }
    if (value === 0x03) {
      return ProtocolFrameKind.Nak
    }
    if (value === 0x04) {
      return ProtocolFrameKind.Heartbeat
    }
    return ProtocolFrameKind.Data
  }
}
