{export in station presentation format (similar to old HDB format)}
{metadata and profiles}
{where neccesary observed values in reported units are concerted to default units}
{conversion of liters to kilograms made with constant water density 1.025 }

unit osexport_hdb;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Dialogs, Variants,

  // program modules
  osmain, dm, osexport, osunitsconversion, procedures;

procedure ExportHDB(user_path:string; conv:integer);

implementation

//liter to kg conversion
//conv=0: constant density 1.025 (ICES)
//conv=1  computed density
procedure ExportHDB(user_path:string; conv:integer);
Type
DAR=Array of Array of double; //dynmic array of real

Var
DSt: DAR;
i,j,kt,var_count,stations_count,index :integer;
station_id,cruise_id,source_id :integer;
cnt,units_def,units_id,bd,stver,cast,instrument :integer;
tn,prfn :integer;
lat,lon,val,val_conv1,lev_dbar,lev_m,DF: real;
fn,tbl,units_name :string;
cruise_number,PI_name,stno,str,units_sname :string;
dt :TDateTime;
st_with_data,ipd_exist,isconverted: boolean;
fo: text;

begin

fn:=user_path+'data.txt';
assignfile(fo,fn);
rewrite(fo);
DF:=-9999; //default value for missing observations

writeln(fo,'# information');
writeln(fo,'# ');
writeln(fo,'# inst: ');
writeln(fo,'# 0  UNKNOWN ');
writeln(fo,'# 1  MBT ');
writeln(fo,'# 2  XB ');
writeln(fo,'# 3  DBT ');
writeln(fo,'# 4  CTD ');
writeln(fo,'# 5  STD ');
writeln(fo,'# 6  XCTD ');
writeln(fo,'# 7  BOTTLE ');
writeln(fo,'# 8  UNDERWAY ');
writeln(fo,'# 9  PROFILING FLOAT ');
writeln(fo,'# 10 MOORED BUOY ');
writeln(fo,'# 11 DRIFTING BUOY ');
writeln(fo,'# 12 TOWED CTD ');
writeln(fo,'# 13 ANIMAL MOUNTED ');
writeln(fo,'# 14 BUCKET ');
writeln(fo,'# 15 GLIDER ');
writeln(fo,'# 16 mBT ');
writeln(fo,'# 17 AXCTD ');
writeln(fo,'# ');
writeln(fo,'# prfn - profile number measured by the instrument');
writeln(fo,'# [dbar] -depth level in dbar');
writeln(fo,'# [m] -depth level in meter');
writeln(fo,'# Default value: '+floattostr(DF));
writeln(fo,'# ');
writeln(fo,'# ');
writeln(fo,'# ');

{try}try
    frmdm.Q.DisableControls;
    frmdm.Q.First;
    cnt:=frmdm.Q.RecordCount;

    stations_count:=0;
{Q}while not frmdm.Q.EOF do begin
    inc(stations_count); //current counter

    station_id :=frmdm.Q.FieldByName('id').Value;
    cruise_id:=frmdm.Q.FieldByName('cruise_id').Value;
    lat:=frmdm.Q.FieldByName('latitude').Value;
    lon:=frmdm.Q.FieldByName('longitude').Value;
    dt:=frmdm.Q.FieldByName('dateandtime').Value;
    if not VarIsNull(frmdm.Q.FieldByName('bottomdepth').Value) then
    bd:=frmdm.Q.FieldByName('bottomdepth').Value else bd:=trunc(DF);
    if not VarIsNull(frmdm.Q.FieldByName('st_number_origin').Value) then
    stno:=frmdm.Q.FieldByName('st_number_origin').Value else stno:='unknown';
    stver:=frmdm.Q.FieldByName('stversion').Value;
    cast:=frmdm.Q.FieldByName('cast_number').Value;

    {...default unit values to be converted}
    with frmdm.q2 do begin
      Close;
      SQL.Clear;
      SQL.Add(' select source_id, cruise_number, PI from CRUISE ');
      SQL.Add(' where id=:cruise_id ');
      ParamByName('cruise_id').AsInteger:=cruise_id;
      Open;
      source_id:=FieldByName('source_id').AsInteger;
      cruise_number:=FieldByName('cruise_number').AsString;
      PI_name:=FieldByName('PI').AsString;
      Close;
    end;

    ProgressTaskbar(stations_count, cnt); // windows progressbar

