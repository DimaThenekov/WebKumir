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
  IdURI,
  IdHTTPHeaderInfo,
  Vcl.ClipBrd,
  Vcl.Graphics,
  Vcl.Imaging.pngimage,
  Generics.Collections,
  ActiveX,
  System.SyncObjs;

Type
  TCommandHandler = class
  protected
    procedure CommandGet(AThread: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
    procedure Context(AContext: TIdContext);
  end;
{$R *.res}

type
  T2Date = class
  public
    _start: TDateTime;
    _end: TDateTime;
  end;

  TProgram = class
  public
    programm: string;
    exit_data: string;
    res: string;
    task: integer;
    date: int64;
    uniID: string;
  end;

  Aarraofstrint = class
  public
    uniID: string;
    pos: longint;
  end;

  Aarraofstrintint = class
  public
    uniID: string;
    posx: int64;
    posy: int64;
  end;

  Aarraofint = array of longint;
  Aarraofstr = array of string;
  Aarraofbool = array of boolean;

  TPlayer = class
  public
    login: string;
    name: string;
    password: string;
    pos: array of Aarraofstrintint;
    group: string;
    dollars: array of Aarraofstrint;
    PFile: string;
    PFileName: string;
    isAdmin: boolean;
    Pers: Array [0 .. 5] of longint;
    Dors: array of Aarraofstrint;
    IsAccess: array of Aarraofstrint;
    Scores: int64;
    Fine: int64;
    LastProg: string;
    ip: string;
    // Progs: string;
    // kumirprogs: Aarraofint;
    programs: array of TProgram;
  end;

  TAdmin = class
  public
    name: string;
    password: string;
    PFile: string;
    PFileName: string;
  end;

  TTab = class
  public
    _name: string;
    _type: string;
    _text: string;
  end;

  TMyTask = class
  public
    DefaultProgram: string;
    folder: string;
    solution: string;
    color: longint;
    name: string;
    test: array of string;
    tab: array of TTab;
  end;

  TRoom = array [0 .. 3] of longint;

  TRoad = class
  public
    pos: array [0 .. 2] of longint;
    task: string;
  end;

  TDollar = array [0 .. 1] of longint;
  Aarraof2int = array [0 .. 1] of longint;

  TMap = class
  public
    Ds: array of TDollar;
    RHs: array of TRoad;
    RVs: array of TRoad;
    ROOMs: array of TRoom;
  end;

  TProject = class
  public
    folder: string;
    name: string;
    map: TMap;
    tasks: array of string;
    tasks_info: array of TMyTask;
    // map: TMemIniFile;
    // all_task_info: TMemIniFile;
  end;

  TRunProject = class
  public
    parentInd: longint;
    uniID: string;
    visib_name: string;
    string_freeze: string;
    time_start: int64;
    time_freeze: int64;
    time_end: int64;
    group: string;
  end;

var
  Server: TIdHTTPServer;
  CH: TCommandHandler;
  isLoadingini: boolean;
  version: string = '3.0';
  // command: string;
  admin_of_admin: TAdmin;
  LoadDirectory: string;
  Players: array Of TPlayer;
  reserv: array of TMemIniFile;
  blacklisted: array of string;
  ips: TStringList;
  DampIp: TStringList;
  logs: text;
  ArrForCaptcha: array of Aarraofstr;
  tps: array [0 .. 59] of int64;
  tps_que: array of T2Date;
  tps_que_cs: TCriticalSection;
  WordsForCaptcha: Aarraofstr;
  FileCaptcha: text;
  canlogin: boolean;
  Projects: array of TProject;
  RunProjects: array of TRunProject;
  need_update: boolean;
  DEBUG: boolean;
  last_request_testing: int64;
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

procedure ShellExecuteMy(const AWnd: HWND; const AOperation, AFileName: String; const AParameters: String = ''; const ADirectory: String = ''; const AShowCmd: integer = SW_SHOWNORMAL);
var
  ExecInfo: TShellExecuteInfo;
  NeedUnitialize: boolean;
begin
  try
    Assert(AFileName <> '');

    NeedUnitialize := Succeeded(CoInitializeEx(nil, COINIT_APARTMENTTHREADED or COINIT_DISABLE_OLE1DDE));
    try
      FillChar(ExecInfo, SizeOf(ExecInfo), 0);
      ExecInfo.cbSize := SizeOf(ExecInfo);

      ExecInfo.Wnd := AWnd;
      ExecInfo.lpVerb := Pointer(AOperation);
      ExecInfo.lpFile := PChar(AFileName);
      ExecInfo.lpParameters := Pointer(AParameters);
      ExecInfo.lpDirectory := Pointer(ADirectory);
      ExecInfo.nShow := AShowCmd;
      ExecInfo.fMask := SEE_MASK_NOASYNC { = SEE_MASK_FLAG_DDEWAIT для старых версий Delphi }
        or SEE_MASK_FLAG_NO_UI;
  {$IFDEF UNICODE}
      // Необязательно, см. http://www.transl-gunsmoker.ru/2015/01/what-does-SEEMASKUNICODE-flag-in-ShellExecuteEx-actually-do.html
      ExecInfo.fMask := ExecInfo.fMask or SEE_MASK_UNICODE;
  {$ENDIF}
  {$WARN SYMBOL_PLATFORM OFF}
      Win32Check(ShellExecuteEx(@ExecInfo));
  {$WARN SYMBOL_PLATFORM ON}
    finally
      if NeedUnitialize then
        CoUninitialize;
    end;
  except
      on e: Exception do
      begin
        writeln('Error ' + e.ClassName + ' : ' + e.Message + ' : ' + e.StackTrace + ' : ' + e.UnitScope + ' : ' + e.UnitName);
        exit;
      end;
  end;
end;

procedure SetColorConsole(AColor: TColor);
begin
  SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), FOREGROUND_RED or FOREGROUND_GREEN or FOREGROUND_BLUE);
  case AColor of
    clWhite:
      SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), FOREGROUND_RED or FOREGROUND_GREEN or FOREGROUND_BLUE);
    clRed:
      SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), FOREGROUND_RED or FOREGROUND_INTENSITY);
    clGreen:
      SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), FOREGROUND_GREEN or FOREGROUND_INTENSITY);
    clBlue:
      SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), FOREGROUND_BLUE or FOREGROUND_INTENSITY);
    clMaroon:
      SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), FOREGROUND_GREEN or FOREGROUND_RED or FOREGROUND_INTENSITY);
    clPurple:
      SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), FOREGROUND_RED or FOREGROUND_BLUE or FOREGROUND_INTENSITY);
    clAqua:
      SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), FOREGROUND_GREEN or FOREGROUND_BLUE or FOREGROUND_INTENSITY);
  end;
end;

function ExtractOnlyFileName(const FileName: string): string;
begin
  Result := StringReplace(ExtractFileName(FileName), ExtractFileExt(FileName), '', []);
end;

function RegistrationHash(a, b: string): string;
begin
  Result := md5('Hash:' + a + ';Password:' + b + ';');
end;

procedure iniarr(str: string);
var
  i, j: longint;
  arrofstr: array of string;
  getstr: string;
  tagname: string;
