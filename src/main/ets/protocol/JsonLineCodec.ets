import { BluetoothPacket, BluetoothProtocolCodec, DecodeResult, ProtocolFrameKind } from '../model/BluetoothTypes'
import { ByteUtils } from '../utils/ByteUtils'

export class JsonLineCodec implements BluetoothProtocolCodec {
  readonly protocolId: string = 'json-line-v1'

  encode(packet: BluetoothPacket): ArrayBuffer {
    const line = packet.kind + ',' + packet.command.toString() + ',' + packet.sequence.toString() + ',' +
      this.bytesToHex(packet.payload) + '\n'
    return ByteUtils.asciiToBuffer(line)
  }

  decode(buffer: ArrayBuffer): DecodeResult {
    const text = ByteUtils.bufferToAscii(buffer)
    const lines = text.split('\n')
    const packets: BluetoothPacket[] = []
    for (let index = 0; index < lines.length - 1; index++) {
      const parts = lines[index].split(',')
      if (parts.length !== 4) {
        continue
      }
      packets.push({
        kind: this.textToKind(parts[0]),
        command: Number(parts[1]),
        sequence: Number(parts[2]),
        payload: this.hexToBytes(parts[3])
      })
    }
    return {
      packets,
      rest: ByteUtils.asciiToBuffer(lines[lines.length - 1])
    }
  }

  private bytesToHex(buffer: ArrayBuffer): string {
    const bytes = new Uint8Array(buffer)
    let value = ''
    for (let index = 0; index < bytes.length; index++) {
      const part = bytes[index].toString(16)
      value += part.length === 1 ? '0' + part : part
    }
    return value
  }

  private hexToBytes(value: string): ArrayBuffer {
    const bytes: number[] = []
    for (let index = 0; index + 1 < value.length; index += 2) {
      bytes.push(Number.parseInt(value.substring(index, index + 2), 16))
    }
    return ByteUtils.fromNumbers(bytes)
  }

  private textToKind(value: string): ProtocolFrameKind {
    if (value === ProtocolFrameKind.Ack) {
      return ProtocolFrameKind.Ack
    }
    if (value === ProtocolFrameKind.Nak) {
      return ProtocolFrameKind.Nak
    }
    if (value === ProtocolFrameKind.Heartbeat) {
      return ProtocolFrameKind.Heartbeat
    }
    return ProtocolFrameKind.Data
  }
}
