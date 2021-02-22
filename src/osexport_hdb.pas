unit osexport_hdb;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Dialogs,

  // program modules
  osmain, dm, osexport, osunitsconversion, procedures;

procedure ExportHDB(user_path:string; conv:integer);

implementation

procedure ExportHDB(user_path:string; conv:integer);
Var
  ID, k, kt, cnt, units_def:integer;
  tbl, units_name: string;
  Lat, Lon: real;
begin

  try
   frmdm.Q.DisableControls;
  {T}for kt:=0 to frmexport.CheckGroup1.Items.Count-1 do begin
  {C}if frmexport.CheckGroup1.Checked[kt] then begin

     tbl:=frmexport.CheckGroup1.Items.Strings[kt]; {selected table}

     {...default unit values to be converted}
     with frmdm.q2 do begin
       Close;
       SQL.Clear;
       SQL.Add(' select units_id_default from DATABASE_TABLES ');
       SQL.Add(' where name_table=:nt ');
       ParamByName('nt').AsString:=tbl;
       Open;
       units_def:=FieldByName('units_id_default').AsInteger;
       Close;
     end;

     with frmdm.q3 do begin
       Close;
       SQL.Clear;
       SQL.Add(' select name_short as ns from UNITS ');
       SQL.Add(' where id=:units_id ');
       ParamByName('units_id').AsInteger:=units_def;
       Open;
       units_name:=frmdm.q3.FieldByName('ns').AsString;
       Close;
     end;

    frmdm.Q.First;
    cnt:=frmdm.Q.RecordCount;
    k:=0;
     while not frmdm.Q.EOF do begin
       inc(k); //current counter
       ID :=frmdm.Q.FieldByName('ID').Value;
       Lat:=frmdm.Q.FieldByName('LATITUDE').Value;
       Lon:=frmdm.Q.FieldByName('LONGITUDE').Value;


       ProgressTaskbar(k, cnt); // windows progressbar

      frmdm.Q.Next;
     end; //eof Q
   end; // current selected table
  end; // All tables

  finally
    frmdm.Q.EnableControls;
  end;
end;

end.

