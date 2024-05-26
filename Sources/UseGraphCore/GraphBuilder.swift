import GraphViz
import Foundation

public final class GraphBuilder {
    public static let shared = GraphBuilder()
    
    private init() { }
    
    private func createCSV(from recArray:[CSVRepresentable]) -> String {
        guard let fields = recArray.first?.fields else { return "" }
        var csvString = fields.joined(separator: ",") + "\n"
        for dct in recArray {
            csvString = csvString.appending(dct.csvRepresentation + "\n")
        }
        return csvString
    }
    
    private func csvBuildGraph(dependencyGraph: [String: Node]) {
        let nodes: [String: NodeCSVRepresentation] = dependencyGraph
            .reduce(Set<String>()) { result, element in
                var resultCopy = result
                resultCopy.insert(element.key)
                resultCopy.formUnion(element.value.connectedTo)
                return resultCopy
            }
            .reduce([:]) { result, name in
                var resultCopy = result
                let moduleName = dependencyGraph[name]?.moduleName ?? ""
                let node = NodeCSVRepresentation(id: moduleName + "." + name, module: moduleName, label: name)
                resultCopy[name] = node
                return resultCopy
            }
        
        let edges = dependencyGraph.reduce([EdgeRepresentation]()) { result, element in
            var newResult = result
                
            newResult.append(
                contentsOf: element.value.connectedTo.compactMap { to in
                    if let from = nodes[element.key],
                       let to = nodes[to] {
                        return EdgeRepresentation(source: from.id, target: to.id)
                    }
                    return nil
                }
            )
            return newResult
        }
        
        let edgesCSV = createCSV(from: edges)
        let nodesCSV = createCSV(from: nodes.map { $0.value })
        
        let nodesUrl = URL(fileURLWithPath: #file).deletingLastPathComponent().appending(path: "Nodes.csv")
        let edgesUrl = URL(fileURLWithPath: #file).deletingLastPathComponent().appending(path: "Edges.csv")

        guard let edgesData = edgesCSV.data(using: .utf8),
              let nodesData = nodesCSV.data(using: .utf8) else { fatalError() }
        print(FileManager.default.createFile(atPath: edgesUrl.path(), contents: edgesData))
        print(FileManager.default.createFile(atPath: nodesUrl.path(), contents: nodesData))

    }
    
    public func buildGraph(dependencyGraph: [String: Node], format: OutputFormat) {
        switch format {
        case .svg, .png, .gv:
            buildFormat(dependencyGraph: dependencyGraph, format: format)
        case .csv:
            csvBuildGraph(dependencyGraph: dependencyGraph)
        }
    }

    
    private func buildFormat(dependencyGraph: [String: Node], format: OutputFormat) {
        let format: Format? = switch format {
        case .svg:
                .svg
        case .png:
                .png
        case .gv:
                .gv
        case .csv:
            nil
        }
        
        guard let format else { fatalError() }
        var graph = Graph(directed: true)
        
        let nodes: [String: GraphViz.Node] = dependencyGraph
            .reduce(Set<String>()) { result, element in
                var resultCopy = result
                resultCopy.insert(element.key)
                resultCopy.formUnion(element.value.connectedTo)
                return resultCopy
            }
            .reduce([:]) { result, name in
                var resultCopy = result
                var node = GraphViz.Node(name)
                if let moduleName = dependencyGraph[name]?.moduleName {
                    node.id = moduleName + "." + name
                    node.label = moduleName
                }
                resultCopy[name] = node
                return resultCopy
            }
        
        dependencyGraph.forEach { from in
            from.value.connectedTo.forEach { to in
                if let from = nodes[from.key],
                   let to = nodes[to] {
                    graph.append(Edge(from: from, to: to))
                }
            }
        }
        print("Start building graph...")
        graph.render(using: .fdp, to: format) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                let url = URL(fileURLWithPath: #file).deletingLastPathComponent().appending(path: "Graph.\(format.rawValue)")
                guard var fileContents = String(data: data, encoding: .utf8) else { fatalError() }
                if format == .gv {
                    fileContents = self.removeSecondAndThirdLine(string: fileContents)
                }
                
                print(FileManager.default.createFile(atPath: url.path(), contents: fileContents.data(using: .utf8)))
                Task {
                    System.shared.run("open \(url.path())")
                }
            case .failure(let failure):
                print(failure)
            }
        }
        sleep(10000)
    }
    
    private func removeSecondAndThirdLine(string: String) -> String {
        var lines = string.split(separator: "\n")
        lines.removeSubrange(1...2)
        return lines.joined(separator: "\n")
    }
}