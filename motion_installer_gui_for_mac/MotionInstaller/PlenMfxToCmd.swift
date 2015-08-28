//
//  PlenJsonToCmd.swift
//  MotionInstaller
//
//  Created by PLEN on 2015/07/16.
//  Copyright (c) 2015 PLEN Project Company Ltd. and Yugo KAJIWARA All rights reserved.
//
//  This software is released under the MIT License.

import Foundation


class MfxToCmd : PlenConvertCmd {
    
    override init() {
        super.init()
    }
    
    func MfxParse(path: NSURL!) -> Bool {
        let readStr = NSString(contentsOfURL: path, encoding: NSUTF8StringEncoding, error: nil)
        
        if readStr == nil {
            delegate.MessageFromJsonToCmd("error : モーションファイルの検索に失敗しました．")
        }
        
        let xml = SWXMLHash.parse(readStr as! String)
        
        switch xml {
        case .Error(let error):
                delegate.MessageFromJsonToCmd("error : MFXファイルの解析に失敗しました．選択したモーションファイルが破損している恐れがあります．")
                return false
        default:
            break
        }
        delegate.MessageFromJsonToCmd("【\(path.lastPathComponent!)】モーションファイルを送信データとして変換します...")
        return CmdParse(xml)
    }
    
    func CmdParse(mfxData: XMLIndexer) -> Bool{
        var cmdStr = ""
        isConverted = false
        
        // slot
        let slot = mfxData["mfx"]["motion"].element?.attributes["id"]?.toInt()
        if slot == nil || slot! < 0 || slot! > 99 {
            delegate.MessageFromJsonToCmd("error : 送信データの変換に失敗しました（slot）")
            return false
        }
        cmdStr = String(format: "%02hhx", slot!)
        //name
        let name = mfxData["mfx"]["motion"]["name"].element?.text
        if name == nil {
            delegate.MessageFromJsonToCmd("error : 送信データの変換に失敗しました（name）")
            return false
        }
        cmdStr += name!
        // 空白埋め
        for var i = 0; i < (20 - count(name!)); i++ {
            cmdStr += " "
        }
        self.name = name!
        // extra
        let fnc  = mfxData["mfx"]["motion"]["extra"]["function"].element?.text!.toInt()
        let prm0 = mfxData["mfx"]["motion"]["extra"]["param"].withAttr("id", "0").element?.text!.toInt()
        let prm1 = mfxData["mfx"]["motion"]["extra"]["param"].withAttr("id", "1").element?.text!.toInt()
        if fnc == nil || prm0 == nil || prm1 == nil {
            delegate.MessageFromJsonToCmd("error : 送信データの変換に失敗しました（extra）")
            return false
        }
        cmdStr += String(format: "%02hhx%02hhx%02hhx", fnc!, prm0!, prm1!)
        //frames
        let frameNum = mfxData["mfx"]["motion"]["frameNum"].element?.text!.toInt()
        if frameNum == nil {
            delegate.MessageFromJsonToCmd("error : 送信データの変換に失敗しました（frameNum）")
            return false
        }
        cmdStr += String(format : "%02hhx", frameNum!)
        // ヘッダ部は30バイトなのでカウント値がおかしければエラーをはく
        if count(cmdStr) != 30 {
            delegate.MessageFromJsonToCmd("error : 送信データの変換に失敗しました（header）")
            return false
        }
        println(cmdStr)
        // frame
        for i in 0...(frameNum! - 1) {
            for frame in mfxData["mfx"]["motion"]["frame"].withAttr("id", i.description).all {
                // time
                let time = frame["time"].element?.text!.toInt()
                if time == nil {
                    delegate.MessageFromJsonToCmd("error : 送信データの変換に失敗しました（frame）")
                    return false
                }
                var frameStr = String(format: "%04hx", time!)
                // joint
                for j in 0...23 {
                    let joint = frame["joint"].withAttr("id", j.description).element?.text!.toInt()
                    if joint == nil {
                        delegate.MessageFromJsonToCmd("error : 送信データの変換に失敗しました（joint）")
                        return false
                    }
                    frameStr += String(format: "%04hx", joint!)
                }
                
                if count(frameStr) != 100 {
                    delegate.MessageFromJsonToCmd("error : 送信データの変換に失敗しました（frame）")
                    return false
                }
                cmdStr += frameStr
            }
        }
        isConverted = true
        convertedStr = cmdStr
        delegate.MessageFromJsonToCmd("***** モーションファイルを送信データに変換しました．（\(count(cmdStr))バイト） *****")
        return true
    }
}
