import Foundation
import SwiftParser
import SwiftSyntax
import XcodeProj

public struct ModuleScanResult: Equatable {
    public let fileScanResult: [String: Node]
}

public struct FileScanResult {
    public let fileName: String
    public let parametersDependencies: [String: Node]
}

public struct Node: Hashable {
    public let moduleName: String
    public let fileName: String
    public let connectedTo: Set<String>

    public init(
        moduleName: String,
        fileName: String,
        connectedTo: Set<String>
    ) {
        self.moduleName = moduleName
        self.connectedTo = connectedTo
        self.fileName = fileName
    }
}

public enum InitScanner {
    public static func scan(url: URL, excludedModules: [String] = []) async throws -> [ModuleScanResult] {
        var modules = [Module]()

        if url.pathExtension == "xcodeproj" {
            modules = try XcodeprojManager.getAllModules(projUrl: url)
                .filter { !excludedModules.contains($0.moduleName) }
        } else {
            let fileURLs = FileManager.default.allFiles(inDirectory: url)
            modules = [Module(moduleName: "", files: fileURLs)]
        }
        return await processModules(modules: modules)
    }

    static func processModules(modules: [Module]) async -> [ModuleScanResult] {
        var moduleScanResult: [ModuleScanResult] = []

        await withTaskGroup(of: ([FileScanResult], String)?.self) { group in
            for module in modules {
                group.addTask {
                    (await handleModule(module: module), module.moduleName)
                }
            }
            for await entity in group {
                if let entity {
                    if !entity.0.isEmpty {
                        let graph = entity.0
                            .map(\.parametersDependencies)
                            .reduce([String: Node]()) { result, element in
                                result.merging(element, uniquingKeysWith: {
                                    Node(
                                        moduleName: $0.moduleName,
                                        fileName: $0.fileName,
                                        connectedTo: $0.connectedTo.union($1.connectedTo)
                                    )
                                })
                            }

                        let graphWithConnectedExtensions = graph
                            .reduce([String: Node]()) { result, element in
                                var index = 0
                                var newSet = element.value.connectedTo
                                while graph.keys.contains(element.key + "Ext\(index)") {
                                    newSet.insert(element.key + "Ext\(index)")
                                    index += 1
                                }
                                var newResult = result
                                newResult[element.key] = Node(
                                    moduleName: element.value.moduleName,
                                    fileName: element.value.fileName,
                                    connectedTo: newSet
                                )
                                return newResult
                            }

                        moduleScanResult.append(ModuleScanResult(fileScanResult: graphWithConnectedExtensions))
                    }
                }
            }
        }
        return moduleScanResult
    }

    static func processModules(modules: [SourceModule]) async -> [ModuleScanResult] {
        var moduleScanResult: [ModuleScanResult] = []

        await withTaskGroup(of: ([FileScanResult], String)?.self) { group in
            for module in modules {
                group.addTask {
                    (await handleModule(module: module), module.moduleName)
                }
            }
            for await entity in group {
                if let entity {
                    if !entity.0.isEmpty {
                        let graph = entity.0
                            .map(\.parametersDependencies)
                            .reduce([String: Node]()) { result, element in
                                result.merging(element, uniquingKeysWith: {
                                    Node(
                                        moduleName: $0.moduleName,
                                        fileName: $0.fileName,
                                        connectedTo: $0.connectedTo.union($1.connectedTo)
                                    )
                                })
                            }

                        let graphWithConnectedExtensions = graph
                            .reduce([String: Node]()) { result, element in
                                var index = 0
                                var newSet = element.value.connectedTo
                                while graph.keys.contains(element.key + "Ext\(index)") {
                                    newSet.insert(element.key + "Ext\(index)")
                                    index += 1
                                }
                                var newResult = result
                                newResult[element.key] = Node(
                                    moduleName: element.value.moduleName,
                                    fileName: element.value.fileName,
                                    connectedTo: newSet
                                )
                                return newResult
                            }

                        moduleScanResult.append(ModuleScanResult(fileScanResult: graphWithConnectedExtensions))
                    }
                }
            }
        }
        return moduleScanResult
    }

    static func handleModule(module: Module) async -> [FileScanResult] {
        var fileGraphs = [FileScanResult]()
        await withTaskGroup(of: ([String: Set<String>], String).self) { group in
            for file in module.files {
                group.addTask {
                    (await matchPattern(at: file), file.path())
                }
            }
            for await entity in group {
                let results = entity.0
                    .reduce([String: Node]()) { result, element in
                        var newResult = result
                        newResult[element.key] = Node(
                            moduleName: module.moduleName,
                            fileName: entity.1,
                            connectedTo: element.value
                        )

                        return newResult
                    }
                fileGraphs.append(FileScanResult(fileName: entity.1, parametersDependencies: results))
            }
        }

        return fileGraphs
    }

    static func handleModule(module: SourceModule) async -> [FileScanResult] {
        var fileGraphs = [FileScanResult]()
        await withTaskGroup(of: ([String: Set<String>], String).self) { group in
            for file in module.files {
                group.addTask {
                    (findDependencies(text: file.source), file.name)
                }
            }
            for await entity in group {
                let results = entity.0
                    .reduce([String: Node]()) { result, element in
                        var newResult = result
                        newResult[element.key] = Node(
                            moduleName: module.moduleName,
                            fileName: entity.1,
                            connectedTo: element.value
                        )

                        return newResult
                    }
                fileGraphs.append(FileScanResult(fileName: entity.1, parametersDependencies: results))
            }
        }

        return fileGraphs
    }

    private static func matchPattern(at fileURL: URL) async -> [String: Set<String>] {
        guard fileURL.pathExtension == "swift",
              let _ = try? String(contentsOf: fileURL)
        else {
            return [:]
        }
        do {
            return try findDependencies(dir: fileURL)
        } catch {
            return [:]
        }
    }

    private static func findDependencies(dir: URL) throws -> [String: Set<String>] {
        let text = try String(contentsOf: dir, encoding: .utf8)
        let rootNode: SourceFileSyntax = Parser.parse(source: text)
        let visitor = DefinitionVisitor()
        visitor.walk(rootNode)
        return visitor.graphDependencies
    }

    private static func findDependencies(text: String) -> [String: Set<String>] {
        let rootNode: SourceFileSyntax = Parser.parse(source: text)
        let visitor = DefinitionVisitor()
        visitor.walk(rootNode)
        return visitor.graphDependencies
    }
}

extension String {
    func containsRegexPattern(_ pattern: String) -> Bool {
        range(of: pattern, options: .regularExpression) != nil
    }
}
