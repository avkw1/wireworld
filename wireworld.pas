program wireworld;

uses wwcore, GraphABC;

const
  /// Количество строк поля
  N = 600;
  /// Количество столбцов поля
  M = 800;

type
  //////////////////////////////////////////////////////////////////////////////
  /// Область просмотра поля
  Viewport = class
  public
    /// цвет фона (вокруг поля)
    static bgColor: Color := clLightGray;
    /// цвет пустой клетки
    static emptyColor: Color := RGB(0, 0, 0); // ff000000
    /// цвет проводника
    static wireColor: Color := RGB(255, 128, 0);  // ffff8000
    /// цвет сигнала
    static signalColor: Color := RGB(255, 255, 255);  // ffffffff
    /// цвет хвоста сигнала
    static signalTailColor: Color := RGB(0, 128, 255); // ff0080ff

  private
    /// название (для заголовка окна)
    name: string;
    /// данные (поле)
    data: Field;
    /// горизонтальная координата поля
    x0: integer;
    /// вертикальная координата поля
    y0: integer;
    /// ширина
    width: integer;
    /// высота
    height: integer;
    /// размер клетки
    cellSize: integer := 1;

  public
    /// ширина поля в пикселях
    property fieldWidth: integer read data.nCols * cellSize;
    /// высота поля в пикселях
    property fieldHeight: integer read data.nRows * cellSize;

    /// вернуть цвет для состояния клетки
    static function cellStateToColor(cs: CellState): Color;
    begin
      case cs of
        empty: result := emptyColor;
        wire: result := wireColor;
        signal: result := signalColor;
        signalTail: result := signalTailColor;
      end;
    end;

    /// вернуть состояние клетки для цвета
    static function colorToCellState(c: Color): CellState;
    begin
      result := empty;
      if c = wireColor then
        result := wire
      else if c = signalColor then
        result := signal
      else if c = signalTailColor then
        result := signalTail;
    end;

    constructor Create(name: string := 'Wireworld');
    begin
      self.name := name;
      width := window.Width;
      height := window.Height;
      data := new Field(height, width);
    end;

    /// установить заголовок окна
    procedure setWindowTitle;
    begin
      window.Title := name + ' [Поколение ' + data.genNumber + ']';
    end;

    /// нарисовать клетку по координатам
    procedure drawCell(i, j, x, y: integer);
    begin
      SetBrushColor(cellStateToColor(data.getCellState(i, j)));
      FillRectangle(x, y, x + cellSize, y + cellSize);
    end;

    /// нарисовать клетку, вычислив координаты
    procedure drawCell(i, j: integer);
    begin
      var x := x0 + j * cellSize;
      var y := y0 + i * cellSize;
      drawCell(i, j, x, y);
    end;

    /// нарисовать
    procedure draw;
    begin
      setWindowTitle;
      LockDrawing;
      // если окно больше поля, то нарисовать фон
      if (fieldHeight < height) or (fieldWidth < width) then
        clearWindow(bgColor);
      // расчёт индексов для рисования только клеток, попадающих в окно
      var iBegin := floor((-y0) / cellSize);
      var jBegin := floor((-x0) / cellSize);
      var iEnd := min(ceil((height - y0) / cellSize) - 1, data.nRows - 1);
      var jEnd := min(ceil((width - x0) / cellSize) - 1, data.nCols - 1);
      var y := y0 + iBegin * cellSize;
      for var i := iBegin to iEnd do
      begin
        var x := x0 + jBegin * cellSize;
        for var j := jBegin to jEnd do
        begin
          // сбросить флаг изменения
          data.cellStateChanged(i, j);
          // нарисовать клетку
          drawCell(i, j, x, y);
          x += cellSize;
        end;
        y += cellSize;
      end;
      UnlockDrawing;
    end;

    /// нарисовать только изменившиеся клетки
    procedure drawChanged;
    begin
      setWindowTitle;
      LockDrawing;
      // расчёт индексов для рисования только клеток, попадающих в окно
      var iBegin := floor((-y0) / cellSize);
      var jBegin := floor((-x0) / cellSize);
      var iEnd := min(ceil((height - y0) / cellSize) - 1, data.nRows - 1);
      var jEnd := min(ceil((width - x0) / cellSize) - 1, data.nCols - 1);
      for var i := iBegin to iEnd do
        for var j := jBegin to jEnd do
          // флаг изменения сбрасывается после чтения
          if data.cellStateChanged(i, j) then
            // нарисовать клетку, если она изменилась
            drawCell(i, j);
      UnlockDrawing;
    end;

    /// один шаг (одно поколение)
    procedure nextGeneration(draw: boolean := true);
    begin
      data.nextGeneration;
      if draw then
        drawChanged;
    end;

    /// очистить поле (все клетки пустые)
    procedure clear;
    begin
      data.clear;
      draw
    end;

    /// очистить сигналы
    procedure clearSignals;
    begin
      data.clearSignals;
      draw
    end;

    /// загрузить изображение
    procedure loadPicture(fname: string);
    begin
      var p: Picture := new Picture(fname);
      if (p.Height = data.nRows) and (p.Width = data.nCols) then
      begin
        data.clearGenNumber;
        for var i := 0 to data.nRows - 1 do
          for var j := 0 to data.nCols - 1 do
            data.setCellState(i, j, colorToCellState(p.GetPixel(j, i)));
        draw;
      end;
    end;

    /// исправить положение поля (x0, y0)
    procedure fixPosition;
    begin
      if x0 < (width - fieldWidth) then
        x0 := width - fieldWidth;
      if x0 > 0 then
        x0 := 0;
      if y0 < (height - fieldHeight) then
        y0 := height - fieldHeight;
      if y0 > 0 then
        y0 := 0;
    end;

    /// вернуть размер клетки (масштаб)
    function getCellSize: integer;
    begin
      result := cellSize;
    end;

    /// установить исходный масштаб (размер клетки 1) и положение (0, 0)
    procedure scaleTo1;
    begin
      var sizeChanged := (width <> data.nCols) or (height <> data.nRows);
      if (cellSize <> 1) or (x0 <> 0) or (y0 <> 0) or sizeChanged then
      begin
        cellSize := 1;
        x0 := 0;
        y0 := 0;
        // если размер окна изменён
        if sizeChanged then
        begin
          // восстановить размер окна
          window.Normalize;
          window.SetSize(data.nCols, data.nRows); // будет вызван resize -> draw
        end
        else
          draw;
      end;
    end;

    /// увеличить масштаб
    procedure scaleUp;
    begin
      if cellSize < 32 then
      begin
        cellSize := cellSize shl 1;
        x0 := x0 shl 1;
        y0 := y0 shl 1;
        draw;
      end;
    end;

    /// уменьшить масштаб
    procedure scaleDown;
    begin
      if cellSize > 1 then
      begin
        cellSize := cellSize shr 1;
        x0 := x0 shr 1;
        y0 := y0 shr 1;
        fixPosition;
        draw;
      end;
    end;

    /// сдвиг изображения
    procedure move(dx, dy: integer);
    begin
      var xOld := x0;
      var yOld := y0;
      x0 += dx;
      y0 += dy;
      fixPosition;
      if (xOld <> x0) or (yOld <> y0) then
        draw;
    end;

    /// обработчик мышки
    procedure mouseDown(x, y, mb: integer);
    begin
      var i := (y - y0) div CellSize;
      var j := (x - x0) div CellSize;
      if (i >= data.nRows) or (j >= data.nCols) then
        exit;
      case mb of
        1: data.incCellState(i, j);
        2: data.decCellState(i, j);
      end;
      drawCell(i, j);
    end;

    /// обработчик изменения размера окна
    procedure resize;
    begin
      width := window.Width;
      height := window.Height;
      fixPosition;
      draw
    end;

  end;

  //////////////////////////////////////////////////////////////////////////////
  /// Управляющий класс
  Control = class
  private
    /// область просмотра игрового поля
    vp: Viewport;
    /// шаг перемещения при сдвиге (кол-во клеток)
    moveStep: integer := 10;
    /// флаг остановки
    stop: boolean := true;
    /// имя файла с картинкой
    wwFileName := 'ww800x600.gif';
    /// быстрый режим (эксперимент)
    fastMode: boolean := false;
    /// количество шагов без перерисовки для быстрого режима
    fastModeSteps: integer := 100;

  public
    constructor Create;
    begin
      vp := new Viewport;
      vp.loadPicture(wwFileName);
    end;

    /// запуск игры
    procedure play;
    begin
      if stop then
      begin
        stop := false;
        repeat
          if fastMode then
          begin // быстрый режим
            loop fastModeSteps - 1 do
              vp.nextGeneration(false);
            vp.nextGeneration;
          end
          else // обычный режим
            vp.nextGeneration;
          System.Windows.Forms.Application.DoEvents;
        until stop;
      end
      else
        stop := true;
    end;

    /// обработчик мышки
    procedure mouseDown(x, y, mb: integer);
    begin
      if stop then
        vp.mouseDown(x, y, mb);
    end;

    /// обработчик клавиатуры
    procedure keyDown(k: integer);
    begin
      case k of
        VK_Space: play;
        VK_PageUp: vp.scaleUp;
        VK_PageDown: vp.scaleDown;
        VK_Up: vp.move(0, vp.getCellSize * moveStep);
        VK_Down: vp.move(0, vp.getCellSize * -moveStep);
        VK_Left: vp.move(vp.getCellSize * moveStep, 0);
        VK_Right: vp.move(vp.getCellSize * -moveStep, 0);
        VK_Home: vp.scaleTo1;
      end;
      if stop then
        case k of
          VK_Enter: vp.nextGeneration;
          VK_Delete: vp.clear;
          VK_Back: vp.clearSignals;
          VK_Insert: vp.loadPicture(wwFileName);
        end
    end;

    /// обработчик изменения размера окна
    procedure resize;
    begin
      vp.resize;
    end;

  end;

////////////////////////////////////////////////////////////////////////////////
var
  // объект - управление игрой
  ctrl: Control;

// Обработчик мышки
procedure mouseDown(x, y, mb: integer);
begin
  ctrl.mouseDown(x, y, mb);
end;

// Обработчик клавиатуры
procedure keyDown(k: integer);
begin
  ctrl.keyDown(k);
end;

// Обработчик изменения размера окна
procedure resize;
begin
  ctrl.resize;
end;

// Основная процедура
begin
  SetSmoothingOff;
  window.SetSize(M, N);
  window.CenterOnScreen;
  ctrl := new Control;
  OnMouseDown := mouseDown;
  OnKeyDown := keyDown;
  OnResize := resize;
end.
