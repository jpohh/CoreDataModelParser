//
//  ModelUtilities-Generated.swift
//  CoreDataModelParser
//
//  Created by James O'Leary on 9/21/15.

import Foundation

@objc protocol CoreDataEntity {
    static func entityName() -> String
    static func localizedNameSingular() -> String
    static func localizedNamePlural() -> String
    static func properties() -> [CoreDataProperty]
    var shortUniqueID: String { get }
    var uniqueID: String { get }
}

class KeyPath {
    class func build(properties: [Property]) -> String {
        return properties.map{ $0.key }.joinWithSeparator(".")
    }
}

protocol Property {
    var key: String { get }
    var localizedName: String { get }
}

protocol Relationship: Property {
    var toMany: Bool { get }
}

protocol Attribute: Property {
    var format: RFSFormat { get }
}

@objc class CoreDataProperty: NSObject, Property {
    let key: String
    let localizedName: String
    init(key k: String, localizedName l: String) {
        fatalError("don't create me")
    }
}

class CoreDataAttribute: CoreDataProperty, Attribute {
    let format: RFSFormat
    init(key k: String, localizedName l: String, format f: RFSFormat) {
        format = f
        super.init(key: k, localizedName: l)
    }
}

class CoreDataRelationship: CoreDataProperty, Relationship {
    let toMany: Bool
    init(key k: String, localizedName l: String, toMany t: Bool) {
        toMany = t
        super.init(key: k, localizedName: l)
    }
}

extension CoreDataEntity {
    static func inContext(context: NSManagedObjectContext) -> Self {
        return NSEntityDescription.insertNewObjectForEntityForName(entityName, inManagedObjectContext: context) as! Self
    }
    
    static var entityDescription: NSEntityDescription {
        return entity
    }
    
    static var entityName: String {
        return self.entityName()
    }
    
    static var entity: NSEntityDescription {
        return NSEntityDescription.entityForName(entityName, inManagedObjectContext: RFSDataController.managedObjectContext())!
    }
    
    var entity: NSEntityDescription {
        return Self.entity
    }
}

