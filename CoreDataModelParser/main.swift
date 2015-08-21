//
//  main.swift
//  CoreDataModelParser
//
//  Created by James O'Leary on 8/19/15.
//  Copyright © 2015 James O'Leary. All rights reserved.
//

import Foundation
import CoreData

let cli = CommandLine()
let filePath = StringOption(shortFlag: "f", longFlag: "file", required: true, helpMessage: "Path to the xcdatamodeld file")
let outputPath = StringOption(shortFlag: "o", longFlag: "output", required: false, helpMessage: "Where to direct output files to. In this location, they'll write to a directory called \"generated\", and all generated source files will live in there")
cli.addOption(filePath)
cli.addOption(outputPath)

do {
    try cli.parse()
} catch {
    cli.printUsage(error)
    exit(EX_USAGE)
}

struct Entity {
    let attributes: [Attribute]
    let className: String
    let name: String
    var properties: [Property] {
        var properties = attributes.map { $0 as Property }
        properties.extend(relationships.map { $0 as Property })
        return properties.sort { $0.name < $1.name }
    }
    let relationships: [Relationship]
    let renamingIdentifier: String?
    let syncable: Bool
}

struct Attribute: Property {
    let attributeType: NSAttributeType
    let defaultValueAsString: String
    let indexed: Bool
    let name: String
    let optional: Bool
    let renamingIdentifier: String?
    let storedInExternalRecord: Bool
    let syncable: Bool
    let transient: Bool
    let userInfo: [String: String]
}

struct Relationship: Property {
    let deleteRule: NSDeleteRule
    let destinationEntityName: String
    let indexed: Bool
    let maxCount: Int
    let minCount: Int
    let name: String
    let optional: Bool
    let ordered: Bool
    let renamingIdentifier: String?
    let storedInExternalRecord: Bool
    let transient: Bool
    var toMany: Bool  {
        return maxCount != 1
    }
    let userInfo: [String: String]
}

protocol Property {
    var indexed: Bool { get }
    var name: String { get }
    var optional: Bool { get }
    var renamingIdentifier: String? { get }
    var storedInExternalRecord: Bool { get }
    var transient: Bool { get }
    var userInfo: [String: String] { get }
}

let path = filePath.value!
let currentVersionPath = path + "/.xccurrentversion"
let currentVersionData = NSData(contentsOfFile: currentVersionPath)
guard let currentVersionData = currentVersionData else {
    print("no current version document")
    exit(EX_DATAERR)
}
let currentVersionDoc = Ji(xmlData: currentVersionData)
guard let currentVersionDoc = currentVersionDoc else {
    print("current version document couldn't be loaded as XML")
    exit(EX_DATAERR)
}

let modelNameForCurrentVersion = currentVersionDoc.rootNode?.firstChildWithName("dict")?.firstChildWithName("string")?.value
guard let modelNameForCurrentVersion = modelNameForCurrentVersion else {
    print("couldn't find name of file for most recent model version")
    exit(EX_DATAERR)
}

let modelPath = path + "/" + modelNameForCurrentVersion + "/contents"
let modelData = NSData(contentsOfFile: modelPath)
guard let modelData = modelData else {
    print("couldn't load current model as data")
    exit(EX_DATAERR)
}
print(modelData.length)
let modelDocument = Ji(xmlData: modelData)
guard let modelDocument = modelDocument else {
    print("couldn't render current model as XML")
    exit(EX_DATAERR)
}
guard let modelRootNode = modelDocument.rootNode else {
    print("couldn't load root node")
    exit(EX_DATAERR)
}

func attributeTypeForString(string: String?) -> NSAttributeType {
    guard let string = string else {
        return .UndefinedAttributeType
    }
    switch string {
    case "Binary Data":
        return .BinaryDataAttributeType
    case "Boolean":
        return .BooleanAttributeType
    case "Date":
        return .DateAttributeType
    case "Decimal":
        return .DecimalAttributeType
    case "Double":
        return .DoubleAttributeType
    case "Float":
        return .FloatAttributeType
    case "Integer 16":
        return .Integer16AttributeType
    case "Integer 32":
        return .Integer32AttributeType
    case "Integer 64":
        return .Integer64AttributeType
    case "Object ID":
        return .ObjectIDAttributeType
    case "String":
        return .StringAttributeType
    case "Transformable":
        return .TransformableAttributeType
    default:
        return .UndefinedAttributeType
    }
}

func userInfoFromString(string: String?) -> [String: String] {
    var userInfo = [String: String]()
    guard let string = string else { return userInfo }
    let scanner = NSScanner(string: string)
    while !scanner.atEnd {
        scanner.scanUpToString("<entry key=\"", intoString: nil)
        scanner.scanString("<entry key=\"", intoString: nil)
        var key: NSString?
        scanner.scanUpToString("\"", intoString: &key)
        scanner.scanString("\" value=\"", intoString: nil)
        var value: NSString?
        scanner.scanUpToString("\"", intoString: &value)
        userInfo[key as? String ?? ""] = value as? String ?? ""
    }
    return userInfo
}

