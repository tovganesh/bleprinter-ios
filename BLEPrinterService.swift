//
//  BLEPrinterService.swift
//  OneGreenDiary
//
//  Originally Created  - ( empty ;-) ) by Abhay Chaudhary on 1/26/16.
//  Reworked and made functional by V. Ganesh, added general framework for handing BLE printers
//
//  Copyright © 2016 OneGreenDiary Software Pvt. Ltd. 
// 
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation
import CoreBluetooth
import BluetoothKit

class BLEPrinterService : BKPeripheralDelegate, BKCentralDelegate, BKAvailabilityObserver, BKRemotePeripheralDelegate {
    
    let peripheral = BKPeripheral()
    let central = BKCentral()

    // The UUID for the white lable BLE printer, obtained using LighBlue app. 
    // The same may be obtained using any other Bluetooth explorer app.
    var serviceUUID = NSUUID(UUIDString: "E7810A71-73AE-499D-8C15-FAA9AEF0C3F2")
    var characteristicUUID = NSUUID(UUIDString: "BEF8D6C9-9C21-4C9E-B632-BD58C1009F9F")

    var deviceReady = false;
    
    var connectedDevice:BKRemotePeripheral?;
    
    internal init() {
        self.initCentral()
    }
   
    // set a new service UUID, need to call initCentral() after this 
    func setServiceUUID(suid: NSUUID) {
        self.serviceUUID = suid
    }
    
    // set a new characteristic UUID, need to call initCentral() after this 
    func setCharacteristicUUID(cuid: NSUUID) {
        self.characteristicUUID = cuid
    }
    
    func isDeviceReady() -> Bool {
        return self.deviceReady
    }
    
    func initCentral() {
        do {
            central.delegate = self;
            central.addAvailabilityObserver(self)
            
            let configuration = BKConfiguration(dataServiceUUID: serviceUUID!, dataServiceCharacteristicUUID: characteristicUUID!)
            try central.startWithConfiguration(configuration)
        } catch let error {
            print("ERROR - initCentral")
            print(error)
        }
    }
   
    // helper function to convert a hext string to NSData 
    func hexToNSData(string: String) -> NSData {
        let length = string.characters.count
        
        
        let rawData = UnsafeMutablePointer<CUnsignedChar>.alloc(length/2)
        var rawIndex = 0
        
        for var index = 0; index < length; index+=2{
            let single = NSMutableString()
            single.appendString(string.substringWithRange(Range(start:string.startIndex.advancedBy(index), end:string.startIndex.advancedBy(index+2))))
            rawData[rawIndex] = UInt8(single as String, radix:16)!
            rawIndex++
        }
        
        let data:NSData = NSData(bytes: rawData, length: length/2)
        rawData.dealloc(length/2)
        
        return data
    }
    
    func printLine(line: String) {
        if !self.deviceReady {
            return
        }
        
        let lineFeed = self.hexToNSData("0A")
        let printer  = self.connectedDevice!.getPeripheral()!
        
        printer.writeValue(line.dataUsingEncoding(NSUTF8StringEncoding)!, forCharacteristic: self.connectedDevice!.getCharacteristic()!, type: CBCharacteristicWriteType.WithResponse)
        
        printer.writeValue(lineFeed, forCharacteristic: self.connectedDevice!.getCharacteristic()!, type: CBCharacteristicWriteType.WithResponse)
    }
    
    func printToBuffer(line: String) {
        if !self.deviceReady {
            return
        }
        
        let printer  = self.connectedDevice!.getPeripheral()!
        
        printer.writeValue(line.dataUsingEncoding(NSUTF8StringEncoding)!, forCharacteristic: self.connectedDevice!.getCharacteristic()!, type: CBCharacteristicWriteType.WithResponse)
    }
    
    func printTab() {
        if !self.deviceReady {
            return
        }
        
        let tabFeed = self.hexToNSData("09")
        let printer  = self.connectedDevice!.getPeripheral()!
        
        printer.writeValue(tabFeed, forCharacteristic: self.connectedDevice!.getCharacteristic()!, type: CBCharacteristicWriteType.WithResponse)
    }
    
    func printLineFeed() {
        if !self.deviceReady {
            return
        }
        
        let tabFeed = self.hexToNSData("0A")
        let printer  = self.connectedDevice!.getPeripheral()!
        
        printer.writeValue(tabFeed, forCharacteristic: self.connectedDevice!.getCharacteristic()!, type: CBCharacteristicWriteType.WithResponse)
    }
    
