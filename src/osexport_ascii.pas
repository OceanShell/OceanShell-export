unit osexport_ascii;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Dialogs, Variants,

  // program modules
  osmain, dm, osexport, osunitsconversion;


procedure ExportASCII(user_path:string);

implementation

procedure qf_ocean_to_woce(qf_ocean:integer; var qf_woce:integer);
begin
    {WOCE flags according Table 1 in GLODAP article}
    if qf_ocean =-9999 then qf_woce:=9; //there is no sample -> data not received/not used/sample not drawn/no data
    if qf_ocean =0     then qf_woce:=9; //not checked -> data not received/not used/sample not drawn/no data
    if qf_ocean =1     then qf_woce:=4; //        bad -> bad/not used
    if qf_ocean =2     then qf_woce:=3; // suspitious -> questionable/not used
    if qf_ocean =3     then qf_woce:=0; // calculated -> not used/interpolated or calculated value
    if qf_ocean>=4     then qf_woce:=2; // acceptable -> acceptable
end;


procedure ExportASCII(user_path:string);
var
kt,ks,mik, ID, cnt: integer;
Lat, Lon:real;
tbl_count,units_count,samples_count,samples_total,conv1_count,conv2_count :integer;
units_def,station_id :integer;
step,row1,row2,sel_size :integer;
conv1_min,conv1_max,conv2_min,conv2_max :real;
conv1_md,conv2_md :double;
tbl,fn,units_name,fstr,st :string;
convert,isconverted,best :boolean;
DT1,DT2: TDateTime;

{P_tables}
lev_dbar,lev_m,val,valerr,val_conv1,val_conv2 :real;
PQF1,PQF2,SQF,WQF :integer;
btl_num,units_id,instr_id,prf_num,prf_best :integer;
fo, md: text;

first_tbl:boolean=true;
date1: TDateTime;
CrID, Cast, QCF, Ver, SrcID, InstID, ProjID, PlatID:integer;
Src, Inst, Proj, Ctry,  PLat: string;
StNum, CrNum, PiName, Depth:Variant;

