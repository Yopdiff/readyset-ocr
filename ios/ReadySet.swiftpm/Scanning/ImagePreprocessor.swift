import CoreGraphics

/// OCR 전에 이미지 정리 (friend's preprocess.js의 prepare()를 Swift로 옮김)
/// 1. 흑백  2. 어두운 화면이면 반전  3. 색 배경을 흰색으로  4. 대비 높이기  5. 표 테두리 지우기
enum ImagePreprocessor {
    /// - scale: 이미 키운 배율 (테두리 두께 기준에 쓰임)
    static func prepare(_ image: CGImage, scale: Double) -> CGImage? {
        let w = image.width, h = image.height, n = w * h
        guard n > 0,
              let context = CGContext(
                data: nil, width: w, height: h,
                bitsPerComponent: 8, bytesPerRow: w,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
              )
        else { return nil }
        
        // 1. 흑백 (투명한 부분은 흰색으로)
        let rect = CGRect(x: 0, y: 0, width: w, height: h)
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(rect)
        context.draw(image, in: rect)
        guard let data = context.data else { return nil }
        let p = data.bindMemory(to: UInt8.self, capacity: n)
        
        // 2. 어두운 화면(다크 모드)이면 반전
        var sum = 0
        for i in 0..<n { sum += Int(p[i]) }
        if sum / n < 110 {
            for i in 0..<n { p[i] = 255 - p[i] }
        }
        
        // 3. 색 배경을 흰색으로
        flattenBackground(p, w: w, h: h, step: max(1, Int(scale.rounded())))
        
        // 4. 대비: 하위 1% ~ 상위 1%를 0~255로 늘림
        var hist = [Int](repeating: 0, count: 256)
        for i in 0..<n { hist[Int(p[i])] += 1 }
        let cut = Double(n) * 0.01
        var lo = 0, hi = 255, acc = 0
        for v in 0..<256 {
            acc += hist[v]
            if Double(acc) >= cut { lo = v; break }
        }
        acc = 0
        for v in stride(from: 255, through: 0, by: -1) {
            acc += hist[v]
            if Double(acc) >= cut { hi = v; break }
        }
        if hi - lo > 40 {
            let k = 255.0 / Double(hi - lo)
            hist = [Int](repeating: 0, count: 256)
            for i in 0..<n {
                let v = max(0, min(255, (Double(p[i]) - Double(lo)) * k))
                p[i] = UInt8(v)
                hist[Int(p[i])] += 1
            }
        }
        
        // 5. 표 테두리 지우기 (긴 선이 글자 인식을 방해함)
        eraseLines(p, w: w, h: h, threshold: otsu(hist, total: n), scale: scale)
        
        return context.makeImage()
    }
    
    /// 배경 밝기를 추정해서(글자·선 같은 얇은 것은 지움) 각 픽셀을 배경으로 나눔 → 배경이 흰색이 됨
    private static func flattenBackground(_ p: UnsafeMutablePointer<UInt8>, w: Int, h: Int, step: Int) {
        let gw = (w + step - 1) / step
        let gh = (h + step - 1) / step
        let r = 4
        var a = [UInt8](repeating: 0, count: gw * gh)
        var b = [UInt8](repeating: 0, count: gw * gh)
        
        for y in 0..<h {
            let row = (y / step) * gw
            for x in 0..<w {
                let v = p[y * w + x]
                let k = row + x / step
                if v > a[k] { a[k] = v }
            }
        }
        
        func pass(_ src: [UInt8], _ dst: inout [UInt8], horizontal: Bool, wantMax: Bool) {
            for y in 0..<gh {
                for x in 0..<gw {
                    var m: UInt8 = wantMax ? 0 : 255
                    for d in -r...r {
                        let xx = horizontal ? x + d : x
                        let yy = horizontal ? y : y + d
                        if xx < 0 || yy < 0 || xx >= gw || yy >= gh { continue }
                        let v = src[yy * gw + xx]
                        if wantMax ? (v > m) : (v < m) { m = v }
                    }
                    dst[y * gw + x] = m
                }
            }
        }
        pass(a, &b, horizontal: true, wantMax: true)     // 넓히기
        pass(b, &a, horizontal: false, wantMax: true)
        pass(a, &b, horizontal: true, wantMax: false)    // 좁히기
        pass(b, &a, horizontal: false, wantMax: false)
        
        for y in 0..<h {
            let row = (y / step) * gw
            for x in 0..<w {
                let background = max(Int(a[row + x / step]), 1)
                let v = Int(p[y * w + x]) * 255 / background
                p[y * w + x] = UInt8(min(v, 255))
            }
        }
    }
    
    /// 한 방향으로 길고 다른 방향으로 얇은 어두운 선(표 테두리)을 흰색으로
    private static func eraseLines(_ p: UnsafeMutablePointer<UInt8>, w: Int, h: Int, threshold: UInt8, scale: Double) {
        let n = w * h
        let long = Int((34 * scale).rounded())
        let thin = Int((3 * scale).rounded())
        let halo = Int((scale / 2).rounded(.up)) + 1
        var hrun = [UInt16](repeating: 0, count: n)
        var vrun = [UInt16](repeating: 0, count: n)
        
        for y in 0..<h {
            var start = -1
            for x in 0...w {
                let dark = x < w && p[y * w + x] < threshold
                if dark && start < 0 { start = x }
                if !dark && start >= 0 {
                    let length = UInt16(min(65535, x - start))
                    for k in start..<x { hrun[y * w + k] = length }
                    start = -1
                }
            }
        }
        for x in 0..<w {
            var start = -1
            for y in 0...h {
                let dark = y < h && p[y * w + x] < threshold
                if dark && start < 0 { start = y }
                if !dark && start >= 0 {
                    let length = UInt16(min(65535, y - start))
                    for k in start..<y { vrun[k * w + x] = length }
                    start = -1
                }
            }
        }
        
        var out = [UInt8](UnsafeBufferPointer(start: p, count: n))
        for y in 0..<h {
            for x in 0..<w {
                let i = y * w + x
                let hr = Int(hrun[i]), vr = Int(vrun[i])
                if hr >= long && vr <= thin {
                    for d in (-halo - vr)...(halo + vr) {
                        let yy = y + d
                        if yy >= 0 && yy < h { out[yy * w + x] = 255 }
                    }
                } else if vr >= long && hr <= thin {
                    for d in (-halo - hr)...(halo + hr) {
                        let xx = x + d
                        if xx >= 0 && xx < w { out[y * w + xx] = 255 }
                    }
                }
            }
        }
        for i in 0..<n { p[i] = out[i] }
    }
    
    /// 글자(어두움)와 배경(밝음)을 가르는 기준 밝기 자동 계산 (오츠 방법)
    private static func otsu(_ hist: [Int], total: Int) -> UInt8 {
        var sum = 0.0
        for i in 0..<256 { sum += Double(i * hist[i]) }
        var sumB = 0.0, wB = 0.0, best = 0.0
        var threshold = 127
        for t in 0..<256 {
            wB += Double(hist[t])
            if wB == 0 { continue }
            let wF = Double(total) - wB
            if wF == 0 { break }
            sumB += Double(t * hist[t])
            let mB = sumB / wB
            let mF = (sum - sumB) / wF
            let between = wB * wF * (mB - mF) * (mB - mF)
            if between > best {
                best = between
                threshold = t
            }
        }
        return UInt8(threshold)
    }
}
