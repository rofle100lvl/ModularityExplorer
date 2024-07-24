import ArgumentParser
import Foundation
import PeripheryKit
import Shared
import Utils
import XcodeSupport

public struct UseGraphPeripheryAnalyzeCommand: AsyncParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "usage_graph_dynamic_analyze",
        abstract: "Command to build graph of usage.",
        version: "0.0.1"
    )

    @Argument(help: "Path to project (.xcodeproj)")
    var projectPath: String? = nil

    @Argument(help: "Paths to folder with sources - \"path1,path2,path3\"")
    var folderPaths: String? = nil

    @Argument(help: "Schemes to analyze")
    var schemes: String

    @Argument(help: "Targets to analyze")
    var targets: String

    @Option(help: "Use if you want to exclude any entity names")
    var excludedNames: String? = nil

    @Option(help: "Use if you want to exclude any targets")
    var excludedTargets: String? = nil

    public func run() async throws {
        var projectURL: URL?
        var folderURLs: [String] = []

        if let projectPath {
            projectURL = URL(string: projectPath)
        }
        if let folderPaths {
            folderURLs = try folderPaths.split(separator: ",").map {
                guard let folderURL = URL(string: String($0)) else { throw PathError.pathIsNotCorrect }
                return folderURL.path()
            }
        } else {
            throw PathError.pathIsNotCorrect
        }

        guard let projectURL else { throw PathError.pathIsNotCorrect }
        Configuration.shared.workspace = projectURL.absoluteString
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

        var counter = 0
        for folderPath in folderURLs {
            let edgesInFolder = edges
                .filter {
                    $0.from.fileName.matches(.init("\(folderPath).*"))
                }
                .filter {
                    $0.to.fileName.matches("^(?!\(folderPath)).*") && $0.to.moduleName == $0.from.moduleName
                }

            guard let url = URL(string: folderPath) else {
                return
            }
            let data = try await GraphBuilder.shared.buildGraphData(edges: edgesInFolder, format: .svg)
            counter += edgesInFolder.count

            let htmlString = HTMLGenerator.shared.generateHTMLTable(
                withLinks: edgesInFolder
                    .sorted {
                        $0.from.id < $1.from.id
                    }
                    .sorted {
                        $0.to.id < $1.to.id
                    }
                    .map {
                        (
                            $0.from.fileName, $0.from.id, $0.to.fileName, $0.to.id, $0.references.sorted(by: { $0 < $1 })
                                .map {
                                    String($0.line)
                                }
                        )
                    },
                svgString: String(data: data, encoding: .utf8) ?? ""
            )
            guard let edgesData = htmlString.data(using: .utf8) else { fatalError() }

            FileManager.default.createFile(atPath: url.appending(path: "module-info.html").path(), contents: edgesData)

            print(folderPath + " - " + String(edgesInFolder.count))
        }
    }
}

extension String {
    func matches(_ regex: String) -> Bool {
        return range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }
}
