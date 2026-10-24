import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct FallbackMacro: AccessorMacro, PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard
            let property = propertyInfo(from: node, declaration: declaration, context: context),
            let selectedValue = selectedValueExpression(from: node)
        else {
            return []
        }

        let getter: String
        let setter: String
        if isObservableState(context.lexicalContext) {
            guard let identifier = declaration.as(VariableDeclSyntax.self)?.bindings.first?
                .pattern.as(IdentifierPatternSyntax.self)?.identifier.text
            else { return [] }
            getter = "get { _$observationRegistrar.access(self, keyPath: \\.\(identifier)); return \(selectedValue) ?? self.\(property.storageName) }"
            setter = "set { _$observationRegistrar.mutate(self, keyPath: \\.\(identifier), &self.\(property.storageName), newValue, _$isIdentityEqual) }"
        } else {
            getter = "get { \(selectedValue) ?? self.\(property.storageName) }"
            setter = "set { self.\(property.storageName) = newValue }"
        }

        return [
            AccessorDeclSyntax(stringLiteral: getter),
            AccessorDeclSyntax(stringLiteral: setter),
        ]
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let property = propertyInfo(from: node, declaration: declaration, context: context) else {
            diagnoseInvalidUse(of: node, declaration: declaration, in: context)
            return []
        }

        let observationIgnored = isObservableState(context.lexicalContext)
            ? "@ObservationStateIgnored "
            : ""
        return [
            DeclSyntax(
                stringLiteral: "\(observationIgnored)private var \(property.storageName): \(property.type.trimmedDescription)"
            ),
        ]
    }

    private struct PropertyInfo {
        let storageName: String
        let type: TypeSyntax
    }

    private static func propertyInfo(
        from node: AttributeSyntax,
        declaration: some DeclSyntaxProtocol,
        context: some MacroExpansionContext
    ) -> PropertyInfo? {
        guard context.lexicalContext.contains(where: { $0.is(StructDeclSyntax.self) }),
              let variable = declaration.as(VariableDeclSyntax.self),
              variable.bindingSpecifier.text == "var",
              variable.bindings.count == 1,
              let binding = variable.bindings.first,
              binding.accessorBlock == nil,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
              let type = binding.typeAnnotation?.type,
              selectedValueExpression(from: node) != nil,
              !isObservableState(context.lexicalContext) || hasAttribute("ObservationStateIgnored", on: variable)
        else {
            return nil
        }

        return PropertyInfo(storageName: "_\(identifier.text)", type: type)
    }

    private static func selectedValueExpression(from node: AttributeSyntax) -> String? {
        guard case let .argumentList(arguments) = node.arguments,
              arguments.count == 1,
              let argument = arguments.first
        else {
            return nil
        }

        if argument.label == nil, argument.expression.is(KeyPathExprSyntax.self) {
            return "self[keyPath: \(argument.expression.trimmedDescription)]"
        }

        if argument.label?.text == "select" {
            return "(\(argument.expression.trimmedDescription))(self)"
        }

        return nil
    }

    private static func isObservableState(_ lexicalContext: [Syntax]) -> Bool {
        lexicalContext.compactMap { $0.as(StructDeclSyntax.self) }.contains { structure in
            structure.attributes.contains { attribute in
                attribute.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "ObservableState"
            }
        }
    }

    private static func hasAttribute(_ name: String, on variable: VariableDeclSyntax) -> Bool {
        variable.attributes.contains { attribute in
            attribute.as(AttributeSyntax.self)?.attributeName.trimmedDescription == name
        }
    }

    private static func diagnoseInvalidUse(
        of node: AttributeSyntax,
        declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) {
        let message: FallbackDiagnostic.Message
        if !context.lexicalContext.contains(where: { $0.is(StructDeclSyntax.self) }) {
            message = .structOnly
        } else if let variable = declaration.as(VariableDeclSyntax.self), variable.bindingSpecifier.text != "var" {
            message = .mutablePropertyOnly
        } else if let variable = declaration.as(VariableDeclSyntax.self),
                  variable.bindings.first?.typeAnnotation == nil {
            message = .explicitTypeRequired
        } else if let variable = declaration.as(VariableDeclSyntax.self), variable.bindings.count != 1 {
            message = .singlePropertyOnly
        } else if isObservableState(context.lexicalContext),
                  let variable = declaration.as(VariableDeclSyntax.self),
                  !hasAttribute("ObservationStateIgnored", on: variable) {
            message = .observationStateIgnoredRequired
        } else if let binding = declaration.as(VariableDeclSyntax.self)?.bindings.first,
                  binding.accessorBlock != nil {
            message = .storedPropertyOnly
        } else if selectedValueExpression(from: node) == nil {
            message = .selectionRequired
        } else {
            message = .storedPropertyOnly
        }

        context.diagnose(Diagnostic(node: Syntax(declaration), message: FallbackDiagnostic(message)))
    }

}

private struct FallbackDiagnostic: DiagnosticMessage {
    enum Message {
        case structOnly
        case mutablePropertyOnly
        case explicitTypeRequired
        case singlePropertyOnly
        case storedPropertyOnly
        case selectionRequired
        case observationStateIgnoredRequired
    }

    let reason: Message

    init(_ reason: Message) {
        self.reason = reason
    }

    var diagnosticID: MessageID {
        MessageID(domain: "FallbackMacro", id: String(describing: reason))
    }

    var severity: DiagnosticSeverity { .error }

    var message: String {
        switch reason {
        case .structOnly:
            "@Fallback can only be applied to a property in a struct"
        case .mutablePropertyOnly:
            "@Fallback requires a mutable 'var' property"
        case .explicitTypeRequired:
            "@Fallback requires an explicit property type"
        case .singlePropertyOnly:
            "@Fallback can only be applied to a declaration with one property"
        case .storedPropertyOnly:
            "@Fallback requires a stored property"
        case .selectionRequired:
            "@Fallback requires one key path argument or one 'select' closure argument"
        case .observationStateIgnoredRequired:
            "Add @ObservationStateIgnored to this property when using @ObservableState"
        }
    }
}
