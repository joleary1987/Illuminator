//
//  IlluminatorElement.swift
//  Illuminator
//
//  Created by Ian Katz on 2016-12-12.
//




enum AbortIlluminatorTree: Error { // swift3: Error {
    case backtrack(data: IlluminatorElement?)
    case eof()
    case parseError(badLine: String)
    case doubleDepth(badLine: String)
}


class IlluminatorElement: Equatable {
    var source = ""                              // input data
    var depth = 0                                // interpretation of whitespace
    var parent: IlluminatorElement?              // linked list
    var children = [IlluminatorElement]()        // tree
    var elementType: XCUIElementType = .other    // tie back to automation elements
    var handle: UInt = 0                         // memory address, probably
    var traits: UInt = 0                         // bit flags, probably
    var x: Double?
    var y: Double?
    var w: Double?
    var h: Double?
    var isMainWindow = false                     // mainWindow is special
    var label: String?                           // accessibility label
    var identifier: String?                      // accessibility identifier
    var value: String?                           // field value
    var placeholderValue: String?                //
    
    var index: String? {
        get {
            return identifier ?? label
        }
    }
    
    var numericIndex: UInt? {
        get {
            return getNumericIndexMembership().0
        }
    }

    func getNumericIndexMembership() -> (UInt?, UInt) {
        guard let parent = parent else { return (0, 1) }
        let cohort = parent.childrenMatchingType(elementType)
        guard let idx = cohort.index(of: self) else { return (nil, 0) }
        return (UInt(idx), UInt(cohort.count))
    }

    func toString() -> String {
        let elementDesc = elementType.toString()
        return "\(elementDesc) - label: \(String(describing: label)) identifier: \(String(describing: identifier)) value: \(String(describing: value))"
    }
    
    func treeToString() -> String {
        // swift3 let indent = String(repeating: " ", count: depth)
        let indent = String(repeating: " ", count: depth)
        let childrenString = children.map{ $0.toString() }.joined(separator: "")
        return ["\(indent)\(toString())", childrenString].joined(separator: "\n")
    }
    
    // from a line of a debug description, create a standalone element
    static func fromDebugDescriptionLine(_ content: String) -> IlluminatorElement? {
        // regex crap
        let fc = "([\\d\\.]+)"        // float capture
        let pc = "\\{\(fc), \(fc)\\}" // pair capture
        let innerRE = "([ →]*)([^\\s]+) 0x([\\dabcdef]+): ([^{]*)?((\\{\(pc), \(pc)\\})?(, )?(.*)?)?"
        
        // safely regex capture
        let safeRegex = { (input: String, regex: String, capture: Int) -> String? in
            guard let field = input.matchingStrings(regex)[safe: 0] else { return nil }
            return field[safe: capture]
        }
        
        // safely extract data from the "extra" field at the end
        let safeExtra = { (input: String, label: String) -> String? in safeRegex(input, "\(label): '([^']*)'($|,)", 1) }
        
        // ensure doubles parse
        guard let matches = content.matchingStrings(innerRE)[safe: 0], matches.count > 12 else {
            return nil
        }
        
        // get depth
        let d = (matches[1].characters.count / 2) - 1
        guard d >= 0 else { return nil }
        
        // build return element
        let ret = IlluminatorElement()
        ret.depth        = d
        ret.elementType  = XCUIElementType.fromString(matches[2])
        ret.handle       = strtoul(matches[3], nil, 16)
        ret.x            = Double(matches[safe: 7] ?? "")
        ret.y            = Double(matches[safe: 8] ?? "")
        ret.w            = Double(matches[safe: 9] ?? "")
        ret.h            = Double(matches[safe: 10] ?? "")
        ret.source       = content
        
        let special      = matches[4]
        ret.isMainWindow = special.matchingStrings("Main Window").count == 1
        if let field = safeRegex(special, "traits: (\\d+)", 1),
            let trait = UInt(field) {
            ret.traits = trait
        }
        
        let extras           = matches[12]
        ret.label            = safeExtra(extras, "label")
        ret.identifier       = safeExtra(extras, "identifier")
        ret.value            = safeExtra(extras, "value")
        ret.placeholderValue = safeExtra(extras, "placeholderValue")
        
        return ret
    }

