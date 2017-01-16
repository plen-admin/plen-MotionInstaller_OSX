//
//  main.swift
//  CommandLineDemo
//
//  Created by Andrew Madsen on 4/13/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
//

import Foundation

enum ApplicationState {
	case InitializationState
	case WaitingForPortSelectionState([ORSSerialPort])
	case WaitingForBaudRateInputState
	case WaitingForUserInputState
}

// MARK: User prompts

struct UserPrompter {
	func printIntroduction() {
		println("This program demonstrates the use of ORSSerialPort")
		println("in a Foundation-based command-line tool.")
		println("Please see http://github.com/armadsen/ORSSerialPort/\nor email andrew@openreelsoftware.com for more information.\n")
	}
	
	func printPrompt() {
		print("\n> ")
	}
	
	func promptForSerialPort() {
		println("\nPlease select a serial port: \n")
		let availablePorts = ORSSerialPortManager.sharedSerialPortManager().availablePorts as! [ORSSerialPort]
		var i = 0
		for port in availablePorts {
			println("\(i++). \(port.name)")
		}
		printPrompt()
	}
	
	func promptForBaudRate() {
		print("\nPlease enter a baud rate: ");
	}
}

class StateMachine : NSObject, ORSSerialPortDelegate {
	var currentState = ApplicationState.InitializationState
	let standardInputFileHandle = NSFileHandle.fileHandleWithStandardInput()
	let prompter = UserPrompter()
	
	var serialPort: ORSSerialPort? {
		didSet {
			serialPort?.delegate = self;
			serialPort?.open()
		}
	}
	
	func runProcessingInput() {
		setbuf(stdout, nil)
		standardInputFileHandle.readabilityHandler = { (fileHandle: NSFileHandle!) in
			let data = fileHandle.availableData
			dispatch_async(dispatch_get_main_queue(), { () -> Void in
				self.handleUserInput(data)
			})
		}
		
		prompter.printIntroduction()
		
		let availablePorts = ORSSerialPortManager.sharedSerialPortManager().availablePorts as! [ORSSerialPort]
		if availablePorts.count == 0 {
			println("No connected serial ports found. Please connect your USB to serial adapter(s) and run the program again.\n")
			exit(EXIT_SUCCESS)
		}
		prompter.promptForSerialPort()
		currentState = .WaitingForPortSelectionState(availablePorts)

		NSRunLoop.currentRunLoop().run() // Required to receive data from ORSSerialPort and to process user input
	}
	
	// MARK: Port Settings
	func setupAndOpenPortWithSelectionString(var selectionString: String, availablePorts: [ORSSerialPort]) -> Bool {
		selectionString = selectionString.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
		if let index = selectionString.toInt() {
			let clampedIndex = min(max(index, 0), availablePorts.count-1)
			self.serialPort = availablePorts[clampedIndex]
			return true
		} else {
			return false
		}
	}
	
	func setBaudRateOnPortWithString(var selectionString: String) -> Bool {
		selectionString = selectionString.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
		if let baudRate = selectionString.toInt() {
			self.serialPort?.baudRate = baudRate
			print("Baud rate set to \(baudRate)")
			return true
		} else {
			return false
		}
	}
	
	// MARK: Data Processing
	func handleUserInput(dataFromUser: NSData) {
		if let string = NSString(data: dataFromUser, encoding: NSUTF8StringEncoding) as? String {
			
			if string.lowercaseString.hasPrefix("exit") ||
				string.lowercaseString.hasPrefix("quit") {
					println("Quitting...")
					exit(EXIT_SUCCESS)
			}
			
			switch self.currentState {
			case .WaitingForPortSelectionState(let availablePorts):
				if !setupAndOpenPortWithSelectionString(string, availablePorts: availablePorts) {
					print("\nError: Invalid port selection.")
					prompter.promptForSerialPort()
					return
				}
			case .WaitingForBaudRateInputState:
				if !setBaudRateOnPortWithString(string) {
					print("\nError: Invalid baud rate. Baud rate should consist only of numeric digits.");
					prompter.promptForBaudRate();
					return;
				}
				currentState = .WaitingForUserInputState
				prompter.printPrompt()
			case .WaitingForUserInputState:
				self.serialPort?.sendData(dataFromUser)
				prompter.printPrompt()
			default:
				break;
			}
		}
	}
	
	// ORSSerialPortDelegate
	
	func serialPort(serialPort: ORSSerialPort, didReceiveData data: NSData) {
		if let string = NSString(data: data, encoding: NSUTF8StringEncoding) {
			print("\nReceived: \"\(string)\" \(data)")
		}
		prompter.printPrompt()
	}
	
	func serialPortWasRemovedFromSystem(serialPort: ORSSerialPort) {
		self.serialPort = nil
	}
	
	func serialPort(serialPort: ORSSerialPort, didEncounterError error: NSError) {
		println("Serial port (\(serialPort)) encountered error: \(error)")
	}
	
	func serialPortWasOpened(serialPort: ORSSerialPort) {
		print("Serial port \(serialPort) was opened")
		prompter.promptForBaudRate()
		currentState = .WaitingForBaudRateInputState
	}
}

StateMachine().runProcessingInput()
