unit MapEditor;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Objects, FMX.Edit, FMX.Controls.Presentation, FMX.Surfaces, Math,
  FMX.ListBox;

type
  TForm2 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Image1: TImage;
    Panel1: TPanel;
    Label1: TLabel;
    ComboBox1: TComboBox;
    procedure UpdateMap();
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure Image1MouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure ComboBox1Change(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

type
  arr = array of string;
  arr3 = array of longint;
  arr2 = array [0 .. 1] of longint;

var
  Form2: TForm2;
  SelectInd: longint;

implementation

{$R *.fmx}

uses WKEditor;

procedure TForm2.UpdateMap();
var
  b: TBitmapSurface;
  LTX, LTY, RBX, RBY, i, j, X, Y, k: longint;
begin
  try
    LTX := 0;
    LTY := 0;
    RBX := 0;
    RBY := 0;
    b := TBitmapSurface.Create();
    for i := 0 to MapIni.ReadInteger('Count', 'road horizontal', 0) - 1 do
    begin
      LTX := min(LTX, min(MapIni.ReadInteger('RH:' + i.ToString, 'Pos2', 0),
        MapIni.ReadInteger('RH:' + i.ToString, 'Pos3', 0)));
      LTY := min(LTY, MapIni.ReadInteger('RH:' + i.ToString, 'Pos1', 0));
      RBX := max(RBX, max(MapIni.ReadInteger('RH:' + i.ToString, 'Pos2', 0),
        MapIni.ReadInteger('RH:' + i.ToString, 'Pos3', 0)));
      RBY := max(RBY, MapIni.ReadInteger('RH:' + i.ToString, 'Pos1', 0));
    end;
    for i := 0 to MapIni.ReadInteger('Count', 'road vertical', 0) - 1 do
    begin
      LTX := min(LTX, MapIni.ReadInteger('RV:' + i.ToString, 'Pos1', 0));
      LTY := min(LTY, min(MapIni.ReadInteger('RV:' + i.ToString, 'Pos2', 0),
        MapIni.ReadInteger('RV:' + i.ToString, 'Pos3', 0)));
      RBX := max(RBX, MapIni.ReadInteger('RV:' + i.ToString, 'Pos1', 0));
      RBY := max(RBY, min(MapIni.ReadInteger('RV:' + i.ToString, 'Pos2', 0),
        MapIni.ReadInteger('RV:' + i.ToString, 'Pos3', 0)));
    end;
    for i := 0 to MapIni.ReadInteger('Count', 'Room', 0) - 1 do
    begin
      LTX := min(LTX, min(MapIni.ReadInteger('Room:' + i.ToString, 'Pos1', 0),
        MapIni.ReadInteger('Room:' + i.ToString, 'Pos3', 0)));
      LTY := min(LTY, min(MapIni.ReadInteger('Room:' + i.ToString, 'Pos2', 0),
        MapIni.ReadInteger('Room:' + i.ToString, 'Pos4', 0)));
      RBX := max(RBX, max(MapIni.ReadInteger('Room:' + i.ToString, 'Pos1', 0),
        MapIni.ReadInteger('Room:' + i.ToString, 'Pos3', 0)));
      RBY := max(RBY, max(MapIni.ReadInteger('Room:' + i.ToString, 'Pos2', 0),
        MapIni.ReadInteger('Room:' + i.ToString, 'Pos4', 0)));
    end;
    LTX := LTX - 14;
    LTY := LTY - 14;
    RBX := RBX + 15;
    RBY := RBY + 15;
    b.SetSize(RBX - LTX, RBX - LTX);
    b.Clear($FFFFFFFF);
    for i := 0 to MapIni.ReadInteger('Count', 'Room', 0) - 1 do
      for X := MapIni.ReadInteger('Room:' + i.ToString, 'Pos1', 0) +
        1 to MapIni.ReadInteger('Room:' + i.ToString, 'Pos3', 0) - 1 do
        for Y := MapIni.ReadInteger('Room:' + i.ToString, 'Pos2', 0) +
          1 to MapIni.ReadInteger('Room:' + i.ToString, 'Pos4', 0) - 1 do
        begin
          b.Pixels[X - LTX, Y - LTY] := $FF00FF00;
        end;
    for i := 0 to MapIni.ReadInteger('Count', 'road horizontal', 0) - 1 do
      for X := MapIni.ReadInteger('RH:' + i.ToString, 'Pos2', 0)
        to MapIni.ReadInteger('RH:' + i.ToString, 'Pos3', 0) do
      begin
        b.Pixels[X - LTX, MapIni.ReadInteger('RH:' + i.ToString, 'Pos1', 0) -
          LTY] := $FF00C800;

        if X = (MapIni.ReadInteger('RH:' + i.ToString, 'Pos2', 0) +
          MapIni.ReadInteger('RH:' + i.ToString, 'Pos3', 0)) div 2 then
          if MapIni.ReadString('RH:' + i.ToString, 'dor', '') <> '' then
          begin
            b.Pixels[X - LTX, MapIni.ReadInteger('RH:' + i.ToString, 'Pos1', 0)
              - LTY] := $FF0000FF;
            for k := 0 to TaskIni.ReadInteger('Count', 'tasks', 0) - 1 do
              if TaskIni.ReadString('Task:' + k.ToString, 'name', '')
                = MapIni.ReadString('RH:' + i.ToString, 'dor', '') then
                b.Pixels[X - LTX, MapIni.ReadInteger('RH:' + i.ToString, 'Pos1', 0)
                  - LTY] := $FF0000FF-k;
          end;
      end;
    for i := 0 to MapIni.ReadInteger('Count', 'road vertical', 0) - 1 do
      for Y := MapIni.ReadInteger('RV:' + i.ToString, 'Pos2', 0)
        to MapIni.ReadInteger('RV:' + i.ToString, 'Pos3', 0) do
      begin
        b.Pixels[MapIni.ReadInteger('RV:' + i.ToString, 'Pos1', 0) - LTX,
          Y - LTY] := $FF00C800;

        if Y = (MapIni.ReadInteger('RV:' + i.ToString, 'Pos2', 0) +
          MapIni.ReadInteger('RV:' + i.ToString, 'Pos3', 0)) div 2 then
          if MapIni.ReadString('RV:' + i.ToString, 'dor', '') <> '' then
          begin
            b.Pixels[MapIni.ReadInteger('RV:' + i.ToString, 'Pos1', 0) - LTX,
              Y - LTY] := $FF0000FF;
            for k := 0 to TaskIni.ReadInteger('Count', 'tasks', 0) - 1 do
              if TaskIni.ReadString('Task:' + k.ToString, 'name', '')
                = MapIni.ReadString('RV:' + i.ToString, 'dor', '') then
                b.Pixels[MapIni.ReadInteger('RV:' + i.ToString, 'Pos1', 0) -
                  LTX, Y - LTY] := $FF0000FF - k;
          end;
      end;
    for i := 0 to MapIni.ReadInteger('Count', 'dollar', 0) - 1 do
    begin
      b.Pixels[MapIni.ReadInteger('D:' + i.ToString, 'Pos1', 0) - LTX,
        MapIni.ReadInteger('D:' + i.ToString, 'Pos2', 0) - LTY] := $FF000000;
    end;
    b.Pixels[0 - LTX, 0 - LTY] := $FFFF0000;

    Image1.Bitmap.Assign(b);
  finally
    b.Free;
  end;
end;

procedure TForm2.Button1Click(Sender: TObject);
begin
  UpdateMap();
  Image1.Bitmap.SaveToFile('map.png');
end;

procedure TForm2.Button2Click(Sender: TObject);
var
  b: TBitmapSurface;
  LoadImg: TImage;
  map: array of arr;
  dbl_arr: array of arr3;
  arr_dollars: array of arr2;
  ppoint: arr2;
  oth: array of arr2;
  Y, X, i, j, summ, el_x, el_y, x2, x3, y2, y3: longint;
  isdor: string;
  red, green, blue, alpha: byte;
begin
  if MessageDlg('Вы уверены? (МОГУТ быть потеряны названия задач)',
    TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0) = mrNo
  then
    exit;
  isRed[0] := true;
  try
    LoadImg := TImage.Create(nil);
    LoadImg.Bitmap.LoadFromFile('map.png');
    b := TBitmapSurface.Create();
    b.Assign(LoadImg.Bitmap);
    SetLength(map, b.Height);
    SetLength(arr_dollars, 0);
    ppoint[0] := -10000;
    ppoint[1] := -10000;
    MapIni.Clear();

    for Y := 0 to b.Height - 1 do
    begin
      SetLength(map[Y], b.Width);
      for X := 0 to b.Width - 1 do
      begin
        map[Y][X] := '_';

        red := TAlphaColorRec(b.Pixels[X, Y]).R;
        green := TAlphaColorRec(b.Pixels[X, Y]).G;
        blue := TAlphaColorRec(b.Pixels[X, Y]).b;
        alpha := TAlphaColorRec(b.Pixels[X, Y]).A;
        if (alpha < 128) then
        begin
          red := 255;
          green := 255;
          blue := 255;
          b.Pixels[X, Y] := $FFFFFFFF;
        end;
        if ((red > 128) and (green > 128)) and (blue > 128) then
        begin
          continue; // белый
        end;
        if ((red < 128) and (green < 128)) and (blue < 128) then
        begin
          red := 0; // чёрный, доллар
          green := 255;
          blue := 0;
          b.Pixels[X, Y] := $FF00FF00;
          SetLength(arr_dollars, length(arr_dollars) + 1);
          arr_dollars[High(arr_dollars)][0] := X;
          arr_dollars[High(arr_dollars)][1] := Y;
        end;
        if ((red < 128) and (green < 128)) and (blue > 128) then
        begin
          b.Pixels[X, Y] := $FF00FF00-((255-blue)mod 126)*256;
          red := TAlphaColorRec(b.Pixels[X, Y]).R; // синий, дверь
          green := TAlphaColorRec(b.Pixels[X, Y]).G;
          blue := TAlphaColorRec(b.Pixels[X, Y]).b;
          map[Y, X] := 'D';
        end;
        if ((red > 128) and (green < 128)) and (blue < 128) then
        begin
          red := 0; // красный, нулевая точка
          green := 255;
          blue := 0;
          b.Pixels[X, Y] := $FF00FF00;
          if (ppoint[0] = -10000) and (ppoint[1] = -10000) then
          begin
            ppoint[0] := X;
            ppoint[1] := Y;
          end
          else
            ShowMessage('Есть две точки входа!!!');
        end;
      end;
    end;
    for Y := 0 to b.Height - 1 do
      for X := 0 to b.Width - 1 do
      begin
        red := TAlphaColorRec(b.Pixels[X, Y]).R;
        green := TAlphaColorRec(b.Pixels[X, Y]).G;
        blue := TAlphaColorRec(b.Pixels[X, Y]).b;
        if ((red < 128) and (green > 128)) and (blue < 128) then
        begin
          // зелёный, комната или дорога
          summ := 0;
          if (X - 1 >= 0) and
            (((TAlphaColorRec(b.Pixels[X - 1, Y]).R < 128) and
            (TAlphaColorRec(b.Pixels[X - 1, Y]).G > 128)) and
            (TAlphaColorRec(b.Pixels[X - 1, Y]).b < 128)) then
            summ := summ + 1000;
          if (Y - 1 >= 0) and
            (((TAlphaColorRec(b.Pixels[X, Y - 1]).R < 128) and
            (TAlphaColorRec(b.Pixels[X, Y - 1]).G > 128)) and
            (TAlphaColorRec(b.Pixels[X, Y - 1]).b < 128)) then
            summ := summ + 100;
          if (X + 1 < b.Width) and
            (((TAlphaColorRec(b.Pixels[X + 1, Y]).R < 128) and
            (TAlphaColorRec(b.Pixels[X + 1, Y]).G > 128)) and
            (TAlphaColorRec(b.Pixels[X + 1, Y]).b < 128)) then
            summ := summ + 10;
          if (Y + 1 < b.Height) and
            (((TAlphaColorRec(b.Pixels[X, Y + 1]).R < 128) and
            (TAlphaColorRec(b.Pixels[X, Y + 1]).G > 128)) and
            (TAlphaColorRec(b.Pixels[X, Y + 1]).b < 128)) then
            summ := summ + 1;
          if (summ = 101) then
          begin
            if (map[Y, X] <> 'D') then
              map[Y, X] := 'V'
            else
              map[Y, X] := 'DV';
          end
          else if (summ = 1010) then
          begin
            if (map[Y, X] <> 'D') then
              map[Y, X] := 'H'
            else
              map[Y, X] := 'DH';
          end
          else
            map[Y][X] := 'R';
        end;
      end;
    SetLength(dbl_arr, b.Height);
    for Y := 0 to b.Height - 1 do
    begin
      SetLength(dbl_arr[Y], b.Width);
      for X := 0 to b.Width - 1 do
        if (map[Y, X] = '_') then
          dbl_arr[Y, X] := 1000000000
        else
          dbl_arr[Y, X] := 0;
    end;
    SetLength(oth, 1);
    oth[0][0] := ppoint[0];
    oth[0][1] := ppoint[1];
    while (length(oth) > 0) do
    begin
      el_x := oth[High(oth)][0];
      el_y := oth[High(oth)][1];
      SetLength(oth, length(oth) - 1);
      if (el_x + 1 < b.Width) and (dbl_arr[el_y][el_x + 1] <> 0) then
        dbl_arr[el_y][el_x] := min(dbl_arr[el_y][el_x],
          dbl_arr[el_y][el_x + 1] + 1);
      if (el_y + 1 < b.Height) and (dbl_arr[el_y + 1][el_x] <> 0) then
        dbl_arr[el_y][el_x] := min(dbl_arr[el_y][el_x],
          dbl_arr[el_y + 1][el_x] + 1);
      if (el_x - 1 >= 0) and (dbl_arr[el_y][el_x - 1] <> 0) then
        dbl_arr[el_y][el_x] := min(dbl_arr[el_y][el_x],
          dbl_arr[el_y][el_x - 1] + 1);
      if (el_y - 1 >= 0) and (dbl_arr[el_y - 1][el_x] <> 0) then
        dbl_arr[el_y][el_x] := min(dbl_arr[el_y][el_x],
          dbl_arr[el_y - 1][el_x] + 1);
      if (el_x + 1 < b.Width) and (dbl_arr[el_y][el_x + 1] = 0) then
      begin
        dbl_arr[el_y][el_x + 1] := dbl_arr[el_y][el_x] + 1;
        SetLength(oth, length(oth) + 1);
        oth[High(oth)][0] := el_x + 1;
        oth[High(oth)][1] := el_y;
      end;
      if (el_y + 1 < b.Height) and (dbl_arr[el_y + 1][el_x] = 0) then
      begin
        dbl_arr[el_y + 1][el_x] := dbl_arr[el_y][el_x] + 1;
        SetLength(oth, length(oth) + 1);
        oth[High(oth)][0] := el_x;
        oth[High(oth)][1] := el_y + 1;
      end;
      if (el_x - 1 >= 0) and (dbl_arr[el_y][el_x - 1] = 0) then
      begin
        dbl_arr[el_y][el_x - 1] := dbl_arr[el_y][el_x] + 1;
        SetLength(oth, length(oth) + 1);
        oth[High(oth)][0] := el_x - 1;
        oth[High(oth)][1] := el_y;
      end;
      if (el_y - 1 >= 0) and (dbl_arr[el_y - 1][el_x] = 0) then
      begin
        dbl_arr[el_y - 1][el_x] := dbl_arr[el_y][el_x] + 1;
        SetLength(oth, length(oth) + 1);
        oth[High(oth)][0] := el_x;
        oth[High(oth)][1] := el_y - 1;
      end;
    end;
    MapIni.WriteInteger('Count', 'road horizontal', 0);
    for Y := 0 to b.Height - 1 do
      for X := 0 to b.Width - 1 do
        if (map[Y][X] = 'H') or (map[Y][X] = 'DH') then
        begin
          x2 := X;
          isdor := '';
          while (x2 < b.Width) and
            ((map[Y][x2] = 'H') or (map[Y][x2] = 'DH')) do
            if (map[Y][x2] = 'H') then
              x2 := x2 + 1
            else
            begin
              red := TAlphaColorRec(b.Pixels[x2, Y]).R;
              green := TAlphaColorRec(b.Pixels[x2, Y]).G;
              blue := TAlphaColorRec(b.Pixels[x2, Y]).b;
              if (((red < 128) and (green > 128)) and (blue  < 128)) and (255-green<=TaskIni.ReadInteger('Count', 'tasks', 0) - 1) then
                isdor := TaskIni.ReadString('Task:' + (255-green).ToString, 'name', '')
              else
                isdor := 'open_' + IntToStr(dbl_arr[Y][x2]) + '_blocks';
              x2 := x2 + 1;
            end;
          x2 := x2 - 1;
          for x3 := X to x2 do
          begin
            map[min(max(Y - 1, 0), b.Height - 1)][x3] := '_';
            map[min(max(Y, 0), b.Height - 1)][x3] := '_';
            map[min(max(Y + 1, 0), b.Height - 1)][x3] := '_';
          end;
          MapIni.WriteInteger('RH:' + IntToStr(MapIni.ReadInteger('Count',
            'road horizontal', 0)), 'Pos1', Y - ppoint[1]);
          MapIni.WriteInteger('RH:' + IntToStr(MapIni.ReadInteger('Count',
            'road horizontal', 0)), 'Pos2', X - ppoint[0]);
          MapIni.WriteInteger('RH:' + IntToStr(MapIni.ReadInteger('Count',
            'road horizontal', 0)), 'Pos3', x2 - ppoint[0]);
          if isdor <> '' then
            MapIni.WriteString('RH:' + IntToStr(MapIni.ReadInteger('Count',
              'road horizontal', 0)), 'dor', isdor);
          MapIni.WriteInteger('Count', 'road horizontal',
            MapIni.ReadInteger('Count', 'road horizontal', 0) + 1);
        end;
    MapIni.WriteInteger('Count', 'road vertical', 0);
    for Y := 0 to b.Height - 1 do
      for X := 0 to b.Width - 1 do
        if (map[Y][X] = 'V') or (map[Y][X] = 'DV') then
        begin
          y2 := Y;
          isdor := '';
          while (y2 < b.Height) and
            ((map[y2][X] = 'V') or (map[y2][X] = 'DV')) do
            if (map[y2][X] = 'V') then
              y2 := y2 + 1
            else
            begin
              red := TAlphaColorRec(b.Pixels[X, y2]).R;
              green := TAlphaColorRec(b.Pixels[X, y2]).G;
              blue := TAlphaColorRec(b.Pixels[X, y2]).b;
              if (((red < 128) and (green > 128)) and (blue  < 128)) and (255-green<=TaskIni.ReadInteger('Count', 'tasks', 0) - 1) then
                isdor := TaskIni.ReadString('Task:' + (255-green).ToString, 'name', '')
              else
                isdor := 'open_' + IntToStr(dbl_arr[y2][X]) + '_blocks';
              y2 := y2 + 1;
            end;
          y2 := y2 - 1;
          for y3 := Y to y2 do
          begin
            map[y3][min(max(X - 1, 0), b.Width - 1)] := '_';
            map[y3][min(max(X, 0), b.Width - 1)] := '_';
            map[y3][min(max(X + 1, 0), b.Width - 1)] := '_';
          end;
          MapIni.WriteInteger('RV:' + IntToStr(MapIni.ReadInteger('Count',
            'road vertical', 0)), 'Pos1', X - ppoint[0]);
          MapIni.WriteInteger('RV:' + IntToStr(MapIni.ReadInteger('Count',
            'road vertical', 0)), 'Pos2', Y - ppoint[1]);
          MapIni.WriteInteger('RV:' + IntToStr(MapIni.ReadInteger('Count',
            'road vertical', 0)), 'Pos3', y2 - ppoint[1]);
          if isdor <> '' then
            MapIni.WriteString('RV:' + IntToStr(MapIni.ReadInteger('Count',
              'road vertical', 0)), 'dor', isdor);
          MapIni.WriteInteger('Count', 'road vertical',
            MapIni.ReadInteger('Count', 'road vertical', 0) + 1);
        end;
    MapIni.WriteInteger('Count', 'Room', 0);
    for Y := 0 to b.Height - 1 do
      for X := 0 to b.Width - 1 do
        if (map[Y][X] = 'R') then
        begin
          x2 := X;
          while (x2 < b.Width) and (map[Y][x2] = 'R') do
            x2 := x2 + 1;
          x2 := x2 - 1;
          y2 := Y;
          while (y2 < b.Height) and (map[y2][X] = 'R') do
            y2 := y2 + 1;
          y2 := y2 - 1;
          for y3 := Y - 1 to min(y2 + 1, b.Height) do
            for x3 := X - 1 to min(x2 + 1, b.Width) do
              map[y3][x3] := '_';
          MapIni.WriteInteger('Room:' + IntToStr(MapIni.ReadInteger('Count',
            'Room', 0)), 'Pos1', X - 1 - ppoint[0]);
          MapIni.WriteInteger('Room:' + IntToStr(MapIni.ReadInteger('Count',
            'Room', 0)), 'Pos2', Y - 1 - ppoint[1]);
          MapIni.WriteInteger('Room:' + IntToStr(MapIni.ReadInteger('Count',
            'Room', 0)), 'Pos3', x2 + 1 - ppoint[0]);
          MapIni.WriteInteger('Room:' + IntToStr(MapIni.ReadInteger('Count',
            'Room', 0)), 'Pos4', y2 + 1 - ppoint[1]);
          MapIni.WriteInteger('Count', 'Room', MapIni.ReadInteger('Count',
            'Room', 0) + 1);
        end;
    MapIni.WriteInteger('Count', 'dollar', length(arr_dollars));
    for i := 0 to length(arr_dollars) - 1 do
    begin
      MapIni.WriteInteger('D:' + IntToStr(i), 'Pos1',
        arr_dollars[i][0] - ppoint[0]);
      MapIni.WriteInteger('D:' + IntToStr(i), 'Pos2',
        arr_dollars[i][1] - ppoint[1]);
      MapIni.WriteInteger('D:' + IntToStr(i), 'getit', -1);
    end;
    SelectInd := -1;
    ComboBox1.Items.Clear;
    ComboBox1.ItemIndex := -1;
    UpdateMap();
    // MapIni.UpdateFile;
  finally
    b.Free;
    LoadImg.Free;
  end;
end;

procedure TForm2.ComboBox1Change(Sender: TObject);
begin
  if SelectInd <> -1 then
  begin
    if SelectInd mod 2 = 0 then
    begin
    MapIni.WriteString('RH:' + IntToStr(SelectInd div 2), 'dor', TaskIni.ReadString('Task:' + ComboBox1.ItemIndex.ToString, 'name', ''))

    end
    else
    begin
    MapIni.WriteString('RV:' + IntToStr(SelectInd div 2), 'dor', TaskIni.ReadString('Task:' + ComboBox1.ItemIndex.ToString, 'name', ''))


    end;
    UpdateMap();
  end;
end;

procedure TForm2.FormShow(Sender: TObject);
begin
  UpdateMap();
end;

procedure TForm2.Image1MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
var
  b: TBitmapSurface;
  i, j, LTX, LTY, needX, needY, bestInd: longint;
  maxR: extended;
begin
  b := TBitmapSurface.Create();
  b.Assign(Image1.Bitmap);
  for j := 0 to b.Height - 1 do
    for i := 0 to b.Width - 1 do
      if b.Pixels[i, j] = $FFFF0000 then
      begin
        LTX := i;
        LTY := j;
      end;
  needX := round(X / Image1.Width * b.Width) - LTX;
  needY := round(Y / Image1.Height * b.Height) - LTY;
  bestInd := -1;
  maxR := 1000000000000;
  for j := 0 to MapIni.ReadInteger('Count', 'road horizontal', 0) - 1 do
  begin
    i := (MapIni.ReadInteger('RH:' + j.ToString, 'Pos2', 0) +
      MapIni.ReadInteger('RH:' + j.ToString, 'Pos3', 0)) div 2;
    if MapIni.ReadString('RH:' + j.ToString, 'dor', '') <> '' then
      if maxR > power(MapIni.ReadInteger('RH:' + j.ToString, 'Pos1', 0) - needY,
        2) + power(i - needX, 2) then
      begin
        maxR := power(MapIni.ReadInteger('RH:' + j.ToString, 'Pos1', 0) - needY,
          2) + power(i - needX, 2);
        bestInd := j * 2;
      end;
  end;
  for j := 0 to MapIni.ReadInteger('Count', 'road vertical', 0) - 1 do
  begin
    i := (MapIni.ReadInteger('RV:' + j.ToString, 'Pos2', 0) +
      MapIni.ReadInteger('RV:' + j.ToString, 'Pos3', 0)) div 2;
    if MapIni.ReadString('RV:' + j.ToString, 'dor', '') <> '' then
      if maxR > power(MapIni.ReadInteger('RV:' + j.ToString, 'Pos1', 0) - needX,
        2) + power(i - needY, 2) then
      begin
        maxR := power(MapIni.ReadInteger('RV:' + j.ToString, 'Pos1', 0) - needX,
          2) + power(i - needY, 2);
        bestInd := j * 2 + 1;
      end;
  end;
  if maxR < 1.5 * 1.5 then
  begin
    SelectInd := -1;
    ComboBox1.Items.Clear;
    ComboBox1.ItemIndex := 0;
    for i := 0 to TaskIni.ReadInteger('Count', 'tasks', 0) - 1 do
    begin
      ComboBox1.Items.Add(TaskIni.ReadString('Task:' + i.ToString, 'name', ''));
      if bestInd mod 2 = 0 then
      begin
       // ShowMessage( MapIni.ReadString('RH:' + IntToStr(bestInd div 2),'dor', ' '));
        if TaskIni.ReadString('Task:' + i.ToString, 'name', '')
          = MapIni.ReadString('RH:' + IntToStr(bestInd div 2),'dor', ' ')
        then
          ComboBox1.ItemIndex := i;

      end
      else
      begin
        if TaskIni.ReadString('Task:' + i.ToString, 'name', '')
          = MapIni.ReadString('RV:' + IntToStr(bestInd div 2),'dor', ' ')
        then
          ComboBox1.ItemIndex := i;
      end;

    end;
    SelectInd := bestInd;
    ComboBox1Change(nil);
  end;
end;

end.
