//
//  IlluminatorScreen.swift
//  Illuminator
//
//  Created by Ian Katz on 20/10/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest


public protocol IlluminatorScreen: CustomStringConvertible {
    var testCaseWrapper: IlluminatorTestcaseWrapper { get }
    var label: String { get }
    var isActive: Bool { get }
    func becomesActive() throws
}

public extension IlluminatorScreen {
    var description: String {
        return label
    }

    var testCase: XCTestCase {
        get {
            return testCaseWrapper.testCase
        }
    }
}


// a screen that is always available (more like a shake action)
@available(iOS 9.0, *)
open class IlluminatorBaseScreen<T>: IlluminatorScreen {
    open let testCaseWrapper: IlluminatorTestcaseWrapper
    open let label: String
    open let app = XCUIApplication() // seems like the appropriate place to set this up
    
    public init (label labelVal: String, testCaseWrapper t: IlluminatorTestcaseWrapper) {
        testCaseWrapper = t
        label = labelVal
    }
    
    
    // By default, we assume that the screen is always active.  This should be overridden with a more realistic measurement
    open var isActive: Bool {
        return true
    }
    
    // Since the screen is always active, we don't need to waste time
    open func becomesActive() throws {
        return
    }

    open func verifyIsActive() -> IlluminatorActionGeneric<T> {
        return makeAction(label: #function) { }
    }
    
    open func verifyNotActive() -> IlluminatorActionGeneric<T> {
        let nullScreen = IlluminatorBaseScreen<T>(label: "null screen", testCaseWrapper: self.testCaseWrapper)
        return IlluminatorActionGeneric(label: #function, testCaseWrapper: self.testCaseWrapper, screen: nullScreen) { state in
            throw IlluminatorExceptions.incorrectScreen(message: "IlluminatorBaseScreen instances are always active")
        }
    }
    
    // shortcut function to make an action tied to this screen that either reads or writes the test state
    open func makeAction(label l: String = #function, task: @escaping (T) throws -> T) -> IlluminatorActionGeneric<T> {
        return IlluminatorActionGeneric(label: l, testCaseWrapper: self.testCaseWrapper, screen: self, task: task)
    }
    
    // shortcut function to make an action tied to this screen that neither reads nor writes the test state
    open func makeAction(label l: String = #function, task: @escaping () throws -> ()) -> IlluminatorActionGeneric<T> {
        return makeAction(label: l) { (state: T) in
            try task()
            return state
        }
    }
    
    // shortcut function to make composite actions
    open func makeAction(_ firstAction: IlluminatorActionGeneric<T>, secondAction: IlluminatorActionGeneric<T>, label l: String = #function) -> IlluminatorActionGeneric<T> {
        return makeAction(label: l) { (state: T) in
            return try secondAction.task(try firstAction.task(state))
        }
    }
    
    // shortcut function to make composite actions
    open func makeAction(_ actions: [IlluminatorActionGeneric<T>], label l: String = #function) -> IlluminatorActionGeneric<T> {
        // need 2 actions to do anything useful
        guard actions.count > 0 else {
            return makeAction() {
                throw IlluminatorExceptions.developerError(message: "Trying to make a composite Illuminator action from none")
            }
        }
        guard actions.count > 1 else { return actions[0] }
  
        return actions.tail.reduce(actions[0]) { makeAction($0, secondAction: $1) }
    }
}

// a "normal" screen -- one that may take a moment of animation to appear
@available(iOS 9.0, *)
open class IlluminatorDelayedScreen<T>: IlluminatorBaseScreen<T> {
    let screenTimeout: Double
    var nextTimeout: Double // For setting temporarily
    
