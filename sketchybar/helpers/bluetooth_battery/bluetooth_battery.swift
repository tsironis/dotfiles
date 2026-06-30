// bluetooth_battery — one-shot reader for BLE devices that expose the GATT
// Battery Service (0x180F). macOS does not surface these (e.g. ZMK/QMK keyboards)
// via system_profiler/ioreg, so we read them directly with CoreBluetooth.
//
// Output: one line per device, "<name>=<percent>", e.g. "Cherry Plum=52".
// For split devices with multiple Battery Level characteristics, the highest
// non-zero reading is used (matches what macOS displays; 0 = an off/peer half).
//
// Build: swiftc -O -o bin/bluetooth_battery bluetooth_battery.swift \
//          -framework CoreBluetooth -framework Foundation

import Foundation
import CoreBluetooth

let BATTERY_SERVICE = CBUUID(string: "180F")
let BATTERY_LEVEL = CBUUID(string: "2A19")
let TIMEOUT_SECONDS = 4.0

final class Reader: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var central: CBCentralManager!
    private var peripherals: [CBPeripheral] = []
    private var best: [UUID: Int] = [:]   // device -> highest battery % seen

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
        for s in p.services ?? [] where s.uuid == BATTERY_SERVICE {
            p.discoverCharacteristics([BATTERY_LEVEL], for: s)
        }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
        for ch in s.characteristics ?? [] where ch.uuid == BATTERY_LEVEL {
            p.readValue(for: ch)
        }
    }

    func peripheral(_ p: CBPeripheral, didUpdateValueFor ch: CBCharacteristic, error: Error?) {
        guard ch.uuid == BATTERY_LEVEL, let b = ch.value?.first else { return }
        let pct = Int(b)
        if pct > (best[p.identifier] ?? 0) { best[p.identifier] = pct }
    }

    private var reported = false
    func report() {
        if reported { return }
        reported = true
        for p in peripherals {
            let name = p.name ?? "Unknown"
            if let pct = best[p.identifier], pct > 0 {
                print("\(name)=\(pct)")
            }
        }
        exit(0)
    }
}

Reader().run()
