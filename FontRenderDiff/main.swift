import Foundation
import AppKit

func printUsage(_ message: String) {
    print(message)
    print("Usage: FontRenderDiff (fontFile.ttf | fontFile.otf | ( fontFile.ttc fontName)) testStringsFile testImageDirectory")
}

func checkArgc(_ expected: Int) {
    if Int(CommandLine.argc) < expected {
        printUsage("Not enough arguments.")
        exit(1)
    }
}

func reportAnyErrors(_ errors: [String]?, testStringsFile: String) {
    if let errors = errors {
        for error in errors {
            print(error)
        }
        let plural = errors.count != 1 ? "s" : ""
        print("\(errors.count) error\(plural) found for “\(testStringsFile)”.")
        exit(1)
    }
}

func getFontDesc(fontFile: String, fontName: String?) -> CTFontDescriptor {
    if let ctFontDescs = CTFontManagerCreateFontDescriptorsFromURL(URL(fileURLWithPath: fontFile) as CFURL) {
        let fontDescs = ctFontDescs as! Array<CTFontDescriptor>
        if let fontName = fontName {
            if let fontDesc = fontDescs.first(where: { return CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as! String == fontName}) {
                return fontDesc
            } else {
                printUsage("File “\(fontFile)” doesn’t contain a font with PostScript name “\(fontName)”.")
                let fontNames = fontDescs.map( { return CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as! String}).joined(separator: ", ")
                print("Available fonts: \(fontNames).")
                exit(1)
            }
        } else {
            return fontDescs[0]
        }
    } else {
        printUsage("File “\(fontFile)” doesn’t appear to be a font file.")
        exit(1)
    }
}

func main() {
    checkArgc(4)

    let fontFile = CommandLine.arguments[1]
    var increment = 0
    var fontName: String?
    if fontFile.hasSuffix(".ttc") {
        checkArgc(5)
        increment = 1
        fontName = CommandLine.arguments[2]
    }
    let testStringsFile = CommandLine.arguments[2 + increment]
    let testImageDirectory = CommandLine.arguments[3 + increment]

    let fontDesc = getFontDesc(fontFile: fontFile, fontName: fontName)

    let testStringsData: String
    do {
        testStringsData = try String(contentsOfFile: testStringsFile, encoding: String.Encoding.utf8)
    } catch let error as NSError {
        print("Couldn’t read test strings file “\(testStringsFile)”; got error: \(error.localizedDescription)")
        exit(1)
    }

    var (testStrings, errors): ([String]?, [String]?) = parseTestStrings(testStringsData)
    reportAnyErrors(errors, testStringsFile: testStringsFile)

    errors = testFontRendering(testStrings!, fontDesc: fontDesc, testImageDirectory: testImageDirectory)
    reportAnyErrors(errors, testStringsFile: testStringsFile)
}

main()
