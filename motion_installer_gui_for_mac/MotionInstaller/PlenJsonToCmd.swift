//
//  PlenJsonToCmd.swift
//  MotionInstaller
//
//  Created by PLEN on 2015/07/16.
//  Copyright (c) 2015 PLEN Project Company Ltd. and Yugo KAJIWARA All rights reserved.
//
//  This software is released under the MIT License.

import Foundation

protocol PlenConvertCmdDelegate {
    func MessageFromJsonToCmd(str : String)
}

class PlenConvertCmd {
    var delegate:PlenConvertCmdDelegate!
    var name = ""
    var convertedStr = ""
    var isConverted = false
    
    init() {
    }
}

class JsonToCmd : PlenConvertCmd {
    
    override init() {
        super.init()
    }
    
    func JsonParse(path: NSURL!) -> Bool {
        let readStr = NSString(contentsOfURL: path, encoding: NSUTF8StringEncoding, error: nil)
        
        if readStr == nil {
            delegate.MessageFromJsonToCmd("error : モーションファイルの検索に失敗しました．")
        }
        
        let json = JSON.parse(readStr as! String)
        if json.isError == true {
            delegate.MessageFromJsonToCmd("error : JSONファイルの解析に失敗しました．選択したモーションファイルが破損している恐れがあります．")
            return false
        }
        delegate.MessageFromJsonToCmd("【\(path.lastPathComponent!)】モーションファイルを送信データとして変換します...")
        return CmdParse(json)
    }
    
    func CmdParse(jsonData: JSON) -> Bool{
        var cmdStr = ""
        isConverted = false
        
        // slot
        cmdStr += String(format: "%02hhx", jsonData["slot"].asInt!)
        //name
        let name = jsonData["name"].asString!
        cmdStr += name
        for var i = 0; i < (20 - count(name)); i++ {
            cmdStr += " "
        }
        self.name = name
        // codes
        if jsonData["codes"].length == 0 {
            cmdStr += "000000"
        } else {
            var codesStr: String? = nil
            for codes in jsonData["codes"].asArray! {
                if codes["func"].asString == "loop" {
                    codesStr = "01"
                    for i in 0...1 {
                        codesStr! += String(format : "%02hhx", codes["args"].asArray![i].asInt!)
                    }
                } else if codes["func"].asString == "jump" {
                    if codesStr == nil {
                        codesStr = String(format : "02%02hhx00", codes["args"].asArray![0].asInt!)
                    }
                } else {
                    delegate.MessageFromJsonToCmd("error : 送信データの変換に失敗しました（header）")
                    return false
                } 
            }
            cmdStr += codesStr!
        }
        
        //println(cmdStr)
        //frames
        cmdStr += String(format : "%02hx", count(jsonData["frames"].asArray!))
        // ヘッダ部は30バイトなのでカウント値がおかしければエラーをはく
        if count(cmdStr) != 30 {
            delegate.MessageFromJsonToCmd("error : 送信データの変換に失敗しました（header）")
            return false
        }
        println(cmdStr)
        // frame
        for frame in jsonData["frames"].asArray! {
            
            var frameStr = String(format: "%04hx", frame["transition_time_ms"].asInt16!)
            for output in frame["outputs"].asArray! {
                valueMap[DEVICE_MAP[output["device"].asString!]!] = output["value"].asInt16!
            }
            for value in valueMap {
                frameStr += String(format: "%04hx", value)
            }
            
            if count(frameStr) != 100 {
                delegate.MessageFromJsonToCmd("error : 送信データの変換に失敗しました（frame）")
                return false
            }
            cmdStr += frameStr
        }
        isConverted = true
        convertedStr = cmdStr
        delegate.MessageFromJsonToCmd("***** モーションファイルを送信データに変換しました．（\(count(cmdStr))バイト） *****")
        return true
    }
    
    private let DEVICE_MAP = [
        "left_shoulder_pitch"  : 0,
        "right_shoulder_pitch" : 12,
        "left_shoulder_roll"   : 2,
        "right_shoulder_roll"  : 14,
        "left_elbow_roll"      : 3,
        "right_elbow_roll"     : 15,
        "left_thigh_yaw"       : 1,
        "right_thigh_yaw"      : 13,
        "left_thigh_roll"      : 4,
        "right_thigh_roll"     : 16,
        "left_thigh_pitch"     : 5,
        "right_thigh_pitch"    : 17,
        "left_knee_pitch"      : 6,
        "right_knee_pitch"     : 18,
        "left_foot_pitch"      : 7,
        "right_foot_pitch"     : 19,
        "left_foot_roll"       : 8,
        "right_foot_roll"      : 20
    ]
    
    private var valueMap:[Int16] = [Int16](count:24, repeatedValue:0)

}