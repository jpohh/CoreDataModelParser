//
//  CanonicalFiles.swift
//  CoreDataModelParser
//
//  Created by James O'Leary on 8/19/15.
//  Copyright © 2015 James O'Leary. All rights reserved.
//

import Foundation

//class CardReader: NSManagedObject {

//    @NSManaged var ipAddress: String
//    @NSManaged var name: String
//    @NSManaged var uniqueID: String
//    @NSManaged var devices: NSSet
//
//}

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

func codeForAttribute(attribute: Attribute) -> String {
    return "\t@NSManaged var " + attribute.name + ": " + typeForAttribute(attribute)
}

func codeForAttributes(attributes: [Attribute]) -> [String] {
    return attributes.map(codeForAttribute)
}

func fileForEntity(entity: Entity) -> (filename: String, code: [String]) {
    var code = [String]()
    code.append("class \(entity.className): NSManagedObject {")
    code.extend(codeForAttributes(entity.attributes))
    code.append("}")
    code.append("")
    return ("\(entity.className).swift", code)
}