begin

 assignfile(md, user_path+'metadata.txt'); rewrite(md);
 writeln(md,'Station_ID', #9, 'Latitude', #9, 'Longitude', #9, 'Date_and_time', #9,
            'Bottom_depth', #9, 'St_number_origin', #9, 'St_version', #9,
            'Cast_number', #9, 'Source_ID', #9, 'Source', #9, 'Cruise_ID', #9,
            'Cruise_number', #9, 'Platform_ID', #9, 'Platform', #9, 'Country', #9,
            'PI', #9,'Institute_ID', #9, 'Institute', #9, 'Project_ID', #9, 'Project');
try
 frmdm.Q.DisableControls;
{T}for kt:=0 to frmexport.CheckGroup1.Items.Count-1 do begin
{C}if frmexport.CheckGroup1.Checked[kt] then begin

  // Edit1.Text:='';
  // Edit2.Text:='';

   tbl:=frmexport.CheckGroup1.Items.Strings[kt]; {selected table}

   {...default unit values to be converted}
   with frmdm.q1 do begin
     Close;
     SQL.Clear;
     SQL.Add(' select units_id_default from DATABASE_TABLES ');
     SQL.Add(' where name_table=:nt ');
     ParamByName('nt').AsString:=tbl;
     Open;
     units_def:=FieldByName('units_id_default').AsInteger;
     Close;
   end;

   with frmdm.q1 do begin
     Close;
     SQL.Clear;
     SQL.Add(' select name_short as ns from UNITS ');
     SQL.Add(' where id=:units_id ');
     ParamByName('units_id').AsInteger:=units_def;
     Open;
     units_name:=FieldByName('ns').AsString;
     Close;
   end;

   fn:=user_path+copy(tbl,3,length(tbl))+'.txt';
   assignfile(fo,fn);
   rewrite(fo);

  // if convert=true then
   fstr:='id'+#9+'[dbar]'+#9+'[m]'+#9+'val'
   +#9+'PQF1'+#9+'PQF2'+#9+'SQF'+#9+'WOCEQF'
   +#9+'niskin'+#9+'units_id'+#9+'instrument_id'+#9+'prf_num'+#9+'prf_best'
   +#9+'units_def'+#9+'val_conv1'+#9+'val_conv2';
 {  if convert=false then
   fstr:='id'+#9+'[dbar]'+#9+'[m]'+#9+'val'
   +#9+'PQF1'+#9+'PQF2'+#9+'SQF'+#9+'WOCEQF'
   +#9+'niskin'+#9+'units_id'+#9+'instrument_id'+#9+'prf_num'+#9+'prf_best'; }

   {...four tables include additional column}
   if (tbl='P_HE') or (tbl='P_C14') or (tbl='P_HE3') or (tbl='P_NEON') then
   fstr:='id'+#9+'[dbar]'+#9+'[m]'+#9+'val'+#9+'count_err'
   +#9+'PQF1'+#9+'PQF2'+#9+'SQF'+#9+'WOCEQF'
   +#9+'niskin'+#9+'units_id'+#9+'instrument_id'+#9+'prf_num'+#9+'prf_best';

   writeln(fo,fstr);


   {.....total number samples in table}
  frmdm.Q.First;
  cnt:=frmdm.Q.RecordCount;
   while not frmdm.Q.EOF do begin
     ID   :=frmdm.Q.FieldByName('ID').Value;
     Lat  :=frmdm.Q.FieldByName('LATITUDE').Value;
     Lon  :=frmdm.Q.FieldByName('LONGITUDE').Value;
     Date1:=frmdm.Q.FieldByName('DATEANDTIME').Value;
     Depth:=frmdm.Q.FieldByName('BOTTOMDEPTH').Value;
     CrID :=frmdm.Q.FieldByName('CRUISE_ID').Value;
     Cast :=frmdm.Q.FieldByName('CAST_NUMBER').Value;
     StNum:=frmdm.Q.FieldByName('ST_NUMBER_ORIGIN').Value;
     QCF  :=frmdm.Q.FieldByName('QCFLAG').Value;
     Ver  :=frmdm.Q.FieldByName('STVERSION').Value;

     if first_tbl then begin
       with frmdm.q1 do begin
        Close;
         SQL.Clear;
         SQL.Add(' SELECT ');
         SQL.Add(' INSTITUTE_ID, PROJECT_ID, SOURCE_ID, SOURCE.NAME AS SRC, ');
         SQL.Add(' COUNTRY.NAME AS COUNTRY, ');
         SQL.Add(' INSTITUTE.NAME AS INSTITUTE, PROJECT.NAME AS PROJECT, ');
         SQL.Add(' CRUISE.PI,  CRUISE_NUMBER, ');
         SQL.Add(' PLATFORM_ID, PLATFORM.NAME AS PLATFORM ');
         SQL.Add(' FROM CRUISE, PLATFORM, COUNTRY, INSTITUTE, PROJECT, SOURCE ');
         SQL.Add(' WHERE ');
         SQL.Add(' CRUISE.SOURCE_ID=SOURCE.ID AND ');
         SQL.Add(' CRUISE.PLATFORM_ID=PLATFORM.ID AND ');
         SQL.Add(' PLATFORM.COUNTRY_ID=COUNTRY.ID AND ');
         SQL.Add(' CRUISE.INSTITUTE_ID=INSTITUTE.ID AND ');
         SQL.Add(' CRUISE.PROJECT_ID=PROJECT.ID AND ');
         SQL.Add(' CRUISE.ID='+inttostr(CrID));
        Open;
         CrNum :=FieldByName('CRUISE_NUMBER').Value;
         SrcID :=FieldByName('SOURCE_ID').Value;
         Src   :=FieldByName('SRC').Value;
         PlatID:=FieldByName('PLATFORM_ID').Value;
         Plat  :=FieldByName('PLATFORM').Value;
         InstID:=FieldByName('INSTITUTE_ID').Value;
         Inst  :=FieldByName('INSTITUTE').Value;
         ProjID:=FieldByName('PROJECT_ID').Value;
         Proj  :=FieldByName('PROJECT').Value;
         Ctry  :=FieldByName('COUNTRY').Value;
         PIName:=FieldByName('PI').Value;
      end;

      if VarIsNull(CrNum)=true then CrNum:='';
      if VarIsNull(StNum)=true then StNum:='';
      if VarIsNull(PiName)=true then PiName:='';
      if VarIsNull(Depth)=true then Depth:=99999;

        writeln(md,inttostr(ID), #9,
                   floattostr(Lat), #9,
                   floattostr(lon), #9,
                   datetimetostr(date1), #9,
                   inttostr(depth), #9,
                   StNum, #9,
                   inttostr(ver), #9,
                   inttostr(cast), #9,
                   inttostr(SrcID), #9,
                   Src, #9,
                   inttostr(CrID), #9,
                   CrNum, #9,
                   inttostr(PlatID), #9,
                   Plat, #9,
                   Ctry, #9,
                   PIName, #9,
                   inttostr(instid), #9,
                   Inst, #9,
                   Inttostr(ProjID), #9,
                   Proj);
     end;

       samples_count:=0;
       conv1_count:=0;
       conv2_count:=0;
       conv1_min:=9999;
       conv1_max:=-9999;
       conv1_md:=0;
       conv2_min:=9999;
       conv2_max:=-9999;
       conv2_md:=0;

   with frmdm.q1 do begin
     Close;
     SQL.Clear;
     SQL.Add(' select * from '+tbl);
     SQL.Add(' where ID=:ID');
     ParamByName('ID').AsInteger:=ID;
     Open;
   end;

   while not frmdm.q1.EOF do begin

   WQF:=9;
   val_conv1:=-9999;
   val_conv2:=-9999;

   station_id:=frmdm.q1.FieldByName('id').AsInteger;
   lev_dbar:=frmdm.q1.FieldByName('lev_dbar').AsFloat;
   lev_m:=frmdm.q1.FieldByName('lev_m').AsFloat;
   val:=frmdm.q1.FieldByName('val').AsFloat;
   PQF1:=frmdm.q1.FieldByName('PQF1').AsInteger;
   PQF2:=frmdm.q1.FieldByName('PQF2').AsInteger;
   SQF:=frmdm.q1.FieldByName('SQF').AsInteger;
   btl_num:=frmdm.q1.FieldByName('bottle_number').AsInteger;
   units_id:=frmdm.q1.FieldByName('units_id').AsInteger;
   instr_id:=frmdm.q1.FieldByName('instrument_id').AsInteger;
   prf_num:=frmdm.q1.FieldByName('profile_number').AsInteger;
   best:=frmdm.q1.FieldByName('profile_best').AsBoolean;

   if (tbl='P_HE') or (tbl='P_C14') or (tbl='P_HE3') or (tbl='P_NEON') then
   valerr:=frmdm.q1.FieldByName('valerr').AsFloat;

   if best=true then prf_best:=1 else prf_best:=0;

   {convert OCEAN QF to WOCE}
   qf_ocean_to_woce(PQF2,WQF);

   if units_id=units_def then begin
     val_conv1:=val;
     val_conv2:=val;
   end;

   {CONVERSION}
   if units_id<>units_def then begin

     isconverted:=false;
     //ICES
     GetDefaultUnits(tbl,units_id,units_def,val,val_conv1,isconverted);

    //Advanced
     GetDefaultUnitsExact(tbl,units_id,units_def,station_id,instr_id,prf_num,val,lat,lon,lev_m,val_conv2,isconverted);

   end;

   if (tbl='P_HE') or (tbl='P_C14') or (tbl='P_HE3') or (tbl='P_NEON') then
   writeln(fo,inttostr(station_id)
  +#9+floattostrF(lev_dbar,ffFixed,9,1)
  +#9+floattostrF(lev_m,ffFixed,9,1)
  +#9+floattostr(val)
  +#9+floattostr(valerr)
  +#9+inttostr(PQF1)
  +#9+inttostr(PQF2)
  +#9+inttostr(SQF)
  +#9+inttostr(WQF)
  +#9+inttostr(btl_num)
  +#9+inttostr(units_id)
  +#9+inttostr(instr_id)
  +#9+inttostr(prf_num)
  +#9+inttostr(prf_best)
  +#9+inttostr(units_def)
  +#9+floattostrF(val_conv1,ffFixed,12,5)
  +#9+floattostrF(val_conv2,ffFixed,12,5))
  else
    writeln(fo,inttostr(station_id)
   +#9+floattostrF(lev_dbar,ffFixed,9,1)
   +#9+floattostrF(lev_m,ffFixed,9,1)
   +#9+floattostr(val)
   +#9+inttostr(PQF1)
   +#9+inttostr(PQF2)
   +#9+inttostr(SQF)
   +#9+inttostr(WQF)
   +#9+inttostr(btl_num)
   +#9+inttostr(units_id)
   +#9+inttostr(instr_id)
   +#9+inttostr(prf_num)
   +#9+inttostr(prf_best)
   +#9+inttostr(units_def)
   +#9+floattostrF(val_conv1,ffFixed,12,5)
   +#9+floattostrF(val_conv2,ffFixed,12,5));


{PQF2}if PQF2>=3 then begin
  if val_conv1<>-9999 then begin
    conv1_count:=conv1_count+1;
    conv1_md:=conv1_md+val_conv1;
    if conv1_min>val_conv1 then conv1_min:=val_conv1;
    if conv1_max<val_conv1 then conv1_max:=val_conv1;
  end;
  if val_conv2<>-9999 then begin
    conv2_count:=conv2_count+1;
    conv2_md:=conv2_md+val_conv2;
    if conv2_min>val_conv2 then conv2_min:=val_conv2;
    if conv2_max<val_conv2 then conv2_max:=val_conv2;
  end;
{PQF2}end;

   frmdm.q1.Next;
{S}end;



  frmdm.Q.Next;
{STEP}end;
  closefile(fo);

  assignfile(fo, fn); reset(fo);
  readln(fo, st);
  readln(fo, st);
  closefile(fo);
  if trim(st)='' then DeleteFile(fn);

  first_tbl:=false;

{C}end; {table is checked }


{T}end; {tables cycle}
finally
  closefile(md);
  frmdm.Q.EnableControls;
end;

end;

end.