    @discardableResult
    fileprivate static func parseTreeHelper(_ parent: IlluminatorElement?, source: [String]) throws -> IlluminatorElement {
        guard let line = source.first else { throw AbortIlluminatorTree.eof() }
        
        guard let elem = IlluminatorElement.fromDebugDescriptionLine(line) else {
            throw AbortIlluminatorTree.parseError(badLine: line)
        }

        // process parent
        if let parent = parent {
            guard elem.depth - parent.depth == 1 else { throw AbortIlluminatorTree.backtrack(data: elem) }
            elem.parent = parent
            parent.children.append(elem)
        }
        
        // process children
        do {
            try parseTreeHelper(elem, source: source.tail)
        } catch AbortIlluminatorTree.eof {
            // no problem
        } catch AbortIlluminatorTree.backtrack(let data) {
            if let data = data, let parent = parent {
                // extra backtrack if necessary
                if data.depth - parent.depth < 1 {
                    throw AbortIlluminatorTree.backtrack(data: data)
                }
                
                if data.depth - parent.depth == 1 {
                    // fast forward the choices that occurred during recursion
                    let fastforward = Array(source[source.index(of: data.source)!..<source.count])
                    try parseTreeHelper(parent, source: fastforward)
                }
            }
        }
        return elem
    }
    
    // return a tree of IlluminatorElements from the relevant section of a debugDescription
    // or nil if there is a parse error
    fileprivate static func parseTree(_ content: String) -> IlluminatorElement? {
        let lines = content.components(separatedBy: "\n")
        guard lines.count > 0 else { return nil }
        
        let elems = lines.map() { (line: String) -> IlluminatorElement? in IlluminatorElement.fromDebugDescriptionLine(line) }
        let actualElems = elems.flatMap{ $0 }
        
        guard elems.count == actualElems.count else {
            for (i, elem) in elems.enumerated() {
                if elem == nil {
                    print("Illuminator BUG while parsing debugDescription line: \(lines[i])")
                }
            }
            return nil
        }
        
        do {
            return try parseTreeHelper(nil, source: lines)
        } catch AbortIlluminatorTree.backtrack {
            print("Somehow got a backtrack error at the top level of tree parsing")
        } catch AbortIlluminatorTree.parseError(let badLine) {
            print("Caught a parse error of \(badLine)")
        } catch {
            print("Caught an error that we didn't throw... somehow")
        }
        return nil
    }
    
    // return a tree of IlluminatorElements from a debugDescription
    static func fromDebugDescription(_ content: String) -> IlluminatorElement? {
        let outerRE = "\\n([^:]+):\\n( →.+(\\n .*)*)"
        let matches = content.matchingStrings(outerRE)
        let sections = matches.reduce([String: String]()) { dict, matches in
            var ret = dict
            ret[matches[1]] = matches[2]
            return ret
        }
        guard let section = sections["Element subtree"] else { return nil }
        return parseTree(section)
    }
    
    // given a chain of elements and a top level app, get the tail element
    fileprivate func toXCUIElementHelper(_ acc: [IlluminatorElement], app: XCUIApplication) -> XCUIElement {
        
        let finish = { (top: XCUIElement) in
            return acc.reduce(app) { (parent: XCUIElement, elem) in elem.toXCUIElementWith(parent: parent) }
        }
        
        guard elementType != XCUIElementType.application else { return finish(app) }
        guard let parent = parent else {
            print("Warning about toXCUIElementHelper not knowing it's done")
            return finish(app)
        }
        return parent.toXCUIElementHelper([self] + acc, app: app)
    }
    
