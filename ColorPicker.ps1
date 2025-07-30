Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object Windows.Forms.Form
$form.Text = "吸色器工具"
$form.Size = [Drawing.Size]::new(300, 200)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true

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
    $colorBtn.Text = if ($script:isSampling) { "吸色中…" } else { "開啟吸色模式" }
    $zoomForm.Visible = $script:isSampling
})

$timer = [Windows.Forms.Timer]::new()
$timer.Interval = 50
$timer.Add_Tick({
    if ($script:isSampling) {
        $mousePos = [Windows.Forms.Cursor]::Position

        # 只有滑鼠移動才更新
        if ($mousePos -ne $script:lastMousePos) {
            $script:lastMousePos = $mousePos

            $zoomForm.Hide()

            $bmp = [Drawing.Bitmap]::new($bmpSize, $bmpSize)
            $gfx = [Drawing.Graphics]::FromImage($bmp)
            $gfx.CopyFromScreen($mousePos.X - $centerOffset, $mousePos.Y - $centerOffset, 0, 0, $bmp.Size)
            if ($script:cachedBitmap) { $script:cachedBitmap.Dispose() }
            $script:cachedBitmap = $bmp
            $gfx.Dispose()

            $zoomForm.Show()

            $centerColor = $bmp.GetPixel($centerOffset, $centerOffset)
            $rgbLabel.Text = "RGB: R=$($centerColor.R) G=$($centerColor.G) B=$($centerColor.B)"
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
            $colorBtn.Text = "開啟吸色模式"
            $zoomForm.Visible = $false
            if ($script:cachedBitmap) {
                $script:cachedBitmap.Dispose()
                $script:cachedBitmap = $null
            }
        }
    }
})

$timer.Start()
$form.Controls.Add($rgbLabel)
$form.Controls.Add($colorBtn)
[void]$form.ShowDialog()