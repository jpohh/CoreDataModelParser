//
//  CanonicalFiles.swift
//  CoreDataModelParser
//
//  Created by James O'Leary on 8/19/15.
//  Copyright © 2015 James O'Leary. All rights reserved.
//

import Foundation

func typeForAttribute(attribute: Attribute) -> String {
    switch attribute.attributeType {
    case .UndefinedAttributeType:
        return "ERROR"
    case .Integer16AttributeType:
        return "Int16"
    case .Integer32AttributeType:
        return "Int32"
    case .Integer64AttributeType:
        return "Int64"
    case .DecimalAttributeType:
        return "NSDecimalNumber"
    case .DoubleAttributeType:
        return "Double"
    case .FloatAttributeType:
        return "Float"
    case .StringAttributeType:
        return "String"
    case .BooleanAttributeType:
        return "Bool"
    case .DateAttributeType:
        return "NSDate"
    case .BinaryDataAttributeType:
        return "NSData"
    case .TransformableAttributeType:
        return attribute.userInfo["attributeValueClassName"]!
    case .ObjectIDAttributeType:
        return "NSManagedObjectID"
    }
}

func typeForRelationship(relationship: Relationship) -> String {
    var type = ""
    if relationship.toMany {
        type = type + "Set<" + relationship.destinationEntityName + ">"
    } else {
        type = type + relationship.destinationEntityName
    }
    return type
}

func codeForProperty(property: Property) -> String {
    if let attribute = property as? Attribute {
        return codeForAttribute(attribute)
    } else if let relationship = property as? Relationship {
        return codeForRelationship(relationship)
    } else {
        assertionFailure("code can only be rendered for an attribute or relationship")
        return ""
    }
}

func codeForRelationship(relationship: Relationship) -> String {
    return "@NSManaged var " + relationship.name + ": " + typeForRelationship(relationship) + (relationship.optional ? "?" : ":")
}

func codeForAttribute(attribute: Attribute) -> String {
    return "@NSManaged var " + attribute.name + ": " + typeForAttribute(attribute) + (attribute.optional ? "?" : "")
}

func codeForAttributes(attributes: [Attribute]) -> [String] {
    return attributes.map(codeForAttribute)
}

func fileForEntity(entity: Entity) -> (filename: String, code: [String]) {
    var code = [String]()
    code.append("class \(entity.className): NSManagedObject {")
    code.extend(entity.properties.map(codeForProperty))
    code.append("}")
    code.append("")
    return ("\(entity.className).swift", code)
}
