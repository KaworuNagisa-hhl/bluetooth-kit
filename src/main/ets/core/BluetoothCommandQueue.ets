import {
  BluetoothError,
  BluetoothPacket,
  BluetoothProtocolCodec,
  BluetoothTransport,
  CommandOptions,
  CommandResult,
  ProtocolFrameKind
} from '../model/BluetoothTypes'
import { ByteUtils } from '../utils/ByteUtils'

interface PendingCommand {
  request: BluetoothPacket
  options: CommandOptions
  attempts: number
  resolve: (result: CommandResult) => void
}

export class BluetoothCommandQueue {
  private transport?: BluetoothTransport
  private codec?: BluetoothProtocolCodec
  private defaultTimeoutMs: number = 3000
  private defaultRetryCount: number = 0
  private retryBackoffMs: number = 0
  private queue: PendingCommand[] = []
  private active?: PendingCommand

  bind(transport: BluetoothTransport, codec: BluetoothProtocolCodec): void {
    this.transport = transport
    this.codec = codec
  }

  configure(defaultTimeoutMs: number, defaultRetryCount: number, retryBackoffMs: number): void {
    this.defaultTimeoutMs = defaultTimeoutMs
    this.defaultRetryCount = defaultRetryCount
    this.retryBackoffMs = retryBackoffMs
  }

  enqueue(request: BluetoothPacket, options: CommandOptions): Promise<CommandResult> {
    return new Promise<CommandResult>((resolve) => {
      this.queue.push({ request, options, attempts: 0, resolve })
      this.drain()
    })
  }

  handlePacket(packet: BluetoothPacket): boolean {
    if (!this.active || !this.active.options.expectAck) {
      return false
    }
    if (packet.sequence !== this.active.request.sequence) {
      return false
    }
    const expectedCommand = this.active.options.expectedResponseCommand === undefined ?
      this.active.request.command : this.active.options.expectedResponseCommand
    if (packet.command !== expectedCommand) {
      return false
    }
    if (packet.kind !== ProtocolFrameKind.Ack && packet.kind !== ProtocolFrameKind.Data) {
      return false
    }
    const done = this.active
    this.active = undefined
    done.resolve({
      request: done.request,
      response: packet,
      attempts: done.attempts,
      timedOut: false
    })
    this.drain()
    return true
  }

  clear(): void {
    while (this.queue.length > 0) {
      const pending = this.queue.shift()
      if (pending) {
        pending.resolve({ request: pending.request, attempts: pending.attempts, timedOut: true })
      }
    }
    if (this.active) {
      const active = this.active
      this.active = undefined
      active.resolve({ request: active.request, attempts: active.attempts, timedOut: true })
    }
  }

  private drain(): void {
    if (this.active || this.queue.length === 0) {
      return
    }
    const pending = this.queue.shift()
    if (!pending) {
      return
    }
    this.active = pending
    this.sendActive()
  }

  private async sendActive(): Promise<void> {
    if (!this.active || !this.transport || !this.codec) {
      return
    }
    const pending = this.active
    pending.attempts += 1
    try {
      await this.transport.write(this.codec.encode(pending.request))
    } catch (err) {
      const error: BluetoothError = {
        code: 'WRITE_FAILED',
        message: err instanceof Error ? err.message : 'Bluetooth write failed.'
      }
      this.active = undefined
      pending.resolve({
        request: pending.request,
        attempts: pending.attempts,
        timedOut: false,
        error
      })
      this.drain()
      return
    }
    if (!pending.options.expectAck) {
      this.active = undefined
      pending.resolve({
        request: pending.request,
        attempts: pending.attempts,
        timedOut: false
      })
      this.drain()
      return
    }
    this.waitForResponse(pending)
  }

  private waitForResponse(pending: PendingCommand): void {
    const timeoutMs = pending.options.timeoutMs === undefined ? this.defaultTimeoutMs : pending.options.timeoutMs
    setTimeout(() => {
      if (this.active !== pending) {
        return
      }
      const retryCount = pending.options.retryCount === undefined ? this.defaultRetryCount : pending.options.retryCount
      if (pending.attempts <= retryCount) {
        setTimeout(() => this.sendActive(), this.retryBackoffMs)
        return
      }
      this.active = undefined
      pending.resolve({
        request: pending.request,
        attempts: pending.attempts,
        timedOut: true
      })
      this.drain()
    }, timeoutMs)
  }
}
