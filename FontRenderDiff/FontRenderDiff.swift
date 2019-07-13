import Foundation
import AppKit


let resolutionMultiplier = 2 // We want double the default resolution, 144 dpi instead of 72 dpi.
let imageSize = (x: 1000, y: 200)
let bitmapSize = (x: imageSize.x * resolutionMultiplier, y: imageSize.y * resolutionMultiplier)
let bitmapRect = CGRect(x: 0, y: 0, width: bitmapSize.x, height: bitmapSize.y)
let baseLine = 90 * resolutionMultiplier
let startOffset = 100 * resolutionMultiplier
let fontSize = 72 * resolutionMultiplier

// Typographic instructions.
let instructionIndicator = " ♦ "
let noLigatureKeyword = "nolig"
let noLigatureInstruction = instructionIndicator + noLigatureKeyword
let discretionaryLigatureKeyword = "dlig"
let discretionaryLigatureInstruction = instructionIndicator + discretionaryLigatureKeyword
let fractionKeyword = "frac"
let fractionInstruction = instructionIndicator + fractionKeyword
let ordinalKeyword = "ordn"
let ordinalInstruction = instructionIndicator + ordinalKeyword
let languageKeyword = "lang"
let languageInstruction = instructionIndicator + languageKeyword


// Parse contents of test strings file into test strings array. If errors occur, return printable error messages.
func parseTestStrings(_ testStringsData: String) -> (testStrings: [String]?, errors: [String]?) {
    var testStrings = [String]()
    var errors = [String]()
    let lines = testStringsData.split(separator: "\n")
    line: for line in lines {
        // Can't use String API here because we need to work with precise Unicode code points or UTF-16 code units.
        var nsLine = line as NSString

        // Strip leading space characters (but leave non-breaking spaces in place as part of test data).
        var spaces = 0
        while nsLine.length > spaces && nsLine.character(at: spaces) == 0x0020 {
            spaces += 1
        }
        nsLine = nsLine.substring(from: spaces) as NSString

        // Skip over empty and comment lines.
        if nsLine.length == 0 || nsLine.hasPrefix("//") {
            continue
        }

        // Handle Unicode escapes.
        var range = nsLine.range(of: "\\u{", options: .literal)
        while range.location != NSNotFound {
            var location = range.location + 3
            var codePoint = 0
            var codeUnit: unichar = 0
            escape: while location < nsLine.length {
                codeUnit = nsLine.character(at: location)
                switch codeUnit {
                case 0x0030 ... 0x0039:
                    codePoint = codePoint * 16 + (Int(codeUnit) - 0x0030)
                case 0x0041 ... 0x0046:
                    codePoint = codePoint * 16 + (Int(codeUnit) - 0x0041 + 10)
                case 0x0061 ... 0x0066:
                    codePoint = codePoint * 16 + (Int(codeUnit) - 0x0061 + 10)
                case 0x007D:
                    break escape
                default:
                    errors.append("Invalid Unicode escape in line " + line)
                    continue line
                }
                if codePoint > 0x10FFFF {
                    errors.append("Unicode escape for code point above 0x10FFFF in line " + line)
                    continue line
                }
                location += 1
            }
            if codeUnit != 0x007D || location < range.location + 4 {
                errors.append("Incomplete Unicode escape in line " + line)
                continue line
            }
            if codePoint >= 0xD800 && codePoint < 0xE000 {
                errors.append("Unicode escape for surrogate code point in line " + line)
            }

            let replacement = String(U(codePoint))
            nsLine = nsLine.substring(to: range.location) + replacement + nsLine.substring(from: location + 1) as NSString
            range = nsLine.range(of: "\\u{", options: .literal)
        }

        // Remove trailing comments
        range = nsLine.range(of: " //", options: .literal)
        if range.location != NSNotFound {
            nsLine = nsLine.substring(to: range.location) as NSString
        }

        // Validate instructions.
        range = nsLine.range(of: instructionIndicator, options: .literal)
        if range.location != NSNotFound {
            let nsInstruction = nsLine.substring(from: range.location + instructionIndicator.utf16.count)
            if nsInstruction != noLigatureKeyword && nsInstruction != discretionaryLigatureKeyword && nsInstruction != fractionKeyword && nsInstruction != ordinalKeyword && !nsInstruction.hasPrefix(languageKeyword) {
                errors.append("Unknown instruction “\(nsInstruction)”.")
                continue line
            }
        }

        testStrings.append(nsLine as String)
    }

    return errors.count > 0 ? (testStrings: nil, errors: errors) : (testStrings: testStrings, errors: nil)
}


func drawableString(_ text: CFString, font: CTFont, lang: String?) -> CFAttributedString {
    let length = CFStringGetLength(text)
    let attrString = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0)!
    CFAttributedStringReplaceString (attrString, CFRangeMake(0, 0), text)
    let black = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.0, 0.0, 0.0, 1.0])!
    CFAttributedStringSetAttribute(attrString, CFRangeMake(0, length), kCTForegroundColorAttributeName, black)
    CFAttributedStringSetAttribute(attrString, CFRangeMake(0, length), kCTFontAttributeName, font)
    if let lang = lang {
        CFAttributedStringSetAttribute(attrString, CFRangeMake(0, length), kCTLanguageAttributeName, (lang as NSString))
    }
    return attrString
}

