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
  Math;

Type
  TCommandHandler = class
  protected
    procedure CommandGet(AThread: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
      AResponseInfo: TIdHTTPResponseInfo);
  end;
{$R *.res}

type
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
    Dors: string;
  end;

var
  Server: TIdHTTPServer;
  CH: TCommandHandler;
  command: string;
  LoadDirectory: string;
  Players: Array Of TPlayer;
  reserv: array of TMemIniFile;
  blacklisted: array of string;
  map: TMemIniFile;
  ips : TStringList;
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
  ar: TArray<string>;
  i: longint;
begin

  ar := a.Dors.Split([';']);
  for i := Low(ar) to High(ar) do
    if length(ar[i].Split([':'])) > 1 then
      if ar[i].Split([':'])[0] = s then
      begin
        if ar[i].Split([':'])[1] = '0' then
          Result := false;
        if ar[i].Split([':'])[1] = '1' then
          Result := true;
        exit;
      end;
  a.Dors := a.Dors + s + ':0;'
end;

procedure DorClose(a: TPlayer; s: string);
var
  ar: TArray<string>;
  i: longint;
  s2: string;
begin
  DorIsOpen(a, s);
  ar := a.Dors.Split([';']);
  for i := Low(ar) to High(ar) do
    if (length(ar[i].Split([':'])) > 1) and (ar[i].Split([':'])[0] = s) then
    begin
      s2 := s2 + ar[i].Split([':'])[0] + ':0;';
      exit;
    end
    else
    begin
      s2 := s2 + ar[i] + ';'
    end;
end;

procedure DorOpen(a: TPlayer; s: string);
var
  ar: TArray<string>;
  i: longint;
  s2: string;
begin
  DorIsOpen(a, s);
  ar := a.Dors.Split([';']);
  for i := Low(ar) to High(ar) do
    if (length(ar[i].Split([':'])) > 1) and (ar[i].Split([':'])[0] = s) then
    begin
      s2 := s2 + ar[i].Split([':'])[0] + ':1;';
      exit;
    end
    else
    begin
      s2 := s2 + ar[i] + ';'
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
  i: longint;
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
    ini.WriteString('Player:' + i.ToString, 'dors', Players[i].Dors);
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
  i: longint;
  ini: TMemIniFile;
begin
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
    Players[i].Dors := ini.ReadString('Player:' + i.ToString, 'dors', '');
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
        SetLength(reserv, 0);
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
        writeln('');
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

function LoadServFile(user, s: string): String;
var
  i: longint;
  userindex: longint;
