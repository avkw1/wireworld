program wireworld;

uses wwcore, GraphABC, System.Windows.Forms;

const
  /// Версия программы
  version = '1.0';

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
    /// количество строк поля
    property nRows: integer read data.nRows;
    /// количество столбцов поля
    property nCols: integer read data.nCols;
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

    /// установить масштаб (размер клетки), изменить размер окна
    procedure setScaleResizeWindow(cs: integer);
    begin
      x0 := 0;
      y0 := 0;
      cellSize := cs;
      // если размер окна отличается от размера поля
      if (width <> fieldWidth) or (height <> fieldHeight) then
      begin
        window.Normalize;
        window.SetSize(fieldWidth, fieldHeight); // будет вызван resize -> draw
        Application.DoEvents;
        window.CenterOnScreen;
      end
      else
        draw;
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
      if (p.Height <> data.nRows) or (p.Width <> data.nCols) then
      begin
        data.resize(p.Height, p.Width);
        fixPosition;
      end;
      for var i := 0 to data.nRows - 1 do
        for var j := 0 to data.nCols - 1 do
          data.setCellState(i, j, colorToCellState(p.GetPixel(j, i)));
      draw;
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

    /// автоматически выбрать масштаб, изменить размер окна
    procedure autoScale;
    begin
      var cs: integer := 1;
      while cs <= maxCellSize do
      begin
        cs *= 2;
        if (data.nCols * cs > ScreenWidth - 20) or
          (data.nRows * cs > ScreenHeight - 100) then
        begin
          cs := cs div 2;
          break;
        end;
      end;
      setScaleResizeWindow(cs);
    end;

    /// установить масштаб 1:1 (размер клетки 1), изменить размер окна
    procedure scaleTo1;
    begin
      setScaleResizeWindow(1);
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
  /// Задача для управляющего класса (перечислимый тип)
  ControlTask = (
    /// нет задачи
    noTask,
    /// открыть файл
    fileOpen,
    /// сохранить файл
    fileSave,
    /// запуск теста
    test);

  //////////////////////////////////////////////////////////////////////////////
  /// Управляющий класс
  Control = class
  public
    /// начальная ширина окна
    static initWidth := 800;
    /// начальная высота окна
    static initHeight := 600;
    /// имя файла с картинкой для инициализации и теста
    static initFileName := GetCurrentDir + '\img\wwc_counter.gif';

  private
    /// название (для заголовка окна)
    name: string;
    /// область просмотра игрового поля
    vp: Viewport;
    /// флаг разрешения редактирования
    edit: boolean;
    /// флаг остановки
    stop: boolean := true;
    /// пропуск кадров (рисования поколений)
    skipFrames: integer;
    /// задача для основного потока или запуск теста
    task: ControlTask;
    /// имя загруженного файла
    fileName: string;
    /// имя файла, выбранное в диалоговом окне
    dlgFileName: string;

    /// установить имя файла и размер картинки для заголовка окна
    procedure setFileNameAndSize;
    begin
      name := ExtractFileName(fileName);
      name += ' [' + vp.nCols + 'x' + vp.nRows + ']';
    end;

    /// проверить флаг разрешения редактирования
    function checkEdit: boolean;
    begin
      result := edit;
      if not edit then
        MessageBox.Show(
          'Нажмите F4, чтобы разрешить редактирование изображения', self.name);
    end;

  public
    constructor Create;
    begin
      window.Title := String.Empty;
      window.SetSize(initWidth, initHeight);
      window.CenterOnScreen;
      SetSmoothingOff;
      vp := new Viewport;
      try
        vp.loadPicture(initFileName);
      except
        vp.clear;
      end;
      fileName := initFileName;
      setFileNameAndSize;
      setWindowTitle('> > > Для справки нажмите F1 ! < < <');
    end;

    /// установить заголовок окна
    procedure setWindowTitle(message: string := nil);
    begin
      var t := name + ' [' + vp.cellSize + ':1]';
      if skipFrames > 0 then
        t += ' [Рисование 1/' + (skipFrames + 1) + ']';
      t += ' [Поколение ' + vp.genNumber.ToString;
      if stop then
      begin
        t += ']';
        if edit then
          t += ' [Редактирование]';
      end
      else
        t += '+]';
      if message <> nil then
        t += ' ' + message;
      window.Title := t;
    end;

    /// показать справку
    procedure help;
    begin
      MessageBox.Show(
        'Эмулятор клеточного автомата Wireworld' + #10 +
        'Версия: ' + version + #10 + #10 +
        'Управление программой:' + #10 + #10 +
        '<Пробел> - запустить/остановить смену поколений' + #10 +
        '<NumPad+> - увеличить пропуск рисования поколений' + #10 +
        '<NumPad-> - уменьшить пропуск рисования поколений' + #10 +
        '<PageUp> - увеличить масштаб' + #10 +
        '<PageDown> - уменьшить масштаб' + #10 +
        '<Home> - установить масштаб 1:1, изменить размер окна' + #10 +
        '<End> - автоматически выбрать масштаб, изменить размер окна' + #10 +
        '<Стрелки> - сдвинуть область просмотра поля' + #10 +
        '<F1> - показать справку (это сообщение)' + #10 + #10 +
        'Только когда смена поколений остановлена:' + #10 + #10 +
        '<Левая и правая кнопки мышки> - переключение состояния клетки' + #10 +
        '<Enter> - следующее поколение (один шаг)' + #10 +
        '<Delete> - очистить поле (сделать все клетки пустыми)' + #10 +
        '<Backspace> - удалить все сигналы (сделать сигналы проводниками)' + #10 +
        '<Insert> - перезагрузить изображение' + #10 +
        '<F2> - загрузить изображение из файла' + #10 +
        '<F3> - сохранить изображение в файл' + #10 +
        '<F4> - разрешить/запретить редактирование изображения' + #10 +
        '<F12> - запустить тесты производительности',
        'Справка');
    end;

    /// запуск игры
    procedure play;
    begin
      if stop then
      begin
        stop := false;
        setWindowTitle;
        repeat
          loop skipFrames do
            vp.nextGeneration(false); // пропуск рисования
          vp.nextGeneration;
          setWindowTitle;
          Application.DoEvents;
        until stop;
        setWindowTitle;
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
        19: skipFrames := 35;
        35: skipFrames := 49;
        49: skipFrames := 95;
        95: skipFrames := 99;
        99: skipFrames := 191;
        191: skipFrames := 199;
        199: skipFrames := 499;
        499: skipFrames := 999;
        999: skipFrames := 1151;
        1151: skipFrames := 1999;
        1999: skipFrames := 2303;
        2303: skipFrames := 3839;
        3839: skipFrames := 4999;
        4999: skipFrames := 9999;
      end;
      setWindowTitle;
    end;

    /// уменьшить пропуск кадров
    procedure decSkipFrames;
    begin
      case skipFrames of
        1..9: dec(skipFrames);
        19: skipFrames := 9;
        35: skipFrames := 19;
        49: skipFrames := 35;
        95: skipFrames := 49;
        99: skipFrames := 95;
        191: skipFrames := 99;
        199: skipFrames := 191;
        499: skipFrames := 199;
        999: skipFrames := 499;
        1151: skipFrames := 999;
        1999: skipFrames := 1151;
        2303: skipFrames := 1999;
        3839: skipFrames := 2303;
        4999: skipFrames := 3839;
        9999: skipFrames := 4999;
      end;
      setWindowTitle;
    end;

    /// увеличить масштаб
    procedure scaleUp;
    begin
      vp.scaleUp(window.Width div 2, window.Height div 2);
      setWindowTitle;
    end;

    /// уменьшить масштаб
    procedure scaleDown;
    begin
      vp.scaleDown(window.Width div 2, window.Height div 2);
      setWindowTitle;
    end;

    /// установить масштаб 1:1
    procedure scaleTo1;
    begin
      vp.scaleTo1;
      setWindowTitle;
    end;

    /// автовыбор масштаба
    procedure autoScale;
    begin
      vp.autoScale;
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
      if checkEdit then
      begin
        vp.clear;
        setWindowTitle;
      end;
    end;

    /// очистить сигналы
    procedure clearSignals;
    begin
      if checkEdit then
      begin
        vp.clearSignals;
        setWindowTitle;
      end;
    end;

    /// загрузить изображение
    procedure loadPicture;
    begin
      task := fileOpen;
      repeat
        sleep(100);
      until task = noTask;
      if dlgFileName.Length > 0 then
      begin
        try
          vp.loadPicture(dlgFileName);
        except
          on e: Exception do
          begin
            MessageBox.Show(e.Message, 'Ошибка при загрузке файла');
            exit;
          end;
        end;
        edit := false;
        fileName := dlgFileName;
        skipFrames := 0;
        vp.autoScale;
        setFileNameAndSize;
        setWindowTitle;
      end;
    end;

    /// перезагрузить изображение
    procedure reloadPicture;
    begin
      try
        vp.loadPicture(fileName);
        edit := false;
        SetWindowTitle;
      except
        on e: Exception do
          MessageBox.Show(e.Message, 'Ошибка при загрузке файла');
      end;
    end;

    /// сохранить изображение
    procedure savePicture;
    begin
      task := fileSave;
      repeat
        sleep(100);
      until task = noTask;
      if dlgFileName.Length > 0 then
      begin
        try
          vp.savePicture(dlgFileName);
        except
          on e: Exception do
          begin
            MessageBox.Show(e.Message, 'Ошибка при сохранении файла');
            exit;
          end;
        end;
        fileName := dlgFileName;
        setFileNameAndSize;
        setWindowTitle;
        MessageBox.Show('Сохранено в файл "' + fileName + '".', self.name);
      end
    end;

    /// Разрешить/запретить редактирование изображения
    procedure toggleEdit;
    begin
      edit := not edit;
      setWindowTitle;
    end;

    /// выполнить тесты производительности
    procedure performanceTests;
    begin
      task := test;
      // тест 1 (без рисования)
      try
        vp.loadPicture(initFileName);
      except
        on e: Exception do
        begin
          MessageBox.Show(e.Message, 'Ошибка при загрузке файла');
          task := noTask;
          exit;
        end;
      end;
      edit := false;
      fileName := initFileName;
      skipFrames := 0;
      vp.scaleTo1;
      window.Title := 'Тест 1 запущен...';
      Milliseconds;
      loop 1000 do
        vp.nextGeneration(false);
      var t1 := MillisecondsDelta;
      // тест 2 (с рисованием)
      Application.DoEvents;
      name := 'Тест 2 запущен...';
      vp.loadPicture(initFileName);
      stop := false;
      setWindowTitle;
      Milliseconds;
      loop 1000 do
      begin
        vp.nextGeneration;
        setWindowTitle;
        Application.DoEvents;
      end;
      var t2 := MillisecondsDelta;
      // тест 3 (полная перерисовка - Viewport.draw)
      name := 'Тест 3 запущен...';
      stop := true;
      setWindowTitle;
      Milliseconds;
      loop 100 do
      begin
        vp.draw;
        Application.DoEvents;
      end;
      var t3 := MillisecondsDelta;
      setFileNameAndSize;
      setWindowTitle;
      MessageBox.Show(
        'Тест 1 (1000 поколений без рисования) : ' + t1 / 1000 + ' с' + #10 +
        'Тест 2 (1000 поколений с рисованием)  : ' + t2 / 1000 + ' с' + #10 +
        'Тест 3 (100 полных перерисовок)       : ' + t3 / 1000 + ' с' + #10 +
        'Скорость без рисования : ' + 60000000 div t1 + ' поколений в минуту' + #10 +
        'Скорость с рисованием  : ' + 60000000 div t2 + ' поколений в минуту' + #10 +
        'Скорость п.перерисовки : ' + 6000000 div t3 +
        ' кадров в минуту (' + round(100000 / t3, 2) + ' к/с)' +  #10,
        'Результаты тестов производительности');
      task := noTask;
    end;

    /// обработчик мышки
    procedure mouseDown(x, y, mb: integer);
    begin
      if task <> noTask then
        exit;
      if stop then
      begin
        if checkEdit then
        begin
          vp.mouseDown(x, y, mb);
          setWindowTitle;
        end;
      end;
    end;

    /// обработчик клавиатуры
    procedure keyDown(k: integer);
    begin
      if task <> noTask then
        exit;
      case k of
        VK_F1: help;
        VK_Space: play;
        VK_Add: incSkipFrames;
        VK_Subtract: decSkipFrames;
        VK_PageUp: scaleUp;
        VK_PageDown: scaleDown;
        VK_Up: vp.move(0, vp.maxCellSize);
        VK_Down: vp.move(0, -vp.maxCellSize);
        VK_Left: vp.move(vp.maxCellSize, 0);
        VK_Right: vp.move(-vp.maxCellSize, 0);
        VK_Home: scaleTo1;
        VK_End: autoScale;
      end;
      if stop then
        case k of
          VK_Enter: nextGeneration;
          VK_Delete: clear;
          VK_Back: clearSignals;
          VK_Insert: reloadPicture;
          VK_F2: loadPicture;
          VK_F3: savePicture;
          VK_F4: toggleEdit;
          VK_F12: performanceTests;
        end
    end;

    /// обработчик изменения размера окна
    procedure resize;
    begin
      vp.resize;
    end;

    /// цикл для основного потока
    procedure mainThreadLoop;
    begin
      // Из-за особенностей реализации модуля GraphABC диалоги открытия и
      // сохранения файлов могут быть запущены только из основного потока
      var ofn := new OpenFileDialog;
      ofn.DefaultExt := '.gif';
      ofn.Filter := 'Изображения GIF (*.gif)|*.gif';
      var sfn := new SaveFileDialog;
      sfn.DefaultExt := ofn.DefaultExt;
      sfn.Filter := ofn.Filter;
      while true do
      begin
        sleep(100);
        if task = fileOpen then
        begin
          dlgFileName := string.Empty;
          ofn.FileName := string.Empty;
          ofn.InitialDirectory := ExtractFileDir(fileName);
          if DialogResult.OK = ofn.ShowDialog then
            dlgFileName := ofn.FileName;
          task := noTask;
        end
        else if task = fileSave then
        begin
          dlgFileName := string.Empty;
          sfn.FileName := string.Empty;
          sfn.InitialDirectory := ExtractFileDir(fileName);
          if DialogResult.OK = sfn.ShowDialog then
            dlgFileName := sfn.FileName;
          task := noTask;
        end;
      end;
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
  ctrl := new Control;
  OnMouseDown := mouseDown;
  OnKeyDown := keyDown;
  OnResize := resize;
  ctrl.mainThreadLoop;
end.
