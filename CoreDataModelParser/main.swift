//
//  main.swift
//  CoreDataModelParser
//
//  Created by James O'Leary on 8/19/15.
//  Copyright © 2015 James O'Leary. All rights reserved.
//

import Foundation

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

let path = filePath.value!
let dataModel = NSURL(fileURLWithPath: path)
let model = Model(url: dataModel)
var consumers: [ModelConsumer] = []
let tests = consumers.map { $0.tests }.flatMap { $0 }
var testFailed = false
for test in tests {
    if !test() { testFailed = true }
}
guard !testFailed else {
    print("EXIT: tests failed")
    exit(EX_DATAERR)
}
guard let outputPath = outputPath.value else {
    print("EXIT: Can't output files. No output path was provided.")
    exit(EX_USAGE)
}
let sourceFiles = consumers.map { $0.files }.flatMap { $0 }
for file in sourceFiles {
    let allCode = file.lines.joinWithSeparator(",")
    let path = outputPath + "/generated/" + file.name
    do {
        try NSFileManager.defaultManager().createDirectoryAtPath(path, withIntermediateDirectories: true, attributes: nil)
        try allCode.writeToFile(path, atomically: false, encoding: NSUTF8StringEncoding)
        print("\(file.name) wrote to \(path)")
    } catch {
        print("EXIT: error writing file. \(error)")
        exit(EX_DATAERR)
    }
}
