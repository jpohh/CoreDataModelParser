//
//  Model.swift
//  CoreDataModelParser
//
//  Created by James O'Leary on 9/19/15.
//  Copyright © 2015 James O'Leary. All rights reserved.
//

import Foundation
import CoreData

struct Entity {
    let attributes: [Attribute]
    let className: String
    let name: String
    let parentEntityName: String
    var properties: [Property] {
        var properties = attributes.map { $0 as Property }
        properties.appendContentsOf(relationships.map { $0 as Property })
        return properties.sort { $0.name < $1.name }
    }
    let relationships: [Relationship]
    let renamingIdentifier: String?
    let syncable: Bool
    let userInfo: [String: String]
}

struct Attribute: Property {
    let attributeType: NSAttributeType
    let defaultValueAsString: String
    let entityName: String
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
    let entityName: String
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
    var entityName: String { get }
    var indexed: Bool { get }
    var name: String { get }
    var optional: Bool { get }
    var renamingIdentifier: String? { get }
    var storedInExternalRecord: Bool { get }
    var transient: Bool { get }
    var userInfo: [String: String] { get }
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
    let entityName = node.parent!.attributes["name"]!
    let indexed = node.attributes["indexed"] == "YES"
    let name = node.attributes["name"]!
    let optional = node.attributes["optional"] == "YES"
    let renamingIdentifier = node.attributes["renamingIdentifier"]
    let storedInExternalRecord = node.attributes["storedInExternalRecord"] == "YES"
    let syncable = node.attributes["syncable"] == "YES"
    let transient = node.attributes["transient"] == "YES"
    let children = node.childrenWithName("userInfo")
    let userInfo = userInfoFromNode(node)
    return Attribute(attributeType: attributeType, defaultValueAsString: defaultValue, entityName: entityName, indexed: indexed, name: name, optional: optional, renamingIdentifier: renamingIdentifier, storedInExternalRecord: storedInExternalRecord, syncable: syncable, transient: transient, userInfo: userInfo ?? [:])
}

let relationshipForNode: (JiNode) -> Relationship = { node in
    let deleteRuleString = node.attributes["deleteRule"]
    let deleteRule = NSDeleteRule.NoActionDeleteRule
    let destinationEntityName = node.attributes["destinationEntity"]!
    let entityName = node.parent!.attributes["name"]!
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
    return Relationship(deleteRule: deleteRule, destinationEntityName: destinationEntityName, entityName: entityName, indexed: indexed, maxCount: maxCount, minCount: minCount, name: name, optional: optional, ordered: ordered, renamingIdentifier: renamingIdentifier, storedInExternalRecord: storedInExternalRecord, transient: transient, userInfo: userInfo)
}


struct File {
    let name: String
    let lines: [String]
}

struct Model {
    let entities: [Entity]
    var attributes: [Attribute] { get {
        let a = self.entities.reduce([Attribute]()) { (allAttributes, entity: Entity) in
            var newArray = Array(allAttributes)
            newArray.appendContentsOf(entity.attributes)
            return newArray
        }
        return a
        }
    }
    
    init(url: NSURL) {
        let currentVersionPath = path + "/.xccurrentversion"
        guard let currentVersionData = NSData(contentsOfFile: currentVersionPath) else {
            print("no current version document")
            exit(EX_DATAERR)
        }
        guard let currentVersionDoc = Ji(xmlData: currentVersionData) else {
            print("current version document couldn't be loaded as XML")
            exit(EX_DATAERR)
        }
        
        guard let modelNameForCurrentVersion = currentVersionDoc.rootNode?.firstChildWithName("dict")?.firstChildWithName("string")?.value else {
            print("couldn't find name of file for most recent model version")
            exit(EX_DATAERR)
        }
        
        let modelPath = path + "/" + modelNameForCurrentVersion + "/contents"
        guard let modelData = NSData(contentsOfFile: modelPath) else {
            print("couldn't load current model as data")
            exit(EX_DATAERR)
        }
        
        guard let modelDocument = Ji(xmlData: modelData) else {
            print("couldn't render current model as XML")
            exit(EX_DATAERR)
        }
        guard let modelRootNode = modelDocument.rootNode else {
            print("couldn't load root node")
            exit(EX_DATAERR)
        }
        let entityNodes = modelRootNode.childrenWithName("entity")
        entities = entityNodes.map { (entity: JiNode) -> Entity in
            let attributes = entity.childrenWithName("attribute").map(attributeForNode)
            let relationships = entity.childrenWithName("relationship").map(relationshipForNode)
            let className = entity.attributes["representedClassName"]! // if you hit here you forget to specify a class name in the Core Data model
            let name = entity.attributes["name"]!
            let parentEntityName = entity.attributes["parentEntity"]
            let renamingIdentifier = entity.attributes["renamingIdentifier"]
            let syncable = entity.attributes["syncable"] == "YES"
            let userInfo = userInfoFromNode(entity)
            return Entity(attributes: attributes, className: className, name: name, parentEntityName: parentEntityName ?? "", relationships: relationships, renamingIdentifier: renamingIdentifier, syncable: syncable, userInfo: userInfo)
        }
    }
}


protocol ModelConsumer {
    var model: Model { get }
    var files: [File] { get }
    var tests: [ () -> Bool ] { get }
}

extension ModelConsumer {
    var entities: [Entity] {
        return model.entities
    }
}