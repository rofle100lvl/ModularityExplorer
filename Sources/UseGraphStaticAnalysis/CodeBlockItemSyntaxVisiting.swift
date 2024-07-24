import SwiftSyntax

protocol CodeBlockItemSyntaxVisiting {
    func visitCode(
        _ node: CodeBlockItemSyntax,
        graphDependencies: inout [String: Set<String>]
    ) -> SyntaxVisitorContinueKind

    func visitCode(
        _ node: MemberBlockItemSyntax,
        containerName: String,
        graphDependencies: inout [String: Set<String>]
    ) -> SyntaxVisitorContinueKind
}

final class CodeBlockItemSyntaxVisitor: CodeBlockItemSyntaxVisiting {
    let moduleName: String?

    init(moduleName: String?) {
        self.moduleName = moduleName
    }

    func visitCode(
        _ node: MemberBlockItemSyntax,
        containerName: String,
        graphDependencies: inout [String: Set<String>]
    ) -> SyntaxVisitorContinueKind {
        var name: String?
        var memberBlock: MemberBlockSyntax?
        switch node.decl.kind {
        case .structDecl:
            let structDecl = node.decl.as(StructDeclSyntax.self)
            memberBlock = structDecl?.memberBlock
            name = structDecl?.name.text
        case .classDecl:
            let classDecl = node.decl.as(ClassDeclSyntax.self)
            memberBlock = classDecl?.memberBlock
            name = classDecl?.name.text
        case .enumDecl:
            let enumDecl = node.decl.as(EnumDeclSyntax.self)
            memberBlock = enumDecl?.memberBlock
            name = enumDecl?.name.text
        default:
            break
        }

        if let name,
           let memberBlock
        {
            if var set = graphDependencies[containerName] {
                set.insert(containerName.appending(".").appending(name))
                graphDependencies[containerName] = set
            } else {
                graphDependencies[containerName] = Set<String>().union([containerName.appending(".").appending(name)])
            }
            diveInto(
                name: containerName.appending(".").appending(name),
                memberBlock: memberBlock,
                graphDependencies: &graphDependencies
            )
            return .skipChildren
        }
        return .visitChildren
    }

    func visitCode(
        _ node: CodeBlockItemSyntax,
        graphDependencies: inout [String: Set<String>]
    ) -> SyntaxVisitorContinueKind {
        var name: String?
        var memberBlock: MemberBlockSyntax?
        var isExtension = false

        switch node.item {
        case let .decl(declSyntax):
            switch declSyntax.kind {
            case .structDecl:
                let structDecl = node.item.as(StructDeclSyntax.self)
                memberBlock = structDecl?.memberBlock
                name = structDecl?.name.text
            case .classDecl:
                let classDecl = node.item.as(ClassDeclSyntax.self)
                memberBlock = classDecl?.memberBlock
                name = classDecl?.name.text
            case .enumDecl:
                let enumDecl = node.item.as(EnumDeclSyntax.self)
                memberBlock = enumDecl?.memberBlock
                name = enumDecl?.name.text
            case .extensionDecl:
                let extensionDecl = node.item.as(ExtensionDeclSyntax.self)
                memberBlock = extensionDecl?.memberBlock
                name = extensionDecl?.extendedType.as(IdentifierTypeSyntax.self)?.name.text
                isExtension = true
            default:
                break
            }
        default:
            break
        }

        if var name,
           let memberBlock
        {
            if isExtension {
                var index = 0
                while graphDependencies.keys.contains(name + "Ext\(index)") {
                    index += 1
                }
                name = name + "Ext\(index)"
            }
            diveInto(
                name: name,
                memberBlock: memberBlock,
                graphDependencies: &graphDependencies
            )
            return .skipChildren
        }
        return .visitChildren
    }

    private func diveInto(
        name: String,
        memberBlock: MemberBlockSyntax,
        graphDependencies: inout [String: Set<String>]
    ) {
        guard name != "Layout" && name != "PreviewModifier" && name != "Constants" else { return }
        let definitionVisitor = EntityVisitor(
            entityName: name,
            codeBlockItemSyntaxVisitor: self
        )
        definitionVisitor.walk(memberBlock)
        graphDependencies.merge(definitionVisitor.graphDependencies, uniquingKeysWith: { old, new in
            old.union(new)
        })
    }
}