func createPNG(drawFunc: (_ context: CGContext) -> ()) -> Data {

    // Set up graphics context.
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
    let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue
    let context = CGContext(data: nil, width: bitmapSize.x, height: bitmapSize.y, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace!, bitmapInfo: bitmapInfo)!

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    // Paint background white.
    context.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    context.fill(bitmapRect)

    drawFunc(context)

    // Return the PNG data for the resulting image.
    // On the way, double the resolution by cutting the size in half.
    let image = context.makeImage()!
    let bitmap = NSBitmapImageRep(cgImage: image)
    bitmap.size = NSSize(width: imageSize.x, height: imageSize.y)
    return bitmap.representation(using: .png, properties: [NSBitmapImageRep.PropertyKey: Any]())!
}

// Create a standardized image in PNG format for the given text in the specified font.
func createTestImage(_ text: String, fontDesc: CTFontDescriptor) -> Data {
    var myText = text
    var myLang: String? = nil
    var myFontDesc = fontDesc

    // Process instructions, if any.
    if myText.hasSuffix(noLigatureInstruction) {
        myText = (myText as NSString).substring(to: text.utf16.count - noLigatureInstruction.utf16.count)
        myFontDesc = CTFontDescriptorCreateCopyWithFeature(fontDesc, kLigaturesType as CFNumber, kCommonLigaturesOffSelector as CFNumber)
    } else if myText.hasSuffix(discretionaryLigatureInstruction) {
        myText = (myText as NSString).substring(to: text.utf16.count - discretionaryLigatureInstruction.utf16.count)
        myFontDesc = CTFontDescriptorCreateCopyWithFeature(fontDesc, kLigaturesType as CFNumber, kRareLigaturesOnSelector as CFNumber)
    } else if myText.hasSuffix(fractionInstruction) {
        myText = (myText as NSString).substring(to: text.utf16.count - fractionInstruction.utf16.count)
        myFontDesc = CTFontDescriptorCreateCopyWithFeature(fontDesc, kFractionsType as CFNumber, kDiagonalFractionsSelector as CFNumber)
    } else if myText.hasSuffix(ordinalInstruction) {
        myText = (myText as NSString).substring(to: text.utf16.count - ordinalInstruction.utf16.count)
        myFontDesc = CTFontDescriptorCreateCopyWithFeature(fontDesc, kVerticalPositionType as CFNumber, kOrdinalsSelector as CFNumber)
    } else if myText.contains(languageInstruction) {
        let range =  (myText as NSString).range(of: languageInstruction)
        myLang = (myText as NSString).substring(from: range.location + languageInstruction.utf16.count + 1)
        myText = (myText as NSString).substring(to: range.location)
    }

    return createPNG() {
        context in

        // Create the font.
        let font = CTFontCreateWithFontDescriptor(myFontDesc, CGFloat(fontSize), nil)

        // Turn the text into an attributed string with this font, and then into a line.
        let drawable = drawableString(myText as CFString, font: font, lang: myLang)
        let line = CTLineCreateWithAttributedString(drawable)

        // Draw lines indicating the font metrics.
        context.setFillColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        let ascentLine = baseLine + Int(CTFontGetAscent(font))
        let descentLine = baseLine - Int(CTFontGetDescent(font))
        context.fill(CGRect(x: 0, y: CGFloat(ascentLine), width: CGFloat(bitmapSize.x), height: 1))
        context.fill(CGRect(x: 0, y: CGFloat(baseLine), width: CGFloat(bitmapSize.x), height: -1))
        context.fill(CGRect(x: 0, y: CGFloat(descentLine), width: CGFloat(bitmapSize.x), height: -1))
        context.fill(CGRect(x: CGFloat(startOffset), y: 0, width: -1, height: CGFloat(bitmapSize.y)))
        let width = CTLineGetTypographicBounds(line, nil, nil, nil)
        let endOffset = startOffset + Int(width)
        context.fill(CGRect(x: CGFloat(endOffset), y: 0, width: 1, height: CGFloat(bitmapSize.y)))

        // Draw the text.
        context.textPosition = CGPoint(x: CGFloat(startOffset), y: CGFloat(baseLine))
        CTLineDraw(line, context)
    }
}

