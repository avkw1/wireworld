program wireworld;

uses GraphABC;

const
  /// Количество строк поля
  N = 600;
  /// Количество столбцов поля
  M = 800;
  /// Имя файла
  wwFileName = 'ww800x600.gif';
  /// Быстрый режим (эксперимент)
  fastMode = false;
  /// Количество шагов без перерисовки для быстрого режима
  fastModeSteps = 100;

type
  /// Состояние клетки (перечислимый тип)
  CellState = (
    empty,      /// пустая клетка
    wire,       /// проводник
    signal,     /// сигнал
    signal_tail /// "хвост" сигнала
  );

  /// Клетка -------------------------------------------------------------------
  Cell = class
  private
    /// состояние
    state: CellState;
    /// новое состояние
    newState: CellState;
    /// флаг изменения состояния
    changed: boolean;
    /// соседи
    neighbors: array [1..8] of Cell;

  public
    /// вернуть состояние
    function getState: CellState;
    begin
      result := state
    end;

    /// установить состояние
    procedure setState(cs: CellState);
    begin
      state := cs;
      newState := cs;
    end;

    /// связать с соседями
    procedure setNeighbors(n1, n2, n3, n4, n5, n6, n7, n8: Cell);
    begin
      neighbors[1] := n1;
      neighbors[2] := n2;
      neighbors[3] := n3;
      neighbors[4] := n4;
      neighbors[5] := n5;
      neighbors[6] := n6;
      neighbors[7] := n7;
      neighbors[8] := n8;
    end;

    /// "инкремент" состояния
    procedure incState;
    begin
      case state of
        empty: state := wire;
        wire: state := signal;
        signal: state := signal_tail;
        signal_tail: state := empty;
      end;
      newState := state;
    end;

    /// "декремент" состояния
    procedure decState;
    begin
      case state of
        empty: state := signal_tail;
        wire: state := empty;
        signal: state := wire;
        signal_tail: state := signal;
      end;
      newState := state;
    end;

    /// очистить сигналы
    procedure clearSignals;
    begin
      if (state = signal) or (state = signal_tail) then
        setState(wire);
    end;

    /// вычислить новое состояние
    procedure calcNewState;
    begin
      if state = empty then
        exit;
      case state of
        wire:
          begin
            var count := 0;
            for var i := 1 to high(neighbors) do
              if neighbors[i].state = signal then
                inc(count);
            if (count = 1) or (count = 2) then
              newState := signal;
          end;
        signal: newState := signal_tail;
        signal_tail: newState := wire;
      end;
    end;

    /// применить новое состояние
    procedure applyNewState;
    begin
      if state <> newState then
      begin
        state := newState;
        changed := true;
      end;
    end;

    /// состояние изменилось? (возвращает и сбрасывает флаг)
    function stateChanged: boolean;
    begin
      result := changed;
      changed := false;
    end;

  end;

  /// Игровое поле -------------------------------------------------------------
  Field = class
  private
    /// клетки поля
    cells: array [1..N, 1..M] of Cell;
    /// номер поколения
    genNumber: cardinal;

  public
    constructor Create;
    begin
      // создание клеток
      for var i := 1 to N do
        for var j := 1 to M do
          cells[i, j] := new Cell;
      // связывание с соседями
      for var i := 1 to N do
      begin
        var i1 := i - 1;
        if i1 = 0 then
          i1 := N;
        var i2 := i + 1;
        if i2 = N + 1 then
          i2 := 1;
        for var j := 1 to M do
        begin
          var j1 := j - 1;
          if j1 = 0 then
            j1 := M;
          var j2 := j + 1;
          if j2 = M + 1 then
            j2 := 1;
          cells[i, j].setNeighbors(
            cells[i1, j], cells[i1, j2], cells[i, j2], cells[i2, j2],
            cells[i2, j], cells[i2, j1], cells[i, j1], cells[i1, j1]);
        end;
      end;
    end;

    /// вернуть состояние клетки
    function getCellState(i, j: integer): CellState;
    begin
      result := cells[i, j].getState;
    end;

    /// установить состояние клетки
    procedure setCellState(i, j: integer; cs: CellState);
    begin
      cells[i, j].setState(cs);
    end;

    /// "инкремент" состояния клетки
    procedure incCellState(i, j: integer);
    begin
      cells[i, j].incState;
    end;

    /// "декремент" состояния клетки
    procedure decCellState(i, j: integer);
    begin
      cells[i, j].decState;
    end;

    /// вернуть номер поколения
    function getGenNumber: cardinal;
    begin
      result := genNumber;
    end;

    /// обнулить номер поколения
    procedure clearGenNumber;
    begin
      genNumber := 0;
    end;

    /// состояние клетки изменилось?
    function cellStateChanged(i, j: integer): boolean;
    begin
      result := cells[i, j].stateChanged;
    end;

    /// переход к следующему шагу
    procedure nextStep();
    begin
      for var i := 1 to N do
        for var j := 1 to M do
          cells[i, j].calcNewState;
      inc(genNumber);
      for var i := 1 to N do
        for var j := 1 to M do
          cells[i, j].applyNewState;
    end;

    /// очистить (все клетки пустые)
    procedure clear;
    begin
      genNumber := 0;
      for var i := 1 to N do
        for var j := 1 to M do
          cells[i, j].setState(empty);
    end;

    /// очистить сигналы
    procedure clearSignals;
    begin
      genNumber := 0;
      for var i := 1 to N do
        for var j := 1 to M do
          cells[i, j].clearSignals;
    end;

  end;

  /// Область просмотра поля ---------------------------------------------------
  FieldViewport = class
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
    /// шаг перемещения при сдвиге (кол-во клеток)
    moveStep: integer := 10;
    /// флаг остановки
    stop: boolean := true;

  public
    /// вернуть цвет для состояния клетки
    static function cellStateToColor(cs: CellState): Color;
    begin
      case cs of
        empty: result := emptyColor;
        wire: result := wireColor;
        signal: result := signalColor;
        signal_tail: result := signalTailColor;
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
        result := signal_tail;
    end;

    constructor Create(name: string := 'Wireworld');
    begin
      self.name := name;
      data := new Field;
      width := window.Width;
      height := window.Height;
    end;

    /// установить заголовок окна
    procedure setWindowTitle;
    begin
      window.Title := name + ' [Поколение ' + data.getGenNumber + ']';
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
      var x := x0 + (j - 1) * cellSize;
      var y := y0 + (i - 1) * cellSize;
      drawCell(i, j, x, y);
    end;

    /// вернуть ширину поля в пикселях
    function fieldWidth: integer;
    begin
      result := M * cellSize;
    end;

    /// вернуть высоту поля в пикселях
    function fieldHeight: integer;
    begin
      result := N * cellSize;
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
      var iBegin := floor((-y0) / cellSize) + 1;
      var jBegin := floor((-x0) / cellSize) + 1;
      var iEnd := min(ceil((height - y0) / cellSize), N);
      var jEnd := min(ceil((width - x0) / cellSize), M);
      var y := y0 + (iBegin - 1) * cellSize;
      for var i := iBegin to iEnd do
      begin
        var x := x0 + (jBegin - 1) * cellSize;
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
      var iBegin := floor((-y0) / cellSize) + 1;
      var jBegin := floor((-x0) / cellSize) + 1;
      var iEnd := min(ceil((height - y0) / cellSize), N);
      var jEnd := min(ceil((width - x0) / cellSize), M);
      for var i := iBegin to iEnd do
        for var j := jBegin to jEnd do
          // флаг изменения сбрасывается после чтения
          if data.cellStateChanged(i, j) then
            // нарисовать клетку, если она изменилась
            drawCell(i, j);
      UnlockDrawing;
    end;

    /// один шаг (одно поколение)
    procedure nextStep;
    begin
      data.nextStep;
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
      if (p.Height = N) and (p.Width = M) then
      begin
        data.clearGenNumber;
        for var i := 1 to N do
          for var j := 1 to M do
            data.setCellState(i, j, colorToCellState(p.GetPixel(j - 1, i - 1)));
        draw;
      end;
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
            loop fastModeSteps do
              data.nextStep;
            drawChanged;
          end
          else // обычный режим
            nextStep;
          System.Windows.Forms.Application.DoEvents;
        until stop;
      end
      else
        stop := true;
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

    /// установить исходный масштаб (размер клетки 1) и положение (0, 0)
    procedure scaleTo1;
    begin
      if (cellSize <> 1) or (x0 <> 0) or (y0 <> 0) then
      begin
        cellSize := 1;
        x0 := 0;
        y0 := 0;
        draw;
      end;
    end;

    /// увеличить масштаб
    procedure scaleUp;
    begin
      if cellSize < 64 then
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
      if stop then
      begin
        var i := (y - y0) div CellSize + 1;
        var j := (x - x0) div CellSize + 1;
        if (i > N) or (j > M) then
          exit;
        case mb of
          1: data.incCellState(i, j);
          2: data.decCellState(i, j);
        end;
        drawCell(i, j);
      end;
    end;

    /// обработчик клавиатуры
    procedure keyDown(k: integer);
    begin
      case k of
        VK_Space: play;
        VK_PageUp: scaleUp;
        VK_PageDown: scaleDown;
        VK_Up: move(0, cellSize * moveStep);
        VK_Down: move(0, -cellSize * moveStep);
        VK_Left: move(cellSize * moveStep, 0);
        VK_Right: move(-cellSize * moveStep, 0);
        VK_Home: scaleTo1;
      end;
      if stop then
        case k of
          VK_Enter: nextStep;
          VK_Delete: clear;
          VK_Back: clearSignals;
          VK_Insert: loadPicture(wwFileName);
        end
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

var
  // объект - область просмотра игрового поля
  view: FieldViewport;

// Обработчик мышки
procedure mouseDown(x, y, mb: integer);
begin
  view.mouseDown(x, y, mb);
end;

// Обработчик клавиатуры
procedure keyDown(k: integer);
begin
  view.keyDown(k);
end;

// Обработчик изменения размера окна
procedure resize;
begin
  view.resize;
end;

// Основная процедура
begin
  SetSmoothingOff;
  window.SetSize(M, N);
  window.CenterOnScreen;
  view := new FieldViewport;
  view.loadPicture(wwFileName);
  OnMouseDown := mouseDown;
  OnKeyDown := keyDown;
  OnResize := resize;
end.
