unit osdensity;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Dialogs, dynlibs, osmain, dm, GibbsSeaWater, procedures;

procedure PopulateDensityTbl;

implementation

procedure PopulateDensityTbl;
Var
  id, cnt, raw, profnum, instrid:integer;
  prof_best:boolean;
  lat, lon, p_ref: real;
  sp, t: double;
  lev_dbar, lev_m: real;

  SA, p, pot_dens, pot_temp:double;

  gsw_sa_from_sp:Tgsw_sa_from_sp;
  gsw_rho_t_exact:Tgsw_rho_t_exact;
  gsw_pt_from_t:Tgsw_pt_from_t;
begin
 try
  with frmdm.Q do begin
    Close;
      SQL.Text:='Select ID, LATITUDE, LONGITUDE FROM STATION ORDER BY ID';
    Open;
    Last;
    First;
  end;
  cnt:=frmdm.Q.RecordCount;

  raw:=0;
   while not frmdm.Q.EOF do begin
     ID   :=frmdm.Q.FieldByName('ID').Value;
     Lat  :=frmdm.Q.FieldByName('LATITUDE').Value;
     Lon  :=frmdm.Q.FieldByName('LONGITUDE').Value;

     inc(raw);

  //   frmosmain.memo1.lines.add('STATION: '+inttostr(ID));

     sp:=-9999; t:=-9999;
     with frmdm.q1 do begin
      Close;
       SQL.Clear;
       SQL.Add(' SELECT ');
       SQL.Add(' P_TEMPERATURE.VAL as TVAL, P_SALINITY.VAL as SVAL, ');
       SQL.Add(' P_TEMPERATURE.LEV_DBAR as LEV_DBAR, ');
       SQL.Add(' P_TEMPERATURE.LEV_M as LEV_M, ');
       SQL.Add(' P_TEMPERATURE.INSTRUMENT_ID as INSTR, ');
       SQL.Add(' P_TEMPERATURE.PROFILE_NUMBER as PROF_NUM, ');
       SQL.Add(' P_TEMPERATURE.PROFILE_BEST as PROF_BEST ');
       SQL.Add(' FROM P_TEMPERATURE, P_SALINITY ');
       SQL.Add(' WHERE ');
       SQL.Add(' P_SALINITY.ID=P_TEMPERATURE.ID AND ');
      // SQL.Add(' P_SALINITY.LEV_M=P_TEMPERATURE.LEV_M AND ');
       SQL.Add(' P_SALINITY.LEV_DBAR=P_TEMPERATURE.LEV_DBAR AND ');
       SQL.Add(' P_SALINITY.INSTRUMENT_ID=P_TEMPERATURE.INSTRUMENT_ID AND ');
       SQL.Add(' P_SALINITY.PROFILE_NUMBER=P_TEMPERATURE.PROFILE_NUMBER AND ');
       SQL.Add(' P_TEMPERATURE.PQF2<>1 AND P_TEMPERATURE.PQF2<>2 AND ');
       SQL.Add(' P_SALINITY.PQF2<>1 AND P_SALINITY.PQF2<>2 AND ');
       SQL.Add(' P_SALINITY.ID=:ID ');
       ParamByName('ID').Value:=ID;
      Open;
   end;

   while not frmdm.q1.EOF do begin
    LEV_DBAR :=frmdm.q1.FieldByName('LEV_DBAR').Value;
    LEV_M    :=frmdm.q1.FieldByName('LEV_M').Value;
    ProfNum  :=frmdm.q1.FieldByName('PROF_NUM').Value;
    InstrID  :=frmdm.q1.FieldByName('INSTR').Value;
    prof_best:=frmdm.q1.FieldByName('PROF_BEST').Value;
    t        :=frmdm.q1.FieldByName('TVAL').Value;
    sp       :=frmdm.q1.FieldByName('SVAL').Value;

  //  showmessage('here');

   {         ParamByName('LEV').Value:=LEV_M;
       ParamByName('INSTR_ID').Value:=instr_id;
       ParamByName('PROF_NUM').Value:=prof_num; }
    p_ref:=10.1325; //atmosheric pressure, dbar

    gsw_sa_from_sp:=Tgsw_z_from_p(GetProcedureAddress(libgswteos, 'gsw_sa_from_sp'));
    SA  := gsw_sa_from_sp(sp, p_ref, lon, lat); // absolute salinity

   // showmessage(floattostr(SA));

    p:=LEV_DBAR+p_ref; //absolute pressure=atmospheric pressure+hydrostatic pressure

    gsw_pt_from_t:=Tgsw_pt_from_t(GetProcedureAddress(libgswteos, 'gsw_pt_from_t'));
    pot_temp:=gsw_pt_from_t(SA, t, p, p_ref);  //potential temperature
 //   showmessage(floattostr(pot_temp));

    gsw_rho_t_exact:=Tgsw_rho_t_exact(GetProcedureAddress(libgswteos, 'gsw_rho_t_exact'));
    pot_dens:=gsw_rho_t_exact(SA, pot_temp, p); //potential density
   // showmessage(floattostr(pot_dens));
    pot_dens:=pot_dens/1000;

  {  frmosmain.Memo1.Lines.add(
    floattostr(lev_dbar)+'   '+
    floattostr(t)+'   '+
    floattostr(sp)+'    '+
    floattostr(pot_dens)); }

        with frmdm.q2 do begin
            Close;
             SQL.Clear;
             SQL.Add(' insert into ');
             SQL.Add(' P_DENSITY ');
             SQL.Add(' (ID, LEV_DBAR, LEV_M, VAL, PQF1, PQF2, SQF, UNITS_ID, ');
             SQL.Add('  INSTRUMENT_ID, PROFILE_NUMBER, PROFILE_BEST) ');
             SQL.Add(' values ');
             SQL.Add(' (:ID, :LEV_DBAR, :LEV_M, :VAL, :PQF1, :PQF2, :SQF, :UNITS_ID, ');
             SQL.Add('  :INSTRUMENT_ID, :PROFILE_NUMBER, :PROFILE_BEST) ');
             ParamByName('ID').AsInteger:=id;
             ParamByName('LEV_DBAR').AsFloat:=lev_dbar;
             ParamByName('LEV_M').AsFloat:=lev_m;
             ParamByName('VAL').AsFloat:=pot_dens;
             ParamByName('PQF1').AsInteger:=0;
             ParamByName('PQF2').AsInteger:=0;
             ParamByName('SQF').AsInteger:=0;
             ParamByName('UNITS_ID').AsInteger:=29;
             ParamByName('INSTRUMENT_ID').AsInteger:=instrID;
             ParamByName('PROFILE_NUMBER').AsInteger:=profnum;
             ParamByName('PROFILE_BEST').AsBoolean:=prof_best;
            ExecSQL;
           end;

    frmdm.q1.Next;
   end;
   frmdm.TR.CommitRetaining;


     //ProgressTaskbar(raw, cnt);
    frmdm.Q.Next;
   end;
 finally
   frmdm.TR.Commit;
   frmdm.Q.EnableControls;
 end;

end;

end.

