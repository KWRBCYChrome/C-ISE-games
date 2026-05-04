if ($global:BlockBlastRunning) { 
    Write-Host "Block Blast is already running!" -ForegroundColor Yellow
    return 
}
$global:BlockBlastRunning = $true

# ============================================================
# SETTINGS
# ============================================================
$GridSize = 8
$CellSize = 40
$GridPixelSize = $GridSize * $CellSize
$PieceAreaHeight = 150
$WindowWidth = $GridPixelSize + 40
$WindowHeight = $GridPixelSize + $PieceAreaHeight + 80
$PanelOffsetX = 20
$PanelOffsetY = 55
$TotalPanelHeight = $GridPixelSize + $PieceAreaHeight

$PointsPerCell = 1
$ComboMultiplier = 10

# ============================================================
# GAME STATE
# ============================================================
$script:Grid = New-Object 'int[,]' $GridSize, $GridSize
$script:Score = 0
$script:GameOver = $false
$script:Pieces = @()
$script:SelectedPiece = $null
$script:PieceIndex = -1
$script:DragX = 0
$script:DragY = 0
$script:DragOffsetX = 0
$script:DragOffsetY = 0

# ============================================================
# PIECE DEFINITIONS
# ============================================================
$script:AllPieces = @(
    @{ id = 1; name = "1x1"; color = [System.Drawing.Color]::Black; matrix = @(@(1)) },
    @{ id = 2; name = "2x1"; color = [System.Drawing.Color]::Black; matrix = @(@(1,1)) },
    @{ id = 3; name = "1x2"; color = [System.Drawing.Color]::Black; matrix = @(@(1),@(1)) },
    @{ id = 4; name = "3x1"; color = [System.Drawing.Color]::Black; matrix = @(@(1,1,1)) },
    @{ id = 5; name = "1x3"; color = [System.Drawing.Color]::Black; matrix = @(@(1),@(1),@(1)) },
    @{ id = 6; name = "4x1"; color = [System.Drawing.Color]::Black; matrix = @(@(1,1,1,1)) },
    @{ id = 7; name = "1x4"; color = [System.Drawing.Color]::Black; matrix = @(@(1),@(1),@(1),@(1)) },
    @{ id = 8; name = "5x1"; color = [System.Drawing.Color]::Black; matrix = @(@(1,1,1,1,1)) },
    @{ id = 9; name = "1x5"; color = [System.Drawing.Color]::Black; matrix = @(@(1),@(1),@(1),@(1),@(1)) },
    @{ id = 10; name = "L1"; color = [System.Drawing.Color]::Black; matrix = @(@(1,0),@(1,0),@(1,1)) },
    @{ id = 11; name = "L2"; color = [System.Drawing.Color]::Black; matrix = @(@(0,1),@(1,1),@(1,0)) },
    @{ id = 12; name = "L3"; color = [System.Drawing.Color]::Black; matrix = @(@(1,1),@(0,1),@(0,1)) },
    @{ id = 13; name = "L4"; color = [System.Drawing.Color]::Black; matrix = @(@(1,0),@(1,1),@(0,1)) },
    @{ id = 14; name = "T1"; color = [System.Drawing.Color]::Black; matrix = @(@(1,1,1),@(0,1,0)) },
    @{ id = 15; name = "T2"; color = [System.Drawing.Color]::Black; matrix = @(@(0,1),@(1,1),@(0,1)) },
    @{ id = 16; name = "2x2"; color = [System.Drawing.Color]::Black; matrix = @(@(1,1),@(1,1)) },
    @{ id = 17; name = "3x3"; color = [System.Drawing.Color]::Black; matrix = @(@(1,1,1),@(1,1,1),@(1,1,1)) },
    @{ id = 18; name = "Z1"; color = [System.Drawing.Color]::Black; matrix = @(@(1,1,0),@(0,1,1)) },
    @{ id = 19; name = "S1"; color = [System.Drawing.Color]::Black; matrix = @(@(0,1,1),@(1,1,0)) },
    @{ id = 20; name = "C1"; color = [System.Drawing.Color]::Black; matrix = @(@(1,1),@(1,0)) },
    @{ id = 21; name = "C2"; color = [System.Drawing.Color]::Black; matrix = @(@(1,1),@(0,1)) },
    @{ id = 22; name = "sL1"; color = [System.Drawing.Color]::Black; matrix = @(@(1,0),@(1,1)) },
    @{ id = 23; name = "sL2"; color = [System.Drawing.Color]::Black; matrix = @(@(1,1),@(1,0)) }
)

