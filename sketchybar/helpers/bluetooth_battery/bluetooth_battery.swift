// bluetooth_battery — one-shot reader for BLE devices that expose the GATT
// Battery Service (0x180F). macOS does not surface these (e.g. ZMK/QMK keyboards)
// via system_profiler/ioreg, so we read them directly with CoreBluetooth.
//
// Output: one line per Battery Level characteristic, "<label>=<percent>".
//   Cherry Plum R=42
//   Cherry Plum L=88
//
// A split keyboard exposes one Battery Service per half. Each half is reported
// separately and 0% is reported as 0%, never hidden. An earlier version of this
// helper collapsed the halves to the highest non-zero reading, on the assumption
// that 0 meant "peer half is off". That masked a genuinely flat half: with the
// central at 0% and the peripheral at 88%, the widget displayed 88% while the
// keyboard was dying. Worse, macOS responds to a BLE HID reporting 0% by polling
// its battery characteristic ~33 times a second, which saturates the connection
// and makes the keyboard appear to freeze. Seeing the low half early is the whole
// point of this helper.
//
// Halves are told apart by the Characteristic Presentation Format descriptor
// (0x2904), whose "description" field ZMK sets to 0x0106 ("main", the central)
// or 0x0108 ("auxiliary", a peripheral proxied by the central).
//
// Build: make   (or)
//   swiftc -O -o bin/bluetooth_battery bluetooth_battery.swift \
//     -framework CoreBluetooth -framework Foundation

import Foundation
import CoreBluetooth

let BATTERY_SERVICE = CBUUID(string: "180F")
let BATTERY_LEVEL = CBUUID(string: "2A19")
let PRESENTATION_FORMAT = CBUUID(string: "2904")
let TIMEOUT_SECONDS = 5.0

// CPF "description" values ZMK uses to tag which half a battery level belongs to.
let CPF_MAIN = 0x0106
let CPF_AUX = 0x0108

// Which physical half is the central, for devices where we know the build.
// Everything else falls back to the generic "main"/"aux" suffixes below.
// The Charybdis shield makes the right half the central
// (boards/shields/charybdis/Kconfig.defconfig), so main == R.
let HALF_LABELS: [String: (main: String, aux: String)] = [
    "Cherry Plum": (main: "R", aux: "L")
]
let DEFAULT_HALF_LABELS = (main: "main", aux: "aux")

private struct Reading {
    var percent: Int?
    var cpf: Int?
    let order: Int
}

final class Reader: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var central: CBCentralManager!
    private var peripherals: [CBPeripheral] = []
    private var readings: [UUID: [ObjectIdentifier: Reading]] = [:]
    private var discovered: [UUID: Int] = [:]

    func run() {
        central = CBCentralManager(delegate: self, queue: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + TIMEOUT_SECONDS) { [weak self] in
            self?.report()
        }
        RunLoop.main.run()
    }

    func centralManagerDidUpdateState(_ c: CBCentralManager) {
        switch c.state {
        case .poweredOn:
            let found = c.retrieveConnectedPeripherals(withServices: [BATTERY_SERVICE])
            if found.isEmpty { report() }
            for p in found {
                peripherals.append(p)
                p.delegate = self
                c.connect(p, options: nil)
            }
        case .unauthorized:
            FileHandle.standardError.write("bluetooth unauthorized\n".data(using: .utf8)!)
            exit(2)
        case .poweredOff:
            exit(3)
        default:
            break
        }
    }

    func centralManager(_ c: CBCentralManager, didConnect p: CBPeripheral) {
        p.discoverServices([BATTERY_SERVICE])
    }

    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        // A split device exposes several 0x180F primary services, so discover
        // characteristics on every one of them rather than just the first.
        for s in p.services ?? [] where s.uuid == BATTERY_SERVICE {
            p.discoverCharacteristics([BATTERY_LEVEL], for: s)
        }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
        for ch in s.characteristics ?? [] where ch.uuid == BATTERY_LEVEL {
            let order = discovered[p.identifier] ?? 0
            discovered[p.identifier] = order + 1
            readings[p.identifier, default: [:]][ObjectIdentifier(ch)] =
                Reading(percent: nil, cpf: nil, order: order)
            p.readValue(for: ch)
            p.discoverDescriptors(for: ch)
        }
    }

    func peripheral(_ p: CBPeripheral, didUpdateValueFor ch: CBCharacteristic, error: Error?) {
        guard ch.uuid == BATTERY_LEVEL, let b = ch.value?.first else { return }
        readings[p.identifier]?[ObjectIdentifier(ch)]?.percent = Int(b)
    }

    func peripheral(_ p: CBPeripheral, didDiscoverDescriptorsFor ch: CBCharacteristic, error: Error?) {
        for d in ch.descriptors ?? [] where d.uuid == PRESENTATION_FORMAT {
            p.readValue(for: d)
        }
    }

    func peripheral(_ p: CBPeripheral, didUpdateValueFor d: CBDescriptor, error: Error?) {
        guard d.uuid == PRESENTATION_FORMAT, let ch = d.characteristic else { return }
        // CPF layout: format(1) exponent(1) unit(2, LE) namespace(1) description(2, LE)
        guard let data = d.value as? Data, data.count >= 7 else { return }
        let description = Int(data[5]) | (Int(data[6]) << 8)
        readings[p.identifier]?[ObjectIdentifier(ch)]?.cpf = description
    }

    private var reported = false

    func report() {
        if reported { return }
        reported = true

        for p in peripherals {
            let name = p.name ?? "Unknown"
            guard let found = readings[p.identifier], !found.isEmpty else { continue }
            let ordered = found.values.sorted { $0.order < $1.order }

            // A device with a single battery level keeps the plain "<name>=<pct>"
            // form, so non-split devices are unaffected.
            if ordered.count == 1 {
                if let pct = ordered[0].percent { print("\(name)=\(pct)") }
                continue
            }

            let labels = HALF_LABELS[name] ?? DEFAULT_HALF_LABELS
            for r in ordered {
                guard let pct = r.percent else { continue }
                // Fall back to discovery order when the CPF is missing or
                // unreadable: ZMK registers the central's own service first.
                let suffix: String
                switch r.cpf {
                case .some(CPF_MAIN): suffix = labels.main
                case .some(CPF_AUX): suffix = labels.aux
                default: suffix = r.order == 0 ? labels.main : labels.aux
                }
                print("\(name) \(suffix)=\(pct)")
            }
        }
        exit(0)
    }
}

Reader().run()
