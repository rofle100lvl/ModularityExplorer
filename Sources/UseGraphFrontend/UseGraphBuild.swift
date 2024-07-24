import ArgumentParser
import Foundation
import UseGraphCore
import UseGraphStaticAnalysis

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

public struct UseGraphBuildCommand: AsyncParsableCommand {
  public init() {}
  
  public static let configuration = CommandConfiguration(
    commandName: "usage_graph",
    abstract: "Command to build graph of usage.",
    version: "0.0.1"
  )
  
  @Option(help: "Path to project (.xcodeproj)")
  var projectPath: String? = nil
  
  @Option(help: "Path to folder with sources")
  var folderPath: String? = nil
  
  @Argument(help: "Output file format. Now available: CSV, SVG, PNG, GV")
  var format: String = "svg"
    
  @Flag(help: "If enabled all leasts will show you type of their variables")
  var showLastChildren: Bool = false
  
  @Option(help: "Use if you want to exclude any entity names")
  var excludedNames: String? = nil
  
  @Option(help: "Use if you want to exclude any targets")
  var excludedTargets: String? = nil
  
  public func run() async throws {
    if projectPath != nil && folderPath != nil {
      throw PathError.shouldBeOnlyOnePath
    }
    
    if projectPath == nil && folderPath == nil {
      throw PathError.shouldBeOnlyOnePath
    }
    
    var url: URL?
    
    if let projectPath {
      url = URL(string: projectPath)
    } else if let folderPath {
      url = URL(string: folderPath)
    }
    
    guard let url else {
      throw PathError.pathIsNotCorrect
    }
    
    let format = try OutputFormat.parse(format: format)
    
    var scanResults = try await InitScanner.scan(url: url, excludedModules: excludedTargets?.split(separator: ",").map { String($0) } ?? [])
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
      for item in excludedNames.split(separator: ", ") {
        scanResults.removeValue(forKey: String(item))
      }
    }
    var results = scanResults
    
    if !showLastChildren {
      results = scanResults
        .reduce([String: Node]()) { result, element in
          var newResult = result
          let usedNodes = element.value.connectedTo.filter { scanResults.keys.contains($0) }
          newResult[element.key] = Node(
            moduleName: element.value.moduleName,
            fileName: element.value.fileName,
            connectedTo: usedNodes
          )
          return newResult
        }
    }
    
    excludeNames(excludedNames: excludedNames, scanResults: &scanResults)
    
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
    
    try await GraphBuilder.shared.buildGraph(dependencyGraph: results, format: format)
  }
  
  func excludeNames(excludedNames: String?, scanResults: inout [String: Node]) {
    if let excludedNames {
      for item in excludedNames.split(separator: ", ") {
        scanResults.removeValue(forKey: String(item))
      }
    }
  }
}
