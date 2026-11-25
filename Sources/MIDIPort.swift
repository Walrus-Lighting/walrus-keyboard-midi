import Foundation
import CoreMIDI

/// A virtual two-way MIDI controller called "Walrus Keyboard MIDI". Lightkey sees one device with an input and an
/// output of the same name, so it treats it as a controller and sends feedback back to it.
final class MIDIPort {
    static let deviceName = "Walrus Keyboard MIDI"

    private var client = MIDIClientRef()
    private var source = MIDIEndpointRef()
    private var destination = MIDIEndpointRef()
    private(set) var isReady = false

    /// Called for every note Lightkey sends back: (note, isOn).
    var onNote: ((Int, Bool) -> Void)?

    func start() {
        guard !isReady else { return }
        guard MIDIClientCreate("Walrus Keyboard MIDI" as CFString, nil, nil, &client) == noErr else { return }
        guard MIDISourceCreate(client, MIDIPort.deviceName as CFString, &source) == noErr else { return }
        let status = MIDIDestinationCreateWithBlock(client, MIDIPort.deviceName as CFString, &destination) { [weak self] list, _ in
            self?.handle(list)
        }
        guard status == noErr else { return }
        isReady = true
    }

    func stop() {
        guard isReady else { return }
        MIDIEndpointDispose(source)
        MIDIEndpointDispose(destination)
        MIDIClientDispose(client)
        isReady = false
    }

    func send(note: Int, on: Bool) {
        guard isReady else { return }
        var buffer = [UInt8](repeating: 0, count: 256)
        let bytes: [UInt8] = [on ? 0x90 : 0x80, UInt8(note & 0x7F), on ? 127 : 0]
        buffer.withUnsafeMutableBytes { raw in
            let list = raw.bindMemory(to: MIDIPacketList.self).baseAddress!
            let packet = MIDIPacketListInit(list)
            _ = MIDIPacketListAdd(list, 256, packet, 0, bytes.count, bytes)
            MIDIReceived(source, list)
        }
    }

    /// Sends one raw message, e.g. the MIDI clock byte 0xF8.
    func sendRaw(_ bytes: [UInt8]) {
        guard isReady else { return }
        var buffer = [UInt8](repeating: 0, count: 64)
        buffer.withUnsafeMutableBytes { raw in
            let list = raw.bindMemory(to: MIDIPacketList.self).baseAddress!
            let packet = MIDIPacketListInit(list)
            _ = MIDIPacketListAdd(list, 64, packet, 0, bytes.count, bytes)
            MIDIReceived(source, list)
        }
    }

    private func handle(_ list: UnsafePointer<MIDIPacketList>) {
        var packet = list.pointee.packet
        for _ in 0..<list.pointee.numPackets {
            let length = Int(packet.length)
            let bytes = withUnsafeBytes(of: packet.data) { Array($0.prefix(length)) }
            var i = 0
            while i + 2 < bytes.count {
                let status = bytes[i] & 0xF0
                if status == 0x90 || status == 0x80 {
                    let note = Int(bytes[i + 1])
                    let isOn = status == 0x90 && bytes[i + 2] > 0
                    DispatchQueue.main.async { [weak self] in self?.onNote?(note, isOn) }
                    i += 3
                } else {
                    i += 1
                }
            }
            packet = MIDIPacketNext(&packet).pointee
        }
    }
}
