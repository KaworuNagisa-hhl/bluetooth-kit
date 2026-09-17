import { describe, it, expect } from '@ohos/hypium'
import { BleMtuChunker, ByteUtils, Crc16, LengthPrefixedCodec, ProtocolFrameKind } from 'bluetooth_kit'

export default function localUnitTest() {
  describe('BluetoothKit', () => {
    it('keeps_crc16_modbus_contract', 0, () => {
      const crc = Crc16.modbus(ByteUtils.asciiToBuffer('123456789'))
      expect(crc).assertEqual(0x4B37)
    })

    it('decodes_sticky_and_half_packets', 0, () => {
      const codec = new LengthPrefixedCodec()
      const first = codec.encode({
        kind: ProtocolFrameKind.Data,
        command: 1,
        sequence: 1,
        payload: ByteUtils.fromNumbers([1, 2, 3])
      })
      const second = codec.encode({
        kind: ProtocolFrameKind.Ack,
        command: 1,
        sequence: 1,
        payload: ByteUtils.empty()
      })
      const half = ByteUtils.slice(second, 0, 4)
      const decoded = codec.decode(ByteUtils.concat(first, half))
      expect(decoded.packets.length).assertEqual(1)
      expect(decoded.rest.byteLength).assertEqual(4)
      const completed = codec.decode(ByteUtils.concat(decoded.rest, ByteUtils.slice(second, 4)))
      expect(completed.packets.length).assertEqual(1)
      expect(completed.packets[0].kind).assertEqual(ProtocolFrameKind.Ack)
    })

    it('chunks_ble_payload_by_mtu_minus_att_header', 0, () => {
      const chunks = BleMtuChunker.chunk(ByteUtils.fromNumbers([1, 2, 3, 4, 5, 6]), 6)
      expect(chunks.length).assertEqual(2)
      expect(chunks[0].byteLength).assertEqual(3)
    })
  })
}