# ============================================================
# HELPER FUNCTIONS
# ============================================================
function Get-MatrixRows {
    param($Matrix)
    return $Matrix.Length
}

function Get-MatrixCols {
    param($Matrix)
    $max = 0
    for ($i = 0; $i -lt $Matrix.Length; $i++) {
        if ($Matrix[$i] -ne $null -and $Matrix[$i].Length -gt $max) {
            $max = $Matrix[$i].Length
        }
    }
    return $max
}

function CountPieceCells {
    param($Piece)
    $count = 0
    $matrix = $Piece.matrix
    for ($r = 0; $r -lt $Piece.rows; $r++) {
        $rowData = $matrix[$r]
        if ($rowData -eq $null) { continue }
        for ($c = 0; $c -lt $rowData.Length; $c++) {
            if ($rowData[$c] -eq 1) { $count++ }
        }
    }
    return $count
}

# ============================================================
# INITIALIZATION
# ============================================================
function Initialize-Game {
    $script:Score = 0
    $script:GameOver = $false
    $script:SelectedPiece = $null
    $script:PieceIndex = -1
    
    for ($x = 0; $x -lt $GridSize; $x++) {
        for ($y = 0; $y -lt $GridSize; $y++) {
            $script:Grid[$x, $y] = 0
        }
    }
    
    $script:Pieces = @()
    for ($i = 0; $i -lt 3; $i++) {
        $script:Pieces += Generate-RandomPiece
    }
}

function Generate-RandomPiece {
    $index = Get-Random -Minimum 0 -Maximum $AllPieces.Length
    $template = $AllPieces[$index]
    
    $matrix = $template.matrix
    $rows = Get-MatrixRows -Matrix $matrix
    $cols = Get-MatrixCols -Matrix $matrix
    
    return @{
        id = $template.id
        name = $template.name
        color = $template.color
        matrix = $matrix
        rows = $rows
        cols = $cols
    }
}

# ============================================================
# GAME LOGIC
# ============================================================
function CanPlacePiece {
    param($Piece, $GridX, $GridY)
    
    $matrix = $Piece.matrix
    
    for ($r = 0; $r -lt $Piece.rows; $r++) {
        $rowData = $matrix[$r]
        if ($rowData -eq $null) { continue }
        
        for ($c = 0; $c -lt $rowData.Length; $c++) {
            if ($rowData[$c] -eq 1) {
                $gx = $GridX + $c
                $gy = $GridY + $r
                
                if ($gx -lt 0 -or $gx -ge $GridSize -or $gy -lt 0 -or $gy -ge $GridSize) {
                    return $false
                }
                if ($script:Grid[$gx, $gy] -ne 0) {
                    return $false
                }
            }
        }
    }
    return $true
}

function PlacePiece {
    param($Piece, $GridX, $GridY)
    
    $matrix = $Piece.matrix
    
    for ($r = 0; $r -lt $Piece.rows; $r++) {
        $rowData = $matrix[$r]
        if ($rowData -eq $null) { continue }
        
        for ($c = 0; $c -lt $rowData.Length; $c++) {
            if ($rowData[$c] -eq 1) {
                $gx = $GridX + $c
                $gy = $GridY + $r
                $script:Grid[$gx, $gy] = 1
            }
        }
    }
    
    $cellsPlaced = CountPieceCells -Piece $Piece
    $script:Score += $cellsPlaced * $PointsPerCell
}

