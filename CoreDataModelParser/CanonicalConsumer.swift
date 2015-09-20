//
//  CanonicalFiles.swift
//  CoreDataModelParser
//
//  Created by James O'Leary on 8/19/15.
//  Copyright © 2015 James O'Leary. All rights reserved.
//

import Foundation
import CoreData

struct CanconicalConsumer: ModelConsumer {
    var model: Model
    var files: [File] {
        var files: [File] = []
        files.appendContentsOf(entities.map{ $0.objCHeaderFile })
        return files
    }    
    var tests: [() -> Bool] {
        return []
    }
}

extension Attribute {
    var stringForType: String {
        switch self.attributeType {
        case .BinaryDataAttributeType:
            return "NSData *"
        case .BooleanAttributeType:
            return "BOOL "
        case .DateAttributeType:
            return "NSDate *"
        case .DecimalAttributeType:
            return "NSDecimalNumber *"
        case .DoubleAttributeType:
            return "double "
        case .FloatAttributeType:
            return "float "
        case .Integer16AttributeType:
            return "int16_t "
        case .Integer32AttributeType:
            return "int32_t "
        case .Integer64AttributeType:
            return "int64_t "
        case .ObjectIDAttributeType:
            return "NSManagedObjectID "
        case .StringAttributeType:
            return "NSString *"
        case .TransformableAttributeType:
            return userInfo["attributeValueClassName"]! + "*"
        case .UndefinedAttributeType:
            return ""
        }
    }
}

extension String {
    var first: String {
        return String(self[startIndex])
    }
    var last: String {
        return String(self[endIndex.predecessor()])
    }
    var uppercaseFirst:String {
        return first.uppercaseString + String(characters.dropFirst())
    }
}

extension Relationship {
    var customAccessorDeclarations: [String]? {
        guard toMany else { return nil }
        let prefix = "- (void)"
        let suffix = name.uppercaseFirst + ":(NSSet<" + destinationEntityName + " *> *)values;"
        return [ prefix + "add" + suffix, prefix + "remove" + suffix ]
    }
}

extension Property {
    var modifiers: String {
        var annotations: [String] = []
        if optional { annotations.append("nullable") }
        annotations.append("nonatomic")
        if self is Relationship {
            annotations.append("retain")
        } else if let attribute = self as? Attribute where attribute.stringForType.rangeOfString("*") != nil {
            annotations.append("retain")
        }
        return "(" + annotations.joinWithSeparator(", ") + ")"
    }
        
    var line: String {
        var line = "@property "
        line.appendContentsOf(modifiers)
        line.appendContentsOf(" ")
        if let relationship = self as? Relationship {
            if relationship.toMany {
                line.appendContentsOf("NSSet<" + relationship.destinationEntityName + " *> ")
            } else {
                line.appendContentsOf(relationship.destinationEntityName + " *")
            }
        } else if let attribute = self as? Attribute {
            line.appendContentsOf(attribute.stringForType)
        }
        line.appendContentsOf(name + ";")
        return line
    }
}

extension Entity {
    var objCHeaderFile: File {
        var lines = ["// CoreDataModelParser generated"]
        lines.appendContentsOf(["NS_ASSUME_NONNULL_BEGIN", ""])
        lines.appendContentsOf(["@interface " + name + ": JOManagedObject", ""])
        lines.appendContentsOf(properties.sort { $0.name < $1.name }.map { $0.line })
        lines.appendContentsOf([""])
        lines.appendContentsOf(relationships.map { $0.customAccessorDeclarations }.flatMap{ $0 }.flatMap { $0 })
        lines.appendContentsOf(["", "@end", "", "NS_ASSUME_NONNULL_END", ""])
        
        lines.appendContentsOf(["@implementation " + name, ""])
        lines.appendContentsOf(properties.map { property -> String? in
            property.transient ? nil : ("@dynamic " + property.name + ";")
        }.flatMap{ $0 })
        lines.appendContentsOf(["", "@end", ""])
        return File(name: name + ".h", lines: lines)
    }
    var objCImplementationFile: File {
        return File(name: name + ".m", lines: [])
    }
}