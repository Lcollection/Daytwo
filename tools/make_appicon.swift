// 生成 Daytwo 应用图标：靛蓝→青色渐变背景 + 白色日出图形
// 用法: swift tools/make_appicon.swift <输出.png> [--rounded]
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("usage: make_appicon <out.png> [--rounded]")
    exit(1)
}
let out = URL(fileURLWithPath: args[1])
let rounded = args.contains("--rounded")
let size = 1024

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(
    data: nil, width: size, height: size,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

// 背景：靛蓝 → 青色 对角渐变
let top = CGColor(srgbRed: 0.29, green: 0.31, blue: 0.90, alpha: 1.0)     // #4A50E6
let bottom = CGColor(srgbRed: 0.02, green: 0.71, blue: 0.83, alpha: 1.0)  // #06B6D4
let gradient = CGGradient(colorsSpace: colorSpace, colors: [top, bottom] as CFArray, locations: [0, 1])!

if rounded {
    let radius = Double(size) * 0.22
    let path = CGPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size), cornerWidth: radius, cornerHeight: radius, transform: nil)
    context.addPath(path)
    context.clip()
}
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: Double(size)), end: CGPoint(x: Double(size), y: 0), options: [])

let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
func white(_ alpha: CGFloat) -> CGColor { CGColor(srgbRed: 1, green: 1, blue: 1, alpha: alpha) }

// 太阳（CG 坐标系原点在左下）
context.setFillColor(white(0.98))
context.fillEllipse(in: CGRect(x: 362, y: 314, width: 300, height: 300))

// 地平线
context.setFillColor(white(0.95))
let line = CGPath(roundedRect: CGRect(x: 282, y: 290, width: 460, height: 28), cornerWidth: 14, cornerHeight: 14, transform: nil)
context.addPath(line)
context.fillPath()

// 地平线下方的倒影光晕
context.setFillColor(white(0.28))
context.fill(CGRect(x: 402, y: 236, width: 220, height: 16))
context.setFillColor(white(0.14))
context.fill(CGRect(x: 442, y: 196, width: 140, height: 14))

guard let image = context.makeImage() else {
    print("无法生成图像")
    exit(1)
}

let destination = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    print("写入 PNG 失败")
    exit(1)
}
print("已生成 \(out.path)")
