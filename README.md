# CoreDataModelParser
A typed interface to a Core Data model file, written in Swift.

I wrote this so I could write type-safe Core Data code in late August 2015, because Xcode 6.4 doesn't support Objective-C generics, and Xcode 7.0 isn't GM yet, and the Swift code generation from a Core Data model doesn't have typed relationships.

I didn't want to have to write out 32 separate model classes manually just to have the proper types, so I begin thinking about code generation. mogenerator would fit the bill, but I've tried working with it in the past, and it didn't provide the flexibility I wanted to get at the model, so I could run verification functions to make sure I've done things like put a "uniqueID" attribute typed as a String on each entity. Currently, the trade-off is that this codebase isn't nearly as tested, flexible, and has caveman-like code generation by comparison. mogenerator has full templating, CoreDataModelParser merely will take a dictionary [(filename: String): (code: [String]), and write (code) out to (file) on disk.

I'm not sure where this will be going – right now my only goal is to get it to write out Swift 1.2-compatible source files for all the managed objects. I'll be confining that work to CanonicalFiles.swift. The object of that file is to generate basic model files for the most recent version of Swift that can be used for iOS App Store submission.

The intention of Actions.swift is to provide a place for people to insert their own validation logic. It should probably be in the .gitignore, actually. I'll have to look into that.

After source code generation, the next goal of the project will be to expose the Model struct in a way that model tests could easily be integrate into XCTest.

