//
//  Actions.swift
//  CoreDataModelParser
//
//  Created by James O'Leary on 8/19/15.
//  Copyright © 2015 James O'Leary. All rights reserved.
//

import Foundation

func verifyEntities(entities: [Entity]) -> Bool {
    for entity in entities {
        print(entity)
    }
    return true
}

func verifyAttributes(attributes: [Attribute]) -> Bool {
    for attribute in attributes {
        print(attribute)
    }
    return true
}

func generateSourceFiles(entities: [Entity], attributes: [Attribute]) -> [String: [String]]? {
    return nil
}

