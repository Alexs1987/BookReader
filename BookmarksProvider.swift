//
//  BookmarksProvider.swift
//  BookReader
//
//  Created by Alex on 19/10/2019.
//

import Foundation

protocol BookmarksProviderProtocol: class {
    func hasBookmark(for url: URL, pageIndex: Int) -> Bool
    
    func addBookmark(for url: URL, pageIndex: Int)
    
    func removeBookmark(for url: URL, pageIndex: Int)
    
    func bookmarks(for url: URL) -> [Int]?
}

class BookmarksProvider: NSObject, BookmarksProviderProtocol {
    
    func hasBookmark(for url: URL, pageIndex: Int) -> Bool {
        migateLegacyBookmarksIfNeeded(for: url)
        
        guard let bookmarks = UserDefaults.standard.array(forKey: trimDocumentsPath(to: url.absoluteString)) as? [Int] else {
            return false
        }
        
        return bookmarks.contains(pageIndex)
    }
    
    func addBookmark(for url: URL, pageIndex: Int) {
        migateLegacyBookmarksIfNeeded(for: url)

        let bookmarksKey = trimDocumentsPath(to: url.absoluteString)
        let bookmarks = UserDefaults.standard.array(forKey: bookmarksKey) as? [Int] ?? [Int]()
        UserDefaults.standard.set((bookmarks + [pageIndex]).sorted(), forKey: bookmarksKey)
    }
    
    func removeBookmark(for url: URL, pageIndex: Int) {
        migateLegacyBookmarksIfNeeded(for: url)
        
        let bookmarksKey = trimDocumentsPath(to: url.absoluteString)
        
        guard var bookmarks = UserDefaults.standard.array(forKey: bookmarksKey) as? [Int], let index = bookmarks.firstIndex(of: pageIndex) else {
            return
        }
        
        bookmarks.remove(at: index)
        UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)
    }
    
    func bookmarks(for url: URL) -> [Int]? {
        migateLegacyBookmarksIfNeeded(for: url)
        
        return UserDefaults.standard.array(forKey: trimDocumentsPath(to: url.absoluteString)) as? [Int]
    }
}

private extension BookmarksProvider {
    func migateLegacyBookmarksIfNeeded(for url: URL) {
        guard let bookmarks = UserDefaults.standard.array(forKey: url.absoluteString) as? [Int] else {
            return
        }
        UserDefaults.standard.removeObject(forKey: url.absoluteString)
        UserDefaults.standard.set(bookmarks, forKey: trimDocumentsPath(to: url.absoluteString))
    }
    
    func trimDocumentsPath(to path: String) -> String {
        let path = path.replacingOccurrences(of: documentsURL.path + "/", with: "")
        return path
    }

    var documentsURL: URL {
        let fileManager = FileManager.default
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].resolvingSymlinksInPath()
    }
}
