//
//  ViewController.swift
//  MotionInstaller
//
//  Created by PLEN on 2015/07/16.
//  Copyright (c) 2015 PLEN Project Company Ltd. and Yugo KAJIWARA All rights reserved.
//
//  This software is released under the MIT License.

import Cocoa
import CoreBluetooth

class ViewController: NSViewController,PlenMotionInstallDelegate, PlenConvertCmdDelegate {

    @IBOutlet var btnRead: NSButton!
    @IBOutlet var btnStart: NSButton!
    @IBOutlet var btnStop: NSButton!
    @IBOutlet var btnPortUpDate: NSButton!
    @IBOutlet var txtViewLog: NSTextView!
    @IBOutlet var labelSendedCnt: NSTextField!
    @IBOutlet var labelMotionCnt: NSTextField!
    @IBOutlet var cmbBoxSerial: NSComboBox!
    @IBOutlet var cmbBoxConnect: NSComboBox!
    
    let BLE = "BLE"
    let USB = "USB"
    
    var isAutoAppStart = false
    var isAutoAppClose = false
    
    var bleProcess = BLEProcess()
    var usbProcess: SerialPort?
    var connectProcess:ConnectProcess!
    
    var convertedCmdList = [PlenConvertCmd]()
    var sendCmdList = [PlenConvertCmd]()
    
    var sendedCnt: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bleProcess.delegate = self
        // Do any additional setup after loading the view.
        
        cmbBoxSerial_Init()
        
        
        // windowを最前面に表示させる
        (NSApp as! NSApplication).activateIgnoringOtherApps(true)
        
        // 引数にjsonファイルの指定がある（[0]：appのパス，[1]：jsonのパス，[2]：ファイル名）
        let arguments: [String] = NSProcessInfo.processInfo().arguments.map({String($0 as! NSString)})
        if arguments.count == 3 {
            // jsonのパスはURLエンコードされている
            let path = arguments[1].stringByRemovingPercentEncoding;

            if path == nil {
                return
            }
            // JSONファイルをパースする
            if NSFileManager.defaultManager().fileExistsAtPath(path!) == true {
                var jsonParser = JsonToCmd()
                jsonParser.delegate = self
                if jsonParser.JsonParse(NSURL(fileURLWithPath: path!)) == true {
                    convertedCmdList.append(jsonParser)
                }
            }
            if convertedCmdList.count == 0 {
                return
            }
            
            isAutoAppStart = true
            isAutoAppClose = true
        }
        
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    /*----- シリアルポート一覧コンボボックス初期化 -----*/
    func cmbBoxSerial_Init() {
        // 「$ ls /dev/tty.usb*」の結果をpipeに格納，受け取ったtty.usb一覧をコンボボックスに表示する
        let task = NSTask()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "ls /dev/tty.usb*"]
        
