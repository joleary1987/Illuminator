//
//  XCUIElement.swift
//  Illuminator
//
//  Created by Katz, Ian on 10/23/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest
@available(iOS 9.0, *)


// string-representable optionset
// pattern via http://www.swift-studies.com/blog/2015/6/17/exploring-swift-20-optionsettypes
public struct IlluminatorElementReadiness: OptionSet, CustomStringConvertible {
    fileprivate enum Readiness: Int, CustomStringConvertible {
        case exists       = 1
        case inMainWindow = 2
        case hittable     = 4

        var description : String {
            var shift = 0
            while (rawValue >> shift != 1) { shift = shift + 1 } // TODO: probably a better way to do this
            return ["Exists", "Down", "Hittable"][shift]
        }
    }

    public  let rawValue: Int
    public  init(rawValue: Int) { self.rawValue = rawValue}
    fileprivate init(_ readiness: Readiness) { self.rawValue = readiness.rawValue }

    static let Exists        = IlluminatorElementReadiness(Readiness.exists)
    static let InMainWindow  = IlluminatorElementReadiness(Readiness.inMainWindow)
    static let Hittable      = IlluminatorElementReadiness(Readiness.hittable)

    public var description : String{
        var result = [String]()
        var shift = 0

        // TODO: probably a better way to reduce()
        while let v = Readiness(rawValue: 1 << shift) {
            shift = shift + 1
            if self.contains(IlluminatorElementReadiness(v)){
                result.append("\(v)")
            }
        }
        return "[\(result.joined(separator: ","))]"
    }
}


let defaultReadiness: IlluminatorElementReadiness = [.Exists, .Hittable]

extension XCUIElement {
    
    // best effort
    // this code was adapted from the original javascript implementation of Illuminator
    // and it may no longer be relevant.  It is here until we can find a more relevant equality operation
    func equals(_ e: XCUIElement) -> Bool {
        
        // nonexistent elements can't be equal to anything
        guard exists && e.exists else {
            return false
        }
        
        var result = false
        
        let c1 = self.elementType == e.elementType
        let c2 = self.self.label == e.label
        let c3 = self.identifier == e.identifier
        let c4 = self.isHittable == e.isHittable
        let c5 = self.frame == e.frame
        let c6 = self.isEnabled == e.isEnabled
        let c7 = self.accessibilityLabel == e.accessibilityLabel
        let c8 = self.isSelected == e.isSelected
        
        result = c1 && c2 && c3 && c4 && c5 && c6 && c7 && c8
        
        return result
    }

    func swipeTo(target element: XCUIElement, direction: UISwipeGestureRecognizerDirection, failMessage: String, giveUpCondition: (XCUIElement, XCUIElement) -> Bool) throws {
        repeat {
            if element.exists {
                if element.isHittable { return }
            }

            switch direction {
            case UISwipeGestureRecognizerDirection.down:
                swipeDown()
            case UISwipeGestureRecognizerDirection.up:
                swipeUp()
            case UISwipeGestureRecognizerDirection.left:
                swipeLeft()
            case UISwipeGestureRecognizerDirection.right:
                swipeRight()
            default:
                ()
            }
        } while !giveUpCondition(self, element)

        if !element.inMainWindow {
            throw IlluminatorExceptions.elementNotReady(message: "Couldn't find \(element) after \(failMessage)")
        }
    }

    func swipeTo(target element: XCUIElement, direction: UISwipeGestureRecognizerDirection, withTimeout seconds: Double) throws {
        let startTime = Date()
        try swipeTo(target: element, direction: direction, failMessage: "scrolling for \(seconds) seconds") { (_, _) in
            return (0 - startTime.timeIntervalSinceNow) > seconds
        }
    }

    func swipeTo(target element: XCUIElement, direction: UISwipeGestureRecognizerDirection, maxSwipes: UInt) throws {
        var totalSwipes: UInt = 0
        try swipeTo(target: element, direction: direction, failMessage: "swiping \(maxSwipes) times") { (_, _) in
            totalSwipes = totalSwipes + 1
            return totalSwipes > maxSwipes
        }
    }

    // check the rectangle of an element and see if it is in the main window.
    var inMainWindow: Bool {
        get {
            guard exists else { return false }
            let window = XCUIApplication().windows.element(boundBy: 0)
            return window.frame.contains(self.frame)
        }
    }

    // general purpose function for checking that an element is ready for an action
    // in order to throw an illuminator error instead of simply XCTFailing with no info
    func ready(usingCriteria desired: IlluminatorElementReadiness, otherwiseFailWith description: String) throws -> XCUIElement {
        let failMessage = { (message: String) -> String in "\(description); element not ready: \(message)" }
        if desired.contains(.Exists) && !exists {
            throw IlluminatorExceptions.elementNotReady(message: failMessage("element does not exist"))
        }

        if desired.contains(.InMainWindow) && !inMainWindow {
            throw IlluminatorExceptions.elementNotReady(message: failMessage("element is not within the bounds of the main window"))
        }

        if desired.contains(.Hittable) && !isHittable {
            throw IlluminatorExceptions.elementNotReady(message: failMessage("element is not hittable"))
        }

        return self
    }

    @discardableResult
    func ready(usingCriteria desired: IlluminatorElementReadiness) throws -> XCUIElement {
        return try ready(usingCriteria: desired, otherwiseFailWith: "Failed readiness check")
    }

    func ready() throws -> XCUIElement {
        return try ready(usingCriteria: defaultReadiness)
    }

    // wait for readiness condition for a given number of seconds; throw or return self
    func whenReady(usingCriteria desired: IlluminatorElementReadiness, withTimeout seconds: Double) throws -> XCUIElement {
        var lastMessage: String? = nil
        // this flow looks strange, but basically we're working around waitForResult()'s exception -- it throws
        // VerificationFailed, and we want ElementNotReady
        do {
            try waitForProperty(seconds, desired: true) {
                do {
                    try $0.ready(usingCriteria: desired)
                    return true
                } catch IlluminatorExceptions.elementNotReady(let message) {
                    lastMessage = message
                    return false
                } catch {
                    return false
                }
            }
            return self
        } catch IlluminatorExceptions.verificationFailed(let failMessage) {
            throw IlluminatorExceptions.elementNotReady(message: (lastMessage ?? failMessage))
        }
    }

    func whenReady(_ secondsToWait: Double = 3.0) throws -> XCUIElement {
        return try whenReady(usingCriteria: defaultReadiness, withTimeout: secondsToWait)
    }

    public func waitForProperty<T: WaitForible>(_ seconds: Double, desired: T, getProperty: (XCUIElement) -> T) throws {
        try waitForResult(seconds, desired: desired, what: "waitForProperty") { () -> T in
            return getProperty(self)
        }
    }
}

