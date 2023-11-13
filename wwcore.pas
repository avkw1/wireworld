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
    state_: CellState;
    /// новое состояние
    newState: CellState;
    /// флаг изменения состояния
    changed: boolean;
    /// соседи
    neighbors: array [1..8] of Cell;

  private
    /// установить состояние
    procedure setState(cs: CellState);
    begin
      state_ := cs;
      newState := cs;
    end;

  public
    /// состояние
    property state: CellState read state_ write setState;

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
      case state_ of
        empty: setState(wire);
        wire: setState(signal);
        signal: setState(signalTail);
        signalTail: setState(empty);
      end;
    end;

    /// "декремент" состояния
    procedure decState;
    begin
      case state_ of
        empty: setState(signalTail);
        wire: setState(empty);
        signal: setState(wire);
        signalTail: setState(signal);
      end;
    end;

    /// очистить сигналы
    procedure clearSignals;
    begin
      if (state_ = signal) or (state_ = signalTail) then
        setState(wire);
    end;

    /// вычислить новое состояние
    procedure calcNewState;
    begin
      if state_ = empty then
        exit;
      case state_ of
        wire:
          begin
            var count := 0;
            for var i := 1 to high(neighbors) do
              if neighbors[i].state_ = signal then
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
      if state_ <> newState then
      begin
        state_ := newState;
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
    genNumber_: cardinal;

  public
    /// количество строк
    property nRows: integer read cells.GetLength(0);
    /// количество столбцов
    property nCols: integer read cells.GetLength(1);
    /// номер поколения
    property genNumber: cardinal read genNumber_;

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
      result := cells[i, j].state;
    end;

    /// установить состояние клетки
    procedure setCellState(i, j: integer; cs: CellState);
    begin
      cells[i, j].state := cs;
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
      genNumber_ := 0;
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
      inc(genNumber_);
      for var i := 0 to nRows - 1 do
        for var j := 0 to nCols - 1 do
          cells[i, j].applyNewState;
    end;

    /// очистить (все клетки пустые)
    procedure clear;
    begin
      genNumber_ := 0;
      for var i := 0 to nRows - 1 do
        for var j := 0 to nCols - 1 do
          cells[i, j].state := empty;
    end;

    /// очистить сигналы
    procedure clearSignals;
    begin
      genNumber_ := 0;
      for var i := 0 to nRows - 1 do
        for var j := 0 to nCols - 1 do
          cells[i, j].clearSignals;
    end;

  end;

end.