function CheckAndClearLines {
    $clearedRows = @()
    $clearedCols = @()
    
    for ($y = 0; $y -lt $GridSize; $y++) {
        $full = $true
        for ($x = 0; $x -lt $GridSize; $x++) {
            if ($script:Grid[$x, $y] -eq 0) { $full = $false; break }
        }
        if ($full) { $clearedRows += $y }
    }
    
    for ($x = 0; $x -lt $GridSize; $x++) {
        $full = $true
        for ($y = 0; $y -lt $GridSize; $y++) {
            if ($script:Grid[$x, $y] -eq 0) { $full = $false; break }
        }
        if ($full) { $clearedCols += $x }
    }
    
    foreach ($y in $clearedRows) {
        for ($x = 0; $x -lt $GridSize; $x++) {
            $script:Grid[$x, $y] = 0
        }
    }
    
    foreach ($x in $clearedCols) {
        for ($y = 0; $y -lt $GridSize; $y++) {
            $script:Grid[$x, $y] = 0
        }
    }
    
    $linesCleared = $clearedRows.Count + $clearedCols.Count
    
    if ($linesCleared -gt 0) {
        $basePoints = switch ($linesCleared) {
            1 { 10 }
            2 { 30 }
            3 { 60 }
            4 { 100 }
            default { $linesCleared * 25 }
        }
        
        $comboBonus = $linesCleared * ($linesCleared - 1) * $ComboMultiplier / 2
        
        $totalPoints = $basePoints + $comboBonus
        $script:Score += $totalPoints
    }
    
    return $linesCleared
}

function Get-AvailablePieces {
    $available = @()
    for ($i = 0; $i -lt $script:Pieces.Count; $i++) {
        if ($script:Pieces[$i] -ne $null) {
            $available += $script:Pieces[$i]
        }
    }
    return $available
}

function CanPlaceAnyPiece {
    $available = Get-AvailablePieces
    
    if ($available.Count -eq 0) {
        return $false
    }
    
    foreach ($piece in $available) {
        for ($x = 0; $x -lt $GridSize; $x++) {
            for ($y = 0; $y -lt $GridSize; $y++) {
                if (CanPlacePiece -Piece $piece -GridX $x -GridY $y) {
                    return $true
                }
            }
        }
    }
    return $false
}

function ShouldReplenishPieces {
    for ($i = 0; $i -lt $script:Pieces.Count; $i++) {
        if ($script:Pieces[$i] -ne $null) {
            return $false
        }
    }
    return $true
}

function ReplenishPieces {
    if (ShouldReplenishPieces) {
        $script:Pieces = @()
        for ($i = 0; $i -lt 3; $i++) {
            $script:Pieces += Generate-RandomPiece
        }
        return $true
    }
    return $false
}

function FindPieceAtPosition {
    param($MouseX, $MouseY)
    
    $pieceY = $GridPixelSize + 25
    $pieceSize = 28
    
    for ($i = 0; $i -lt $script:Pieces.Count; $i++) {
        $piece = $script:Pieces[$i]
        if ($piece -eq $null) { continue }
        
        $pieceX = 30 + ($i * 100)
        $pieceWidth = $piece.cols * $pieceSize
        $pieceHeight = $piece.rows * $pieceSize
        
        if ($MouseX -ge $pieceX -and $MouseX -lt ($pieceX + $pieceWidth) -and
            $mouseY -ge $pieceY -and $mouseY -lt ($pieceY + $pieceHeight)) {
            return @{ Piece = $piece; Index = $i; X = $pieceX; Y = $pieceY }
        }
    }
    return $null
}

