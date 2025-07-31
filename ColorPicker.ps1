Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object Windows.Forms.Form
$form.Text = "吸色器工具"
$form.Size = [Drawing.Size]::new(300, 200)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true
$form.SizeGripStyle = [System.Windows.Forms.SizeGripStyle]::Hide

# 設定視窗圖標
$iconPath = Join-Path $PSScriptRoot "ColorPicker.ico"
if (Test-Path $iconPath) {
    $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($iconPath)
}
function Resize() {
    $totalHeight = 0

    foreach ($ctrl in $form.Controls) {
        if ($ctrl -is [System.Windows.Forms.Button] -and $ctrl -ne $closeBtn) {
            $ctrl.Width = $form.ClientSize.Width - 20

            # 抓顯示所需高度（TextRenderer 預測顯示效果）
            $textSize = [System.Windows.Forms.TextRenderer]::MeasureText(
                $ctrl.Text,
                $ctrl.Font,
                [System.Drawing.Size]::new($ctrl.Width, 9999),
                [System.Windows.Forms.TextFormatFlags]::WordBreak
            )

            # 使用 Font.Height 或指定的單行高計算行數
            $lineHeight = $ctrl.Font.Height
            $lineCount = [math]::Ceiling($textSize.Height / $lineHeight)

            # 最小限制：若沒有換行，也至少顯示一行
            if ($lineCount -lt 1) { $lineCount = 1 }

            $ctrl.Height = $lineCount * $lineHeight + 10
            $totalHeight += $ctrl.Height + 10
        }
    }

    # 垂直置中排列
    $startY = [Math]::Max(10, ($form.ClientSize.Height - $totalHeight) / 2)
    foreach ($ctrl in $form.Controls) {
        if ($ctrl -is [System.Windows.Forms.Button]) {
            $ctrl.Left = ($form.ClientSize.Width - $ctrl.Width) / 2
            $ctrl.Top  = $startY
            $startY += $ctrl.Height + 10
        }
    }
}
$form.Add_Resize({
    Resize
})

$rgbLabel = [Windows.Forms.Label]::new()
$rgbLabel.Location = [Drawing.Point]::new(20, 100)
$rgbLabel.Size = [Drawing.Size]::new(250, 30)
$rgbLabel.Font = [Drawing.Font]::new("Segoe UI", 12)
$rgbLabel.Text = "RGB: -"

$colorBtn = [Windows.Forms.Button]::new()
$colorBtn.Text = "開啟吸色模式"
$colorBtn.Location = [Drawing.Point]::new(20, 20)
$colorBtn.Size = [Drawing.Size]::new(160, 40)
$colorBtn.Font = [Drawing.Font]::new("Microsoft JhengHei", 10)
$colorBtn.BackColor =  [Drawing.Color]::White
# 美化按鈕樣式
$colorBtn.FlatStyle = 'Flat'
$colorBtn.FlatAppearance.BorderSize = 0

$script:isSampling = $false

$zoomForm = [Windows.Forms.Form]::new()
$zoomForm.FormBorderStyle = 'None'
$zoomForm.Size = [Drawing.Size]::new(180, 180)
$zoomForm.TopMost = $true
$zoomForm.ShowInTaskbar = $false
$zoomForm.BackColor = [Drawing.Color]::White
$zoomForm.TransparencyKey = $zoomForm.BackColor
$zoomForm.DoubleBuffered = $true

$bmpSize = 9
$pixelSize = 20
$centerOffset = [Math]::Floor($bmpSize / 2)

$script:cachedBitmap = $null

$zoomForm.Add_Paint({
    param ($sender, $e)
    $g = $e.Graphics
    $g.Clear($zoomForm.BackColor)

    if ($script:cachedBitmap) {
        for ($x = 0; $x -lt $bmpSize; $x++) {
            for ($y = 0; $y -lt $bmpSize; $y++) {
                $pixelColor = $script:cachedBitmap.GetPixel($x, $y)
                $brush = [Drawing.SolidBrush]::new($pixelColor)
                $g.FillRectangle($brush, $x * $pixelSize, $y * $pixelSize, $pixelSize, $pixelSize)
                $brush.Dispose()
            }
        }

        $highlightPen = [Drawing.Pen]::new([Drawing.Color]::Red, 2)
        $g.DrawRectangle($highlightPen, $centerOffset * $pixelSize, $centerOffset * $pixelSize, $pixelSize, $pixelSize)
        $highlightPen.Dispose()
    }
})

$colorBtn.Add_Click({
    $script:isSampling = -not $script:isSampling
    $colorBtn.Text = "吸色中…"
    $zoomForm.Visible = $script:isSampling
    $form.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
})

$timer = [Windows.Forms.Timer]::new()
$timer.Interval = 33
$timer.Add_Tick({
    if ($script:isSampling) {
        $mousePos = [Windows.Forms.Cursor]::Position

        # 只有滑鼠移動才更新
        if ($mousePos -ne $script:lastMousePos) {
            $script:lastMousePos = $mousePos

            $zoomForm.Opacity = 0

            $bmp = [Drawing.Bitmap]::new($bmpSize, $bmpSize)
            $gfx = [Drawing.Graphics]::FromImage($bmp)
            $gfx.CopyFromScreen($mousePos.X - $centerOffset, $mousePos.Y - $centerOffset, 0, 0, $bmp.Size)
            if ($script:cachedBitmap) { $script:cachedBitmap.Dispose() }
            $script:cachedBitmap = $bmp
            $gfx.Dispose()

            $zoomForm.Opacity = 1

            $centerColor = $bmp.GetPixel($centerOffset, $centerOffset)
            $rgbLabel.Text = "R=$($centerColor.R) G=$($centerColor.G) B=$($centerColor.B)"
            $form.BackColor = $centerColor

            $zoomForm.Location = [Drawing.Point]::new(
                $mousePos.X - [Math]::Floor($zoomForm.Width / 2),
                $mousePos.Y - [Math]::Floor($zoomForm.Height / 2)
            )

            $zoomForm.Invalidate()
        }

        # 點擊左鍵關閉模式
        if ([Windows.Forms.Control]::MouseButtons -band [Windows.Forms.MouseButtons]::Left) {
            $script:isSampling = $false
            $colorBtn.Text = "開啟吸色模式`n" + $rgbLabel.Text
            $zoomForm.Visible = $false
            if ($script:cachedBitmap) {
                $script:cachedBitmap.Dispose()
                $script:cachedBitmap = $null
            }
            $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
            [System.Windows.Forms.Clipboard]::SetText($rgbLabel.Text)
        }
    }
})

$timer.Start()
$form.Controls.Add($colorBtn)
Resize
[void]$form.ShowDialog()