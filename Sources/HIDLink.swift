import Foundation
import IOKit.hid

/// Talks to the keyboard's lighting channel (the vendor-defined HID interface).
final class HIDLink {
    private let vendorID = 0x2F0E
    private let productIDs: Set<Int> = [0x0102, 0x0103]
    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private let chunk = 57

    var isConnected: Bool { device != nil }

    /// Tries to find and open the keyboard. Safe to call repeatedly.
    @discardableResult
    func connect() -> Bool {
        if device != nil { return true }
        let mgr = manager ?? IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        manager = mgr
        IOHIDManagerSetDeviceMatching(mgr, [kIOHIDVendorIDKey: vendorID] as CFDictionary)
        IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        let found = (IOHIDManagerCopyDevices(mgr) as? Set<IOHIDDevice>) ?? []
        for d in found {
            let pid = (IOHIDDeviceGetProperty(d, kIOHIDProductIDKey as CFString) as? Int) ?? 0
            let page = (IOHIDDeviceGetProperty(d, kIOHIDPrimaryUsagePageKey as CFString) as? Int) ?? 0
            guard productIDs.contains(pid), page == 0xFF00 else { continue }
            if IOHIDDeviceOpen(d, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess {
                device = d
                return true
            }
        }
        return false
    }

    func disconnect() {
        if let d = device { IOHIDDeviceClose(d, IOOptionBits(kIOHIDOptionsTypeNone)) }
        device = nil
    }

    /// Sends one request, split into 57-byte pieces exactly as the keyboard expects.
    @discardableResult
    func send(_ buf: [UInt8]) -> Bool {
        guard let d = device, !buf.isEmpty else { return false }
        let total = buf.count
        var offset = 0
        while offset < total {
            let part = Array(buf[offset..<min(offset + chunk, total)])
            var pkt: [UInt8] = [buf[0],
                                UInt8(total & 0xFF), UInt8((total >> 8) & 0xFF), UInt8((total >> 16) & 0xFF),
                                UInt8(offset & 0xFF), UInt8((offset >> 8) & 0xFF), UInt8((offset >> 16) & 0xFF)]
            pkt += part
            pkt += [UInt8](repeating: 0, count: chunk - part.count)
            let r = pkt.withUnsafeBufferPointer {
                IOHIDDeviceSetReport(d, kIOHIDReportTypeOutput, 0, $0.baseAddress!, $0.count)
            }
            if r != kIOReturnSuccess {
                disconnect()
                return false
            }
            offset += chunk
        }
        return true
    }

    func sendFrame(_ colours: [RGB]) -> Bool {
        var data: [UInt8] = [0x0F, 0x03]
        data.reserveCapacity(2 + colours.count * 3)
        for c in colours { data += [c.r, c.g, c.b] }
        return send(data)
    }

    func keepAlive() -> Bool { send([0x07]) }
}
