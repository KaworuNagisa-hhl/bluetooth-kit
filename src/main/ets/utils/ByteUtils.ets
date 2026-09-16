export class ByteUtils {
  static empty(): ArrayBuffer {
    return new ArrayBuffer(0)
  }

  static concat(first: ArrayBuffer, second: ArrayBuffer): ArrayBuffer {
    const buffer = new ArrayBuffer(first.byteLength + second.byteLength)
    const output = new Uint8Array(buffer)
    output.set(new Uint8Array(first), 0)
    output.set(new Uint8Array(second), first.byteLength)
    return buffer
  }

  static slice(buffer: ArrayBuffer, start: number, end?: number): ArrayBuffer {
    const source = new Uint8Array(buffer)
    const resolvedEnd = end === undefined ? source.length : end
    const sliced = new ArrayBuffer(resolvedEnd - start)
    const output = new Uint8Array(sliced)
    for (let index = start; index < resolvedEnd; index++) {
      output[index - start] = source[index]
    }
    return sliced
  }

  static fromNumbers(values: number[]): ArrayBuffer {
    const buffer = new ArrayBuffer(values.length)
    const output = new Uint8Array(buffer)
    for (let index = 0; index < values.length; index++) {
      output[index] = values[index] & 0xFF
    }
    return buffer
  }

  static toNumbers(buffer: ArrayBuffer): number[] {
    const source = new Uint8Array(buffer)
    const values: number[] = []
    for (let index = 0; index < source.length; index++) {
      values.push(source[index])
    }
    return values
  }

  static asciiToBuffer(value: string): ArrayBuffer {
    const buffer = new ArrayBuffer(value.length)
    const output = new Uint8Array(buffer)
    for (let index = 0; index < value.length; index++) {
      output[index] = value.charCodeAt(index) & 0x7F
    }
    return buffer
  }

  static bufferToAscii(buffer: ArrayBuffer): string {
    const source = new Uint8Array(buffer)
    let text = ''
    for (let index = 0; index < source.length; index++) {
      text += String.fromCharCode(source[index])
    }
    return text
  }
}
