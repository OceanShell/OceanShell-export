unit osexport;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  LCLintf, ComCtrls, fphttpclient, fpjson, jsonparser;

type

  { Tfrmexport }

  Tfrmexport = class(TForm)
    btnExport: TButton;
    btnCancel: TButton;
    chkServer: TCheckBox;
    CheckGroup1: TCheckGroup;
    btnSelectAll: TLabel;
    Memo1: TMemo;
    ProgressBar1: TProgressBar;
    rgFormat: TRadioGroup;
    grConversion: TRadioGroup;

    procedure btnCancelClick(Sender: TObject);
    procedure btnExportClick(Sender: TObject);
    procedure CheckGroup1ItemClick(Sender: TObject; Index: integer);
    procedure chkServerChange(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnSelectAllClick(Sender: TObject);

  private

  public

  end;

var
  frmexport: Tfrmexport;
  cancel_fl:boolean = false;

implementation

{$R *.lfm}

{ Tfrmexport }

uses osmain, dm, osexport_ascii, osexport_hdb, osexport_netcdf;


procedure Tfrmexport.FormShow(Sender: TObject);
begin

   {$IFDEF UNIX}
    progressbar1.Visible:=true;
  {$ELSE}
    progressbar1.Visible:=false;
  {$ENDIF}

  CheckGroup1.items:=frmosmain.ListBox1.Items;

  TRadioButton(rgFormat.Controls[2]).Enabled := False;
  TRadioButton(grConversion.Controls[1]).Enabled := False;
end;

procedure Tfrmexport.btnExportClick(Sender: TObject);
Var
  Client: TFPHttpClient;
  Response : TStream;

  tbl_count, kt: integer;
  DT1, DT2:TDateTime;
  user_path, par_str, Params, sql, mode: string;
  tmark:int64;
begin
 memo1.Clear;
 cancel_fl:=false;


 if frmosmain.ODir.Execute then begin
  // export folder
  user_path:=frmosmain.ODir.FileName+PathDelim;

  DT1:=Now;
  memo1.Lines.Add('...start: ');
  memo1.Lines.Add(FormatDateTime('DD.MM.YYYY hh:nn:ss',DT1));
  Application.ProcessMessages;

  (* local export *)
  if chkServer.Checked=false then begin
    case rgFormat.ItemIndex of
     0: osexport_ascii.ExportASCII(user_path, grConversion.ItemIndex);
     1: osexport_hdb.ExportHDB(user_path, grConversion.ItemIndex); //0-ices, 1-precise
     2: osexport_netcdf.ExportNetCDF(user_path, grConversion.ItemIndex);
    end;
  end;

  (* server side export *)
  if chkServer.Checked=true then begin
    par_str:='';
    for kt:=0 to CheckGroup1.Items.Count-1 do
     if CheckGroup1.Checked[kt] then
         par_str:=par_str+'","P_'+CheckGroup1.Items.Strings[kt];

    par_str:=copy(par_str, 3, length(par_str))+'"';

    sql:=trim(StringReplace(frmdm.Q.SQL.Text, LineEnding, ' ', [rfReplaceAll]));

    tmark:=getTickCount64;

     case rgFormat.ItemIndex of
      0: mode:='ascii';
      1: mode:='hdb';
      // 2: mode:='netcdf';
     end;

    Params:= '{'+
             '"time": "'+inttostr(tmark)+'",'+
             '"tables": ['+par_str+'],'+
             '"sql": "'+sql+'",'+
             '"conv": "'+inttostr(grConversion.Itemindex)+'",'+
             '"mode": "'+mode+'"'+
             '}';

    Client := TFPHttpClient.Create(nil);
    Client.AddHeader('User-Agent','Mozilla/5.0 (compatible; fpweb)');
    Client.AddHeader('Content-Type','application/json; charset=UTF-8');
    Client.AddHeader('Accept', 'application/json');
    Client.AllowRedirect := true;
    Client.RequestBody := TStringStream.Create(Params);

    Response := TFileStream.Create(user_path+inttostr(tmark)+'.zip', fmCreate);
    try
        try
            Client.Get('http://158.39.77.222/export', Response);
         // Client.Get('http://127.0.0.1:5000/export', Response);
        except on E:Exception do
          showmessage('Something bad happened in Post Request : ' + E.Message);
        end;
    finally
        Client.RequestBody.Free;
        Client.Free;
        Response.Free;
    end;
  end;

  DT2:=Now;

  memo1.Lines.Add('');
  memo1.Lines.Add('...stop: ');
  memo1.Lines.Add(FormatDateTime('DD.MM.YYYY hh:nn:ss',DT2));
  memo1.Lines.Add('');
  memo1.Lines.Add('...time spent: ');
  memo1.Lines.Add(timetostr(DT2-DT1));
  Application.ProcessMessages;

  OpenDocument(user_path);
 end;
end;

procedure Tfrmexport.CheckGroup1ItemClick(Sender: TObject; Index: integer);
Var
  kt, tbl_count:integer;
begin
 tbl_count:=0;
 for kt:=0 to CheckGroup1.Items.Count-1 do
   if CheckGroup1.Checked[kt] then
    inc(tbl_count);

 if tbl_count>0 then btnExport.Enabled:=true;
 if tbl_count=0 then btnExport.Enabled:=false;
end;

procedure Tfrmexport.chkServerChange(Sender: TObject);
begin
 TRadioButton(grConversion.Controls[1]).Enabled := Not chkServer.Checked;
end;

procedure Tfrmexport.btnCancelClick(Sender: TObject);
begin
  cancel_fl:=true;

  memo1.Lines.Add('');
  memo1.Lines.Add('...export cancelled: ');
  memo1.Lines.Add(FormatDateTime('DD.MM.YYYY hh:nn:ss',now));
  Application.ProcessMessages;

  btnExport.Enabled:=true;
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

 CheckGroup1.OnItemClick(self, 0);
end;


end.

