import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import FallbackMacros

final class FallbackMacroTests: XCTestCase {
    private let macros: [String: Macro.Type] = ["Fallback": FallbackMacro.self]

    func testGeneratesAccessorsAndPrivateStorage() {
        assertMacroExpansion(
            #"""
            struct State {
              let parent: Parent
              @Fallback(\State.parent.child)
              var child: Child
            }
            """#,
            expandedSource: #"""
            struct State {
              let parent: Parent
              var child: Child {
                  get {
                      self[keyPath: \State.parent.child] ?? self._child
                  }
                  set {
                      self._child = newValue
                  }
              }

              private var _child: Child
            }
            """#,
            macros: macros
        )
    }

    func testSupportsMultiLevelKeyPathsAndMultipleProperties() {
        assertMacroExpansion(
            #"""
            struct State {
              let parent: Parent
              @Fallback(\State.parent.context.child)
              var child: Child
              @Fallback(\State.parent.context.district)
              var district: District
            }
            """#,
            expandedSource: #"""
            struct State {
              let parent: Parent
              var child: Child {
                  get {
                      self[keyPath: \State.parent.context.child] ?? self._child
                  }
                  set {
                      self._child = newValue
                  }
              }

              private var _child: Child
              var district: District {
                  get {
                      self[keyPath: \State.parent.context.district] ?? self._district
                  }
                  set {
                      self._district = newValue
                  }
              }

              private var _district: District
            }
            """#,
            macros: macros
        )
    }

    func testDiagnosesLetProperty() {
        assertMacroExpansion(
            #"""
            struct State {
              let parent: Parent
              @Fallback(\State.parent.child) let child: Child
            }
            """#,
            expandedSource: #"""
            struct State {
              let parent: Parent
              let child: Child
            }
            """#,
            diagnostics: [
                DiagnosticSpec(message: "@Fallback requires a mutable 'var' property", line: 3, column: 3),
            ],
            macros: macros
        )
    }

    func testDiagnosesMissingType() {
        assertMacroExpansion(
            #"""
            struct State {
              let parent: Parent
              @Fallback(\State.parent.child) var child
            }
            """#,
            expandedSource: #"""
            struct State {
              let parent: Parent
              var child
            }
            """#,
            diagnostics: [
                DiagnosticSpec(message: "@Fallback requires an explicit property type", line: 3, column: 3),
            ],
            macros: macros
        )
    }

}