//check available data at station
    var_count:=0;
    str:='inst'+#9+'prfn'+#9+'[dbar]'+#9+'[m]';
{T}for kt:=0 to frmexport.CheckGroup1.Items.Count-1 do begin
{C}if frmexport.CheckGroup1.Checked[kt] then begin
    tbl:=frmexport.CheckGroup1.Items.Strings[kt];

 {...variables at the station}
    st_with_data:=false;
  with frmdm.q2 do begin
    Close;
    SQL.Clear;
    SQL.Add(' select id from '+tbl);
    SQL.Add(' where id=:station_id ');
    SQL.Add(' and PQF2>=3 ');
    ParamByName('station_id').AsInteger:=station_id;
    Open;
    if frmdm.q2.IsEmpty=false then begin inc(var_count); st_with_data:=true; end;
    Close;
   end;

{D}if st_with_data=true then begin
  {...default unit ID}
  with frmdm.q2 do begin
    Close;
    SQL.Clear;
    SQL.Add(' select units_id_default from DATABASE_TABLES ');
    SQL.Add(' where name_table=:tbl ');
    ParamByName('tbl').AsString:=tbl;
    Open;
    units_def:=FieldByName('units_id_default').AsInteger;
    Close;
  end;
  {...default unit names}
   with frmdm.q2 do begin
    Close;
    SQL.Clear;
    SQL.Add(' select name_short,name from UNITS ');
    SQL.Add(' where id=:units_def ');
    ParamByName('units_def').AsInteger:=units_def;
    Open;
    units_sname:=FieldByName('name_short').AsString;
    units_name:=FieldByName('name').AsString;
    Close;
   end;
   str:=str+#9+tbl+'('+units_sname+')';
{D}end;
{C}end;
{T}end;

