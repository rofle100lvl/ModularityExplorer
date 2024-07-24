import Foundation
import GraphViz
import Utils

protocol CSVRepresentable {
    var csvRepresentation: String { get }
    var fields: [String] { get }
}

struct EdgeCSV: CSVRepresentable {
    var fields: [String] {
        ["Source", "Target", "Type"]
    }

    let source: String
    let target: String
    let type = "directed"

    var csvRepresentation: String {
        source + "," + target + "," + type
    }
}

enum OutputFormat {
    case svg
    case png
    case gv

    public static func parse(format: String) throws -> OutputFormat {
        switch format.lowercased() {
        case "svg":
            .svg
        case "png":
            .png
        case "gv":
            .gv
        default:
            throw FormatError.formatIsNotCorrect
        }
    }
}

final class GraphBuilder {
    static let shared = GraphBuilder()

    private init() {}

    private func createCSV(from recArray: [CSVRepresentable]) -> String {
        guard let fields = recArray.first?.fields else { return "" }
        var csvString = fields.joined(separator: ",") + "\n"
        for dct in recArray {
            csvString = csvString.appending(dct.csvRepresentation + "\n")
        }
        return csvString
    }

    func csvBuildGraph(edges: [UseGraphPeriphery.Edge]) {
        var uniqueSet = Set<Node>()
        edges.map { [$0.from, $0.to] }.flatMap { $0 }.forEach { uniqueSet.insert($0) }

        let edges = edges.map { EdgeCSV(source: $0.from.id, target: $0.to.id) }
        let edgesCSV = createCSV(from: edges)
        let nodesCSV = createCSV(from: Array(uniqueSet))

        let nodesUrl = URL(fileURLWithPath: #file).deletingLastPathComponent().appending(path: "Nodes.csv")
        let edgesUrl = URL(fileURLWithPath: #file).deletingLastPathComponent().appending(path: "Edges.csv")

        guard let edgesData = edgesCSV.data(using: .utf8),
              let nodesData = nodesCSV.data(using: .utf8) else { fatalError() }
        print(FileManager.default.createFile(atPath: edgesUrl.path(), contents: edgesData))
        print(FileManager.default.createFile(atPath: nodesUrl.path(), contents: nodesData))
    }

    func buildGraph(edges: [Edge], format: OutputFormat) async throws {
        switch format {
        case .svg, .png, .gv:
            guard let format = mapFormat(format: format) else { fatalError() }

            let data = try await buildGraphData(edges: edges, format: format)
            let url = URL(fileURLWithPath: #file).deletingLastPathComponent().appending(path: "Graph.\(format.rawValue)")
            guard var fileContents = String(data: data, encoding: .utf8) else { fatalError() }
            if format == .gv {
                fileContents = removeSecondAndThirdLine(string: fileContents)
            }

            print(FileManager.default.createFile(atPath: url.path(), contents: fileContents.data(using: .utf8)))
            Task {
                System.shared.run("open \(url.path())")
            }
        }
    }

    func buildGraphData(edges: [Edge], format: Format) async throws -> Data {
        var graph = Graph(directed: true)

        for edge in edges {
            graph.append(GraphViz.Edge(
                from: GraphViz.Node(edge.from.id),
                to: GraphViz.Node(edge.to.id)
            ))
        }

        print("Start building graph...")

        return try await withCheckedThrowingContinuation { continuation in
            graph.render(using: .fdp, to: format) { [weak self] result in
                guard self != nil else { return }
                switch result {
                case let .success(data):
                    continuation.resume(returning: data)
                case let .failure(failure):
                    continuation.resume(throwing: BuildGraphError.buildGraphError)
                    print(failure)
                }
            }
        }
    }

    private func removeSecondAndThirdLine(string: String) -> String {
        var lines = string.split(separator: "\n")
        lines.removeSubrange(1 ... 2)
        return lines.joined(separator: "\n")
    }
}

extension GraphBuilder {
    func mapFormat(format: OutputFormat) -> Format? {
        switch format {
        case .svg:
            .svg
        case .png:
            .png
        case .gv:
            .gv
        }
    }
}