# ============================================================
# FORM CREATION
# ============================================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$MainForm = New-Object System.Windows.Forms.Form
$MainForm.Text = "Block Blast"
$MainForm.Size = New-Object System.Drawing.Size($WindowWidth, $WindowHeight)
$MainForm.StartPosition = "CenterScreen"
$MainForm.FormBorderStyle = "FixedSingle"
$MainForm.MaximizeBox = $false
$MainForm.BackColor = [System.Drawing.Color]::White
$MainForm.KeyPreview = $true

$PictureBox = New-Object System.Windows.Forms.PictureBox
$PictureBox.Location = New-Object System.Drawing.Point($PanelOffsetX, $PanelOffsetY)
$PictureBox.Size = New-Object System.Drawing.Size($GridPixelSize, $TotalPanelHeight)
$PictureBox.BackColor = [System.Drawing.Color]::White
$PictureBox.Cursor = [System.Windows.Forms.Cursors]::Hand
$MainForm.Controls.Add($PictureBox)

$bitmap = New-Object System.Drawing.Bitmap($GridPixelSize, $TotalPanelHeight)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.Clear([System.Drawing.Color]::White)

$PictureBox.Image = $bitmap

# ============================================================
# RENDERING
# ============================================================
function Render-Game {
    if ($graphics -eq $null) { return }
    
    $g = $graphics
    $g.Clear([System.Drawing.Color]::White)
    
    $brushWhite = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $g.FillRectangle($brushWhite, 0, 0, $GridPixelSize, $GridPixelSize)
    
    $penLight = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(180, 180, 180), 1)
    
    for ($x = 0; $x -le $GridSize; $x++) {
        $g.DrawLine($penLight, ($x * $CellSize), 0, ($x * $CellSize), $GridPixelSize)
    }
    for ($y = 0; $y -le $GridSize; $y++) {
        $g.DrawLine($penLight, 0, ($y * $CellSize), $GridPixelSize, ($y * $CellSize))
    }
    
    $brushBlack = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black)
    $brushGray = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(180, 180, 180))
    
    for ($x = 0; $x -lt $GridSize; $x++) {
        for ($y = 0; $y -lt $GridSize; $y++) {
            if ($script:Grid[$x, $y] -eq 1) {
                $g.FillRectangle($brushBlack, ($x * $CellSize + 2), ($y * $CellSize + 2), ($CellSize - 4), ($CellSize - 4))
            } elseif ($script:Grid[$x, $y] -eq 2) {
                $g.FillRectangle($brushGray, ($x * $CellSize + 4), ($y * $CellSize + 4), ($CellSize - 8), ($CellSize - 8))
            }
        }
    }
    
    $penDark = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 2)
    $g.DrawLine($penDark, 0, $GridPixelSize, $GridPixelSize, $GridPixelSize)
    
    $pieceY = $GridPixelSize + 25
    $pieceSize = 28
    
    for ($i = 0; $i -lt $script:Pieces.Count; $i++) {
        $piece = $script:Pieces[$i]
        if ($piece -eq $null) { continue }
        
        $pieceX = 30 + ($i * 100)
        
        $matrix = $piece.matrix
        for ($r = 0; $r -lt $piece.rows; $r++) {
            $rowData = $matrix[$r]
            if ($rowData -eq $null) { continue }
            
            for ($c = 0; $c -lt $rowData.Length; $c++) {
                if ($rowData[$c] -eq 1) {
                    $px = $pieceX + $c * $pieceSize
                    $py = $pieceY + $r * $pieceSize
                    
                    if ($script:SelectedPiece -eq $piece) {
                        $g.FillRectangle($brushGray, $px, $py, ($pieceSize - 2), ($pieceSize - 2))
                    } else {
                        $g.FillRectangle($brushBlack, $px, $py, ($pieceSize - 2), ($pieceSize - 2))
                    }
                }
            }
        }
    }
    
    if ($script:SelectedPiece -ne $null) {
        $matrix = $script:SelectedPiece.matrix
        
        for ($r = 0; $r -lt $script:SelectedPiece.rows; $r++) {
            $rowData = $matrix[$r]
            if ($rowData -eq $null) { continue }
            
            for ($c = 0; $c -lt $rowData.Length; $c++) {
                if ($rowData[$c] -eq 1) {
                    $px = $script:DragX + $c * $CellSize
                    $py = $script:DragY + $r * $CellSize
                    $g.FillRectangle($brushBlack, $px, $py, ($CellSize - 2), ($CellSize - 2))
                }
            }
        }
    }
    
    $penLight.Dispose()
    $penDark.Dispose()
    $brushWhite.Dispose()
    $brushBlack.Dispose()
    $brushGray.Dispose()
    
    $PictureBox.Invalidate()
}