begin
  str := trim(str) + #13#10;
  SetLength(arrofstr, 0);
  SetLength(WordsForCaptcha, 0);
  SetLength(ArrForCaptcha, 0);
  getstr := '';

  for i := 1 to length(str) do
    if (str[i] = #10) or (str[i] = #13) then
    begin
      if getstr <> '' then
      begin
        SetLength(arrofstr, length(arrofstr) + 1);
        arrofstr[High(arrofstr)] := getstr;
      end;
      getstr := '';
    end
    else
      getstr := getstr + str[i];
  tagname := '';
  for i := 0 to High(arrofstr) do
    if (length(arrofstr[i]) > 5) and ((arrofstr[i][1] = '<') and (arrofstr[i][2] = '!')) then
    begin
      if tagname = '' then
      begin
        for j := 3 to High(arrofstr[i]) - 1 do
          tagname := tagname + arrofstr[i][j];
        if tagname <> '_new_sting_s' then
          if pos('_new_sting_', tagname) > 0 then
          begin
            SetLength(ArrForCaptcha, length(ArrForCaptcha) + 1);
            SetLength(ArrForCaptcha[High(ArrForCaptcha)], 1);
            ArrForCaptcha[High(ArrForCaptcha)][0] := tagname[length(tagname)];
          end;
      end
      else
        tagname := '';
    end
    else if tagname = '_new_sting_s' then
    begin
      SetLength(WordsForCaptcha, length(WordsForCaptcha) + 1);
      WordsForCaptcha[High(WordsForCaptcha)] := arrofstr[i];
    end
    else if pos('_new_sting_', tagname) > 0 then
    begin
      SetLength(ArrForCaptcha[High(ArrForCaptcha)], length(ArrForCaptcha[High(ArrForCaptcha)]) + 1);
      ArrForCaptcha[High(ArrForCaptcha)][High(ArrForCaptcha[High(ArrForCaptcha)])] := arrofstr[i];
    end;

  // writeln(arrofstr[i]);

end;

function str2json(s: string): string;
var
  i: longint;
  output: string;
begin
  output := '';
  for i := 1 to length(s) do
    if s[i] = #13 then
      output := output + '\r'
    else if s[i] = #10 then
      output := output + '\n'
    else if s[i] = #9 then
      output := output + '\t'
    else if s[i] = '"' then
      output := output + '\"'
    else if s[i] = '\' then
      output := output + '\\'
    else if s[i] = '/' then
      output := output + '\/'
    else
      output := output + s[i];

  str2json := output;
end;

function GenCaptcha(str: string; ans: boolean): string;
var
  i, j, k, start_pos: longint;
  genkey: int64;
  genword, spase: string;
  strings: array [1 .. 12] of string;
begin
  str := md5(str);
  genkey := 0;
  for i := 1 to length(str) do
  begin
    if (str[i] >= 'a') and (str[i] <= 'f') then
      genkey := genkey * 16 + (ord(str[i]) - ord('a') + 10);
    if (str[i] >= '0') and (str[i] <= '9') then
      genkey := genkey * 16 + (ord(str[i]) - ord('0'));
    genkey := genkey mod 36028797018963970;
  end;
  genword := AnsiUpperCase(WordsForCaptcha[((genkey mod 1048576) mod length(WordsForCaptcha))]);
  if ans then
  begin
    Result := genword;
    exit;
  end;
  genkey := genkey div 1048576;
  for i := 1 to length(genword) do
    for j := 0 to High(ArrForCaptcha) do
      if ArrForCaptcha[j][0] = genword[i] then
      begin
        start_pos := (12 - High(ArrForCaptcha[j])) div 2;
        spase := '';
        for k := 1 to length(ArrForCaptcha[j][1].Split(['#'])[1 + (genkey mod 14)]) do
          spase := spase + ' ';
        for k := 1 to High(ArrForCaptcha[j]) do
          strings[start_pos + k] := strings[start_pos + k] + ArrForCaptcha[j][k].Split(['#'])[1 + (genkey mod 14)];
        for k := 1 to start_pos do
          strings[k] := strings[k] + spase;
        for k := 12 downto 12 - start_pos + 1 - ((12 - High(ArrForCaptcha[j])) mod 2) do
          strings[k] := strings[k] + spase;
        genkey := genkey div 14;
        if genkey = 0 then
          genkey := 100000000000000;
      end;
  // writeln(genkey);
  Result := '';
  for i := 1 to 12 do
    Result := Result + strings[i] + #13#10;
end;

function ClearStr(str: string; chars: string = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@()[]:-'): string;
var
  symbols, textInEdit: String;
  i: integer;
begin
  symbols := chars;
  for i := 1 to length(str) do
  begin
    if (pos(Copy(str, i, 1), symbols) = 0) then
    // Если i-й символ отсутствует в наборе символов...
    begin
      textInEdit := str;
      Delete(textInEdit, i, 1); // ...удаляем этот символ
      str := textInEdit;
      str := ClearStr(str);
      break;
    end;
  end;
  Result := str;
end;

function DorIsOpen(a: TPlayer; PrjInd: longint; s: string): boolean;
var
  i: longint;
begin

  for i := 0 to High(a.Dors) do
    if (a.Dors[i].pos mod 2 = 0) then
    begin
      if (a.Dors[i].uniID = RunProjects[PrjInd].uniID) and (Projects[RunProjects[PrjInd].parentInd].map.RVs[a.Dors[i].pos div 2].task = s) then
      begin
        Result := true;
        exit;
      end;
    end
    else
    begin
      if (a.Dors[i].uniID = RunProjects[PrjInd].uniID) and (Projects[RunProjects[PrjInd].parentInd].map.RHs[a.Dors[i].pos div 2].task = s) then
      begin
        Result := true;
        exit;
      end;
    end;
  Result := false;
end;

procedure DorClose(a: TPlayer; PrjInd: longint; s: string);
var
  i: longint;
begin
  for i := 0 to High(a.Dors) do
    if (a.Dors[i].pos mod 2 = 0) then
    begin
      if (a.Dors[i].uniID = RunProjects[PrjInd].uniID) and (Projects[RunProjects[PrjInd].parentInd].map.RVs[a.Dors[i].pos div 2].task = s) then
      begin
        a.Dors[i].Free;
        a.Dors[i] := a.Dors[High(a.Dors)];
        SetLength(a.Dors, length(a.Dors) - 1);
        exit;
      end;
    end
    else
    begin
      if (a.Dors[i].uniID = RunProjects[PrjInd].uniID) and (Projects[RunProjects[PrjInd].parentInd].map.RHs[a.Dors[i].pos div 2].task = s) then
      begin
        a.Dors[i].Free;
        a.Dors[i] := a.Dors[High(a.Dors)];
        SetLength(a.Dors, length(a.Dors) - 1);
        exit;
      end;
    end;
end;

procedure DorOpen(a: TPlayer; PrjInd: longint; s: string);
var
  i: longint;
begin
  for i := 0 to High(Projects[RunProjects[PrjInd].parentInd].map.RVs) do
  begin
    if Projects[RunProjects[PrjInd].parentInd].map.RVs[i].task = s then
    begin
      SetLength(a.Dors, length(a.Dors) + 1);
      a.Dors[High(a.Dors)] := Aarraofstrint.Create();
      a.Dors[High(a.Dors)].uniID := RunProjects[PrjInd].uniID;
      a.Dors[High(a.Dors)].pos := i * 2;
      exit;
    end;
  end;
  for i := 0 to High(Projects[RunProjects[PrjInd].parentInd].map.RHs) do
  begin
    if Projects[RunProjects[PrjInd].parentInd].map.RHs[i].task = s then
    begin
      SetLength(a.Dors, length(a.Dors) + 1);
      a.Dors[High(a.Dors)] := Aarraofstrint.Create();
      a.Dors[High(a.Dors)].uniID := RunProjects[PrjInd].uniID;
      a.Dors[High(a.Dors)].pos := i * 2 + 1;
      exit;
    end;
  end;
end;

function LoadFileToStr2(const FileName: TFileName): String;
var
  LStrings: TStringList;
begin
  LStrings := TStringList.Create;
  try
    LStrings.Loadfromfile(FileName, TEncoding.GetEncoding('UTF-16LE'));
    Result := LStrings.text;
  finally
    FreeAndNil(LStrings);
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
  Result := EncodeDateTime(s.Split(['_'])[0].ToInteger, s.Split(['_'])[1].ToInteger, s.Split(['_'])[2].ToInteger, s.Split(['_'])[3].ToInteger, s.Split(['_'])[4].ToInteger,
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

function MyINI2TXT(s: string): string;
var
  i: longint;
begin
  Result := '';
  i := 1;
  while i <= length(s) do
    if (s[i] <> '#') then
    begin
      Result := Result + s[i];
      inc(i);
    end
    else
    begin
      if i + 2 > length(s) then
        break;
      Result := Result + chr((ord(s[i + 1]) - ord('0')) * 10 + (ord(s[i + 2]) - ord('0')));
      inc(i);
      inc(i);
      inc(i);
    end;
end;

function MyTXT2INI(s: string): string;
var
  i: longint;
begin
  Result := '';
  for i := 1 to length(s) do
    if (s[i] = ' ') or ((s[i] > '#') and (s[i] <> '=') and (s[i] <> '\')) then
    begin
      Result := Result + s[i];
    end
    else
    begin
      Result := Result + '#' + (ord(s[i]) div 10).ToString + (ord(s[i]) mod 10).ToString;
    end;
end;

procedure saveini(var ini: TMemIniFile);
var
  i, j, k: longint;
begin
  ini.Clear;
  ini.WriteInteger('Players', 'count', length(Players));
  for i := 0 to High(Players) do
  begin
    ini.WriteString('Player:' + i.ToString, 'login', Players[i].login);
    ini.WriteString('Player:' + i.ToString, 'name', MyTXT2INI(Players[i].name));
    ini.WriteString('Player:' + i.ToString, 'password', Players[i].password);

    ini.WriteInteger('Player:' + i.ToString, 'pos_count', length(Players[i].pos));
    for j := 0 to High(Players[i].pos) do
    begin
      ini.WriteString('Player:' + i.ToString, 'pos:' + j.ToString + ':uniID', Players[i].pos[j].uniID);
      ini.WriteInteger('Player:' + i.ToString, 'pos:' + j.ToString + ':posx', Players[i].pos[j].posx);
      ini.WriteInteger('Player:' + i.ToString, 'pos:' + j.ToString + ':posy', Players[i].pos[j].posy);
    end;

    ini.WriteBool('Player:' + i.ToString, 'isAdmin', Players[i].isAdmin);
    // -------
    ini.WriteInteger('Player:' + i.ToString, 'dor_count', length(Players[i].Dors));
    for j := 0 to High(Players[i].Dors) do
    begin
      ini.WriteString('Player:' + i.ToString, 'dors:' + j.ToString + ':uniID', Players[i].Dors[j].uniID);
      ini.WriteInteger('Player:' + i.ToString, 'dors:' + j.ToString + ':pos', Players[i].Dors[j].pos);
    end;
    ini.WriteInteger('Player:' + i.ToString, 'isaccess_count', length(Players[i].Dors));
    for j := 0 to High(Players[i].Dors) do
    begin
      ini.WriteString('Player:' + i.ToString, 'isaccess:' + j.ToString + ':uniID', Players[i].IsAccess[j].uniID);
      ini.WriteInteger('Player:' + i.ToString, 'isaccess:' + j.ToString + ':pos', Players[i].IsAccess[j].pos);
    end;

    k := 0;
    for j := 0 to High(Players[i].programs) do
      if Players[i].programs[j].res = 'OK' then
      begin
        ini.WriteString('Player:' + i.ToString, 'programm_' + k.ToString + '_programm', MyTXT2INI(Players[i].programs[j].programm));
        ini.WriteString('Player:' + i.ToString, 'programm_' + k.ToString + '_exit_data', MyTXT2INI(Players[i].programs[j].exit_data));
        ini.WriteString('Player:' + i.ToString, 'programm_' + k.ToString + '_res', MyTXT2INI(Players[i].programs[j].res));
        ini.WriteInteger('Player:' + i.ToString, 'programm_' + k.ToString + '_task', Players[i].programs[j].task);
        ini.WriteInt64('Player:' + i.ToString, 'programm_' + k.ToString + '_date', Players[i].programs[j].date);
        ini.WriteString('Player:' + i.ToString, 'programm_' + k.ToString + '_uniID', Players[i].programs[j].uniID);
        k := k + 1;
      end;
    ini.WriteInteger('Player:' + i.ToString, 'programm_num', k);

    ini.WriteInteger('Player:' + i.ToString, 'personage_skin', Players[i].Pers[0]);
    ini.WriteInteger('Player:' + i.ToString, 'personage_hairstyle', Players[i].Pers[1]);
    ini.WriteInteger('Player:' + i.ToString, 'personage_eye', Players[i].Pers[2]);
    ini.WriteInteger('Player:' + i.ToString, 'personage_shirt', Players[i].Pers[3]);
    ini.WriteInteger('Player:' + i.ToString, 'personage_pants', Players[i].Pers[4]);
    ini.WriteInteger('Player:' + i.ToString, 'personage_footwear', Players[i].Pers[5]);

    ini.WriteInteger('Player:' + i.ToString, 'dollars', length(Players[i].dollars));
    for j := 0 to High(Players[i].dollars) do
    begin
      ini.WriteString('Player:' + i.ToString, 'dollar:' + j.ToString + ':uniID', Players[i].dollars[j].uniID);
      ini.WriteInteger('Player:' + i.ToString, 'dollar:' + j.ToString + ':pos', Players[i].dollars[j].pos);
    end;
  end;
  ini.WriteInteger('RunProjects', 'count', length(RunProjects));
  for i := 0 to High(RunProjects) do
  begin
    ini.WriteInteger('RunProjects:' + i.ToString, 'parentInd', RunProjects[i].parentInd);
    ini.WriteString('RunProjects:' + i.ToString, 'uniID', RunProjects[i].uniID);
    ini.WriteString('RunProjects:' + i.ToString, 'visib_name', MyTXT2INI(RunProjects[i].visib_name));
    ini.WriteString('RunProjects:' + i.ToString, 'string_freeze', MyTXT2INI(RunProjects[i].string_freeze));
    ini.WriteInt64('RunProjects:' + i.ToString, 'time_start', RunProjects[i].time_start);
    ini.WriteInt64('RunProjects:' + i.ToString, 'time_freeze', RunProjects[i].time_freeze);
    ini.WriteInt64('RunProjects:' + i.ToString, 'time_end', RunProjects[i].time_end);
    ini.WriteString('RunProjects:' + i.ToString, 'group', MyTXT2INI(RunProjects[i].group));
  end;
end;

function MyINI2List(s: string): TStringList;
var
  st: TStringList;
  i, j: longint;
  s2, s3, s4, key, line: string;
begin
  st := TStringList.Create;
  s2 := '';
  line := '';
  s := s + #10;
  for i := 1 to length(s) do
  begin
    if s[i] = #10 then
    begin
      s3 := trim(line);
      if (length(s3) > 10) and (s3[1] = '<') and (s3[2] = '!') and (s3[3] = '-') and (s3[4] = '-') and (s3[5] = '-') and (s3[6] = '-') and (s3[s3.length] = '>') and (s3[s3.length - 1] = '-') and
        (s3[s3.length - 2] = '-') and (s3[s3.length - 3] = '-') and (s3[s3.length - 4] = '-') then
      begin
        s4 := '';
        for j := 7 to s3.length - 5 do
          s4 := s4 + s3[j];
        if s2 <> '' then
          st.AddPair(key, trim(s2));
        key := s4;
        s2 := '';
      end
      else
      begin
        s2 := s2 + line + s[i];
      end;
      line := '';
    end
    else
      line := line + s[i];
  end;
  // s2 := s2 + line;
  if s2 <> '' then
    st.AddPair(key, trim(s2));
  // st.AddPair();
  MyINI2List := st;
end;

function Loadini(): boolean;
var
  i, g, j, k, k2, k3, errs, warns: longint;
  instr: boolean;
  mys, ss, lastss: string;
  ini: TMemIniFile;
  sr, sr2, sr3: TSearchRec;
  prjfolder: string;
  output_s: TStringList;
  task_sl: TStringList;
  png: TPngImage;
  clr: TColor;

  Y, X, summ, el_x, el_y, x2, x3, y2, y3: longint;
  isdor: longint;
  ppoint: Aarraof2int;
  map: array of Aarraofstr;
  red, green, blue: byte;
begin
  // ---------
  try

    if isLoadingini then
      exit;
    isLoadingini := true;
    Result := true;
    warns := 0;
    errs := 0;
    output_s := TStringList.Create;
    writeln('loading (' + LoadDirectory + '\projects\):');
    for i := 0 to High(Projects) do
    begin
      Projects[i].map.Free;
      Projects[i].Free;
    end;
    SetLength(Projects, 0);
    write('[');
    if FindFirst(LoadDirectory + '\projects\' + '*.*', faAnyFile, sr) = 0 then
      repeat
        k := 0;
        if sr.Attr and faDirectory <> 0 then
          if sr.name <> '.' then
            if sr.name <> '..' then
              if sr.name <> '' then
                if sr.name[1] <> '_' then
                  k := 1;
        if k = 1 then
        begin
          write('|');
          prjfolder := LoadDirectory + '\projects\' + sr.name + '\';
          SetLength(Projects, length(Projects) + 1);
          Projects[High(Projects)] := TProject.Create();

          output_s.Add('  ' + length(Projects).ToString + '. loading (' + sr.name + '): ');

          for i := Low(Projects[High(Projects)].tasks_info) to High(Projects[High(Projects)].tasks_info) do
            Projects[High(Projects)].tasks_info[i].Free;
          SetLength(Projects[High(Projects)].tasks_info, 0);
          SetLength(Projects[High(Projects)].tasks, 0);
          Projects[High(Projects)].folder := 'projects\' + sr.name + '\';
          output_s.Add('    loading tasks: ');
          if FindFirst(prjfolder + 'task\' + '*.*', faAnyFile, sr2) = 0 then
            repeat
              k2 := 0;
              if sr2.Attr and faDirectory <> 0 then
                if sr2.name <> '.' then
                  if sr2.name <> '..' then
                    if sr2.name <> '' then
                      if sr2.name[1] <> '_' then
                        k2 := 1;
              if k2 = 1 then
              begin
                output_s.Add('      loading ' + sr2.name + ': ');
                SetLength(Projects[High(Projects)].tasks_info, length(Projects[High(Projects)].tasks_info) + 1);
                SetLength(Projects[High(Projects)].tasks, length(Projects[High(Projects)].tasks) + 1);
                i := High(Projects[High(Projects)].tasks_info);
                Projects[High(Projects)].tasks_info[i] := TMyTask.Create;
                Projects[High(Projects)].tasks_info[i].folder := sr2.name;
                mys := prjfolder + 'task\' + sr2.name + '\';
                if FileExists(mys + 'manifest__secret_information__.txt') then
                begin
                  task_sl := MyINI2List(LoadFileToStr(mys + 'manifest__secret_information__.txt').trim());
                end
                else
                begin
                  output_s.strings[output_s.Count - 1] := output_s.strings[output_s.Count - 1] + '!ERROR! file ' + mys + 'manifest__secret_information__.txt' + ' not found ';
                  inc(errs);
                  continue;
                end;
                Projects[High(Projects)].tasks_info[i].name := trim(task_sl.Values['name']);
                if Projects[High(Projects)].tasks_info[i].name = '' then
                begin
                  output_s.strings[output_s.Count - 1] := output_s.strings[output_s.Count - 1] + '!ERROR! manifest not have name ';
                  inc(errs);
                  continue;
                end;

                Projects[High(Projects)].tasks_info[i].DefaultProgram := task_sl.Values['default program'];
                if Projects[High(Projects)].tasks_info[i].DefaultProgram = '' then
                begin
                  output_s.strings[output_s.Count - 1] := output_s.strings[output_s.Count - 1] + '!ERROR! manifest not have default program ';
                  inc(errs);
                  continue;
                end;

                Projects[High(Projects)].tasks[i] := Projects[High(Projects)].tasks_info[i].name;
                SetLength(Projects[High(Projects)].tasks_info[i].tab, 1);
                Projects[High(Projects)].tasks_info[i].tab[0] := TTab.Create;
                Projects[High(Projects)].tasks_info[i].tab[0]._name := 'Условие';
                Projects[High(Projects)].tasks_info[i].tab[0]._type := 'text';
                Projects[High(Projects)].tasks_info[i].tab[0]._text := StringReplace(StringReplace(task_sl.Values['condition'], '"', '&quot;', [rfReplaceAll]), '''', '&lsquo;', [rfReplaceAll]);
                if trim(Projects[High(Projects)].tasks_info[i].tab[0]._text) = '' then
                begin
                  output_s.strings[output_s.Count - 1] := output_s.strings[output_s.Count - 1] + '!ERROR! manifest not have condition ';
                  inc(errs);
                  continue;
                end;
                for j := 0 to i - 1 do
                  if trim(Projects[High(Projects)].tasks[j]) = trim(Projects[High(Projects)].tasks[i]) then
                  begin
                    output_s.strings[output_s.Count - 1] := output_s.strings[output_s.Count - 1] + '!ERROR! task name is repeat ';
                    inc(errs);
                    break;
                  end;
                Projects[High(Projects)].tasks_info[i].solution := task_sl.Values['solution'];
                if trim(Projects[High(Projects)].tasks_info[i].solution) = '' then
                begin
                  output_s.strings[output_s.Count - 1] := output_s.strings[output_s.Count - 1] + '!WARNING! manifest not have Solution ';
                  inc(warns);
                end
                else if trim(trim(Projects[High(Projects)].tasks_info[i].solution).Split([#13])[0]) <> 'использовать Робот' then
                begin
                  output_s.strings[output_s.Count - 1] := output_s.strings[output_s.Count - 1] + '!WARNING! Solution not start on "использовать Робот" ';
                  inc(warns);
                end;
                Projects[High(Projects)].tasks_info[i].color := -1;
                SetLength(Projects[High(Projects)].tasks_info[i].test, 0);
                if FindFirst(mys + '*.fil', faAnyFile, sr3) = 0 then
                  repeat
                    if sr3.name[1] <> '_' then
                    begin
                      SetLength(Projects[High(Projects)].tasks_info[i].test, length(Projects[High(Projects)].tasks_info[i].test) + 1);

                      Projects[High(Projects)].tasks_info[i].test[High(Projects[High(Projects)].tasks_info[i].test)] := 'task\/' + sr2.name + '\/' + sr3.name;
                      if (pos('__secret_information__', sr3.name) = 0) then
                      begin
                        SetLength(Projects[High(Projects)].tasks_info[i].tab, length(Projects[High(Projects)].tasks_info[i].tab) + 1);
                        j := High(Projects[High(Projects)].tasks_info[i].tab);
                        Projects[High(Projects)].tasks_info[i].tab[j] := TTab.Create;
                        Projects[High(Projects)].tasks_info[i].tab[j]._name := 'Тест ' + j.ToString;
                        Projects[High(Projects)].tasks_info[i].tab[j]._type := 'fil';
                        Projects[High(Projects)].tasks_info[i].tab[j]._text := 'task\/' + sr2.name + '\/' + sr3.name;
                      end;
                      // writeln(sr3.name);
                    end;
                  until FindNext(sr3) <> 0;
                SetLength(Projects[High(Projects)].tasks_info[i].tab, length(Projects[High(Projects)].tasks_info[i].tab) + 1);
                j := High(Projects[High(Projects)].tasks_info[i].tab);
                Projects[High(Projects)].tasks_info[i].tab[j] := TTab.Create;
                Projects[High(Projects)].tasks_info[i].tab[j]._name := 'Загрузить';
                Projects[High(Projects)].tasks_info[i].tab[j]._type := 'load';
                Projects[High(Projects)].tasks_info[i].tab[j]._text := '';
                SetLength(Projects[High(Projects)].tasks_info[i].tab, length(Projects[High(Projects)].tasks_info[i].tab) + 1);
                j := High(Projects[High(Projects)].tasks_info[i].tab);
                Projects[High(Projects)].tasks_info[i].tab[j] := TTab.Create;
                Projects[High(Projects)].tasks_info[i].tab[j]._name := 'Топ';
                Projects[High(Projects)].tasks_info[i].tab[j]._type := 'site';
                Projects[High(Projects)].tasks_info[i].tab[j]._text := '\\top.html';

                { for j := 0 to High(Projects[High(Projects)].tasks_info[i].test) do
                  Projects[High(Projects)].tasks_info[i].test[j] := Projects[High(Projects)].all_task_info.ReadString('Task:' + i.ToString, 'test_' + j.ToString, '');

                  SetLength(Projects[High(Projects)].tasks_info[i].tab, Projects[High(Projects)].all_task_info.ReadInteger('Task:' + i.ToString, 'tab_count', 0));
                  for j := Low(Projects[High(Projects)].tasks_info[i].tab) to High(Projects[High(Projects)].tasks_info[i].tab) do
                  begin
                  Projects[High(Projects)].tasks_info[i].tab[j] := TTab.Create;
                  Projects[High(Projects)].tasks_info[i].tab[j]._name := Projects[High(Projects)].all_task_info.ReadString('Task:' + i.ToString, 'tab_' + j.ToString + '_name', '');
                  Projects[High(Projects)].tasks_info[i].tab[j]._type := Projects[High(Projects)].all_task_info.ReadString('Task:' + i.ToString, 'tab_' + j.ToString + '_type', '');
                  if Projects[High(Projects)].tasks_info[i].tab[j]._type = 'text' then
                  Projects[High(Projects)].tasks_info[i].tab[j]._text := Projects[High(Projects)].all_task_info.ReadString('Task:' + i.ToString, 'tab_' + j.ToString + '_text', '')
                  else if (Projects[High(Projects)].tasks_info[i].tab[j]._type = 'site') or (Projects[High(Projects)].tasks_info[i].tab[j]._type = 'fil') then
                  Projects[High(Projects)].tasks_info[i].tab[j]._text := Projects[High(Projects)].all_task_info.ReadString('Task:' + i.ToString, 'tab_' + j.ToString + '_url', '')
                  else if Projects[High(Projects)].tasks_info[i].tab[j]._type = 'load' then
                  Projects[High(Projects)].tasks_info[i].tab[j]._text := ''
                  else
                  writeln('no found type ' + Projects[High(Projects)].tasks_info[i].tab[j]._type + ' on ' + Projects[High(Projects)].tasks_info[i].tab[j]._name);


                  // _text: if  _type=text
                  // _url : if  _type=site  or  _type=fil
                  // ____ : if  _type=load

                  end; }
                output_s.strings[output_s.Count - 1] := output_s.strings[output_s.Count - 1] + 'OK';
              end;
            until FindNext(sr2) <> 0;
          mys := (prjfolder + 'name.txt');

          output_s.Add('    getting name and colors: ');
          if FileExists(mys) then
          begin
            Projects[High(Projects)].name := MyINI2List(LoadFileToStr(mys).trim()).Values['name'];
            mys := MyINI2List(LoadFileToStr(mys).trim()).Values['colors'];
            // StrToInt64('$' + trim(task_sl.Values['color']))
            if Projects[High(Projects)].name = '' then
            begin
              output_s.strings[output_s.Count - 1] := output_s.strings[output_s.Count - 1] + '!ERROR! file not have name ';
              inc(errs);
              continue;
            end;
            if trim(mys) = '' then
            begin
              output_s.strings[output_s.Count - 1] := output_s.strings[output_s.Count - 1] + '!ERROR! file not have colors ';
              inc(errs);
              continue;
            end;
            for i := 0 to High(mys.Split([#10])) do
              if trim(mys.Split([#10])[i]) <> '' then
              begin
                ss := mys.Split([#10])[i];
                for j := 0 to High(Projects[High(Projects)].tasks_info) do
                  if trim(ss.Split(['='])[1]) = trim(Projects[High(Projects)].tasks_info[j].folder) then
                    Projects[High(Projects)].tasks_info[j].color := StrToInt64('$' + trim(ss.Split(['='])[0]));
              end;
            for j := 0 to High(Projects[High(Projects)].tasks_info) do
              if Projects[High(Projects)].tasks_info[j].color = -1 then
              begin
                output_s.Add('!ERROR! Task ' + Projects[High(Projects)].tasks_info[j].name + ' not have color. If you are not using the task, please delete the folder. ');
                inc(errs);
                continue;
              end;

          end
          else
          begin
            output_s.Add('!ERROR! file ' + mys + ' not found ');
            inc(errs);
            continue;
          end;
          output_s.strings[output_s.Count - 1] := output_s.strings[output_s.Count - 1] + 'OK';
          Projects[High(Projects)].map := TMap.Create();
          output_s.Add('    loading map: ');
          png := TPngImage.Create;
          mys := LoadDirectory + '\projects\' + sr.name + '\';
          output_s.Add('      reading file: ');
          if FileExists(mys + 'map.png') then
          begin
            png.Loadfromfile(mys + 'map.png');
            output_s.strings[output_s.Count - 1] := output_s.strings[output_s.Count - 1] + 'OK';
            output_s.Add('      reading bitmap: ');
            SetLength(map, png.Height);
            SetLength(Projects[High(Projects)].map.Ds, 0);
            SetLength(Projects[High(Projects)].map.RHs, 0);
            SetLength(Projects[High(Projects)].map.RVs, 0);
            SetLength(Projects[High(Projects)].map.ROOMs, 0);
            ppoint[0] := -10000;
            ppoint[1] := -10000;
            for Y := 0 to png.Height - 1 do
            begin
              SetLength(map[Y], png.Width);
              for X := 0 to png.Width - 1 do
              begin
                map[Y][X] := '_';
                clr := png.Canvas.Pixels[X, Y];
                red := GetRValue(clr);
                green := GetGValue(clr);
                blue := GetBValue(clr);
                if ((red > 128) and (green > 128)) and (blue > 128) then
                begin
                  continue; // белый
                end;
                if ((red < 128) and (green < 128)) and (blue < 128) then
                begin
                  red := 0; // чёрный, доллар
                  green := 255;
                  blue := 0;
                  png.Pixels[X, Y] := $00FF00;
                  SetLength(Projects[High(Projects)].map.Ds, length(Projects[High(Projects)].map.Ds) + 1);
                  Projects[High(Projects)].map.Ds[High(Projects[High(Projects)].map.Ds)][0] := X;
                  Projects[High(Projects)].map.Ds[High(Projects[High(Projects)].map.Ds)][1] := Y;
                end;
                if ((red < 128) and (green < 128)) and (blue > 128) then
                begin
                  png.Pixels[X, Y] := $00FF00 - ((255 - blue) mod 126) * 256;
                  red := 0;
                  green := 0;
                  blue := 255;
                  map[Y, X] := 'D';
                end;
                if ((red > 128) and (green < 128)) and (blue < 128) then
                begin
                  red := 0; // красный, нулевая точка
                  green := 255;
                  blue := 0;
                  png.Pixels[X, Y] := $00FF00;
                  if (ppoint[0] = -10000) and (ppoint[1] = -10000) then
                  begin
                    ppoint[0] := X;
                    ppoint[1] := Y;
                  end
                  else
                  begin
                    output_s.strings[output_s.Count - 1] := output_s.strings[output_s.Count - 1] + '!ERROR! found 2 point-start ';
                    inc(errs);
                    continue;
                  end;
                end;
              end;
            end;
            output_s.strings[output_s.Count - 1] := output_s.strings[output_s.Count - 1] + 'OK';
            output_s.Add('      founding road: ');
            for Y := 0 to png.Height - 1 do
              for X := 0 to png.Width - 1 do
              begin
                clr := png.Canvas.Pixels[X, Y];
                red := GetRValue(clr);
                green := GetGValue(clr);
                blue := GetBValue(clr);
                if ((red < 128) and (green > 128)) and (blue < 128) then
                begin
                  // зелёный, комната или дорога
                  summ := 0;
                  if (X - 1 >= 0) and (((GetRValue(png.Canvas.Pixels[X - 1, Y]) < 128) and (GetGValue(png.Canvas.Pixels[X - 1, Y]) > 128)) and (GetBValue(png.Canvas.Pixels[X - 1, Y]) < 128)) then
                    summ := summ + 1000;
                  if (Y - 1 >= 0) and (((GetRValue(png.Canvas.Pixels[X, Y - 1]) < 128) and (GetGValue(png.Canvas.Pixels[X, Y - 1]) > 128)) and (GetBValue(png.Canvas.Pixels[X, Y - 1]) < 128)) then
                    summ := summ + 100;
                  if (X + 1 < png.Width) and (((GetRValue(png.Canvas.Pixels[X + 1, Y]) < 128) and (GetGValue(png.Canvas.Pixels[X + 1, Y]) > 128)) and (GetBValue(png.Canvas.Pixels[X + 1, Y]) < 128))
                  then
                    summ := summ + 10;
                  if (Y + 1 < png.Height) and (((GetRValue(png.Canvas.Pixels[X, Y + 1]) < 128) and (GetGValue(png.Canvas.Pixels[X, Y + 1]) > 128)) and (GetBValue(png.Canvas.Pixels[X, Y + 1]) < 128))
                  then
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
            output_s.strings[output_s.Count - 1] := output_s.strings[output_s.Count - 1] + 'OK';
            output_s.Add('      processing: ');
            for Y := 0 to png.Height - 1 do
              for X := 0 to png.Width - 1 do
                if (map[Y][X] = 'H') or (map[Y][X] = 'DH') then
                begin
                  x2 := X;
                  isdor := -1;
                  while (x2 < png.Width) and ((map[Y][x2] = 'H') or (map[Y][x2] = 'DH')) do
                    if (map[Y][x2] = 'H') then
                      x2 := x2 + 1
                    else
                    begin
                      clr := png.Canvas.Pixels[x2, Y];
                      red := GetRValue(clr);
                      green := GetGValue(clr);
                      blue := GetBValue(clr);
                      if (((red < 128) and (green > 128)) and (blue < 128)) and (255 - green <= 127) then
                        isdor := 255 - green;
                      x2 := x2 + 1;
                    end;
                  x2 := x2 - 1;
                  for x3 := X to x2 do
                  begin
                    map[min(max(Y - 1, 0), png.Height - 1)][x3] := '_';
                    map[min(max(Y, 0), png.Height - 1)][x3] := '_';
                    map[min(max(Y + 1, 0), png.Height - 1)][x3] := '_';
                  end;
                  SetLength(Projects[High(Projects)].map.RHs, length(Projects[High(Projects)].map.RHs) + 1);
                  Projects[High(Projects)].map.RHs[High(Projects[High(Projects)].map.RHs)] := TRoad.Create();
                  Projects[High(Projects)].map.RHs[High(Projects[High(Projects)].map.RHs)].pos[0] := Y - ppoint[1];
                  Projects[High(Projects)].map.RHs[High(Projects[High(Projects)].map.RHs)].pos[1] := X - ppoint[0];
                  Projects[High(Projects)].map.RHs[High(Projects[High(Projects)].map.RHs)].pos[2] := x2 - ppoint[0];
                  if isdor <> -1 then
                    for i := 0 to High(Projects[High(Projects)].tasks_info) do
                      if Projects[High(Projects)].tasks_info[i].color = 255 - isdor then
                      begin
                        Projects[High(Projects)].map.RHs[High(Projects[High(Projects)].map.RHs)].task := Projects[High(Projects)].tasks_info[i].name;
                        break;
                      end
                      else if i = High(Projects[High(Projects)].tasks_info) then
                      begin
                        output_s.strings[output_s.Count - 1] := output_s.strings[output_s.Count - 1] + '!ERROR! task with color rgb(0,0,' + (255 - isdor).ToString + ') on [' + X.ToString + ',' +
                          Y.ToString + '] not faund ';
                        inc(errs);
                      end;
                end;
            for Y := 0 to png.Height - 1 do
              for X := 0 to png.Width - 1 do
                if (map[Y][X] = 'V') or (map[Y][X] = 'DV') then
                begin
                  y2 := Y;
                  isdor := -1;
                  while (y2 < png.Height) and ((map[y2][X] = 'V') or (map[y2][X] = 'DV')) do
                    if (map[y2][X] = 'V') then
                      y2 := y2 + 1
                    else
                    begin
                      clr := png.Canvas.Pixels[X, y2];
                      red := GetRValue(clr);
                      green := GetGValue(clr);
                      blue := GetBValue(clr);
                      if (((red < 128) and (green > 128)) and (blue < 128)) and (255 - green <= 127) then
                        isdor := 255 - green;
                      y2 := y2 + 1;
                    end;
                  y2 := y2 - 1;
                  for y3 := Y to y2 do
                  begin
                    map[y3][min(max(X - 1, 0), png.Width - 1)] := '_';
                    map[y3][min(max(X, 0), png.Width - 1)] := '_';
                    map[y3][min(max(X + 1, 0), png.Width - 1)] := '_';
                  end;
                  SetLength(Projects[High(Projects)].map.RVs, length(Projects[High(Projects)].map.RVs) + 1);
                  Projects[High(Projects)].map.RVs[High(Projects[High(Projects)].map.RVs)] := TRoad.Create();
                  Projects[High(Projects)].map.RVs[High(Projects[High(Projects)].map.RVs)].pos[0] := X - ppoint[0];
                  Projects[High(Projects)].map.RVs[High(Projects[High(Projects)].map.RVs)].pos[1] := Y - ppoint[1];
                  Projects[High(Projects)].map.RVs[High(Projects[High(Projects)].map.RVs)].pos[2] := y2 - ppoint[1];
                  if isdor <> -1 then
                    for i := 0 to High(Projects[High(Projects)].tasks_info) do
                      if Projects[High(Projects)].tasks_info[i].color = 255 - isdor then
                      begin
                        Projects[High(Projects)].map.RVs[High(Projects[High(Projects)].map.RVs)].task := Projects[High(Projects)].tasks_info[i].name;
                        break;
                      end
                      else if i = High(Projects[High(Projects)].tasks_info) then
                      begin
                        output_s.strings[output_s.Count - 1] := output_s.strings[output_s.Count - 1] + '!ERROR! task with color rgb(0,0,' + (255 - isdor).ToString + ') on [' + X.ToString + ',' +
                          Y.ToString + '] not faund ';
                        inc(errs);
                      end;
                end;
            for Y := 0 to png.Height - 1 do
              for X := 0 to png.Width - 1 do
                if (map[Y][X] = 'R') then
                begin
                  x2 := X;
                  while (x2 < png.Width) and (map[Y][x2] = 'R') do
                    x2 := x2 + 1;
                  x2 := x2 - 1;
                  y2 := Y;
                  while (y2 < png.Height) and (map[y2][X] = 'R') do
                    y2 := y2 + 1;
                  y2 := y2 - 1;
                  for y3 := Y - 1 to min(y2 + 1, png.Height) do
                    for x3 := X - 1 to min(x2 + 1, png.Width) do
                      map[y3][x3] := '_';
                  SetLength(Projects[High(Projects)].map.ROOMs, length(Projects[High(Projects)].map.ROOMs) + 1);
                  Projects[High(Projects)].map.ROOMs[High(Projects[High(Projects)].map.ROOMs)][0] := X - 1 - ppoint[0];
                  Projects[High(Projects)].map.ROOMs[High(Projects[High(Projects)].map.ROOMs)][1] := Y - 1 - ppoint[1];
                  Projects[High(Projects)].map.ROOMs[High(Projects[High(Projects)].map.ROOMs)][2] := x2 + 1 - ppoint[0];
                  Projects[High(Projects)].map.ROOMs[High(Projects[High(Projects)].map.ROOMs)][3] := y2 + 1 - ppoint[1];
                end;
            for i := 0 to length(Projects[High(Projects)].map.Ds) - 1 do
            begin
              Projects[High(Projects)].map.Ds[i][0] := Projects[High(Projects)].map.Ds[i][0] - ppoint[0];
              Projects[High(Projects)].map.Ds[i][1] := Projects[High(Projects)].map.Ds[i][1] - ppoint[1];
            end;
            output_s.strings[output_s.Count - 1] := output_s.strings[output_s.Count - 1] + 'OK';

          end
          else
          begin
            output_s.strings[output_s.Count - 1] := output_s.strings[output_s.Count - 1] + '!ERROR! map file not found ';
            inc(errs);
          end;
          png.Free;
        end;
        // end;
      until FindNext(sr) <> 0;
    FindClose(sr);
    writeln(']');
    {
      mys := (LoadDirectory + '\projects\' + prjfolder + '\tasks.ini');
      all_task_info := TMemIniFile.Create(mys);
      for i := Low(tasks_info) to High(tasks_info) do
      tasks_info[i].Free;
      time_freeze := all_task_info.ReadInt64('Count', 'time_freeze', 3000000000);
      time_end := all_task_info.ReadInt64('Count', 'time_end', 3000000000);
      string_freeze := '';
      SetLength(tasks_info, all_task_info.ReadInteger('Count', 'tasks', 0));
      SetLength(tasks, all_task_info.ReadInteger('Count', 'tasks', 0));
      for i := 0 to High(tasks_info) do
      begin
      tasks_info[i] := TMyTask.Create;
      tasks_info[i].STime := all_task_info.ReadInt64('Task:' + i.ToString,
      'time', 0);
      tasks_info[i].URLDefaultProgram := all_task_info.ReadString
      ('Task:' + i.ToString, 'URLDefaultProgram', '');
      tasks_info[i].name := all_task_info.ReadString('Task:' + i.ToString,
      'name', '');
      tasks[i] := tasks_info[i].name;
      SetLength(tasks_info[i].test,
      all_task_info.ReadInteger('Task:' + i.ToString, 'test_count', 0));
      for j := Low(tasks_info[i].test) to High(tasks_info[i].test) do
      tasks_info[i].test[j] := all_task_info.ReadString('Task:' + i.ToString,
      'test_' + j.ToString, '');

      SetLength(tasks_info[i].tab, all_task_info.ReadInteger('Task:' + i.ToString,
      'tab_count', 0));
      for j := Low(tasks_info[i].tab) to High(tasks_info[i].tab) do
      begin
      tasks_info[i].tab[j] := TTab.Create;
      tasks_info[i].tab[j]._name := all_task_info.ReadString
      ('Task:' + i.ToString, 'tab_' + j.ToString + '_name', '');
      tasks_info[i].tab[j]._type := all_task_info.ReadString
      ('Task:' + i.ToString, 'tab_' + j.ToString + '_type', '');
      if tasks_info[i].tab[j]._type = 'text' then
      tasks_info[i].tab[j]._text := all_task_info.ReadString
      ('Task:' + i.ToString, 'tab_' + j.ToString + '_text', '')
      else if (tasks_info[i].tab[j]._type = 'site') or
      (tasks_info[i].tab[j]._type = 'fil') then
      tasks_info[i].tab[j]._text := all_task_info.ReadString
      ('Task:' + i.ToString, 'tab_' + j.ToString + '_url', '')
      else if tasks_info[i].tab[j]._type = 'load' then
      tasks_info[i].tab[j]._text := ''
      else
      writeln('no found type ' + tasks_info[i].tab[j]._type + ' on ' +
      tasks_info[i].tab[j]._name);


      // _text: if  _type=text
      // _url : if  _type=site  or  _type=fil
      // ____ : if  _type=load

      end;
      end;
      all_task_info.Free; }
    { g := 0;
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
      if (mys[i] = '[') or (mys[i] = '') then
      g := g + 1;
      if (mys[i] = '') or (mys[i] = ']') then
      g := g - 1;
      if (mys[i] = '"') or (mys[i] = '''') then
      begin
      instr := true;
      ss := '';
      end;

      end;
      i := i + 1;
      end; }
    // ---------
  finally
    writeln(output_s.text);
  end;
  writeln('');
  write('Geting player info: ');
  ini := TMemIniFile.Create(LoadDirectory + '\projects\defaut.ini');
  for i := 0 to High(Players) do
    Players[i].Free;
  SetLength(Players, 0);
  SetLength(Players, ini.ReadInteger('Players', 'count', 0));
  for i := 0 to High(Players) do
  begin
    Players[i] := TPlayer.Create;
    Players[i].login := ini.ReadString('Player:' + i.ToString, 'login', '');
    Players[i].name := MyINI2TXT(ini.ReadString('Player:' + i.ToString, 'name', ''));
    Players[i].password := ini.ReadString('Player:' + i.ToString, 'password', '');

    SetLength(Players[i].pos, ini.ReadInteger('Player:' + i.ToString, 'pos_count', 0));
    for j := 0 to High(Players[i].pos) do
    begin
      Players[i].pos[j] := Aarraofstrintint.Create();
      Players[i].pos[j].uniID := ini.ReadString('Player:' + i.ToString, 'pos:' + j.ToString + ':uniID', '');
      Players[i].pos[j].posx := ini.ReadInteger('Player:' + i.ToString, 'pos:' + j.ToString + ':posx', 0);
      Players[i].pos[j].posy := ini.ReadInteger('Player:' + i.ToString, 'pos:' + j.ToString + ':posy', 0);
    end;

    Players[i].isAdmin := ini.ReadBool('Player:' + i.ToString, 'isAdmin', false);
    // -------
    SetLength(Players[i].Dors, length(RunProjects));
    SetLength(Players[i].Dors, ini.ReadInteger('Player:' + i.ToString, 'dor_count', 0));
    SetLength(Players[i].IsAccess, ini.ReadInteger('Player:' + i.ToString, 'isaccess_count', 0));

    // ini.WriteInteger('Player:' + i.ToString, 'dor_count', High(Players[i].Dors));
    for j := 0 to ini.ReadInteger('Player:' + i.ToString, 'dor_count', 0) - 1 do
    begin
      Players[i].Dors[j] := Aarraofstrint.Create();
      Players[i].Dors[j].uniID := ini.ReadString('Player:' + i.ToString, 'dors:' + j.ToString + ':uniID', '');
      Players[i].Dors[j].pos := ini.ReadInteger('Player:' + i.ToString, 'dors:' + j.ToString + ':pos', 0);
    end;
    for j := 0 to ini.ReadInteger('Player:' + i.ToString, 'isaccess_count', 0) - 1 do
    begin
      Players[i].IsAccess[j] := Aarraofstrint.Create();
      Players[i].IsAccess[j].uniID := ini.ReadString('Player:' + i.ToString, 'isaccess:' + j.ToString + ':uniID', '');
      Players[i].IsAccess[j].pos := ini.ReadInteger('Player:' + i.ToString, 'isaccess:' + j.ToString + ':pos', 0);
    end;
    SetLength(Players[i].programs, ini.ReadInteger('Player:' + i.ToString, 'programm_num', 0));
    for j := 0 to High(Players[i].programs) do
    begin
      Players[i].programs[j] := TProgram.Create();
      Players[i].programs[j].programm := MyINI2TXT(ini.ReadString('Player:' + i.ToString, 'programm_' + j.ToString + '_programm', ''));
      Players[i].programs[j].exit_data := MyINI2TXT(ini.ReadString('Player:' + i.ToString, 'programm_' + j.ToString + '_exit_data', ''));
      Players[i].programs[j].res := MyINI2TXT(ini.ReadString('Player:' + i.ToString, 'programm_' + j.ToString + '_res', 'OK'));
      Players[i].programs[j].task := ini.ReadInteger('Player:' + i.ToString, 'programm_' + j.ToString + '_task', 0);
      Players[i].programs[j].date := ini.ReadInt64('Player:' + i.ToString, 'programm_' + j.ToString + '_date', 0);
      Players[i].programs[j].uniID := ini.ReadString('Player:' + i.ToString, 'programm_' + j.ToString + '_uniID', '');
    end;

    Players[i].Pers[0] := ini.ReadInteger('Player:' + i.ToString, 'personage_skin', 50);
    Players[i].Pers[1] := ini.ReadInteger('Player:' + i.ToString, 'personage_hairstyle', 6);
    Players[i].Pers[2] := ini.ReadInteger('Player:' + i.ToString, 'personage_eye', 4);
    Players[i].Pers[3] := ini.ReadInteger('Player:' + i.ToString, 'personage_shirt', 1);
    Players[i].Pers[4] := ini.ReadInteger('Player:' + i.ToString, 'personage_pants', 2);
    Players[i].Pers[5] := ini.ReadInteger('Player:' + i.ToString, 'personage_footwear', 4);

    SetLength(Players[i].dollars, ini.ReadInteger('Player:' + i.ToString, 'dollars', 0));
    for j := 0 to High(Players[i].dollars) do
    begin
      Players[i].dollars[j] := Aarraofstrint.Create();
      Players[i].dollars[j].uniID := ini.ReadString('Player:' + i.ToString, 'dollar:' + j.ToString + ':uniID', '');
      Players[i].dollars[j].pos := ini.ReadInteger('Player:' + i.ToString, 'dollar:' + j.ToString + ':pos', 0);
    end;
  end;
  writeln('OK');
  write('Geting Run Projects info: ');
  ini := TMemIniFile.Create(LoadDirectory + '\projects\defaut.ini');
  for i := Low(RunProjects) to High(RunProjects) do
    RunProjects[i].Free;
  SetLength(RunProjects, 0);
  for i := 0 to ini.ReadInteger('RunProjects', 'count', 0) - 1 do
  begin
    if (ini.ReadInteger('RunProjects:' + i.ToString, 'parentInd', 0) >= low(Projects)) and (ini.ReadInteger('RunProjects:' + i.ToString, 'parentInd', 0) <= high(Projects)) then
    begin
      SetLength(RunProjects, length(RunProjects) + 1);
      RunProjects[High(RunProjects)] := TRunProject.Create();
      RunProjects[High(RunProjects)].parentInd := ini.ReadInteger('RunProjects:' + i.ToString, 'parentInd', 0);
      RunProjects[High(RunProjects)].uniID := ini.ReadString('RunProjects:' + i.ToString, 'uniID', '');
      RunProjects[High(RunProjects)].visib_name := MyINI2TXT(ini.ReadString('RunProjects:' + i.ToString, 'visib_name', ''));
      RunProjects[High(RunProjects)].string_freeze := MyINI2TXT(ini.ReadString('RunProjects:' + i.ToString, 'string_freeze', ''));
      RunProjects[High(RunProjects)].time_start := ini.ReadInt64('RunProjects:' + i.ToString, 'time_start', 0);
      RunProjects[High(RunProjects)].time_freeze := ini.ReadInt64('RunProjects:' + i.ToString, 'time_freeze', 0);
      RunProjects[High(RunProjects)].time_end := ini.ReadInt64('RunProjects:' + i.ToString, 'time_end', 0);
      RunProjects[High(RunProjects)].group := MyINI2TXT(ini.ReadString('RunProjects:' + i.ToString, 'group', ''));
    end
    else
    begin
      write('!WARNING! defaut.ini is not valid ');
      inc(warns);
    end;
  end;
  writeln('OK');
  ini.Free;
  writeln('');
  writeln('');
  writeln('');
  writeln('Warning: ' + warns.ToString);
  writeln('Errors: ' + errs.ToString);
  if errs > 0 then
    Result := false;
  isLoadingini := false;
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
      reserv[High(reserv)] := TMemIniFile.Create(LoadDirectory + '\autosaves\' + DateToFileName(Now) + '.ini');
      saveini(reserv[High(reserv)]);
    end
    else
    begin
      writeln('saveing');
      adminsave := TMemIniFile.Create(LoadDirectory + '\autosaves\' + DateToFileName(Now) + '.ini');
      saveini(adminsave);
      adminsave.UpdateFile;
      adminsave.Free;
      adminsave := TMemIniFile.Create(LoadDirectory + '\projects\defaut.ini');
      saveini(adminsave);
      adminsave.UpdateFile;
      adminsave.Free;
      // write('>');
    end

end;

function GetTPSInfo(): string;
var
  str2: string;
  myk, myj, myi: longint;
  IDate: T2Date;
begin
  myj := 0;
  myk := 0;
  for myi := 0 to 59 do
    if tps[myi] > 0 then
    begin
      myj := myj + (tps[myi] - 1);
      inc(myk);
    end;
  if myk = 0 then
    str2 := 'Использовано памяти для усреднения: ' + myk.ToString + #13#10 + 'Нет запросов'
  else if myj = 0 then
    str2 := 'Использовано памяти для усреднения: ' + myk.ToString + #13#10 + 'Всё мгновенно (<1мс)'
  else
    str2 := 'Использовано памяти для усреднения: ' + myk.ToString + #13#10 + 'На запрос в среднем: ' + FloatToStrF((myj / myk), ffFixed, 10, 2) + ' мс' + #13#10 +
      'С этой нагрузкой сервер может выдержать ' + FloatToStrF(1000 / (myj / myk), ffFixed, 10, 2) + ' запросов в секунду';
  str2 := str2 + #13#10#13#10;
  str2 := str2 + 'Тестирующая система: ';
  if (DateTimeToUnix(Now(), false) - last_request_testing) <= 30 then
    str2 := str2 + 'работает '
  else
    str2 := str2 + 'не работает ';
  if (DateTimeToUnix(Now(), false) - last_request_testing) > 1000000000 then
    str2 := str2 + #13#10
  else
    str2 := str2 + '(Последнее соединение было ' + (DateTimeToUnix(Now(), false) - last_request_testing).ToString + ' секунд назад)' + #13#10 + #13#10;
  str2 := str2 + '        ╔══════════════════════════════════════════════════╗' + #13#10;
  for myk := 0 to 11 do
  begin
    myj := 0;
    tps_que_cs.Enter;
    try
      for myi := 0 to High(tps_que) do
      begin
        IDate := tps_que[myi];
        if (MilliSecondsBetween(IDate._start, Now) >= (myk) * 5000) and (MilliSecondsBetween(IDate._start, Now) < (myk + 1) * 5000) then
          myj := myj + MilliSecondsBetween(IDate._start, IDate._end) + 1;
      end;
    finally
      tps_que_cs.Leave;
    end;
    str2 := str2 + '-' + ((myk * 5 + 5) div 10).ToString + ((myk * 5 + 5) mod 10).ToString + ' sec ║';
    for myi := 1 to round(myj / 5000 * 48) do
      str2 := str2 + '-';
    str2 := str2 + '|';
    for myi := round(myj / 5000 * 48) to 48 do
      str2 := str2 + ' ';
    str2 := str2 + '║ ' + round(myj / 5000 * 100).ToString + '%' + #13#10;
  end;
  str2 := str2 + '        ╚══════════════════════════════════════════════════╝' + #13#10;
  Result := str2;
end;

function GetIndex(s: string): longint;
var
  i: longint;
begin
  Result := -1;
  for i := Low(Players) to High(Players) do
    if Players[i].login = s then
    begin
      Result := i;
      exit;
    end;
end;

function registering(str: TStrings): string;

var
  login, name, password, seed, answer, key: String;
  i, j: integer;
begin
  // str.:=TEncoding.UTF8;
  // TEncoding.Convert(TEncoding.GetEncoding(''))
  login := '';
  password := '';
  seed := '0';
  answer := '';
  Result := 'OK';
  for key in str do
  begin
    if key.Split(['='])[0] = 'login' then
      login := key.Split(['='])[1];
    if key.Split(['='])[0] = 'name' then
      name := key.Split(['='])[1];
    if key.Split(['='])[0] = 'password' then
      password := key.Split(['='])[1];
    if key.Split(['='])[0] = 'seed' then
      seed := key.Split(['='])[1];
    if key.Split(['='])[0] = 'answer' then
      answer := key.Split(['='])[1];
  end;

  if (length(login) >= 32) then
    Result := 'log_not_valid';
  if (length(name) >= 256) then
    Result := 'name_not_valid';
  if (length(password) >= 32) then
    Result := 'pas_not_valid';

  if (length(login) < 3) then
    Result := 'log_not_valid';
  if (length(name) < 3) then
    Result := 'name_not_valid';
  if (length(password) < 3) then
    Result := 'pas_not_valid';

  if (length(seed) >= 32) then
    Result := 'seed_not_valid';
  if (length(answer) >= 128) then
    Result := 'answer_not_valid';

  if (login <> ClearStr(login)) then
    Result := 'log_not_valid';
  if (GetIndex(login) <> -1) then
    Result := 'log_not_valid2';
  if (login = admin_of_admin.name) then
    Result := 'log_not_valid2';
  if (name <> ClearStr(name, '-0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ. ')) then
    Result := 'name_not_valid';
  if (password <> ClearStr(password)) then
    Result := 'pas_not_valid';
  if (seed <> ClearStr(seed, '0123456789')) then
    Result := 'seed_not_valid';
  if (answer <> ClearStr(answer, '-0123456789ABCDEF')) then
    Result := 'answer_not_valid';
  if Result = 'OK' then
  begin
    if answer = '' then
    begin
      Result := GenCaptcha('login:=' + login + 'password:=' + password + 'seed:=' + seed + ';', false);
    end
    else if AnsiUpperCase(TIdURI.URLDecode((answer.Replace('-', '%')))) <> GenCaptcha('login:=' + login + 'password:=' + password + 'seed:=' + seed + ';', true) then
      Result := 'answer_not_valid2'
    else if TIdURI.URLDecode((name.Replace('-', '%'))) <> ClearStr(TIdURI.URLDecode((name.Replace('-', '%'))),
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZабвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ0123456789. ') then
      Result := 'name_not_valid'
    else
    begin
      SetColorConsole(clAqua);
      writeln('add player');
      SetColorConsole(clWhite);
      SetLength(Players, length(Players) + 1);
      Players[High(Players)] := TPlayer.Create;
      Players[High(Players)].login := login;
      Players[High(Players)].name := TIdURI.URLDecode((name.Replace('-', '%')));
      Players[High(Players)].password := password;
      SetLength(Players[High(Players)].pos, 0);

      Players[High(Players)].isAdmin := false;
      SetLength(Players[High(Players)].Dors, 0);
      SetLength(Players[High(Players)].IsAccess, 0);
      Players[High(Players)].Pers[0] := 59;
      Players[High(Players)].Pers[1] := 1;
      Players[High(Players)].Pers[2] := 7;
      Players[High(Players)].Pers[3] := 16;
      Players[High(Players)].Pers[4] := 5;
      Players[High(Players)].Pers[5] := 2;
      Players[High(Players)].Scores := 0;
      Players[High(Players)].Fine := 0;
      Players[High(Players)].group := '';
      SetLength(Players[High(Players)].dollars, 0);
      SetLength(Players[High(Players)].programs, 0);
      writeln(logs, 'add player');
      writeln(logs, 'login: ' + login);
      writeln(logs, 'password: ' + password);
      writeln(logs, '....OK');
      writeln(logs, '');
      write('>');
    end;

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

function GetIPs(port: string): String;
var
  i: longint;
begin
  TIdStack.IncUsage;
  try
    if GStack.LocalAddresses.Count <= 1 then
      Result := GetIP + port
    else
    begin
      Result := GStack.LocalAddresses[0] + port + ' (';
      for i := 1 to GStack.LocalAddresses.Count - 2 do
        Result := Result + GStack.LocalAddresses[i] + port + ', ';
      Result := Result + GStack.LocalAddresses[GStack.LocalAddresses.Count - 1] + port + ')';
    end;
  finally
    TIdStack.DecUsage;
  end;
end;

procedure write_server_data();
var
  f: text;
  i: longint;
  ips, port: string;
begin
  port := ':' + Server.DefaultPort.ToString;
  ips := 'localhost' + port;
  TIdStack.IncUsage;
  try
    for i := 0 to GStack.LocalAddresses.Count - 1 do
      ips := ips + ';;' + GStack.LocalAddresses[i] + port;
  finally
    TIdStack.DecUsage;
  end;
  AssignFile(f, LoadDirectory + '\port.txt');
  ReWrite(f);
  writeln(f, ips + #13#10 + admin_of_admin.name + #13#10 + admin_of_admin.password);
  Closefile(f);

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

function GetDollar(X, Y: int64; n: string; PrjInd: longint): boolean;
var
  i, j, k, f, PlaInd, x1, y1: longint;
begin
  PlaInd := GetIndex(n);
  if Players[PlaInd].isAdmin then
    exit;
  for i := 0 to High(Projects[RunProjects[PrjInd].parentInd].map.Ds) do
  // if Projects[prjInd].map.ReadInteger('D:' + i.ToString, 'getit', -1) < 0 then
  begin
    x1 := Projects[RunProjects[PrjInd].parentInd].map.Ds[i][0];
    y1 := Projects[RunProjects[PrjInd].parentInd].map.Ds[i][1];
    if (y1 = Y) and (x1 = X) then
    begin
      // Projects[prjInd].map.WriteInteger('D:' + i.ToString, 'getit', PlaInd);
      f := 0;
      for j := 0 to High(Players) do
        for k := 0 to High(Players[j].dollars) do
          if (RunProjects[PrjInd].uniID = Players[j].dollars[k].uniID) and (Players[j].dollars[k].pos = i) then
          begin
            f := 1;
          end;
      if f = 0 then
      begin
        SetLength(Players[PlaInd].dollars, length(Players[PlaInd].dollars) + 1);
        Players[PlaInd].dollars[High(Players[PlaInd].dollars)] := Aarraofstrint.Create();
        Players[PlaInd].dollars[High(Players[PlaInd].dollars)].uniID := RunProjects[PrjInd].uniID;
        Players[PlaInd].dollars[High(Players[PlaInd].dollars)].pos := i;
        exit;
      end;
    end;
  end;
end;

function OpenAccess(X, Y: int64; n: string; PrjInd: longint): boolean;
var
  i, j, PlaInd, x1, y1, f: longint;
begin
  PlaInd := GetIndex(n);
  for i := 0 to High(Projects[RunProjects[PrjInd].parentInd].map.RVs) do
  begin
    x1 := Projects[RunProjects[PrjInd].parentInd].map.RVs[i].pos[0];
    y1 := Floor((Projects[RunProjects[PrjInd].parentInd].map.RVs[i].pos[1] + Projects[RunProjects[PrjInd].parentInd].map.RVs[i].pos[2]) / 2);
    if (x1 = X) and (y1 = Y) then
      if not((Projects[RunProjects[PrjInd].parentInd].map.RVs[i].task = '') or (Projects[RunProjects[PrjInd].parentInd].map.RVs[i].task = 'open')) then
        if not DorIsOpen(Players[PlaInd], PrjInd, Projects[RunProjects[PrjInd].parentInd].map.RVs[i].task) then
        begin
          f := 1;
          for j := 0 to High(Players[PlaInd].IsAccess) do
            if (Players[PlaInd].IsAccess[j].uniID = RunProjects[PrjInd].uniID) and (Players[PlaInd].IsAccess[j].pos = 2 * i) then
            begin
              f := 0;
            end;
          if f = 1 then
          begin
            SetLength(Players[PlaInd].IsAccess, length(Players[PlaInd].IsAccess) + 1);
            Players[PlaInd].IsAccess[High(Players[PlaInd].IsAccess)] := Aarraofstrint.Create();
            Players[PlaInd].IsAccess[High(Players[PlaInd].IsAccess)].uniID := RunProjects[PrjInd].uniID;
            Players[PlaInd].IsAccess[High(Players[PlaInd].IsAccess)].pos := i * 2;
          end;
          exit;
        end;
  end;
  for i := 0 to High(Projects[RunProjects[PrjInd].parentInd].map.RHs) do
  begin
    y1 := Projects[RunProjects[PrjInd].parentInd].map.RHs[i].pos[0];
    x1 := Floor((Projects[RunProjects[PrjInd].parentInd].map.RHs[i].pos[1] + Projects[RunProjects[PrjInd].parentInd].map.RHs[i].pos[2]) / 2);

    if (x1 = X) and (y1 = Y) then
      if not((Projects[RunProjects[PrjInd].parentInd].map.RHs[i].task = '') or (Projects[RunProjects[PrjInd].parentInd].map.RHs[i].task = 'open')) then
        if not DorIsOpen(Players[PlaInd], PrjInd, Projects[RunProjects[PrjInd].parentInd].map.RHs[i].task) then
        begin
          f := 1;
          for j := 0 to High(Players[PlaInd].IsAccess) do
            if (Players[PlaInd].IsAccess[j].uniID = RunProjects[PrjInd].uniID) and (Players[PlaInd].IsAccess[j].pos = 2 * i + 1) then
            begin
              f := 0;
            end;
          if f = 1 then
          begin
            SetLength(Players[PlaInd].IsAccess, length(Players[PlaInd].IsAccess) + 1);
            Players[PlaInd].IsAccess[High(Players[PlaInd].IsAccess)] := Aarraofstrint.Create();
            Players[PlaInd].IsAccess[High(Players[PlaInd].IsAccess)].uniID := RunProjects[PrjInd].uniID;
            Players[PlaInd].IsAccess[High(Players[PlaInd].IsAccess)].pos := i * 2 + 1;
          end;
          exit;
        end;
  end;
end;

function InHouse(X, Y: int64; n: string; PrjInd: longint): boolean;
var
  i, PlaInd, x1, y1, x2, y2: longint;
begin
  PlaInd := GetIndex(n);
  Result := false;
  for i := 0 to High(Projects[RunProjects[PrjInd].parentInd].map.ROOMs) do
  begin
    x1 := Projects[RunProjects[PrjInd].parentInd].map.ROOMs[i][0];
    y1 := Projects[RunProjects[PrjInd].parentInd].map.ROOMs[i][1];
    x2 := Projects[RunProjects[PrjInd].parentInd].map.ROOMs[i][2];
    y2 := Projects[RunProjects[PrjInd].parentInd].map.ROOMs[i][3];
    if (x2 > X) and (X > x1) and (y2 > Y) and (Y > y1) then
    begin
      Result := true;
      exit;
    end;
  end;
  for i := 0 to High(Projects[RunProjects[PrjInd].parentInd].map.RVs) do
  begin
    x1 := Projects[RunProjects[PrjInd].parentInd].map.RVs[i].pos[0];
    y1 := Projects[RunProjects[PrjInd].parentInd].map.RVs[i].pos[1];
    y2 := Projects[RunProjects[PrjInd].parentInd].map.RVs[i].pos[2];
    if not Players[PlaInd].isAdmin then
      if x1 = X then
        if Y = Floor((y1 + y2) / 2) then
          if not((Projects[RunProjects[PrjInd].parentInd].map.RVs[i].task = '') or (Projects[RunProjects[PrjInd].parentInd].map.RVs[i].task = 'open')) then
            if not DorIsOpen(Players[PlaInd], PrjInd, Projects[RunProjects[PrjInd].parentInd].map.RVs[i].task) then
            begin
              Result := false;
              exit;
            end;

    if (x1 = X) and (y2 >= Y) and (Y >= y1) then
    begin
      Result := true;
      exit;
    end;
  end;
  for i := 0 to High(Projects[RunProjects[PrjInd].parentInd].map.RHs) do
  begin
    y1 := Projects[RunProjects[PrjInd].parentInd].map.RHs[i].pos[0];
    x1 := Projects[RunProjects[PrjInd].parentInd].map.RHs[i].pos[1];
    x2 := Projects[RunProjects[PrjInd].parentInd].map.RHs[i].pos[2];
    if not Players[PlaInd].isAdmin then
      if y1 = Y then
        if X = Floor((x1 + x2) / 2) then
          if not((Projects[RunProjects[PrjInd].parentInd].map.RHs[i].task = '') or (Projects[RunProjects[PrjInd].parentInd].map.RHs[i].task = 'open')) then
            if not DorIsOpen(Players[PlaInd], PrjInd, Projects[RunProjects[PrjInd].parentInd].map.RHs[i].task) then
            begin
              Result := false;
              exit;
            end;

    if (y1 = Y) and (x2 >= X) and (X >= x1) then
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
    move(a[Index + 1], a[Index], (Last - Index) * SizeOf(a[Index]));
  SetLength(a, Last);
end;

function GetSortPlayers(ind: boolean; PrjInd: longint): ansistring;
var
  a, max_time, min_time: array of int64;
  i, j, k, m: longint;
  time: int64;
begin
  SetLength(a, length(Projects[RunProjects[PrjInd].parentInd].tasks));
  SetLength(max_time, length(Projects[RunProjects[PrjInd].parentInd].tasks));
  for i := 0 to High(Projects[RunProjects[PrjInd].parentInd].tasks) do
    max_time[i] := 0;
  SetLength(min_time, length(Projects[RunProjects[PrjInd].parentInd].tasks));
  for i := 0 to High(min_time) do
    min_time[i] := 9223372036854775807;
  Result := 'names;scores;fine;';
  for i := 0 to High(Projects[RunProjects[PrjInd].parentInd].tasks) do
    Result := Result + Projects[RunProjects[PrjInd].parentInd].tasks[i] + ';';
  Result := Result + #13#10;
  for i := 0 to High(Players) do
  begin
    Players[i].Scores := 0;
    // if  then

    for j := 0 to High(Players[i].programs) do
      if Players[i].programs[j].uniID = RunProjects[PrjInd].uniID then
        // if ((not Players[i].isAdmin) and (not ind)) or (ind) then
        if Players[i].programs[j].res = 'OK' then
        begin
          inc(a[Players[i].programs[j].task]);
          if not Players[i].isAdmin then
            if (max_time[Players[i].programs[j].task] < Players[i].programs[j].date) then
              max_time[Players[i].programs[j].task] := Players[i].programs[j].date;
          if not Players[i].isAdmin then
            if (min_time[Players[i].programs[j].task] > Players[i].programs[j].date) then
              min_time[Players[i].programs[j].task] := Players[i].programs[j].date;
          inc(Players[i].Scores, 100);
        end;
    for j := 0 to High(Players[i].dollars) do
      if Players[i].dollars[j].uniID = RunProjects[PrjInd].uniID then
        Players[i].Scores := Players[i].Scores + 1;
  end;
  for i := 0 to High(Players) do
  begin
    Players[i].Fine := 0;
    if Players[i].isAdmin then
      continue;
    m := 0;
    for j := 0 to High(Players[i].programs) do
      if Players[i].programs[j].uniID = RunProjects[PrjInd].uniID then
        // if ((not Players[i].isAdmin) and (not ind)) or (ind) then
        if not Players[i].isAdmin then
          if Players[i].programs[j].res = 'OK' then
          begin
            m := m + 1;
            time := Players[i].programs[j].date;
            k := Players[i].programs[j].task;
            if (a[Players[i].programs[j].task] <= 1) then
              inc(Players[i].Fine, 1000)
            else
              inc(Players[i].Fine, Floor((1 - (time - min_time[k]) / (max_time[k] - min_time[k])) * 1000 + ((time - min_time[k]) / (max_time[k] - min_time[k])) * (250 / a[k] + 750)));

          end;
    Players[i].Fine := m * 1000 - Players[i].Fine;
  end;
  for i := 0 to High(Players) do
    if length(Players[i].IsAccess) >= 1 then
    begin
      if (not ind) then
        if (Players[i].isAdmin) then
          continue;
      k := 1;
      for j := 0 to High(Players[i].pos) do
        if Players[i].pos[j].uniID = RunProjects[PrjInd].uniID then
        begin
          k := 0;
          break;
        end;
      if k = 0 then
      begin
        if ind then
          Result := Result + Players[i].login + ' (' + Players[i].name + ')'
        else
          Result := Result + Players[i].login;
        Result := Result + ';' + Players[i].Scores.ToString + ';' + Players[i].Fine.ToString + ';';
        for j := 0 to High(Players[i].Dors) do
          if (Players[i].Dors[j].pos mod 2 = 0) then
          begin
            if (Players[i].Dors[j].uniID = RunProjects[PrjInd].uniID) then
            begin
              Result := Result + '''' + Projects[RunProjects[PrjInd].parentInd].map.RVs[Players[i].Dors[j].pos div 2].task + ''';';
            end;
          end
          else
          begin
            if (Players[i].Dors[j].uniID = RunProjects[PrjInd].uniID) then
            begin
              Result := Result + '''' + Projects[RunProjects[PrjInd].parentInd].map.RHs[Players[i].Dors[j].pos div 2].task + ''';';

            end;
          end;
        Result := Result + #13#10;
      end;
    end;

end;

function AdminFile(s, prog: string): string;
var
  i, j, k: integer;
  s2, s3, s4: string;
begin
  Result := s;
  if (s = 'login') then
    Result := 'OKADMINOFADMIN'
  else if (s = 'get_prj') then
  begin
    Result := 'name_folder;name;tasks;' + #13#10;
    for i := 0 to High(Projects) do
    begin
      Result := Result + Projects[i].folder + ';';
      Result := Result + Projects[i].name + ';''';
      for j := 0 to High(Projects[i].tasks) do
        Result := Result + Projects[i].tasks[j] + ''', ''';
      Result := Result + ''';' + #13#10;
    end;
  end
  else if (s = 'get_run_prj') then
  begin
    Result := 'name_parent;visib_name;groups;time_start;time_freeze;time_end;uniID;' + #13#10;
    for i := 0 to High(RunProjects) do
    begin
      Result := Result + Projects[RunProjects[i].parentInd].name + ';';
      Result := Result + RunProjects[i].visib_name + ';';
      Result := Result + RunProjects[i].group + ';';
      Result := Result + RunProjects[i].time_start.ToString + ';';
      Result := Result + RunProjects[i].time_freeze.ToString + ';';
      Result := Result + RunProjects[i].time_end.ToString + ';';
      Result := Result + RunProjects[i].uniID + ';';
      Result := Result + #13#10;
    end;
  end
  else if (length(s.Split(['create_proj_'])) = 2) then
  begin
    if (length(s.Split(['_'])) <> 5) then
      Result := 'Bad request'
    else if s.Split(['_'])[2].ToInteger.ToString <> s.Split(['_'])[2] then
      Result := 'Bad request2'
    else if (length(s.Split(['_'])[3]) <> 10) then
      Result := 'Bad request3'
    else
    begin
      for i := 0 to High(RunProjects) do
        if RunProjects[i].uniID = s.Split(['_'])[3] then
        begin
          Result := 'uniID занят';
          exit;
        end;
      SetLength(RunProjects, length(RunProjects) + 1);
      RunProjects[High(RunProjects)] := TRunProject.Create;
      RunProjects[High(RunProjects)].parentInd := s.Split(['_'])[2].ToInteger;
      RunProjects[High(RunProjects)].uniID := s.Split(['_'])[3];
      RunProjects[High(RunProjects)].visib_name := 'copy ' + Projects[RunProjects[High(RunProjects)].parentInd].name;
      RunProjects[High(RunProjects)].string_freeze := '';
      RunProjects[High(RunProjects)].time_start := DateTimeToUnix(Now(), false) + 3600;
      RunProjects[High(RunProjects)].time_freeze := DateTimeToUnix(Now(), false) + 3600 * 2;
      RunProjects[High(RunProjects)].time_end := DateTimeToUnix(Now(), false) + 3600 * 3;
      RunProjects[High(RunProjects)].group := 'admins';
      Result := 'OK';
    end;

  end
  else if (length(s.Split(['del_proj_'])) = 2) then
  begin
    if (length(s.Split(['_'])) <> 4) then
      Result := 'Bad request'
    else if (length(s.Split(['_'])[2]) <> 10) then
      Result := 'Bad request3'
    else
    begin
      Result := 'NOTFOUND';
      for i := 0 to High(RunProjects) do
        if RunProjects[i].uniID = s.Split(['_'])[2] then
        begin
          RunProjects[i].Free;
          RunProjects[i] := RunProjects[High(RunProjects)];
          SetLength(RunProjects, length(RunProjects) - 1);
          Result := 'OK';
          exit;
        end;
    end;

  end
  else if s = 'save_dat' then
  begin
    prog := TIdURI.URLDecode(StringReplace(prog, '+', ' ', [rfReplaceAll, rfIgnoreCase]));
    // writeln(prog);
    for i := 0 to High(prog.Split([#10])) do
      if prog.Split([#10])[i] <> '' then
      begin
        if (length(prog.Split([#10])[i].Split([',s_p_l_i_t,'])) = 6) or (length(prog.Split([#10])[i].Split([',s_p_l_i_t,'])) = 7) then
        begin
          for j := 0 to High(RunProjects) do
            if prog.Split([#10])[i].Split([',s_p_l_i_t,'])[5] = RunProjects[j].uniID then
            begin
              RunProjects[j].visib_name := prog.Split([#10])[i].Split([',s_p_l_i_t,'])[0];
              RunProjects[j].group := prog.Split([#10])[i].Split([',s_p_l_i_t,'])[1];
              RunProjects[j].time_start := prog.Split([#10])[i].Split([',s_p_l_i_t,'])[2].ToInt64;
              RunProjects[j].time_freeze := prog.Split([#10])[i].Split([',s_p_l_i_t,'])[3].ToInt64;
              RunProjects[j].time_end := prog.Split([#10])[i].Split([',s_p_l_i_t,'])[4].ToInt64;
              if high(prog.Split([#10])[i].Split([',s_p_l_i_t,'])) >= 6 then
                if TryStrToInt(prog.Split([#10])[i].Split([',s_p_l_i_t,'])[6], k) then
                  if (k >= 0) and (k <= high(Projects)) then
                    RunProjects[j].parentInd := k;
            end;
        end;
      end;
  end
  else if (length(s.Split(['new_ID_'])) = 2) then
  begin
    if (length(s.Split(['_'])) <> 5) then
      Result := 'Bad request'
    else if (length(s.Split(['_'])[2]) <> 10) then
      Result := 'Bad request2'
    else if (length(s.Split(['_'])[3]) <> 10) then
      Result := 'Bad request3'
    else
    begin
      Result := 'NOTFOUND';
      for i := 0 to High(RunProjects) do
        if RunProjects[i].uniID = s.Split(['_'])[2] then
        begin
          RunProjects[i].uniID := s.Split(['_'])[3];
          Result := 'OK';
          exit;
        end;
    end;

  end
  else if (s = 'reg_on_or_of') then
  begin
    canlogin := not canlogin;
  end
  else if (s = 'get_list_players') then
  begin
    Result := '';
    for j := 0 to High(Players) do
    begin
      Result := Result + ';login:' + Players[j].login + ';name:' + Players[j].name + ';password:' + Players[j].password + ';isAdmin:' + Players[j].isAdmin.ToInteger.ToString + ';group:' +
        Players[j].group + #13#10;
    end;
  end
  else if (length(s.Split(['get_player_data_'])) = 2) then
  begin
    Result := '';
    k := GetIndex(s.Split(['get_player_data_'])[1]);
    if k = -1 then
    begin
      Result := 'player_not_found';
      exit;
    end;
    Result := Result + ';login:' + Players[k].login + #13#10;
    Result := Result + ';name:' + Players[k].name + Iif(Players[k].ip <> '', ' [' + Players[k].ip + ']') + #13#10;
    Result := Result + ';password:' + Players[k].password + #13#10;

    Result := Result + ';pos:' + length(Players[k].pos).ToString + #13#10;
    for j := 0 to High(Players[k].pos) do
    begin
      Result := Result + ';pos:' + j.ToString + ':uniID:' + Players[k].pos[j].uniID + #13#10;
      Result := Result + ';pos:' + j.ToString + ':posx:' + Players[k].pos[j].posx.ToString + #13#10;
      Result := Result + ';pos:' + j.ToString + ':posy:' + Players[k].pos[j].posy.ToString + #13#10;
    end;

    Result := Result + ';group:' + Players[k].group + #13#10;

    Result := Result + ';dollars:' + length(Players[k].dollars).ToString + #13#10;
    for j := 0 to High(Players[k].dollars) do
    begin
      Result := Result + ';dollars:' + j.ToString + ':uniID:' + Players[k].dollars[j].uniID + #13#10;
      Result := Result + ';dollars:' + j.ToString + ':pos:' + Players[k].dollars[j].pos.ToString + #13#10;
    end;

    Result := Result + ';isAdmin:' + Players[k].isAdmin.ToInteger.ToString + #13#10;

    Result := Result + ';Dors:' + length(Players[k].Dors).ToString + #13#10;
    for j := 0 to High(Players[k].Dors) do
    begin
      Result := Result + ';Dors:' + j.ToString + ':uniID:' + Players[k].Dors[j].uniID + #13#10;
      Result := Result + ';Dors:' + j.ToString + ':pos:' + Players[k].Dors[j].pos.ToString + #13#10;
    end;

    Result := Result + ';IsAccess:' + length(Players[k].IsAccess).ToString + #13#10;
    for j := 0 to High(Players[k].IsAccess) do
    begin
      Result := Result + ';IsAccess:' + j.ToString + ':uniID:' + Players[k].IsAccess[j].uniID + #13#10;
      Result := Result + ';IsAccess:' + j.ToString + ':pos:' + Players[k].IsAccess[j].pos.ToString + #13#10;
    end;

    Result := Result + ';programs:' + length(Players[k].programs).ToString + #13#10;
    i := 0;
    for j := High(Players[k].programs) downto 0 do
    begin
      inc(i);
      if i > 10 then
        break;
      Result := Result + ';programs:' + j.ToString + ':uniID:' + Players[k].programs[j].uniID + #13#10;
      Result := Result + ';programs:' + j.ToString + ':task:' + Players[k].programs[j].task.ToString + #13#10;
      Result := Result + ';programs:' + j.ToString + ':date:' + Players[k].programs[j].date.ToString + #13#10;
      Result := Result + ';programs:' + j.ToString + ':res:' + Players[k].programs[j].res + #13#10;
      Result := Result + ';programs:' + j.ToString + ':programm:' + StringReplace(StringReplace(Players[k].programs[j].programm, #13, '_return_', [rfReplaceAll, rfIgnoreCase]), #10, '_return2_',
        [rfReplaceAll, rfIgnoreCase]) + #13#10;
    end;

  end
  else if (s = 'rps') then
  begin
    Result := GetTPSInfo;
  end
  else if (s = 'exestrings') then
  begin
    prog := TIdURI.URLDecode(StringReplace(prog, '+', ' ', [rfReplaceAll, rfIgnoreCase]));
    Result := 'OK' + #13#10;
    s3 := '';
    s4 := '';
    for i := 0 to High(prog.Split([#10])) do
    begin
      s2 := trim(prog.Split([#10])[i]);
      if (pos('comand_select_serv ', s2) = 1) then
      begin
        k := 0;
        s3 := s2.Split(['comand_select_serv '])[1];
        for j := 0 to High(RunProjects) do
          if s3 = RunProjects[j].uniID then
          begin
            k := 1;
            break;
          end;
        if k = 1 then
          Result := Result + 'OK' + #13#10
        else
        begin
          Result := 'ERR_server_not_found' + #13#10;
          break;
        end;
      end;
      if (pos('comand_select_player ', s2) = 1) then
      begin
        k := 0;
        s4 := s2.Split(['comand_select_player '])[1];
        for j := 0 to High(Players) do
          if s4 = Players[j].login then
          begin
            k := 1;
            break;
          end;
        if k = 1 then
          Result := Result + 'OK' + #13#10
        else
        begin
          Result := 'ERR_player_not_found' + #13#10;
          break;
        end;
      end;
      if (pos('comand_del', s2) = 1) then
      begin
        if s4 = '' then
        begin
          Result := 'ERR_player_not_selected' + #13#10;
          break;
        end;
        k := GetIndex(s4);
        Players[k].Free;
        Players[k] := Players[High(Players)];
        SetLength(Players, length(Players) - 1);
        s4 := '';
        Result := Result + 'OK' + #13#10;
      end;
      if (pos('comand_pos_del', s2) = 1) then
      begin
        if s4 = '' then
        begin
          Result := 'ERR_player_not_selected' + #13#10;
          break;
        end;
        if s3 = '' then
        begin
          Result := 'ERR_server_not_selected' + #13#10;
          break;
        end;
        k := GetIndex(s4);
        for j := 0 to High(Players[k].pos) do
          if Players[k].pos[j].uniID = s3 then
          begin
            Players[k].pos[j].Free;
            Players[k].pos[j] := Players[k].pos[High(Players[k].pos)];
            SetLength(Players[k].pos, length(Players[k].pos) - 1);
            break;
          end;
        Result := Result + 'OK' + #13#10;
      end;
      if (pos('comand_access_del_', s2) = 1) then
      begin
        if s4 = '' then
        begin
          Result := 'ERR_player_not_selected' + #13#10;
          break;
        end;
        if s3 = '' then
        begin
          Result := 'ERR_server_not_selected' + #13#10;
          break;
        end;
        k := GetIndex(s4);
        for j := 0 to High(Players[k].IsAccess) do
          if Players[k].IsAccess[j].uniID = s3 then
            if Players[k].IsAccess[j].pos.ToString = s2.Split(['comand_access_del_'])[1] then
            begin
              Players[k].IsAccess[j].Free;
              Players[k].IsAccess[j] := Players[k].IsAccess[High(Players[k].IsAccess)];
              SetLength(Players[k].IsAccess, length(Players[k].IsAccess) - 1);
              break;
            end;
        Result := Result + 'OK' + #13#10;
      end;
      if (pos('comand_dor_del_', s2) = 1) then
      begin
        if s4 = '' then
        begin
          Result := 'ERR_player_not_selected' + #13#10;
          break;
        end;
        if s3 = '' then
        begin
          Result := 'ERR_server_not_selected' + #13#10;
          break;
        end;
        k := GetIndex(s4);
        for j := 0 to High(Players[k].Dors) do
          if Players[k].Dors[j].uniID = s3 then
            if Players[k].Dors[j].pos.ToString = s2.Split(['comand_dor_del_'])[1] then
            begin
              Players[k].Dors[j].Free;
              Players[k].Dors[j] := Players[k].Dors[High(Players[k].Dors)];
              SetLength(Players[k].Dors, length(Players[k].Dors) - 1);
              break;
            end;
        Result := Result + 'OK' + #13#10;
      end;
      if (pos('comand_re_login_', s2) = 1) then
      begin
        if s4 = '' then
        begin
          Result := 'ERR_player_not_selected' + #13#10;
          break;
        end;
        k := 0;
        for j := 0 to High(Players) do
          if s2.Split(['comand_re_login_'])[1] = Players[j].login then
          begin
            k := 1;
            break;
          end;
        if k = 1 then
        begin
          Result := 'ERR_login_used' + #13#10;
          break;
        end;
        if (s2.Split(['comand_re_login_'])[1] <> ClearStr(s2.Split(['comand_re_login_'])[1])) or (s2.Split(['comand_re_login_'])[1] = admin_of_admin.name) then
        begin
          Result := 'ERR_login_not_valid' + #13#10;
          break;
        end; {
          Result := 'log_not_valid2';
          if (name <> ClearStr(name, '-0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ. ')) then
          Result := 'name_not_valid';
          if (password <> ClearStr(password)) then
          Result := 'pas_not_valid';
          if (seed <> ClearStr(seed, '0123456789')) then
          Result := 'seed_not_valid';
          if (answer <> ClearStr(answer, '-0123456789ABCDEF')) then
          Result := 'answer_not_valid';
          if Result = 'OK' then
          begin
          if answer = '' then
          begin
          Result := GenCaptcha('login:=' + login + 'password:=' + password + 'seed:=' + seed + ';', false);
          end
          else if AnsiUpperCase(TIdURI.URLDecode((answer.Replace('-', '%')))) <> GenCaptcha('login:=' + login + 'password:=' + password + 'seed:=' + seed + ';', true) then
          Result := 'answer_not_valid2'
          else if TIdURI.URLDecode((name.Replace('-', '%'))) <> ClearStr(TIdURI.URLDecode((name.Replace('-', '%'))),
          'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZабвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ0123456789. ') then
        }
        k := GetIndex(s4);
        Players[k].login := s2.Split(['comand_re_login_'])[1];
        s4 := '';
        Result := Result + 'OK' + #13#10;
      end;
      if (pos('comand_re_name_', s2) = 1) then
      begin
        if s4 = '' then
        begin
          Result := 'ERR_player_not_selected' + #13#10;
          break;
        end;
        k := GetIndex(s4);
        Players[k].name := s2.Split(['comand_re_name_'])[1];
        s4 := '';
        Result := Result + 'OK' + #13#10;
      end;
      if (pos('comand_set_pas_', s2) = 1) then
      begin
        if s4 = '' then
        begin
          Result := 'ERR_player_not_selected' + #13#10;
          break;
        end;
        k := GetIndex(s4);
        Players[k].password := s2.Split(['comand_set_pas_'])[1];
        Result := Result + 'OK' + #13#10;
      end;
      if (pos('comand_set_group_', s2) = 1) then
      begin
        if s4 = '' then
        begin
          Result := 'ERR_player_not_selected' + #13#10;
          break;
        end;
        k := GetIndex(s4);
        Players[k].group := s2.Split(['comand_set_group_'])[1];
        Result := Result + 'OK' + #13#10;
      end;
      if (pos('comand_op_or_deop ', s2) = 1) then
      begin
        if s4 = '' then
        begin
          Result := 'ERR_player_not_selected' + #13#10;
          break;
        end;
        k := GetIndex(s4);
        if s2.Split(['comand_op_or_deop '])[1] = '1' then
          Players[k].isAdmin := true
        else
          Players[k].isAdmin := false;
        Result := Result + 'OK' + #13#10;
      end;
    end;

  end
  else if (length(s.Split(['GetFile'])) > 1) then
  begin
    if not FileExists(LoadDirectory + '/' + StringReplace(s.Split(['GetFile'])[1], '$', '\', [rfReplaceAll, rfIgnoreCase])) then
    begin
      Result := '404' + LoadDirectory + '/' + StringReplace(s.Split(['GetFile'])[1], '$', '\', [rfReplaceAll, rfIgnoreCase]);
      exit;
    end
    else
    begin
      Result := LoadFileToStr(LoadDirectory + '/' + StringReplace(s.Split(['GetFile'])[1], '$', '\', [rfReplaceAll, rfIgnoreCase]));
      exit;
    end;
  end
  else if (length(s.Split(['GetTests'])) > 1) then
  begin
    Result := '[';
    for i := 0 to High(Projects) do
    begin
      Result := Result + #13#10 + '{';
      for j := 0 to High(Projects[i].tasks) do
      begin
        Result := Result + #13#10;
        Result := Result + '"' + Projects[i].tasks[j] + '": [';
        for k := 0 to High(Projects[i].tasks_info[j].test) do
          Result := Result + '"' + StringReplace(Projects[i].folder, '\', '\/', [rfReplaceAll]) + Projects[i].tasks_info[j].test[k] + '",';
        if Result[length(Result)] = ',' then
          Delete(Result, length(Result), 1);
        Result := Result + '],';
      end;
      if Result[length(Result)] = ',' then
        Delete(Result, length(Result), 1);
      Result := Result + #13#10 + '},';
    end;
    if Result[length(Result)] = ',' then
      Delete(Result, length(Result), 1);
    Result := Result + #13#10 + ']';
  end
  else if (length(s.Split(['GetPrograms'])) > 1) then
  begin
    Result := ';';
    for i := 0 to High(Players) do // 10000000
      for j := 0 to High(Players[i].programs) do
        if (Players[i].programs[j].res = 'Queue') or (Players[i].programs[j].res = 'Testing') then
        begin
          Result := Result + (i * 10000000 + j).ToString() + ';';
        end;
    last_request_testing := DateTimeToUnix(Now(), false);
    exit;
  end
  else if (length(s.Split(['GetProgram'])) > 1) then
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
    for k := 0 to High(RunProjects) do
      if RunProjects[k].uniID = Players[i].programs[j].uniID then
      begin
        Result := RunProjects[k].parentInd.ToString + #13#10 + Projects[RunProjects[k].parentInd].tasks[Players[i].programs[j].task] + #13#10 + Players[i].programs[j].programm;
        break;
      end;
    exit;
  end
  else if (s.Split([';'])[0] = 'upload') then
  begin
    if (length(s.Split([';'])) <= 2) then
    begin
      Result := 'error1';
      exit;
    end;
    if (s.Split([';'])[1] <> 'res') then
    begin
      Result := 'error2';
      exit;
    end;
    if not TryStrToInt(s.Split([';'])[2], i) then
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
      Players[i].programs[j].exit_data := TIdURI.URLDecode(StringReplace(prog, '+', ' ', [rfReplaceAll, rfIgnoreCase]));
    end
    else
    begin
      Players[i].programs[j].res := 'OK';
      need_update := true;
      for k := 0 to High(RunProjects) do
        if RunProjects[k].uniID = Players[i].programs[j].uniID then
        begin
          DorOpen(Players[i], k, Projects[RunProjects[k].parentInd].tasks[Players[i].programs[j].task]);
        end;

    end;
    Result := 'OK';

  end;

end;

function SaveServFile(user, s, prog: string; PrjInd: longint): String;
var
  i, j, f: longint;
  userindex: longint;
begin
  // s = upload;kumir;B1;
  // s = upload;js;2134;
  if PrjInd < 0 then
  begin
    Result := 'error3';
    exit;
  end;

  Result := '___NoT_FoUnD_CoMmAnD__' + s + '___NoT_FoUnD_CoMmAnD__';
  if (length(s.Split([';'])) <= 2) then
  begin
    Result := 'error1';
    exit;
  end;
  if (s.Split([';'])[0] <> 'upload') or ((s.Split([';'])[1] <> 'res') and (s.Split([';'])[1] <> 'kumir')) then
  begin
    Result := 'error2';
    exit;
  end;

  userindex := GetIndex(user);

  // writeln(logs, s);
  writeln(logs, 'pl = ', MyTXT2INI(user));
  writeln(logs, 's = ', MyTXT2INI(TIdURI.URLDecode(StringReplace(s, '+', ' ', [rfReplaceAll, rfIgnoreCase]))));
  writeln(logs, 'prog = ', MyTXT2INI(TIdURI.URLDecode(StringReplace(prog, '+', ' ', [rfReplaceAll, rfIgnoreCase]))));
  flush(logs);
  if s.Split([';'])[1] = 'kumir' then
  begin
    f := 1;
    for j := 0 to High(Players[userindex].IsAccess) do
      if (Players[userindex].IsAccess[j].uniID = RunProjects[PrjInd].uniID) then
        if (Players[userindex].IsAccess[j].pos mod 2 = 0) then
        begin
          if (Players[userindex].IsAccess[j].uniID = RunProjects[PrjInd].uniID) and
            (Projects[RunProjects[PrjInd].parentInd].map.RVs[Players[userindex].IsAccess[j].pos div 2].task = TIdURI.URLDecode(StringReplace(s.Split([';'])[2], '+', ' ', [rfReplaceAll, rfIgnoreCase])))
          then
          begin
            f := 0;
            break;
          end;
        end
        else
        begin
          if (Players[userindex].IsAccess[j].uniID = RunProjects[PrjInd].uniID) and
            (Projects[RunProjects[PrjInd].parentInd].map.RHs[Players[userindex].IsAccess[j].pos div 2].task = TIdURI.URLDecode(StringReplace(s.Split([';'])[2], '+', ' ', [rfReplaceAll, rfIgnoreCase])))
          then
          begin
            f := 0;
            break;
          end;
        end;
    if f = 1 then
    begin
      Result := 'Иди решай задачи, а не пытайся обмануть систему)';
      exit;
    end;

    If (Players[userindex].LastProg <> prog) then
    begin
      // inc(ProgremNum);
      for i := 0 to High(Players[userindex].programs) do
        if Not((Players[userindex].programs[i].res = 'OK') or (Players[userindex].programs[i].res[1] = 'E')) then
        begin
          Result := 'Дождитесь завершения проверки всех задач';
          exit;
        end;
      j := -1;
      for i := 0 to High(Projects[RunProjects[PrjInd].parentInd].tasks) do
        if Projects[RunProjects[PrjInd].parentInd].tasks[i] = TIdURI.URLDecode(StringReplace(s.Split([';'])[2], '+', ' ', [rfReplaceAll, rfIgnoreCase])) then
          j := i;
      if j = -1 then
      begin
        Result := 'Данной задачи не найдено';
        exit;
      end;
      if RunProjects[PrjInd].time_start > DateTimeToUnix(Now(), false) then
      begin
        Result := 'Отправить решение на эту задачу можно будет через ' + ((RunProjects[PrjInd].time_start - DateTimeToUnix(Now(), false)) div 60).ToString + ' минут ' +
          ((RunProjects[PrjInd].time_start - DateTimeToUnix(Now(), false)) mod 60).ToString + ' секунд';
        exit;
      end;
      if RunProjects[PrjInd].time_end < DateTimeToUnix(Now(), false) then
      begin
        Result := 'Тур закончился уже как ' + ((DateTimeToUnix(Now(), false) - RunProjects[PrjInd].time_end) div 60).ToString + ' минут ' +
          ((DateTimeToUnix(Now(), false) - RunProjects[PrjInd].time_end) mod 60).ToString + ' секунд';
        exit;
      end;

      for i := 0 to High(Players[userindex].programs) do
        if ((Players[userindex].programs[i].uniID = RunProjects[PrjInd].uniID)) then
          if ((Players[userindex].programs[i].res = 'OK')) then
            if ((Players[userindex].programs[i].task = j)) then
            begin
              Result := 'Эта задача уже решена';
              exit;
            end;
      Players[userindex].LastProg := prog;
      // Players[userindex].Progs := Players[userindex].Progs +
      // ProgremNum.ToString + ';';
      SetLength(Players[userindex].programs, length(Players[userindex].programs) + 1);
      Players[userindex].programs[High(Players[userindex].programs)] := TProgram.Create;

      Players[userindex].programs[High(Players[userindex].programs)].programm := TIdURI.URLDecode(StringReplace(prog, '+', ' ', [rfReplaceAll, rfIgnoreCase]));
      Players[userindex].programs[High(Players[userindex].programs)].task := -1;
      for i := 0 to High(Projects[RunProjects[PrjInd].parentInd].tasks) do
        if Projects[RunProjects[PrjInd].parentInd].tasks[i] = TIdURI.URLDecode(StringReplace(s.Split([';'])[2], '+', ' ', [rfReplaceAll, rfIgnoreCase])) then
          Players[userindex].programs[High(Players[userindex].programs)].task := i;
      if Players[userindex].programs[High(Players[userindex].programs)].task = -1 then
      begin
        Result := 'Данной задачи не найдено2';
        SetLength(Players[userindex].programs, length(Players[userindex].programs) - 1);
        exit;
      end;
      Players[userindex].programs[High(Players[userindex].programs)].res := 'Queue';
      Players[userindex].programs[High(Players[userindex].programs)].date := DateTimeToUnix(Now(), false);
      Players[userindex].programs[High(Players[userindex].programs)].uniID := RunProjects[PrjInd].uniID;
      // add to 1 stek
      // lol;
      Result := 'Программа отправлена';
    end
    else
      Result := 'Эта программа уже была отправлена';
  end;
  { else if s.Split([';'])[1] = 'res' then
    begin
    if Players[userindex].isAdmin then
    begin
    if not TryStrToInt(s.Split([';'])[2], i) then
    begin
    Result := 'Except';
    exit;
    end;
    if not TryStrToInt(s.Split([';'])[2], j) then
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
    Players[i].programs[j].exit_data := TIdURI.URLDecode(StringReplace(prog, '+', ' ', [rfReplaceAll, rfIgnoreCase]));
    end
    else
    begin
    Players[i].programs[j].res := 'OK';
    DorOpen(Players[i], PrjInd, Projects[RunProjects[PrjInd].parentInd].tasks[Players[i].programs[j].task]);
    end;
    Result := 'OK';

    end;
    end; }
end;

function LoadServFile(user, s: string; PrjInd: longint): String;
var
  i, j, k, f: longint;
  s2: string;
  userindex: longint;
begin
  userindex := GetIndex(user);
  Result := '___NoT_FoUnD_CoMmAnD__' + s + '___NoT_FoUnD_CoMmAnD__';
  if (s = 'login') then
  begin
    if not(Players[userindex].isAdmin) then
      Result := 'OK'
    else
      Result := 'OKADMIN';
  end
  else if (s = 'map') and (PrjInd >= 0) then
  begin
    // Result := LoadFileToStr(ExtractFilePath(ParamStr(0)) + LoadDirectory + '\save\map.txt')
    Result := '{' + #13#10 + '  "rooms": [' + #13#10;
    for i := 0 to High(Projects[RunProjects[PrjInd].parentInd].map.ROOMs) do
    begin
      Result := Result + '    {' + #13#10;
      Result := Result + '      "position": [' + Projects[RunProjects[PrjInd].parentInd].map.ROOMs[i][0].ToString + ',' + Projects[RunProjects[PrjInd].parentInd].map.ROOMs[i][1].ToString + ',' +
        Projects[RunProjects[PrjInd].parentInd].map.ROOMs[i][2].ToString + ',' + Projects[RunProjects[PrjInd].parentInd].map.ROOMs[i][3].ToString + ']' + #13#10;

      if i = High(Projects[RunProjects[PrjInd].parentInd].map.ROOMs) then
        Result := Result + '    }' + #13#10
      else
        Result := Result + '    },' + #13#10;
    end;
    // ===================================
    Result := Result + '  ],' + #13#10;
    Result := Result + '  "road vertical": [' + #13#10;
    for i := 0 to High(Projects[RunProjects[PrjInd].parentInd].map.RVs) do
    begin
      Result := Result + '    {' + #13#10;
      Result := Result + '      "position": [' + Projects[RunProjects[PrjInd].parentInd].map.RVs[i].pos[0].ToString + ',' + Projects[RunProjects[PrjInd].parentInd].map.RVs[i].pos[1].ToString + ',' +
        Projects[RunProjects[PrjInd].parentInd].map.RVs[i].pos[2].ToString + '],' + #13#10;
      if ((Projects[RunProjects[PrjInd].parentInd].map.RVs[i].task = '') or (Projects[RunProjects[PrjInd].parentInd].map.RVs[i].task = 'open')) then
        Result := Result + '      "dor": "' + Projects[RunProjects[PrjInd].parentInd].map.RVs[i].task + '"' + #13#10
      else if DorIsOpen(Players[userindex], PrjInd, Projects[RunProjects[PrjInd].parentInd].map.RVs[i].task) then
        Result := Result + '      "dor": "open"' + #13#10
      else
        Result := Result + '      "dor": "file:' + Projects[RunProjects[PrjInd].parentInd].map.RVs[i].task + '"' + #13#10;

      if i = High(Projects[RunProjects[PrjInd].parentInd].map.RVs) then
        Result := Result + '    }' + #13#10
      else
        Result := Result + '    },' + #13#10;
    end;
    Result := Result + '  ],' + #13#10;
    // ===================================
    Result := Result + '  "road horizontal": [' + #13#10;
    for i := 0 to High(Projects[RunProjects[PrjInd].parentInd].map.RHs) do
    begin
      Result := Result + '    {' + #13#10;
      Result := Result + '      "position": [' + Projects[RunProjects[PrjInd].parentInd].map.RHs[i].pos[0].ToString + ',' + Projects[RunProjects[PrjInd].parentInd].map.RHs[i].pos[1].ToString + ',' +
        Projects[RunProjects[PrjInd].parentInd].map.RHs[i].pos[2].ToString + '],' + #13#10;
      if ((Projects[RunProjects[PrjInd].parentInd].map.RHs[i].task = '') or (Projects[RunProjects[PrjInd].parentInd].map.RHs[i].task = 'open')) then
        Result := Result + '      "dor": "' + Projects[RunProjects[PrjInd].parentInd].map.RHs[i].task + '"' + #13#10
      else if DorIsOpen(Players[userindex], PrjInd, Projects[RunProjects[PrjInd].parentInd].map.RHs[i].task) then
        Result := Result + '      "dor": "open"' + #13#10
      else
        Result := Result + '      "dor": "file:' + Projects[RunProjects[PrjInd].parentInd].map.RHs[i].task + '"' + #13#10;

      if i = High(Projects[RunProjects[PrjInd].parentInd].map.RHs) then
        Result := Result + '    }' + #13#10
      else
        Result := Result + '    },' + #13#10;
    end;
    Result := Result + '  ],' + #13#10;
    // ===================================
    Result := Result + '  "dollar": [' + #13#10;
    for i := 0 to High(Projects[RunProjects[PrjInd].parentInd].map.Ds) do
    begin
      Result := Result + '    {' + #13#10;

      f := 0;
      for j := 0 to High(Players) do
        for k := 0 to High(Players[j].dollars) do
          if (RunProjects[PrjInd].uniID = Players[j].dollars[k].uniID) and (Players[j].dollars[k].pos = i) then
          begin
            f := 1;
          end;
      if f = 0 then
      begin
        Result := Result + '      "position": [' + Projects[RunProjects[PrjInd].parentInd].map.Ds[i][0].ToString + ',' + Projects[RunProjects[PrjInd].parentInd].map.Ds[i][1].ToString + ']' + #13#10;
      end;
      if i = High(Projects[RunProjects[PrjInd].parentInd].map.Ds) then
        Result := Result + '    }' + #13#10
      else
        Result := Result + '    },' + #13#10;
    end;
    Result := Result + '  ]' + #13#10;
    // ===================================
    Result := Result + '}';
  end
  else if (s = 'move_down') and (PrjInd >= 0) then
  begin
    for j := 0 to High(Players[userindex].pos) do
      if Players[userindex].pos[j].uniID = RunProjects[PrjInd].uniID then
      begin
        Result := 'OK';
        GetDollar(Players[userindex].pos[j].posx, Players[userindex].pos[j].posy + 1, user, PrjInd);
        OpenAccess(Players[userindex].pos[j].posx + 1, Players[userindex].pos[j].posy + 1, user, PrjInd);
        OpenAccess(Players[userindex].pos[j].posx - 1, Players[userindex].pos[j].posy + 1, user, PrjInd);
        OpenAccess(Players[userindex].pos[j].posx, Players[userindex].pos[j].posy + 1 + 1, user, PrjInd);
        OpenAccess(Players[userindex].pos[j].posx, Players[userindex].pos[j].posy + 1 - 1, user, PrjInd);
        OpenAccess(Players[userindex].pos[j].posx, Players[userindex].pos[j].posy + 1, user, PrjInd);
        if InHouse(Players[userindex].pos[j].posx, Players[userindex].pos[j].posy + 1, user, PrjInd) then
          inc(Players[userindex].pos[j].posy)
        else
          Result := 'STOP';
      end;

  end
  else if (s = 'move_left') and (PrjInd >= 0) then
  begin
    for j := 0 to High(Players[userindex].pos) do
      if Players[userindex].pos[j].uniID = RunProjects[PrjInd].uniID then
      begin
        Result := 'OK';
        GetDollar(Players[userindex].pos[j].posx - 1, Players[userindex].pos[j].posy, user, PrjInd);
        OpenAccess(Players[userindex].pos[j].posx - 1 + 1, Players[userindex].pos[j].posy, user, PrjInd);
        OpenAccess(Players[userindex].pos[j].posx - 1 - 1, Players[userindex].pos[j].posy, user, PrjInd);
        OpenAccess(Players[userindex].pos[j].posx - 1, Players[userindex].pos[j].posy + 1, user, PrjInd);
        OpenAccess(Players[userindex].pos[j].posx - 1, Players[userindex].pos[j].posy - 1, user, PrjInd);
        OpenAccess(Players[userindex].pos[j].posx - 1, Players[userindex].pos[j].posy, user, PrjInd);
        if InHouse(Players[userindex].pos[j].posx - 1, Players[userindex].pos[j].posy, user, PrjInd) then
          inc(Players[userindex].pos[j].posx, -1)
        else
          Result := 'STOP';
      end;
  end
  else if (s = 'move_rigth') and (PrjInd >= 0) then
  begin
    for j := 0 to High(Players[userindex].pos) do
      if Players[userindex].pos[j].uniID = RunProjects[PrjInd].uniID then
      begin
        Result := 'OK';
        GetDollar(Players[userindex].pos[j].posx + 1, Players[userindex].pos[j].posy, user, PrjInd);
        OpenAccess(Players[userindex].pos[j].posx + 1 + 1, Players[userindex].pos[j].posy, user, PrjInd);
        OpenAccess(Players[userindex].pos[j].posx + 1 - 1, Players[userindex].pos[j].posy, user, PrjInd);
        OpenAccess(Players[userindex].pos[j].posx + 1, Players[userindex].pos[j].posy + 1, user, PrjInd);
        OpenAccess(Players[userindex].pos[j].posx + 1, Players[userindex].pos[j].posy - 1, user, PrjInd);
        OpenAccess(Players[userindex].pos[j].posx + 1, Players[userindex].pos[j].posy, user, PrjInd);
        if InHouse(Players[userindex].pos[j].posx + 1, Players[userindex].pos[j].posy, user, PrjInd) then
          inc(Players[userindex].pos[j].posx)
        else
          Result := 'STOP';
      end;
  end
  else if (s = 'move_up') and (PrjInd >= 0) then
  begin
    for j := 0 to High(Players[userindex].pos) do
      if Players[userindex].pos[j].uniID = RunProjects[PrjInd].uniID then
      begin
        Result := 'OK';
        GetDollar(Players[userindex].pos[j].posx, Players[userindex].pos[j].posy - 1, user, PrjInd);
        OpenAccess(Players[userindex].pos[j].posx + 1, Players[userindex].pos[j].posy - 1, user, PrjInd);
        OpenAccess(Players[userindex].pos[j].posx - 1, Players[userindex].pos[j].posy - 1, user, PrjInd);
        OpenAccess(Players[userindex].pos[j].posx, Players[userindex].pos[j].posy - 1 + 1, user, PrjInd);
        OpenAccess(Players[userindex].pos[j].posx, Players[userindex].pos[j].posy - 1 - 1, user, PrjInd);
        OpenAccess(Players[userindex].pos[j].posx, Players[userindex].pos[j].posy - 1, user, PrjInd);
        if InHouse(Players[userindex].pos[j].posx, Players[userindex].pos[j].posy - 1, user, PrjInd) then
          inc(Players[userindex].pos[j].posy, -1)
        else
          Result := 'STOP';
      end;
  end
  else if (s = 'get_is_access') and (PrjInd >= 0) then
  begin
    Result := '[';
    for i := 0 to High(Players[userindex].IsAccess) do
      if Players[userindex].IsAccess[i].uniID = RunProjects[PrjInd].uniID then
        if (Players[userindex].IsAccess[i].pos mod 2 = 0) then
        begin
          if (Players[userindex].IsAccess[i].uniID = Players[userindex].IsAccess[i].uniID) then
          begin
            Result := Result + '"' + Projects[RunProjects[PrjInd].parentInd].map.RVs[Players[userindex].IsAccess[i].pos div 2].task + '",';
          end;
        end
        else
        begin
          if (Players[userindex].IsAccess[i].uniID = RunProjects[PrjInd].uniID) then
          begin
            Result := Result + '"' + Projects[RunProjects[PrjInd].parentInd].map.RHs[Players[userindex].IsAccess[i].pos div 2].task + '",';
          end;
        end;
    // Result := Result + '"'+Projects[RunProjects[PrjInd].parentInd].map.ReadString('RV:' + (Players[i].IsAccess[j].pos div 2).ToString, 'dor', '') + ''';';
    // Result := Result + '"' + Projects[RunProjects[PrjInd].parentInd].tasks[i] + '":' + Players[userindex].IsAccess[RunProjects[PrjInd].parentInd][i].ToInteger.ToString + ',';
    if Result[length(Result)] = ',' then
      Delete(Result, length(Result), 1);
    Result := Result + ']';
  end
  else if (s = 'get_prog_list') and (Players[userindex].isAdmin) then
  begin
    Result := '[';
    for i := 0 to High(Projects) do
    begin
      Result := Result + '{';
      Result := Result + '"folder":"' + MyTXT2INI(StringReplace(Projects[i].folder, '\', '/', [rfReplaceAll])) + '",';
      Result := Result + '"name":"' + MyTXT2INI(Projects[i].name) + '",';
      Result := Result + '"tasks_info":[';
      for j := 0 to High(Projects[i].tasks_info) do
      begin
        Result := Result + '{';
        Result := Result + '"DefaultProgram":"' + MyTXT2INI(Projects[i].tasks_info[j].DefaultProgram) + '",';
        Result := Result + '"folder":"' + MyTXT2INI(Projects[i].tasks_info[j].folder) + '",';
        Result := Result + '"solution":"' + MyTXT2INI(Projects[i].tasks_info[j].solution) + '",';
        Result := Result + '"name":"' + MyTXT2INI(Projects[i].tasks_info[j].name) + '",';
        Result := Result + '"tests":[';
        for k := 0 to High(Projects[i].tasks_info[j].test) do
        begin
          if FileExists(LoadDirectory + '\' + Projects[i].folder + StringReplace(Projects[i].tasks_info[j].test[k], '\/', '\', [rfReplaceAll])) then
            Result := Result + '"' + MyTXT2INI(LoadFileToStr(LoadDirectory + '\' + Projects[i].folder + StringReplace(Projects[i].tasks_info[j].test[k], '\/', '\', [rfReplaceAll]))) + '",';
        end;

        if Result[length(Result)] = ',' then
          Delete(Result, length(Result), 1);
        Result := Result + ']},';
      end;
      if Result[length(Result)] = ',' then
        Delete(Result, length(Result), 1);
      Result := Result + ']},';
    end;
    // Result := Result + '"'+Projects[RunProjects[PrjInd].parentInd].map.ReadString('RV:' + (Players[i].IsAccess[j].pos div 2).ToString, 'dor', '') + ''';';
    // Result := Result + '"' + Projects[RunProjects[PrjInd].parentInd].tasks[i] + '":' + Players[userindex].IsAccess[RunProjects[PrjInd].parentInd][i].ToInteger.ToString + ',';
    if Result[length(Result)] = ',' then
      Delete(Result, length(Result), 1);
    Result := Result + ']';
  end
  else if (s = 'get_programs') and (Players[userindex].isAdmin) then
  begin
    Result := '{"time":"' + IntToStr(DateTimeToUnix(Now(), false)) + '","programs":[';
    for i := 0 to High(Players) do
      for j := 0 to High(Players[i].programs) do
      begin
        Result := Result + '{';
        Result := Result + '"Login":"' + MyTXT2INI(Players[i].login) + '",';
        Result := Result + '"Name":"' + MyTXT2INI(Players[i].name + Iif(Players[i].ip <> '', ' [' + Players[i].ip + ']')) + '",';
        Result := Result + '"programm":"' + MyTXT2INI(Players[i].programs[j].programm) + '",';
        Result := Result + '"exit_data":"' + MyTXT2INI(Players[i].programs[j].exit_data) + '",';
        Result := Result + '"res":"' + Players[i].programs[j].res + '",';
        Result := Result + '"task":"' + Players[i].programs[j].task.ToString + '",';
        Result := Result + '"date":"' + Players[i].programs[j].date.ToString + '",';
        for k := 0 to High(RunProjects) do
          if RunProjects[k].uniID = Players[i].programs[j].uniID then
            if (Players[i].programs[j].task >= 0) and (Players[i].programs[j].task <= High(Projects[RunProjects[k].parentInd].tasks_info)) then
            begin
              Result := Result + '"task_name":"' + MyTXT2INI(Projects[RunProjects[k].parentInd].tasks[Players[i].programs[j].task]) + '",';
              Result := Result + '"proj_name":"' + MyTXT2INI(Projects[RunProjects[k].parentInd].name) + '",';
              break;
            end;

        Result := Result + '"uniID":"' + Players[i].programs[j].uniID + '"';
        Result := Result + '},';
      end;
    // Result := Result + '"'+Projects[RunProjects[PrjInd].parentInd].map.ReadString('RV:' + (Players[i].IsAccess[j].pos div 2).ToString, 'dor', '') + ''';';
    // Result := Result + '"' + Projects[RunProjects[PrjInd].parentInd].tasks[i] + '":' + Players[userindex].IsAccess[RunProjects[PrjInd].parentInd][i].ToInteger.ToString + ',';
    if Result[length(Result)] = ',' then
      Delete(Result, length(Result), 1);
    Result := Result + ']}';
  end
  else if (s = 'get_dors') and (PrjInd >= 0) then
  begin
    Result := '{';
    for i := 0 to High(Projects[RunProjects[PrjInd].parentInd].map.RVs) do
      if (Projects[RunProjects[PrjInd].parentInd].map.RVs[i].task <> '') and (Projects[RunProjects[PrjInd].parentInd].map.RVs[i].task <> 'open') then
      begin
        Result := Result + '"' + Projects[RunProjects[PrjInd].parentInd].map.RVs[i].pos[0].ToString + ';' +
          ((Projects[RunProjects[PrjInd].parentInd].map.RVs[i].pos[1] + Projects[RunProjects[PrjInd].parentInd].map.RVs[i].pos[2]) div 2).ToString + '":"' + Projects[RunProjects[PrjInd].parentInd]
          .map.RVs[i].task + '",';
      end;
    for i := 0 to High(Projects[RunProjects[PrjInd].parentInd].map.RHs) do
      if (Projects[RunProjects[PrjInd].parentInd].map.RHs[i].task <> '') and (Projects[RunProjects[PrjInd].parentInd].map.RHs[i].task <> 'open') then
      begin
        Result := Result + '"' + ((Projects[RunProjects[PrjInd].parentInd].map.RHs[i].pos[1] + Projects[RunProjects[PrjInd].parentInd].map.RHs[i].pos[2]) div 2).ToString + ';' +
          Projects[RunProjects[PrjInd].parentInd].map.RHs[i].pos[0].ToString + '":"' + Projects[RunProjects[PrjInd].parentInd].map.RHs[i].task + '",';
      end;
    // Result := Result + '"'+Projects[RunProjects[PrjInd].parentInd].map.ReadString('RV:' + (Players[i].IsAccess[j].pos div 2).ToString, 'dor', '') + ''';';
    // Result := Result + '"' + Projects[RunProjects[PrjInd].parentInd].tasks[i] + '":' + Players[userindex].IsAccess[RunProjects[PrjInd].parentInd][i].ToInteger.ToString + ',';
    if Result[length(Result)] = ',' then
      Delete(Result, length(Result), 1);
    Result := Result + '}';
  end
  else if (s = 'gettab') and (PrjInd >= 0) then
  begin
    Result := '[' + #13#10;
    if (Players[userindex].isAdmin) then
      for i := 0 to High(Projects[RunProjects[PrjInd].parentInd].tasks_info) do
      begin
        Result := Result + '	{' + #13#10;
        Result := Result + '		"DefaultProgram": "' + str2json(Projects[RunProjects[PrjInd].parentInd].tasks_info[i].DefaultProgram) + '",' + #13#10;
        Result := Result + '		"name": "' + Projects[RunProjects[PrjInd].parentInd].tasks_info[i].name + '",' + #13#10;
        Result := Result + '		"tab": [';
        for j := 0 to High(Projects[RunProjects[PrjInd].parentInd].tasks_info[i].tab) do
        begin
          Result := Result + '{';
          Result := Result + '				"name": "' + Projects[RunProjects[PrjInd].parentInd].tasks_info[i].tab[j]._name + '",' + #13#10;
          if Projects[RunProjects[PrjInd].parentInd].tasks_info[i].tab[j]._type = 'text' then
            Result := Result + '				"text": "' + str2json(Projects[RunProjects[PrjInd].parentInd].tasks_info[i].tab[j]._text) + '",' + #13#10
          else if Projects[RunProjects[PrjInd].parentInd].tasks_info[i].tab[j]._type = 'fil' then
            Result := Result + '				"url": "' + Projects[RunProjects[PrjInd].parentInd].tasks_info[i].tab[j]._text + '",' + #13#10
          else if Projects[RunProjects[PrjInd].parentInd].tasks_info[i].tab[j]._type = 'site' then
            Result := Result + '				"url": "' + Projects[RunProjects[PrjInd].parentInd].tasks_info[i].tab[j]._text + '",' + #13#10
          else if Projects[RunProjects[PrjInd].parentInd].tasks_info[i].tab[j]._type = 'load' then
          else
            writeln('er9234');
          Result := Result + '				"type": "' + Projects[RunProjects[PrjInd].parentInd].tasks_info[i].tab[j]._type + '"' + #13#10;
          Result := Result + '			},';
        end;
        if Result[length(Result)] = ',' then
          Delete(Result, length(Result), 1);
        Result := Result + '],' + #13#10;
        Result := Result + '		"tests": [';
        for j := 0 to High(Projects[RunProjects[PrjInd].parentInd].tasks_info[i].test) do
          Result := Result + '"' + Projects[RunProjects[PrjInd].parentInd].tasks_info[i].test[j] + '",';
        if Result[length(Result)] = ',' then
          Delete(Result, length(Result), 1);
        Result := Result + ']' + #13#10;
        Result := Result + '	},';

      end;
    if (not Players[userindex].isAdmin) then
      for k := 0 to High(Players[userindex].IsAccess) do
        if (Players[userindex].IsAccess[k].uniID = RunProjects[PrjInd].uniID) then
        begin
          if (Players[userindex].IsAccess[k].pos mod 2 = 0) then
          begin
            s2 := Projects[RunProjects[PrjInd].parentInd].map.RVs[Players[userindex].IsAccess[k].pos div 2].task;
          end
          else
          begin
            s2 := Projects[RunProjects[PrjInd].parentInd].map.RHs[Players[userindex].IsAccess[k].pos div 2].task;
          end;
          for i := 0 to High(Projects[RunProjects[PrjInd].parentInd].tasks_info) do
            if Projects[RunProjects[PrjInd].parentInd].tasks_info[i].name = s2 then
            begin
              Result := Result + '	{' + #13#10;
              Result := Result + '		"DefaultProgram": "' + str2json(Projects[RunProjects[PrjInd].parentInd].tasks_info[i].DefaultProgram) + '",' + #13#10;
              Result := Result + '		"name": "' + Projects[RunProjects[PrjInd].parentInd].tasks_info[i].name + '",' + #13#10;
              Result := Result + '		"tab": [';
              for j := 0 to High(Projects[RunProjects[PrjInd].parentInd].tasks_info[i].tab) do
              begin
                Result := Result + '{';
                Result := Result + '				"name": "' + Projects[RunProjects[PrjInd].parentInd].tasks_info[i].tab[j]._name + '",' + #13#10;
                if Projects[RunProjects[PrjInd].parentInd].tasks_info[i].tab[j]._type = 'text' then
                  Result := Result + '				"text": "' + str2json(Projects[RunProjects[PrjInd].parentInd].tasks_info[i].tab[j]._text) + '",' + #13#10
                else if Projects[RunProjects[PrjInd].parentInd].tasks_info[i].tab[j]._type = 'fil' then
                  Result := Result + '				"url": "' + Projects[RunProjects[PrjInd].parentInd].tasks_info[i].tab[j]._text + '",' + #13#10
                else if Projects[RunProjects[PrjInd].parentInd].tasks_info[i].tab[j]._type = 'site' then
                  Result := Result + '				"url": "' + Projects[RunProjects[PrjInd].parentInd].tasks_info[i].tab[j]._text + '",' + #13#10
                else if Projects[RunProjects[PrjInd].parentInd].tasks_info[i].tab[j]._type = 'load' then
                else
                  writeln('er9235');
                Result := Result + '				"type": "' + Projects[RunProjects[PrjInd].parentInd].tasks_info[i].tab[j]._type + '"' + #13#10;
                Result := Result + '			},';
              end;
              if Result[length(Result)] = ',' then
                Delete(Result, length(Result), 1);
              Result := Result + ']' + #13#10; // ,
              // Result := Result + '		"tests": [';
              // for j := 0 to High(Projects[RunProjects[PrjInd].parentInd].tasks_info[i].test) do
              // Result := Result + '"' + Projects[RunProjects[PrjInd].parentInd].tasks_info[i].test[j] + '",';
              // if Result[length(Result)] = ',' then
              // Delete(Result, length(Result), 1);
              // Result := Result + ']' + #13#10;
              Result := Result + '	},';
              break;
            end;
        end;

    if Result[length(Result)] = ',' then
      Delete(Result, length(Result), 1);
    Result := Result + ']';
  end
  else if (s = 'getpos') and (PrjInd >= 0) then
  begin
    Result := '{' + #13#10 + '  "count": ' + length(Players).ToString + ',' + #13#10;
    for i := Low(Players) to High(Players) - 1 do
    begin
      Result := Result + '  "Player:' + i.ToString + '": [' + #13#10;
      Result := Result + '    {' + #13#10;
      Result := Result + '      "Name": "' + Players[i].login + '",' + #13#10;
      f := 0;
      for j := 0 to High(Players[i].pos) do
        if Players[i].pos[j].uniID = RunProjects[PrjInd].uniID then
        begin
          Result := Result + '      "posx": ' + Players[i].pos[j].posx.ToString + ',' + #13#10;
          Result := Result + '      "posy": ' + Players[i].pos[j].posy.ToString + ',' + #13#10;
          f := 1;
          break;
        end;
      if (f = 0) and (userindex = i) then
      begin

        if RunProjects[PrjInd].time_start > DateTimeToUnix(Now(), false) then
          f := 0
        else if RunProjects[PrjInd].group = '' then
          f := 1
        else if Players[i].isAdmin then
          f := 1
        else
        begin
          k := 0;
          for j := 0 to High(RunProjects[PrjInd].group.Split([','])) do
            if trim(Players[i].group) = trim(RunProjects[PrjInd].group.Split([','])[j]) then
            begin
              k := 1;
              break;
            end;
          if k = 0 then
            f := 0
          else
            f := 1
        end;
        if f = 1 then
        begin
          SetLength(Players[i].pos, length(Players[i].pos) + 1);
          Players[i].pos[High(Players[i].pos)] := Aarraofstrintint.Create();
          Players[i].pos[High(Players[i].pos)].uniID := RunProjects[PrjInd].uniID;
          Players[i].pos[High(Players[i].pos)].posx := 0;
          Players[i].pos[High(Players[i].pos)].posy := 0;
          Result := Result + '      "posx": 0,' + #13#10;
          Result := Result + '      "posy": 0,' + #13#10;
          f := 1;
        end;
      end;
      Result := Result + '      "personage1": ' + Players[i].Pers[0].ToString + ',' + #13#10;
      Result := Result + '      "personage2": ' + Players[i].Pers[1].ToString + ',' + #13#10;
      Result := Result + '      "personage3": ' + Players[i].Pers[2].ToString + ',' + #13#10;
      Result := Result + '      "personage4": ' + Players[i].Pers[3].ToString + ',' + #13#10;
      Result := Result + '      "personage5": ' + Players[i].Pers[4].ToString + ',' + #13#10;
      Result := Result + '      "personage6": ' + Players[i].Pers[5].ToString + ',' + #13#10;
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
    Result := Result + '      "Name": "' + Players[i].login + '",' + #13#10;
    f := 0;
    for j := 0 to High(Players[i].pos) do
      if Players[i].pos[j].uniID = RunProjects[PrjInd].uniID then
      begin
        Result := Result + '      "posx": ' + Players[i].pos[j].posx.ToString + ',' + #13#10;
        Result := Result + '      "posy": ' + Players[i].pos[j].posy.ToString + ',' + #13#10;
        f := 1;
        break;
      end;
    if (f = 0) and (userindex = i) then
    begin

      if RunProjects[PrjInd].time_start > DateTimeToUnix(Now(), false) then
        f := 0
      else if RunProjects[PrjInd].group = '' then
        f := 1
      else if Players[i].isAdmin then
        f := 1
      else
      begin
        k := 0;
        for j := 0 to High(RunProjects[PrjInd].group.Split([','])) do
          if trim(Players[i].group) = trim(RunProjects[PrjInd].group.Split([','])[j]) then
          begin
            k := 1;
            break;
          end;
        if k = 0 then
          f := 0
        else
          f := 1
      end;
      if f = 1 then
      begin
        SetLength(Players[i].pos, length(Players[i].pos) + 1);
        Players[i].pos[High(Players[i].pos)] := Aarraofstrintint.Create();
        Players[i].pos[High(Players[i].pos)].uniID := RunProjects[PrjInd].uniID;
        Players[i].pos[High(Players[i].pos)].posx := 0;
        Players[i].pos[High(Players[i].pos)].posy := 0;
        Result := Result + '      "posx": 0,' + #13#10;
        Result := Result + '      "posy": 0,' + #13#10;
        f := 1;
      end;
    end;
    Result := Result + '      "personage1": ' + Players[i].Pers[0].ToString + ',' + #13#10;
    Result := Result + '      "personage2": ' + Players[i].Pers[1].ToString + ',' + #13#10;
    Result := Result + '      "personage3": ' + Players[i].Pers[2].ToString + ',' + #13#10;
    Result := Result + '      "personage4": ' + Players[i].Pers[3].ToString + ',' + #13#10;
    Result := Result + '      "personage5": ' + Players[i].Pers[4].ToString + ',' + #13#10;
    Result := Result + '      "personage6": ' + Players[i].Pers[5].ToString + ',' + #13#10;
    if Players[i].isAdmin then
      Result := Result + '      "isAdmin": "true"' + #13#10
    else
      Result := Result + '      "isAdmin": "false"' + #13#10;
    Result := Result + '    }' + #13#10;
    Result := Result + '  ]' + #13#10;
    Result := Result + '}';
  end
  else if (length(s.Split(['EditPersonage'])) > 1) and (length(s.Split(['EditPersonage'])[1].Split(['_'])) > 5) then
  begin
    Players[userindex].Pers[0] := s.Split(['EditPersonage'])[1].Split(['_'])[0].ToInteger;
    Players[userindex].Pers[1] := s.Split(['EditPersonage'])[1].Split(['_'])[1].ToInteger;
    Players[userindex].Pers[2] := s.Split(['EditPersonage'])[1].Split(['_'])[2].ToInteger;
    Players[userindex].Pers[3] := s.Split(['EditPersonage'])[1].Split(['_'])[3].ToInteger;
    Players[userindex].Pers[4] := s.Split(['EditPersonage'])[1].Split(['_'])[4].ToInteger;
    Players[userindex].Pers[5] := s.Split(['EditPersonage'])[1].Split(['_'])[5].ToInteger;
    Result := 'OK';
  end
  else if (s = '_server_list_') then
  begin
    Result := 'name;access;start_time;plus_end;server_uniID;' + #13#10;
    for i := 0 to High(RunProjects) do
    begin
      if RunProjects[i].time_start > DateTimeToUnix(Now(), false) then
        Result := Result + RunProjects[i].visib_name + ';NOOK;' + IntToStr(DateTimeToUnix(Now(), false) - RunProjects[i].time_start) + ';' + (RunProjects[i].time_end - RunProjects[i].time_start)
          .ToString + ';' + RunProjects[i].uniID + ';' + #13#10
      else if RunProjects[i].group = '' then
        Result := Result + RunProjects[i].visib_name + ';OK;' + IntToStr(DateTimeToUnix(Now(), false) - RunProjects[i].time_start) + ';' + (RunProjects[i].time_end - RunProjects[i].time_start)
          .ToString + ';' + RunProjects[i].uniID + ';' + #13#10
      else if Players[userindex].isAdmin then
        Result := Result + RunProjects[i].visib_name + ';OK;' + IntToStr(DateTimeToUnix(Now(), false) - RunProjects[i].time_start) + ';' + (RunProjects[i].time_end - RunProjects[i].time_start)
          .ToString + ';' + RunProjects[i].uniID + ';' + #13#10
      else
      begin
        k := 0;
        for j := 0 to High(RunProjects[i].group.Split([','])) do
          if trim(Players[userindex].group) = trim(RunProjects[i].group.Split([','])[j]) then
          begin
            k := 1;
            break;
          end;
        if k = 0 then
          Result := Result + RunProjects[i].visib_name + ';NOOK;' + IntToStr(DateTimeToUnix(Now(), false) - RunProjects[i].time_start) + ';' + (RunProjects[i].time_end - RunProjects[i].time_start)
            .ToString + ';' + RunProjects[i].uniID + ';' + #13#10
        else
          Result := Result + RunProjects[i].visib_name + ';OK;' + IntToStr(DateTimeToUnix(Now(), false) - RunProjects[i].time_start) + ';' + (RunProjects[i].time_end - RunProjects[i].time_start)
            .ToString + ';' + RunProjects[i].uniID + ';' + #13#10
      end;
    end;
  end
  else if (s = 'get_time') and (PrjInd >= 0) then
  begin
    if (Now() < unixtodatetime(RunProjects[PrjInd].time_end, false)) then
      Result := 'time: ' + DateTimeToUnix(Now(), false).ToString + #13#10 + 'delta: ' + MilliSecondsBetween(Now(), unixtodatetime(RunProjects[PrjInd].time_end, false)).ToString
    else
      Result := 'time: ' + DateTimeToUnix(Now(), false).ToString + #13#10 + 'delta: ' + (-MilliSecondsBetween(Now(), unixtodatetime(RunProjects[PrjInd].time_end, false))).ToString
  end
  else if (s = 'get_table') and (PrjInd >= 0) then
  begin
    // string_freeze:string;
    // time_freeze:int64;
    if Players[userindex].isAdmin then
      if RunProjects[PrjInd].time_freeze < DateTimeToUnix(Now(), false) then
      begin
        if RunProjects[PrjInd].string_freeze = '' then
          RunProjects[PrjInd].string_freeze := GetSortPlayers(false, PrjInd);
        Result := 'F' + GetSortPlayers(Players[userindex].isAdmin, PrjInd)
      end
      else
      begin
        Result := 'N' + GetSortPlayers(Players[userindex].isAdmin, PrjInd);
        RunProjects[PrjInd].string_freeze := '';
      end;

    if not Players[userindex].isAdmin then
      if RunProjects[PrjInd].time_freeze < DateTimeToUnix(Now(), false) then
      begin
        if RunProjects[PrjInd].string_freeze = '' then
          RunProjects[PrjInd].string_freeze := GetSortPlayers(false, PrjInd);
        Result := 'F' + RunProjects[PrjInd].string_freeze;
      end
      else
      begin
        Result := 'N' + GetSortPlayers(Players[userindex].isAdmin, PrjInd);
        RunProjects[PrjInd].string_freeze := '';
      end;

  end
  else if (length(s.Split(['Get_my_programs'])) > 1) and (PrjInd >= 0) then
  begin
    Result := '[';
    j := 0;
    for i := High(Players[userindex].programs) downto Low(Players[userindex].programs) do
      if Players[userindex].programs[i].uniID = RunProjects[PrjInd].uniID then
        if Projects[RunProjects[PrjInd].parentInd].tasks[Players[userindex].programs[i].task] = TIdURI.URLDecode(StringReplace(s.Split(['Get_my_programs'])[1], '+', ' ', [rfReplaceAll, rfIgnoreCase]))
        then
        begin
          inc(j);
          if j > 50 then
            break;
          Result := Result + '[' + i.ToString() + ',"' + Players[userindex].programs[i].res + '","' + Players[userindex].programs[i].date.ToString + '"]';
          Result := Result + ',';

        end;
    if Result[length(Result)] = ',' then
      Delete(Result, length(Result), 1);
    Result := Result + ']';

  end
  else if (length(s.Split(['Get_my_program'])) > 1) and (PrjInd >= 0) then
  begin
    i := StrToInt(s.Split(['Get_my_program'])[1]);
    Result := 'Error';
    if (i < 0) or (i > High(Players[userindex].programs)) then
      exit;
    Result := 'Номер: ' + i.ToString() + #13#10;
    Result := Result + 'Ответ тестирующей системы: ' + Players[userindex].programs[i].res + #13#10;
    Result := Result + 'Дата отправки: ' + DateToFileName(unixtodatetime(Players[userindex].programs[i].date, false)) + #13#10;
    Result := Result + #13#10;

    Result := Result + Players[userindex].programs[i].programm;
  end
  else if (Players[userindex].isAdmin) then
  begin
    if (s = '_my_server_list_') then
    begin
      Result := 'name;access;start_time;plus_end;server_uniID;' + #13#10;
      for i := 0 to High(RunProjects) do
      begin
        k := 0;
        for j := 0 to High(RunProjects[i].group.Split([','])) do
          if 'gr_' + trim(Players[userindex].login) = trim(RunProjects[i].group.Split([','])[j]) then
          begin
            k := 1;
            break;
          end;
        if '' = trim(RunProjects[i].group) then
        begin
          k := 1;
        end;

        if k = 0 then
          continue;

        if RunProjects[i].time_start > DateTimeToUnix(Now(), false) then
          Result := Result + RunProjects[i].visib_name + ';NOOK;' + RunProjects[i].time_start.ToString + ';' + (RunProjects[i].time_end - RunProjects[i].time_freeze).ToString + ';' +
            (RunProjects[i].time_end - RunProjects[i].time_start).ToString + ';' + RunProjects[i].uniID + ';' + #13#10
        else if RunProjects[i].time_end < DateTimeToUnix(Now(), false) then
          Result := Result + RunProjects[i].visib_name + ';NOOK;' + RunProjects[i].time_start.ToString + ';' + (RunProjects[i].time_end - RunProjects[i].time_freeze).ToString + ';' +
            (RunProjects[i].time_end - RunProjects[i].time_start).ToString + ';' + RunProjects[i].uniID + ';' + #13#10
        else if RunProjects[i].group = '' then
          Result := Result + RunProjects[i].visib_name + ';ALL;' + RunProjects[i].time_start.ToString + ';' + (RunProjects[i].time_end - RunProjects[i].time_freeze).ToString + ';' +
            (RunProjects[i].time_end - RunProjects[i].time_start).ToString + ';' + RunProjects[i].uniID + ';' + #13#10
        else
        begin
          k := 0;
          for j := 0 to High(RunProjects[i].group.Split([','])) do
            if '' = trim(RunProjects[i].group.Split([','])[j]) then
            begin
              k := 1;
              break;
            end;
          if k = 1 then
          begin
            Result := Result + RunProjects[i].visib_name + ';ALL;' + RunProjects[i].time_start.ToString + ';' + (RunProjects[i].time_end - RunProjects[i].time_freeze).ToString + ';' +
              (RunProjects[i].time_end - RunProjects[i].time_start).ToString + ';' + RunProjects[i].uniID + ';' + #13#10;
            continue;
          end;
          k := 0;
          for j := 0 to High(RunProjects[i].group.Split([','])) do
            if 'gr_player_' + trim(Players[userindex].login) = trim(RunProjects[i].group.Split([','])[j]) then
            begin
              k := 1;
              break;
            end;
          if k = 0 then
            Result := Result + RunProjects[i].visib_name + ';ONLY_YOU;' + RunProjects[i].time_start.ToString + ';' + (RunProjects[i].time_end - RunProjects[i].time_freeze).ToString + ';' +
              (RunProjects[i].time_end - RunProjects[i].time_start).ToString + ';' + RunProjects[i].uniID + ';' + #13#10
          else
            Result := Result + RunProjects[i].visib_name + ';YOU_AND_YOUR_GRUOP;' + RunProjects[i].time_start.ToString + ';' + (RunProjects[i].time_end - RunProjects[i].time_freeze).ToString + ';' +
              (RunProjects[i].time_end - RunProjects[i].time_start).ToString + ';' + RunProjects[i].uniID + ';' + #13#10;
        end;
      end;
    end
    else if (s = '_proj_list_') then
    begin
      Result := 'folder;name;tasks' + #13#10;
      for i := 0 to High(Projects) do
      begin
        Result := Result + Projects[i].folder + ';_s_p_l_i_t_;' + Projects[i].name + ';_s_p_l_i_t_;';
        for j := 0 to High(Projects[i].tasks) do
          Result := Result + Projects[i].tasks[j] + ';_s_p_l_i_t_;';
        Result := Result + #13#10;
      end;
    end
    else if (length(s.Split(['create_proj_'])) = 2) then
    begin
      // create_proj_(proj parent)_(visib name)_(time_start)_(time_freeze)_(time_end)_(group)_(uniID)_

      if (length(s.Split(['_'])) <> 10) then
        Result := 'Bad request(' + length(s.Split(['_'])).ToString + ')'
      else if s.Split(['_'])[2].ToInteger.ToString <> s.Split(['_'])[2] then // proj parent
        Result := 'Bad request2'
      else if (length(TIdURI.URLDecode(StringReplace(s.Split(['_'])[3], '+', ' ', [rfReplaceAll, rfIgnoreCase]))) < 3) then // visib name
        Result := 'Bad request3'
      else if s.Split(['_'])[4].ToInt64.ToString <> s.Split(['_'])[4] then // time start
        Result := 'Bad request4'
      else if s.Split(['_'])[5].ToInt64.ToString <> s.Split(['_'])[5] then // time freeze
        Result := 'Bad request5'
      else if s.Split(['_'])[6].ToInt64.ToString <> s.Split(['_'])[6] then // time end
        Result := 'Bad request6'
      else if not((s.Split(['_'])[7] = 'All') or (s.Split(['_'])[7] = 'Gr') or (s.Split(['_'])[7] = 'OnlyYou')) then // group
        Result := 'Bad request7'
      else if (length(s.Split(['_'])[8]) <> 10) then
        Result := 'Bad request8'
      else
      begin
        for i := 0 to High(RunProjects) do
          if RunProjects[i].uniID = s.Split(['_'])[8] then
          begin
            Result := 'uniID занят';
            exit;
          end;
        SetLength(RunProjects, length(RunProjects) + 1);
        RunProjects[High(RunProjects)] := TRunProject.Create;
        RunProjects[High(RunProjects)].parentInd := s.Split(['_'])[2].ToInteger;
        RunProjects[High(RunProjects)].uniID := s.Split(['_'])[8];
        RunProjects[High(RunProjects)].visib_name := TIdURI.URLDecode(StringReplace(s.Split(['_'])[3], '+', ' ', [rfReplaceAll, rfIgnoreCase]));
        RunProjects[High(RunProjects)].string_freeze := '';
        RunProjects[High(RunProjects)].time_start := s.Split(['_'])[4].ToInt64 div 1000;
        RunProjects[High(RunProjects)].time_freeze := s.Split(['_'])[5].ToInt64 div 1000;
        RunProjects[High(RunProjects)].time_end := s.Split(['_'])[6].ToInt64 div 1000;
        if (s.Split(['_'])[7] = 'All') then
          RunProjects[High(RunProjects)].group := '';
        if (s.Split(['_'])[7] = 'Gr') then
          RunProjects[High(RunProjects)].group := 'gr_player_' + trim(Players[userindex].login) + ',gr_' + trim(Players[userindex].login);
        if (s.Split(['_'])[7] = 'OnlyYou') then
          RunProjects[High(RunProjects)].group := 'gr_' + trim(Players[userindex].login);
        Result := 'OK';
      end;

    end
    else if (length(s.Split(['del_proj_'])) = 2) then
    begin
      if (length(s.Split(['_'])) <> 4) then
        Result := 'Bad request'
      else if (length(s.Split(['_'])[2]) <> 10) then
        Result := 'Bad request2'
      else
      begin
        Result := 'NOTFOUND';
        for i := 0 to High(RunProjects) do
          if RunProjects[i].uniID = s.Split(['_'])[2] then
          begin
            RunProjects[i].Free;
            RunProjects[i] := RunProjects[High(RunProjects)];
            SetLength(RunProjects, length(RunProjects) - 1);
            Result := 'OK';
            exit;
          end;
      end;
    end
    else if (length(s.Split(['_get_top_proj_'])) = 2) then
    begin
      if (length(s.Split(['_'])) <> 6) then
        Result := 'Bad request'
      else if (length(s.Split(['_'])[4]) <> 10) then
        Result := 'Bad request2'
      else
      begin
        Result := 'NOTFOUND';
        for i := 0 to High(RunProjects) do
          if RunProjects[i].uniID = s.Split(['_'])[4] then
          begin
            Result := GetSortPlayers(true, i);
            exit;
          end;
      end;
    end
    else if (length(s.Split(['_get_stat_players_'])) = 2) then
    begin
      j := 0;
      k := 0;
      for i := 0 to High(Players) do
      begin
        if ((trim(Players[i].group) = '') and (not Players[i].isAdmin)) then
        begin
          inc(j);
        end;
        if trim(Players[i].group) = 'gr_player_' + trim(Players[userindex].login) then
        begin
          inc(k);
        end;
      end;
      Result := k.ToString + #13#10 + j.ToString + #13#10 + length(Players).ToString + #13#10;
    end
    else if (length(s.Split(['_get_players_no_group_'])) = 2) then
    begin
      Result := 'login;name;' + #13#10;
      for i := 0 to High(Players) do
        if ((trim(Players[i].group) = '') and (not Players[i].isAdmin)) then
          Result := Result + Players[i].login + ';' + Players[i].name + Iif(Players[i].ip <> '', ' [' + Players[i].ip + ']') + ';' + #13#10;
    end
    else if (length(s.Split(['_get_players_in_group_'])) = 2) then
    begin
      Result := 'login;name;' + #13#10;
      for i := 0 to High(Players) do
        if trim(Players[i].group) = 'gr_player_' + trim(Players[userindex].login) then
          Result := Result + Players[i].login + ';' + Players[i].name + Iif(Players[i].ip <> '', ' [' + Players[i].ip + ']') + ';' + #13#10;
    end
    else if (length(s.Split(['_player_add_group_'])) = 2) then
    begin
      if (length(s.Split(['_'])) <> 6) then
        Result := 'Login have _'
      else if (GetIndex(s.Split(['_'])[4]) < 0) then
        Result := 'Login not found'
      else
      begin
        i := GetIndex(s.Split(['_'])[4]);
        if ((trim(Players[i].group) = '') and (not Players[i].isAdmin)) then
        begin
          Players[i].group := 'gr_player_' + trim(Players[userindex].login);
          Result := 'OK';
        end
        else
          Result := 'NOOK';
      end;
    end
    else if (length(s.Split(['_player_del_group_'])) = 2) then
    begin
      if (length(s.Split(['_'])) <> 6) then
        Result := 'Bad request'
      else if (GetIndex(s.Split(['_'])[4]) < 0) then
        Result := 'Bad request2'
      else
      begin
        i := GetIndex(s.Split(['_'])[4]);
        if trim(Players[i].group) = 'gr_player_' + trim(Players[userindex].login) then
        begin
          Players[i].group := '';
          Result := 'OK';
        end
        else
          Result := 'NOOK';
      end;
    end
  end;
end;
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


// DorOpen(GetIndex(s.Split(['SendSolution'])[1].Split([';'])[0]),GetIndex(s.Split(['SendSolution'])[1].Split([';'])[1]));

procedure TCommandHandler.CommandGet(AThread: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  img: boolean;
  i, Index: longint;
var
  stream: TStream;
  s, s2: string;
var
  FS: TFileStream;
  Range: TIdEntityRange;
  StartPos, EndPos: int64;
  inerv: T2Date;
begin
  inerv := T2Date.Create;
  inerv._start := Now;
  try
    while isLoadingini do
    begin
      sleep(50);
    end;
    // AResponseInfo.ContentText := 'Server uploading files. Error 503';
    // AResponseInfo.ResponseNo := 503;
    // exit;
    // ========= ban list =========
    for i := 0 to length(blacklisted) - 1 do
      If blacklisted[i] = AThread.Binding.PeerIP Then
      begin
        AThread.Connection.IOHandler.InputBuffer.Clear;
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
    if ips.Values[AThread.Binding.PeerIP] <> '' then
      ips.Values[AThread.Binding.PeerIP] := IntToStr(StrToInt(ips.Values[AThread.Binding.PeerIP]) + 1)
    else
      ips.Values[AThread.Binding.PeerIP] := '1';
    // ========= ip list =========
    if ARequestInfo.ContentLength > 64000000 then
    begin
      AResponseInfo.ContentText := 'Big content-length';
      AResponseInfo.ResponseNo := 400;
      exit;
    end;

    if ARequestInfo.command = 'POST' then
    begin
      stream := ARequestInfo.PostStream;
      if assigned(stream) then
      begin

        stream.Position := 0;
        s := ReadStringFromStream(stream);
        if s.length > 32000 then
        begin
          AResponseInfo.ContentText := 'big data';
          AResponseInfo.ResponseNo := 200;
          exit;
        end;
        // TIdURI.URLDecode(StringReplace(ReadStringFromStream(stream), '+',
        // ' ', [rfReplaceAll, rfIgnoreCase]));
        // if length(ARequestInfo.URI.Split(['upload/'])[1].Split(['kumir/'])) > 1
        // then
        AResponseInfo.ResponseNo := 200;
        {
          if length(s.Split(['errordamp'])) > 1 then
          if DampIp.Values[AThread.Binding.PeerIP] <> '' then
          if StrToInt64(DampIp.Values[AThread.Binding.PeerIP]) + 20 <= DateTimeToUnix(Now(), false) then
          DampIp.Values[AThread.Binding.PeerIP] := IntToStr(DateTimeToUnix(Now(), false))
          else
          begin
          //DampIp.Values[AThread.Binding.PeerIP] := IntToStr(DateTimeToUnix(Now(), false));
          AResponseInfo.ContentText := 'NOOK';
          AResponseInfo.ResponseNo := 200;
          exit;
          end;
        }
        if length(s.Split(['errordamp'])) > 1 then
        begin
          if DampIp.Values[AThread.Binding.PeerIP] <> '' then
            if StrToInt64(DampIp.Values[AThread.Binding.PeerIP]) + 10 > DateTimeToUnix(Now(), false) then
            begin
              AResponseInfo.ContentText := 'OK';
              AResponseInfo.ResponseNo := 200;
              exit;
            end;
          writeln(logs, MyTXT2INI(TIdURI.URLDecode(StringReplace(s, '+', ' ', [rfReplaceAll, rfIgnoreCase]))));
          flush(logs);
          DampIp.Values[AThread.Binding.PeerIP] := IntToStr(DateTimeToUnix(Now(), false));
          AResponseInfo.ContentText := 'OK';
          AResponseInfo.ResponseNo := 200;
          exit;
        end;
        // if length(ARequestInfo.URI.Split(['upload/'])[1].Split(['js/'])) > 1
        // then
        // получение решения
      end
      else
      begin
        AResponseInfo.ContentText := '500';
        AResponseInfo.ResponseNo := 500;
        exit;
      end;
    end;
    AThread.Binding.SetKeepAliveValues(true, 60000, 500);
    // writeln(AThread.Binding.PeerIP);
    if (ARequestInfo.URI = '\') or (ARequestInfo.URI = '/') or (ARequestInfo.URI = '') then
    begin
      AResponseInfo.Redirect('/login.html');
      exit;
    end;
    if (pos('index.html', ARequestInfo.URI) > 0) and (DEBUG) then
    begin
      Loadini();
    end;
    if length(ARequestInfo.URI.Split(['protect/'])) > 1 then
    begin
      AResponseInfo.ContentType := 'text/plain; charset=utf-8';
      AResponseInfo.ContentText := '__PrOtEcT_NoT_CoMpLeTeD__';
      AResponseInfo.CacheControl := 'no-cache, must-revalidate';
      if admin_of_admin.PFileName <> '' then
        if admin_of_admin.PFileName + '.txt' = ARequestInfo.URI.Split(['protect/'])[1] then
        begin
          if ARequestInfo.command = 'POST' then
          begin
            AResponseInfo.ContentText := AdminFile(admin_of_admin.PFile.Split(['/', '\'])[1].Split(['.txt'])[0], s);
            // if length(ARequestInfo.URI.Split(['upload/'])[1].Split(['js/'])) > 1
            // then
            // получение решения
          end
          else
            AResponseInfo.ContentText := AdminFile(admin_of_admin.PFile.Split(['/', '\'])[1].Split(['.txt'])[0], '');
          admin_of_admin.PFile := '';
          admin_of_admin.PFileName := '';
          exit;
        end;

      if length(ARequestInfo.URI.Split(['protect/'])[0].Split(['_'])) <= 2 then
        exit;
      s2 := ARequestInfo.URI.Split(['protect/'])[0].Split(['_'])[1];
      Index := -1;
      for i := 0 to High(RunProjects) do
        if RunProjects[i].uniID = s2 then
          Index := i;

      for i := Low(Players) to High(Players) do
        if Players[i].PFileName <> '' then
          if Players[i].PFileName + '.txt' = ARequestInfo.URI.Split(['protect/'])[1] then
          begin
            if ARequestInfo.command = 'POST' then
            begin
              AResponseInfo.ContentText := SaveServFile(Players[i].PFile.Split(['/', '\'])[0], Players[i].PFile.Split(['/', '\'])[1].Split(['.txt'])[0], s, Index);
              // if length(ARequestInfo.URI.Split(['upload/'])[1].Split(['js/'])) > 1
              // then
              // получение решения
            end
            else
              AResponseInfo.ContentText := LoadServFile(Players[i].PFile.Split(['/', '\'])[0], Players[i].PFile.Split(['/', '\'])[1].Split(['.txt'])[0], Index);
            Players[i].ip := AThread.Binding.PeerIP;
            Players[i].PFile := '';
            Players[i].PFileName := '';
            break;
          end;
      exit;
    end;
    if length(ARequestInfo.URI.Split(['commands/'])) > 1 then
      if length(ARequestInfo.URI.Split(['commands/'])[1].Split(['/', '\'])) > 1 then
      begin
        AResponseInfo.CacheControl := 'no-cache, must-revalidate';
        index := GetIndex(ARequestInfo.URI.Split(['commands/'])[1].Split(['/', '\'])[0]);
        if (index = -1) then
        begin
          if ARequestInfo.URI.Split(['commands/'])[1].Split(['/', '\'])[0] = admin_of_admin.name then
          begin
            AResponseInfo.ContentText := md5(FloatToStr(random) + FloatToStr(random) + FloatToStr(random) + FloatToStr(random));
            admin_of_admin.PFileName := RegistrationHash(AResponseInfo.ContentText, admin_of_admin.password);
            admin_of_admin.PFile := ARequestInfo.URI.Split(['commands/'])[1];
          end;
          exit;
        end;
        AResponseInfo.ContentType := 'text/html; charset=utf-8';
        AResponseInfo.ContentText := md5(FloatToStr(random) + FloatToStr(random) + FloatToStr(random) + FloatToStr(random));
        Players[index].PFileName := RegistrationHash(AResponseInfo.ContentText, Players[index].password);
        Players[index].PFile := ARequestInfo.URI.Split(['commands/'])[1];
        exit;
      end;
    if (pos('__secret_information__', ARequestInfo.URI) > 0) then
    begin
      AResponseInfo.ContentText := '403';
      AResponseInfo.ResponseNo := 403;
      exit;
    end;
    if canlogin and ((pos('registering', ARequestInfo.URI) < 3) and (pos('registering', ARequestInfo.URI) > 0)) then
    begin

      AResponseInfo.ContentText := registering(ARequestInfo.Params);
      AResponseInfo.ResponseNo := 200;
      exit;
    end;
    if ((pos('_can_i_register_.txt', ARequestInfo.URI) < 3) and (pos('_can_i_register_.txt', ARequestInfo.URI) > 0)) then
    begin
      AResponseInfo.CacheControl := 'no-cache, must-revalidate';

      if canlogin then
        AResponseInfo.ContentText := 'YES'
      else
        AResponseInfo.ContentText := 'NO';
      AResponseInfo.ResponseNo := 200;
      exit;
    end;

    if (pos('/task', ARequestInfo.URI) = 12) then
    begin
      Index := -1;
      s2 := ARequestInfo.URI.Split(['/task'])[0];
      for i := 0 to High(RunProjects) do
        if '/' + RunProjects[i].uniID = s2 then
          Index := i;
      if Index <> -1 then
      begin
        s2 := LoadDirectory + '\' + Projects[RunProjects[Index].parentInd].folder + 'task' + ARequestInfo.URI.Split(['/task'])[1];
        if not FileExists(s2) then
        begin
          AResponseInfo.ContentText := '404';
          AResponseInfo.ResponseNo := 404;
          exit;
        end;
        AResponseInfo.ContentType := 'text/plain; charset=utf-8';
        AResponseInfo.ResponseNo := 200;
        if (pos('.KUM', AnsiUpperCase(ARequestInfo.Document)) > 0) then
        begin
          AResponseInfo.ContentText := LoadFileToStr2(s2);
        end
        else
          AResponseInfo.ContentText := LoadFileToStr(s2);
        exit;
      end;

    end;

    if not FileExists(LoadDirectory + '\index' + ARequestInfo.URI) then
    begin
      AResponseInfo.ContentText := '404';
      AResponseInfo.ResponseNo := 404;
      exit;
    end
    else
      AResponseInfo.ResponseNo := 200;
    if pos('.PDF', AnsiUpperCase(ARequestInfo.Document)) > 0 then
    begin
      AResponseInfo.ContentType := 'application/pdf';
      AResponseInfo.ContentDisposition := 'inline; filename=' + ExtractFileName(LoadDirectory + '\index' + ARequestInfo.URI) + ';';
      AResponseInfo.ServeFile(AThread, LoadDirectory + '\index' + ARequestInfo.URI);
      exit;
    end
    else if pos('.MP4', AnsiUpperCase(ARequestInfo.Document)) > 0 then
    begin
      // AResponseInfo.ContentType := 'video/mp4';
      { AResponseInfo.ContentDisposition := 'inline; filename=' +
        ExtractFileName(ExtractFilePath(ParamStr(0)) + LoadDirectory + '\index' +
        ARequestInfo.URI) + ';';
        AResponseInfo.AcceptRanges := 'bytes';
        AResponseInfo.ServeFile(AThread, ExtractFilePath(ParamStr(0)) +
        LoadDirectory + '\index' + ARequestInfo.URI); }

      try
        FS := TFileStream.Create(LoadDirectory + '\index' + ARequestInfo.URI, fmOpenRead or fmShareDenyWrite);
      except
        AResponseInfo.ResponseNo := 500;
        exit;
      end;

      AResponseInfo.ContentType := 'video/mp4';
      AResponseInfo.AcceptRanges := 'bytes';
      AResponseInfo.ContentDisposition := 'inline;';

      if ARequestInfo.Ranges.Count = 1 then
      begin
        Range := ARequestInfo.Ranges.Ranges[0];

        StartPos := Range.StartPos;
        EndPos := Range.EndPos;

        if StartPos >= 0 then
        begin
          // requesting prefix range from BOF
          if EndPos >= 0 then
            EndPos := IndyMin(EndPos, StartPos + (1024 * 1024 * 10) - 1)
          else
            EndPos := StartPos + (1024 * 1024 * 10) - 1;
        end
        else
        begin
          // requesting suffix range from EOF
          if EndPos >= 0 then
            EndPos := IndyMin(EndPos, 1024 * 1024 * 10)
          else
            EndPos := (1024 * 1024 * 10);
        end;

        AResponseInfo.ContentStream := TIdHTTPRangeStream.Create(FS, StartPos, EndPos);
        AResponseInfo.ResponseNo := TIdHTTPRangeStream(AResponseInfo.ContentStream).ResponseCode;

        if AResponseInfo.ResponseNo = 206 then
        begin
          AResponseInfo.ContentRangeStart := TIdHTTPRangeStream(AResponseInfo.ContentStream).RangeStart;
          AResponseInfo.ContentRangeEnd := TIdHTTPRangeStream(AResponseInfo.ContentStream).RangeEnd;
          AResponseInfo.ContentRangeInstanceLength := FS.Size;
        end;
      end
      else
      begin
        AResponseInfo.ContentStream := FS;
        AResponseInfo.ResponseNo := 200;
      end;
      exit;
    end
    else if pos('.AVI', AnsiUpperCase(ARequestInfo.Document)) > 0 then
    begin
      AResponseInfo.ContentType := 'video/x-msvideo';
      AResponseInfo.ContentDisposition := 'inline; filename=' + ExtractFileName(LoadDirectory + '\index' + ARequestInfo.URI) + ';';
      AResponseInfo.ServeFile(AThread, LoadDirectory + '\index' + ARequestInfo.URI);
      exit;
    end
    else if pos('.DOCX', AnsiUpperCase(ARequestInfo.Document)) > 0 then
    begin
      // AResponseInfo.ContentType := 'application/msword';
      AResponseInfo.ContentDisposition := 'inline; filename=' + ExtractFileName(LoadDirectory + '\index' + ARequestInfo.URI) + ';';
      AResponseInfo.ServeFile(AThread, LoadDirectory + '\index' + ARequestInfo.URI);
      exit;
    end
    else if pos('.MP3', AnsiUpperCase(ARequestInfo.Document)) > 0 then
    begin
      AResponseInfo.ContentType := 'audio/x-mpeg-3';
      img := true;
    end
    else if pos('.ICO', AnsiUpperCase(ARequestInfo.Document)) > 0 then
    begin
      AResponseInfo.CacheControl := 'public, max-age=3600';
      AResponseInfo.Pragma := 'cache';
      AResponseInfo.Expires := IncHour(Now());
      AResponseInfo.ContentType := 'image/x-icon';
      img := true;
    end
    else if pos('.GIF', AnsiUpperCase(ARequestInfo.Document)) > 0 then
    begin
      AResponseInfo.CacheControl := 'public, max-age=3600';
      AResponseInfo.Pragma := 'cache';
      AResponseInfo.Expires := IncHour(Now());
      AResponseInfo.ContentType := 'image/gif';
      img := true;
    end
    else if pos('.JPG', AnsiUpperCase(ARequestInfo.Document)) > 0 then
    begin
      AResponseInfo.CacheControl := 'public, max-age=3600';
      AResponseInfo.Pragma := 'cache';
      AResponseInfo.Expires := IncHour(Now());
      AResponseInfo.ContentType := 'image/jpg';
      img := true;
    end
    else if pos('.JPEG', AnsiUpperCase(ARequestInfo.Document)) > 0 then
    begin
      AResponseInfo.CacheControl := 'public, max-age=3600';
      AResponseInfo.Pragma := 'cache';
      AResponseInfo.Expires := IncHour(Now());
      AResponseInfo.ContentType := 'image/jpeg';
      img := true;
    end
    else if pos('.BMP', AnsiUpperCase(ARequestInfo.Document)) > 0 then
    begin
      AResponseInfo.CacheControl := 'public, max-age=3600';
      AResponseInfo.Pragma := 'cache';
      AResponseInfo.Expires := IncHour(Now());
      AResponseInfo.ContentType := 'image/bmp';
      img := true;
    end
    else if pos('.PNG', AnsiUpperCase(ARequestInfo.Document)) > 0 then
    begin
      AResponseInfo.CacheControl := 'public, max-age=3600';
      AResponseInfo.Pragma := 'cache';
      AResponseInfo.Expires := IncHour(Now());
      AResponseInfo.ContentType := 'image/png';
      img := true;
    end
    else if (pos('.CSS', AnsiUpperCase(ARequestInfo.Document)) > 0) then
    begin
      AResponseInfo.ContentType := 'text/css; charset=utf-8';
      img := false;
    end
    else if (pos('.KUM', AnsiUpperCase(ARequestInfo.Document)) > 0) then
    begin
      AResponseInfo.ContentType := 'text/plain; charset=utf-8';
      AResponseInfo.ContentText := LoadFileToStr2(LoadDirectory + '\index' + ARequestInfo.URI);
      AResponseInfo.ResponseNo := 200;
      exit;
      // img := false;
      // LoadFileToStr2
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
      AResponseInfo.ServeFile(AThread, LoadDirectory + '\index' + ARequestInfo.URI)
    else
      AResponseInfo.ContentText := LoadFileToStr(LoadDirectory + '\index' + ARequestInfo.URI);

  finally
    inerv._end := Now;
    tps_que_cs.Enter;
    try
      SetLength(tps_que, length(tps_que) + 1);
      tps_que[high(tps_que)] := inerv;
      tps[random(60)] := MilliSecondsBetween(inerv._start, inerv._end) + 1;
    finally
      tps_que_cs.Leave;
    end;
  end;
end;

procedure TCommandHandler.Context(AContext: TIdContext);
var
  i: longint;
begin
  for i := 0 to length(blacklisted) - 1 do
    If blacklisted[i] = AContext.Binding.PeerIP Then
    begin
      AContext.Connection.IOHandler.InputBuffer.Clear;
      AContext.Connection.Disconnect; // or raise an Exception...
      exit;
    end;
end;

var
  sr: TSearchRec;
  myi, myj, myk, myport: longint;
  task: ITask;
  iswork: boolean;
  str, str2: string;

var
  fls: text;

var
  files: TStringDynArray;
  bestindex: longint;

begin

  LoadDirectory := ExtractFilePath(ParamStr(0)) + 'WebKumirFiles';
  DEBUG := false;
  if (not DirectoryExists(LoadDirectory)) then
  begin
    writeln('   Creating proj-folder...  |         Создание проекта         ');
    writeln('         Please wait        |       Подождите, пожалуйста      ');
    writeln('');
    try

      GetResource('index', LoadDirectory);
    except
      on e: Exception do
      begin
        writeln('Error ' + e.ClassName + ' : ' + e.Message + ' : ' + e.StackTrace + ' : ' + e.UnitScope + ' : ' + e.UnitName);
        exit;
      end;
    end;
  end;
  Server := TIdHTTPServer.Create(nil);
  CH := TCommandHandler.Create;
  Server.OnContextCreated := CH.Context;
  Server.OnCommandGet := CH.CommandGet;
  Server.KeepAlive := true;
  Server.ListenQueue := 100;
  Server.MaximumHeaderLineCount := 2048 * 2;
  iswork := true;
  task := TTask.Create(
    procedure()
    var
      a: longint;
      b: longint;
      c: longint;
    var
      write_time: int64;
    begin
      a := 0;
      need_update := false;
      while iswork do
      begin
        if (a > 2 * 60) or (need_update and (a > 2 * 5)) then
        begin
          SaveAll(false);
          write('>');
          need_update := false;
          a := 0;
        end
        else
        begin
          SaveAll(true);
          inc(a);
        end;
        for b := 1 to 30 do
          if iswork then
          begin
            sleep(1000);
            if iswork then
              if write_time <> last_request_testing then
                if (DateTimeToUnix(Now(), false) - last_request_testing) > 20 then
                  if (DateTimeToUnix(Now(), false) - last_request_testing) <= 1000000000 then
                  begin
                    write_time := last_request_testing;
                    SetColorConsole(clMaroon);
                    write('Предупреждение: ');
                    SetColorConsole(clWhite);
                    writeln('тестирующая система не работает');
                    writeln(' Для её запуска можно использовать команду "ts"');
                    write('>');
                  end;
          end;
        tps_que_cs.Enter;
        try
          c := -1;
          for b := 0 to High(tps_que) do
            if (MilliSecondsBetween(tps_que[b]._start, Now) > 60000) then
              c := b;
          for b := 0 to c do
            tps_que[b].Free;
          for b := 0 to High(tps_que) do
            if c + b + 1 < length(tps_que) then
              tps_que[b] := tps_que[c + b + 1]
            else
            begin
              SetLength(tps_que, b);
              break;
            end;
        finally
          tps_que_cs.Leave;
        end;
      end;
      SaveAll(false);
    end);
  ips := TStringList.Create;
  DampIp := TStringList.Create;
  admin_of_admin := TAdmin.Create;
  // tps_que := TQueue<T2Date>.Create;
  SetLength(tps_que, 0);
  tps_que_cs := TCriticalSection.Create;
  // SetLength(kumirprogs, 0);
  SetLength(blacklisted, 0);
  try
    assign(logs, LoadDirectory + '\projects\log.txt', CP_UTF8);
    if FileExists(LoadDirectory + '\projects\log.txt') then
      append(logs);

    iniarr(LoadFileToStr(LoadDirectory + '\projects\captcha.txt'));
    randomize();
    admin_of_admin.name := 'admin' + (random(90) + 10).ToString;
    admin_of_admin.password := 'pas' + (random(90000000) + 10000000).ToString;
    isLoadingini := false;
    if not Loadini() then
    begin
      writeln('');
      writeln('Please, fix errors');
      writeln('');
      readln;
      exit;
    end;
    writeln('');
    writeln('');
    writeln('');
    writeln('   ╔════════════════════════════════════════════════════╗');
    writeln('   ║                     WELCOME TO                     ║');
    writeln('   ║                                                    ║');
    writeln('   ║               _     _  __                          ║');
    writeln('   ║              | |   | |/ /                          ║');
    writeln('   ║ __      _____| |__ | '' /_   _ __   __ _   _ _ __   ║');
    writeln('   ║ \ \ /\ / / _ \ ''_ \|  <| | | |  \_/  | | | | ''_ \  ║');
    writeln('   ║  \ V  V /  __/ |_) | . \ |_| |       | |_| | |_) | ║');
    writeln('   ║   \_/\_/ \___|_.__/|_|\_\__, |_|\_/|_|\__,_| .__/  ║');
    writeln('   ║                          __/ |             | |     ║');
    writeln('   ║                         |___/              |_|     ║');
    writeln('   ╚════════════════════════════════════════════════════╝');
    writeln('                           v' + version);
    writeln('');
    writeln('');
    writeln('       Enter the port       |           Введите порт           ');
    writeln(' to start the admin console | для старта консоли администратора');
    writeln('        Default: 80         |        По умолчанию: 80          ');
    write('Port: ');
    if FileExists('auto.txt') then
    begin
      myport := LoadFileToStr('auto.txt').trim().ToInteger;
      SetColorConsole(clMaroon);
      writeln(myport);
      SetColorConsole(clWhite);
      ShellExecute(0, 'open', PChar('http://localhost:' + myport.ToString + '/login.html?auto=true&login=' + admin_of_admin.name + '&password=' + admin_of_admin.password), nil, nil, SW_SHOWNORMAL);
    end
    else
    begin
      readln(str);
      myport := StrToIntDef(str, -1);
      if myport < 1 then
      begin
        myport := 80;
        SetColorConsole(clMaroon);
        writeln('Port: ', myport);
        SetColorConsole(clWhite);
      end;
    end;
    writeln('  ');
    writeln('  ===========================RUN=================================');
    if myport <> 80 then
    begin
      write('  For local computer:  ');
      SetColorConsole(clMaroon);
      write(GetIPs(':' + myport.ToString));
      SetColorConsole(clWhite);
      writeln('  - Для частных компьютеров');
      writeln('  For this computer:     localhost:' + myport.ToString + '      - Для этого компьютера');
    end
    else
    begin
      write('  For local computer:  ');
      SetColorConsole(clMaroon);
      write(GetIPs(''));
      SetColorConsole(clWhite);
      writeln('  - Для частных компьютеров');
      writeln('  For this computer:       localhost       - Для этого компьютера');
    end;
    writeln('  ');
    writeln('      To manage the server    |      Для управления сервером     ');
    writeln('        go to this site       |       зайдите на этот сайт       ');
    writeln('                              |                                  ');
    write('         Login:');
    SetColorConsole(clMaroon);
    write(admin_of_admin.name);
    SetColorConsole(clWhite);
    write('        |          Логин:');
    SetColorConsole(clMaroon);
    writeln(admin_of_admin.name);
    SetColorConsole(clWhite);
    write('      Password:');
    SetColorConsole(clMaroon);
    write(admin_of_admin.password);
    SetColorConsole(clWhite);
    write('    |        Пароль:');
    SetColorConsole(clMaroon);
    writeln(admin_of_admin.password);
    SetColorConsole(clWhite);
    writeln('  ===========================RUN=================================');
    writeln('  ');
    writeln('  ');
    writeln('  ========================FAST HELP===============================');
    writeln('       To open this site      |     Для открытия этого сайта     ');
    writeln('      write "o" or "open"     |    напишите "o" или "открыть"    ');
    writeln('  ');
    writeln('       To copy this site      |     Для копирование этого сайта  ');
    writeln('         write "copy"         |        напишите "копировать"     ');
    writeln('  ');
    writeln('   To automate the inclusion  |     Для автоматизации включения  ');
    writeln('     write "auto"/"noauto"    |      напишите "авто"/"не_авто"   ');
    writeln('  ');
    writeln('     To launch an instance    |       Для запуска экземпляра     ');
    writeln('     of the testing system    |        тестирующей системы       ');
    writeln('          write "ts"          |            напишите "тс"         ');
    writeln('  ');
    writeln('     For help write "help"    |     Для помощи напишите "help"   ');
    writeln('  ========================FAST HELP===============================');
    writeln('  ');
    Server.DefaultPort := myport;
    write_server_data();
    ShellExecuteMy(SW_SHOW, 'open', LoadDirectory + '\init.bat', myport.ToString, LoadDirectory + '\', 1);
    Server.Active := true;
    task.Start;
    while true do
    begin
      write('>');
      readln(str);
      if (str = '') then
        continue;
      if (str.Split([' '])[0] = 'reload') then
      begin
        Loadini();

      end;

      if (str.Split([' '])[0] = 'lres') then
      begin
        if (length(str.Split([' '])) <= 1) then
        begin
          writeln('loading reserve');
          // FileNameToDate
          files := TDirectory.GetFiles(LoadDirectory + '\autosaves\', '*.ini', TSearchOption.soAllDirectories);
          bestindex := -1;
          for myi := 0 to length(files) - 1 do
            if ExtractOnlyFileName(files[myi]) <> 'defaut' then
              if bestindex = -1 then
              begin
                bestindex := myi;
              end
              else if FileNameToDate(ExtractOnlyFileName(files[bestindex])) < FileNameToDate(ExtractOnlyFileName(files[myi])) then
              begin
                bestindex := myi;
              end;
          if bestindex <> -1 then
            writeln('newest reserve is ' + files[bestindex]);
          writeln('operative Bbackups:');
          for myi := 0 to length(reserv) - 1 do
            writeln(reserv[myi].FileName);

          writeln('Use "lres" command and name file for Backup');
          writeln('example: "lres C:\directory\file.ini"');
        end
        else
        begin
          for myi := 0 to length(reserv) - 1 do
            if (reserv[myi].FileName = str.Split([' '])[1]) then
              reserv[myi].UpdateFile;
          if CopyFile(PWideChar(str.Split([' '])[1]), PWideChar(LoadDirectory + '\projects\defaut.ini'), false) then
          begin
            writeln('Файл успешно скопирован.');
            if FileExists(LoadDirectory + '\projects\defaut.ini') then
              Loadini()
            else
            begin
              writeln('Not found defaut save!!!');
              writeln('For load reserved save use "lres" command');
            end;
          end
          else
            writeln('Error: файл не был скопирован.');
        end;
      end;

      str := trim(str).ToLower;
      if (str = '') then
        continue;
      if (str = 'o') or (str = 'open') or (str = 'о') or (str = 'открыть') then
      begin
        writeln('         Opening...         |            Открытие...           ');
        ShellExecute(0, 'open', PChar('http://localhost:' + myport.ToString + '/login.html?login=' + admin_of_admin.name + '&password=' + admin_of_admin.password), nil, nil, SW_SHOWNORMAL);
        writeln('');

      end;
      if (str = 'copy') or (str = 'копировать') then
      begin
        writeln('         Copying...         |           Копирование...         ');
        Clipboard.Clear;
        Clipboard.AsText := ('http://localhost:' + myport.ToString + '/login.html?login=' + admin_of_admin.name + '&password=' + admin_of_admin.password);
        writeln('');

      end;

      if (str = 'autosave') or (str = 'save') or (str = 'сохранить') or (str = 'сохрн') then
      begin
        writeln('         Saving...          |           Сохранение...          ');
        SaveAll(false);
        writeln('');
      end;

      if (str = 'auto') or (str = 'авто') then
      begin
        if not FileExists('auto.txt') then
        begin
          writeln('           OK...            |               ОК...              ');
          AssignFile(fls, 'auto.txt');
          ReWrite(fls);
          writeln(fls, myport.ToString);
          Closefile(fls);
          writeln('');
          writeln('   Now, when starting the   |   Теперь при запуске приложения  ');
          writeln('  application, a browser    |  будет открываться окно браузера ');
          writeln('      window will open      | и запускаться тестирущая система ');
        end
        else
        begin
          writeln('      auto run is work      |   автоматический запуск работает ');
        end;
        writeln('');
      end;

      if (str = 'ts') or (str = 'тс') then
      begin
        write_server_data();
        ShellExecuteMy(SW_SHOW, 'open', LoadDirectory + '\init.bat', myport.ToString, LoadDirectory + '\', 1);
        writeln('OK');
      end;
      if (str = 'noauto') or (str = 'не_авто') then
      begin
        if FileExists('auto.txt') then
        begin
          DeleteFile('auto.txt');
          writeln('           OK...            |               ОК...              ');
        end
        else
        begin
          writeln('    auto run isn''t work    | автоматический запуск не работает');
        end;
        writeln('');
      end;
      if (str = 'help') then
      begin
        writeln('  ');
        writeln('  ==========================BACKUP==========================');
        writeln('    lres - Get list of backup');
        writeln('           Получить список резервных копий');
        writeln('');
        writeln('    lres <file> - Set defaut file');
        writeln('                  Восстановить резервную копию');
        writeln('  ==========================BACKUP==========================');
        writeln('');
        writeln('  ============================IP============================');
        writeln('    banip - Write blacklist');
        writeln('            Выводит черный список');
        writeln('');
        writeln('    banip <ip> - Add an IP address to the server blacklist (not saved after restart)');
        writeln('                 Добавить IP-адрес в черный список (не сохраняется после перезагрузки)');
        writeln('');
        writeln('    cbl - Clear blacklist');
        writeln('          Очистить черный список');
        writeln('');
        writeln('    ipl - Write list client ip and number of requests for each');
        writeln('          Вывести список клиентских ip и количество запросов для каждого');
        writeln('');
        writeln('    cipl - Clear iplist');
        writeln('           Очистить iplist');
        writeln('');
        writeln('    ip - Write server IP(s)');
        writeln('         Вывести IP сервера');
        writeln('  ============================IP============================');
        writeln('');
        writeln('  ===========================DEBUG==========================');
        writeln('    debug - On/Off debuging(files are reloaded when the site is reloaded)');
        writeln('            Вкл/выкл отладку (файлы перезагружаются при перезагрузке сайта)');
        writeln('');
        writeln('    tps - Server statistics');
        writeln('          Статистика сервера');
        writeln('');
        writeln('    reload - Reread files');
        writeln('             Перечитать файлы');
        writeln('  ===========================DEBUG==========================');
        writeln('');
        writeln('  ===========================OTHER==========================');
        writeln('    exit - Exit');
        writeln('           Выход');
        writeln('  ===========================OTHER==========================');
        writeln('');
      end;
      if (str = 'tps') then
      begin
        writeln(GetTPSInfo());
      end
      else if (str = 'debug') then
      begin
        if DEBUG then
        begin
          writeln('debugging stopped');
          DEBUG := false
        end
        else
        begin
          isLoadingini := false;
          writeln('debugging started');
          DEBUG := true;
        end
      end
      else if (str.Split([' '])[0] = 'banip') then
      begin
        if (length(str.Split([' '])) = 2) then
        begin
          writeln('adding');
          myj := 0;
          for myi := 0 to High(blacklisted) do
            if blacklisted[myi] = str.Split([' '])[1] then
            begin
              myj := 1;
            end;
          if (myj = 0) then
          begin
            SetLength(blacklisted, length(blacklisted) + 1);
            blacklisted[High(blacklisted)] := str.Split([' '])[1];
            writeln('....OK');
          end
          else
            writeln('....This ip has already been banned');

        end
        else if length(blacklisted) = 0 then
          writeln('banip is empty')
        else
          for str in blacklisted do
            writeln(str);
      end
      else if (str = 'ipl') then
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
        writeln('OK');
      end
      else if (str = 'cipl') then
      begin
        ips.Clear;
        writeln('OK');
      end
      else if (str = 'cbl') then
      begin
        SetLength(blacklisted, 0);
        writeln('OK');
      end
      else if (str = 'exit') then
      begin
        break;
      end
      else if (str = 'ip') then
      begin
        writeln('IP(s): ', GetIPs(':' + myport.ToString));
        writeln('');
      end
    end;
  except
    on e: Exception do
    begin
      writeln('Error ' + e.ClassName + ' : ' + e.Message + ' : ' + e.StackTrace + ' : ' + e.UnitScope + ' : ' + e.UnitName);
      writeln(logs, 'Error ' + e.ClassName + ' : ' + e.Message + ' : ' + e.StackTrace + ' : ' + e.UnitScope + ' : ' + e.UnitName);
      flush(logs);
    end;
  end;

  writeln('** write close for close **');
  iswork := false;
  str := '';
  while task.Status <> TTaskStatus.Completed do
    sleep(50);
  write('>>');
  while str.trim <> 'close' do
  begin
    readln(str);
    write('>>');
  end;
  writeln('OK');

end.
