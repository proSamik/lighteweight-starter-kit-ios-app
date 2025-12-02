import SwiftUI

struct ImageCropperView: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var cropSize: CGFloat = 300
    @State private var viewSize: CGSize = .zero
    @Environment(\.colorScheme) var colorScheme

    private let minCropSize: CGFloat = 100
    private let maxCropSize: CGFloat = 400

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color.black : Color(.systemGray6))
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    // Image with crop area
                    ZStack {
                        GeometryReader { geometry in
                            // The image
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .scaleEffect(scale)
                                .offset(offset)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .gesture(
                                    SimultaneousGesture(
                                        MagnificationGesture()
                                            .onChanged { value in
                                                scale = lastScale * value
                                            }
                                            .onEnded { value in
                                                lastScale = scale
                                            },
                                        DragGesture()
                                            .onChanged { value in
                                                offset = CGSize(
                                                    width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height
                                                )
                                            }
                                            .onEnded { value in
                                                lastOffset = offset
                                            }
                                    )
                                )
                                .onAppear {
                                    viewSize = geometry.size
                                }
                                .onChange(of: geometry.size) { oldValue, newValue in
                                    viewSize = newValue
                                }
                        }

                        // Crop overlay with resizable corners
                        ResizableCropOverlay(cropSize: $cropSize, minSize: minCropSize, maxSize: maxCropSize)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Spacer()

                    // Controls
                    VStack(spacing: 20) {
                        // Size indicator
                        Text("\(Int(cropSize)) × \(Int(cropSize))")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)

                        // Reset button
                        Button(action: resetTransform) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset")
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray5))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Crop Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        cropImage()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func resetTransform() {
        withAnimation {
            scale = 1.0
            lastScale = 1.0
            offset = .zero
            lastOffset = .zero
        }
    }

    private func cropImage() {
        // Normalize the image orientation first
        let normalizedImage = normalizeImageOrientation(image)

        // Final output size
        let outputSize = CGSize(width: cropSize, height: cropSize)

        // Get the normalized image size
        let imageSize = normalizedImage.size

        // Calculate the displayed image size (aspect fit)
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height

        var displayedImageSize: CGSize
        if imageAspect > viewAspect {
            // Image is wider - constrained by width
            displayedImageSize = CGSize(
                width: viewSize.width,
                height: viewSize.width / imageAspect
            )
        } else {
            // Image is taller - constrained by height
            displayedImageSize = CGSize(
                width: viewSize.height * imageAspect,
                height: viewSize.height
            )
        }

        // Apply user's scale
        let scaledImageSize = CGSize(
            width: displayedImageSize.width * scale,
            height: displayedImageSize.height * scale
        )

        // Calculate center of view
        let viewCenter = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)

        // Calculate where the scaled image is positioned (center + offset)
        let imageCenter = CGPoint(
            x: viewCenter.x + offset.width,
            y: viewCenter.y + offset.height
        )

        // Calculate top-left of the scaled image
        let imageTopLeft = CGPoint(
            x: imageCenter.x - scaledImageSize.width / 2,
            y: imageCenter.y - scaledImageSize.height / 2
        )

        // Crop rect in view coordinates (center of view)
        let cropRect = CGRect(
            x: viewCenter.x - cropSize / 2,
            y: viewCenter.y - cropSize / 2,
            width: cropSize,
            height: cropSize
        )

        // Convert crop rect to image coordinates
        // Scale factor from displayed size to original image size
        let imageScale = imageSize.width / scaledImageSize.width

        let cropInImageCoordinates = CGRect(
            x: (cropRect.origin.x - imageTopLeft.x) * imageScale,
            y: (cropRect.origin.y - imageTopLeft.y) * imageScale,
            width: cropRect.width * imageScale,
            height: cropRect.height * imageScale
        )

        // Crop the image
        guard let cgImage = normalizedImage.cgImage,
              let croppedCGImage = cgImage.cropping(to: cropInImageCoordinates) else {
            onCrop(normalizedImage)
            return
        }

        // Create final image at output size
        let renderer = UIGraphicsImageRenderer(size: outputSize)
        let croppedImage = renderer.image { context in
            UIImage(cgImage: croppedCGImage).draw(in: CGRect(origin: .zero, size: outputSize))
        }

        onCrop(croppedImage)
    }

    private func normalizeImageOrientation(_ image: UIImage) -> UIImage {
        // If already up, return as is
        if image.imageOrientation == .up {
            return image
        }

        // Render the image in the correct orientation
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalizedImage ?? image
    }
}

