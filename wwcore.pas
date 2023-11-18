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
    /// потенциал (в соседней клетке есть сигнал)
    potential: boolean;
    /// флаг изменения состояния
    changed: boolean;
    /// соседи
    neighbors: array of Cell;

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
      neighbors := new Cell[8];
      var i := 0;
      if n1 <> nil then begin neighbors[i] := n1; inc(i) end;
      if n2 <> nil then begin neighbors[i] := n2; inc(i) end;
      if n3 <> nil then begin neighbors[i] := n3; inc(i) end;
      if n4 <> nil then begin neighbors[i] := n4; inc(i) end;
      if n5 <> nil then begin neighbors[i] := n5; inc(i) end;
      if n6 <> nil then begin neighbors[i] := n6; inc(i) end;
      if n7 <> nil then begin neighbors[i] := n7; inc(i) end;
      if n8 <> nil then begin neighbors[i] := n8; inc(i) end;
      SetLength(neighbors, i);
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

    /// установить потенциалы соседним клеткам
    procedure setNeighborPotentials;
    begin
      for var i := 0 to neighbors.GetUpperBound(0) do
      begin
        var n := neighbors[i];
        if n.newState = wire then
          n.potential := true;
      end;
    end;

    /// вычислить новое состояние
    procedure calcNewState;
    begin
      case state_ of
        wire:
          if potential then
          begin
            potential := false;
            var count := 0;
            for var i := 0 to neighbors.GetUpperBound(0) do
              if neighbors[i].state_ = signal then
                inc(count);
            if count < 1 then exit;
            if count > 2 then exit;
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
        if state_ = signal then
          setNeighborPotentials;
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
    /// флаг подготовки к расчёту поколений
    prepared: boolean;

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
    end;

    /// вернуть состояние клетки
    function getCellState(i, j: integer): CellState;
    begin
      var c := cells[i, j];
      if c <> nil then
        result := c.state
      else
        result := empty;
    end;

    /// установить состояние клетки
    procedure setCellState(i, j: integer; cs: CellState);
    begin
      prepared := false;
      if cs = empty then
        cells[i, j] := nil
      else
      begin
        var c := cells[i, j];
        if c = nil then
        begin
          c := new Cell;
          cells[i, j] := c;
        end;
        c.state := cs;
      end;
    end;

    /// "инкремент" состояния клетки
    procedure incCellState(i, j: integer);
    begin
      prepared := false;
      if cells[i, j] = nil then
        cells[i, j] := new Cell;
      cells[i, j].incState;
      if cells[i, j].state = empty then
        cells[i, j] := nil;
    end;

    /// "декремент" состояния клетки
    procedure decCellState(i, j: integer);
    begin
      prepared := false;
      if cells[i, j] = nil then
        cells[i, j] := new Cell;
      cells[i, j].decState;
      if cells[i, j].state = empty then
        cells[i, j] := nil;
    end;

    /// обнулить номер поколения
    procedure clearGenNumber;
    begin
      genNumber_ := 0;
    end;

    /// состояние клетки изменилось?
    function cellStateChanged(i, j: integer): boolean;
    begin
      var c := cells[i, j];
      if c <> nil then
        result := c.stateChanged
      else
        result := false;
    end;

    /// подготовить к расчёту поколений
    procedure prepare;
    begin
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
          var c := cells[i, j];
          if c <> nil then
          begin
            var j1 := j - 1;
            if j1 < 0 then
              j1 := nCols - 1;
            var j2 := j + 1;
            if j2 = nCols then
              j2 := 0;
            // связать с соседями
            c.setNeighbors(
              cells[i1, j], cells[i1, j2], cells[i, j2], cells[i2, j2],
              cells[i2, j], cells[i2, j1], cells[i, j1], cells[i1, j1]);
            // установить потенциалы для сигналов
            if c.state = signal then
              c.setNeighborPotentials;
          end;
        end;
      end;
    end;

    /// переход к следующему поколению
    procedure nextGeneration;
    begin
      if not prepared then
      begin
        prepare;
        prepared := true;
      end;
      for var i := 0 to nRows - 1 do
        for var j := 0 to nCols - 1 do
        begin
          var c := cells[i, j];
          if c <> nil then
            c.calcNewState;
        end;
      inc(genNumber_);
      for var i := 0 to nRows - 1 do
        for var j := 0 to nCols - 1 do
        begin
          var c := cells[i, j];
          if c <> nil then
            c.applyNewState;
        end;
    end;

    /// очистить (все клетки пустые)
    procedure clear;
    begin
      genNumber_ := 0;
      for var i := 0 to nRows - 1 do
        for var j := 0 to nCols - 1 do
          cells[i, j] := nil;
    end;

    /// очистить сигналы
    procedure clearSignals;
    begin
      genNumber_ := 0;
      for var i := 0 to nRows - 1 do
        for var j := 0 to nCols - 1 do
        begin
          var c := cells[i, j];
          if c <> nil then
            c.clearSignals;
        end;
    end;

  end;

end.
