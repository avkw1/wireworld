program wireworld;

uses GraphABC;

const
  /// Количество строк поля
  N = 600;
  /// Количество столбцов поля
  M = 800;
  /// Размер клетки
  CellSizeConst = 1;
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
  public
    /// цвет пустой клетки
    static emptyColor: Color := clBlack;
    /// цвет проводника
    static wireColor: Color := RGB(255, 128, 0);  // ffff8000
    /// цвет сигнала
    static signalColor: Color := clWhite;
    /// цвет хвоста сигнала
    static signalTailColor: Color := RGB(0, 128, 255); // ff0080ff
  
  private
    /// состояние
    state: CellState;
    /// новое состояние
    newState: CellState;
    /// соседи
    neighbors: array [1..8] of Cell;
    /// горизонтальная координата (для рисования)
    x: integer;
    /// вертикальная координата (для рисования)
    y: integer;
  
  public
    /// вернуть состояние
    function getState: CellState;
    begin
      result := state
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
    
    /// установить координаты для рисования
    procedure setCoordinates(x, y: integer);
    begin
      self.x := x;
      self.y := y;
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
    
    /// нарисовать
    procedure draw(size: integer := 1);
    begin
      if size = 1 then
        case state of
          empty: SetPixel(x, y, emptyColor);
          wire: SetPixel(x, y, wireColor);
          signal: SetPixel(x, y, signalColor);
          signal_tail: SetPixel(x, y, signalTailColor);
        end
      else
      begin
        case state of
          empty: SetBrushColor(emptyColor);
          wire: SetBrushColor(wireColor);
          signal: SetBrushColor(signalColor);
          signal_tail: SetBrushColor(signalTailColor);
        end;
        FillRectangle(x, y, x + size, y + size);
      end;
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
    
    /// установить состояние
    procedure setState(cs: CellState);
    begin
      state := cs;
      newState := cs;
    end;
    
    /// очистить сигналы
    procedure clearSignals;
    begin
      if (state = signal) or (state = signal_tail) then
        setState(wire);
    end;
  
  end;
  
  /// Игровое поле -------------------------------------------------------------
  GameField = class
  private
    /// клетки поля
    cells: array [1..N, 1..M] of Cell;
    /// размер клетки
    cellSize: integer;
    /// номер поколения
    nGen: cardinal;
    /// флаг остановки
    stop: boolean := true;
  
  public
    constructor Create(cellSize: integer := 1);
    begin
      // установить размер клетки
      self.cellSize := cellSize;
      // создание клеток
      for var i := 1 to N do
        for var j := 1 to M do
          cells[i, j] := new Cell;
      // связывание с соседями, установка координат
      var y := 0;
      for var i := 1 to N do
      begin
        var i1 := i - 1;
        if i1 = 0 then
          i1 := N;
        var i2 := i + 1;
        if i2 = N + 1 then
          i2 := 1;
        var x := 0;
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
          cells[i, j].setCoordinates(x, y);
          x += cellSize;
        end;
        y += cellSize;
      end;
    end;
    
    /// нарисовать
    procedure draw;
    begin
      LockDrawing;
      setWindowTitle;
      for var i := 1 to N do
        for var j := 1 to M do
          cells[i, j].draw(cellSize);
      UnlockDrawing;
    end;
    
    /// перерисовать не пустые клетки
    procedure redrawNotEmpty;
    begin
      LockDrawing;
      setWindowTitle;
      for var i := 1 to N do
        for var j := 1 to M do
          if cells[i, j].getState <> empty then
            cells[i, j].draw(cellSize);
      UnlockDrawing;
    end;
    
    /// переход к следующему шагу (без рисования!)
    procedure nextStep();
    begin
      for var i := 1 to N do
        for var j := 1 to M do
          cells[i, j].calcNewState;
      inc(nGen);
      for var i := 1 to N do
        for var j := 1 to M do
          cells[i, j].setNewState;
    end;
    
    /// переход к следующему шагу и его отрисовка
    procedure nextStepAndDraw();
    begin
      for var i := 1 to N do
        for var j := 1 to M do
          cells[i, j].calcNewState;
      inc(nGen);
      setWindowTitle;
      LockDrawing;
      for var i := 1 to N do
        for var j := 1 to M do
          // если состояние клетки изменилось, то перерисовать её
          if cells[i, j].stateChanged then
          begin
            cells[i, j].setNewState;
            cells[i, j].draw(cellSize);
          end;
      UnlockDrawing;
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
              nextStep;
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
    
    /// остановлено?
    function stopped: boolean;
    begin
      result := stop;
    end;
    
    /// очистить (все клетки пустые)
    procedure clear;
    begin
      nGen := 0;
      for var i := 1 to N do
        for var j := 1 to M do
          cells[i, j].setState(empty);
      draw;
    end;
    
    /// очистить сигналы
    procedure clearSignals;
    begin
      nGen := 0;
      for var i := 1 to N do
        for var j := 1 to M do
          cells[i, j].clearSignals;
      draw;
    end;
    
    /// загрузить изображение
    procedure loadPicture(fname: string);
    begin
      var p: Picture;
      p := new Picture(fname);
      if (p.Height = N) and (p.Width = M) then
      begin
        nGen := 0;
        for var i := 1 to N do
          for var j := 1 to M do
          begin
            var cs: CellState;
            var name := p.GetPixel(j - 1, i - 1).Name;
            case name of
              'ff000000': cs := empty;
              'ffff8000': cs := wire;
              'ffffffff': cs := signal;
              'ff0080ff': cs := signal_tail;
            end;
            cells[i, j].setState(cs);
          end;
        draw;
      end;
    end;
    
    /// установить заголовок окна
    procedure setWindowTitle;
    begin
      window.Title := 'Клеточный автомат WireWorld [Поколение ' + nGen + ']';
    end;
    
    /// обработчик мышки
    procedure mouseDown(x, y, mb: integer);
    begin
      if stopped then
      begin
        var i := y div CellSize + 1;
        var j := x div CellSize + 1;
        case mb of 
          1: cells[i, j].incState;
          2: cells[i, j].decState;
        end;
        cells[i, j].draw(CellSize);
      end;
    end;
    
    /// обработчик клавиатуры
    procedure keyDown(k: integer);
    begin
      if stopped then
        case k of
          VK_Right: nextStepAndDraw;
          VK_Delete: clear;
          VK_Back: clearSignals;
          VK_Space: play;
          VK_Home: loadPicture(wwFileName);
        end
      else if k = VK_Space then
        play;
    end;
  end;

var
  // объект - игровое поле
  game: GameField;

// Обработчик мышки
procedure mouseDown(x, y, mb: integer);
begin
  game.mouseDown(x, y, mb);
end;

// Обработчик клавиатуры
procedure keyDown(k: integer);
begin
  game.keyDown(k);
end;

// Основная процедура
begin
  window.SetSize(M * CellSizeConst, N * CellSizeConst);
  window.IsFixedSize := true;
  window.CenterOnScreen;
  game := new GameField(CellSizeConst);
  game.loadPicture(wwFileName);
  OnMouseDown := mouseDown;
  OnKeyDown := keyDown;
end.