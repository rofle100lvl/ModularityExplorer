import Foundation

protocol CSVRepresentable {
    var csvRepresentation: String { get }
    var fields: [String] { get }
}

struct NodeCSVRepresentation: CSVRepresentable {
    var fields: [String] {
        ["Id", "Module", "Label", "Path"]
    }

    let id: String
    let module: String
    let label: String
    let path: String

    init(id: String, module: String = "", label: String, path: String) {
        self.id = id
        self.module = module
        self.label = label
        self.path = path
    }

    var csvRepresentation: String {
        id + "," + module + "," + label + "," + path
    }
}

struct EdgeRepresentation: CSVRepresentable {
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
