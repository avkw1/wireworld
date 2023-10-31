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
              newState := signal
            else
              newState := wire;
          end;
        signal: newState := signal_tail;
        signal_tail: newState := wire;
      end;
    end;

    /// состояние изменилось?
    function stateChanged: boolean;
    begin
      result := state <> newState
    end;

    /// установить новое состояние
    procedure setNewState;
    begin
      state := newState
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

    /// вычислить новое состояние
    procedure calcNewState;
    begin
      for var i := 1 to N do
        for var j := 1 to M do
          cells[i, j].calcNewState;
      // инкремент номера поколения
      inc(genNumber);
    end;

    /// состояние клетки изменилось?
    function cellStateChanged(i, j: integer): boolean;
    begin
      result := cells[i, j].stateChanged;
    end;

    /// установить новое состояние для клетки
    procedure setCellNewState(i, j: integer);
    begin
      cells[i, j].setNewState;
    end;

    /// переход к следующему шагу
    procedure nextStep();
    begin
      calcNewState;
      for var i := 1 to N do
        for var j := 1 to M do
          setCellNewState(i, j);
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

    /// загрузить изображение
    procedure loadPicture(fname: string);
    begin
      var p: Picture := new Picture(fname);
      if (p.Height = N) and (p.Width = M) then
      begin
        genNumber := 0;
        for var i := 1 to N do
          for var j := 1 to M do
          begin
            var cs: CellState;
            var name := p.GetPixel(j - 1, i - 1).Name;
            // TODO: сравнить с константами цветов
            case name of
              'ff000000': cs := empty;
              'ffff8000': cs := wire;
              'ffffffff': cs := signal;
              'ff0080ff': cs := signal_tail;
            end;
            cells[i, j].setState(cs);
          end;
      end;
    end;
  end;

  /// Область просмотра поля ---------------------------------------------------
  FieldViewport = class
  public
    /// цвет фона (вокруг поля)
    static bgColor: Color := clGray;
    /// цвет пустой клетки
    static emptyColor: Color := clBlack;
    /// цвет проводника
    static wireColor: Color := RGB(255, 128, 0);  // ffff8000
    /// цвет сигнала
    static signalColor: Color := clWhite;
    /// цвет хвоста сигнала
    static signalTailColor: Color := RGB(0, 128, 255); // ff0080ff


  private
    /// название (для заголовка окна)
    name: string;
    /// данные (поле)
    data: Field;
    /// горизонтальная координата
    x0: integer;
    /// вертикальная координата
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
      // TODO: оставить только FillRectangle?
      if cellSize = 1 then
        case data.getCellState(i, j) of
          empty: SetPixel(x, y, emptyColor);
          wire: SetPixel(x, y, wireColor);
          signal: SetPixel(x, y, signalColor);
          signal_tail: SetPixel(x, y, signalTailColor);
        end
      else
      begin
        case data.getCellState(i, j) of
          empty: SetBrushColor(emptyColor);
          wire: SetBrushColor(wireColor);
          signal: SetBrushColor(signalColor);
          signal_tail: SetBrushColor(signalTailColor);
        end;
        FillRectangle(x, y, x + cellSize, y + cellSize);
      end;
    end;

    /// нарисовать клетку, вычислив координаты
    procedure drawCell(i, j: integer);
    begin
      var x := x0 + (j - 1) * CellSize;
      var y := y0 + (i - 1) * CellSize;
      drawCell(i, j, x, y);
    end;

    /// нарисовать
    procedure draw;
    begin
      LockDrawing;
      setWindowTitle;
      if (N * cellSize < height) or (M * cellSize < width) then
        clearWindow(bgColor);
      var y := y0;
      for var i := 1 to N do
      begin
        var x := x0;
        for var j := 1 to M do
        begin
          // TODO: рисовать только клетки, попадающие в окно!
          drawCell(i, j, x, y);
          x += cellSize;
        end;
        y += cellSize;
      end;
      UnlockDrawing;
    end;

    /// перерисовать не пустые клетки
    procedure redrawNotEmpty;
    begin
      LockDrawing;
      setWindowTitle;
      for var i := 1 to N do
        for var j := 1 to M do
          if data.getCellState(i, j) <> empty then
            // TODO: рисовать только клетки, попадающие в окно!
            drawCell(i, j);
      UnlockDrawing;
    end;

    /// переход к следующему шагу и его отрисовка
    procedure nextStepAndDraw;
    begin
      data.calcNewState;
      setWindowTitle;
      LockDrawing;
      for var i := 1 to N do
        for var j := 1 to M do
          // если состояние клетки изменилось, то перерисовать её
          if data.cellStateChanged(i, j) then
          begin
            data.setCellNewState(i, j);
            // TODO: рисовать только клетки, попадающие в окно!
            drawCell(i, j);
          end;
      UnlockDrawing;
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
      data.loadPicture(fname);
      draw
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
            redrawNotEmpty;
          end
          else // обычный режим
            nextStepAndDraw;
          System.Windows.Forms.Application.DoEvents;
        until stop;
      end
      else
        stop := true;
    end;

    /// установить исходный масштаб (размер клетки 1)
    procedure scaleTo1;
    begin
      cellSize := 1;
      x0 := 0;
      y0 := 0;
      draw
    end;

    /// увеличить масштаб
    procedure scaleUp;
    begin
      if cellSize < 64 then
      begin
        cellSize := cellSize shl 1;
        x0 := x0 shl 1;
        y0 := y0 shl 1;
      end;
      draw
    end;

    /// уменьшить масштаб
    procedure scaleDown;
    begin
      if cellSize > 1 then
      begin
        cellSize := cellSize shr 1;
        x0 := x0 shr 1;
        y0 := y0 shr 1;
      end;
      draw
    end;

    /// сдвиг изображения
    procedure move(dx, dy: integer);
    begin
      x0 += dx;
      y0 += dy;
      draw
    end;

    /// обработчик мышки
    procedure mouseDown(x, y, mb: integer);
    begin
      if stop then
      begin
        var i := (y - y0) div CellSize + 1;
        var j := (x - x0) div CellSize + 1;
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
          VK_Enter: nextStepAndDraw;
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
