unit osexport;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  LCLintf;

type

  { Tfrmexport }

  Tfrmexport = class(TForm)
    btnExport: TButton;
    CheckGroup1: TCheckGroup;
    btnSelectAll: TLabel;
    Memo1: TMemo;
    rgFormat: TRadioGroup;
    grConversion: TRadioGroup;

    procedure btnExportClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnSelectAllClick(Sender: TObject);

  private

  public

  end;

var
  frmexport: Tfrmexport;

implementation

{$R *.lfm}

{ Tfrmexport }

uses osmain, osexport_ascii, osexport_hdb, osexport_netcdf;


procedure Tfrmexport.FormShow(Sender: TObject);
begin
  CheckGroup1.items:=frmosmain.ListBox1.Items;

  TRadioButton(rgFormat.Controls[2]).Enabled := False;
end;

procedure Tfrmexport.btnExportClick(Sender: TObject);
Var
  tbl_count, kt: integer;
  DT1, DT2:TDateTime;
  user_path: string;
  hh, mm, ss, ms:word;
begin
 memo1.Clear;

   tbl_count:=0;
   for kt:=0 to frmexport.CheckGroup1.Items.Count-1 do
     if frmexport.CheckGroup1.Checked[kt] then begin
      inc(tbl_count);
      //showmessage(frmexport.CheckGroup1.Items.Strings[kt]);
     end;

   if tbl_count=0 then begin
      showmessage('Variable is not selected!');
      Exit;
   end;


 if frmosmain.ODir.Execute then begin
  // export folder
  user_path:=frmosmain.ODir.FileName+PathDelim;

  DT1:=Now;
  memo1.Lines.Add('...start: ');
  memo1.Lines.Add(FormatDateTime('DD.MM.YYYY hh:nn:ss',DT1));
  Application.ProcessMessages;

  case rgFormat.ItemIndex of
   0: osexport_ascii.ExportASCII(user_path, grConversion.ItemIndex);
   1: osexport_hdb.ExportHDB(user_path, grConversion.ItemIndex); //0-ices, 1-precise
   2: osexport_netcdf.ExportNetCDF(user_path, grConversion.ItemIndex);
  end;

  DT2:=Now;

  memo1.Lines.Add('');
  memo1.Lines.Add('...stop: ');
  memo1.Lines.Add(FormatDateTime('DD.MM.YYYY hh:nn:ss',DT2));
  memo1.Lines.Add('');
  memo1.Lines.Add('...time spent: ');

  DecodeTime(DT2-DT1, hh, mm, ss, ms);
  memo1.Lines.Add('Hours: '+inttostr(hh));
  memo1.Lines.Add('Minutes: '+inttostr(mm));
  memo1.Lines.Add('Seconds: '+inttostr(ss));
  Application.ProcessMessages;

  OpenDocument(user_path);
 end;
end;

procedure Tfrmexport.btnSelectAllClick(Sender: TObject);
var
i: integer;
fl:boolean;
begin
 fl := CheckGroup1.Checked[0];
  for i:=0 to CheckGroup1.Items.Count-1 do
    CheckGroup1.Checked[i]:=not fl;

 if fl=false then
   btnSelectAll.Caption:='Deselect All' else
   btnSelectAll.Caption:='Select All';
end;

end.