begin
  userindex := GetIndex(user);
  Result := s;
  if s = 'login' then
    Result := 'OK'
  else if s = 'map' then
  begin
    // Result := LoadFileToStr(ExtractFilePath(ParamStr(0)) + LoadDirectory + '\save\map.txt')
    Result := '{' + #10#13 + '  "rooms": [' + #10#13;
    for i := 0 to map.ReadInteger('Count', 'Room', 0) - 2 do
    begin
      Result := Result + '    {' + #10#13;
      Result := Result + '      "position": [' +
        map.ReadInteger('Room:' + i.ToString, 'pos1', 0).ToString + ',' +
        map.ReadInteger('Room:' + i.ToString, 'pos2', 0).ToString + ',' +
        map.ReadInteger('Room:' + i.ToString, 'pos3', 0).ToString + ',' +
        map.ReadInteger('Room:' + i.ToString, 'pos4', 0).ToString + ']'
        + #10#13;
      Result := Result + '    },' + #10#13;
    end;
    i := map.ReadInteger('Count', 'Room', 0) - 1;
    if i >= 0 then
    begin
      Result := Result + '    {' + #10#13;
      Result := Result + '      "position": [' +
        map.ReadInteger('Room:' + i.ToString, 'pos1', 0).ToString + ',' +
        map.ReadInteger('Room:' + i.ToString, 'pos2', 0).ToString + ',' +
        map.ReadInteger('Room:' + i.ToString, 'pos3', 0).ToString + ',' +
        map.ReadInteger('Room:' + i.ToString, 'pos4', 0).ToString + ']'
        + #10#13;
      Result := Result + '    }' + #10#13;
    end;
    Result := Result + '  ],' + #10#13;
    // ===================================
    Result := Result + '  "road vertical": [' + #10#13;
    for i := 0 to map.ReadInteger('Count', 'road vertical', 0) - 2 do
    begin
      Result := Result + '    {' + #10#13;
      Result := Result + '      "position": [' +
        map.ReadInteger('RV:' + i.ToString, 'pos1', 0).ToString + ',' +
        map.ReadInteger('RV:' + i.ToString, 'pos2', 0).ToString + ',' +
        map.ReadInteger('RV:' + i.ToString, 'pos3', 0).ToString + '],' + #10#13;
      if map.ReadString('RV:' + i.ToString, 'dor', '') = '' then
        Result := Result + '      "dor": "open"' + #10#13
      else if DorIsOpen(Players[userindex], map.ReadString('RV:' + i.ToString,
        'dor', '')) then
        Result := Result + '      "dor": "open"' + #10#13
      else
        Result := Result + '      "dor": "file:' +
          map.ReadString('RV:' + i.ToString, 'dor', '') + '"' + #10#13;
      Result := Result + '    },' + #10#13;
    end;
    i := map.ReadInteger('Count', 'road vertical', 0) - 1;
    if i >= 0 then
    begin
      Result := Result + '    {' + #10#13;
      Result := Result + '      "position": [' +
        map.ReadInteger('RV:' + i.ToString, 'pos1', 0).ToString + ',' +
        map.ReadInteger('RV:' + i.ToString, 'pos2', 0).ToString + ',' +
        map.ReadInteger('RV:' + i.ToString, 'pos3', 0).ToString + '],' + #10#13;
      if map.ReadString('RV:' + i.ToString, 'dor', '') = '' then
        Result := Result + '      "dor": "open"' + #10#13
      else if DorIsOpen(Players[userindex], map.ReadString('RV:' + i.ToString,
        'dor', '')) then
        Result := Result + '      "dor": "open"' + #10#13
      else
        Result := Result + '      "dor": "file:' +
          map.ReadString('RV:' + i.ToString, 'dor', '') + '"' + #10#13;
      Result := Result + '    }' + #10#13;
    end;
    Result := Result + '  ],' + #10#13;
    // ===================================
    Result := Result + '  "road horizontal": [' + #10#13;
    for i := 0 to map.ReadInteger('Count', 'road horizontal', 0) - 2 do
    begin
      Result := Result + '    {' + #10#13;
      Result := Result + '      "position": [' +
        map.ReadInteger('RH:' + i.ToString, 'pos1', 0).ToString + ',' +
        map.ReadInteger('RH:' + i.ToString, 'pos2', 0).ToString + ',' +
        map.ReadInteger('RH:' + i.ToString, 'pos3', 0).ToString + '],' + #10#13;
      if map.ReadString('RH:' + i.ToString, 'dor', '') = '' then
        Result := Result + '      "dor": "open"' + #10#13
      else if DorIsOpen(Players[userindex], map.ReadString('RH:' + i.ToString,
        'dor', '')) then
        Result := Result + '      "dor": "open"' + #10#13
      else
        Result := Result + '      "dor": "file:' +
          map.ReadString('RH:' + i.ToString, 'dor', '') + '"' + #10#13;
      Result := Result + '    },' + #10#13;
    end;
    i := map.ReadInteger('Count', 'road vertical', 0) - 1;
    if i >= 0 then
    begin
      Result := Result + '    {' + #10#13;
      Result := Result + '      "position": [' +
        map.ReadInteger('RH:' + i.ToString, 'pos1', 0).ToString + ',' +
        map.ReadInteger('RH:' + i.ToString, 'pos2', 0).ToString + ',' +
        map.ReadInteger('RH:' + i.ToString, 'pos3', 0).ToString + '],' + #10#13;
      if map.ReadString('RH:' + i.ToString, 'dor', '') = '' then
        Result := Result + '      "dor": "open"' + #10#13
      else if DorIsOpen(Players[userindex], map.ReadString('RH:' + i.ToString,
        'dor', '')) then
        Result := Result + '      "dor": "open"' + #10#13
      else
        Result := Result + '      "dor": "file:' +
          map.ReadString('RH:' + i.ToString, 'dor', '') + '"' + #10#13;
      Result := Result + '    }' + #10#13;
    end;
    Result := Result + '  ]' + #10#13;

    Result := Result + '}';
  end
  else if s = 'move_down' then
  begin
    Result := 'OK';
    if InHouse(Players[GetIndex(user)].posx, Players[GetIndex(user)].posy + 1,
      user) then
      inc(Players[GetIndex(user)].posy)
    else
      Result := 'STOP';
  end
  else if s = 'move_left' then
  begin
    Result := 'OK';
    if InHouse(Players[GetIndex(user)].posx - 1, Players[GetIndex(user)].posy,
      user) then
      inc(Players[GetIndex(user)].posx, -1)
    else
      Result := 'STOP';
  end
  else if s = 'move_rigth' then
  begin
    Result := 'OK';
    if InHouse(Players[GetIndex(user)].posx + 1, Players[GetIndex(user)].posy,
      user) then
      inc(Players[GetIndex(user)].posx)
    else
      Result := 'STOP';
  end
  else if s = 'move_up' then
  begin
    Result := 'OK';
    if InHouse(Players[GetIndex(user)].posx, Players[GetIndex(user)].posy - 1,
      user) then
      inc(Players[GetIndex(user)].posy, -1)
    else
      Result := 'STOP';
  end
  else if s = 'getpos' then
  begin
    Result := '{' + #10#13 + '  "count": ' + length(Players).ToString;
    for i := Low(Players) to High(Players) - 1 do
    begin
      Result := Result + ',' + #10#13 + '  "Player:' + i.ToString +
        '": [' + #10#13;
      Result := Result + '    {' + #10#13;
      Result := Result + '      "Name": "' + Players[i].name + '",' + #10#13;
      Result := Result + '      "posx": ' + Players[i].posx.ToString +
        ',' + #10#13;
      Result := Result + '      "posy": ' + Players[i].posy.ToString +
        ',' + #10#13;
      Result := Result + '      "personage1": ' + Players[i].Pers[0].ToString +
        ',' + #10#13;
      Result := Result + '      "personage2": ' + Players[i].Pers[1].ToString +
        ',' + #10#13;
      Result := Result + '      "personage3": ' + Players[i].Pers[2].ToString +
        ',' + #10#13;
      Result := Result + '      "personage4": ' + Players[i].Pers[3].ToString +
        ',' + #10#13;
      Result := Result + '      "personage5": ' + Players[i].Pers[4].ToString +
        ',' + #10#13;
      Result := Result + '      "personage6": ' + Players[i].Pers[5].ToString +
        ',' + #10#13;
      if Players[i].isAdmin then
        Result := Result + '      "isAdmin": "true"' + #10#13
      else
        Result := Result + '      "isAdmin": "false"' + #10#13;
      Result := Result + '    }' + #10#13;
      Result := Result + '  ],' + #10#13;

    end;
    i := High(Players);
    Result := Result + '  "Player:' + i.ToString + '": [' + #10#13;
    Result := Result + '    {' + #10#13;
    Result := Result + '      "Name": "' + Players[i].name + '",' + #10#13;
    Result := Result + '      "posx": ' + Players[i].posx.ToString +
      ',' + #10#13;
    Result := Result + '      "posy": ' + Players[i].posy.ToString + ','
      + #10#13;
    Result := Result + '      "posy": ' + Players[i].posy.ToString +
      ',' + #10#13;
    Result := Result + '      "personage1": ' + Players[i].Pers[0].ToString +
      ',' + #10#13;
    Result := Result + '      "personage2": ' + Players[i].Pers[1].ToString +
      ',' + #10#13;
    Result := Result + '      "personage3": ' + Players[i].Pers[2].ToString +
      ',' + #10#13;
    Result := Result + '      "personage4": ' + Players[i].Pers[3].ToString +
      ',' + #10#13;
    Result := Result + '      "personage5": ' + Players[i].Pers[4].ToString +
      ',' + #10#13;
    Result := Result + '      "personage6": ' + Players[i].Pers[5].ToString +
      ',' + #10#13;
    if Players[i].isAdmin then
      Result := Result + '      "isAdmin": "true"' + #10#13
    else
      Result := Result + '      "isAdmin": "false"' + #10#13;
    Result := Result + '    }' + #10#13;
    Result := Result + '  ]' + #10#13;
    Result := Result + '}';
  end
  else if length(s.Split(['EditPersonage'])) > 1 then
  if length(s.Split(['EditPersonage'])[1].Split([';'])) > 5 then
  begin
    Players[userindex].Pers[0]:=s.Split(['EditPersonage'])[1].Split([';'])[0].ToInteger;
    Players[userindex].Pers[1]:=s.Split(['EditPersonage'])[1].Split([';'])[1].ToInteger;
    Players[userindex].Pers[2]:=s.Split(['EditPersonage'])[1].Split([';'])[2].ToInteger;
    Players[userindex].Pers[3]:=s.Split(['EditPersonage'])[1].Split([';'])[3].ToInteger;
    Players[userindex].Pers[4]:=s.Split(['EditPersonage'])[1].Split([';'])[4].ToInteger;
    Players[userindex].Pers[5]:=s.Split(['EditPersonage'])[1].Split([';'])[5].ToInteger;
    Result := 'OK';
  end;
