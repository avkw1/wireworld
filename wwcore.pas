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
    signalTail);

  //////////////////////////////////////////////////////////////////////////////
  /// Клетка
  Cell = class
  private
    /// состояние
    state_: CellState;
    /// новое состояние
    newState: CellState;
    /// потенциал (в соседней клетке есть сигнал)
    potential: integer;
    /// флаг изменения состояния
    changed: boolean;
    /// соседи
    neighbors: array of Cell;

    /// установить состояние
    procedure setState(cs: CellState);
    begin
      state_ := cs;
      newState := cs;
    end;

    /// установить потенциалы соседним клеткам
    procedure setNeighborPotentials;
    begin
      for var i := 0 to neighbors.GetUpperBound(0) do
      begin
        var n := neighbors[i];
        if n.newState = wire then
          inc(n.potential);
      end;
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
      // установить потенциалы для сигналов
      if state_ = signal then
        setNeighborPotentials;
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

    /// очистить (обнулить) потенциал
    procedure clearPotential;
    begin
      potential := 0;
    end;

    /// вычислить новое состояние
    procedure calcNewState;
    begin
      case state_ of
        wire:
          if potential > 0 then
          begin
            if potential < 3 then
              newState := signal;
            potential := 0;
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

    /// сбросить флаг изменения состояния
    procedure clearChanged;
    begin
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
    genNumber_: uint64;
    /// флаг подготовки к расчёту поколений
    prepared: boolean;
    /// граничные индексы (для пропуска пустых строк сверху и снизу)
    iMin, iMax: integer;
    /// граничные индексы (для пропуска пустых клеток слева и справа)
    jMin, jMax: array of integer;

  public
    /// количество строк
    property nRows: integer read cells.GetLength(0);
    /// количество столбцов
    property nCols: integer read cells.GetLength(1);
    /// номер поколения
    property genNumber: uint64 read genNumber_;

    constructor Create(nRows, nCols: integer);
    begin
      cells := new Cell[nRows, nCols];
      jMin := new integer[nRows];
      jMax := new integer[nRows];
    end;

    /// изменить размер поля
    procedure resize(nRows, nCols: integer);
    begin
      prepared := false;
      genNumber_ := 0;
      SetLength(cells, nRows, nCols);
      SetLength(jMin, nRows);
      SetLength(jMax, nRows);
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
      genNumber_ := 0;
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
      genNumber_ := 0;
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
      genNumber_ := 0;
      if cells[i, j] = nil then
        cells[i, j] := new Cell;
      cells[i, j].decState;
      if cells[i, j].state = empty then
        cells[i, j] := nil;
    end;

    /// вернуть состояние клетки, если оно изменилось, иначе вернуть empty
    function getCellStateIfChanged(i, j: integer): CellState;
    begin
      var c := cells[i, j];
      if (c <> nil) and c.stateChanged then
        result := c.state
      else
        result := empty;
    end;

    /// вернуть состояние клетки и сбросить флаг изменения
    function getCellStateClearChanged(i, j: integer): CellState;
    begin
      var c := cells[i, j];
      if c <> nil then
      begin
        c.clearChanged;
        result := c.state;
      end
      else
        result := empty;
    end;

  private
    /// найти граничные индексы (область, где есть не пустые клетки)
    procedure findMinMaxIndexes;
    begin
      var iEnd := nRows - 1;
      var jEnd := nCols - 1;
      iMin := -1;
      iMax := -1;
      // поиск iMin
      for var i := 0 to iEnd do
      begin
        for var j := 0 to jEnd do
          if cells[i, j] <> nil then
          begin
            iMin := i;
            break;
          end;
        if iMin >= 0 then
          break;
      end;
      // если все клетки пустые
      if iMin = -1 then
      begin
        iMin := 0;
        for var i := 0 to iEnd do
        begin
          jMin[i] := 0;
          jMax[i] := -1;
        end;
        exit;
      end;
      // поиск iMax
      for var i := iEnd downto iMin do
      begin
        for var j := jEnd downto 0 do
          if cells[i, j] <> nil then
          begin
            iMax := i;
            break;
          end;
        if iMax >= 0 then
          break;
      end;
      // заполнение jMin и jMax
      for var i := 0 to iEnd do
      begin
        if (i < iMin) or (i > iMax) then
        begin
          jMin[i] := 0;
          jMax[i] := -1;
          continue;
        end;
        for var j := 0 to jEnd do
          if cells[i, j] <> nil then
          begin
            jMin[i] := j;
            break;
          end;
        for var j := jEnd downto 0 do
          if cells[i, j] <> nil then
          begin
            jMax[i] := j;
            break;
          end;
      end;
    end;

    /// подготовить к расчёту поколений
    procedure prepare;
    begin
      // найти граничные индексы
      findMinMaxIndexes;
      // очистить все потенциалы
      for var i := iMin to iMax do
        for var j := jMin[i] to jMax[i] do
        begin
          var c := cells[i, j];
          if c <> nil then
            c.clearPotential;
        end;
      // связать с соседями (поверхность тора), установить потенциалы
      for var i := iMin to iMax do
      begin
        var i1 := i - 1;
        if i1 < 0 then
          i1 := nRows - 1;
        var i2 := i + 1;
        if i2 = nRows then
          i2 := 0;
        for var j := jMin[i] to jMax[i] do
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
            // связать с соседями, установить потенциалы
            c.setNeighbors(
              cells[i1, j], cells[i1, j2], cells[i, j2], cells[i2, j2],
              cells[i2, j], cells[i2, j1], cells[i, j1], cells[i1, j1]);
          end;
        end;
      end;
      prepared := true;
    end;

  public
    /// переход к следующему поколению
    procedure nextGeneration;
    begin
      if not prepared then
        prepare;
      for var i := iMin to iMax do
        for var j := jMin[i] to jMax[i] do
        begin
          var c := cells[i, j];
          if c <> nil then
            c.calcNewState;
        end;
      inc(genNumber_);
      for var i := iMin to iMax do
        for var j := jMin[i] to jMax[i] do
        begin
          var c := cells[i, j];
          if c <> nil then
            c.applyNewState;
        end;
    end;

    /// очистить (все клетки пустые)
    procedure clear;
    begin
      prepared := false;
      genNumber_ := 0;
      for var i := 0 to nRows - 1 do
        for var j := 0 to nCols - 1 do
          cells[i, j] := nil;
    end;

    /// очистить сигналы
    procedure clearSignals;
    begin
      prepared := false;
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
