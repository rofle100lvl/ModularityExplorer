import ArgumentParser
import Foundation
import Utils
import UseGraphStaticAnalysis
import UseGraphCore

struct EdgeNode: Hashable {
    let name: String
    let moduleName: String
    let fileName: String
    let connectedTo: Set<String>
}

struct Edge {
    let from: EdgeNode
    let to: EdgeNode
}

public struct UseGraphAnalyzeCommand: AsyncParsableCommand {
    public init() { }
    
    public static let configuration = CommandConfiguration(
        commandName: "usage_graph_analyze",
        abstract: "Command to build graph of usage.",
        version: "0.0.1"
    )
    
    @Argument(help: "Path to project (.xcodeproj)")
    var projectPath: String? = nil
    
    @Argument(help: "Paths to folder with sources - \"path1,path2,path3\"")
    var folderPaths: String? = nil
    
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
        
        var scanResults = try await InitScanner.scan(url: projectURL, excludedModules: excludedTargets?.split(separator: ",").map { String($0) } ?? [])
            .map(\.fileScanResult)
            .reduce([String: Node]()) { result, element in
                result.merging(element, uniquingKeysWith: {
                    Node(
                        moduleName: $0.moduleName,
                        fileName: $0.fileName,
                        connectedTo: $0.connectedTo.union($1.connectedTo)
                    )
                })
            }
        
        if let excludedNames {
            excludedNames.split(separator: ", ").forEach {
                scanResults.removeValue(forKey: String($0))
            }
        }
        
        var results = scanResults
        results = results
            .reduce([String: Node]()) { result, element in
                var newResult = result
                var set = element.value.connectedTo
                for to in set {
                    if results.keys.contains(where: { $0 == element.key.appending(".").appending(to) }) {
                        set.remove(to)
                        set.insert(element.key.appending(".").appending(to))
                    }
                }
                newResult[element.key] = Node(
                    moduleName: element.value.moduleName,
                    fileName: element.value.fileName,
                    connectedTo: set
                )
                return newResult
            }
        
        var counter = 0
        for folderPath in folderURLs {
            let edgesInFolder = results.filter {
                return $0.value.fileName.matches(.init("\(folderPath).*"))
            }
            
            let connectionGraph = edgesInFolder.reduce([String: Node]()) { result, element in
                var newResult = result
                let newSet = element.value.connectedTo.filter {
                    return results[$0]?.fileName.matches("^(?!\(folderPath)).*") ?? false && results[$0]?.moduleName == element.value.moduleName
                }
                newSet.forEach {
                    newResult[$0] = results[$0].map { node in
                        Node(moduleName: node.moduleName, fileName: node.fileName, connectedTo: Set<String>())
                    }
                }
                newResult[element.key] = Node(
                    moduleName: element.value.moduleName,
                    fileName: element.value.fileName,
                    connectedTo: newSet
                )
                return newResult
            }
            
            let edges = connectionGraph
                .map { element in
                    var edges: [Edge] = []
                    element.value.connectedTo.forEach {
                        guard let to = results[$0] else { return }
                        edges.append(
                            Edge(
                                from: element.value.toEdgeNode(with: element.key),
                                to: to.toEdgeNode(with: $0)
                            )
                        )
                    }
                    return edges
                }
                .flatMap { $0 }
            
            guard let url = URL(string: folderPath) else {
                return
            }
            let data = try await GraphBuilder.shared.buildGraphData(dependencyGraph: connectionGraph, format: .svg)
            counter += edges.count

            let htmlString = HTMLGenerator.shared.generateHTMLTable(
                withLinks: edges.map {
                    ($0.from.fileName, $0.from.name, $0.to.fileName, $0.to.name, [])
                },
                svgString: String(data: data, encoding: .utf8) ?? ""
            )
            guard let edgesData = htmlString.data(using: .utf8) else { fatalError() }
            
            FileManager.default.createFile(atPath: url.appending(path: "module-info.html").path(), contents: edgesData)
            
            print(folderPath + " - " + String(edges.count))
           
        }
        print(counter)
    }
}

extension Node {
    func toEdgeNode(with name: String) -> EdgeNode {
        EdgeNode(
            name: name,
            moduleName: moduleName,
            fileName: fileName,
            connectedTo: connectedTo
        )
    }
}
extension String {
    func matches(_ regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }
}