{V}if var_count>0 then begin

    //frmexport.Memo2.lines.Add('station_id='+inttostr(station_id));
    //showmessage('station_id='+inttostr(station_id)+'  variables at station:'+str);

    writeln(fo,inttostr(station_id)+#9+'(station_id)');
    writeln(fo,inttostr(cruise_id)+#9+'(cruise_id)');
    writeln(fo,inttostr(source_id)+#9+'(source_id)');
    writeln(fo,cruise_number+#9+'(cruise_number)');
    writeln(fo,PI_name+#9+'(PI)');
    writeln(fo,floattostr(lat)+#9+'(latitude deg.)');
    writeln(fo,floattostr(lon)+#9+'(longitude deg.)');
    writeln(fo,datetimetostr(dt)+#9+'(station date and time)');
    writeln(fo,inttostr(bd)+#9+'(bottom depth)');
    writeln(fo,stno+#9+'(st_number_origin)');
    writeln(fo,inttostr(stver)+#9+'(station version)');
    writeln(fo,inttostr(cast)+#9+'(cast number)');
    writeln(fo,inttostr(var_count)+#9+'(number of variables at station)');
    writeln(fo,str);
    //writeln(fo,'....................');

      tn:=0; //table sequential number in DSt
{T}for kt:=0 to frmexport.CheckGroup1.Items.Count-1 do begin
{C}if frmexport.CheckGroup1.Checked[kt] then begin

     tbl:=frmexport.CheckGroup1.Items.Strings[kt]; {selected table}
     //frmexport.Memo2.lines.Add(tbl);

     {...variables at the station}
        st_with_data:=false;
      with frmdm.q2 do begin
        Close;
        SQL.Clear;
        SQL.Add(' select id from '+tbl);
        SQL.Add(' where id=:station_id ');
        ParamByName('station_id').AsInteger:=station_id;
        Open;
        if frmdm.q2.IsEmpty=false then begin inc(tn); st_with_data:=true; end;
        Close;
       end;

{SWD}if st_with_data=true then begin
      //showmessage(inttostr(tn)+'  '+tbl);

     {...default unit ID}
     with frmdm.q2 do begin
       Close;
       SQL.Clear;
       SQL.Add(' select units_id_default from DATABASE_TABLES ');
       SQL.Add(' where name_table=:tbl ');
       ParamByName('tbl').AsString:=tbl;
       Open;
       units_def:=FieldByName('units_id_default').AsInteger;
       Close;
     end;
      {...default unit names}
     with frmdm.q2 do begin
       Close;
       SQL.Clear;
       SQL.Add(' select name_short,name from UNITS ');
       SQL.Add(' where id=:units_def ');
       ParamByName('units_def').AsInteger:=units_def;
       Open;
       units_sname:=FieldByName('name_short').AsString;
       units_name:=FieldByName('name').AsString;
       Close;
     end;
     {...profile/profiles}
     with frmdm.q2 do begin
       Close;
       SQL.Clear;
       SQL.Add(' select * from '+tbl);
       SQL.Add(' where id=:station_id ');
       SQL.Add(' and PQF2>=3 ');
       SQL.Add(' order by instrument_id,profile_number,lev_dbar ');
       ParamByName('station_id').AsInteger:=station_id;
       Open;
      end;

{frmdm.q2.Last;
showmessage('frmdm.q2.RecordCount='+inttostr(frmdm.q2.RecordCount));
frmdm.q2.First;}

{q2f}if frmdm.q2.IsEmpty=false then begin
{q2w}while not frmdm.q2.Eof do begin
      lev_dbar:=frmdm.q2.FieldByName('lev_dbar').AsFloat;           //showmessage('lev_dbar='+floattostr(lev_dbar));
      lev_m:=frmdm.q2.FieldByName('lev_m').AsFloat;                 //showmessage('lev_m='+floattostr(lev_m));
      prfn:=frmdm.q2.FieldByName('profile_number').AsInteger;       //showmessage('prf='+inttostr(prfn));
      instrument:=frmdm.q2.FieldByName('instrument_id').AsInteger;  //showmessage('instrument_id='+inttostr(instrument));
      val:=frmdm.q2.FieldByName('val').AsFloat;                     //showmessage('val='+floattostr(val));
      units_id:=frmdm.q2.FieldByName('units_id').AsInteger;         //showmessage('units_id='+inttostr(units_id));

{conv}if (units_id<>units_def) then begin
        {ICES liter->kg constant density 1.025}
        isconverted:=false;
        val_conv1:=DF;
        getdefaultunits(tbl,units_id,units_def,val,val_conv1,isconverted);
        val:=val_conv1;
{conv}end;

//showmessage('converted val='+floattostr(val));

      {ipd: instrument_id, profile_number, lev_dbar}
      ipd_exist:=false;
     for i:=0 to High(DSt) do begin
     if (DSt[i,0]=instrument) and (DSt[i,1]=prfn) and (DSt[i,2]=lev_dbar) then begin
      ipd_exist:=true;
      index:=i;
     end;
     end;

     {...add new record}
     if ipd_exist=false then begin
      {0-instrument_id 1-profile_number 2-lev_dbar 3-lev_m, var}
      setlength(DSt, length(DSt)+1, 4+var_count);
      for j:=0 to (4+var_count) do DSt[High(DSt),j]:=DF;
      DSt[High(DSt),0]:=instrument;
      DSt[High(DSt),1]:=prfn;
      DSt[High(DSt),2]:=lev_dbar;
      DSt[High(DSt),3]:=lev_m;
      DSt[High(DSt),tn+3]:=val;
     end;

     {...update record}
     if ipd_exist=true then begin
       DSt[index,tn+3]:=val;
       {if (DSt[i,0]=7) and (DSt[i,1]=3)
       then showmessage('inst='+floattostr(DSt[i,0])
           +'  prf='+floattostr(DSt[i,1])+'  dbar='+floattostr(DSt[i,2])
           +'  DSt='+floattostr(DSt[index,tn+3])
           +'  DSt='+floattostr(DSt[index,tn+4]));}
     end;

       frmdm.q2.Next;
{q2w}end;
{q2f}end;

{SWD}end;
{C}end;
{T}end;


   for i:=0 to High(DSt) do begin
   for j:=0 to 3+var_count do begin
    if j=0 then write(fo,floattostr(DSt[i,j])+#9);
    if j=1 then write(fo,floattostr(DSt[i,j]));
    if j=2 then write(fo,#9+floattostrF(DSt[i,j],ffFixed,12,1));
    if j=3 then write(fo,#9+floattostrF(DSt[i,j],ffFixed,12,1));
    if j>3 then write(fo,#9+floattostrF(DSt[i,j],ffFixed,12,3));
   end;
    writeln(fo);
   end;

    setlength(DSt,0,0);
{V}end;
    frmdm.Q.Next;
{Q}end;
    closefile(fo);

finally
    frmdm.Q.EnableControls;
{try}end;

end;

end.