end;

procedure TCommandHandler.CommandGet(AThread: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  img: boolean;
  i, index: longint;
begin
  for I := 0 to Length(blacklisted) - 1 do
    If blacklisted[I] = AThread.Binding.PeerIP Then
    begin
      AThread.Connection.Disconnect; // or raise an Exception...
      exit;
    end;
 if ips.Values[AThread.Binding.PeerIP]<>'' then
  ips.Values[AThread.Binding.PeerIP]:=IntToStr(StrToInt(ips.Values[AThread.Binding.PeerIP])+1)
 else
  ips.Values[AThread.Binding.PeerIP]:='0';
  //writeln(AThread.Binding.PeerIP);
  if (ARequestInfo.URI = '\') or (ARequestInfo.URI = '/') or
    (ARequestInfo.URI = '') then
  begin
    AResponseInfo.Redirect('\index.html');
    exit;
  end;
  if length(ARequestInfo.URI.Split(['protect/'])) > 1 then
  begin
    AResponseInfo.ContentType := 'text/html; charset=utf-8';
    for i := Low(Players) to High(Players) do
      if Players[i].PFileName <> '' then
        if Players[i].PFileName + '.txt' = ARequestInfo.URI.Split
          (['protect/'])[1] then
        begin
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
      if (index=-1) then
        exit;
      AResponseInfo.ContentType := 'text/html; charset=utf-8';
      AResponseInfo.ContentText := md5(IntToStr(random(10000000)));
      Players[index].PFileName := RegistrationHash(AResponseInfo.ContentText,
        Players[index].password);
      Players[index].PFile := ARequestInfo.URI.Split(['commands/'])[1];
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

  if Pos('.ICO', ANSIUPPERCASE(ARequestInfo.Document)) > 0 then
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
  str:string;
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
  ips:= TStringList.Create;
  setlength(blacklisted,0);
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

          setlength(blacklisted,0);
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
          writeln('=====================================');
          writeln('|   login   |   password   | isAmin |');
          for myi := 0 to High(Players) do
          begin
            write('|' + Players[myi].name);
            for myj := length(Players[myi].name) to 10 do
              write(' ');
            write('|' + Players[myi].password);
            for myj := length(Players[myi].password) to 13 do
              write(' ');
            if Players[myi].isAdmin then
              writeln('|  true  |')
            else
              writeln('| false  |');
          end;
        end
        else if (command.Split([' '])[0] = 'banip') then
        begin
          if (length(command.Split([' '])) = 2) then
          begin
            writeln('adding');
            setlength(blacklisted,length(blacklisted)+1);
            blacklisted[High(blacklisted)]:= command.Split([' '])[1];
            writeln('....OK');
          end
          else
            for str in blacklisted do
              writeln(str);
        end
        else if (command.Split([' '])[0] = 'iplist') then
        begin
          ips.Sort;
          for myi := 0 to ips.Count-1 do
          begin
            writeln(ips.Names[myi]+' - '+ips.ValueFromIndex[myi]);
          end;
        end
        else if (command.Split([' '])[0] = 'cleariplist') then
        begin
          ips.Clear;
          for myi := 0 to ips.Count-1 do
          begin
            writeln(ips.Names[myi]+' - '+ips.ValueFromIndex[myi]);
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