# ============================================================
# MOUSE EVENT HANDLERS
# ============================================================
$PictureBox.add_MouseDown({
    param($sender, $e)
    
    if ($script:GameOver) {
        Initialize-Game
        Render-Game
        return
    }
    
    $mouseX = $e.X
    $mouseY = $e.Y
    
    $hit = FindPieceAtPosition -MouseX $mouseX -MouseY $mouseY
    
    if ($hit -ne $null) {
        $script:SelectedPiece = $hit.Piece
        $script:PieceIndex = $hit.Index
        
        $script:DragOffsetX = $mouseX - $hit.X
        $script:DragOffsetY = $mouseY - $hit.Y
        
        $script:DragX = $hit.X
        $script:DragY = $hit.Y
        
        $PictureBox.Capture = $true
        Render-Game
    }
})

$PictureBox.add_MouseMove({
    param($sender, $e)
    
    if ($script:SelectedPiece -ne $null) {
        $mouseX = $e.X
        $mouseY = $e.Y
        
        $script:DragX = $mouseX - $script:DragOffsetX
        $script:DragY = $mouseY - $script:DragOffsetY
        
        if ($script:DragY -lt 0) { $script:DragY = 0 }
        if ($script:DragY -gt ($GridPixelSize + $PieceAreaHeight - $CellSize)) {
            $script:DragY = $GridPixelSize + $PieceAreaHeight - $CellSize
        }
        
        for ($x = 0; $x -lt $GridSize; $x++) {
            for ($y = 0; $y -lt $GridSize; $y++) {
                if ($script:Grid[$x, $y] -eq 2) {
                    $script:Grid[$x, $y] = 0
                }
            }
        }
        
        if ($mouseY -lt $GridPixelSize) {
            $gridX = [Math]::Floor(($mouseX - $script:DragOffsetX + ($script:SelectedPiece.cols * $CellSize) / 2) / $CellSize)
            $gridY = [Math]::Floor(($mouseY - $script:DragOffsetY + ($script:SelectedPiece.rows * $CellSize) / 2) / $CellSize)
            
            if (CanPlacePiece -Piece $script:SelectedPiece -GridX $gridX -GridY $gridY) {
                $matrix = $script:SelectedPiece.matrix
                
                for ($r = 0; $r -lt $script:SelectedPiece.rows; $r++) {
                    $rowData = $matrix[$r]
                    if ($rowData -eq $null) { continue }
                    
                    for ($c = 0; $c -lt $rowData.Length; $c++) {
                        if ($rowData[$c] -eq 1) {
                            $gx = $gridX + $c
                            $gy = $gridY + $r
                            if ($gx -ge 0 -and $gx -lt $GridSize -and $gy -ge 0 -and $gy -lt $GridSize) {
                                $script:Grid[$gx, $gy] = 2
                            }
                        }
                    }
                }
            }
        }
        
        Render-Game
    }
})

