//
//  HTMLBuilder.swift
//
//
//  Created by Roman Gorbenko on 08.06.2024.
//

import Foundation

public final class HTMLGenerator {
    public static let shared = HTMLGenerator()

    private init() {}

    public func generateHTMLTable(withLinks links: [(fromURL: String, fromText: String, toURL: String, toText: String, lines: [String])], svgString: String) -> String {
        var htmlString = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Ссылочная таблица</title>
            <meta charset="UTF-8">
            <style>
                svg {
                  border: 1px solid blue;
                }
            </style>
        </head>
        <body>
            <table border="1">
                <tr>
                    <th>From</th>
                    <th>To</th>
                    <th>Lines</th>
                </tr>
        """

        for link in links {
            htmlString += """
                <tr>
                    <td><a href="\(link.fromURL)">\(link.fromText)</a></td>
                    <td><a href="\(link.toURL)">\(link.toText)</a></td>
                    <td>\(link.lines.joined(separator: ", "))</td>
                </tr>
            """
        }

        htmlString += """
            </table>
            <div style={{
                backgroundColor: 'lightpink',
                resize: 'horizontal',
                overflow: 'hidden',
                width: '1000px',
                height: 'auto',
              }}>
                <svg viewBox="0 0 3000 3000">
                    \(svgString)
                </svg>
            </div>
        </body>
        </html>
        """

        return htmlString
    }
}