struct ResizableCropOverlay: View {
    @Binding var cropSize: CGFloat
    let minSize: CGFloat
    let maxSize: CGFloat
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimmed areas outside crop zone
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .mask(
                        Rectangle()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .overlay(
                                Rectangle()
                                    .frame(width: cropSize, height: cropSize)
                                    .blendMode(.destinationOut)
                            )
                    )
                    .allowsHitTesting(false)

                // Crop border
                Rectangle()
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(width: cropSize, height: cropSize)
                    .allowsHitTesting(false)

                // Grid lines (rule of thirds)
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle().fill(Color.white.opacity(0.5)).frame(height: 1)
                    Spacer()
                    Rectangle().fill(Color.white.opacity(0.5)).frame(height: 1)
                    Spacer()
                }
                .frame(width: cropSize, height: cropSize)
                .allowsHitTesting(false)

                HStack(spacing: 0) {
                    Spacer()
                    Rectangle().fill(Color.white.opacity(0.5)).frame(width: 1)
                    Spacer()
                    Rectangle().fill(Color.white.opacity(0.5)).frame(width: 1)
                    Spacer()
                }
                .frame(width: cropSize, height: cropSize)
                .allowsHitTesting(false)

                // Resizable corners
                ResizableCorners(cropSize: $cropSize, minSize: minSize, maxSize: maxSize)
            }
        }
    }
}

struct ResizableCorners: View {
    @Binding var cropSize: CGFloat
    let minSize: CGFloat
    let maxSize: CGFloat

    var body: some View {
        ZStack {
            // Top-left corner
            ResizableCornerHandle(position: .topLeft, cropSize: $cropSize, minSize: minSize, maxSize: maxSize)
                .offset(x: -cropSize/2, y: -cropSize/2)

            // Top-right corner
            ResizableCornerHandle(position: .topRight, cropSize: $cropSize, minSize: minSize, maxSize: maxSize)
                .offset(x: cropSize/2, y: -cropSize/2)

            // Bottom-left corner
            ResizableCornerHandle(position: .bottomLeft, cropSize: $cropSize, minSize: minSize, maxSize: maxSize)
                .offset(x: -cropSize/2, y: cropSize/2)

            // Bottom-right corner
            ResizableCornerHandle(position: .bottomRight, cropSize: $cropSize, minSize: minSize, maxSize: maxSize)
                .offset(x: cropSize/2, y: cropSize/2)
        }
    }
}

enum CornerPosition {
    case topLeft, topRight, bottomLeft, bottomRight
}

struct ResizableCornerHandle: View {
    let position: CornerPosition
    @Binding var cropSize: CGFloat
    let minSize: CGFloat
    let maxSize: CGFloat

    @State private var initialSize: CGFloat = 0

    var body: some View {
        ZStack {
            // Corner handle
            Circle()
                .fill(Color.blue)
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )

            // Corner lines
            VStack(spacing: 0) {
                Rectangle().fill(Color.blue).frame(width: 3, height: 25)
                Spacer()
            }
            .frame(width: 3, height: 30)

            HStack(spacing: 0) {
                Rectangle().fill(Color.blue).frame(width: 25, height: 3)
                Spacer()
            }
            .frame(width: 30, height: 3)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if initialSize == 0 {
                        initialSize = cropSize
                    }

                    // Calculate size change based on drag distance
                    let multiplier: CGFloat = position == .topLeft || position == .bottomLeft ? -1 : 1
                    let sizeChange = (value.translation.width * multiplier + value.translation.height) / 2

                    let newSize = min(max(initialSize + sizeChange, minSize), maxSize)
                    cropSize = newSize
                }
                .onEnded { _ in
                    initialSize = 0
                }
        )
    }
}
