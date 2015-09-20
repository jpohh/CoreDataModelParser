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
        var files = entities.map{ $0.objCHeaderFile }
        files.append(model.swiftFile)
        files.append(model.objCAllHeadersFile)
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

extension Model {
    var swiftFile: File {
        var lines = [String]()
        lines.appendContentsOf(["// CoreDataModelParser generated", ""])
        lines.appendContentsOf(["@objc protocol CoreDataEntity {", "\tstatic var entityName: String { get }", "}", ""])
        entities.forEach { entity in
            lines.append("extension " + entity.className + ": CoreDataEntity {")
            lines.append("\t@objc static let entityName = \"" + entity.name + "\"")
            lines.append("}")
            lines.append("")
        }
        return File(name: "ModelUtilities-Generated.swift", lines: lines)
    }
    var objCAllHeadersFile: File {
        var lines = [String]()
        lines.appendContentsOf(entities.map { "#import \"" + $0.name + ".h\"" })
        lines.append("")
        return File(name: "Model-All.h", lines: lines)
    }
}

extension Property {
    var modifiers: String {
        var annotations: [String] = []
        if optional && isObjectType { annotations.append("nullable") }
        annotations.append("nonatomic")
        if isObjectType { annotations.append("retain") }
        return "(" + annotations.joinWithSeparator(", ") + ")"
    }
    
    var isObjectType: Bool {
        if self is Relationship {
            return true
        } else if let attribute = self as? Attribute where attribute.stringForType.rangeOfString("*") != nil {
            return true
        } else {
            return false
        }
    }
        
    var line: String {
        var line = "@property "
        line.appendContentsOf(modifiers)
        line.appendContentsOf(" ")
        if let relationship = self as? Relationship {
            if relationship.toMany {
                line.appendContentsOf("NSSet<" + relationship.destinationEntityName + " *> *")
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
    var superclassName: String {
        if !usingDefaultSuperclass {
            return parentEntityName
        } else {
            return "NSManagedObject"
        }
    }
    
    var usingDefaultSuperclass: Bool {
        return parentEntityName.isEmpty
    }
    
    var objCHeaderFile: File {
        var lines = ["// CoreDataModelParser generated"]
        if !usingDefaultSuperclass {
            lines.appendContentsOf(["", "#import \"" + superclassName + ".h\"", ""])
        }
        lines.appendContentsOf(relationships.map { "@class " + $0.destinationEntityName + ";" })
        lines.appendContentsOf(["NS_ASSUME_NONNULL_BEGIN", ""])
        lines.appendContentsOf(["@interface " + className + ": " + superclassName, ""])
        let nonTransientProperties = properties.filter { !$0.transient }.sort { $0.name < $1.name }
        lines.appendContentsOf(nonTransientProperties.map { $0.line })
        lines.appendContentsOf(["", "@end"])

        let customAccessors = relationships.map { $0.customAccessorDeclarations }.flatMap{ $0 }.flatMap { $0 }
        if !customAccessors.isEmpty {
            lines.appendContentsOf(["", "@interface " + className + " (CoreDataGeneratedAccessors)", ""])
            lines.appendContentsOf(customAccessors)
            lines.appendContentsOf(["", "@end"])
        }
        lines.appendContentsOf(["", "NS_ASSUME_NONNULL_END", ""])
        
        lines.appendContentsOf(["", "@implementation " + name, ""])
        lines.appendContentsOf(properties.map { property -> String? in
            property.transient ? nil : ("@dynamic " + property.name + ";")
        }.flatMap{ $0 })
        lines.appendContentsOf(["", "@end", ""])
        return File(name: name + ".h", lines: lines)
    }
}
