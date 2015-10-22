//
//  BLE.swift
//  BLETestSwift
//
//  Created by PLEN on 2015/07/16.
//  Copyright (c) 2015 PLEN Project Company Ltd. and Yugo KAJIWARA All rights reserved.
//
//  This software is released under the MIT License.

import Foundation
import CoreBluetooth

protocol PlenMotionInstallDelegate {
    func MessageFormBLEProcess(message: String!)
    func PlenConnected(isError: Bool)
    func PlenCommandSended(sendedCmd: PlenConvertCmd!)
    func BLEStateUpdated(state: CBCentralManagerState)
}

class BLEProcess:NSObject, CBCentralManagerDelegate, CBPeripheralDelegate,ConnectProcess {
    let PLEN_TX_CHARACTERISTIC_UUID = CBUUID(string: "F90E9CFE-7E05-44A5-9D75-F13644D6F645")
    let PLEN_CONTROL_SERVICE_UUID = CBUUID(string: "E1F40469-CFE1-43C1-838D-DDBC9DAFDDE6")

    let exlucde_uuid_1 = NSUUID(UUIDString: "00-07-80-2D-90-84")
    let ONE_PACKET = 20
    let ONE_FRAME_PER_PACKET = 5
    
    var delegate: PlenMotionInstallDelegate!
    
    var centralManager: CBCentralManager!
    var connectPeripheral: CBPeripheral!
    var connectCharacteristic: CBCharacteristic!
    
    var connectExcludePeripherals: [CBPeripheral] = []
    var uncheckedServices: [CBService] = []
    
    var isBLEAvailable = false
    var isConnected = false

    var sendCmd: PlenConvertCmd!
    var stackSendcmdStr: NSString = ""
    var isCmdSended = false
    var isCmdHeaderSended = false
    var sendedHeaderCnt = 0
    var sendedFrameCnt = 0
    var sendedPacketCnt = 0
    var sendAllFrameCnt = 0
    
    override init() {
        super.init()
        
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    
    func centralManagerDidUpdateState(central: CBCentralManager!) {
        println("state : \(central.state.toString)")
        if central.state == CBCentralManagerState.PoweredOn {
            isBLEAvailable = true
        }
        delegate.BLEStateUpdated(central.state)
    }
}

/*----- BLE Send Process -----*/
extension BLEProcess {
    
    func peripheral(peripheral: CBPeripheral!, didWriteValueForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
        if(error != nil) {
            delegate.MessageFormBLEProcess("BLE Error \(error)")
            return
        }
        
        var packetSize = ONE_PACKET
        
        // case0:#IN, case1:headerPacket(先頭10バイト), case2:headerPacket（残り20バイト）
        if isCmdHeaderSended == false {
            switch sendedPacketCnt++ {
            case 0:
                packetSize = 10
            case 2:
                isCmdHeaderSended = true
                delegate.MessageFormBLEProcess("header written.")
                sendedFrameCnt = 0
                sendedPacketCnt = 0
            default:
                break
            }
        }
        else {
            if ++sendedPacketCnt >= ONE_FRAME_PER_PACKET {
                sendedPacketCnt = 0
                delegate.MessageFormBLEProcess("frame written.  : \(++sendedFrameCnt)/\(sendAllFrameCnt)")
            }
        }
        if stackSendcmdStr != "" {
            var data : NSData?
            if stackSendcmdStr.length >= packetSize {
                data = stackSendcmdStr.substringToIndex(packetSize).dataUsingEncoding(NSASCIIStringEncoding)
                stackSendcmdStr = stackSendcmdStr.substringFromIndex(packetSize)
            }
            else {
                data = stackSendcmdStr.dataUsingEncoding(NSASCIIStringEncoding)
                stackSendcmdStr = ""
            }
            connectPeripheral.writeValue(data, forCharacteristic: connectCharacteristic, type:CBCharacteristicWriteType.WithResponse)
        }
        else {
            delegate.MessageFormBLEProcess(" [\(sendCmd.name)] send Complete...")
            delegate.PlenCommandSended(sendCmd)
        }
        
    }
    
