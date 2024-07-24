import GraphViz
import Utils

public enum OutputFormat {
    case svg
    case png
    case gv
    case csv

    public static func parse(format: String) throws -> OutputFormat {
        switch format.lowercased() {
        case "svg":
            .svg
        case "png":
            .png
        case "gv":
            .gv
        case "csv":
            .csv
        default:
            throw FormatError.formatIsNotCorrect
        }
    }
}
