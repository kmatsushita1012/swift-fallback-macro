import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct FallbackPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [FallbackMacro.self]
}
