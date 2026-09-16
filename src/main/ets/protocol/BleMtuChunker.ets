import { ByteUtils } from '../utils/ByteUtils'

export class BleMtuChunker {
  static readonly DEFAULT_ATT_PAYLOAD: number = 20

  static chunk(buffer: ArrayBuffer, mtu?: number): ArrayBuffer[] {
    const payloadSize = BleMtuChunker.resolvePayloadSize(mtu)
    const chunks: ArrayBuffer[] = []
    let offset = 0
    while (offset < buffer.byteLength) {
      const end = Math.min(offset + payloadSize, buffer.byteLength)
      chunks.push(ByteUtils.slice(buffer, offset, end))
      offset = end
    }
    if (chunks.length === 0) {
      chunks.push(ByteUtils.empty())
    }
    return chunks
  }

  private static resolvePayloadSize(mtu?: number): number {
    if (mtu === undefined || mtu <= 3) {
      return BleMtuChunker.DEFAULT_ATT_PAYLOAD
    }
    return mtu - 3
  }
}