func createDiffImage(oldImage: Data, newImage: Data) -> Data {

    return createPNG() {
        context in

        // Creating a mask directly from PNG data doesn’t work, so we take a slight detour via an image.
        let oldImageImage = CGImage(pngDataProviderSource: CGDataProvider(data: oldImage as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let newImageImage = CGImage(pngDataProviderSource: CGDataProvider(data: newImage as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!

        let oldImageMask = CGImage(maskWidth: bitmapSize.x, height: bitmapSize.y, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bitmapSize.x * 4, provider: oldImageImage.dataProvider!, decode: nil, shouldInterpolate: false)!
        let newImageMask = CGImage(maskWidth: bitmapSize.x, height: bitmapSize.y, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bitmapSize.x * 4, provider: newImageImage.dataProvider!, decode: nil, shouldInterpolate: false)!

        context.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        context.fill (bitmapRect)
        context.clip(to: bitmapRect, mask: oldImageMask)
        context.setFillColor(red: 1.0, green: 0, blue: 0, alpha: 1.0)
        context.fill(bitmapRect)
        context.setBlendMode(.multiply)
        context.resetClip()
        context.clip(to: bitmapRect, mask: newImageMask)
        context.setFillColor(red: 0, green: 1.0, blue: 0, alpha: 1.0)
        context.fill(bitmapRect)
    }
}

func isAATFont(fontDesc: CTFontDescriptor) -> Bool {
    let font = CTFontCreateWithFontDescriptor(fontDesc, CGFloat(12), nil)
    if let fontTables = CTFontCopyAvailableTables(font, CTFontTableOptions(rawValue: 0)) {
        for i in 0 ..< CFArrayGetCount(fontTables) {
            if let value = CFArrayGetValueAtIndex(fontTables, i) {
                // The values are the actual table names, but CFArrayGetValueAtIndex returns them as UnsafeRawPointer.
                if value == UnsafeRawPointer(bitPattern: kCTFontTableMorx) {
                    return true
                }
            }
        }
    }
    return false
}

// Test rendering of the specified font by creating PNG images for the given test strings and
// comparing them with images already present in the test image directory. Save images for
// strings that don't have them yet.
// Return messages for any mismatches found.
func testFontRendering(_ testStrings: [String], fontDesc: CTFontDescriptor, testImageDirectory: String) -> [String]? {
    var errors = [String]()

    let isAAT = isAATFont(fontDesc: fontDesc)

    try! FileManager.default.createDirectory(atPath: testImageDirectory, withIntermediateDirectories: true, attributes: nil)
    let fileManager = FileManager.default

    for text in testStrings {
        let image = createTestImage(text, fontDesc: fontDesc)

        // Strings that are canonically equivalent should render the same way.
        // We therefore use normalized file names.
        // We can’t rely on the Mac file systems for normalization as they use different normalization forms –
        // based on Unicode 3.2 for HFS, on Unicode 9.0 for APFS, and likely with bugs.
        // (It seems though that FileManager uses more up-to-date mappings than HFS.)
        var baseName = text.precomposedStringWithCanonicalMapping

        // Preflighting against Apple bug 41277025: fsck_hfs sees <U+0E33> and <U+0E4D U+0E32> as equivalent,
        // and having file names in one directory that only differ in these characters can lead
        // to irreparable file system corruption.
        // To prevent that, map one to the other.
        // https://developer.apple.com/library/archive/technotes/tn/tn1150table.html
        // says that U+0E33 is the illegal one, although fsck_hfs sees it the other way around.
        // Mapping <U+0E33> to <U+0E4D U+0E32> often results in typographically
        // invalid sequences, so go the other way around.
        baseName = baseName.replacingOccurrences(of: "\u{0E4D}\u{0E32}", with: "\u{0E33}")
        // Do the same for other Southeast Asian script code points with <compat> mappings
        // listed on that page.
        baseName = baseName.replacingOccurrences(of: "\u{0ECD}\u{0EB2}", with: "\u{0EB3}")
        // Break for totally mishandled Tibetan characters.
        assert(!baseName.unicodeScalars.contains(U(0x0F77)))
        assert(!baseName.unicodeScalars.contains(U(0x0F79)))

        // Replace directory separators with alternate representations.
        baseName = baseName.replacingOccurrences(of: "/", with: "@slash@")
        baseName = baseName.replacingOccurrences(of: ":", with: "@colon@")

        // macOS file systems are typically not case sensitive, so upper case and lower case variants
        // of the same string would collide. In this case we have to enable separate images.
        // We do this by appending ⇧ to names containing uppercase letters.
        if baseName.lowercased() != baseName {
            baseName += " ⇧"
        }
        // If the font is an AAT font, there may be a separate image file to record
        // an acceptable divergence of OpenType and AAT versions of the font.
        var imagePath = testImageDirectory + "/" + baseName + ".AAT.png"
        if !(isAAT && fileManager.fileExists(atPath: imagePath)) {
            imagePath = testImageDirectory + "/" + baseName + ".png"
        }
        if fileManager.fileExists(atPath: imagePath) {
            let existingImage = fileManager.contents(atPath: imagePath)!
            if image != existingImage {
                errors.append("Images don't match for string \(text)")
                let diffImage = createDiffImage(oldImage: existingImage, newImage: image)
                fileManager.createFile(atPath: testImageDirectory + "/" + baseName + ".diff.png", contents: diffImage, attributes: nil)
            }
        } else {
            fileManager.createFile(atPath: imagePath, contents: image, attributes: nil)
        }
    }
    return errors.count > 0 ? errors : nil
}

/// Creates a UnicodeScalar.
func U(_ u: Int) -> UnicodeScalar {
    return UnicodeScalar(u)!
}
