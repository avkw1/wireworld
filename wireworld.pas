program wireworld;

uses wwcore, GraphABC, System.Windows.Forms;

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
    /// максимальный размер клетки (степень 2)
    maxCellSize: integer := 32;
    /// состояние предыдущей нарисованной клетки
    prevCellState: CellState;

    /// ширина поля в пикселях
    property fieldWidth: integer read data.nCols * cellSize;
    /// высота поля в пикселях
    property fieldHeight: integer read data.nRows * cellSize;

  public
    /// номер поколения
    property genNumber: uint64 read data.genNumber;

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

    constructor Create;
    begin
      width := window.Width;
      height := window.Height;
      data := new Field(height, width);
    end;

  private
    /// нарисовать клетку
    procedure drawCell(cs: CellState; x, y: integer);
    begin
      if prevCellState <> cs then
      begin
        SetBrushColor(cellStateToColor(cs));
        prevCellState := cs;
      end;
      FillRectangle(x, y, x + cellSize, y + cellSize);
    end;

    /// нарисовать
    procedure draw;
    begin
      LockDrawing;
      // если окно больше поля, то нарисовать фон
      if (fieldHeight < height) or (fieldWidth < width) then
        clearWindow(bgColor);
      // нарисовать все пустые клетки (одним прямоугольником)
      SetBrushColor(emptyColor);
      prevCellState := empty;
      FillRectangle(max(0, x0), max(0, y0), min(width, x0 + fieldWidth),
        min(height, y0 + fieldHeight));
      // расчёт индексов для рисования только клеток, попадающих в окно
      var iBegin := max(0, floor((-y0) / cellSize));
      var jBegin := max(0, floor((-x0) / cellSize));
      var iEnd := min(ceil((height - y0) / cellSize) - 1, data.nRows - 1);
      var jEnd := min(ceil((width - x0) / cellSize) - 1, data.nCols - 1);
      var y := y0 + iBegin * cellSize;
      for var i := iBegin to iEnd do
      begin
        var x := x0 + jBegin * cellSize;
        for var j := jBegin to jEnd do
        begin
          var cs := data.getCellStateClearChanged(i, j);
          if cs <> empty then
            // нарисовать клетку
            drawCell(cs, x, y);
          x += cellSize;
        end;
        y += cellSize;
      end;
      UnlockDrawing;
    end;

    /// нарисовать только изменившиеся клетки
    procedure drawChanged;
    begin
      LockDrawing;
      // расчёт индексов для рисования только клеток, попадающих в окно
      var iBegin := max(0, floor((-y0) / cellSize));
      var jBegin := max(0, floor((-x0) / cellSize));
      var iEnd := min(ceil((height - y0) / cellSize) - 1, data.nRows - 1);
      var jEnd := min(ceil((width - x0) / cellSize) - 1, data.nCols - 1);
      var y := y0 + iBegin * cellSize;
      for var i := iBegin to iEnd do
      begin
        for var j := jBegin to jEnd do
        begin
          // флаг изменения сбрасывается после чтения
          var cs := data.getCellStateIfChanged(i, j);
          if cs <> empty then
            // нарисовать клетку, если она изменилась
            drawCell(cs, x0 + j * cellSize, y);
        end;
        y += cellSize;
      end;
      UnlockDrawing;
    end;

    /// исправить положение поля (x0, y0)
    procedure fixPosition;
    begin
      var dx := width - fieldWidth;
      var dy := height - fieldHeight;
      if dx >= 0 then
        x0 := dx div 2
      else if x0 < dx then
        x0 := dx
      else if x0 > 0 then
        x0 := 0;
      if dy >= 0 then
        y0 := dy div 2
      else if y0 < dy then
        y0 := dy
      else if y0 > 0 then
        y0 := 0;
    end;

  public
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
        for var i := 0 to data.nRows - 1 do
          for var j := 0 to data.nCols - 1 do
            data.setCellState(i, j, colorToCellState(p.GetPixel(j, i)));
        draw;
      end;
    end;

    /// сохранить изображение
    procedure savePicture(fname: string);
    begin
      var p: Picture := new Picture(data.nCols, data.nRows);
      for var i := 0 to data.nRows - 1 do
        for var j := 0 to data.nCols - 1 do
          p.SetPixel(j, i, cellStateToColor(data.getCellState(i, j)));
      p.Save(fname);
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
    procedure scaleUp(x, y: integer);
    begin
      if cellSize < maxCellSize then
      begin
        cellSize *= 2;
        x0 := x0 * 2 - x;
        y0 := y0 * 2 - y;
        fixPosition;
        draw;
      end;
    end;

    /// уменьшить масштаб
    procedure scaleDown(x, y: integer);
    begin
      if cellSize > 1 then
      begin
        cellSize := cellSize div 2;
        x0 := (x0 + x) div 2;
        y0 := (y0 + y) div 2;
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
      var i := (y - y0) div cellSize;
      var j := (x - x0) div cellSize;
      if (i < 0) or (j < 0) or (i >= data.nRows) or (j >= data.nCols) then
        exit;
      case mb of
        1: data.incCellState(i, j);
        2: data.decCellState(i, j);
      end;
      drawCell(data.getCellState(i, j), x0 + j * cellSize, y0 + i * cellSize);
    end;

    /// обработчик изменения размера окна
    procedure resize;
    begin
      x0 += (window.Width - width) div 2;
      y0 += (window.Height - height) div 2;
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
    /// название (для заголовка окна)
    name: string;
    /// область просмотра игрового поля
    vp: Viewport;
    /// флаг остановки
    stop: boolean := true;
    /// флаг запуска тестов
    test: boolean;
    /// имя файла с картинкой
    wwFileName := 'ww800x600.gif';
    /// пропуск кадров (рисования поколений)
    skipFrames: integer;

  public
    constructor Create(name: string := 'Wireworld');
    begin
      self.name := name;
      vp := new Viewport;
      vp.loadPicture(wwFileName);
      setWindowTitle('> > > Для справки нажмите F1 ! < < <');
    end;

    /// установить заголовок окна
    procedure setWindowTitle(message: string := nil);
    begin
      var t := name + ' ';
      if skipFrames > 0 then
        t += '[Рисование 1/' + (skipFrames + 1) + '] ';
      t += '[Поколение ' + vp.genNumber.ToString + '] ';
      if message <> nil then
        t += message;
      window.Title := t;
    end;

    /// показать справку
    procedure help;
    begin
      System.Windows.Forms.MessageBox.Show(
        'Эмулятор клеточного автомата Wireworld' + #10 + #10 + #10 +
        'Управление программой:' + #10 + #10 +
        '<Пробел> - запустить/остановить смену поколений' + #10 +
        '<+> - увеличить пропуск рисования поколений' + #10 +
        '<-> - уменьшить пропуск рисования поколений' + #10 +
        '<PageUp> - увеличить масштаб' + #10 +
        '<PageDown> - уменьшить масштаб' + #10 +
        '<Home> - восстановить начальный масштаб и размер окна' + #10 +
        '<Стрелки> - сдвинуть область просмотра поля' + #10 +
        '<F1> - показать справку (это сообщение)' + #10 + #10 +
        'Только когда смена поколений остановлена:' + #10 + #10 +
        '<Левая и правая кнопки мышки> - переключение состояния клетки' + #10 +
        '<Enter> - следующее поколение (один шаг)' + #10 +
        '<Delete> - очистить поле (сделать все клетки пустыми)' + #10 +
        '<Backspace> - удалить все сигналы (сделать сигналы проводниками)' + #10 +
        '<Insert> - загрузить изображение из файла ("' + wwFileName + '")' + #10 +
        '<F3> - сохранить изображение в файл ("' +
        wwFileName.Replace('.gif', '_<№поколения>.gif")') + #10 +
        '<F2> - запустить тесты производительности',
        'Справка');
    end;

    /// запуск игры
    procedure play;
    begin
      if stop then
      begin
        stop := false;
        repeat
          loop skipFrames do
            vp.nextGeneration(false); // пропуск рисования
          vp.nextGeneration;
          setWindowTitle;
          System.Windows.Forms.Application.DoEvents;
        until stop;
      end
      else
        stop := true;
    end;

    /// увеличить пропуск кадров
    procedure incSkipFrames;
    begin
      case skipFrames of
        0..8: inc(skipFrames);
        9: skipFrames := 19;
        19: skipFrames := 49;
        49: skipFrames := 99;
        99: skipFrames := 199;
        199: skipFrames := 499;
        499: skipFrames := 999;
      end;
      setWindowTitle;
    end;

    /// уменьшить пропуск кадров
    procedure decSkipFrames;
    begin
      case skipFrames of
        1..9: dec(skipFrames);
        19: skipFrames := 9;
        49: skipFrames := 19;
        99: skipFrames := 49;
        199: skipFrames := 99;
        499: skipFrames := 199;
        999: skipFrames := 499;
      end;
      setWindowTitle;
    end;

    /// один шаг (одно поколение)
    procedure nextGeneration;
    begin
      vp.nextGeneration;
      setWindowTitle;
    end;

    /// очистить поле (все клетки пустые)
    procedure clear;
    begin
      vp.clear;
      setWindowTitle;
    end;

    /// очистить сигналы
    procedure clearSignals;
    begin
      vp.clearSignals;
      setWindowTitle;
    end;

    /// загрузить изображение
    procedure loadPicture;
    begin
      vp.loadPicture(wwFileName);
      setWindowTitle;
    end;

    /// сохранить изображение
    procedure savePicture;
    begin
      var fname: string;
      fname := wwFileName.Replace('.gif', '_') + vp.genNumber.ToString + '.gif';
      if fileexists(fname) then
        if MessageBox.Show(
          'Файл "' + fname + '" уже существует! Перезаписать?"',
          self.name, MessageBoxButtons.YesNo) = DialogResult.No then
            exit;
      vp.savePicture(fname);
      MessageBox.Show('Сохранено в файл "' + fname + '".', self.name);
    end;

    /// выполнить тесты производительности
    procedure performanceTests;
    begin
      test := true;
      skipFrames := 0;
      // тест 1 (без рисования)
      vp.scaleTo1;
      vp.loadPicture(wwFileName);
      window.Title := 'Тест 1 запущен...';
      Milliseconds;
      loop 1000 do
        vp.nextGeneration(false);
      var t1 := MillisecondsDelta;
      // тест 2 (с рисованием)
      System.Windows.Forms.Application.DoEvents;
      var n := name;
      name := 'Тест 2 запущен...';
      vp.loadPicture(wwFileName);
      setWindowTitle;
      Milliseconds;
      loop 1000 do
      begin
        vp.nextGeneration;
        setWindowTitle;
        System.Windows.Forms.Application.DoEvents;
      end;
      var t2 := MillisecondsDelta;
      // тест 3 (полная перерисовка - Viewport.draw)
      name := 'Тест 3 запущен...';
      setWindowTitle;
      Milliseconds;
      loop 100 do
      begin
        vp.draw;
        System.Windows.Forms.Application.DoEvents;
      end;
      var t3 := MillisecondsDelta;
      name := n;
      setWindowTitle;
      System.Windows.Forms.MessageBox.Show(
        'Тест 1 (1000 поколений без рисования) : ' + t1 / 1000 + ' с' + #10 +
        'Тест 2 (1000 поколений с рисованием)  : ' + t2 / 1000 + ' с' + #10 +
        'Тест 3 (100 полных перерисовок)       : ' + t3 / 1000 + ' с' + #10 +
        'Скорость без рисования : ' + 60000000 div t1 + ' поколений в минуту' + #10 +
        'Скорость с рисованием  : ' + 60000000 div t2 + ' поколений в минуту' + #10 +
        'Скорость п.перерисовки : ' + 6000000 div t3 +
        ' кадров в минуту (' + round(100000 / t3, 2) + ' к/с)' +  #10,
        'Результаты тестов производительности');
      test := false;
    end;

    /// обработчик мышки
    procedure mouseDown(x, y, mb: integer);
    begin
      if test then
        exit;
      if stop then
      begin
        vp.mouseDown(x, y, mb);
        setWindowTitle;
      end;
    end;

    /// обработчик клавиатуры
    procedure keyDown(k: integer);
    begin
      if test then
        exit;
      case k of
        VK_F1: help;
        VK_Space: play;
        VK_Add: incSkipFrames;
        VK_Subtract: decSkipFrames;
        VK_PageUp: vp.scaleUp(window.Width div 2, window.Height div 2);
        VK_PageDown: vp.scaleDown(window.Width div 2, window.Height div 2);
        VK_Up: vp.move(0, vp.maxCellSize);
        VK_Down: vp.move(0, -vp.maxCellSize);
        VK_Left: vp.move(vp.maxCellSize, 0);
        VK_Right: vp.move(-vp.maxCellSize, 0);
        VK_Home: vp.scaleTo1;
      end;
      if stop then
        case k of
          VK_Enter: nextGeneration;
          VK_Delete: clear;
          VK_Back: clearSignals;
          VK_Insert: loadPicture;
          VK_F3: savePicture;
          VK_F2: performanceTests;
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