    public init (label labelVal: String, testCaseWrapper t: IlluminatorTestcaseWrapper, screenTimeout s: Double) {
        screenTimeout = s
        nextTimeout = s
        super.init(label: labelVal, testCaseWrapper: t)
    }
    
    
    // By default, we assume that the screen
    override open func becomesActive() throws {
        defer { nextTimeout = screenTimeout }  // reset the timeout after we run
        do {
            try waitForResult(nextTimeout, desired: true, what: "[\(self) isActive]", getResult: { self.isActive })
        } catch IlluminatorExceptions.verificationFailed(let message) {
            throw IlluminatorExceptions.incorrectScreen(message: message)
        }
    }
    
    override open func verifyNotActive() -> IlluminatorActionGeneric<T> {
        let nullScreen = IlluminatorBaseScreen<T>(label: "null screen", testCaseWrapper: self.testCaseWrapper)
        return IlluminatorActionGeneric(label: #function, testCaseWrapper: self.testCaseWrapper, screen: nullScreen) { state in
            var stillActive: Bool
            do {
                try waitForResult(self.nextTimeout, desired: false, what: "[\(self) isActive]", getResult: { self.isActive })
                stillActive = false
            } catch IlluminatorExceptions.verificationFailed {
                stillActive = true
            }
            
            if stillActive {
                throw IlluminatorExceptions.incorrectScreen(message: "\(self) failed to become inactive")
            }
            return state
        }
    }
}

// a screen whose appearance is linked to the (dis)appearance of a transient dialog (like a spinner)
@available(iOS 9.0, *)
open class IlluminatorScreenWithTransient<T>: IlluminatorBaseScreen<T> {
    let screenTimeoutSoft: Double   // how long we'd wait if we didn't see the transient
    let screenTimeoutHard: Double   // how long we'd wait if we DID see the transient
    
    var nextTimeoutSoft: Double     // Sometimes we may want to adjust the timeouts temporarily
    var nextTimeoutHard: Double
    
    
    public init (testCaseWrapper: IlluminatorTestcaseWrapper,
                 label: String,
                 screenTimeoutSoft timeoutSoft: Double,
                                   screenTimeoutHard timeoutHard: Double) {
        screenTimeoutSoft = timeoutSoft
        screenTimeoutHard = timeoutHard
        nextTimeoutSoft = screenTimeoutSoft
        nextTimeoutHard = screenTimeoutHard
        super.init(label: label, testCaseWrapper: testCaseWrapper)
    }
    
    // To be overridden by the extender of the class
    open var transientIsActive: Bool {
        return false;
    }
    
    override open func becomesActive() throws {
        defer {
            nextTimeoutSoft = screenTimeoutSoft
            nextTimeoutHard = screenTimeoutHard
        }
        
        let hardTime = Date()
        var softTime = Date()
        repeat {
            if transientIsActive {
                softTime = Date()
            } else if isActive {
                return
            }
        } while hardTime.timeIntervalSinceNow < nextTimeoutHard && softTime.timeIntervalSinceNow < nextTimeoutSoft
        
        let msg = "[\(self) becomesActive] failed "
        throw IlluminatorExceptions.incorrectScreen(
            message: msg + ((hardTime.timeIntervalSinceNow > nextTimeoutHard) ? "hard" : "soft") + " timeout")
    }
    
    override open func verifyNotActive() -> IlluminatorActionGeneric<T> {
        let nullScreen = IlluminatorBaseScreen<T>(label: "null screen", testCaseWrapper: self.testCaseWrapper)
        return IlluminatorActionGeneric(label: #function, testCaseWrapper: self.testCaseWrapper, screen: nullScreen) { state in
            
            let hardTime = Date()
            var softTime = Date()
            repeat {
                if self.transientIsActive {
                    softTime = Date()
                } else if !self.isActive {
                    return state
                }
            } while hardTime.timeIntervalSinceNow < self.nextTimeoutHard && softTime.timeIntervalSinceNow < self.nextTimeoutSoft
            
            
            if self.isActive {
                throw IlluminatorExceptions.incorrectScreen(message: "\(self) failed to become inactive")
            }
            return state
        }
    }
}

