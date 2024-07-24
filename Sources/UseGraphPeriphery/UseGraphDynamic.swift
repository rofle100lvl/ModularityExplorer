import ArgumentParser
import Foundation
import PeripheryKit
import Shared
import XcodeSupport

struct Reference: Hashable, Comparable {
    static func < (lhs: Reference, rhs: Reference) -> Bool {
        lhs.file < rhs.file || lhs.line < rhs.line
    }

    let line: Int
    let file: String
}

struct Edge: Hashable {
    let from: Node
    let to: Node
    let references: [Reference]
}

struct EdgeWithoutReference: Hashable {
    let from: Node
    let to: Node
}

struct Node: Hashable, CSVRepresentable {
    var csvRepresentation: String {
        [moduleName, fileName, line, entityName ?? "", entityType ?? "", moduleName + id].joined(separator: ",")
    }

    var fields: [String] {
        ["moduleName", "fileName", "line", "entityName", "entityType", "id"]
    }

    var id: String {
        moduleName + "." + (containerName ?? "") + (entityName ?? "") + "." + (entityType ?? "")
    }

    public let moduleName: String
    public let fileName: String
    public let line: String
    public let containerName: String?
    public let entityName: String?
    public let entityType: String?

    public init(
        moduleName: String,
        fileName: String,
        line: String,
        entityName: String?,
        containerName: String?,
        entityType: String?
    ) {
        self.moduleName = moduleName
        self.fileName = fileName
        self.line = line
        self.entityName = entityName
        self.containerName = containerName
        self.entityType = entityType
    }
}

enum PathError: Error {
    case pathIsNotCorrect
    case shouldBeOnlyOnePath

    var localizedDescription: String {
        switch self {
        case .pathIsNotCorrect:
            "Path is not correct. Check your path."
        case .shouldBeOnlyOnePath:
            "You should set strictly one path. Not a zero and not a both of them. Project or folder"
        }
    }
}

public struct UseGraphPeripheryCommand: AsyncParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "usage_graph_dynamic",
        abstract: "Command to build graph of usage.",
        version: "0.0.1"
    )

    @Option(help: "Path to project (.xcodeproj)")
    var projectPath: String? = nil

    @Argument(help: "Schemes to analyze")
    var schemes: String

    @Argument(help: "Targets to analyze")
    var targets: String

    public func run() async throws {
        Configuration.shared.workspace = projectPath
        Configuration.shared.schemes = schemes.components(separatedBy: ",")
        if projectPath != nil {
            Configuration.shared.targets = targets.components(separatedBy: ",")
        }
        let driver = try XcodeProjectDriver.build()
        try driver.build()

        let graph = SourceGraph.shared
        try driver.index(graph: graph)

        var edgeDict: [EdgeWithoutReference: [Reference]] = [:]

        graph.allReferences
            .forEach {
                if let declaration = graph.allExplicitDeclarationsByUsr[$0.usr],
                   declaration.parent != $0.parent
                {
                    guard let entity = $0.parent?.findEntity(),
                          entity != declaration.findEntity(),
                          let entityParent = entity.presentAsNode(),
                          let declarationParent = declaration.presentAsNode() else { return }
                    let edge = EdgeWithoutReference(
                        from: entityParent,
                        to: declarationParent
                    )
                    if !edgeDict.keys.contains(edge) {
                        edgeDict[edge] = []
                    }
                    edgeDict[edge]?.append(
                        Reference(
                            line: $0.location.line,
                            file: $0.location.file.path.string
                        )
                    )
                }
            }

        let edges = edgeDict.compactMap {
            Edge(from: $0.key.from, to: $0.key.to, references: $0.value)
        }
        GraphBuilder.shared.csvBuildGraph(edges: edges)
    }
}

extension Declaration {
    func findEntity() -> Declaration? {
        var parent: Declaration? = self
        while parent != nil,
              parent?.kind != .class,
              parent?.kind != .enum,
              parent?.kind != .struct,
              parent?.kind != .extension,
              parent?.kind != .protocol,
              parent?.kind != .typealias,
              parent?.kind != .extensionEnum,
              parent?.kind != .extensionStruct,
              parent?.kind != .extensionClass,
              parent?.kind != .extensionProtocol
        {
            parent = parent?.parent
        }
        return parent
    }

    func presentAsNode() -> Node? {
        let entity = findEntity()
        guard let entity else { return nil }
        return Node(
            moduleName: entity.location.file.modules.first!,
            fileName: entity.location.file.path.string,
            line: String(entity.location.line),
            entityName: entity.name,
            containerName: entity.parent?.name,
            entityType: entity.kind.rawValue
        )
    }
}
