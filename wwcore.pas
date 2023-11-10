unit wwcore;

type
  //////////////////////////////////////////////////////////////////////////////
  /// Состояние клетки (перечислимый тип)
  CellState = (
    /// пустая клетка
    empty,
    /// проводник
    wire,
    /// сигнал
    signal,
    /// "хвост" сигнала
    signalTail
  );
  
  //////////////////////////////////////////////////////////////////////////////
  /// Клетка
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
        signal: state := signalTail;
        signalTail: state := empty;
      end;
      newState := state;
    end;
    
    /// "декремент" состояния
    procedure decState;
    begin
      case state of
        empty: state := signalTail;
        wire: state := empty;
        signal: state := wire;
        signalTail: state := signal;
      end;
      newState := state;
    end;
    
    /// очистить сигналы
    procedure clearSignals;
    begin
      if (state = signal) or (state = signalTail) then
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
        signal: newState := signalTail;
        signalTail: newState := wire;
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
  
  //////////////////////////////////////////////////////////////////////////////
  /// Игровое поле
  Field = class
  private
    /// клетки поля
    cells: array [,] of Cell;
    /// номер поколения
    genN: cardinal;
  
  public
    /// количество строк
    property nRows: integer read cells.GetLength(0);
    /// количество столбцов
    property nCols: integer read cells.GetLength(1);
    /// номер поколения
    property genNumber: cardinal read genN;
    
    constructor Create;
    begin
      cells := new Cell[0, 0];
    end;
    
    constructor Create(nRows, nCols: integer);
    begin
      cells := new Cell[nRows, nCols];
      // создание клеток
      for var i := 0 to nRows - 1 do
        for var j := 0 to nCols - 1 do
          cells[i, j] := new Cell;
      // связывание с соседями
      for var i := 0 to nRows - 1 do
      begin
        var i1 := i - 1;
        if i1 < 0 then
          i1 := nRows - 1;
        var i2 := i + 1;
        if i2 = nRows then
          i2 := 0;
        for var j := 0 to nCols - 1 do
        begin
          var j1 := j - 1;
          if j1 < 0 then
            j1 := nCols - 1;
          var j2 := j + 1;
          if j2 = nCols then
            j2 := 0;
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
    
    /// обнулить номер поколения
    procedure clearGenNumber;
    begin
      genN := 0;
    end;
    
    /// состояние клетки изменилось?
    function cellStateChanged(i, j: integer): boolean;
    begin
      result := cells[i, j].stateChanged;
    end;
    
    /// переход к следующему поколению
    procedure nextGeneration;
    begin
      for var i := 0 to nRows - 1 do
        for var j := 0 to nCols - 1 do
          cells[i, j].calcNewState;
      inc(genN);
      for var i := 0 to nRows - 1 do
        for var j := 0 to nCols - 1 do
          cells[i, j].applyNewState;
    end;
    
    /// очистить (все клетки пустые)
    procedure clear;
    begin
      genN := 0;
      for var i := 0 to nRows - 1 do
        for var j := 0 to nCols - 1 do
          cells[i, j].setState(empty);
    end;
    
    /// очистить сигналы
    procedure clearSignals;
    begin
      genN := 0;
      for var i := 0 to nRows - 1 do
        for var j := 0 to nCols - 1 do
          cells[i, j].clearSignals;
    end;
  
  end;

end.
