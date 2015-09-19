//
//  CanonicalFiles.swift
//  CoreDataModelParser
//
//  Created by James O'Leary on 8/19/15.
//  Copyright © 2015 James O'Leary. All rights reserved.
//

import Foundation

struct Canconical: ModelConsumer {
    var model: Model
    var files: [File] {
        return []
    }    
    var tests: [() -> Bool] {
        return []
    }
}