func userInfoFromNode(node: JiNode) -> [String: String] {
    let children = node.childrenWithName("userInfo")
    let userInfo = children.first?.children.reduce([String: String]()) { (dict, node) -> [String: String] in
        var added = dict
        added[node.attributes["key"]!] = node.attributes["value"]!
        return added
    }
    return userInfo ?? [:]
}

let attributeForNode: (JiNode) -> (Attribute) = { node in
    let attributeTypeString = node.attributes["attributeType"]
    let attributeType = attributeTypeForString(attributeTypeString)
    let defaultValue = node.attributes["defaultValueString"] ?? ""
    let indexed = node.attributes["indexed"] == "YES"
    let name = node.attributes["name"]!
    let optional = node.attributes["optional"] == "YES"
    let renamingIdentifier = node.attributes["renamingIdentifier"]
    let storedInExternalRecord = node.attributes["storedInExternalRecord"] == "YES"
    let syncable = node.attributes["syncable"] == "YES"
    let transient = node.attributes["transient"] == "YES"
    let children = node.childrenWithName("userInfo")
    let userInfo = userInfoFromNode(node)
    return Attribute(attributeType: attributeType, defaultValueAsString: defaultValue, indexed: indexed, name: name, optional: optional, renamingIdentifier: renamingIdentifier, storedInExternalRecord: storedInExternalRecord, syncable: syncable, transient: transient, userInfo: userInfo ?? [:])
}

let relationshipForNode: (JiNode) -> Relationship = { node in
    let deleteRuleString = node.attributes["deleteRule"]
    let deleteRule = NSDeleteRule.NoActionDeleteRule
    let destinationEntityName = node.attributes["destinationEntity"]!
    let indexed = node.attributes["indexed"] == "YES"
    let maxCount = Int(node.attributes["maxCount"] ?? "0")!
    let minCount = Int(node.attributes["minCount"] ?? "0")!
    let name = node.attributes["name"]!
    let optional = node.attributes["optional"] == "YES"
    let ordered = node.attributes["ordered"] == "YES"
    let renamingIdentifier = node.attributes["renamingIdentifier"]
    let storedInExternalRecord = node.attributes["storedInExternalRecord"] == "YES"
    let transient = node.attributes["transient"] == "YES"
    var toMany: Bool  {
        return maxCount  > 1
    }
    let userInfo = userInfoFromNode(node)
    return Relationship(deleteRule: deleteRule, destinationEntityName: destinationEntityName, indexed: indexed, maxCount: maxCount, minCount: minCount, name: name, optional: optional, ordered: ordered, renamingIdentifier: renamingIdentifier, storedInExternalRecord: storedInExternalRecord, transient: transient, userInfo: userInfo)
}

let entityNodes = modelRootNode.childrenWithName("entity")
let entities = entityNodes.map { (entity: JiNode) -> Entity in
    let attributes = entity.childrenWithName("attribute").map(attributeForNode)
    let relationships = entity.childrenWithName("relationship").map(relationshipForNode)
    let className = entity.attributes["representedClassName"]!
    let name = entity.attributes["name"]!
    let renamingIdentifier = entity.attributes["renamingIdentifier"]
    let syncable = entity.attributes["syncable"] == "YES"
    return Entity(attributes: attributes, className: className, name: name, relationships: relationships, renamingIdentifier: renamingIdentifier, syncable: syncable)
}

struct Model {
    let entities: [Entity]
    var attributes: [Attribute] { get {
        let a = self.entities.reduce([Attribute]()) { (allAttributes, entity: Entity) in
            var newArray = Array(allAttributes)
            newArray.extend(entity.attributes)
            return newArray
        }
        return a
        } }
    
    var entitiesVerifiedCorrectly: Bool {
        return verifyEntities(entities)
    }
    
    var attributesVerifiedCorrectly: Bool {
        return verifyAttributes(attributes)
    }
    
    var sourceFiles: [(filename: String, code: [String])] {
        return generateSourceFiles(entities, attributes: attributes)
    }
}



let model = Model(entities: entities)
guard model.entitiesVerifiedCorrectly else {
    print("EXIT: Entity verification failed. Check your verifyEntities implementation in Model.swift")
    exit(EX_DATAERR)
}
guard model.attributesVerifiedCorrectly else {
    print("EXIT: Attribute verification failed. Check your verifyAttributes implementation in Model.swift")
    exit(EX_DATAERR)
}
let sourceFiles = model.sourceFiles
guard let outputPath = outputPath.value else {
    print("EXIT: Can't output files. No output path was provided.")
    exit(EX_USAGE)
}

for (filename, code) in sourceFiles {
    let allCode = "\n".join(code)
    let filePath = outputPath + "/generated"
    let path = filePath + "/" + filename
    do {
        try NSFileManager.defaultManager().createDirectoryAtPath(filePath, withIntermediateDirectories: true, attributes: nil)
        try allCode.writeToFile(path, atomically: false, encoding: NSUTF8StringEncoding)
        print("wrote to \(path)")
    } catch {
        print("EXIT: error writing file. \(error)")
        exit(EX_DATAERR)
    }
}