        let pipe = NSPipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = NSString(data: data, encoding: NSUTF8StringEncoding) {
            let ports = output.componentsSeparatedByString("\n")
            cmbBoxSerial.removeAllItems()
            for port in ports {
                if port as! String != "" {
                    cmbBoxSerial.addItemWithObjectValue(port)
                }
            }
            if cmbBoxSerial.objectValues.count > 0 {
                cmbBoxSerial.selectItemAtIndex(0)
            }
        }
        task.waitUntilExit()
    }

    @IBAction func btnRead_Click(sender: AnyObject) {
        // ファイル選択ダイアログ初期化
        var openFilePanel = NSOpenPanel()
        var allowedFileTypes:NSArray = ["mfx", "json"]
        openFilePanel.allowedFileTypes = allowedFileTypes as [AnyObject]
        openFilePanel.canChooseFiles = true
        openFilePanel.allowsMultipleSelection = true
        // ファイル選択ダイアログ表示
        if openFilePanel.runModal() == NSOKButton {
            convertedCmdList.removeAll()
            labelMotionCnt.stringValue = String(openFilePanel.URLs.count)
            for pathObj in openFilePanel.URLs {
                if (pathObj as! NSURL).pathExtension == "mfx" {
                    var mfxParser = MfxToCmd()
                    mfxParser.delegate = self
                    if mfxParser.MfxParse(pathObj as! NSURL) == true {
                        convertedCmdList.append(mfxParser)
                    }
                }
                else {
                    var jsonParser = JsonToCmd()
                    jsonParser.delegate = self
                    if jsonParser.JsonParse(pathObj as! NSURL) == true {
                        convertedCmdList.append(jsonParser)
                    }
                }
                
            }
        }
    }
    
    @IBAction func btnStart_Click(sender: AnyObject) {
        
        txtViewLog.insertText("***** 通信を開始します... *****\n")
        
        if convertedCmdList.count == 0 {
            txtViewLog.insertText("error : 送信するモーションファイルが読み込まれていません．")
            return
        }
        // BLE通信
        if (cmbBoxConnect.objectValueOfSelectedItem as! String) == BLE {
            if bleProcess.centralManager.state != CBCentralManagerState.PoweredOn {
                txtViewLog.insertText("error : BLEを利用できません．(\(bleProcess.centralManager.state.toString))    \n")
                return
            }
            connectProcess = bleProcess
        }
        // USB通信
        else {
            if cmbBoxSerial.objectValueOfSelectedItem == nil {
                txtViewLog.insertText("error : シリアルポートを選択してください．\n")
                return
            }
            
            usbProcess = SerialPort(delegate: self, devicePath: cmbBoxSerial.objectValueOfSelectedItem as! String)
            
            
            if usbProcess?.serialPort == nil {
                txtViewLog.insertText("error : 選択されたシリアルポートが利用できません．\n")
                return
            }
            connectProcess = usbProcess!
        }
        connectProcess.PlenConnect()
        btnRead.enabled = false
        btnStart.enabled = false
        btnPortUpDate.enabled = false
        cmbBoxConnect.enabled = false
        cmbBoxSerial.enabled = false
        labelSendedCnt.stringValue = "0 / \(convertedCmdList.count)"
        sendedCnt = 0
    }

    
    @IBAction func btnStop_Click(sender: AnyObject) {
        txtViewLog.insertText("***** 通信が中断されました． *****\n")
        PlenDisconnect()
    }
    
    @IBAction func btnPortUpdate_Click(sender: AnyObject) {
        cmbBoxSerial.deselectItemAtIndex(cmbBoxSerial.indexOfSelectedItem)
        cmbBoxSerial.removeAllItems()
        cmbBoxSerial_Init()
    }

    @IBAction func cmbBoxConnect_SelectedItemChanged(sender: AnyObject) {
        if (cmbBoxConnect.objectValueOfSelectedItem as! String) == USB {
            cmbBoxSerial.enabled = true
            btnPortUpDate.enabled = true
            isAutoAppStart = false
        }
        else {
            cmbBoxSerial.enabled = false
            btnPortUpDate.enabled = false
            if isAutoAppStart == true {
                btnStart_Click(self)
                isAutoAppStart = false
            }
        }
    }
    
    func MessageFromJsonToCmd(str: String) {
        txtViewLog.insertText(str + "\n")
    }
}

/*----- Communication Process -----*/
extension ViewController {
    
    func BLEStateUpdated(state: CBCentralManagerState) {
        cmbBoxConnect.removeAllItems()
        // BLE使用可能時はコンボボックスにBLE，USBを，それ以外の場合はUSBのみ表示する
        if state == CBCentralManagerState.PoweredOn {
            cmbBoxConnect.addItemWithObjectValue(BLE)
            cmbBoxConnect.addItemWithObjectValue(USB)
        }
        else {
            cmbBoxConnect.addItemWithObjectValue(USB)
        }
        cmbBoxConnect.selectItemAtIndex(0)
        cmbBoxConnect_SelectedItemChanged(self)
    }
    
    func MessageFormBLEProcess(message: String!) {
        txtViewLog.insertText(message + "\n")
    }
    
    func PlenConnected(isError: Bool) {
        
        if isError == true {
            txtViewLog.insertText("error : PLENとの接続に失敗しました")
            return
        }
        sendCmdList = convertedCmdList
        connectProcess.PlenSendCommand(sendCmdList.first!)
    }
    
    func PlenCommandSended(sendedCmd: PlenConvertCmd!) {
        labelSendedCnt.stringValue = "\(++sendedCnt) / \(convertedCmdList.count)"
        sendCmdList.removeAtIndex(0)
        
        if sendCmdList.count == 0 {
            txtViewLog.insertText("***** すべてのモーションデータの送信が完了しました． *****\n")
            PlenDisconnect()
            
            if isAutoAppClose == true {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                    NSThread.sleepForTimeInterval(1)
                    (NSApp as! NSApplication).terminate(self)
                })
            }
            
            return
        }
        else {
            connectProcess.PlenSendCommand(sendCmdList.first!)
        }
    }
    
    func PlenDisconnect() {
        connectProcess.PlenDisconnect()
        btnRead.enabled = true
        btnStart.enabled = true
        cmbBoxConnect.enabled = true
        cmbBoxConnect_SelectedItemChanged(self)
    }
}