    // actual scan function
    func scan() {
        central.scanContinuouslyWithChangeHandler({ changes, discoveries in
                print("Discovery List")
                print(discoveries)
                // assume that the first discovery is the printer we desire to connect,
                // in ideal world this is true, but in reality you may have additional checks to make
                if let firstPrinter =  discoveries.first {
                    if (self.connectedDevice != firstPrinter.remotePeripheral)  {
                        // if we are not already connected, connect to the printer device
                        self.central.connect(30, remotePeripheral: firstPrinter.remotePeripheral) { remotePeripheral, error in
                            if error == nil {
                                self.deviceReady = false; self.connectedDevice = nil;
                                print("Connection DONE")
                                print(remotePeripheral)
                                print(error)
                            
                                remotePeripheral.delegate = self
                            
                                if remotePeripheral.state == BKRemotePeripheral.State.Connected {
                                    print("REMOTE connected")
                                    
                                    print(remotePeripheral.identifier)
                                    print(remotePeripheral.getConfiguration())
                                    
                                    // once connected, set appropriate flags 
                                    self.deviceReady = true
                                    self.connectedDevice = firstPrinter.remotePeripheral
                                }
                            }
                        }
                    }
                } else if discoveries.count == 0 && self.connectedDevice != nil {
                    self.deviceReady = true
                    // print("WRITING")
                    // self.printLine("OneGreenDiary")
                    // print("DONE WRITING")
                }
            }, stateHandler: { newState in
                if newState == .Scanning {
                    print("Scanning")
                } else if newState == .Stopped {
                    print("Stopped")
                }
            }, duration: 5, inBetweenDelay: 10, errorHandler: { error in
                print("ERROR - scan")
                print(error)
            })
    }
    
    func peripheral(peripheral: BKPeripheral, remoteCentralDidConnect remoteCentral: BKRemoteCentral) {
        //print("CONNECT")
        //print(peripheral)
    }
    
    func peripheral(peripheral: BKPeripheral, remoteCentralDidDisconnect remoteCentral: BKRemoteCentral) {
        //print("DISCONNECT")
        //print(peripheral)
    }
    
    func central(central: BKCentral, remotePeripheralDidDisconnect remotePeripheral: BKRemotePeripheral) {
        //print("CENTRAL")
        //print(central)
    }
    
    func availabilityObserver(availabilityObservable: BKAvailabilityObservable, availabilityDidChange availability: BKAvailability) {
        print("AVAILABLE - 1")
        // scan auto starts on availability of the bluetooth device
        scan()
    }
    
    func availabilityObserver(availabilityObservable: BKAvailabilityObservable, unavailabilityCauseDidChange unavailabilityCause: BKUnavailabilityCause) {
        print("AVAILABLE - 2")
        // scan auto starts on availability of the bluetooth device
        scan()
    }
    
    func remotePeripheral(remotePeripheral: BKRemotePeripheral, didUpdateName name: String) {
        // print("NAME CHANGE \(name)")
    }
    
    func remotePeripheral(remotePeripheral: BKRemotePeripheral, didSendArbitraryData data: NSData) {
        // print("REMOTE DATA")
        // print(remotePeripheral)
        // print(data)
    }
    
    // helper functions
    var CHARS_PER_LINE = 30
    
    func centerText(text: String, spaceChar: NSString = " ") -> String {
        let nChars = text.length
        
        // print(String(format: "Item%22s%3s", " ".cStringUsingEncoding(NSASCIIStringEncoding), "Qty".cStringUsingEncoding(NSASCIIStringEncoding)))
        
        if nChars >= CHARS_PER_LINE {
            return text.substringToIndex(text.startIndex.advancedBy(CHARS_PER_LINE))
        } else {
            let totalSpaces = CHARS_PER_LINE - nChars
            let spacesOnEachSide = totalSpaces / 2
            let spacesString = "%\(spacesOnEachSide)s"
            
            let centeredString = String(format: spacesString + text + spacesString, spaceChar.cStringUsingEncoding(NSASCIIStringEncoding), spaceChar.cStringUsingEncoding(NSASCIIStringEncoding))
            
            return centeredString
        }
    }
    
    func rowText(colText: [String], colWidth: [Int], padSpace: [String], spaceChar: NSString = " ") -> String {
        let nCols = colText.count
        
        if nCols != colWidth.count {
            return ""
        }
        
        if nCols != padSpace.count {
            return ""
        }
        
        let totalColWidth = colWidth.reduce(0, combine: +)
        
        if totalColWidth > CHARS_PER_LINE {
            return ""
        }
        
        var rowLine = ""
        
        for var cidx=0; cidx<nCols; cidx++ {
            let ct = colText[cidx]
            let cw = colWidth[cidx]
            let ctw = ct.length
            
            if ctw > cw {
                // simply truncate text to fit
                let cutText = ct.substringToIndex(ct.startIndex.advancedBy(cw+1))
                rowLine += cutText
            } else {
                var totalSpaces = cw - ctw + 1
                var spacesString = "%\(totalSpaces)s"
                
                // this is normally padded right, left aligned
                if padSpace[cidx] == "R" {
                    let colLineText = String(format: ct + spacesString, spaceChar.cStringUsingEncoding(NSASCIIStringEncoding))
                    rowLine += colLineText
                } else if padSpace[cidx] == "L" {
                    let colLineText = String(format: spacesString + ct, spaceChar.cStringUsingEncoding(NSASCIIStringEncoding))
                    rowLine += colLineText
                } else if padSpace[cidx] == "C" {
                    let spacesOnEachSide = totalSpaces / 2
                    spacesString = "%\(spacesOnEachSide)s"
                    
                    let colLineText = String(format: spacesString + ct + spacesString, spaceChar.cStringUsingEncoding(NSASCIIStringEncoding), spaceChar.cStringUsingEncoding(NSASCIIStringEncoding))
                    rowLine += colLineText
                }
            }
        }
        
        return rowLine
    }
}
