export class Crc16 {
  static modbus(buffer: ArrayBuffer): number {
    const bytes = new Uint8Array(buffer)
    let crc = 0xFFFF
    for (let index = 0; index < bytes.length; index++) {
      crc = crc ^ bytes[index]
      for (let bit = 0; bit < 8; bit++) {
        const carry = crc & 0x0001
        crc = crc >> 1
        if (carry !== 0) {
          crc = crc ^ 0xA001
        }
      }
    }
    return crc & 0xFFFF
  }
}
