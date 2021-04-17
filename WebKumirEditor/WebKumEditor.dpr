program WebKumEditor;

uses
  System.StartUpCopy,
  FMX.Forms,
  WKEditor in 'WKEditor.pas' {Form1},
  MapEditor in 'MapEditor.pas' {Form2},
  PlayersEditor in 'PlayersEditor.pas' {Form3};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TForm2, Form2);
  Application.CreateForm(TForm3, Form3);
  Application.Run;
end.
