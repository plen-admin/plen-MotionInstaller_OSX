//
//  SerialPort.swift
//  MotionInstaller
//
//  Created by PLEN on 2015/07/16.
//  Copyright (c) 2015 PLEN Project Company Ltd. and Yugo KAJIWARA All rights reserved.
//
//  This software is released under the MIT License.

import Foundation
import ORSSerial


class SerialPort: NSObject, ConnectProcess, ORSSerialPortDelegate {
    
    let BAUDRATE = 115200
    var serialPort: ORSSerialPort?
    var delegate: PlenMotionInstallDelegate!
    
    var sendCmdStr: NSString!
    var sendCmd: PlenConvertCmd!
    
    var isPlenConnected = false
    
    override init() {
        super.init()
    }
    
    convenience init(delegate: PlenMotionInstallDelegate, devicePath: String!) {
        self.init()
        
        self.delegate = delegate
        self.serialPort = ORSSerialPort(path: devicePath)
        self.serialPort?.delegate = self
        self.serialPort?.close()
    }
    
    func PlenSendCommand(sendCmd: PlenConvertCmd) {
        self.sendCmd = sendCmd
        sendCmdStr = sendCmd.convertedStr as NSString
        // メインスレッドと別スレッドで通信処理を行う
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), SendCommand)
    }
    
    func SendCommand() {
        let frameCnt: Int = (sendCmdStr.length - 30 ) / 100
        var sendCnt = 0
        
        // header
        serialPort!.sendData(StrToNSData(">IN"))
        serialPort!.sendData(StrToNSData(sendCmdStr.substringRangeIndex(0 , range: 10)))
        NSThread.sleepForTimeInterval(0.1)
        serialPort!.sendData(StrToNSData(sendCmdStr.substringRangeIndex(10, range: 20)))
        // 画面表示はメインスレッドと同期して行う
        dispatch_async(dispatch_get_main_queue(), {
            self.delegate.MessageFormBLEProcess("header written.")
        })
        NSThread.sleepForTimeInterval(0.1)
        
        // frame
        sendCmdStr = sendCmdStr.substringFromIndex(30)
        do {
            serialPort!.sendData(StrToNSData(sendCmdStr.substringRangeIndex(0 , range: 20)))
            NSThread.sleepForTimeInterval(0.05)
            serialPort!.sendData(StrToNSData(sendCmdStr.substringRangeIndex(20, range: 20)))
            NSThread.sleepForTimeInterval(0.05)
            serialPort!.sendData(StrToNSData(sendCmdStr.substringRangeIndex(40, range: 20)))
            NSThread.sleepForTimeInterval(0.05)
            serialPort!.sendData(StrToNSData(sendCmdStr.substringRangeIndex(60, range: 20)))
            NSThread.sleepForTimeInterval(0.05)
            serialPort!.sendData(StrToNSData(sendCmdStr.substringRangeIndex(80, range: 20)))
            NSThread.sleepForTimeInterval(0.05)
            
            if isPlenConnected == true {
                // 画面表示はメインスレッドと同期して行う
                dispatch_async(dispatch_get_main_queue(), {
                    self.delegate.MessageFormBLEProcess("frame written.  : \(++sendCnt)/\(frameCnt)")
                })
            }
            sendCmdStr = sendCmdStr.substringFromIndex(100)
        } while (sendCmdStr != "" && isPlenConnected == true)
        
        if isPlenConnected == false {
            return
        }
        
        dispatch_async(dispatch_get_main_queue(), {
            self.delegate.MessageFormBLEProcess(" [\(self.sendCmd.name)] send Complete...")
            self.delegate.PlenCommandSended(self.sendCmd)
        })
    }
    
    func StrToNSData(str: NSString) -> NSData {
        return str.dataUsingEncoding(NSASCIIStringEncoding)!
    }
    
    func PlenConnect() {
        if serialPort == nil {
            delegate.PlenConnected(true)
            return
        }
        
        serialPort!.baudRate = BAUDRATE
        serialPort!.open()
        delegate.PlenConnected(false)
        isPlenConnected = true
    }
    
    func PlenDisconnect() {
        if serialPort != nil {
            serialPort!.close()
            delegate.MessageFormBLEProcess("PLEN disconnected.")
            isPlenConnected = false
        }
    }
}
extension SerialPort {
    func serialPortWasOpened(serialPort: ORSSerialPort) {
        println("THE PORT IS OPEN...")
    }
    
    func serialPortWasClosed(serialPort: ORSSerialPort) {
        println("THE PORT IS CLOSE")
    }
    
    func serialPort(serialPort: ORSSerialPort, didReceiveData data: NSData) {
        if let string = NSString(data: data, encoding: NSUTF8StringEncoding) {
            print(string)
        }
    }
    
    @objc func serialPortWasRemovedFromSystem(serialPort: ORSSerialPort) {    }
    
    func serialPort(serialPort: ORSSerialPort, didEncounterError error: NSError) {
        println("PORT ERR \(error)")
    }
}

extension NSString {
    func substringRangeIndex(from:Int, range:Int) -> NSString {
        if self.length < (from + range) {
            return ""
        }
        let str:NSString = self.substringFromIndex(from)
        return str.substringToIndex(range)
    }
}