unit PlayersEditor;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Edit, FMX.EditBox, FMX.NumberBox, FMX.Layouts,
  FMX.ListBox;

type
  TForm3 = class(TForm)
    Panel1: TPanel;
    Label1: TLabel;
    Panel2: TPanel;
    Panel3: TPanel;
    Label2: TLabel;
    Edit1: TEdit;
    Label3: TLabel;
    Edit2: TEdit;
    Panel4: TPanel;
    Label4: TLabel;
    Label5: TLabel;
    GridPanelLayout1: TGridPanelLayout;
    NumberBox1: TNumberBox;
    NumberBox2: TNumberBox;
    Panel5: TPanel;
    Label6: TLabel;
    ComboBox1: TComboBox;
    CheckBox1: TCheckBox;
    Panel6: TPanel;
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    Label7: TLabel;
    Button5: TButton;
    FramedVertScrollBox1: TFramedVertScrollBox;
    Label8: TLabel;
    CheckBox2: TCheckBox;
    Panel8: TPanel;
    ComboBox3: TComboBox;
    Panel9: TPanel;
    Label9: TLabel;
    NumberBox3: TNumberBox;
    GridPanelLayout2: TGridPanelLayout;
    procedure Edit1ChangeTracking(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure Edit1Change(Sender: TObject);
    procedure Edit2Change(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure ComboBox1Change(Sender: TObject);
    procedure NumberBox1Change(Sender: TObject);
    procedure NumberBox2Change(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure NumberBox3Change(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure ComboBox3Change(Sender: TObject);
    procedure CheckBox1Change(Sender: TObject);
    procedure CheckBox2Change(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form3: TForm3;
  editNum:longint;

implementation

{$R *.fmx}

uses WKEditor;

procedure TForm3.Button1Click(Sender: TObject);
begin
  NumberBox1.Value:=0;
  NumberBox2.Value:=0;
end;

procedure TForm3.Button2Click(Sender: TObject);
var i:longint;
begin
  for i := 0 to TaskIni.ReadInteger('Count','tasks',0)-1 do
     PlayersIni.WriteInteger('Player:'+editNum.ToString,'dors'+i.ToString,0);
  ComboBox1Change(nil);
end;

procedure TForm3.Button3Click(Sender: TObject);
begin
  PlayersIni.WriteInteger('Player:'+editNum.ToString,'personage_skin',59);
  PlayersIni.WriteInteger('Player:'+editNum.ToString,'personage_hairstyle',1);
  PlayersIni.WriteInteger('Player:'+editNum.ToString,'personage_eye',7);
  PlayersIni.WriteInteger('Player:'+editNum.ToString,'personage_shirt',16);
  PlayersIni.WriteInteger('Player:'+editNum.ToString,'personage_pants',5);
  PlayersIni.WriteInteger('Player:'+editNum.ToString,'personage_footwear',2);
end;

procedure TForm3.Button4Click(Sender: TObject);
var i:longint;
begin
  for i := 0 to TaskIni.ReadInteger('Count','tasks',0)-1 do
     PlayersIni.WriteInteger('Player:'+editNum.ToString,'isaccess'+i.ToString,0);
  ComboBox1Change(nil);
end;

procedure TForm3.Button5Click(Sender: TObject);
begin
  NumberBox3.Value:=0;
end;

procedure TForm3.CheckBox1Change(Sender: TObject);
begin
  PlayersIni.WriteInteger('Player:'+editNum.ToString,'isaccess'+ComboBox1.ItemIndex.ToString,CheckBox1.IsChecked.ToInteger);
end;

procedure TForm3.CheckBox2Change(Sender: TObject);
begin
  PlayersIni.WriteInteger('Player:'+editNum.ToString,'dors'+ComboBox1.ItemIndex.ToString,CheckBox2.IsChecked.ToInteger);
end;

procedure TForm3.ComboBox1Change(Sender: TObject);
begin
  CheckBox1.IsChecked:=PlayersIni.ReadInteger('Player:'+editNum.ToString,'isaccess'+ComboBox1.ItemIndex.ToString,-1)=1;
  CheckBox2.IsChecked:=PlayersIni.ReadInteger('Player:'+editNum.ToString,'dors'+ComboBox1.ItemIndex.ToString,-1)=1;

end;

procedure TForm3.ComboBox3Change(Sender: TObject);
begin
  PlayersIni.WriteInteger('Player:'+editNum.ToString,'isAdmin',ComboBox3.ItemIndex);
end;

procedure TForm3.Edit1Change(Sender: TObject);
begin
  PlayersIni.WriteString('Player:'+editNum.ToString,'name',Edit1.Text);
  Form1.TabChange();
end;

procedure TForm3.Edit1ChangeTracking(Sender: TObject);
var
  symbols, textInEdit: String;
   i: Integer;
begin
  symbols := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#№(){}[];:,.<>+/-=';
  for i := 1 to Length(Edit1.Text) do
  begin
    if (Pos(Copy(Edit1.Text, i, 1), symbols) = 0) then  // Если i-й символ отсутствует в наборе символов...
    begin
      textInEdit := Edit1.Text;
      Delete(textInEdit, i, 1);  // ...удаляем этот символ
      Edit1.Text := textInEdit;
      Edit1ChangeTracking(Sender);
      break;
    end;
  end;
end;

procedure TForm3.Edit2Change(Sender: TObject);
begin
  PlayersIni.WriteString('Player:'+editNum.ToString,'password',Edit2.Text);
end;

procedure TForm3.FormShow(Sender: TObject);
var i:longint;
begin
//ShowMessage(editNum.ToString);
  Edit1.Text:=PlayersIni.ReadString('Player:'+editNum.ToString,'name','ERRRRROOR');
  Edit2.Text:=PlayersIni.ReadString('Player:'+editNum.ToString,'password','ERRRRROOR');
  ComboBox3.ItemIndex:=PlayersIni.ReadInteger('Player:'+editNum.ToString,'isAdmin',0);
  NumberBox1.Value:=PlayersIni.ReadInteger('Player:'+editNum.ToString,'posx',0);
  NumberBox2.Value:=PlayersIni.ReadInteger('Player:'+editNum.ToString,'posy',0);
  NumberBox3.Value:=PlayersIni.ReadInteger('Player:'+editNum.ToString,'dollars',0);
  ComboBox1.Items.Clear;
  ComboBox1.ItemIndex:=0;
  for i := 0 to TaskIni.ReadInteger('Count','tasks',0)-1 do
     ComboBox1.Items.Add(TaskIni.ReadString('Task:'+i.ToString,'name',''));
end;

procedure TForm3.NumberBox1Change(Sender: TObject);
begin
  PlayersIni.WriteInteger('Player:'+editNum.ToString,'posx',round(NumberBox1.Value));
end;

procedure TForm3.NumberBox2Change(Sender: TObject);
begin
  PlayersIni.WriteInteger('Player:'+editNum.ToString,'posy',round(NumberBox2.Value));
end;

procedure TForm3.NumberBox3Change(Sender: TObject);
begin
  PlayersIni.WriteInteger('Player:'+editNum.ToString,'dollars',round(NumberBox3.Value));
end;

end.
