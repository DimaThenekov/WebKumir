unit WKEditor;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Edit,
  FMX.Layouts, FMX.TreeView, FMX.StdCtrls, FMX.Controls.Presentation,
  FMX.Memo.Types, FMX.ScrollBox, FMX.Memo,System.IniFiles;

type
  TForm1 = class(TForm)
    TabPanel: TPanel;
    TabName: TLabel;
    PrTree: TTreeView;
    TreeMap: TTreeViewItem;
    TreePlayers: TTreeViewItem;
    TreeTasks: TTreeViewItem;
    TreeViewItem7: TTreeViewItem;
    TabSave: TButton;
    TabOpen: TButton;
    procedure TabChange();
    procedure FormShow(Sender: TObject);
    procedure TreeMapDblClick(Sender: TObject);
    procedure TreeItemClick(Sender: TObject);
    procedure TabOpenClick(Sender: TObject);
    procedure TabSaveClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  isRed:array[0..2] of boolean;
  MapIni: TMemIniFile;
  PlayersIni: TMemIniFile;
  TaskIni: TMemIniFile;

implementation

{$R *.fmx}

uses MapEditor, PlayersEditor;

procedure TForm1.FormShow(Sender: TObject);
begin
  // a;
  MapIni:= TMemIniFile.Create('');
  PlayersIni:= TMemIniFile.Create('');
  TaskIni:= TMemIniFile.Create('');
  TabOpenClick(nil);
end;

procedure TForm1.TreeItemClick(Sender: TObject);
begin
  //ShowMessage('');
  editNum:=TTreeViewItem(Sender).Tag;
  with TForm3.Create(nil) do
    try
      ShowModal;
    finally
      Free;
    end;
end;
procedure TForm1.TabChange();
var i,j:longint;
    TreeNewItem:TTreeViewItem;
begin
  for i := 0 to TreePlayers.Count-1 do
    TreePlayers.ItemByIndex(0).Free;
  for i := 0 to PlayersIni.ReadInteger('Players','count',0)-1 do
  begin
    TreeNewItem:=TTreeViewItem.Create(Self);
    TreeNewItem.Text:=PlayersIni.ReadString('Player:'+i.ToString,'name','ERRRRROOR');
    TreeNewItem.Parent:= TreePlayers;
    TreeNewItem.OnDblClick:=TreeItemClick;
    TreeNewItem.Tag:=i;
  end;

end;

procedure TForm1.TabOpenClick(Sender: TObject);
begin
  MapIni.Free;
  PlayersIni.Free;
  TaskIni.Free;
  MapIni:= TMemIniFile.Create('save\map.m.ini');
  PlayersIni:= TMemIniFile.Create('save\defaut.ini');
  TaskIni:= TMemIniFile.Create('save\all.ini');
  isRed[0]:=false;
  isRed[1]:=false;
  isRed[2]:=false;
  TabChange();
end;

procedure TForm1.TabSaveClick(Sender: TObject);
begin
  if isRed[0] then
    MapIni.UpdateFile;
  if isRed[1] then
    PlayersIni.UpdateFile;
  if isRed[2] then
    TaskIni.UpdateFile;
end;

procedure TForm1.TreeMapDblClick(Sender: TObject);
begin
  with TForm2.Create(nil) do
    try
      ShowModal;
    finally
      Free;
    end;
end;

end.