$PictureBox.add_MouseUp({
    param($sender, $e)
    
    if ($script:SelectedPiece -ne $null) {
        $mouseX = $e.X
        $mouseY = $e.Y
        
        for ($x = 0; $x -lt $GridSize; $x++) {
            for ($y = 0; $y -lt $GridSize; $y++) {
                if ($script:Grid[$x, $y] -eq 2) {
                    $script:Grid[$x, $y] = 0
                }
            }
        }
        
        if ($mouseY -lt $GridPixelSize) {
            $gridX = [Math]::Floor(($mouseX - $script:DragOffsetX + ($script:SelectedPiece.cols * $CellSize) / 2) / $CellSize)
            $gridY = [Math]::Floor(($mouseY - $script:DragOffsetY + ($script:SelectedPiece.rows * $CellSize) / 2) / $CellSize)
            
            if (CanPlacePiece -Piece $script:SelectedPiece -GridX $gridX -GridY $gridY) {
                PlacePiece -Piece $script:SelectedPiece -GridX $gridX -GridY $gridY
                $script:Pieces[$script:PieceIndex] = $null
                
                $null = CheckAndClearLines
                
                $replenished = ReplenishPieces
                
                if (-not $replenished) {
                    if (-not (CanPlaceAnyPiece)) {
                        $script:GameOver = $true
                    }
                }
            }
        }
        
        $script:SelectedPiece = $null
        $script:PieceIndex = -1
        $PictureBox.Capture = $false
        
        Render-Game
    }
})

# ============================================================
# UI LABELS
# ============================================================
$ScoreLabel = New-Object System.Windows.Forms.Label
$ScoreLabel.Location = New-Object System.Drawing.Point(0, 15)
$ScoreLabel.Size = New-Object System.Drawing.Size($WindowWidth, 35)
$ScoreLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$ScoreLabel.Text = "SCORE: 0"
$ScoreLabel.Font = New-Object System.Drawing.Font("Courier New", 18, [System.Drawing.FontStyle]::Bold)
$ScoreLabel.ForeColor = [System.Drawing.Color]::Black
$ScoreLabel.BackColor = [System.Drawing.Color]::White
$MainForm.Controls.Add($ScoreLabel)

$HelpLabel = New-Object System.Windows.Forms.Label
$HelpLabel.Location = New-Object System.Drawing.Point(20, ($WindowHeight - 30))
$HelpLabel.Size = New-Object System.Drawing.Size(($WindowWidth - 40), 20)
$HelpLabel.Text = "Drag blocks to grid | R=Restart | Clear rows/columns"
$HelpLabel.Font = New-Object System.Drawing.Font("Arial", 8)
$HelpLabel.ForeColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
$HelpLabel.BackColor = [System.Drawing.Color]::White
$MainForm.Controls.Add($HelpLabel)

# ============================================================
# GAME TIMER
# ============================================================
$GameTimer = New-Object System.Windows.Forms.Timer
$GameTimer.Interval = 100

$GameTimer.add_Tick({
    $ScoreLabel.Text = "SCORE: $script:Score"
    
    if ($script:GameOver) {
        $ScoreLabel.Text = "GAME OVER: $script:Score"
        $HelpLabel.Text = "Click to restart"
    } else {
        $HelpLabel.Text = "Drag blocks to grid | R=Restart | Clear rows/columns"
    }
})

# ============================================================
# KEYBOARD HANDLER
# ============================================================
$MainForm.add_KeyDown({
    param($sender, $e)
    
    if ($e.KeyCode -eq "R") {
        Initialize-Game
        Render-Game
    }
})

# ============================================================
# FORM CLOSING
# ============================================================
$MainForm.add_FormClosing({
    param($sender, $e)
    $global:BlockBlastRunning = $false
    if ($graphics -ne $null) { $graphics.Dispose() }
    if ($bitmap -ne $null) { $bitmap.Dispose() }
})

# ============================================================
# START GAME
# ============================================================
Initialize-Game
Render-Game
$GameTimer.Start()

[void]$MainForm.ShowDialog()
$GameTimer.Stop()
$GameTimer.Dispose()
$global:BlockBlastRunning = $false
