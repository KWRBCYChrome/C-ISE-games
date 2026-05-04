function Start-Tetris {
    # -------------------------------------------------------------
    # SETTINGS
    # -------------------------------------------------------------
    $cellSize   = 25                     # DON’T MESS WITH THIS / the size of a tile in pixels
    $boardWidth = 10                      # number of columns
    $boardHeight= 20                      # number of rows

    $totalWidth  = $boardWidth * $cellSize
    $totalHeight = $boardHeight * $cellSize

    # -------------------------------------------------------------
    # LOAD ASSEMBLIES
    # -------------------------------------------------------------
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

    # -------------------------------------------------------------
    # TETROMINO DEFINITIONS
    # -------------------------------------------------------------
    $shapes = @(
        @{ id = 1; name = "I"; color = [System.Drawing.Color]::Cyan;
           matrix = @(@(0,0,0,0),@(1,1,1,1),@(0,0,0,0),@(0,0,0,0)) },
        @{ id = 2; name = "O"; color = [System.Drawing.Color]::Yellow;
           matrix = @(@(0,0,0,0),@(0,1,1,0),@(0,1,1,0),@(0,0,0,0)) },
        @{ id = 3; name = "T"; color = [System.Drawing.Color]::Magenta;
           matrix = @(@(0,0,0,0),@(1,1,1,0),@(0,1,0,0),@(0,0,0,0)) },
        @{ id = 4; name = "S"; color = [System.Drawing.Color]::Lime;
           matrix = @(@(0,0,0,0),@(0,1,1,0),@(1,1,0,0),@(0,0,0,0)) },
        @{ id = 5; name = "Z"; color = [System.Drawing.Color]::Red;
           matrix = @(@(0,0,0,0),@(1,1,0,0),@(0,1,1,0),@(0,0,0,0)) },
        @{ id = 6; name = "J"; color = [System.Drawing.Color]::Blue;
           matrix = @(@(0,0,0,0),@(1,1,1,0),@(0,0,1,0),@(0,0,0,0)) },
        @{ id = 7; name = "L"; color = [System.Drawing.Color]::Orange;
           matrix = @(@(0,0,0,0),@(1,1,1,0),@(1,0,0,0),@(0,0,0,0)) }
    )

    $brushes = @()
    foreach ($s in $shapes) {
        $brushes += ,(New-Object System.Drawing.SolidBrush($s.color))
    }

    # -------------------------------------------------------------
    # GAME STATE
    # -------------------------------------------------------------
    $state = @{
        board        = $null
        currentShape = $null
        currentId    = $null
        currentX     = $null
        currentY     = $null
        moveX        = 0
        rotate       = $false
        softDrop     = $false
        hardDrop     = $false
        score        = 0
        lines        = 0
        gameOver     = $false
        paused       = $false
        timer        = $null
        canvas       = $null
        form         = $null
        rand         = New-Object System.Random
    }

    # -------------------------------------------------------------
    # HELPER FUNCTIONS
    # -------------------------------------------------------------

    function Rotate-Shape {
        param([array]$shape)
        $size = $shape.Length
        $new  = @()
        for($i=0;$i -lt $size;$i++) {
            $row = @()
            for($j=$size-1;$j -ge 0;$j--) {
                $row += $shape[$j][$i]
            }
            $new += ,$row
        }
        return $new
    }

    function Test-Placement {
        param([array]$shape,[int]$x,[int]$y)
        $size = $shape.Length
        for($r=0;$r -lt $size;$r++) {
            for($c=0;$c -lt $size;$c++) {
                if($shape[$r][$c] -eq 1) {
                    $cx = $x + $c
                    $cy = $y + $r
                    if($cx -lt 0 -or $cx -ge $boardWidth -or $cy -ge $boardHeight) {
                        return $false
                    }
                    if($cy -ge 0 -and $state.board[$cy][$cx] -ne 0) { return $false }
                }
            }
        }
        return $true
    }

    function Place-Shape {
        param([array]$shape,[int]$x,[int]$y,[int]$id)
        $size = $shape.Length
        for($r=0;$r -lt $size;$r++) {
            for($c=0;$c -lt $size;$c++) {
                if($shape[$r][$c] -eq 1) {
                    $cx = $x + $c
                    $cy = $y + $r
                    if($cx -ge 0 -and $cx -lt $boardWidth -and $cy -ge 0 -and $cy -lt $boardHeight) {
                        $state.board[$cy][$cx] = $id
                    }
                }
            }
        }
    }

    function Clear-FullLines {
        $removed = 0
        for($row=$boardHeight-1;$row -ge 0;$row--) {
            $full = $true
            for($col=0;$col -lt $boardWidth;$col++) {
                if($state.board[$row][$col] -eq 0) { $full = $false; break }
            }
            if($full) {
                for($r=$row;$r -gt 0;$r--) {
                    for($c=0;$c -lt $boardWidth;$c++) {
                        $state.board[$r][$c] = $state.board[$r-1][$c]
                    }
                }
                $state.board[0] = New-Object 'int[]' $boardWidth
                $removed++
                $row++
            }
        }

        if($removed -gt 0) {
            # scoring: 100, 300, 500, 700 for 1-4 lines
            $state.score += ($removed * 100 + ($removed - 1) * 100)
            $state.lines += $removed
        }
    }

    function New-Piece {
        $idx   = $state.rand.Next(0,$shapes.Count)
        $piece = $shapes[$idx]

        $state.currentShape = $piece.matrix
        $state.currentId    = $piece.id
        $state.currentX = [int]($boardWidth/2) - 2
        $state.currentY = 0

        if(-not (Test-Placement $state.currentShape $state.currentX $state.currentY)) {
            $state.gameOver = $true
            $state.timer.Stop()
            $msg = "GAME OVER`n`nScore: $($state.score)`nLines: $($state.lines)`n`nPlay again?"
            $ans = [System.Windows.Forms.MessageBox]::Show($msg,"Tetris","YesNo","Information")
            if($ans -eq "Yes") { Reset-Game } else { $state.form.Close() }
        }
    }

    function Reset-Game {
        $state.board = @()
        for($r=0;$r -lt $boardHeight;$r++) {
            $state.board += ,(New-Object 'int[]' $boardWidth)
        }

        $state.score      = 0
        $state.lines      = 0
        $state.moveX      = 0
        $state.rotate     = $false
        $state.softDrop   = $false
        $state.hardDrop   = $false
        $state.gameOver   = $false
        $state.paused     = $false

        $state.timer.Interval = 500
        New-Piece
        $state.timer.Start()
    }

    function Draw-Game {
        if ($state.canvas) { $state.canvas.Refresh() }
    }

    # -------------------------------------------------------------
    # BUILD THE WINFORMS UI
    # -------------------------------------------------------------

    $form = New-Object System.Windows.Forms.Form
    $form.Text        = "PowerShell Tetris"
    $form.BackColor   = [System.Drawing.Color]::Black
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $state.form = $form

    $uiPanelWidth = 160
    $form.ClientSize = New-Object System.Drawing.Size ($totalWidth + $uiPanelWidth), ($totalHeight + 40)

    $form.KeyPreview  = $true

    $canvas = New-Object System.Windows.Forms.PictureBox
    $canvas.Location = New-Object System.Drawing.Point 0, 0
    $canvas.Size = New-Object System.Drawing.Size $totalWidth, $totalHeight
    $form.Controls.Add($canvas)
    $state.canvas = $canvas

    # score panel
    $scorePanel = New-Object System.Windows.Forms.Panel
    $scorePanel.Location = New-Object System.Drawing.Point $totalWidth, 0
    $scorePanel.Size = New-Object System.Drawing.Size $uiPanelWidth, $totalHeight
    $scorePanel.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $form.Controls.Add($scorePanel)

    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Location = New-Object System.Drawing.Point 10, 10
    $titleLabel.Size = New-Object System.Drawing.Size 140, 25
    $titleLabel.Text = "TETRIS"
    $titleLabel.ForeColor = [System.Drawing.Color]::Cyan
    $titleLabel.Font = New-Object System.Drawing.Font("Arial", 16, [System.Drawing.FontStyle]::Bold)
    $titleLabel.TextAlign = "MiddleCenter"
    $scorePanel.Controls.Add($titleLabel)

    $scoreLabel = New-Object System.Windows.Forms.Label
    $scoreLabel.Location = New-Object System.Drawing.Point 10, 50
    $scoreLabel.Size = New-Object System.Drawing.Size 140, 20
    $scoreLabel.Text = "SCORE"
    $scoreLabel.ForeColor = [System.Drawing.Color]::Gray
    $scoreLabel.Font = New-Object System.Drawing.Font("Arial", 9)
    $scorePanel.Controls.Add($scoreLabel)

    $scoreValue = New-Object System.Windows.Forms.Label
    $scoreValue.Location = New-Object System.Drawing.Point 10, 70
    $scoreValue.Size = New-Object System.Drawing.Size 140, 30
    $scoreValue.Text = "0"
    $scoreValue.ForeColor = [System.Drawing.Color]::Yellow
    $scoreValue.Font = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.FontStyle]::Bold)
    $scorePanel.Controls.Add($scoreValue)

    $linesLabel = New-Object System.Windows.Forms.Label
    $linesLabel.Location = New-Object System.Drawing.Point 10, 110
    $linesLabel.Size = New-Object System.Drawing.Size 140, 20
    $linesLabel.Text = "LINES"
    $linesLabel.ForeColor = [System.Drawing.Color]::Gray
    $linesLabel.Font = New-Object System.Drawing.Font("Arial", 9)
    $scorePanel.Controls.Add($linesLabel)

    $linesValue = New-Object System.Windows.Forms.Label
    $linesValue.Location = New-Object System.Drawing.Point 10, 130
    $linesValue.Size = New-Object System.Drawing.Size 140, 30
    $linesValue.Text = "0"
    $linesValue.ForeColor = [System.Drawing.Color]::Lime
    $linesValue.Font = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.FontStyle]::Bold)
    $scorePanel.Controls.Add($linesValue)

    $controlsLabel = New-Object System.Windows.Forms.Label
    $controlsLabel.Location = New-Object System.Drawing.Point 10, 190
    $controlsLabel.Size = New-Object System.Drawing.Size 140, 120
    $controlsLabel.Text = "CONTROLS`n`n↔  Move`n↑ Rotate`n↓ Soft Drop`n— Hard Drop`nP Pause"
    $controlsLabel.ForeColor = [System.Drawing.Color]::Gray
    $controlsLabel.Font = New-Object System.Drawing.Font("Arial", 9)
    $scorePanel.Controls.Add($controlsLabel)

    $pauseLabel = New-Object System.Windows.Forms.Label
    $pauseLabel.Location = New-Object System.Drawing.Point 10, ($totalHeight / 2 - 30)
    $pauseLabel.Size = New-Object System.Drawing.Size 140, 60
    $pauseLabel.Text = "PAUSED`n`nPress P to resume"
    $pauseLabel.ForeColor = [System.Drawing.Color]::White
    $pauseLabel.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
    $pauseLabel.TextAlign = "MiddleCenter"
    $pauseLabel.Visible = $false
    $pauseLabel.BackColor = [System.Drawing.Color]::FromArgb(180, 0, 0, 0)
    $scorePanel.Controls.Add($pauseLabel)

    # -------------------------------------------------------------
    # KEY HANDLING
    # -------------------------------------------------------------
    $form.add_KeyDown({
        param($s,$e)
        if ($state.gameOver) { return }
        
        switch($e.KeyCode){
            "Left"   { $state.moveX = -1 }
            "Right"  { $state.moveX =  1 }
            "Up"     { $state.rotate = $true }
            "Down"   { $state.softDrop = $true }
            "Space"  { $state.hardDrop = $true }
            "P"      { 
                $state.paused = -not $state.paused
                $pauseLabel.Visible = $state.paused
                if ($state.paused) { $state.timer.Stop() } else { $state.timer.Start() }
            }
            "Escape" { $form.Close() }
        }
    })

    # -------------------------------------------------------------
    # TIMER
    # -------------------------------------------------------------
    $timer = New-Object System.Windows.Forms.Timer
    $state.timer = $timer

    $timer.add_Tick({
        if ($state.paused -or $state.gameOver) { return }
        
        # rotation
        if($state.rotate){
            $rot = Rotate-Shape $state.currentShape
            if(Test-Placement $rot $state.currentX $state.currentY){
                $state.currentShape = $rot
            }
            $state.rotate = $false
        }
        
        # horizontal movement
        if($state.moveX -ne 0){
            $newX = $state.currentX + $state.moveX
            if(Test-Placement $state.currentShape $newX $state.currentY){
                $state.currentX = $newX
            }
            $state.moveX = 0
        }
        
        # hard drop
        if($state.hardDrop){
            while(Test-Placement $state.currentShape $state.currentX ($state.currentY+1)){
                $state.currentY++
                $state.score += 2
            }
            Place-Shape $state.currentShape $state.currentX $state.currentY $state.currentId
            Clear-FullLines
            New-Piece
            $state.hardDrop = $false
            Draw-Game
            return
        }
        
        # drop distance (soft drop = 2x speed)
        $steps = 1
        if($state.softDrop){
            $steps = 2
            $state.softDrop = $false
        }
        
        $canFall = $true
        for($i=0;$i -lt $steps;$i++){
            if(Test-Placement $state.currentShape $state.currentX ($state.currentY+1)){
                $state.currentY++
                if ($steps -gt 1) { $state.score += 1 }
            }else{
                $canFall = $false
                break
            }
        }
        
        if(-not $canFall){
            Place-Shape $state.currentShape $state.currentX $state.currentY $state.currentId
            Clear-FullLines
            New-Piece
        }
        
        Draw-Game
    })

    # -------------------------------------------------------------
    # PAINT
    # -------------------------------------------------------------
    $canvas.add_Paint({
        param($s,$e)
        $g = $e.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::SystemDefault
        
        $g.Clear([System.Drawing.Color]::FromArgb(40, 40, 40))
        
        for($y=0;$y -lt $boardHeight;$y++){
            for($x=0;$x -lt $boardWidth;$x++){
                $id = $state.board[$y][$x]
                if($id -gt 0){
                    $brush = $brushes[$id-1]
                    $g.FillRectangle($brush,
                                     ($x * $cellSize) + 1,
                                     ($y * $cellSize) + 1,
                                     $cellSize - 2,
                                     $cellSize - 2)
                }
            }
        }
        
        if($null -ne $state.currentShape){
            $brush = $brushes[$state.currentId-1]
            $size  = $state.currentShape.Length
            for($r=0;$r -lt $size;$r++){
                for($c=0;$c -lt $size;$c++){
                    if($state.currentShape[$r][$c] -eq 1){
                        $bx = $state.currentX + $c
                        $by = $state.currentY + $r
                        if($bx -ge 0 -and $bx -lt $boardWidth -and $by -ge 0 -and $by -lt $boardHeight){
                            $g.FillRectangle($brush,
                                             ($bx * $cellSize) + 1,
                                             ($by * $cellSize) + 1,
                                             $cellSize - 2,
                                             $cellSize - 2)
                            
                            # highlight effect
                            $highlightBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(100, 255, 255, 255))
                            $g.FillRectangle($highlightBrush,
                                             ($bx * $cellSize) + 1,
                                             ($by * $cellSize) + 1,
                                             $cellSize - 2,
                                             4)
                            $highlightBrush.Dispose()
                        }
                    }
                }
            }
        }
        
        $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(20,255,255,255))
        for($i=0;$i -le $boardWidth;$i++){
            $g.DrawLine($pen, ($i*$cellSize), 0, ($i*$cellSize), $totalHeight)
        }
        for($i=0;$i -le $boardHeight;$i++){
            $g.DrawLine($pen, 0, ($i*$cellSize), $totalWidth, ($i*$cellSize))
        }
        $pen.Dispose()
        
        $scoreValue.Text = $state.score.ToString()
        $linesValue.Text = $state.lines.ToString()
    })

    # -------------------------------------------------------------
    # START THE GAME
    # -------------------------------------------------------------
    $form.add_Load({ Reset-Game })
    $form.ShowDialog()
    $form.Dispose()
}

Start-Tetris



