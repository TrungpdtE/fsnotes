//
//  URL+.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 3/22/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

public extension URL {
    /// Get extended attribute.
    public func extendedAttribute(forName name: String) throws -> Data {
        return try self.withUnsafeFileSystemRepresentation { fileSystemPath -> Data in

            // Determine attribute size:
            let length = getxattr(fileSystemPath, name, nil, 0, 0, 0)
            guard length >= 0 else { throw URL.posixError(errno) }

            // Create buffer with required size:
            var data = Data(count: length)
            let count = data.count

            // Retrieve attribute:
            let result = data.withUnsafeMutableBytes {
                getxattr(fileSystemPath, name, $0, count, 0, 0)
            }
            guard result >= 0 else { throw URL.posixError(errno) }
            return data
        }
    }

    /// Set extended attribute.
    public func setExtendedAttribute(data: Data, forName name: String) throws {

        try self.withUnsafeFileSystemRepresentation { fileSystemPath in
            let result = data.withUnsafeBytes {
                setxattr(fileSystemPath, name, $0, data.count, 0, 0)
            }
            guard result == 0 else { throw URL.posixError(errno) }
        }
    }

    /// Remove extended attribute.
    public func removeExtendedAttribute(forName name: String) throws {

        try self.withUnsafeFileSystemRepresentation { fileSystemPath in
            let result = removexattr(fileSystemPath, name, 0)
            guard result == 0 else { throw URL.posixError(errno) }
        }
    }

    /// Get list of all extended attributes.
    public func listExtendedAttributes() throws -> [String] {

        return try self.withUnsafeFileSystemRepresentation { fileSystemPath -> [String] in
            let length = listxattr(fileSystemPath, nil, 0, 0)
            guard length >= 0 else { throw URL.posixError(errno) }

            // Create buffer with required size:
            var data = Data(count: length)
            let count = data.count

            // Retrieve attribute list:
            let result = data.withUnsafeMutableBytes {
                listxattr(fileSystemPath, $0, count, 0)
            }
            guard result >= 0 else { throw URL.posixError(errno) }

            // Extract attribute names:
            let list = data.split(separator: 0).compactMap {
                String(data: Data($0), encoding: .utf8)
            }
            return list
        }
    }

    /// Helper function to create an NSError from a Unix errno.
    private static func posixError(_ err: Int32) -> NSError {
        return NSError(domain: NSPOSIXErrorDomain, code: Int(err),
                       userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(err))])
    }

    // Access the URL parameters eg nv://make?title=blah&txt=body like so:
    // let titleStr = myURL['title']
    public subscript(queryParam: String) -> String? {
        guard let url = URLComponents(string: self.absoluteString) else { return nil }
        return url.queryItems?.first(where: { $0.name == queryParam })?.value
    }

    public func isRemote() -> Bool {
        return (self.absoluteString.starts(with: "http://") || self.absoluteString.starts(with: "https://"))
    }

    public var attributes: [FileAttributeKey : Any]? {
        do {
            return try FileManager.default.attributesOfItem(atPath: path)
        } catch let error as NSError {
            print("FileAttribute error: \(error)")
        }
        return nil
    }

    public var fileSize: UInt64 {
        return attributes?[.size] as? UInt64 ?? UInt64(0)
    }

    public func removingFragment() -> URL {
        var string = self.absoluteString
        if let query = query {
            string = string.replacingOccurrences(of: "?\(query)", with: "")
        }

        if let fragment = fragment {
            string = string.replacingOccurrences(of: "#\(fragment)", with: "")
        }

        return URL(string: string) ?? self
    }

    var typeIdentifier: String? {
        return (try? resourceValues(forKeys: [.typeIdentifierKey]))?.typeIdentifier
    }
}
