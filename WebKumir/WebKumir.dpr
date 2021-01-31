program WebKumir;
{$APPTYPE CONSOLE}
{$R *.dres}

uses
  Windows,
  SysUtils,
  Types,
  Classes,
  IdHTTPServer,
  IdCustomHTTPServer,
  IdContext,
  System.Zip,
  IdStack,
  ShellApi,
  IOUtils,
  IdHashMessageDigest,
  System.Threading,
  IniFiles,
  DateUtils,
  Math,
  IdGlobal,
  IdURI;

Type
  TCommandHandler = class
  protected
    procedure CommandGet(AThread: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
      AResponseInfo: TIdHTTPResponseInfo);
  end;
{$R *.res}

type

  TProgram = class
  public
    programm: string;
    exit_data: string;
    res: string;
    task: integer;
    date: int64;
  end;

  Aarraofint = array of longint;

  TPlayer = class
  public
    name: string;
    password: string;
    posx: int64;
    posy: int64;
    PFile: string;
    PFileName: string;
    isAdmin: boolean;
    Pers: Array [0 .. 5] of longint;
    Dors: array of boolean;
    Scores: int64;
    Fine: int64;
    LastProg: string;
    // Progs: string;
    // kumirprogs: Aarraofint;
    programs: array of TProgram;
  end;

var
  Server: TIdHTTPServer;
  CH: TCommandHandler;
  command: string;
  LoadDirectory: string;
  Players: Array Of TPlayer;
  reserv: array of TMemIniFile;
  blacklisted: array of string;
  tasks: array of string;
  map: TMemIniFile;
  ips: TStringList;
  // ProgremNum: longint = 0;

function md5(s: string): string;
begin
  Result := '';
  with TIdHashMessageDigest5.Create do
    try
      Result := AnsiLowerCase(HashStringAsHex(s));
    finally
      Free;
    end;
end;

function ExtractOnlyFileName(const FileName: string): string;
begin
  Result := StringReplace(ExtractFileName(FileName),
    ExtractFileExt(FileName), '', []);
end;

function RegistrationHash(a, b: string): string;
begin
  Result := md5('Hash:' + a + ';Password:' + b + ';');
end;

function DorIsOpen(a: TPlayer; s: string): boolean;
var
  i: longint;
begin
  for i := Low(tasks) to High(tasks) do
    if tasks[i] = s then
    begin
      if a.Dors[i] then
        Result := true
      else
        Result := false;
      exit;
    end;
  Result := false;
end;

procedure DorClose(a: TPlayer; s: string);
var
  i: longint;
begin
  for i := Low(tasks) to High(tasks) do
    if tasks[i] = s then
    begin
      a.Dors[i] := false;
      exit;
    end;
end;

procedure DorOpen(a: TPlayer; s: string);
var
  i: longint;
begin
  for i := Low(tasks) to High(tasks) do
    if tasks[i] = s then
    begin
      a.Dors[i] := true;
      exit;
    end;
end;

function LoadFileToStr(const FileName: TFileName): String;
var
  LStrings: TStringList;
begin
  LStrings := TStringList.Create;
  try
    LStrings.Loadfromfile(FileName, TEncoding.UTF8);
    Result := LStrings.text;
  finally
    FreeAndNil(LStrings);
  end;
end;

function FileNameToDate(s: String): TDateTime;
var
  FormatSettings: TFormatSettings;
begin
  Result := EncodeDateTime(s.Split(['_'])[0].ToInteger,
    s.Split(['_'])[1].ToInteger, s.Split(['_'])[2].ToInteger,
    s.Split(['_'])[3].ToInteger, s.Split(['_'])[4].ToInteger,
    s.Split(['_'])[5].ToInteger, 0);
end;

function DateToFileName(s: TDateTime): String;
var
  FormatSettings: TFormatSettings;
begin
  FormatSettings.ShortDateFormat := 'yyyy_mm_dd';
  FormatSettings.DateSeparator := '_';
  FormatSettings.LongTimeFormat := 'hh_nn_ss';
  FormatSettings.TimeSeparator := '_';
  Result := DateToStr(s, FormatSettings) + '_' + TimeToStr(s, FormatSettings);
end;

procedure saveini(var ini: TMemIniFile);
var
  i, j: longint;
begin
  ini.WriteInteger('Players', 'count', length(Players));
  for i := 0 to High(Players) do
  begin
    ini.WriteString('Player:' + i.ToString, 'name', Players[i].name);
    ini.WriteString('Player:' + i.ToString, 'password', Players[i].password);
    ini.WriteInteger('Player:' + i.ToString, 'posx', Players[i].posx);
    ini.WriteInteger('Player:' + i.ToString, 'posy', Players[i].posy);
    ini.WriteBool('Player:' + i.ToString, 'isAdmin', Players[i].isAdmin);
    // -------
    for j := 0 to High(tasks) do
      ini.WriteBool('Player:' + i.ToString, 'dors' + j.ToString,
        Players[i].Dors[i]);
    ini.WriteInteger('Player:' + i.ToString, 'personage_skin',
      Players[i].Pers[0]);
    ini.WriteInteger('Player:' + i.ToString, 'personage_hairstyle',
      Players[i].Pers[1]);
    ini.WriteInteger('Player:' + i.ToString, 'personage_eye',
      Players[i].Pers[2]);
    ini.WriteInteger('Player:' + i.ToString, 'personage_shirt',
      Players[i].Pers[3]);
    ini.WriteInteger('Player:' + i.ToString, 'personage_pants',
      Players[i].Pers[4]);
    ini.WriteInteger('Player:' + i.ToString, 'personage_footwear',
      Players[i].Pers[5]);
  end;
end;

procedure Loadini(s: string);
var
  i, g, j: longint;
  instr: boolean;
  mys, ss, lastss: ansistring;
  ini: TMemIniFile;
