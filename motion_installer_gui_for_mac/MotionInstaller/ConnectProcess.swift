//
//  ConnectProcess.swift
//  MotionInstaller
//
//  Created by PLEN on 2015/07/16.
//  Copyright (c) 2015 PLEN Project Company Ltd. and Yugo KAJIWARA All rights reserved.
//
//  This software is released under the MIT License.

import Foundation

protocol ConnectProcess {
    func PlenConnect()
    func PlenSendCommand(sendCmd: PlenConvertCmd)
    func PlenDisconnect()
}