    func PlenSendCommand(sendCmd: PlenConvertCmd) {
        isCmdSended = false
        isCmdHeaderSended = false
        sendedPacketCnt = 0
        self.sendCmd = sendCmd
        stackSendcmdStr = sendCmd.convertedStr
        sendAllFrameCnt = stackSendcmdStr.length / 100
        var data = ">IN".dataUsingEncoding(NSASCIIStringEncoding)
        connectPeripheral.writeValue(data, forCharacteristic: connectCharacteristic
            , type: CBCharacteristicWriteType.WithResponse)
    }

}

/*----- BLE Connecting Process -----*/
extension BLEProcess {
    /**
    PLEN接続（BLE）メソッド
    Note..接続完了通知はPlenBLEConnectedにて行われる
    */
    func PlenConnect() {
        if isConnected == true {
            PlenDisconnect()
        }
        connectExcludePeripherals.removeAll(keepCapacity: false)
        // PLENのアドバタイズパケットにはサービスUUIDがのっている
        centralManager.scanForPeripheralsWithServices([PLEN_CONTROL_SERVICE_UUID] as [AnyObject], options: nil)
      }

    func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!) {

        if(contains(connectExcludePeripherals, peripheral) == false) {
            println(peripheral.identifier)
            isConnected = true
            connectPeripheral = peripheral
            println(peripheral.identifier.description)
            centralManager.stopScan()
            centralManager.connectPeripheral(connectPeripheral, options:nil)
        }
    }
    func centralManager(central: CBCentralManager!, didConnectPeripheral peripheral: CBPeripheral!) {
        connectPeripheral.delegate = self
        delegate.MessageFormBLEProcess("The peripheral Connected. Scan Services...")
        peripheral.discoverServices(nil)
    }
    
    func peripheral(peripheral: CBPeripheral!, didDiscoverServices error: NSError!) {
        if(error != nil) {
            println("error \(error)")
            return
        }
        var isServiceExisted = false
        
        let services: NSArray = peripheral.services
        for serviceObj in services {
            let service = serviceObj as! CBService
            println(service.UUID.description)
            if service.UUID.isEqual(PLEN_CONTROL_SERVICE_UUID) {
                isServiceExisted = true
                delegate.MessageFormBLEProcess("PLEN Control Service Find. Scan Characteristics...")
                peripheral.discoverCharacteristics(nil, forService: service)
                break
            }
        }
        
        if isServiceExisted == false {
            delegate.MessageFormBLEProcess("Connecting peripheral isn't PLEN")
            centralManager.cancelPeripheralConnection(peripheral)
            connectExcludePeripherals.append(peripheral)
            delegate.MessageFormBLEProcess("PLEN re-searching...")
            centralManager.scanForPeripheralsWithServices([PLEN_CONTROL_SERVICE_UUID] as [AnyObject], options: nil)
            return
        }
    }
    
    func peripheral(peripheral: CBPeripheral!, didDiscoverCharacteristicsForService service: CBService!, error: NSError!) {
        
        if(error != nil) {
            println("error : \(error)")
            return
        }
        
        let characteristics: NSArray = service.characteristics
        
        for chObj in characteristics {
            let characteristic = chObj as! CBCharacteristic
            if(characteristic.UUID.isEqual(PLEN_TX_CHARACTERISTIC_UUID)) {
                connectPeripheral = peripheral
                connectCharacteristic = characteristic
                delegate.MessageFormBLEProcess("PLEN connected")
                delegate.PlenConnected(false)
                
                return
            }
        }
        delegate.MessageFormBLEProcess("Connecting peripheral isn't PLEN")
        centralManager.cancelPeripheralConnection(peripheral)
        connectExcludePeripherals.append(peripheral)
        delegate.MessageFormBLEProcess("PLEN re-searching...")
        centralManager.scanForPeripheralsWithServices([PLEN_CONTROL_SERVICE_UUID] as [AnyObject], options: nil)
        return
    }
}

/*----- BLE Disconnect Process -----*/
extension BLEProcess {
    func PlenDisconnect() {
        if connectPeripheral != nil {
            centralManager.cancelPeripheralConnection(connectPeripheral)
        }
        centralManager.stopScan()
        delegate.MessageFormBLEProcess("PLEN disconnected")
        isConnected = false
    }
}
extension CBCentralManagerState {
    var toString : String! {
        switch self  {
        case CBCentralManagerState.PoweredOn:
            return "Bluetooth4.0 ON."
        case CBCentralManagerState.PoweredOff:
            return "Bluetooth4.0 OFF."
        case CBCentralManagerState.Resetting:
            return "Bluetooth System Service Resetting."
        case CBCentralManagerState.Unauthorized:
            return "This application isn't authorized to use Bluetooth4.0."
        case CBCentralManagerState.Unknown:
            return "This application can't check that Bluetooth4.0 is available. "
        case CBCentralManagerState.Unsupported:
            return "This Mac does not support Bluetooth4.0 ."
        }
    }
}
