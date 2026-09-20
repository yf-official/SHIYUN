import Foundation

guard CommandLine.arguments.count == 3 else {
    fatalError("usage: simplify_json.swift input.json output.json")
}

let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let source = try String(contentsOf: input, encoding: .utf8)
let simplified = source.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? source
try simplified.write(to: output, atomically: true, encoding: .utf8)