begin
  // ---------
  mys := LoadFileToStr(ExtractFilePath(ParamStr(0)) + LoadDirectory +
    '\index\task\all.json');
  g := 0;
  instr := false;
  ss := '';
  lastss := '';
  i := 1;
  SetLength(tasks, 0);
  while i <= length(mys) do
  begin
    if mys[i] = '\' then
    begin
      i := i + 2;
      continue;
    end;
    if instr then
    begin
      if (mys[i] = '"') or (mys[i] = '''') then
      begin
        if (g = 2) and (lastss = 'name') then
        begin
          SetLength(tasks, length(tasks) + 1);
          tasks[High(tasks)] := ss;
        end;
        instr := false;
        lastss := ss;
        ss := '';
      end;
      ss := ss + mys[i];
    end
    else
    begin
      if (mys[i] = '[') or (mys[i] = '{') then
        g := g + 1;
      if (mys[i] = '}') or (mys[i] = ']') then
        g := g - 1;
      if (mys[i] = '"') or (mys[i] = '''') then
      begin
        instr := true;
        ss := '';
      end;

    end;
    i := i + 1;
  end;
  // ---------
  ini := TMemIniFile.Create(s);
  for i := Low(Players) to High(Players) do
    Players[i].Free;
  SetLength(Players, ini.ReadInteger('Players', 'count', 0));
  for i := 0 to High(Players) do
  begin
    Players[i] := TPlayer.Create;
    Players[i].name := ini.ReadString('Player:' + i.ToString, 'name', '');
    Players[i].password := ini.ReadString('Player:' + i.ToString,
      'password', '');
    Players[i].posx := ini.ReadInteger('Player:' + i.ToString, 'posx', 0);
    Players[i].posy := ini.ReadInteger('Player:' + i.ToString, 'posy', 0);
    Players[i].isAdmin := ini.ReadBool('Player:' + i.ToString,
      'isAdmin', false);
    // -------
    SetLength(Players[i].Dors, length(tasks));
    for j := 0 to High(tasks) do
      Players[i].Dors[j] := ini.ReadBool('Player:' + i.ToString,
        'dors' + j.ToString, false);
    Players[i].Pers[0] := ini.ReadInteger('Player:' + i.ToString,
      'personage_skin', 50);
    Players[i].Pers[1] := ini.ReadInteger('Player:' + i.ToString,
      'personage_hairstyle', 6);
    Players[i].Pers[2] := ini.ReadInteger('Player:' + i.ToString,
      'personage_eye', 4);
    Players[i].Pers[3] := ini.ReadInteger('Player:' + i.ToString,
      'personage_shirt', 1);
    Players[i].Pers[4] := ini.ReadInteger('Player:' + i.ToString,
      'personage_pants', 2);
    Players[i].Pers[5] := ini.ReadInteger('Player:' + i.ToString,
      'personage_footwear', 4);
  end;
  ini.Free;
  // tasks
end;

procedure SaveAll(isauto: boolean = false);
var
  i: longint;
  adminsave: TMemIniFile;
begin
  if LoadDirectory <> '' then
    if isauto then
    begin
      if High(reserv) > 300 then
      begin
        reserv[0].Free;
        for i := 1 to High(reserv) do
          reserv[i - 1] := reserv[i];
        // SetLength(reserv, 1);
      end
      else
        SetLength(reserv, length(reserv) + 1);
      reserv[High(reserv)] := TMemIniFile.Create(ExtractFilePath(ParamStr(0)) +
        LoadDirectory + '\save\Autosave\' + DateToFileName(Now) + '.ini');
      saveini(reserv[High(reserv)]);
      if High(reserv) mod 120 = 10 then
      begin
        reserv[High(reserv)].UpdateFile;
        map.UpdateFile;
        writeln('Autosave');
      end;
    end
    else
    begin
      adminsave := TMemIniFile.Create(ExtractFilePath(ParamStr(0)) +
        LoadDirectory + '\save\AdminSave\' + DateToFileName(Now) + '.ini');
      saveini(adminsave);
      adminsave.UpdateFile;
      adminsave.Free;
      adminsave := TMemIniFile.Create(ExtractFilePath(ParamStr(0)) +
        LoadDirectory + '\save\defaut.ini');
      saveini(adminsave);
      adminsave.UpdateFile;
      adminsave.Free;
      map.UpdateFile;
    end

end;

function GetIndex(s: string): longint;
var
  i: longint;
begin
  Result := -1;
  for i := Low(Players) to High(Players) do
    if Players[i].name = s then
    begin
      Result := i;
      exit;
    end;
end;

function GetIP: String;
begin
  TIdStack.IncUsage;
  try
    Result := GStack.LocalAddress;
  finally
    TIdStack.DecUsage;
  end;
end;

procedure GetResource(const resname, tosave: string);
var
  stream: TResourceStream;
var
  ZF: TZipFile;
begin
  // if not DirectoryExists(tosave) then
  // ForceDirectories(tosave);
  stream := TResourceStream.Create(HInstance, resname, RT_RCDATA);
  ZF := TZipFile.Create();
  ZF.Open(stream, TZipMode.zmRead);
  ZF.ExtractAll(ExtractFilePath(ParamStr(0)));
  ZF.Close;
  ZF.Free;
  RenameFile(ExtractFilePath(ParamStr(0)) + 'def', tosave);
end;

function InHouse(x, y: int64; n: string): boolean;
var
  i, PlaInd, x1, y1, x2, y2: longint;
begin
  PlaInd := GetIndex(n);
  Result := false;
  for i := 0 to map.ReadInteger('Count', 'Room', 0) - 1 do
  begin
    x1 := map.ReadInteger('Room:' + i.ToString, 'pos1', 0);
    y1 := map.ReadInteger('Room:' + i.ToString, 'pos2', 0);
    x2 := map.ReadInteger('Room:' + i.ToString, 'pos3', 0);
    y2 := map.ReadInteger('Room:' + i.ToString, 'pos4', 0);
    if (x2 > x) and (x > x1) and (y2 > y) and (y > y1) then
    begin
      Result := true;
      exit;
    end;
  end;
  for i := 0 to map.ReadInteger('Count', 'road vertical', 0) - 1 do
  begin
    x1 := map.ReadInteger('RV:' + i.ToString, 'pos1', 0);
    y1 := map.ReadInteger('RV:' + i.ToString, 'pos2', 0);
    y2 := map.ReadInteger('RV:' + i.ToString, 'pos3', 0);

    if y = Floor((y1 + y2) / 2) then
      if map.ReadString('RV:' + i.ToString, 'dor', '') <> '' then
        if not DorIsOpen(Players[PlaInd], map.ReadString('RV:' + i.ToString,
          'dor', '')) then
        begin
          Result := false;
          exit;
        end;

    if (x1 = x) and (y2 >= y) and (y >= y1) then
    begin
      Result := true;
      exit;
    end;
  end;
  for i := 0 to map.ReadInteger('Count', 'road horizontal', 0) - 1 do
  begin
    y1 := map.ReadInteger('RH:' + i.ToString, 'pos1', 0);
    x1 := map.ReadInteger('RH:' + i.ToString, 'pos2', 0);
    x2 := map.ReadInteger('RH:' + i.ToString, 'pos3', 0);

    if x = Floor((x1 + x2) / 2) then
      if map.ReadString('RH:' + i.ToString, 'dor', '') <> '' then
        if not DorIsOpen(Players[PlaInd], map.ReadString('RH:' + i.ToString,
          'dor', '')) then
        begin
          Result := false;
          exit;
        end;

    if (y1 = y) and (x2 >= x) and (x >= x1) then
    begin
      Result := true;
      exit;
    end;
  end;
end;

procedure delElem(var a: Aarraofint; Index: integer);
var
  Last: integer;
begin
  Last := high(a);
  if Index < Last then
    move(a[Index + 1], a[Index], (Last - Index) * sizeof(a[Index]));
  SetLength(a, Last);
end;

function GetSortPlayers(): ansistring;
var
  a, max_time, min_time: array of int64;
  i, j, k, m: longint;
  time: int64;
begin
  SetLength(a, length(tasks));
  SetLength(max_time, length(tasks));
  for i := 0 to High(tasks) do
    max_time[i] := 0;
  SetLength(min_time, length(tasks));
  for i := 0 to High(min_time) do
    min_time[i] := 9223372036854775807;
  Result :='names;scores;fine;';
  for i := 0 to High(tasks) do
    Result:=Result+tasks[i]+';';
  Result := Result+ #13#10;
  for i := 0 to High(Players) do
  begin
    Players[i].Scores := 0;
    for j := 0 to High(Players[i].programs) do
      if Players[i].programs[j].res = 'OK' then
      begin
        inc(a[Players[i].programs[j].task]);
        if (max_time[Players[i].programs[j].task] < Players[i].programs[j].date)
        then
          max_time[Players[i].programs[j].task] := Players[i].programs[j].date;
        if (min_time[Players[i].programs[j].task] > Players[i].programs[j].date)
        then
          min_time[Players[i].programs[j].task] := Players[i].programs[j].date;
        inc(Players[i].Scores, 100);
      end;
  end;
  for i := 0 to High(Players) do
  begin
    Players[i].Fine := 0;
    m := 0;
    for j := 0 to High(Players[i].programs) do
      if Players[i].programs[j].res = 'OK' then
      begin
        m := m + 1;
        time := Players[i].programs[j].date;
        k := Players[i].programs[j].task;
        if (a[Players[i].programs[j].task] <= 1) then
          inc(Players[i].Fine, 1000)
        else
          inc(Players[i].Fine,
            Floor((1 - (time - min_time[k]) / (max_time[k] - min_time[k])) *
            1000 + ((time - min_time[k]) / (max_time[k] - min_time[k])) *
            (250 / a[k] + 750)));

      end;
    Players[i].Fine := m * 1000 - Players[i].Fine;

  end;
  for i := 0 to High(Players) do
  begin
    Result := Result+ Players[i].name+';'+Players[i].Scores.ToString+';'+Players[i].Fine.ToString+';';
    for j := 0 to High(Players[i].Dors) do
      if Players[i].Dors[j] then
        Result := Result+ '100;'
      else
        Result := Result+ '0;';
    Result := Result+ #13#10;
  end;


end;

function SaveServFile(user, s, prog: string): String;
var
  i, j: longint;
  userindex: longint;
begin
  // s = upload;kumir;B1;
  // s = upload;js;2134;
  Result := s;
  if (length(s.Split([';'])) <= 2) then
  begin
    Result := 'error1';
    exit;
  end;
  if (s.Split([';'])[0] <> 'upload') or
    ((s.Split([';'])[1] <> 'res') and (s.Split([';'])[1] <> 'kumir')) then
  begin
    Result := 'error2';
    exit;
  end;

  userindex := GetIndex(user);
  writeln('s = ', s);
  writeln('prog = ', prog);
  if s.Split([';'])[1] = 'kumir' then
  begin
    if DorIsOpen(Players[userindex], s.Split([';'])[2]) then
    begin
      Result := 'Эта задача уже решена';
      exit;
    end;
    If (Players[userindex].LastProg <> prog) then
    begin
      // inc(ProgremNum);
      for i := 0 to High(Players[userindex].programs) do
        if Not((Players[userindex].programs[i].res='OK')or(Players[userindex].programs[i].res[1]='E')) then
        begin
                Result := 'Дождитесь завершения проверки всех задач';
                exit;
        end;
      Players[userindex].LastProg := prog;
      // Players[userindex].Progs := Players[userindex].Progs +
      // ProgremNum.ToString + ';';
      SetLength(Players[userindex].programs,
        length(Players[userindex].programs) + 1);
      Players[userindex].programs[High(Players[userindex].programs)] :=
        TProgram.Create;

      Players[userindex].programs[High(Players[userindex].programs)].programm :=
        TIdURI.URLDecode(StringReplace(prog, '+', ' ',
        [rfReplaceAll, rfIgnoreCase]));
      Players[userindex].programs[High(Players[userindex].programs)].task := -1;
      for i := 0 to High(tasks) do
        if tasks[i] = s.Split([';'])[2] then
          Players[userindex].programs[High(Players[userindex].programs)
            ].task := i;
      if Players[userindex].programs[High(Players[userindex].programs)].task = -1
      then
      begin
        Result := 'Данной задачи не найдено';
        SetLength(Players[userindex].programs,
          length(Players[userindex].programs) - 1);
        exit;
      end;
      Players[userindex].programs[High(Players[userindex].programs)].res
        := 'Queue';
      Players[userindex].programs[High(Players[userindex].programs)].date :=
        DateTimeToUnix(Now());
      // add to 1 stek
      // lol;
      Result := 'Программа отправлена';
    end
    else
      Result := 'Эта программа уже была отправлена';
  end
  else if s.Split([';'])[1] = 'res' then
  begin
    if Players[userindex].isAdmin then
    begin
      if not TryStrToInt(s.Split([';'])[2],i) then
      begin
        Result := 'Except';
        exit;
      end;
      if not TryStrToInt(s.Split([';'])[2],j) then
      begin
        Result := 'Except';
        exit;
      end;

      i := StrToInt(s.Split([';'])[2]) div 10000000;
      j := StrToInt(s.Split([';'])[2]) mod 10000000;
      if Low(Players) > i then
      begin
        Result := 'ProgNotFound';
        exit;
      end;
      if High(Players) < i then
      begin
        Result := 'ProgNotFound';
        exit;
      end;
      if Low(Players[i].programs) > j then
      begin
        Result := 'ProgNotFound';
        exit;
      end;
      if High(Players[i].programs) < j then
      begin
        Result := 'ProgNotFound';
        exit;
      end;

      if prog <> '' then
      begin
        Players[i].programs[j].res := 'Error ' + s.Split([';'])[3];
        Players[i].programs[j].exit_data :=
          TIdURI.URLDecode(StringReplace(prog, '+', ' ',
          [rfReplaceAll, rfIgnoreCase]));
      end
      else
      begin
        Players[i].programs[j].res := 'OK';
        DorOpen(Players[i], tasks[Players[i].programs[j].task]);
      end;
      Result := 'OK';

    end;
  end;
end;

function LoadServFile(user, s: string): String;
var
  i, j: longint;
  userindex: longint;
begin
  userindex := GetIndex(user);
  Result := s;
  if s = 'login' then
    Result := 'OK'
  else if s = 'map' then
  begin
    // Result := LoadFileToStr(ExtractFilePath(ParamStr(0)) + LoadDirectory + '\save\map.txt')
    Result := '{' + #13#10 + '  "rooms": [' + #13#10;
    for i := 0 to map.ReadInteger('Count', 'Room', 0) - 2 do
    begin
      Result := Result + '    {' + #13#10;
      Result := Result + '      "position": [' +
        map.ReadInteger('Room:' + i.ToString, 'pos1', 0).ToString + ',' +
        map.ReadInteger('Room:' + i.ToString, 'pos2', 0).ToString + ',' +
        map.ReadInteger('Room:' + i.ToString, 'pos3', 0).ToString + ',' +
        map.ReadInteger('Room:' + i.ToString, 'pos4', 0).ToString + ']'
        + #13#10;
      Result := Result + '    },' + #13#10;
    end;
    i := map.ReadInteger('Count', 'Room', 0) - 1;
    if i >= 0 then
    begin
      Result := Result + '    {' + #13#10;
      Result := Result + '      "position": [' +
        map.ReadInteger('Room:' + i.ToString, 'pos1', 0).ToString + ',' +
        map.ReadInteger('Room:' + i.ToString, 'pos2', 0).ToString + ',' +
        map.ReadInteger('Room:' + i.ToString, 'pos3', 0).ToString + ',' +
        map.ReadInteger('Room:' + i.ToString, 'pos4', 0).ToString + ']'
        + #13#10;
      Result := Result + '    }' + #13#10;
    end;
    Result := Result + '  ],' + #13#10;
    // ===================================
    Result := Result + '  "road vertical": [' + #13#10;
    for i := 0 to map.ReadInteger('Count', 'road vertical', 0) - 2 do
    begin
      Result := Result + '    {' + #13#10;
      Result := Result + '      "position": [' +
        map.ReadInteger('RV:' + i.ToString, 'pos1', 0).ToString + ',' +
        map.ReadInteger('RV:' + i.ToString, 'pos2', 0).ToString + ',' +
        map.ReadInteger('RV:' + i.ToString, 'pos3', 0).ToString + '],' + #13#10;
      if map.ReadString('RV:' + i.ToString, 'dor', '') = '' then
        Result := Result + '      "dor": "open"' + #13#10
      else if DorIsOpen(Players[userindex], map.ReadString('RV:' + i.ToString,
        'dor', '')) then
        Result := Result + '      "dor": "open"' + #13#10
      else
        Result := Result + '      "dor": "file:' +
          map.ReadString('RV:' + i.ToString, 'dor', '') + '"' + #13#10;
      Result := Result + '    },' + #13#10;
    end;
    i := map.ReadInteger('Count', 'road vertical', 0) - 1;
    if i >= 0 then
    begin
      Result := Result + '    {' + #13#10;
      Result := Result + '      "position": [' +
        map.ReadInteger('RV:' + i.ToString, 'pos1', 0).ToString + ',' +
        map.ReadInteger('RV:' + i.ToString, 'pos2', 0).ToString + ',' +
        map.ReadInteger('RV:' + i.ToString, 'pos3', 0).ToString + '],' + #13#10;
      if map.ReadString('RV:' + i.ToString, 'dor', '') = '' then
        Result := Result + '      "dor": "open"' + #13#10
      else if DorIsOpen(Players[userindex], map.ReadString('RV:' + i.ToString,
        'dor', '')) then
        Result := Result + '      "dor": "open"' + #13#10
      else
        Result := Result + '      "dor": "file:' +
          map.ReadString('RV:' + i.ToString, 'dor', '') + '"' + #13#10;
      Result := Result + '    }' + #13#10;
    end;
    Result := Result + '  ],' + #13#10;
    // ===================================
    Result := Result + '  "road horizontal": [' + #13#10;
    for i := 0 to map.ReadInteger('Count', 'road horizontal', 0) - 2 do
    begin
      Result := Result + '    {' + #13#10;
      Result := Result + '      "position": [' +
        map.ReadInteger('RH:' + i.ToString, 'pos1', 0).ToString + ',' +
        map.ReadInteger('RH:' + i.ToString, 'pos2', 0).ToString + ',' +
        map.ReadInteger('RH:' + i.ToString, 'pos3', 0).ToString + '],' + #13#10;
      if map.ReadString('RH:' + i.ToString, 'dor', '') = '' then
        Result := Result + '      "dor": "open"' + #13#10
      else if DorIsOpen(Players[userindex], map.ReadString('RH:' + i.ToString,
        'dor', '')) then
        Result := Result + '      "dor": "open"' + #13#10
      else
        Result := Result + '      "dor": "file:' +
          map.ReadString('RH:' + i.ToString, 'dor', '') + '"' + #13#10;
      Result := Result + '    },' + #13#10;
    end;
    i := map.ReadInteger('Count', 'road vertical', 0) - 1;
    if i >= 0 then
    begin
      Result := Result + '    {' + #13#10;
      Result := Result + '      "position": [' +
        map.ReadInteger('RH:' + i.ToString, 'pos1', 0).ToString + ',' +
        map.ReadInteger('RH:' + i.ToString, 'pos2', 0).ToString + ',' +
        map.ReadInteger('RH:' + i.ToString, 'pos3', 0).ToString + '],' + #13#10;
      if map.ReadString('RH:' + i.ToString, 'dor', '') = '' then
        Result := Result + '      "dor": "open"' + #13#10
      else if DorIsOpen(Players[userindex], map.ReadString('RH:' + i.ToString,
        'dor', '')) then
        Result := Result + '      "dor": "open"' + #13#10
      else
        Result := Result + '      "dor": "file:' +
          map.ReadString('RH:' + i.ToString, 'dor', '') + '"' + #13#10;
      Result := Result + '    }' + #13#10;
    end;
    Result := Result + '  ]' + #13#10;

    Result := Result + '}';
  end
  else if s = 'move_down' then
  begin
    Result := 'OK';
    if InHouse(Players[userindex].posx, Players[userindex].posy + 1, user) then
      inc(Players[userindex].posy)
    else
      Result := 'STOP';
  end
  else if s = 'move_left' then
  begin
    Result := 'OK';
    if InHouse(Players[userindex].posx - 1, Players[userindex].posy, user) then
      inc(Players[GetIndex(user)].posx, -1)
    else
      Result := 'STOP';
  end
  else if s = 'move_rigth' then
  begin
    Result := 'OK';
    if InHouse(Players[userindex].posx + 1, Players[userindex].posy, user) then
      inc(Players[GetIndex(user)].posx)
    else
      Result := 'STOP';
  end
  else if s = 'move_up' then
  begin
    Result := 'OK';
    if InHouse(Players[userindex].posx, Players[userindex].posy - 1, user) then
      inc(Players[userindex].posy, -1)
    else
      Result := 'STOP';
  end
  else if s = 'getpos' then
  begin
    Result := '{' + #13#10 + '  "count": ' + length(Players).ToString;
    for i := Low(Players) to High(Players) - 1 do
    begin
      Result := Result + ',' + #13#10 + '  "Player:' + i.ToString +
        '": [' + #13#10;
      Result := Result + '    {' + #13#10;
      Result := Result + '      "Name": "' + Players[i].name + '",' + #13#10;
      Result := Result + '      "posx": ' + Players[i].posx.ToString +
        ',' + #13#10;
      Result := Result + '      "posy": ' + Players[i].posy.ToString +
        ',' + #13#10;
      Result := Result + '      "personage1": ' + Players[i].Pers[0].ToString +
        ',' + #13#10;
      Result := Result + '      "personage2": ' + Players[i].Pers[1].ToString +
        ',' + #13#10;
      Result := Result + '      "personage3": ' + Players[i].Pers[2].ToString +
        ',' + #13#10;
      Result := Result + '      "personage4": ' + Players[i].Pers[3].ToString +
        ',' + #13#10;
      Result := Result + '      "personage5": ' + Players[i].Pers[4].ToString +
        ',' + #13#10;
      Result := Result + '      "personage6": ' + Players[i].Pers[5].ToString +
        ',' + #13#10;
      if Players[i].isAdmin then
        Result := Result + '      "isAdmin": "true"' + #13#10
      else
        Result := Result + '      "isAdmin": "false"' + #13#10;
      Result := Result + '    }' + #13#10;
      Result := Result + '  ],' + #13#10;

    end;
    i := High(Players);
    Result := Result + '  "Player:' + i.ToString + '": [' + #13#10;
    Result := Result + '    {' + #13#10;
    Result := Result + '      "Name": "' + Players[i].name + '",' + #13#10;
    Result := Result + '      "posx": ' + Players[i].posx.ToString +
      ',' + #13#10;
    Result := Result + '      "posy": ' + Players[i].posy.ToString +
      ',' + #13#10;
    Result := Result + '      "posy": ' + Players[i].posy.ToString +
      ',' + #13#10;
    Result := Result + '      "personage1": ' + Players[i].Pers[0].ToString +
      ',' + #13#10;
    Result := Result + '      "personage2": ' + Players[i].Pers[1].ToString +
      ',' + #13#10;
    Result := Result + '      "personage3": ' + Players[i].Pers[2].ToString +
      ',' + #13#10;
    Result := Result + '      "personage4": ' + Players[i].Pers[3].ToString +
      ',' + #13#10;
    Result := Result + '      "personage5": ' + Players[i].Pers[4].ToString +
      ',' + #13#10;
    Result := Result + '      "personage6": ' + Players[i].Pers[5].ToString +
      ',' + #13#10;
    if Players[i].isAdmin then
      Result := Result + '      "isAdmin": "true"' + #13#10
    else
      Result := Result + '      "isAdmin": "false"' + #13#10;
    Result := Result + '    }' + #13#10;
    Result := Result + '  ]' +#13#10;
    Result := Result + '}';
  end
  else if (length(s.Split(['EditPersonage'])) > 1) and
    (length(s.Split(['EditPersonage'])[1].Split([';'])) > 5) then
  begin
    Players[userindex].Pers[0] := s.Split(['EditPersonage'])[1].Split([';'])
      [0].ToInteger;
    Players[userindex].Pers[1] := s.Split(['EditPersonage'])[1].Split([';'])
      [1].ToInteger;
    Players[userindex].Pers[2] := s.Split(['EditPersonage'])[1].Split([';'])
      [2].ToInteger;
    Players[userindex].Pers[3] := s.Split(['EditPersonage'])[1].Split([';'])
      [3].ToInteger;
    Players[userindex].Pers[4] := s.Split(['EditPersonage'])[1].Split([';'])
      [4].ToInteger;
    Players[userindex].Pers[5] := s.Split(['EditPersonage'])[1].Split([';'])
      [5].ToInteger;
    Result := 'OK';
  end
  else if (length(s.Split(['Get_my_programs'])) > 1) then
  begin
    Result := '[';
    j := 0;
    for i := High(Players[userindex].programs)
      downto Low(Players[userindex].programs) do
      if tasks[Players[userindex].programs[i].task]
        = s.Split(['Get_my_programs'])[1] then
      begin
        inc(j);
        if j > 50 then
          break;
        Result := Result + '[' + i.ToString() + ',"' + Players[userindex]
          .programs[i].res + '","' + Players[userindex].programs[i]
          .date.ToString + '"]';
        Result := Result + ',';

      end;
    if Result[length(Result)] = ',' then
      delete(Result, length(Result), 1);
    Result := Result + ']';

  end
  else if Players[userindex].isAdmin then
  begin
    { if (length(s.Split(['SendResults'])) > 1) then
      // SendResultsB1;Admin;1;2134  SendResultsB1;Admin;0;2134   SendResultsB1;Admmin;0;2134
      if (length(s.Split(['SendResults'])[1].Split([';'])) > 3) then
      if GetIndex(s.Split(['SendResults'])[1].Split([';'])[1]) <> -1 then
      begin
      if DorIsOpen(Players[GetIndex(s.Split(['SendResults'])[1].Split([';'])
      [1])], s.Split(['SendResults'])[1].Split([';'])[0]) then
      begin
      Result := 'DorIsOpen';
      exit;
      end;
      if s.Split(['SendResults'])[1].Split([';'])[2] = '1' then
      begin
      programs[StrToInt(s.Split(['SendResults'])[1].Split([';'])[3])].res
      := 'Successful';
      inc(Players[GetIndex(s.Split(['SendResults'])[1].Split([';'])[1])
      ].Scores, 10);
      DorOpen(Players[GetIndex(s.Split(['SendResults'])[1].Split([';'])[1]
      )], s.Split(['SendResults'])[1].Split([';'])[0]);
      Result := 'Successful';
      end
      else
      begin
      programs[StrToInt(s.Split(['SendResults'])[1].Split([';'])[3])].res
      := 'Task not completed';
      inc(Players[GetIndex(s.Split(['SendResults'])[1].Split([';'])[1])
      ].Scores, -1);
      Result := 'Task not completed';
      end;
      end
      else
      writeln('User is not found'); }
    if (length(s.Split(['GetFile'])) > 1) then
    begin
      if not FileExists(ExtractFilePath(ParamStr(0)) + LoadDirectory + '\index'
        + StringReplace(s.Split(['GetFile'])[1], '$', '\',
        [rfReplaceAll, rfIgnoreCase])) then
      begin
        Result := '404';
        exit;
      end
      else
      begin
        Result := LoadFileToStr(ExtractFilePath(ParamStr(0)) + LoadDirectory +
          '\index' + StringReplace(s.Split(['GetFile'])[1], '$', '\',
          [rfReplaceAll, rfIgnoreCase]));
        exit;
      end;
    end;
    if (length(s.Split(['GetPrograms'])) > 1) then
    begin
      Result := ';';
      for i := Low(Players) to High(Players) do // 10000000
        for j := Low(Players[i].programs) to High(Players[i].programs) do
          if (Players[i].programs[j].res = 'Queue') or
            (Players[i].programs[j].res = 'Testing') then
          begin
            Result := Result + (i * 10000000 + j).ToString() + ';';
          end;
      exit;
    end;
    if (length(s.Split(['GetProgram'])) > 1) then
    begin
      i := StrToInt(s.Split(['GetProgram'])[1]) div 10000000;
      j := StrToInt(s.Split(['GetProgram'])[1]) mod 10000000;
      if Low(Players) > i then
      begin
        Result := 'ProgNotFound';
        exit;
      end;
      if High(Players) < i then
      begin
        Result := 'ProgNotFound';
        exit;
      end;
      if Low(Players[i].programs) > j then
      begin
        Result := 'ProgNotFound';
        exit;
      end;
      if High(Players[i].programs) < j then
      begin
        Result := 'ProgNotFound';
        exit;
      end;
      Players[i].programs[j].res := 'Testing';
      Result := tasks[Players[i].programs[j].task] + #13#10 + Players[i]
        .programs[j].programm;
      exit;
    end;

    // DorOpen(GetIndex(s.Split(['SendSolution'])[1].Split([';'])[0]),GetIndex(s.Split(['SendSolution'])[1].Split([';'])[1]));

  end;
end;

procedure TCommandHandler.CommandGet(AThread: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  img: boolean;
  i, Index: longint;
var
  stream: TStream;
  s: string;
begin
  // ========= ban list =========
  for i := 0 to length(blacklisted) - 1 do
    If blacklisted[i] = AThread.Binding.PeerIP Then
    begin
      AThread.Connection.Disconnect; // or raise an Exception...
      exit;
    end;
  // ========= ban list =========
  // ========= protect =========
  if length(ARequestInfo.URI) = 0 then
    exit;
  if ARequestInfo.URI[1] <> '/' then
    exit;
  // ========= protect =========
  // ========= ip list =========
  if ips.Values[ARequestInfo.URI + ' ' + AThread.Binding.PeerIP] <> '' then
    ips.Values[ARequestInfo.URI + ' ' + AThread.Binding.PeerIP] :=
      IntToStr(StrToInt(ips.Values[ARequestInfo.URI + ' ' +
      AThread.Binding.PeerIP]) + 1)
  else
    ips.Values[ARequestInfo.URI + ' ' + AThread.Binding.PeerIP] := '1';
  // ========= ip list =========
  if ARequestInfo.command = 'POST' then
  begin
    stream := ARequestInfo.PostStream;
    if assigned(stream) then
    begin
      stream.Position := 0;
      s := ReadStringFromStream(stream);
      // TIdURI.URLDecode(StringReplace(ReadStringFromStream(stream), '+',
      // ' ', [rfReplaceAll, rfIgnoreCase]));
      // if length(ARequestInfo.URI.Split(['upload/'])[1].Split(['kumir/'])) > 1
      // then
      writeln(s);
      // if length(ARequestInfo.URI.Split(['upload/'])[1].Split(['js/'])) > 1
      // then
      // получение решения
    end;
    // exit;
  end;

  // writeln(AThread.Binding.PeerIP);
  if (ARequestInfo.URI = '\') or (ARequestInfo.URI = '/') or
    (ARequestInfo.URI = '') then
  begin
    AResponseInfo.Redirect('\index.html');
    exit;
  end;
  if length(ARequestInfo.URI.Split(['protect/'])) > 1 then
  begin
    AResponseInfo.ContentType := 'text/html; charset=utf-8';
    AResponseInfo.ContentText := '__PrOtEcT_NoT_CoMpLeTeD__';
    for i := Low(Players) to High(Players) do
      if Players[i].PFileName <> '' then
        if Players[i].PFileName + '.txt' = ARequestInfo.URI.Split
          (['protect/'])[1] then
        begin
          if ARequestInfo.command = 'POST' then
          begin
            AResponseInfo.ContentText :=
              SaveServFile(Players[i].PFile.Split(['/', '\'])[0],
              Players[i].PFile.Split(['/', '\'])[1].Split(['.txt'])[0], s);
            // if length(ARequestInfo.URI.Split(['upload/'])[1].Split(['js/'])) > 1
            // then
            // получение решения
          end
          else
            AResponseInfo.ContentText :=
              LoadServFile(Players[i].PFile.Split(['/', '\'])[0],
              Players[i].PFile.Split(['/', '\'])[1].Split(['.txt'])[0]);
          Players[i].PFile := '';
          Players[i].PFileName := '';
          break;
        end;
    exit;
  end;
  if length(ARequestInfo.URI.Split(['commands/'])) > 1 then
    if length(ARequestInfo.URI.Split(['commands/'])[1].Split(['/', '\'])) > 1
    then
    begin
      index := GetIndex(ARequestInfo.URI.Split(['commands/'])
        [1].Split(['/', '\'])[0]);
      if (index = -1) then
        exit;
      AResponseInfo.ContentType := 'text/html; charset=utf-8';
      AResponseInfo.ContentText := md5(FloatToStr(random));
      Players[index].PFileName := RegistrationHash(AResponseInfo.ContentText,
        Players[index].password);
      Players[index].PFile := ARequestInfo.URI.Split(['commands/'])[1];
      exit;
    end;
  if (Pos('__secret_information__', ARequestInfo.URI) > 0) then
  begin
    AResponseInfo.ContentText := '403';
    AResponseInfo.ResponseNo := 403;
    exit;
  end;
  if (Pos('top_data.json', ARequestInfo.URI) > 0) then
  begin
    AResponseInfo.ContentText := GetSortPlayers();

    AResponseInfo.ResponseNo := 200;
    exit;
  end;
  if not FileExists(ExtractFilePath(ParamStr(0)) + LoadDirectory + '\index' +
    ARequestInfo.URI) then
  begin
    AResponseInfo.ContentText := '404';
    AResponseInfo.ResponseNo := 404;
    exit;
  end
  else
    AResponseInfo.ResponseNo := 200;
  if Pos('.PDF', ANSIUPPERCASE(ARequestInfo.Document)) > 0 then
  begin
    AResponseInfo.ContentType := 'application/pdf';
    AResponseInfo.ContentDisposition := 'inline; filename=' +
      ExtractFileName(ExtractFilePath(ParamStr(0)) + LoadDirectory + '\index' +
      ARequestInfo.URI) + ';';
    AResponseInfo.ServeFile(AThread, ExtractFilePath(ParamStr(0)) +
      LoadDirectory + '\index' + ARequestInfo.URI);
    exit;
  end
  else if Pos('.ICO', ANSIUPPERCASE(ARequestInfo.Document)) > 0 then
  begin
    AResponseInfo.ContentType := 'image/x-icon';
    img := true;
  end
  else if Pos('.GIF', ANSIUPPERCASE(ARequestInfo.Document)) > 0 then
  begin
    AResponseInfo.ContentType := 'image/gif';
    img := true;
  end
  else if Pos('.JPG', ANSIUPPERCASE(ARequestInfo.Document)) > 0 then
  begin
    AResponseInfo.ContentType := 'image/jpg';
    img := true;
  end
  else if Pos('.JPEG', ANSIUPPERCASE(ARequestInfo.Document)) > 0 then
  begin
    AResponseInfo.ContentType := 'image/jpeg';
    img := true;
  end
  else if Pos('.BMP', ANSIUPPERCASE(ARequestInfo.Document)) > 0 then
  begin
    AResponseInfo.ContentType := 'image/bmp';
    img := true;
  end
  else if Pos('.PNG', ANSIUPPERCASE(ARequestInfo.Document)) > 0 then
  begin
    AResponseInfo.ContentType := 'image/png';
    img := true;
  end
  else if (Pos('.CSS', ANSIUPPERCASE(ARequestInfo.Document)) > 0) then
  begin
    AResponseInfo.ContentType := 'text/css; charset=utf-8';
    img := false;
  end
  else
  { if (Pos('.HTML', ANSIUPPERCASE(ARequestInfo.Document)) > 0) or
    (Pos('.HTM', ANSIUPPERCASE(ARequestInfo.Document)) > 0) or
    (Pos('.PHP', ANSIUPPERCASE(ARequestInfo.Document)) > 0) or
    (Pos('.CSS', ANSIUPPERCASE(ARequestInfo.Document)) > 0) or
    (Pos('.TXT', ANSIUPPERCASE(ARequestInfo.Document)) > 0) or
    (Pos('.XML', ANSIUPPERCASE(ARequestInfo.Document)) > 0) or
    (Pos('.JS', ANSIUPPERCASE(ARequestInfo.Document)) > 0) then }
  begin
    AResponseInfo.ContentType := 'text/html; charset=utf-8';
    img := false;
  end;

  if (img) then
    AResponseInfo.ServeFile(AThread, ExtractFilePath(ParamStr(0)) +
      LoadDirectory + '\index' + ARequestInfo.URI)
  else
    AResponseInfo.ContentText := LoadFileToStr(ExtractFilePath(ParamStr(0)) +
      LoadDirectory + '\index' + ARequestInfo.URI);

end;

var
  sr: TSearchRec;
  myi, myj: longint;
  task: ITask;
  iswork: boolean;
  str: string;

var
  files: TStringDynArray;
  bestindex: longint;

begin
  Server := TIdHTTPServer.Create(nil);
  CH := TCommandHandler.Create;
  Server.OnCommandGet := CH.CommandGet;
  task := TTask.Create(
    procedure()
    begin
      while iswork do
      begin
        SaveAll(true);
        Sleep(60000);
      end;
      SaveAll(false);
    end);
  ips := TStringList.Create;
  // SetLength(kumirprogs, 0);
  SetLength(blacklisted, 0);
  iswork := true;
  task.Start;
  writeln('For help use command "help"');
  while (true) do
  begin
    writeln('');
    if LoadDirectory <> '' then
      write('Prj[' + LoadDirectory + ']>')
    else
      write('>');
    readln(command);
    writeln('');
    try
      if LoadDirectory = '' then
      begin
        if (command.Split([' '])[0] = 'help') then
        begin
          writeln('c <project name> - Create project');
          writeln('o <project name> - Open project');
          writeln('l - Get list all project');
          writeln('restart - Restart console');
          writeln('exit - Goodbye))');
          // ZipToFiles(
        end
        else if (command.Split([' '])[0] = 'c') and
          (length(command.Split([' '])) > 0) and (command.Split([' '])[1] <> '')
        then
        begin
          writeln('creating ' + ExtractFilePath(ParamStr(0)) +
            command.Split([' '])[1] + '\index\');
          GetResource('index', ExtractFilePath(ParamStr(0)) +
            command.Split([' '])[1]);
          writeln('....OK');
        end
        else if (command.Split([' '])[0] = 'o') and
          (length(command.Split([' '])) > 0) and (command.Split([' '])[1] <> '')
        then
        begin
          writeln('opening ' + ExtractFilePath(ParamStr(0)) +
            command.Split([' '])[1] + '\index\');
          if not DirectoryExists(ExtractFilePath(ParamStr(0)) +
            command.Split([' '])[1]) then
          begin
            writeln('....Error(Directory not found)');
          end
          else
          begin
            LoadDirectory := command.Split([' '])[1];
            writeln('....OK');
            if FileExists(ExtractFilePath(ParamStr(0)) + command.Split([' '])[1]
              + '\save\map.m.ini') then
              map := TMemIniFile.Create(ExtractFilePath(ParamStr(0)) +
                command.Split([' '])[1] + '\save\map.m.ini')
            else
            begin
              writeln('Not found map!!!');
              writeln('Crating');
              TFile.AppendAllText(ExtractFilePath(ParamStr(0)) +
                command.Split([' '])[1] + '\save\map.m.ini', '');
              map := TMemIniFile.Create(ExtractFilePath(ParamStr(0)) +
                command.Split([' '])[1] + '\save\map.m.ini');
              map.WriteInteger('Count', 'Room', 1);
              map.WriteInteger('Count', 'road vertical', 0);
              map.WriteInteger('Count', 'road horizontal', 0);
              map.WriteInteger('Room:0', 'Pos1', -3);
              map.WriteInteger('Room:0', 'Pos2', -3);
              map.WriteInteger('Room:0', 'Pos3', 3);
              map.WriteInteger('Room:0', 'Pos4', 3);
              writeln('...OK');

            end;
            map.UpdateFile;

            if FileExists(ExtractFilePath(ParamStr(0)) + command.Split([' '])[1]
              + '\save\defaut.ini') then
              Loadini(ExtractFilePath(ParamStr(0)) + command.Split([' '])[1] +
                '\save\defaut.ini')
            else
            begin
              writeln('Not found defaut save!!!');
              writeln('For load reserved save use "lres" command');
            end;
          end;
        end
        else if (command.Split([' '])[0] = 'l') then
        begin
          writeln('projects in ' + ExtractFilePath(ParamStr(0)) + ':');
          if FindFirst(ExtractFilePath(ParamStr(0)) + '*.*', faAnyFile, sr) = 0
          then
            repeat
              if sr.Attr and faDirectory <> 0 then
                if sr.name <> '.' then
                  if sr.name <> '..' then
                    if sr.name <> '' then
                      writeln(sr.name);
            until FindNext(sr) <> 0;
          FindClose(sr);
        end
        else if (command.Split([' '])[0] = 'restart') then
        begin
          ShellExecute(0, nil, PWideChar(ParamStr(0)), nil, nil, 5);
          exit;
        end
        else if (command.Split([' '])[0] = 'exit') then
        begin
          exit;
        end
        else
        begin
          writeln('Command not found');
        end;
      end
      else
      begin
        if (command.Split([' '])[0] = 'help') then
        begin
          writeln('s - Stop http server');
          writeln('r <port> - Run http server');
          writeln('exit - Stop server and go to menu');
          writeln('=============BACKUP=============');
          writeln('save - New backup');
          writeln('lres - Get list of backup');
          writeln('lres <file> - set defaut file');
          writeln('=============PLAYER=============');
          writeln('list - List all user');
          writeln('add <login> <password> - Add user');
          writeln('del <login> 123456789 987654321 - Delete user');
          writeln('ren <login> <login> - Change username');
          writeln('rep <login> <password> <password> - Change password user');
          writeln('op <login> - Grants operator(admin) status to a player.');
          writeln('deop <login> - Revokes operator(admin) status from a player.');
          writeln('===============IP===============');
          writeln('banip - Write blacklist');
          writeln('banip <ip> - Add an IP address to the server blacklist (not saved after restart)');
          writeln('iplist - Write iplist');
          writeln('cleariplist - Clear iplist');
          // ZipToFiles(

          SetLength(blacklisted, 0);
        end
        else if (command.Split([' '])[0] = 'lres') then
        begin
          if (length(command.Split([' '])) <= 1) then
          begin
            writeln('loading reserve');
            // FileNameToDate
            files := TDirectory.GetFiles(ExtractFilePath(ParamStr(0)) +
              LoadDirectory + '\save\', '*.ini',
              TSearchOption.soAllDirectories);
            bestindex := 0;
            for myi := 1 to length(files) - 1 do
              if ExtractOnlyFileName(files[myi]) <> 'defaut' then
                if FileNameToDate(ExtractOnlyFileName(files[bestindex])) <
                  FileNameToDate(ExtractOnlyFileName(files[myi])) then
                begin
                  bestindex := myi;
                end;
            writeln('newest reserve is ' + files[bestindex]);

            writeln('Use "lres" command and name file for Backup');
            writeln('example: "lres C:\directory\file.ini"');
          end
          else if CopyFile(PWideChar(command.Split([' '])[1]),
            PWideChar(ExtractFilePath(ParamStr(0)) + LoadDirectory +
            '\save\defaut.ini'), false) then
            writeln('Файл успешно скопирован.')
          else
            writeln('Ошибка: файл не был скопирован.');
        end
        else if (command.Split([' '])[0] = 's') then
        begin
          if Server.Active = true then
          begin
            writeln('Stoping server');
            Server.Active := false;
            writeln('....OK');
          end;
        end
        else if (command.Split([' '])[0] = 'r') and
          (length(command.Split([' '])) > 0) and (command.Split([' '])[1] <> '')
        then
        begin
          writeln('runing server');
          Server.DefaultPort := StrToInt(command.Split([' '])[1]);
          Server.Active := true;
          writeln(GetIP() + ':' + command.Split([' '])[1]);
          writeln('....OK');
        end
        else if (command.Split([' '])[0] = 'exit') then
        begin
          if Server.Active = true then
          begin
            writeln('Stoping server');
            Server.Active := false;
            writeln('....OK');
          end;
          writeln('saveing');
          SaveAll(false);
          writeln('exiting');
          LoadDirectory := '';
          writeln('....OK');
        end
        else if (command.Split([' '])[0] = 'save') then
        begin
          writeln('saveing');
          SaveAll(false);
          writeln('....OK');
        end
        else if (command.Split([' '])[0] = 'deop') then
        begin
          writeln('deoping');
          Players[GetIndex(command.Split([' '])[1])].isAdmin := false;
          writeln('login: ' + command.Split([' '])[1]);
          writeln('....OK');
        end
        else if (command.Split([' '])[0] = 'add') then
        begin
          writeln('adding');
          SetLength(Players, length(Players) + 1);
          Players[High(Players)] := TPlayer.Create;
          Players[High(Players)].name := command.Split([' '])[1];
          Players[High(Players)].password := command.Split([' '])[2];
          Players[High(Players)].posx := 0;
          Players[High(Players)].posy := 0;
          Players[High(Players)].isAdmin := false;
          writeln('login: ' + command.Split([' '])[1]);
          writeln('password: ' + command.Split([' '])[2]);
          writeln('....OK');
        end
        else if (command.Split([' '])[0] = 'op') then
        begin
          writeln('oping');
          Players[GetIndex(command.Split([' '])[1])].isAdmin := true;
          writeln('login: ' + command.Split([' '])[1]);
          writeln('....OK');
        end
        else if (command.Split([' '])[0] = 'deop') then
        begin
          writeln('deoping');
          Players[GetIndex(command.Split([' '])[1])].isAdmin := false;
          writeln('login: ' + command.Split([' '])[1]);
          writeln('....OK');
        end
        else if (command.Split([' '])[0] = 'ren') then
        begin
          writeln('oping');
          Players[GetIndex(command.Split([' '])[1])].name :=
            command.Split([' '])[2];
          writeln('login: ' + command.Split([' '])[1]);
          writeln('to: ' + command.Split([' '])[2]);
          writeln('....OK');
        end
        else if (command.Split([' '])[0] = 'rep') then
        begin
          writeln('deoping');
          Players[GetIndex(command.Split([' '])[1])].isAdmin := false;
          writeln('login: ' + command.Split([' '])[1]);
          writeln('....OK');
        end
        else if (command.Split([' '])[0] = 'del') then
        begin
          if (command.Split([' '])[2] = '123456789') and
            (command.Split([' '])[3] = '987654321') then
          begin
            writeln('deleting');
            Players[GetIndex(command.Split([' '])[1])] :=
              Players[High(Players)];
            Players[High(Players)].Free;
            SetLength(Players, length(Players) - 1);
            writeln('login: ' + command.Split([' '])[1]);
            writeln('....OK');
          end
          else
          begin
            writeln('deleting');
            if (command.Split([' '])[2] <> '123456789') then
              writeln(command.Split([' '])[2] + ' != 123456789');
            if (command.Split([' '])[3] <> '987654321') then
              writeln(command.Split([' '])[3] + ' != 987654321');
            writeln('....Error');
          end
        end
        else if (command.Split([' '])[0] = 'list') then
        begin
          writeln('=============================================');
          writeln('|   login   |   password   | isAmin | score |');
          for myi := 0 to High(Players) do
          begin
            write('|' + Players[myi].name);
            for myj := length(Players[myi].name) to 10 do
              write(' ');
            write('|' + Players[myi].password);
            for myj := length(Players[myi].password) to 13 do
              write(' ');
            if Players[myi].isAdmin then
              write('|  true  ')
            else
              write('| false  ');
            write('|' + Players[myi].Scores.ToString);
            for myj := length(Players[myi].Scores.ToString) to 6 do
              write(' ');
            writeln('|');
          end;
          writeln('=============================================');
        end
        else if (command.Split([' '])[0] = 'banip') then
        begin
          if (length(command.Split([' '])) = 2) then
          begin
            writeln('adding');
            SetLength(blacklisted, length(blacklisted) + 1);
            blacklisted[High(blacklisted)] := command.Split([' '])[1];
            writeln('....OK');
          end
          else
            for str in blacklisted do
              writeln(str);
        end
        else if (command.Split([' '])[0] = 'iplist') then
        begin
          ips.Sorted := false;
          ips.Sort;
          for myj := 0 to ips.Count - 1 do
            for myi := 1 to ips.Count - 1 do
              if ips.ValueFromIndex[myi - 1] < ips.ValueFromIndex[myi] then
              begin
                ips.Exchange(myi - 1, myi);
                // writeln(ips.Names[myi]+' - '+ips.ValueFromIndex[myi]);
              end;
          for myi := 0 to ips.Count - 1 do
          begin
            writeln(ips.Names[myi] + ' - ' + ips.ValueFromIndex[myi]);
          end;
        end
        else if (command.Split([' '])[0] = 'cleariplist') then
        begin
          ips.Clear;
          for myi := 0 to ips.Count - 1 do
          begin
            writeln(ips.Names[myi] + ' - ' + ips.ValueFromIndex[myi]);
          end;
        end
        else
        begin
          writeln('Command not found');
        end;
      end;
    except
      on e: Exception do
        writeln('Error ' + e.ClassName + ' : ' + e.Message);
    end;
  end;

end.
