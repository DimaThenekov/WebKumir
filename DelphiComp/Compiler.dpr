program Compiler;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils, IOUtils, System.Types;

var
  load_s_fil, load_s_kum: string;
  s_fil, s_kum, s_trans: string;
  s_program: TArray<string>;
  i, j, x, y: longint;
  mys, mys2, mys3: string;
  slu: array of string = ['алг', 'нач', 'кон', 'дано', 'надо'];

var
  error: string;
  main: boolean;

function ReadFile(s: string): string;
begin
  try
    ReadFile := TFile.ReadAllText(s);
  except
    on E: Exception do
    begin
      error := error + 'error 500: ' + E.ClassName + ': ' + E.Message + '. ';
    end;
  end;
end;

function KumReplace2(s, s2, s3: string): string;
var
  i: longint;
begin
  result := s;
  for i := 0 to length(slu) - 1 do
    result := StringReplace(result, s2 + slu[i] + s3, s2 + 'kumiralg_' + slu[i]
      + '_kumiralg' + s3, [rfReplaceAll, rfIgnoreCase]);
end;

function KumReplace(s, s2, s3: string): string;
begin

  result := StringReplace(s, s2 + 'цел таб' + s3, s2 + 'целтаб' + s3,
    [rfReplaceAll, rfIgnoreCase]);
  result := StringReplace(result, s2 + 'вещ таб' + s3, s2 + 'вещтаб' + s3,
    [rfReplaceAll, rfIgnoreCase]);
  result := StringReplace(result, s2 + 'лог таб' + s3, s2 + 'логтаб' + s3,
    [rfReplaceAll, rfIgnoreCase]);
  result := StringReplace(result, s2 + 'сим таб' + s3, s2 + 'симтаб' + s3,
    [rfReplaceAll, rfIgnoreCase]);
  result := StringReplace(result, s2 + 'лит таб' + s3, s2 + 'литтаб' + s3,
    [rfReplaceAll, rfIgnoreCase]);

  result := StringReplace(result, s2 + 'то' + s3, #13#10 + s2 + 'то' + s3 +
    #13#10, [rfReplaceAll, rfIgnoreCase]);
  result := StringReplace(result, s2 + 'иначе' + s3, #13#10 + s2 + 'иначе' + s3
    + #13#10, [rfReplaceAll, rfIgnoreCase]);
  result := StringReplace(result, s2 + 'при' + s3, #13#10 + s2 + 'при' + s3 +
    #13#10, [rfReplaceAll, rfIgnoreCase]);
  result := StringReplace(result, s2 + 'кон' + s3, #13#10 + s2 + 'кон' + s3 +
    #13#10, [rfReplaceAll, rfIgnoreCase]);

  result := StringReplace(result, s2 + 'нач' + s3, s2 + 'нач' + s3 + #13#10,
    [rfReplaceAll, rfIgnoreCase]);
  result := StringReplace(result, s2 + 'выбор' + s3, s2 + 'выбор' + s3 + #13#10,
    [rfReplaceAll, rfIgnoreCase]);
  result := StringReplace(result, s2 + 'раз' + s3, s2 + 'раз' + s3 + #13#10,
    [rfReplaceAll, rfIgnoreCase]);

  result := StringReplace(result, s2 + 'кц_при' + s3, #13#10 + s2 + 'кц_при' +
    s3, [rfReplaceAll, rfIgnoreCase]);
  result := StringReplace(result, s2 + 'кц' + s3, #13#10 + s2 + 'кц' + s3,
    [rfReplaceAll, rfIgnoreCase]);
  result := StringReplace(result, s2 + 'все' + s3, #13#10 + s2 + 'все' + s3,
    [rfReplaceAll, rfIgnoreCase]);

end;

function kumir_isType(s: string): boolean;
begin
  kumir_isType := false;
  if (s = 'цел') then
    kumir_isType := true;
  if (s = 'вещ') then
    kumir_isType := true;
  if (s = 'лог') then
    kumir_isType := true;
  if (s = 'сим') then
    kumir_isType := true;
  if (s = 'лит') then
    kumir_isType := true;

  if (s = 'целтаб') then
    kumir_isType := true;
  if (s = 'вещтаб') then
    kumir_isType := true;
  if (s = 'логтаб') then
    kumir_isType := true;
  if (s = 'симтаб') then
    kumir_isType := true;
  if (s = 'литтаб') then
    kumir_isType := true;

end;

function ItisName(s: string): boolean;
var
  dop: boolean;
  i: longint;
begin
  ItisName := true;
  s := Trim(s);
  for i := 1 to length(s) do
  begin
    dop := true;
    if (s[i] >= 'а') and (s[i] <= 'я') then
      dop := false;
    if (s[i] >= 'А') and (s[i] <= 'Я') then
      dop := false;
    if (s[i] >= 'a') and (s[i] <= 'z') then
      dop := false;
    if (s[i] >= 'A') and (s[i] <= 'Z') then
      dop := false;
    if (i > 1) and (s[i] >= '1') and (s[i] <= '9') then
      dop := false;
    if (s[i] = ' ') then
      dop := false;
    if (s[i] = '_') then
      dop := false;

    if dop = true then
      ItisName := false;
  end;
  if length(s) = 0 then
    ItisName := false;
end;

function TranslateName(s: string): string;
var
  s2: string;
  i: longint;
begin
  result := Trim(StringReplace(Trim(s), ' ', '', [rfReplaceAll]));
  s2 := result;
  result := '';
  for i := 1 to length(s2) do
  begin
    if (s2[i] >= 'а') and (s2[i] <= 'я') then
      result := result + s2[i];
    if (s2[i] >= 'А') and (s2[i] <= 'Я') then
      result := result + s2[i];
    if (s2[i] >= 'a') and (s2[i] <= 'z') then
      result := result + '_en_' + s2[i];
    if (s2[i] >= 'A') and (s2[i] <= 'Z') then
      result := result + '_en_' + s2[i];
    if (i > 1) and (s2[i] >= '1') and (s2[i] <= '9') then
      result := result + s2[i];
    if (s2[i] = ' ') then
      result := result + s2[i];
    if (s2[i] = '_') then
      result := result + s2[i];
  end;
  if not ItisName(result) then
    error := error + 'Ошибка возникла при попытки перевести название "' +
      s + '". ';
  result := '___NAME___' + result + '___NAME___'
end;

function TranslateFormula(s: string): string;
var
  s2, s3: string;
begin
  s2 := '((((((' + Trim(s) + '))))))';
  s3 := '';
  result := '';
  for i := 1 to length(s2) do
    if (s2[i] in ['=', '>', '<', '-', '+', '/', '*', '(', ')']) or (s2[i] in ['0' .. '9']) then
    begin
      s3:=Trim(s3);
      if s3 <> '' then
      begin
        if s2[i] = '(' then
          result := result + 'f_' + TranslateName(s3)
        else
          result := result + 'v_' + TranslateName(s3);
        s3 := '';
      end;
      result := result + s2[i];
    end
    else
      s3 := s3 + s2[i];

end;

function TranslateFormuls(s2: string): string;
var
  i: longint;
  s: string;
begin
  s2 := '  ' + s2 + '  ';
  s := StringReplace(s2, ' не ', ' not ', [rfReplaceAll, rfIgnoreCase]);
  s := StringReplace(s, ' да ', ' true ', [rfReplaceAll, rfIgnoreCase]);
  s := StringReplace(s, ' нет ', ' false ', [rfReplaceAll, rfIgnoreCase]);
  s := StringReplace(s, ' или ', ' || ', [rfReplaceAll, rfIgnoreCase]);
  s := StringReplace(s, ' и ', ' && ', [rfReplaceAll, rfIgnoreCase]);
  s := StringReplace(s, '<>', '!=', [rfReplaceAll, rfIgnoreCase]);

  result := '';
  for i := 0 to length(s.Split([','])) - 1 do
  begin
    result := result + TranslateFormula(s.Split([','])[i]);
    if i < length(s.Split([','])) - 1 then
      result := result + ',';
  end;
end;

function TranslateArg(s: string): string;
var
  i: longint;
  s2: string;
begin
  s := '       ' + s + '                 ';
  s := StringReplace(s, ',', ' , ', [rfReplaceAll]);
  result := '';
  for i := 0 to length(s.Split([' '])) - 1 do
  begin
    if not kumir_isType(s.Split([' '])[i]) then
      result := result + s.Split([' '])[i] + ' ';
  end;
  s2 := result;
  result := '';
  if Trim(s2) <> '' then
    for i := 0 to length(s2.Split([','])) - 1 do
    begin
      result := result + 'v_' + TranslateName(s2.Split([','])[i]);
      if (i < length(s2.Split([','])) - 1) then
        result := result + ',';
    end;
  result := Trim(result);

end;

function TranslateDeclare(s: string): string;
var
  i: longint;
  s2: string;
  flag: boolean;
begin

  // get = 'var a,b,c'

  // s = 'цел длина,ширина лол,знача,вещ ддд,цел таб k[-5:5], вещтаб tab[1:4, 1:12], вещтаб tab2[1:4, 1:12,9:999]';

  // --->'цел длина,ширина лол,знача,вещ ддд,цел таб k[-5:5], вещтаб tab[1:4; 1:12], вещтаб tab2[1:4; 1:12;9:999]';
  flag := false;
  s2 := '';
  for i := 1 to length(s) do
  begin
    if (s[i] = '[') then
      flag := true;
    if (s[i] = ']') then
      flag := false;
    if (s[i] = ',') then
      if (flag) then
      begin
        s2 := s2 + ';';
        continue;
      end;
    s2 := s2 + s[i];
  end;

  // --->'длина,ширина лол,знача,ддд,k[-5:5],tab[1:4; 1:12],tab2[1:4; 1:12;9:999]'
  s2 := '       ' + s2 + '                 ';
  s2 := StringReplace(s2, ',', ' , ', [rfReplaceAll]);
  result := '';
  for i := 0 to length(s2.Split([' '])) - 1 do
  begin
    if not kumir_isType(s2.Split([' '])[i]) then
      result := result + s2.Split([' '])[i] + ' ';
  end;

  // --->'v_длина,v_ширина_лол,v_знача,v_ддд,v_k[-5:5],v_tab[1:4; 1:12],v_tab2[1:4; 1:12;9:999]'
  // --->'var v_длина=0;
  // ...;
  // var v_k=newarrayone(-5,5);
  // var v_tab=newarraytwo(1,4,1,12);
  // var v_tab2=newarraythree(1,4,1,12,9,999);
  s2 := result;
  result := '';
  for i := 0 to length(s2.Split([','])) - 1 do
  begin
    if length(s2.Split([','])[i].Split(['['])) = 1 then
      result := result + 'var v_' + TranslateName(s2.Split([','])[i]) +
        ';' + #13#10
    else if length(s2.Split([','])[i].Split(['['])[1].Split([';'])) = 1 then
      result := result + 'var v_' + TranslateName
        (s2.Split([','])[i].Split(['['])[0]).Split(['['])[0] + '=newarrayone(' +
        TranslateFormuls(StringReplace((s2.Split([','])[i]).Split(['['])
        [1].Split([']'])[0], ':', ',', [rfReplaceAll])) + ');' + #13#10
    else if length(s2.Split([','])[i].Split(['['])[1].Split([';'])) = 2 then
      result := result + 'var v_' + TranslateName
        (s2.Split([','])[i].Split(['['])[0]).Split(['['])[0] + '=newarraytwo(' +
        TranslateFormuls(StringReplace(StringReplace((s2.Split([','])[i])
        .Split(['['])[1].Split([']'])[0], ':', ',', [rfReplaceAll]), ';', ',',
        [rfReplaceAll])) + ');' + #13#10
    else if length(s2.Split([','])[i].Split(['['])[1].Split([';'])) = 3 then
      result := result + 'var v_' + TranslateName
        (s2.Split([','])[i].Split(['['])[0]).Split(['['])[0] + '=newarraythree('
        + TranslateFormuls(StringReplace(StringReplace((s2.Split([','])[i])
        .Split(['['])[1].Split([']'])[0], ':', ',', [rfReplaceAll]), ';', ',',
        [rfReplaceAll])) + ');' + #13#10;

  end;
end;

function kumir_command(s: string): string;
begin
  s := Trim(s);
  result := '';
  if s = '' then
    exit;

  if kumir_isType(s.Split([' '])[0]) then
  begin
    result := TranslateDeclare(s);
  end
  else if ItisName(s.Split(['[', ':='])[0]) and (length(s.Split([':='])) = 2)
  then
  begin
    result := 'v_' + Trim(TranslateName(s.Split([':='])[0])) + '=' +
      TranslateFormula(s.Split([':='])[1]) + #13#10;
  end
  else if s.Split([' '])[0] = 'если' then
  begin
    for i := 1 to length(s.Split([' '])) do
      result := result + s.Split([' '])[i] + ' ';
    result := 'if ' + Trim(TranslateFormuls(Trim(result))) + #13#10;
  end
  else if s = 'то' then
  begin
    result := '{' + #13#10;
  end
  else if s = 'все' then
  begin
    result := '}' + #13#10;
  end
  else if s.Split([' '])[0] = 'вывод' then
  begin
    result := '//=command_вывод=' + s + #13#10;
  end
  else if s.Split([' '])[0] = 'ввод' then
  begin
    result := '//=command_ввод=' + s + #13#10;
  end
  else if ItisName(s) then
  begin
    result := 'p_' + TranslateName(s) + '();' + #13#10;
  end
  else
    result := '-----------------------' + s + '=command=' + #13#10;
  // алг нач кон исп кон_исп дано надо арг рез аргрез знач цел вещ лог сим лит таб целтаб вещтаб логтаб симтаб литтаб и или не да нет утв выход ввод вывод нс если то иначе все выбор при нц кц кц_при раз пока для от до шаг.
end;

function kumir_commands(s: string): string;
var
  i: longint;
begin
  result := '';
  for i := 0 to length(s.Split([#13, #10])) - 1 do
    if Trim(s.Split([#13, #10])[i]) <> '' then
      result := result + kumir_command(Trim(s.Split([#13, #10])[i]));

end;

function kumir_function(s: string): string;
var
  zag: string;
  argum: string;
  name, name2: string;
  i: longint;
begin
  try
    zag := Trim(s.Split(['kumiralg_алг_kumiralg'])
      [1].Split(['kumiralg_нач_kumiralg'])[0]);
  except
    error := error + 'Ошибка как-то связана с началом алгоритма. ';
  end;
  argum := '';
  try
    if (length(zag.Split(['('])) = 2) then
      if (length(zag.Split([')'])) = 2) then
        argum := zag.Split(['('])[1].Split([')'])[0];
  except
    error := error +
      'Ошибка возникла при попытки вытащить аргументы алгоритма. ';
  end;
  name := '';
  try
    if (length(zag.Split(['('])) = 2) then
      name := zag.Split(['('])[0];
    if (length(zag.Split(['('])) <> 2) then
      name := zag;
    name2 := Trim(name);
    name := '';
    for i := 1 to length(name2.Split([' '])) - 1 do
      name := name + name2.Split([' '])[i] + ' ';
    name := Trim(name);
    if not ItisName(name) then
      error := error + 'Какое-то ненормальное название алгоритма. ';
    name := TranslateName(name);
  except
    error := error +
      'Ошибка возникла при попытки вытащить название алгоритма. ';
  end;
  if (argum = '') and (main) then
  begin
    result := 'function mainf()';
    main := false;
  end
  else
  begin
    if name <> '' then
      result := 'function f_' + name + '(' + TranslateArg(argum) + ')'
    else
      error := error + 'У алгоритмат должно быть имя! ';

  end;

  try
    result := result + '{' + #13#10 + 'var v_' + TranslateName('знач') + '=0;' +
      #13#10 + 'if(true){' + #13#10 + kumir_commands
      (s.Split(['kumiralg_нач_kumiralg'])[1].Split(['kumiralg_кон_kumiralg'])[0]
      ) + #13#10 + '}' + #13#10 + 'return v_' + TranslateName('знач') + ';' +
      #13#10 + '}' + #13#10;
  except
    error := error + 'А где конец алгоритма? ';
  end;
end;

function kumir_procedura(s: string; a: boolean): string;
var
  zag: string;
  argum: string;
  name: string;
begin
  // result := '======procedura======' + s + '======procedura======';
  try
    zag := Trim(s.Split(['kumiralg_алг_kumiralg'])
      [1].Split(['kumiralg_нач_kumiralg'])[0]);
  except
    error := error + 'Ошибка как-то связана с началом алгоритма. ';
  end;
  argum := '';
  try
    if (length(zag.Split(['('])) = 2) then
      if (length(zag.Split([')'])) = 2) then
        argum := zag.Split(['('])[1].Split([')'])[0];
  except
    error := error +
      'Ошибка возникла при попытки вытащить аргументы алгоритма. ';
  end;
  name := '';
  try
    if (length(zag.Split(['('])) = 2) then
      name := zag.Split(['('])[0];
    if (length(zag.Split(['('])) <> 2) then
      name := zag;
    name := Trim(name);
    if length(name) > 0 then
    begin
      if not ItisName(name) then
        error := error + 'Какое-то ненормальное название алгоритма. ';
      name := TranslateName(Trim(name));
    end
    else
    begin
      name := '';
    end;
  except
    error := error +
      'Ошибка возникла при попытки вытащить название алгоритма. ';
  end;
  if (Trim(argum) = '') and (main) then
  begin
    result := 'function mainf()';
    main := false;
  end
  else
  begin
    if name <> '' then
      result := 'function p_' + name + '(' + TranslateArg(argum) + ')'
    else
      error := error + 'У алгоритмат должно быть имя! ';

  end;

  try
    result := result + '{' + #13#10 + 'if(true){' + #13#10 +
      kumir_commands(s.Split(['kumiralg_нач_kumiralg'])
      [1].Split(['kumiralg_кон_kumiralg'])[0]) + #13#10 + '}' + #13#10 +
      'return 0;' + #13#10 + '}' + #13#10;
  except
    error := error + 'А где конец алгоритма? ';
  end;
end;

function kumir_proceduraorprocedura(s: string): string;
begin
  if kumir_isType(s.Split([' '])[1]) then
    result := kumir_function(s)
  else
  begin
    result := kumir_procedura(s, main);
  end;
end;

function kumir_entry(s: string): string;
var
  i: longint;
  localcommand: string;
begin
  result := 'var v_МЦЕЛ = 2147483647;' + #13#10;
  result := result + 'var v_МВЕЩ = 1.7976931348623157e+308;' + #13#10;
  result := result + 'var v_да=1; var v_нет=0;' + #13#10;
  for i := 0 to length(s.Split([#10])) - 1 do
  begin
    localcommand := Trim(s.Split([#10])[i]);
    if kumir_isType(localcommand.Split([' '])[0]) then
    begin
      try
        result := result + TranslateDeclare(localcommand) + #13#10;
      except
        error := error +
          'В вступлении как-то неправильно написано объявление переменных. ';
      end;
    end
    else
    begin
      try
        result := result + 'v_' + TranslateName(localcommand.Split([':='])[0]) +
          '=' + TranslateFormula(localcommand.Split([':='])[1]) + ';' + #13#10;
      except
        error := error + 'В вступлении находяться непонятная переменная. ';
      end;
    end;
  end;
end;

function kumir_ran(s: string): string;
var
  s2: string;
  i: longint;
  // Тип величины===['цел'/'вещ'/'лог'/'сим']->[''/'таб']
  // команды вне===[команда вне](999)
  // команда вне===[объявление/присвоение]
  // команды===[команда](999)
  // команда===[объявление/присвоение/цыклы/влево/вправо/вверх/вниз/вывод/утв/]
  // объявление===Тип величины
  // имя===['a-z'/'A-Z'/'а-я'/'А-Я'/' '](999)
begin
  // ->'использовать Робот'
  // ->вступление===команды вне
  // ->алгоритм
  // ->->функция===алг->Тип величины->!имя!->
  // ->->процедура===алг->имя*->

  // удаляем 'использовать Робот'
  if (s.Split([#10])[0].IndexOf('использовать Робот') = -1) then
  begin
    error := 'Не найдено использование Робота. Добавте строку "использовать Робот" в начало.';
    exit;
  end;
  s := StringReplace(s, s.Split([#10])[0] + #10, '', []);
  // удаляем 'использовать Робот'
  main := true;
  s2 := kumir_entry(Trim(s.Split(['kumiralg_алг_kumiralg'])[0])) + #13#10;
  for i := 1 to length(s.Split(['kumiralg_алг_kumiralg'])) - 1 do
    s2 := s2 + kumir_proceduraorprocedura('kumiralg_алг_kumiralg' +
      s.Split(['kumiralg_алг_kumiralg'])[i].Split(['kumiralg_кон_kumiralg'])[0]
      + 'kumiralg_кон_kumiralg');

  result := s2 + 'mainf();';
end;

var
  simvols: array of string = [' ', #13#10, '(', ')']; // нейтральные символы

begin
  try
    { TODO -oUser -cConsole Main : Insert code here }
    error := '';
    load_s_fil := 'c:\1.fil'; // readln(load_s_fil);
    load_s_kum := 'c:\1.kum'; // readln(load_s_prog);
    s_fil := ReadFile(load_s_fil);
    s_kum := ReadFile(load_s_kum);
    // Writeln(s_fil);
    // Writeln(s_kum);
    Writeln('=======================');
    Writeln(s_kum);
    Writeln('=======================');
    // удаляем пробелы и ненужные переносы
    // удаляем пробелы и ненужные переносы
    s_kum := StringReplace(s_kum, ';', #13#10, [rfReplaceAll, rfIgnoreCase]);
    s_program := s_kum.Split([#10]);
    s_kum := '';
    for i := 0 to length(s_program) - 1 do
    begin
      mys := '';
      for j := 1 to length(s_program[i]) do
      begin
        if (s_program[i][j] = '|') then
          break;
        mys := mys + s_program[i][j];
      end;
      if (Trim(mys) <> '') then
        s_kum := s_kum + Trim(mys) + #13#10;
    end;
    // удаляем пробелы и ненужные переносы
    // удаляем пробелы и ненужные переносы
    // перед словом при и после двоеточия в при-строке
    for i := 0 to length(simvols) - 1 do
      for j := 0 to length(simvols) - 1 do
        s_kum := KumReplace(s_kum, simvols[i], simvols[j]);

    for i := 0 to length(simvols) - 1 do
      for j := 0 to length(simvols) - 1 do
        s_kum := KumReplace2(s_kum, simvols[i], simvols[j]);

    // удаляем пробелы и ненужные переносы
    // удаляем пробелы и ненужные переносы
    s_program := s_kum.Split([#10]);
    s_kum := '';
    for i := 0 to length(s_program) - 1 do
    begin
      mys := '';
      for j := 1 to length(s_program[i]) do
      begin
        if (s_program[i][j] = '|') then
          break;
        mys := mys + s_program[i][j];
      end;
      if (Trim(mys) <> '') then
        s_kum := s_kum + Trim(mys) + #13#10;
    end;
    // удаляем пробелы и ненужные переносы
    // удаляем пробелы и ненужные переносы

    Writeln('=======================');
    Writeln(s_kum);
    Writeln('=======================');
    s_trans := kumir_ran(s_kum);

    if error <> '' then
      Writeln(error)
    else
    begin
      Writeln('=======================');
      Writeln(s_trans);
      Writeln('=======================');

    end;
    readln;
  except
    on E: Exception do
    begin
      Writeln('error');
      Writeln(E.ClassName, ': ', E.Message);
    end;
  end;

end.
