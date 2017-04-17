//
//  IlluminatorTestProgress.swift
//  Pods
//
//  Created by Katz, Ian on 3/16/16.
//
//

import Foundation
import XCTest

/*
 * This protocol allows custom handling of results.  For example, screenshots of failure states or desktop notifications
 * isPass and isFail can both be false -- it indicates a "Flagging" state.  They are guaranteed to not both be true
 */
public protocol IlluminatorTestResultHandler {
    associatedtype AbstractStateType: CustomStringConvertible
    func handleTestResult(_ progress: IlluminatorTestProgress<AbstractStateType>) -> ()
}


// cheap hack to get a generic protocol
// https://milen.me/writings/swift-generic-protocols/
struct IlluminatorTestResultHandlerThunk<T: CustomStringConvertible> : IlluminatorTestResultHandler {
    typealias AbstractStateType = T
    
    // closure which will be used to implement `handleTestResult()` as declared in the protocol
    fileprivate let _handleTestResult : (IlluminatorTestProgress<T>) -> ()
    
    // `T` is effectively a handle for `AbstractStateType` in the protocol
    init<P : IlluminatorTestResultHandler>(_ dep : P) where P.AbstractStateType == T {
        // requires Swift 2, otherwise create explicit closure
        _handleTestResult = dep.handleTestResult
    }
    
    func handleTestResult(_ progress: IlluminatorTestProgress<AbstractStateType>) -> () {
        // any protocol methods are implemented by forwarding
        return _handleTestResult(progress)
    }
}


/*
 * This enum uses some functional magic to apply a set of device actions to an initial (passing) state.
 * Each action acts on the current state of the XCUIApplication() and a state variable that may optionally be passed to it
 * Thus, each action is by itself stateless.
 */
@available(iOS 9.0, *)
public enum IlluminatorTestProgress<T: CustomStringConvertible> {
    case passing(T)
    case flagging(T, [String])
    case failing(T, [String])

    func actionDescription(_ action: IlluminatorActionGeneric<T>) -> String {
        guard let screen = action.screen else {
            return "<screenless> \(action.description)"
        }
        return "\(screen.description).\(action.description)"
    }

    // apply an action to a state of progress, returning a new state of progress
    func applyAction(_ action: IlluminatorActionGeneric<T>, checkScreen: Bool) -> IlluminatorTestProgress<T> {
        var myState: T!
        var myErrStrings: [String]!
        
        // fall-through fail, or pick up state and strings
        switch self {
        case .failing:
            return self
        case .flagging(let state, let errStrings):
            myState = state
            myErrStrings = errStrings
        case .passing(let state):
            myState = state
            myErrStrings = []
        }
        
        print("Applying \(actionDescription(action))")

        // check the screen first, because if it fails here then it's a total failure
        if checkScreen {
            if let s = action.screen {
                do {
                    try s.becomesActive()
                } catch IlluminatorExceptions.incorrectScreen(let message) {
                    myErrStrings.append(message)
                    return .failing(myState, myErrStrings)
                } catch let unknownError {
                    myErrStrings.append("Caught error: \(unknownError)")
                    return .failing(myState, myErrStrings)
                }
            }
        }
        
        // tiny function to decorate action errors
        let decorate = {(label: String, message: String) -> String in
            return "\(action.description) \(label): \(message)"
        }
        
        // passing, flagging, or failing as appropriate
        do {
            let newState = try action.task(myState)
            if myErrStrings.isEmpty {
                return .passing(newState)
            } else {
                return .flagging(newState, myErrStrings)
            }
        } catch IlluminatorExceptions.warning(let message) {
            myErrStrings.append(decorate("warning", message))
            return .flagging(myState, myErrStrings)
        } catch IlluminatorExceptions.incorrectScreen(let message) {
            myErrStrings.append(decorate("failed screen check", message))
            return .failing(myState, myErrStrings)
            //} catch IlluminatorExceptions.IndeterminateState(let message) {
            //    myErrStrings.append(decorate("indeterminate state", message))
            //    return .Failing(myErrStrings)
            //} catch IlluminatorExceptions.VerificationFailed(let message) {
            //    myErrStrings.append(decorate("verification failed", message))
            //    return .Failing(myErrStrings)
        } catch let unknownError {
            myErrStrings.append("Caught error: \(unknownError)")
            return .failing(myState, myErrStrings)
        }
    }
    
    // apply an action, checking the screen first
    public func apply(_ action: IlluminatorActionGeneric<T>) -> IlluminatorTestProgress<T> {
        return applyAction(action, checkScreen: true)
    }
    
    // apply an action, without checking the screen first
    public func blindly(_ action: IlluminatorActionGeneric<T>) -> IlluminatorTestProgress<T> {
        return applyAction(action, checkScreen: false)
    }
    
    // handle the final result using a protocol-conformant object
    // then either pass or fail
    public func finish<P: IlluminatorTestResultHandler>(_ handler: P) where P.AbstractStateType == T {
        let genericHandler: IlluminatorTestResultHandlerThunk<T> = IlluminatorTestResultHandlerThunk(handler)
        genericHandler.handleTestResult(self)
        
        // worst case, we handle it ourselves with a default implementation
        finish()
    }

    // handle the final result using a passed-in closure 
    // then either pass or fail
    public func finish(_ handler: (IlluminatorTestProgress<T>) -> ()) {
        handler(self)
        finish()
    }
    
    // interpret the final result in XCTest terms.  this will pass or fail
    public func finish() {
        XCTAssert(self)
    }
    
}

// How to assert Illuminator test progress is pass
public func XCTAssert<T>(_ progress: IlluminatorTestProgress<T>, file f: StaticString = #file, line l: UInt = #line) {
    switch progress {
    case .failing(_, let errStrings):
        XCTFail("Illuminator Failure: \(errStrings.joined(separator: "; "))", file: f, line: l)
    case .flagging(_, let errStrings):
        XCTFail("Illuminator Deferred Failure: \(errStrings.joined(separator: "; "))", file: f, line: l)
    case .passing:
        return
    }
}