    // given the parent element, get this element
    func toXCUIElementWith(parent p: XCUIElement) -> XCUIElement {
        return p.children(matching: elementType)[index ?? ""]
    }
    
    // given the app, work out the full reference to this element
    func toXCUIElement(_ app: XCUIApplication) -> XCUIElement {
        return toXCUIElementHelper([], app: app)
    }
    
    // recursively find the toplevel then construct a string
    fileprivate func toXCUIElementStringHelper(_ acc: [IlluminatorElement], appString: String) -> String? {
        let finish = { (top: String) -> String? in
            guard let last = acc.last else { return appString }
            guard last.elementType != XCUIElementType.other || last.index != nil else { return nil }
            return acc.reduce(appString) { (parentStr: String, elem) in elem.toXCUIElementStringWith(parentStr) }
            
        }
        
        guard elementType != XCUIElementType.application else { return finish(appString) }
        guard let parent = parent else {
            print("Warning about toXCUIElementStringHelper not knowing it's done: \(toString())")
            return finish(appString)
        }
        return parent.toXCUIElementStringHelper([self] + acc, appString: appString)
    }
    
    // given the parent element, get the string that comes from this element
    func toXCUIElementStringWith(_ parent: String) -> String {
        guard elementType != XCUIElementType.other || index != nil else { return parent }
        guard !isMainWindow else { return parent }
        
        let prefix = parent + ".\(elementType.toElementString())"
        
        // fall back on numeric index
        guard let idx = index else {
            let numericIndexPair = getNumericIndexMembership()

            switch numericIndexPair {
            case (.none, _):
                return "\(prefix).elementAtIndex(-1)"
            case (.some, 0):
                return "\(prefix).FAIL()"
            case (.some, 1):
                return "\(prefix)"
            case (.some(let nidx), _):
                return "\(prefix).elementAtIndex(\(nidx))"
 
            }

        }

        return "\(prefix)[\"\(idx)\"]"
    }
    
    // given the app string, work out the full string representing this element
    func toXCUIElementString(_ appString: String) -> String? {
        return toXCUIElementStringHelper([], appString: appString)
    }
    
    // get a dictionary of label -> element for the children
    func childrenMatchingType(_ elementType: XCUIElementType) -> [IlluminatorElement] {
        
        return children.reduce([IlluminatorElement]()) { arr, elem in
            guard elem.elementType == elementType else { return arr }
            var ret = arr
            ret.append(elem)
            return ret
        }
    }
    // get a dictionary of label -> element for the children
    func childrenMatchingTypeDict(_ elementType: XCUIElementType) -> [String: IlluminatorElement] {
        
        return children.reduce([String: IlluminatorElement]()) { dict, elem in
            guard let idx = elem.index else { return dict }
            guard elem.elementType == elementType else { return dict }
            var ret = dict
            ret[idx] = elem
            return ret
        }
    }
    
    func reduce<T>(_ initialResult: T, nextPartialResult: (T, IlluminatorElement) throws -> T) rethrows -> T {
        return try children.reduce(nextPartialResult(initialResult, self)) { (acc, nextElem) in
            return try nextElem.reduce(acc, nextPartialResult: nextPartialResult)
        }
    }
    
    
    // return a list of copy-pastable accessors representing elements on the screen
    static func accessorDump(_ appVarname: String, appDebugDescription: String) -> [String] {
        guard let parsedTree = IlluminatorElement.fromDebugDescription(appDebugDescription) else { return [] }
        
        let lines = parsedTree.reduce([String?]()) { (acc, elem) in
            let str = elem.toXCUIElementString(appVarname)
            return str == nil ? acc : acc + [str]
        }
        return lines.flatMap({$0})
    }
    
}

extension IlluminatorElement : Hashable {
    var hashValue: Int { return Int(handle) }
}

func ==(lhs: IlluminatorElement, rhs: IlluminatorElement) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

