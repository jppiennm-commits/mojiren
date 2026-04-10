Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$brandingDir = Join-Path $projectRoot "assets\branding"
$androidResDir = Join-Path $projectRoot "android\app\src\main\res"
$iosIconDir = Join-Path $projectRoot "ios\Runner\Assets.xcassets\AppIcon.appiconset"

function New-Bitmap {
    param([int]$Size)

    $bitmap = New-Object System.Drawing.Bitmap $Size, $Size
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    return @{ Bitmap = $bitmap; Graphics = $graphics }
}

function New-RoundedRectPath {
    param(
        [float]$X,
        [float]$Y,
        [float]$Width,
        [float]$Height,
        [float]$Radius
    )

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $diameter = $Radius * 2
    $path.AddArc($X, $Y, $diameter, $diameter, 180, 90)
    $path.AddArc($X + $Width - $diameter, $Y, $diameter, $diameter, 270, 90)
    $path.AddArc($X + $Width - $diameter, $Y + $Height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($X, $Y + $Height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function Save-ResizedPng {
    param(
        [System.Drawing.Image]$SourceImage,
        [string]$Path,
        [int]$Width,
        [int]$Height
    )

    $bundle = New-Bitmap -Size $Width
    try {
        $bundle.Graphics.Clear([System.Drawing.Color]::Transparent)
        $bundle.Graphics.DrawImage($SourceImage, 0, 0, $Width, $Height)
        $bundle.Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $bundle.Graphics.Dispose()
        $bundle.Bitmap.Dispose()
    }
}

$bundle = New-Bitmap -Size 1024

try {
    $g = $bundle.Graphics
    $bmp = $bundle.Bitmap

    $outer = [System.Drawing.ColorTranslator]::FromHtml("#F7EEDC")
    $panelTop = [System.Drawing.ColorTranslator]::FromHtml("#FFF8E8")
    $panelBottom = [System.Drawing.ColorTranslator]::FromHtml("#EED9BC")
    $frame = [System.Drawing.ColorTranslator]::FromHtml("#DDBA92")
    $guide = [System.Drawing.Color]::FromArgb(70, 203, 99, 59)
    $guideStrong = [System.Drawing.Color]::FromArgb(190, 203, 99, 59)
    $ink = [System.Drawing.ColorTranslator]::FromHtml("#3B261D")
    $shadow = [System.Drawing.Color]::FromArgb(44, 89, 58, 38)

    $g.Clear($outer)

    $panelPath = New-RoundedRectPath -X 146 -Y 132 -Width 732 -Height 732 -Radius 188

    $shadowBrush = New-Object System.Drawing.SolidBrush $shadow
    $shadowMatrix = New-Object System.Drawing.Drawing2D.Matrix
    $shadowMatrix.Translate(0, 18)
    $shadowPath = $panelPath.Clone()
    $shadowPath.Transform($shadowMatrix)
    $g.FillPath($shadowBrush, $shadowPath)

    $panelBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.Point 146, 132),
        (New-Object System.Drawing.Point 878, 864),
        $panelTop,
        $panelBottom
    )
    $g.FillPath($panelBrush, $panelPath)

    $framePen = New-Object System.Drawing.Pen $frame, 10
    $g.DrawPath($framePen, $panelPath)

    $guidePen = New-Object System.Drawing.Pen $guide, 8
    $guideStrongPen = New-Object System.Drawing.Pen $guideStrong, 16
    $guideStrongPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $guideStrongPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

    $g.DrawLine($guidePen, 512, 268, 512, 760)
    $g.DrawLine($guidePen, 266, 512, 758, 512)
    $g.DrawLine($guideStrongPen, 466, 512, 558, 512)
    $g.DrawLine($guideStrongPen, 512, 466, 512, 558)

    $decorPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(38, 43, 26, 19)), 18
    $decorPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $decorPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawArc($decorPen, 292, 282, 286, 112, 210, 112)
    $g.DrawLine($decorPen, 618, 686, 736, 620)

    $smallBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(64, 203, 99, 59))
    $g.FillEllipse($smallBrush, 192, 192, 22, 22)
    $g.FillEllipse($smallBrush, 810, 800, 30, 30)

    $fontFamily = "Yu Mincho"
    $font = New-Object System.Drawing.Font($fontFamily, 405, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center

    $textRect = New-Object System.Drawing.RectangleF(206, 198, 612, 520)
    $inkBrush = New-Object System.Drawing.SolidBrush $ink
    $g.DrawString([string][char]0x7DF4, $font, $inkBrush, $textRect, $format)

    $sourcePng = Join-Path $brandingDir "app-icon-source-1024.png"
    $bmp.Save($sourcePng, [System.Drawing.Imaging.ImageFormat]::Png)

    $svg = @'
<svg width="1024" height="1024" viewBox="0 0 1024 1024" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="panelFill" x1="146" y1="132" x2="878" y2="864" gradientUnits="userSpaceOnUse">
      <stop stop-color="#FFF8E8"/>
      <stop offset="1" stop-color="#EED9BC"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" rx="240" fill="#F7EEDC"/>
  <rect x="146" y="150" width="732" height="732" rx="188" fill="#593A2616"/>
  <rect x="146" y="132" width="732" height="732" rx="188" fill="url(#panelFill)" stroke="#DDBA92" stroke-width="10"/>
  <path d="M512 268V760" stroke="#CB633B" stroke-opacity="0.28" stroke-width="8"/>
  <path d="M266 512H758" stroke="#CB633B" stroke-opacity="0.28" stroke-width="8"/>
  <path d="M466 512H558" stroke="#CB633B" stroke-width="16" stroke-linecap="round"/>
  <path d="M512 466V558" stroke="#CB633B" stroke-width="16" stroke-linecap="round"/>
  <text x="512" y="472"
        text-anchor="middle"
        dominant-baseline="central"
        fill="#3B261D"
        font-size="405"
        font-family="Yu Mincho, YuMincho, serif">
    &#x7DF4;
  </text>
  <path d="M332 334C394 316 456 316 520 326" stroke="#2B1A13" stroke-opacity="0.12" stroke-width="18" stroke-linecap="round"/>
  <path d="M618 686C658 678 698 656 734 620" stroke="#2B1A13" stroke-opacity="0.12" stroke-width="18" stroke-linecap="round"/>
  <circle cx="203" cy="203" r="11" fill="#CB633B" fill-opacity="0.24"/>
  <circle cx="825" cy="815" r="15" fill="#CB633B" fill-opacity="0.5"/>
</svg>
'@
    [System.IO.File]::WriteAllText((Join-Path $brandingDir "app-icon-source.svg"), $svg, [System.Text.UTF8Encoding]::new($false))

    $androidSizes = @{
        "mipmap-mdpi" = 48
        "mipmap-hdpi" = 72
        "mipmap-xhdpi" = 96
        "mipmap-xxhdpi" = 144
        "mipmap-xxxhdpi" = 192
    }

    foreach ($entry in $androidSizes.GetEnumerator()) {
        $dir = Join-Path $androidResDir $entry.Key
        Save-ResizedPng -SourceImage $bmp -Path (Join-Path $dir "ic_launcher.png") -Width $entry.Value -Height $entry.Value
        Save-ResizedPng -SourceImage $bmp -Path (Join-Path $dir "ic_launcher_round.png") -Width $entry.Value -Height $entry.Value
        Save-ResizedPng -SourceImage $bmp -Path (Join-Path $dir "ic_launcher_foreground.png") -Width $entry.Value -Height $entry.Value
    }

    $iosSizes = @(
        @{ Name = "Icon-App-20x20@1x.png"; Size = 20 },
        @{ Name = "Icon-App-20x20@2x.png"; Size = 40 },
        @{ Name = "Icon-App-20x20@3x.png"; Size = 60 },
        @{ Name = "Icon-App-29x29@1x.png"; Size = 29 },
        @{ Name = "Icon-App-29x29@2x.png"; Size = 58 },
        @{ Name = "Icon-App-29x29@3x.png"; Size = 87 },
        @{ Name = "Icon-App-40x40@1x.png"; Size = 40 },
        @{ Name = "Icon-App-40x40@2x.png"; Size = 80 },
        @{ Name = "Icon-App-40x40@3x.png"; Size = 120 },
        @{ Name = "Icon-App-60x60@2x.png"; Size = 120 },
        @{ Name = "Icon-App-60x60@3x.png"; Size = 180 },
        @{ Name = "Icon-App-76x76@1x.png"; Size = 76 },
        @{ Name = "Icon-App-76x76@2x.png"; Size = 152 },
        @{ Name = "Icon-App-83.5x83.5@2x.png"; Size = 167 },
        @{ Name = "Icon-App-1024x1024@1x.png"; Size = 1024 }
    )

    foreach ($icon in $iosSizes) {
        Save-ResizedPng -SourceImage $bmp -Path (Join-Path $iosIconDir $icon.Name) -Width $icon.Size -Height $icon.Size
    }
}
finally {
    if ($panelPath) { $panelPath.Dispose() }
    if ($shadowPath) { $shadowPath.Dispose() }
    if ($shadowMatrix) { $shadowMatrix.Dispose() }
    if ($shadowBrush) { $shadowBrush.Dispose() }
    if ($panelBrush) { $panelBrush.Dispose() }
    if ($framePen) { $framePen.Dispose() }
    if ($guidePen) { $guidePen.Dispose() }
    if ($guideStrongPen) { $guideStrongPen.Dispose() }
    if ($decorPen) { $decorPen.Dispose() }
    if ($smallBrush) { $smallBrush.Dispose() }
    if ($font) { $font.Dispose() }
    if ($format) { $format.Dispose() }
    if ($inkBrush) { $inkBrush.Dispose() }
    if ($bundle.Graphics) { $bundle.Graphics.Dispose() }
    if ($bundle.Bitmap) { $bundle.Bitmap.Dispose() }
}
