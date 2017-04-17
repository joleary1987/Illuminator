//
//  XCUIElementQuery.swift
//  Illuminator
//
//  Created by Katz, Ian on 10/23/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest


// Swift doesn't allow subscripts to throw
// so we're going to invent our own subscript operator with quill brackets ⁅ ⁆
// inspired by https://gist.github.com/pyrtsa/05baea18e568f72c8e55
// This way we can subscript and get thrown exceptions instead of XCFail()s
// until https://openradar.appspot.com/23296820 gets fixed (which is unlikely)
// also
// our own subscript operator with white brackets 〚 〛 
// which will return an array of matching elements



infix operator ⁅ { associativity left }
postfix operator ⁆ {}

public struct QuillBracketIndex {
    let value: String
}

postfix func ⁆ (index: String) -> QuillBracketIndex {
    return QuillBracketIndex(value: index)
}

public func ⁅ (query: XCUIElementQuery, index: String) throws -> XCUIElement {
    return try query.hardSubscript(index)
}

public func ⁅ (query: XCUIElementQuery, index: QuillBracketIndex) throws -> XCUIElement {
    return try query.hardSubscript(index.value)
}


infix operator〚 { associativity left }
postfix operator 〛 {}

public struct WhiteBracketIndex {
    let value: String
}

public postfix func 〛 (index: String) -> WhiteBracketIndex {
    return WhiteBracketIndex(value: index)
}

public func 〚 (query: XCUIElementQuery, index: String) -> [XCUIElement] {
    return query.subscriptsMatching(index)
}

public func 〚 (query: XCUIElementQuery, index: WhiteBracketIndex) -> [XCUIElement] {
    return query.subscriptsMatching(index.value)
}


extension XCUIElementQuery {
    func subscriptsMatching(_ label: String) -> [XCUIElement] {
        return self.allElementsBoundByAccessibilityElement.reduce([XCUIElement]()) { (acc, elem) in
            print("Checking \(elem) (\(elem.elementType)): \(elem.label)")
            guard elem.label == label else { return acc }
            var nextAcc = acc
            nextAcc.append(elem)
            return nextAcc
        }
    }

    // Do a subscript operation, but fail immediately unless the subscript returns one and only one match
    func hardSubscript(_ index: String) throws -> XCUIElement {
        let matchingElements = allElementsBoundByAccessibilityElement.reduce(0) { (acc, elem) in
            guard elem.label == index else { return acc }
            return acc + 1
        }

        switch matchingElements {
        case 0: throw IlluminatorExceptions.elementNotFound(message: "No elements match the label \"\(index)\"")
        case 1: return self[index]
        default: throw IlluminatorExceptions.multipleElementsFound(message: "Multiple elements match the label \"\(index)\"")
        }
    }
    

}

// allow for-in with elements
// http://design.featherless.software/minimal-swift-protocol-conformance/
//
extension XCUIElementQuery: Sequence {
    public typealias Iterator = AnyIterator<XCUIElement>
    public func makeIterator() -> Iterator {
        var index = UInt(0)
        return AnyIterator {
            guard index < self.count else { return nil }
            
            let element = self.element(boundBy: index)
            index = index + 1
            return element
        }
    }
}

/*
 // please figure out how to do this
 extension XCUIElementQuery: CollectionType {
 subscript(index: Index) -> Generator.Element {
 return elementBoundByIndex(index)
 }
 
 var startIndex : Index { return 0 }
 var endIndex : Index { return Index(UInt(count) - 1) }
 
 }
 */

