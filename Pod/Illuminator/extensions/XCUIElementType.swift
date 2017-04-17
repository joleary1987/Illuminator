//
//  XCUIElementType.swift
//  Illuminator
//
//  Created by Katz, Ian on 10/23/15.
//  Copyright © 2015 PayPal, Inc. All rights reserved.
//

import XCTest
@available(iOS 9.0, *)

let debugStringOfXCUIElementType: [XCUIElementType: String] = [
    .other: "Other",
    .application: "Application",
    .activityIndicator: "ActivityIndicator",
    .alert: "Alert",
    .button: "Button",
    .browser: "Browser",
    .cell: "Cell",
    .checkBox: "CheckBox",   //////////
    .collectionView: "CollectionView",
    .colorWell: "ColorWell",
    .comboBox: "ComboBox",   /////
    .datePicker: "DatePicker",
    .decrementArrow: "DecrementArrow",
    .dialog: "Dialog",
    .disclosureTriangle: "DisclosureTriangle",
    .dockItem: "DockItem",
    .drawer: "Drawer",
    .grid: "Grid",
    .group: "Group",
    .handle: "Handle",
    .helpTag: "HelpTag",
    .icon: "Icon",
    .image: "Image",
    .incrementArrow: "IncrementArrow",
    .key: "Key",
    .keyboard: "Keyboard",
    .layoutArea: "LayoutArea",
    .layoutItem: "LayoutItem",
    .levelIndicator: "LevelIndicator",
    .link: "Link",
    .map: "Map",
    .matte: "Matte",
    .menu: "Menu",
    .menuBar: "MenuBar",
    .menuBarItem: "MenuBarItem",
    .menuButton: "MenuButton",
    .menuItem: "MenuItem",
    .navigationBar: "NavigationBar",
    .outline: "Outline",
    .outlineRow: "OutlineRow",
    .pageIndicator: "PageIndicator",
    .picker: "Picker",
    .pickerWheel: "PickerWheel",
    .popover: "Popover",
    .popUpButton: "PopUpButton",
    .progressIndicator: "ProgressIndicator",
    .radioButton: "RadioButton",
    .radioGroup: "RadioGroup",
    .ratingIndicator: "RatingIndicator",
    .relevanceIndicator: "RelevanceIndicator",
    .ruler: "Ruler",
    .rulerMarker: "RulerMarker",
    .scrollBar: "ScrollBar",
    .scrollView: "ScrollView",
    .searchField: "SearchField",
    .secureTextField: "SecureTextField",
    .segmentedControl: "SegmentedControl",
    .sheet: "Sheet",
    .slider: "Slider",
    .splitGroup: "SplitGroup",
    .splitter: "Splitter",
    .staticText: "StaticText",
    .statusBar: "StatusBar",
    .stepper: "Stepper",
    .switch: "Switch", /////
    .tab: "Tab",
    .tabBar: "TabBar",
    .tabGroup: "TabGroup",
    .table: "Table",
    .tableColumn: "TableColumn",
    .tableRow: "TableRow",
    .textField: "TextField",
    .textView: "TextView",
    .timeline: "Timeline",
    .toggle: "Toggle",
    .toolbar: "Toolbar",
    .toolbarButton: "ToolbarButton",
    .valueIndicator: "ValueIndicator",
    .webView: "WebView",
    .window: "Window"]

let theXCUIElementTypeOfDebugString = debugStringOfXCUIElementType.reduce([String: XCUIElementType]()) { (acc, pair) in
    var ret = acc
    ret[pair.1] = pair.0
    return ret
}


extension XCUIElementType {
    
    static func fromString(_ description: String) -> XCUIElementType {
        guard let val = theXCUIElementTypeOfDebugString[description] else { return .other }
        return val
    }
    
    func toString() -> String {
        guard let val = debugStringOfXCUIElementType[self] else { return "<Unknown \(self)>" }
        return val
    }
    
    func toElementString() -> String {
        switch (self) {
        case .checkBox: return "checkBoxes"
        case .comboBox: return "comboBoxes"
        case .switch: return "switches"
        default:
            let capSingular = toString()
            let fixedCase = String(capSingular.characters.prefix(1)).lowercased() + String(capSingular.characters.dropFirst())
            return "\(fixedCase)s"
        }
    }
}

